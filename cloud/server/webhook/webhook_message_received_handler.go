package webhook

import (
	"context"
	"errors"
	"fmt"
	"time"

	"gitlab.com/fieldkit/cloud/server/common/jobs"
	"gitlab.com/fieldkit/cloud/server/common/logging"
	"gitlab.com/fieldkit/cloud/server/common/sqlxcache"

	"gitlab.com/fieldkit/cloud/server/data"

	"gitlab.com/fieldkit/cloud/server/backend/handlers"
	"gitlab.com/fieldkit/cloud/server/backend/repositories"
	"gitlab.com/fieldkit/cloud/server/storage"
)

type WebHookMessageReceivedHandler struct {
	db       *sqlxcache.DB
	model    *ModelAdapter
	iness    *handlers.InterestingnessHandler
	jqCache  *JqCache
	batch    *MessageBatch
	tsConfig *storage.TimeScaleDBConfig
	verbose  bool
}

func NewWebHookMessageReceivedHandler(db *sqlxcache.DB, metrics *logging.Metrics, publisher jobs.MessagePublisher, tsConfig *storage.TimeScaleDBConfig, verbose bool) *WebHookMessageReceivedHandler {
	return &WebHookMessageReceivedHandler{
		db:       db,
		model:    NewModelAdapter(db),
		iness:    handlers.NewInterestingnessHandler(db),
		tsConfig: tsConfig,
		jqCache:  &JqCache{},
		batch:    &MessageBatch{},
		verbose:  verbose,
	}
}

func (h *WebHookMessageReceivedHandler) Handle(ctx context.Context, m *WebHookMessageReceived) error {
	mr := NewMessagesRepository(h.db)

	if err := mr.QueryMessageForProcessing(ctx, h.batch, m.MessageID, false); err != nil {
		return err
	}

	log := Logger(ctx).Sugar().With("schema_id", m.SchemaID).With("message_id", m.MessageID)

	for _, row := range h.batch.Messages {
		if incoming, err := h.parseMessage(ctx, row); err != nil {
			if errors.Is(err, ErrNoDeviceName) {
				log.Warnw("wh:no-device-name")
				return nil
			} else {
				return err
			}
		} else {
			if len(incoming) == 0 {
				log.Infow("wh:no-incoming")
			} else {
				if h.tsConfig != nil {
					if err := h.saveMessages(ctx, incoming); err != nil {
						return err
					}
				} else {
					log.Infow("wh:no-ts-config")
				}
			}
		}
	}

	return nil
}

func (h *WebHookMessageReceivedHandler) parseMessage(ctx context.Context, row *WebHookMessage) ([]*data.IncomingReading, error) {
	rowLog := Logger(ctx).Sugar().With("schema_id", row.SchemaID).With("message_id", row.ID)

	rowLog.Infow("wh:parsing")

	incoming := make([]*data.IncomingReading, 0)

	allParsed, err := row.Parse(ctx, h.jqCache, h.batch.Schemas)
	if err != nil {
		rowLog.Infow("wh:skipping", "reason", err)
	} else {
		for _, parsed := range allParsed {
			if parsed.ReceivedAt != nil && parsed.ReceivedAt.After(time.Now()) {
				rowLog.Warnw("wh:ignored-future-sample", "future_time", parsed.ReceivedAt)
			} else {
				if h.verbose {
					rowLog.Infow("wh:parsed", "received_at", parsed.ReceivedAt, "device_name", parsed.DeviceName, "data", parsed.Data)
				}

				if saved, err := h.model.Save(ctx, parsed); err != nil {
					return nil, fmt.Errorf("save-model-error: %w", err)
				} else if parsed.ReceivedAt != nil {
					if len(saved.Sensors) != len(parsed.Data) {
						rowLog.Warnf("wh:saved != parsed")
					}
					for _, savedSensor := range saved.Sensors {
						parsedSensor := savedSensor.parsed

						key := parsedSensor.Key
						if key == "" {
							return nil, fmt.Errorf("parsed-sensor has no sensor key")
						}

						if !parsedSensor.Transient {
							sensorKey := fmt.Sprintf("%s.%s", saved.SensorPrefix, key)

							ir := &data.IncomingReading{
								Time:      *parsed.ReceivedAt,
								StationID: saved.Station.ID,
								ModuleID:  savedSensor.sensor.ModuleID,
								SensorKey: sensorKey,
								Value:     parsedSensor.Value,
							}

							if err := h.iness.ConsiderReading(ctx, ir); err != nil {
								return nil, err
							}

							incoming = append(incoming, ir)
						}
					}
				}
			}
		}

		if err := h.model.Close(ctx); err != nil {
			return nil, fmt.Errorf("close-model-error: %w", err)
		}

		if err := h.iness.Close(ctx); err != nil {
			return nil, fmt.Errorf("close-iness-error: %w", err)
		}
	}

	return incoming, nil
}

func (h *WebHookMessageReceivedHandler) saveMessages(ctx context.Context, incoming []*data.IncomingReading) error {
	sr := repositories.NewSensorsRepository(h.db)

	sensors, err := sr.QueryAllSensors(ctx)
	if err != nil {
		return err
	}

	pgPool, err := h.tsConfig.Acquire(ctx)
	if err != nil {
		return err
	}

	for _, ir := range incoming {
		meta := sensors[ir.SensorKey]
		if meta == nil {
			return fmt.Errorf("unknown sensor: '%s'", ir.SensorKey)
		}

		// TODO location
		_, err = pgPool.Exec(ctx, `
			INSERT INTO fieldkit.sensor_data (time, station_id, module_id, sensor_id, value)
			VALUES ($1, $2, $3, $4, $5)
			ON CONFLICT (time, station_id, module_id, sensor_id)
			DO UPDATE SET value = EXCLUDED.value
		`, ir.Time, ir.StationID, ir.ModuleID, meta.ID, ir.Value)
		if err != nil {
			return fmt.Errorf("save-error: %w", err)
		}
	}

	return nil
}
