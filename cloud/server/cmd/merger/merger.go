package main

import (
	"context"
	"encoding/hex"
	"flag"
	"fmt"
	"time"

	"github.com/jmoiron/sqlx"
	"github.com/kelseyhightower/envconfig"

	"gitlab.com/fieldkit/cloud/server/backend/repositories"
	"gitlab.com/fieldkit/cloud/server/common/logging"
	"gitlab.com/fieldkit/cloud/server/common/sqlxcache"
	"gitlab.com/fieldkit/cloud/server/data"
	"gitlab.com/fieldkit/cloud/server/storage"
)

type Options struct {
	PostgresURL  string `split_words:"true"`
	TimeScaleURL string `split_words:"true"`
	Commit       bool
}

func (options *Options) timeScaleConfig() *storage.TimeScaleDBConfig {
	if options.TimeScaleURL == "" {
		return nil
	}

	return &storage.TimeScaleDBConfig{Url: options.TimeScaleURL}
}

func (options *Options) refreshViews(ctx context.Context) error {
	tsConfig := options.timeScaleConfig()

	if tsConfig == nil {
		return fmt.Errorf("refresh-views missing tsdb configuration")
	}

	return tsConfig.RefreshViews(ctx)
}

type StationMerger struct {
	primaryDb     *sqlxcache.DB
	tsDb          *sqlxcache.DB
	queryStations *repositories.StationRepository
}

func NewStationMerger(primaryDb *sqlxcache.DB, tsDb *sqlxcache.DB) *StationMerger {
	return &StationMerger{
		primaryDb:     primaryDb,
		tsDb:          tsDb,
		queryStations: repositories.NewStationRepository(primaryDb),
	}
}

func (s *StationMerger) MergeSensorData(ctx context.Context, tx *sqlx.Tx, keepingModuleID int64, emptyingModuleID int64) error {
	log := logging.Logger(ctx).Sugar()

	if false {
		row := tx.QueryRowContext(ctx, `SELECT MAX(time) AS max_time FROM fieldkit.sensor_data WHERE module_id = $1`, keepingModuleID)
		if err := row.Err(); err != nil {
			return err
		}

		before := time.Time{}
		if err := row.Scan(&before); err != nil {
			return err
		}

		log.Infow("original:max", "time", before, "keeping_module_id", keepingModuleID, "emptying_module_id", emptyingModuleID)

		if _, err := tx.ExecContext(ctx, `
		DELETE FROM fieldkit.sensor_data WHERE module_id = $1 AND time <=
			(SELECT MAX(time) FROM fieldkit.sensor_data WHERE module_id = $2)
		`,
			emptyingModuleID, keepingModuleID); err != nil {
			return err
		}
	}

	if _, err := tx.ExecContext(ctx, `
		UPDATE fieldkit.sensor_data d SET module_id = $1 WHERE d.module_id = $2
		`,
		keepingModuleID, emptyingModuleID); err != nil {
		return err
	}

	return nil
}

