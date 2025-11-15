package backend

import (
	"context"
	"errors"
	"fmt"
	"time"

	"github.com/jackc/pgx/v5/pgxpool"

	"gitlab.com/fieldkit/cloud/server/common/jobs"
	"gitlab.com/fieldkit/cloud/server/common/logging"
	"gitlab.com/fieldkit/cloud/server/common/txs"
	"gitlab.com/fieldkit/cloud/server/messages"
	"gitlab.com/fieldkit/cloud/server/storage"
)

type RefreshMaterializedViewsHandler struct {
	metrics  *logging.Metrics
	tsConfig *storage.TimeScaleDBConfig
}

func NewRefreshMaterializedViewsHandler(metrics *logging.Metrics, tsConfig *storage.TimeScaleDBConfig) *RefreshMaterializedViewsHandler {
	return &RefreshMaterializedViewsHandler{
		metrics:  metrics,
		tsConfig: tsConfig,
	}
}

func (h *RefreshMaterializedViewsHandler) Start(ctx context.Context, m *messages.RefreshAllMaterializedViews, mc *jobs.MessageContext) error {
	log := Logger(ctx).Sugar()

	log.Infow("refresh: querying windows")

	pgPool, err := h.tsConfig.Acquire(ctx)
	if err != nil {
		return err
	}

	rw := NewRefreshWindows(pgPool)

	if dirtyWindows, err := rw.QueryForDirty(ctx); err != nil {
		return err
	} else {
		numberRows := 0

		for _, dirty := range dirtyWindows {
			numberRows += dirty.NumberRows
		}

		now := time.Now().UTC()

		for _, view := range h.tsConfig.MaterializedViews() {
			publishes := 0

			for _, dirty := range dirtyWindows {
				if dirty.DataStart != nil && dirty.DataEnd != nil {
					// Calculate this view's 'horizon' time, which is the time after
					// which samples are being read live. We can't attempt to
					// materialize after this time.
					horizon := view.TimeBucket(view.HorizonTime(now))
					start := view.TimeBucket(*dirty.DataStart).UTC()
					last := view.TimeBucket(*dirty.DataEnd).Add(view.BucketWidth).UTC()

					for {
						end := start.Add(view.RefreshWidth)
						finished := false

						if end.After(last) {
							log.Infow("refresh:last", "end", end, "last", last)
							end = last
							finished = true
						}

						if end.After(horizon) {
							log.Infow("refresh:horizon", "end", end, "horizon", horizon)
							end = horizon
							finished = true
						}

						if start == end || start.After(end) {
							break
						}

						log.Debugw("refresh:send", "view", view.ShortName, "start", start, "end", end)

						mc.Publish(ctx, &messages.RefreshMaterializedView{
							View:  view.ShortName,
							Start: start,
							End:   end,
						}, jobs.WithPriority(5))

						start = end
						publishes += 1

						if finished {
							break
						}
					}

				}
			}

			log.Infow("refresh:view", "view", view.ShortName, "publishes", publishes)
		}

		if numberRows > 0 {
			log.Infow("refresh: deleting")

			deleted, err := rw.DeleteAll(ctx)
			if err != nil {
				return err
			}

			if numberRows != int(deleted) {
				return fmt.Errorf("dirty rows conflict, expected to delete %d, got %d", numberRows, deleted)
			}
		}
	}

	return nil
}

var (
	ErrEmptyRefresh = errors.New("empty refresh")
)

func (h *RefreshMaterializedViewsHandler) getRefreshSQL(_ context.Context, m *messages.RefreshMaterializedView, view *storage.MaterializedView) (string, []interface{}, error) {
	if m.Start.IsZero() || m.End.IsZero() {
		return view.MakeRefreshAllSQL()
	}

	// Calculate this view's 'horizon' time, which is the time after
	// which samples are being read live. We can't attempt to
	// materialize after this time.
	horizon := view.HorizonTime(time.Now().UTC())

	// Calculate the buckets affected. TsDB will only materialize
	// bucket/bins that fall completely within this range. Again,
	// total overlap.
	start := view.TimeBucket(m.Start)
	end := view.TimeBucket(m.End).Add(view.BucketWidth)

	// NOTE: We may want this to eventually include the bin being overlapped
	// with intentionally as part of the refresh policy.
	if end.After(horizon) {
		// Avoid 'refresh window too small' error from TsDB when refresh width
		// is less than a single bucket width.
		if horizon.Sub(start) < view.BucketWidth {
			return "", nil, ErrEmptyRefresh
		}
		end = horizon

	}

	return view.MakeRefreshWindowSQL(start.UTC(), end.UTC())
}

