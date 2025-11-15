package api

import (
	"context"
	"errors"
	"fmt"
	"strconv"
	"strings"
	"time"

	_ "github.com/lib/pq"

	"gitlab.com/fieldkit/cloud/server/common/sqlxcache"

	"goa.design/goa/v3/security"

	sensor "gitlab.com/fieldkit/cloud/server/api/gen/sensor"

	"gitlab.com/fieldkit/cloud/server/backend"
	"gitlab.com/fieldkit/cloud/server/backend/repositories"
	"gitlab.com/fieldkit/cloud/server/common"
	"gitlab.com/fieldkit/cloud/server/data"
	"gitlab.com/fieldkit/cloud/server/storage"

	"gitlab.com/fieldkit/cloud/server/api/querying"
)

type StationsMeta struct {
	Stations map[int32][]*repositories.StationSensor `json:"stations"`
}

type SensorMeta struct {
	ID  int64  `json:"id"`
	Key string `json:"key"`
}

type MetaResult struct {
	Sensors []*SensorMeta `json:"sensors"`
	Modules interface{}   `json:"modules"`
}

func NewRawQueryParamsFromSensorData(payload *sensor.DataPayload) (*backend.RawQueryParams, error) {
	return &backend.RawQueryParams{
		Start:      payload.Start,
		End:        payload.End,
		Resolution: payload.Resolution,
		Stations:   payload.Stations,
		Sensors:    payload.Sensors,
		Aggregate:  payload.Aggregate,
		Tail:       payload.Tail,
		Complete:   payload.Complete,
		Backend:    payload.Backend,
	}, nil
}

type SensorService struct {
	options         *ControllerOptions
	timeScaleConfig *storage.TimeScaleDBConfig
	db              *sqlxcache.DB
	tsdb            querying.DataBackend
}

func NewSensorService(ctx context.Context, options *ControllerOptions, timeScaleConfig *storage.TimeScaleDBConfig) *SensorService {
	return &SensorService{
		options:         options,
		timeScaleConfig: timeScaleConfig,
		db:              options.Database,
	}
}

func (c *SensorService) chooseBackend(ctx context.Context) (querying.DataBackend, error) {
	if c.tsdb == nil {
		if c.timeScaleConfig == nil {
			log := Logger(ctx).Sugar()
			log.Errorw("tsdb:no-configuration")
		} else {
			sensors := repositories.NewSensorsRepository(c.db)

			queryingSpec, err := sensors.QueryQueryingSpec(ctx)
			if err != nil {
				return nil, fmt.Errorf("error querying for querying spec: %w", err)
			}

			if tsdb, err := querying.NewTimeScaleDBBackend(c.timeScaleConfig, c.db, c.options.Metrics, queryingSpec); err != nil {
				return nil, err
			} else {
				c.tsdb = tsdb
			}
		}
	}
	return c.tsdb, nil
}

func (c *SensorService) tail(ctx context.Context, be querying.DataBackend, stationIDs []int32) (*sensor.DataResult, error) {
	data, err := be.QueryTail(ctx, stationIDs)
	if err != nil {
		return nil, err
	}

	return &sensor.DataResult{
		Object: data,
	}, nil
}

func (c *SensorService) Data(ctx context.Context, payload *sensor.DataPayload) (*sensor.DataResult, error) {
	rawParams, err := NewRawQueryParamsFromSensorData(payload)
	if err != nil {
		return nil, err
	}

	qp, err := rawParams.BuildQueryParams()
	if err != nil {
		return nil, sensor.MakeBadRequest(err)
	}

	be, err := c.chooseBackend(ctx)
	if err != nil {
		return nil, sensor.MakeBadRequest(err)
	}

	log := Logger(ctx).Sugar()

	log.Infow("parameters", "start", qp.Start, "end", qp.End, "sensor_ids", qp.SensorIDs(), "module_hw_ids", qp.ModuleIDs(), "stations", qp.Stations, "resolution", qp.Resolution, "aggregate", qp.Aggregate, "tail", qp.Tail)

	if qp.Tail > 0 {
		return c.tail(ctx, be, qp.Stations)
	} else if len(qp.Sensors) == 0 {
		// TODO Deprecated, remove in 0.2.53
		// return nil, sensor.MakeBadRequest(fmt.Errorf("stations:empty"))
		if res, err := c.StationMeta(ctx, &sensor.StationMetaPayload{
			Stations: payload.Stations,
		}); err != nil {
			return nil, err
		} else {
			return &sensor.DataResult{
				Object: res.Object,
			}, nil
		}
	}

	data, err := be.QueryData(ctx, qp)
	if err != nil {
		return nil, err
	}

	return &sensor.DataResult{
		Object: data,
	}, nil
}

