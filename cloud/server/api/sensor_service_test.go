package api

import (
	"fmt"
	"net/http"
	"testing"

	"github.com/kinbiko/jsonassert"
	"github.com/stretchr/testify/assert"

	"gitlab.com/fieldkit/cloud/server/data"
	"gitlab.com/fieldkit/cloud/server/tests"
)

func TestGetSensorsMeta(t *testing.T) {
	assert := assert.New(t)
	e, err := tests.NewTestEnv()
	assert.NoError(err)

	api, err := NewTestableApi(e)
	assert.NoError(err)

	req, _ := http.NewRequest("GET", "/sensors", nil)
	rr := tests.ExecuteRequest(req, api)

	assert.Equal(http.StatusOK, rr.Code)
}

func TestGetSensorsDataNoStationsOrSensors(t *testing.T) {
	assert := assert.New(t)
	e, err := tests.NewTestEnv()
	assert.NoError(err)

	fd, err := e.AddStations(1)
	assert.NoError(err)

	api, err := NewTestableApi(e)
	assert.NoError(err)

	req, _ := http.NewRequest("GET", "/sensors/data", nil)
	req.Header.Add("Authorization", e.NewAuthorizationHeaderForUser(fd.Owner))
	rr := tests.ExecuteRequest(req, api)

	assert.Equal(http.StatusBadRequest, rr.Code)
}

func TestGetStationSensors(t *testing.T) {
	assert := assert.New(t)
	e, err := tests.NewTestEnv()
	assert.NoError(err)

	fd, err := e.AddStations(1)
	assert.NoError(err)

	api, err := NewTestableApi(e)
	assert.NoError(err)

	req, _ := http.NewRequest("GET", fmt.Sprintf("/meta/stations?stations=%d", 1), nil)
	req.Header.Add("Authorization", e.NewAuthorizationHeaderForUser(fd.Owner))
	rr := tests.ExecuteRequest(req, api)

	assert.Equal(http.StatusOK, rr.Code)

	ja := jsonassert.New(t)
	ja.Assertf(rr.Body.String(), `
	{
		"stations": "<<PRESENCE>>"
	}`)
}

func TestGetBookmarkPermissionsNoProjectsAndNoStations(t *testing.T) {
	assert := assert.New(t)
	e, err := tests.NewTestEnv()
	assert.NoError(err)

	user, err := e.AddUser()
	assert.NoError(err)

	r := NewBookmarkPermissionsRepository(e.DB)

	perms, err := r.MakeBookmarkPermissions(e.Ctx, &data.Bookmark{}, user.ID)
	assert.NoError(err)
	assert.False(perms.CanAddComment)
	assert.False(perms.CanAddEvent)
}

func TestGetBookmarkPermissionsNoProjectsAndPublicStation(t *testing.T) {
	assert := assert.New(t)
	e, err := tests.NewTestEnv()
	assert.NoError(err)

	user, err := e.AddUser()
	assert.NoError(err)

	station, err := e.AddStation()
	assert.NoError(err)

	r := NewBookmarkPermissionsRepository(e.DB)

	perms, err := r.MakeBookmarkPermissions(e.Ctx, &data.Bookmark{Stations: []int32{station.ID}}, user.ID)
	assert.NoError(err)
	assert.True(perms.CanAddComment)
	assert.False(perms.CanAddEvent)
}

func TestGetBookmarkPermissionsOnePrivateProjectNotAMember(t *testing.T) {
	assert := assert.New(t)
	e, err := tests.NewTestEnv()
	assert.NoError(err)

	user, err := e.AddUser()
	assert.NoError(err)

	station, err := e.AddStation()
	assert.NoError(err)

	p1, err := e.AddProjectWithPrivacy(data.Private)
	assert.NoError(err)

	r := NewBookmarkPermissionsRepository(e.DB)

	perms, err := r.MakeBookmarkPermissions(e.Ctx, &data.Bookmark{Stations: []int32{station.ID}, Projects: &[]int32{p1.ID}}, user.ID)
	assert.NoError(err)
	assert.False(perms.CanAddComment)
	assert.False(perms.CanAddEvent)
}

func TestGetBookmarkPermissionsOnePublicProjectNotAMember(t *testing.T) {
	assert := assert.New(t)
	e, err := tests.NewTestEnv()
	assert.NoError(err)

	user, err := e.AddUser()
	assert.NoError(err)

	station, err := e.AddStation()
	assert.NoError(err)

	p1, err := e.AddProjectWithPrivacy(data.Public)
	assert.NoError(err)

	r := NewBookmarkPermissionsRepository(e.DB)

	perms, err := r.MakeBookmarkPermissions(e.Ctx, &data.Bookmark{Stations: []int32{station.ID}, Projects: &[]int32{p1.ID}}, user.ID)
	assert.NoError(err)
	assert.True(perms.CanAddComment)
	assert.False(perms.CanAddEvent)
}

