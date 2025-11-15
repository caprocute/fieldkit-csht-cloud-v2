package handlers

import (
	"context"

	"go.uber.org/zap"

	"gitlab.com/fieldkit/cloud/server/common/logging"
)

func Logger(ctx context.Context) *zap.Logger {
	return logging.Logger(ctx).Named("backend")
}