func (h *RefreshMaterializedViewsHandler) RefreshView(ctx context.Context, m *messages.RefreshMaterializedView, mc *jobs.MessageContext) error {
	log := Logger(ctx).Sugar().With("view", m.View)

	pgPool, err := h.tsConfig.Acquire(ctx)
	if err != nil {
		return err
	}

	for _, view := range h.tsConfig.MaterializedViews() {
		if view.ShortName == m.View {
			if sql, args, err := h.getRefreshSQL(ctx, m, view); err != nil {
				if err != ErrEmptyRefresh {
					return err
				}
				log.Infow("refresh", "start", m.Start, "end", m.End, "empty", true)
			} else {
				log.Infow("refresh", "start", m.Start, "end", m.End, "args", args)

				if _, err := pgPool.Exec(ctx, sql, args...); err != nil {
					return err
				}
			}
		}
	}

	return nil
}

type RefreshWindows struct {
	pool *pgxpool.Pool
}

func NewRefreshWindows(pool *pgxpool.Pool) *RefreshWindows {
	return &RefreshWindows{
		pool: pool,
	}
}

type DirtyRange struct {
	ModifiedTime *time.Time `json:"modified"`
	DataStart    *time.Time `json:"data_start"`
	DataEnd      *time.Time `json:"data_end"`
	NumberRows   int        `json:"number_rows"`
}

func (rw *RefreshWindows) queryAllRows(ctx context.Context) ([]*DirtyRange, error) {
	return rw.queryRows(ctx, "SELECT modified, data_start, data_end, 1 AS number_rows FROM fieldkit.sensor_data_dirty ORDER BY data_start")
}

func (rw *RefreshWindows) queryAggregated(ctx context.Context) ([]*DirtyRange, error) {
	return rw.queryRows(ctx, "SELECT MAX(modified), MIN(data_start), MAX(data_end), COUNT(*) AS number_rows FROM fieldkit.sensor_data_dirty")
}

func (rw *RefreshWindows) QueryForDirty(ctx context.Context) ([]*DirtyRange, error) {
	log := Logger(ctx).Sugar()

	allDirty, err := rw.queryAllRows(ctx)
	if err != nil {
		return nil, err
	}

	for _, dirty := range allDirty {
		log.Infow("dirty", "dirty_start", dirty.DataStart.UTC(), "dirty_end", dirty.DataEnd.UTC(), "modified", dirty.ModifiedTime.UTC())
	}

	return allDirty, nil
}

func (rw *RefreshWindows) queryRows(ctx context.Context, query string) ([]*DirtyRange, error) {
	tx, err := txs.RequireQueryable(ctx, rw.pool)
	if err != nil {
		return nil, err
	}

	pgRows, err := tx.Query(ctx, query)
	if err != nil {
		return nil, fmt.Errorf("(query-dirty) %w", err)
	}

	defer pgRows.Close()

	rows := make([]*DirtyRange, 0)

	for pgRows.Next() {
		row := &DirtyRange{}

		if err := pgRows.Scan(&row.ModifiedTime, &row.DataStart, &row.DataEnd, &row.NumberRows); err != nil {
			return nil, err
		}

		rows = append(rows, row)
	}

	if pgRows.Err() != nil {
		return nil, pgRows.Err()
	}

	return rows, nil
}

func (rw *RefreshWindows) DeleteAll(ctx context.Context) (int64, error) {
	tx, err := txs.RequireQueryable(ctx, rw.pool)
	if err != nil {
		return 0, err
	}

	c, err := tx.Exec(ctx, "DELETE FROM fieldkit.sensor_data_dirty")
	if err != nil {
		return 0, err
	}

	return c.RowsAffected(), nil
}