func TestGetBookmarkPermissionsOnePublicProjectMember(t *testing.T) {
	assert := assert.New(t)
	e, err := tests.NewTestEnv()
	assert.NoError(err)

	user, err := e.AddUser()
	assert.NoError(err)

	station, err := e.AddStation()
	assert.NoError(err)

	p1, err := e.AddProjectWithPrivacy(data.Public)
	assert.NoError(err)

	assert.NoError(e.AddProjectUser(p1, user, data.MemberRole))

	r := NewBookmarkPermissionsRepository(e.DB)

	perms, err := r.MakeBookmarkPermissions(e.Ctx, &data.Bookmark{Stations: []int32{station.ID}, Projects: &[]int32{p1.ID}}, user.ID)
	assert.NoError(err)
	assert.True(perms.CanAddComment)
	assert.False(perms.CanAddEvent)
}

func TestGetBookmarkPermissionsOnePublicProjectAdmin(t *testing.T) {
	assert := assert.New(t)
	e, err := tests.NewTestEnv()
	assert.NoError(err)

	user, err := e.AddUser()
	assert.NoError(err)

	station, err := e.AddStation()
	assert.NoError(err)

	p1, err := e.AddProjectWithPrivacy(data.Public)
	assert.NoError(err)

	assert.NoError(e.AddProjectUser(p1, user, data.AdministratorRole))

	r := NewBookmarkPermissionsRepository(e.DB)

	perms, err := r.MakeBookmarkPermissions(e.Ctx, &data.Bookmark{Stations: []int32{station.ID}, Projects: &[]int32{p1.ID}}, user.ID)
	assert.NoError(err)
	assert.True(perms.CanAddComment)
	assert.True(perms.CanAddEvent)
}

type InteresetingProjectSituations struct {
	user             *data.User
	nonMember        *data.Project
	nonMemberPrivate *data.Project
	memberOf         *data.Project
	memberOfPrivate  *data.Project
	adminOf          *data.Project
}

func NewInteresetingProjectSituations(e *tests.TestEnv) (*InteresetingProjectSituations, error) {
	user, err := e.AddUser()
	if err != nil {
		return nil, err
	}

	nonMember, err := e.AddProjectWithPrivacy(data.Public)
	if err != nil {
		return nil, err
	}

	nonMemberPrivate, err := e.AddProjectWithPrivacy(data.Private)
	if err != nil {
		return nil, err
	}

	memberOf, err := e.AddProjectWithPrivacy(data.Public)
	if err != nil {
		return nil, err
	}
	if err := e.AddProjectUser(memberOf, user, data.MemberRole); err != nil {
		return nil, err
	}

	memberOfPrivate, err := e.AddProjectWithPrivacy(data.Private)
	if err != nil {
		return nil, err
	}
	if err := e.AddProjectUser(memberOfPrivate, user, data.MemberRole); err != nil {
		return nil, err
	}

	adminOf, err := e.AddProjectWithPrivacy(data.Public)
	if err != nil {
		return nil, err
	}
	if err := e.AddProjectUser(adminOf, user, data.AdministratorRole); err != nil {
		return nil, err
	}

	return &InteresetingProjectSituations{
		user:             user,
		nonMember:        nonMember,
		nonMemberPrivate: nonMemberPrivate,
		memberOf:         memberOf,
		memberOfPrivate:  memberOfPrivate,
		adminOf:          adminOf,
	}, nil
}

func TestUserProjectsAdminInAllProjects(t *testing.T) {
	assert := assert.New(t)
	e, err := tests.NewTestEnv()
	assert.NoError(err)

	f, err := NewInteresetingProjectSituations(e)
	assert.NoError(err)

	up, err := NewUserProjects(e.Ctx, e.DB, f.user.ID, []int32{})
	assert.NoError(err)
	assert.False(up.AnyProjects())
	assert.True(up.InAnyProjects())
	assert.False(up.AdminInAllProjects())
	assert.False(up.AllPublicProjects())
	assert.False(up.AnyPrivateProjectsOutsideOf())

	up, err = NewUserProjects(e.Ctx, e.DB, f.user.ID, []int32{f.nonMember.ID})
	assert.NoError(err)
	assert.True(up.AnyProjects())
	assert.True(up.InAnyProjects())
	assert.False(up.AdminInAllProjects())
	assert.True(up.AllPublicProjects())
	assert.False(up.AnyPrivateProjectsOutsideOf())

	up, err = NewUserProjects(e.Ctx, e.DB, f.user.ID, []int32{f.nonMember.ID, f.memberOf.ID})
	assert.NoError(err)
	assert.True(up.AnyProjects())
	assert.True(up.InAnyProjects())
	assert.False(up.AdminInAllProjects())
	assert.True(up.AllPublicProjects())
	assert.False(up.AnyPrivateProjectsOutsideOf())

	up, err = NewUserProjects(e.Ctx, e.DB, f.user.ID, []int32{f.nonMember.ID, f.memberOf.ID, f.adminOf.ID})
	assert.NoError(err)
	assert.True(up.AnyProjects())
	assert.True(up.InAnyProjects())
	assert.False(up.AdminInAllProjects())
	assert.True(up.AllPublicProjects())
	assert.False(up.AnyPrivateProjectsOutsideOf())

	up, err = NewUserProjects(e.Ctx, e.DB, f.user.ID, []int32{f.adminOf.ID})
	assert.NoError(err)
	assert.True(up.AnyProjects())
	assert.True(up.InAnyProjects())
	assert.True(up.AdminInAllProjects())
	assert.True(up.AllPublicProjects())
	assert.False(up.AnyPrivateProjectsOutsideOf())
}
