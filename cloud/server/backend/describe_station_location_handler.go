package backend

import (
	"context"

	"github.com/vgarvardt/gue/v4"

	"gitlab.com/fieldkit/cloud/server/backend/repositories"
	"gitlab.com/fieldkit/cloud/server/common/jobs"
	"gitlab.com/fieldkit/cloud/server/common/logging"
	"gitlab.com/fieldkit/cloud/server/common/sqlxcache"
	"gitlab.com/fieldkit/cloud/server/data"
	"gitlab.com/fieldkit/cloud/server/messages"
)

type DescribeStationLocationHandler struct {
	db        *sqlxcache.DB
	metrics   *logging.Metrics
	publisher jobs.MessagePublisher
	locations *data.DescribeLocations
}

func NewDescribeStationLocationHandler(db *sqlxcache.DB, metrics *logging.Metrics, publisher jobs.MessagePublisher, locations *data.DescribeLocations) *DescribeStationLocationHandler {
	return &DescribeStationLocationHandler{
		db:        db,
		metrics:   metrics,
		publisher: publisher,
		locations: locations,
	}
}

func (h *DescribeStationLocationHandler) Handle(ctx context.Context, m *messages.StationLocationUpdated, j *gue.Job) error {
	log := Logger(ctx).Sugar().With("station_id", m.StationID)

	log.Infow("describing-location")

	location := data.NewLocation(m.Location)

	names, err := h.locations.Describe(ctx, location)
	if err != nil {
		return err
	} else if names != nil && (names.OtherLandName != nil || names.NativeLandName != nil) {
		stations := repositories.NewStationRepository(h.db)

		station, err := stations.QueryStationByID(ctx, m.StationID)
		if err != nil {
			return err
		}

		if names.OtherLandName != nil {
			station.PlaceOther = names.OtherLandName
		}

		if names.NativeLandName != nil {
			station.PlaceNative = names.NativeLandName
		}

		if err := stations.UpdateStationPlaces(ctx, station); err != nil {
			return err
		}
	}

	return nil
}