func (s *StationMerger) ProcessAllStations(outerCtx context.Context, options *Options) error {
	log := logging.Logger(outerCtx).Sugar()

	models, err := s.queryStations.QueryStationModels(outerCtx)
	if err != nil {
		return err
	}
	stations := make([]*data.Station, 0)
	for _, model := range models {
		modelStations, err := s.queryStations.QueryAllStationsByModelID(outerCtx, model.ID)
		if err != nil {
			return err
		}

		stations = append(stations, modelStations...)
	}

	modules, err := s.queryStations.QueryAllStationModules(outerCtx)
	if err != nil {
		return err
	}

	log.Infow("preparing", "total_modules", len(modules), "total_stations", len(stations))

	byHardwareID := make(map[string][]int64)
	deletingModules := make(map[int64]int64)
	moduleConfigurations := make(map[int64]int64)
	for _, module := range modules {
		id := hex.EncodeToString(module.HardwareID)
		if byHardwareID[id] == nil {
			byHardwareID[id] = make([]int64, 0)
		}
		byHardwareID[id] = append(byHardwareID[id], module.ID)
		if len(byHardwareID[id]) > 1 {
			deletingModules[module.ID] = byHardwareID[id][0]
			log.Infow("module:will-delete", "deleting_id", module.ID, "keeping_id", byHardwareID[id][0])
		}
		moduleConfigurations[module.ID] = module.ConfigurationID
	}

	log.Infow("modules", "unique_modules", len(byHardwareID), "deleting", len(deletingModules))

	if len(byHardwareID) == len(modules) {
		return nil
	}

	moduleStations := make(map[int64][]int32)

	for _, station := range stations {
		log.Infow("station", "station_id", station.ID, "station_name", station.Name)

		err := s.primaryDb.WithNewOwnedTransaction(outerCtx, func(ctx context.Context, tx *sqlx.Tx) error {
			full, err := s.queryStations.QueryStationFull(ctx, station.ID)
			if err != nil {
				return err
			}

			if len(full.Configurations) == 1 {
				config := full.Configurations[0]
				configID := config.ID

				for _, module := range full.Modules {
					moduleID := module.ID
					if keeping, ok := deletingModules[module.ID]; ok {
						moduleID = keeping
					}

					moduleConfig := data.ConfigurationModule{
						ConfigurationID: configID,
						ModuleID:        moduleID,
						Index:           module.Index,
						Position:        module.Position,
					}

					log.Infow("config:module:solo", "configuration_id", config.ID, "module_id", module.ID, "merged_module_id", moduleConfig.ModuleID)

					_, err := s.queryStations.InsertConfigurationModule(ctx, &moduleConfig)
					if err != nil {
						return err
					}

					if moduleStations[module.ID] != nil {
						return fmt.Errorf("module seen before, unexpectedly")
					}
					moduleStations[module.ID] = []int32{station.ID}
				}
			} else if len(full.Configurations) > 1 {
				for _, config := range full.Configurations {
					empty := true

					for _, module := range full.Modules {
						if module.ConfigurationID == config.ID {
							moduleID := module.ID
							if keeping, ok := deletingModules[module.ID]; ok {
								moduleID = keeping
							}

							moduleConfig := data.ConfigurationModule{
								ConfigurationID: config.ID,
								ModuleID:        moduleID,
								Index:           module.Index,
								Position:        module.Position,
							}

							log.Infow("config:module:multiple", "configuration_id", config.ID, "module_id", module.ID, "merged_module_id", moduleConfig.ModuleID)

							_, err := s.queryStations.InsertConfigurationModule(ctx, &moduleConfig)
							if err != nil {
								return err
							}

							if moduleStations[moduleID] == nil {
								moduleStations[moduleID] = make([]int32, 0)
							}
							moduleStations[moduleID] = append(moduleStations[moduleID], station.ID)

							empty = false
						}
					}

					if empty {
						log.Infow("config:empty, deleting", "configuration_id", config.ID)

						_, err := tx.ExecContext(ctx, "DELETE FROM station_configuration WHERE id = $1", config.ID)
						if err != nil {
							return err
						}
					}
				}
			}

			if options.Commit {
				return tx.Commit()
			} else {
				return tx.Rollback()
			}
		})
		if err != nil {
			return err
		}
	}

	err = s.primaryDb.WithNewOwnedTransaction(outerCtx, func(ctx context.Context, tx *sqlx.Tx) error {
		for deletingID, keepingID := range deletingModules {
			configurationID := moduleConfigurations[deletingID]

			log.Infow("deleting", "module_id", deletingID, "keeping_id", keepingID)

			if false {
				if err := s.queryStations.DeleteStationModule(ctx, deletingID); err != nil {
					return err
				}
			} else {
				if _, err := tx.ExecContext(ctx, "INSERT INTO fieldkit.merged_module (configuration_id, deleted_id, keeping_id) VALUES ($1, $2, $3)", configurationID, deletingID, keepingID); err != nil {
					return err
				}
			}

			_ = keepingID
		}

		if options.Commit {
			return tx.Commit()
		} else {
			return tx.Rollback()
		}
	})
	if err != nil {
		return err
	}

	log.Infow("modules", "unique_modules", len(byHardwareID), "deleting", len(deletingModules))

	_ = log

	return nil
}

func process(ctx context.Context, options *Options) error {
	if err := envconfig.Process("FIELDKIT", options); err != nil {
		panic(err)
	}

	primaryDb, err := sqlxcache.Open(ctx, "postgres", options.PostgresURL)
	if err != nil {
		return err
	}

	tsDb, err := sqlxcache.Open(ctx, "postgres", options.TimeScaleURL)
	if err != nil {
		return err
	}

	merger := NewStationMerger(primaryDb, tsDb)

	if err := merger.ProcessAllStations(ctx, options); err != nil {
		return err
	}

	if options.Commit {
		if err := options.refreshViews(ctx); err != nil {
			return err
		}
	}

	return nil
}

func main() {
	ctx := context.Background()
	options := &Options{}

	flag.BoolVar(&options.Commit, "commit", false, "Commit, otherwise changes will be rolled back.")

	flag.Parse()

	logging.Configure(false, "merger")

	if err := process(ctx, options); err != nil {
		log := logging.Logger(ctx).Sugar()
		log.Errorw("error", "err", err)
	}
}
