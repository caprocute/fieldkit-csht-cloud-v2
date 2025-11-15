package backend

import (
	"context"
	_ "fmt"
	_ "time"

	_ "github.com/jackc/pgx/v5"
	"github.com/vgarvardt/gue/v4"

	"gitlab.com/fieldkit/cloud/server/messages"
	"gitlab.com/fieldkit/cloud/server/storage"

	"gitlab.com/fieldkit/cloud/server/common/jobs"
	"gitlab.com/fieldkit/cloud/server/common/logging"
	"gitlab.com/fieldkit/cloud/server/common/sqlxcache"
	"gitlab.com/fieldkit/cloud/server/common/txs"
)

type MergeModulesHandler struct {
	db        *sqlxcache.DB
	metrics   *logging.Metrics
	publisher jobs.MessagePublisher
	tsConfig  *storage.TimeScaleDBConfig
}

func NewMergeModulesHandler(db *sqlxcache.DB, metrics *logging.Metrics, publisher jobs.MessagePublisher, tsConfig *storage.TimeScaleDBConfig) *MergeModulesHandler {
	return &MergeModulesHandler{
		db:        db,
		metrics:   metrics,
		publisher: publisher,
		tsConfig:  tsConfig,
	}
}

func (h *MergeModulesHandler) Merge(ctx context.Context, m *messages.MergeModules, j *gue.Job, mc *jobs.MessageContext) error {
	log := logging.Logger(ctx).Sugar().With("saga_id", mc.SagaID(), "configuration_id", m.ConfigurationID, "deleting_id", m.DeletingID, "keeping_id", m.KeepingID, "migration", true)

	log.Infow("merging")

	pool, err := h.tsConfig.Acquire(ctx)
	if err != nil {
		return err
	}

	scopeCtx, scope := txs.NewTransactionScope(ctx, pool)
	tx, err := txs.RequireTransaction(scopeCtx, pool)
	if err != nil {
		return err
	}
	if v, err := tx.Exec(scopeCtx, "UPDATE fieldkit.sensor_data d SET module_id = $1 WHERE d.module_id = $2", m.KeepingID, m.DeletingID); err != nil {
		if err := scope.Rollback(ctx); err != nil {
			log.Warnw("merge:rollback", "error", err)
		}
		return err
	} else {
		log.Infow("merged:update", "rows_affected", v.RowsAffected())
	}
	if err := scope.Commit(ctx); err != nil {
		return err
	}

	// No two phase commit here, so if this fails we'll end up trying this again, but updating nothing when the above code runs the second time.
	if v, err := h.db.ExecContext(ctx, "UPDATE fieldkit.merged_module SET merged = TRUE WHERE keeping_id = $1 AND deleted_id = $2", m.KeepingID, m.DeletingID); err != nil {
		return err
	} else {
		if rows, err := v.RowsAffected(); err != nil {
			// Why not?
			return err
		} else {
			log.Infow("merged:marking", "rows_affected", rows)
		}
	}

	return nil
}

type MergedModule struct {
	StationID       int32 `db:"station_id"`
	ConfigurationID int64 `db:"configuration_id"`
	DeletedID       int64 `db:"deleted_id"`
	KeepingID       int64 `db:"keeping_id"`
}

func (h *MergeModulesHandler) PopQueue(ctx context.Context, m *messages.PopMergeQueue, j *gue.Job, mc *jobs.MessageContext) error {
	log := logging.Logger(ctx).Sugar().With("saga_id", mc.SagaID())

	queue := []*MergedModule{}
	err := h.db.SelectContext(ctx, &queue, `
SELECT
	s.id AS station_id, sc.id AS configuration_id, mm.deleted_id, mm.keeping_id
FROM fieldkit.station AS s
    JOIN fieldkit.provision AS p ON (s.device_id = p.device_id)
	JOIN fieldkit.station_configuration AS sc ON (p.id = sc.provision_id) 
	JOIN fieldkit.merged_module AS mm ON (mm.configuration_id = sc.id)
WHERE mm.tried IS NULL
ORDER BY s.updated_at DESC
	`)
	if err != nil {
		return err
	}

	log.Infow("pop-queue", "migration", "modules", "queue_length", len(queue))

	if len(queue) > 0 {
		if m.Rows != nil {
			log.Infow("pop-queue", "migration", "modules", "queue_length", len(queue), "rows", m.Rows)

			for i := 0; i < *m.Rows; i += 1 {
				row := queue[i]
				work := messages.MergeModules{
					StationID:       row.StationID,
					ConfigurationID: row.ConfigurationID,
					DeletingID:      row.DeletedID,
					KeepingID:       row.KeepingID,
				}
				if err := h.publisher.Publish(ctx, work); err != nil {
					return err
				}
				if _, err := h.db.ExecContext(ctx, "UPDATE fieldkit.merged_module SET tried = NOW() WHERE deleted_id = $1 AND keeping_id = $2", row.DeletedID, row.KeepingID); err != nil {
					return err
				}
			}
		} else if m.Stations != nil {
			remaining := *m.Stations
			log.Infow("pop-queue", "migration", "modules", "queue_length", len(queue), "stations", remaining)

			published := 0
			station := queue[0].StationID
			for _, row := range queue {
				if row.StationID != station {
					log.Infow("pop-queue", "migration", "modules", "queue_length", len(queue), "station_id", station, "published", published)

					published = 1
					remaining -= 1
					if remaining > 0 {
						station = row.StationID
					} else {
						break
					}
				}

				work := messages.MergeModules{
					StationID:       row.StationID,
					ConfigurationID: row.ConfigurationID,
					DeletingID:      row.DeletedID,
					KeepingID:       row.KeepingID,
				}
				if err := h.publisher.Publish(ctx, work); err != nil {
					return err
				}
				if _, err := h.db.ExecContext(ctx, "UPDATE fieldkit.merged_module SET tried = NOW() WHERE deleted_id = $1 AND keeping_id = $2", row.DeletedID, row.KeepingID); err != nil {
					return err
				}

				published += 1
			}
		} else {
			log.Warnw("pop-queue:noop")
		}

	} else {
		log.Warnw("pop-queue:empty")
	}

	return nil
}