func (c *SensorService) Tail(ctx context.Context, payload *sensor.TailPayload) (*sensor.TailResult, error) {
	stationIDs := backend.ParseStationIDs(payload.Stations)
	if len(stationIDs) == 0 {
		return nil, sensor.MakeBadRequest(fmt.Errorf("stations:empty"))
	}

	be, err := c.chooseBackend(ctx)
	if err != nil {
		return nil, err
	}

	data, err := be.QueryTail(ctx, stationIDs)
	if err != nil {
		return nil, err
	}

	return &sensor.TailResult{
		Object: data,
	}, nil
}

func (c *SensorService) parseWindows(payload *sensor.RecentlyPayload) []time.Duration {
	durations := make([]time.Duration, 0)

	if payload.Windows != nil {
		windows := strings.Split(*payload.Windows, ",")
		for _, hoursString := range windows {
			hours, err := strconv.Atoi(hoursString)
			if err == nil {
				durations = append(durations, time.Hour*time.Duration(hours))
			}
		}
	}

	return durations
}

func (c *SensorService) Recently(ctx context.Context, payload *sensor.RecentlyPayload) (*sensor.RecentlyResult, error) {
	stationIDs := backend.ParseStationIDs(payload.Stations)
	if len(stationIDs) == 0 {
		return nil, sensor.MakeBadRequest(fmt.Errorf("stations:empty"))
	}

	be, err := c.chooseBackend(ctx)
	if err != nil {
		return nil, err
	}

	durations := c.parseWindows(payload)
	if len(durations) == 0 {
		return &sensor.RecentlyResult{
			Object: querying.NewRecentlyAggregated(),
		}, nil
	}

	data, err := be.QueryRecentlyAggregated(ctx, stationIDs, durations)
	if err != nil {
		return nil, err
	}

	return &sensor.RecentlyResult{
		Object: data,
	}, nil
}

func (c *SensorService) StationMeta(ctx context.Context, payload *sensor.StationMetaPayload) (*sensor.StationMetaResult, error) {
	sr := repositories.NewStationRepository(c.db)

	stationIDs := backend.ParseStationIDs(payload.Stations)

	byStation, err := sr.QueryStationSensors(ctx, stationIDs)
	if err != nil {
		return nil, err
	}

	data := &StationsMeta{
		Stations: byStation,
	}

	return &sensor.StationMetaResult{
		Object: data,
	}, nil
}

func (c *SensorService) SensorMeta(ctx context.Context) (*sensor.SensorMetaResult, error) {
	keysToId := []*data.Sensor{}
	if err := c.db.SelectContext(ctx, &keysToId, `SELECT * FROM fieldkit.aggregated_sensor ORDER BY key`); err != nil {
		return nil, err
	}

	sensors := make([]*SensorMeta, 0)
	for _, ids := range keysToId {
		sensors = append(sensors, &SensorMeta{
			ID:  ids.ID,
			Key: ids.Key,
		})
	}

	r := repositories.NewModuleMetaRepository(c.options.Database)
	modules, err := r.FindAllModulesMeta(ctx)
	if err != nil {
		return nil, err
	}

	data := &MetaResult{
		Sensors: sensors,
		Modules: modules.All(),
	}

	return &sensor.SensorMetaResult{
		Object: data,
	}, nil
}

