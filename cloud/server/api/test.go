package api

import (
	"context"

	"goa.design/goa/v3/security"

	test "gitlab.com/fieldkit/cloud/server/api/gen/test"

	"gitlab.com/fieldkit/cloud/server/common"
)

type TestService struct {
	options *ControllerOptions
}

func NewTestSevice(ctx context.Context, options *ControllerOptions) *TestService {
	return &TestService{
		options: options,
	}
}

func (sc *TestService) Noop(ctx context.Context) error {
	return nil
}

func (s *TestService) JWTAuth(ctx context.Context, token string, scheme *security.JWTScheme) (context.Context, error) {
	return Authenticate(ctx, common.AuthAttempt{
		Token:        token,
		Scheme:       scheme,
		Key:          s.options.JWTHMACKey,
		Unauthorized: func(m string) error { return test.Unauthorized(m) },
		NotFound:     nil,
	})
}
