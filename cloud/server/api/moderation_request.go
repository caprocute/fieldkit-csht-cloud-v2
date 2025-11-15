package api

import (
	"context"
	"errors"
	"fmt"
	"time"

	"goa.design/goa/v3/security"

	"gitlab.com/fieldkit/cloud/server/api/gen/moderation"
	moderationService "gitlab.com/fieldkit/cloud/server/api/gen/moderation"
	"gitlab.com/fieldkit/cloud/server/backend/repositories"
	"gitlab.com/fieldkit/cloud/server/common"
	"gitlab.com/fieldkit/cloud/server/data"
)

type ModerationService struct {
	options *ControllerOptions
}

func NewModerationService(ctx context.Context, options *ControllerOptions) *ModerationService {
	return &ModerationService{
		options: options,
	}
}

func (s *ModerationService) Add(ctx context.Context, payload *moderation.ModerationAddPayload) (*moderation.ModerationRequest, error) {
	tx, err := s.options.Database.Begin(ctx)
	if err != nil {
		return nil, err
	}

	response, err := s.add(ctx, payload)
	if err != nil {
		tx.Rollback()
		return nil, err
	}

	err = tx.Commit()
	return response, err
}

func (s *ModerationService) add(ctx context.Context, payload *moderation.ModerationAddPayload) (*moderation.ModerationRequest, error) {
	p, err := NewPermissions(ctx, s.options).Unwrap()
	if err != nil {
		return nil, err
	}

	if payload.PostType != string(data.ModerationDiscussionPost) && payload.PostType != string(data.ModerationDataEvent) {
		return nil, fmt.Errorf("invalid post type")
	}

	mrRepo := repositories.NewModerationRepository(s.options.Database)
	mr := &data.ModerationRequest{
		PostID:     payload.PostID,
		PostType:   data.PostTypeEnum(payload.PostType),
		ReportedBy: p.UserID(),
		ReportedAt: time.Now().UTC(),
	}

	created, err := mrRepo.AddModerationRequest(ctx, mr)
	if err != nil {
		return nil, err
	}

	response := &moderation.ModerationRequest{
		ID:         created.ID,
		PostID:     created.PostID,
		PostType:   string(created.PostType),
		ReportedBy: created.ReportedBy,
		ReportedAt: created.ReportedAt.Format(time.RFC3339),
	}

	return response, nil
}

func (s *ModerationService) Acknowledge(ctx context.Context, payload *moderation.AcknowledgePayload) (*moderation.ModerationRequest, error) {
	p, err := NewPermissions(ctx, s.options).Unwrap()
	if err != nil {
		return nil, err
	}

	if !p.IsAdmin() {
		return nil, moderation.MakeForbidden(errors.New("admin access required"))
	}

	userID := p.UserID()

	mrRepo := repositories.NewModerationRepository(s.options.Database)
	req, err := mrRepo.AcknowledgeRequest(ctx, payload.ID, userID, payload.Action)
	if err != nil {
		return nil, err
	}

	var acknowledgedAt *string
	if req.AcknowledgedAt != nil {
		formatted := req.AcknowledgedAt.Format(time.RFC3339)
		acknowledgedAt = &formatted
	}

	var acknowledgedByUser *moderation.UserInfo
	if req.AcknowledgedByName != nil {
		acknowledgedByUser = &moderation.UserInfo{Name: *req.AcknowledgedByName}
	}

	response := &moderation.ModerationRequest{
		ID:                 req.ID,
		PostID:             req.PostID,
		PostType:           req.PostType,
		ReportedBy:         req.ReportedBy,
		ReportedByName:     req.ReportedByName,
		ReportedAt:         req.ReportedAt.Format(time.RFC3339),
		AcknowledgedBy:     req.AcknowledgedBy,
		AcknowledgedByUser: acknowledgedByUser,
		AcknowledgedAt:     acknowledgedAt,
	}

	return response, nil
}

func (s *ModerationService) JWTAuth(ctx context.Context, token string, scheme *security.JWTScheme) (context.Context, error) {
	return Authenticate(ctx, common.AuthAttempt{
		Token:        token,
		Scheme:       scheme,
		Key:          s.options.JWTHMACKey,
		NotFound:     func(m string) error { return moderationService.MakeNotFound(errors.New(m)) },
		Unauthorized: func(m string) error { return moderationService.MakeUnauthorized(errors.New(m)) },
		Forbidden:    func(m string) error { return moderationService.MakeForbidden(errors.New(m)) },
	})
}