func (c *SensorService) Meta(ctx context.Context) (*sensor.MetaResult, error) { // TODO Deprecated, remove in 0.2.53
	if res, err := c.SensorMeta(ctx); err != nil {
		return nil, err
	} else {
		return &sensor.MetaResult{
			Object: res.Object,
		}, nil
	}
}

func (c *SensorService) Bookmark(ctx context.Context, payload *sensor.BookmarkPayload) (*sensor.BookmarkAndPermissions, error) {
	repository := repositories.NewBookmarkRepository(c.options.Database)

	saved, err := repository.AddNew(ctx, nil, payload.Bookmark)
	if err != nil {
		return nil, err
	}

	permissions, err := c.MakeBookmarkPermissions(ctx, saved)
	if err != nil {
		return nil, err
	}

	return &sensor.BookmarkAndPermissions{
		URL:         fmt.Sprintf("/viz?v=%s", saved.Token),
		Token:       saved.Token,
		Bookmark:    payload.Bookmark,
		Permissions: permissions,
	}, nil
}

func (c *SensorService) Resolve(ctx context.Context, payload *sensor.ResolvePayload) (*sensor.BookmarkAndPermissions, error) {
	repository := repositories.NewBookmarkRepository(c.options.Database)

	resolved, err := repository.Resolve(ctx, payload.V)
	if err != nil {
		return nil, err
	}
	if resolved == nil {
		return nil, sensor.MakeNotFound(errors.New("not found"))
	}

	permissions, err := c.MakeBookmarkPermissions(ctx, resolved)
	if err != nil {
		return nil, err
	}

	return &sensor.BookmarkAndPermissions{
		URL:         fmt.Sprintf("/viz?v=%s", resolved.Token),
		Bookmark:    resolved.Bookmark,
		Permissions: permissions,
	}, nil
}

func (s *SensorService) JWTAuth(ctx context.Context, token string, scheme *security.JWTScheme) (context.Context, error) {
	return Authenticate(ctx, common.AuthAttempt{
		Token:        token,
		Scheme:       scheme,
		Key:          s.options.JWTHMACKey,
		NotFound:     nil,
		Unauthorized: func(m string) error { return sensor.MakeUnauthorized(errors.New(m)) },
		Forbidden:    func(m string) error { return sensor.MakeForbidden(errors.New(m)) },
	})
}

func (c *SensorService) MakeBookmarkPermissions(ctx context.Context, saved *repositories.SavedBookmark) (*sensor.BookmarkPermissions, error) {
	p, err := NewPermissions(ctx, c.options).Unwrap()
	if err != nil {
		return nil, err
	}

	if p.Anonymous() {
		return &sensor.BookmarkPermissions{
			CanAddEvent:   false,
			CanAddComment: false,
		}, nil
	}

	bookmark, err := saved.Parse()
	if err != nil {
		return nil, err
	}

	userID := p.UserID()

	r := NewBookmarkPermissionsRepository(c.options.Database)

	return r.MakeBookmarkPermissions(ctx, bookmark, userID)
}

type BookmarkPermissionsRepository struct {
	db *sqlxcache.DB
}

func NewBookmarkPermissionsRepository(db *sqlxcache.DB) *BookmarkPermissionsRepository {
	return &BookmarkPermissionsRepository{db: db}
}

