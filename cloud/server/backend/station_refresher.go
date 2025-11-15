package backend

import (
	"context"
	"time"

	"gitlab.com/fieldkit/cloud/server/common/sqlxcache"
	"gitlab.com/fieldkit/cloud/server/storage"
)

/**
 * This type is deprecated.
 */

type StationRefresher struct {
	db          *sqlxcache.DB
	tsConfig    *storage.TimeScaleDBConfig
	tableSuffix string
}

func NewStationRefresher(db *sqlxcache.DB, tsConfig *storage.TimeScaleDBConfig, tableSuffix string) (sr *StationRefresher, err error) {
	return &StationRefresher{
		db:          db,
		tsConfig:    tsConfig,
		tableSuffix: tableSuffix,
	}, nil
}

func (sr *StationRefresher) Refresh(_ context.Context, _ int32, _ time.Duration, _, _ bool) error {
	return nil
}