func (s *ModerationService) ListRequests(ctx context.Context, payload *moderation.ListRequestsPayload) (*moderation.ModerationRequests, error) {
	p, err := NewPermissions(ctx, s.options).Unwrap()
	if err != nil {
		return nil, err
	}

	if !p.IsAdmin() {
		return nil, moderation.MakeForbidden(errors.New("admin access required"))
	}

	mrRepo := repositories.NewModerationRepository(s.options.Database)
	requests, totalPages, err := mrRepo.GetAllModerationRequests(ctx, payload.Page, payload.PageSize)
	if err != nil {
		return nil, err
	}

	// Convert data.ModerationRequestDetail to moderation.ModerationRequest
	moderationRequests := make([]*moderation.ModerationRequest, len(requests))
	for i, req := range requests {
		var acknowledgedAt *string
		if req.AcknowledgedAt != nil {
			formatted := req.AcknowledgedAt.Format(time.RFC3339)
			acknowledgedAt = &formatted
		}

		var acknowledgedByUser *moderation.UserInfo
		if req.AcknowledgedByName != nil {
			acknowledgedByUser = &moderation.UserInfo{Name: *req.AcknowledgedByName}
		}

		moderationRequests[i] = &moderation.ModerationRequest{
			ID:                 req.ID,
			PostID:             req.PostID,
			PostType:           req.PostType,
			ReportedBy:         req.ReportedBy,
			ReportedByName:     req.ReportedByName,
			ReportedAt:         req.ReportedAt.Format(time.RFC3339),
			AcknowledgedBy:     req.AcknowledgedBy,
			AcknowledgedByUser: acknowledgedByUser,
			AcknowledgedAt:     acknowledgedAt,
		}
	}

	return &moderation.ModerationRequests{
		Requests:   moderationRequests,
		TotalPages: int(totalPages),
	}, nil
}

func (s *ModerationService) GetContent(ctx context.Context, payload *moderation.GetContentPayload) (string, error) {
	p, err := NewPermissions(ctx, s.options).Unwrap()
	if err != nil {
		return "", err
	}

	if !p.IsAdmin() {
		return "", moderation.MakeForbidden(errors.New("admin access required"))
	}

	mrRepo := repositories.NewModerationRepository(s.options.Database)
	content, err := mrRepo.GetContent(ctx, data.PostTypeEnum(payload.PostType), payload.PostID)
	if err != nil {
		return "", err
	}

	if content == "" {
		return "", moderation.MakeNotFound(fmt.Errorf("content not found for type %s and id %d", payload.PostType, payload.PostID))
	}

	return content, nil
}

func (s *ModerationService) Cancel(ctx context.Context, payload *moderation.CancelPayload) error {
	p, err := NewPermissions(ctx, s.options).Unwrap()
	if err != nil {
		return err
	}

	if payload.PostType != string(data.ModerationDiscussionPost) && payload.PostType != string(data.ModerationDataEvent) {
		return fmt.Errorf("invalid post type")
	}

	mrRepo := repositories.NewModerationRepository(s.options.Database)
	err = mrRepo.CancelModerationRequest(ctx, payload.PostID, data.PostTypeEnum(payload.PostType), p.UserID())
	if err != nil {
		return moderation.MakeNotFound(err)
	}

	return nil
}

func (s *ModerationService) CheckUserReport(ctx context.Context, payload *moderation.CheckUserReportPayload) (*moderation.CheckUserReportResult, error) {
	p, err := NewPermissions(ctx, s.options).Unwrap()
	if err != nil {
		return nil, err
	}

	if payload.PostType != string(data.ModerationDiscussionPost) && payload.PostType != string(data.ModerationDataEvent) {
		return nil, fmt.Errorf("invalid post type")
	}

	mrRepo := repositories.NewModerationRepository(s.options.Database)
	hasReported, canWithdraw, err := mrRepo.CheckUserReport(ctx, payload.PostID, data.PostTypeEnum(payload.PostType), p.UserID())
	if err != nil {
		return nil, err
	}

	return &moderation.CheckUserReportResult{
		HasReported: hasReported,
		CanWithdraw: canWithdraw,
	}, nil
}