func (r *BookmarkPermissionsRepository) MakeBookmarkPermissions(ctx context.Context, bookmark *data.Bookmark, userID int32) (*sensor.BookmarkPermissions, error) {
	log := Logger(ctx).Sugar()

	projectIDs, err := bookmark.ProjectIDs()
	if err != nil {
		log.Errorw("permissions", "error", err)
		return &sensor.BookmarkPermissions{
			CanAddEvent:   false,
			CanAddComment: false,
		}, nil
	}

	stationIDs, err := bookmark.StationIDs()
	if err != nil {
		log.Errorw("permissions", "error", err)
		return &sensor.BookmarkPermissions{
			CanAddEvent:   false,
			CanAddComment: false,
		}, nil
	}

	userStations, err := NewUserStations(ctx, r.db, userID, stationIDs)
	if err != nil {
		return nil, err
	}

	userProjects, err := NewUserProjects(ctx, r.db, userID, projectIDs)
	if err != nil {
		return nil, err
	}

	canAddEvent := userProjects.AnyProjects() && userProjects.AdminInAllProjects()
	canAddComment :=
		(userStations.AnyStations() && !userStations.AnyUnownedPrivateStations()) && !userProjects.AnyPrivateProjectsOutsideOf()

	log.Infow("permissions", "any_projects", userProjects.AnyProjects(),
		"in_any_projects", userProjects.InAnyProjects(),
		"all_public_projects", userProjects.AllPublicProjects(),
		"admin_in_all_projects", userProjects.AdminInAllProjects(),
		"any_private_projects_outside_of", userProjects.AnyPrivateProjectsOutsideOf())

	return &sensor.BookmarkPermissions{
		CanAddEvent:   canAddEvent,
		CanAddComment: canAddComment,
	}, nil
}

type UserStations struct {
	userID          int32
	stations        []*data.Station
	userProjects    map[int32]*data.ProjectUser
	stationProjects map[int32][]int32
	projectStations map[int32][]int32
}

func NewUserStations(ctx context.Context, db *sqlxcache.DB, userID int32, stationIDs []int32) (*UserStations, error) {
	sr := repositories.NewStationRepository(db)
	pr := repositories.NewProjectRepository(db)

	userProjects, err := pr.QueryProjectUsers(ctx, userID)
	if err != nil {
		return nil, err
	}

	stations, err := sr.QueryStationsByIDs(ctx, stationIDs)
	if err != nil {
		return nil, err
	}

	return &UserStations{
		userID:       userID,
		stations:     stations,
		userProjects: userProjects,
	}, nil
}

func (us *UserStations) AnyStations() bool {
	return len(us.stations) > 0
}

func (us *UserStations) AnyUnownedPrivateStations() bool {
	for _, station := range us.stations {
		if station.Hidden != nil && *station.Hidden && station.OwnerID != us.userID {
			return true
		}
	}
	return false
}

type UserProjects struct {
	userID       int32
	projects     []*data.Project
	userProjects map[int32]*data.ProjectUser
}

func NewUserProjects(ctx context.Context, db *sqlxcache.DB, userID int32, projectIDs []int32) (*UserProjects, error) {
	pr := repositories.NewProjectRepository(db)

	userProjects, err := pr.QueryProjectUsers(ctx, userID)
	if err != nil {
		return nil, err
	}

	projects, err := pr.QueryByIDs(ctx, projectIDs)
	if err != nil {
		return nil, err
	}

	return &UserProjects{
		userID:       userID,
		projects:     projects,
		userProjects: userProjects,
	}, nil
}

func (up *UserProjects) AnyProjects() bool {
	return len(up.projects) > 0
}

func (up *UserProjects) InAnyProjects() bool {
	return len(up.userProjects) > 0
}

func (up *UserProjects) AdminInAllProjects() bool {
	if len(up.projects) == 0 {
		return false
	}
	for _, p := range up.projects {
		if pu, ok := up.userProjects[p.ID]; ok {
			if !pu.LookupRole().IsProjectAdministrator() {
				return false
			}
		} else {
			return false
		}
	}
	return true
}

func (up *UserProjects) AllPublicProjects() bool {
	if len(up.projects) == 0 {
		return false
	}
	for _, p := range up.projects {
		if p.Privacy != data.Public {
			return false
		}
	}
	return true
}

func (up *UserProjects) AnyPrivateProjectsOutsideOf() bool {
	for _, p := range up.projects {
		if p.Privacy != data.Public {
			if _, ok := up.userProjects[p.ID]; !ok {
				return true
			}
		}
	}
	return false
}
