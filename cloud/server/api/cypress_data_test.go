package api

import (
	"testing"
	"time"

	"github.com/bxcodec/faker/v3"
	"github.com/stretchr/testify/assert"

	"gitlab.com/fieldkit/cloud/server/backend/repositories"
	"gitlab.com/fieldkit/cloud/server/data"
	"gitlab.com/fieldkit/cloud/server/tests"
)

func TestAddCypressData(t *testing.T) {
	assert := assert.New(t)
	e, err := tests.NewTestEnv()
	assert.NoError(err)

	user := &data.User{
		Name:     faker.Name(),
		Username: "test@conservify.org",
		Email:    "test@conservify.org",
		Bio:      faker.Sentence(),
		Valid:    true,
		TncDate:  time.Now(),
	}

	user.SetPassword("asdfasdfasdf")

	r := repositories.NewUserRepository(e.DB)

	existing, err := r.QueryByEmail(e.Ctx, user.Email)
	assert.NoError(err)
	if existing != nil {
		assert.NoError(r.Delete(e.Ctx, existing.ID))
	}

	assert.NoError(r.Add(e.Ctx, user))
}
