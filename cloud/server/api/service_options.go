package api

import (
	"context"
	"encoding/base64"

	"github.com/vgarvardt/gue/v4"

	"github.com/aws/aws-sdk-go/aws/session"

	"gitlab.com/fieldkit/cloud/server/common/sqlxcache"

	"gitlab.com/fieldkit/cloud/server/common/jobs"
	"gitlab.com/fieldkit/cloud/server/common/logging"

	"gitlab.com/fieldkit/cloud/server/data"
	"gitlab.com/fieldkit/cloud/server/email"
	"gitlab.com/fieldkit/cloud/server/files"
	"gitlab.com/fieldkit/cloud/server/storage"
)

type ControllerOptions struct {
	Config       *ApiConfiguration
	Session      *session.Session
	Database     *sqlxcache.DB
	Querier      *data.Querier
	JWTHMACKey   []byte
	Emailer      email.Emailer
	Domain       string
	PortalDomain string
	Metrics      *logging.Metrics
	Publisher    jobs.MessagePublisher
	MediaFiles   files.FileArchive

	// Twitter
	ConsumerKey    string
	ConsumerSecret string

	// Services
	signer    *Signer
	locations *data.DescribeLocations
	que       *gue.Client

	// Subscribed listeners
	subscriptions *Subscriptions

	timeScaleConfig *storage.TimeScaleDBConfig

	photoCache *PhotoCache
}

func CreateServiceOptions(ctx context.Context, config *ApiConfiguration, database *sqlxcache.DB, publisher jobs.MessagePublisher, mediaFiles files.FileArchive,
	awsSession *session.Session, metrics *logging.Metrics, que *gue.Client, timeScaleConfig *storage.TimeScaleDBConfig) (controllerOptions *ControllerOptions, err error) {

	emailer, err := createEmailer(awsSession, config)
	if err != nil {
		return nil, err
	}

	jwtHMACKey, err := base64.StdEncoding.DecodeString(config.SessionKey)
	if err != nil {
		return nil, err
	}

	locations := data.NewDescribeLocations(config.MapboxToken, config.NativeLandsToken, metrics)

	controllerOptions = &ControllerOptions{
		Session:         awsSession,
		Database:        database,
		Querier:         data.NewQuerier(database),
		Emailer:         emailer,
		JWTHMACKey:      jwtHMACKey,
		Domain:          config.Domain,
		PortalDomain:    config.PortalDomain,
		Metrics:         metrics,
		Config:          config,
		Publisher:       publisher,
		MediaFiles:      mediaFiles,
		signer:          NewSigner(jwtHMACKey),
		locations:       locations,
		que:             que,
		subscriptions:   NewSubscriptions(),
		timeScaleConfig: timeScaleConfig,
		photoCache:      NewPhotoCache(mediaFiles, metrics),
	}

	return
}

func (o *ControllerOptions) Close() error {
	return nil
}
