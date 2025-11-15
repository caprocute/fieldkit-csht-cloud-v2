package data

import (
	"time"
)

type PostTypeEnum string

const (
	ModerationDiscussionPost PostTypeEnum = "discussion_post"
	ModerationDataEvent      PostTypeEnum = "data_event"
)

type Moderator struct {
	ID        int       `db:"id"`
	UserID    int32     `db:"user_id"`
	CreatedAt time.Time `db:"created_at"`
}

type ModerationAddPayload struct {
	PostID   int32        `json:"post_id"`
	PostType PostTypeEnum `json:"post_type"`
}

type ModerationRequest struct {
	ID             int32        `db:"id"`
	PostID         int32        `db:"post_id"`
	PostType       PostTypeEnum `db:"post_type"`
	ReportedBy     int32        `db:"reported_by"`
	ReportedAt     time.Time    `db:"reported_at"`
	AcknowledgedBy *int32       `db:"acknowledged_by"`
	AcknowledgedAt *time.Time   `db:"acknowledged_at"`
}

type AcknowledgePayload struct {
	ID             int32 `json:"id"`
	AcknowledgedBy int32 `json:"post_id"`
}

type ModerationRequestDetail struct {
	ID                 int32      `json:"id" db:"id"`
	PostID             int32      `json:"postId" db:"post_id"`
	PostType           string     `json:"postType" db:"post_type"`
	ReportedBy         int32      `json:"reportedBy" db:"reported_by"`
	ReportedByName     *string    `json:"reportedByName" db:"reported_by_name"`
	ReportedAt         time.Time  `json:"reportedAt" db:"reported_at"`
	AcknowledgedBy     *int32     `json:"acknowledgedBy,omitempty" db:"acknowledged_by"`
	AcknowledgedByName *string    `json:"acknowledgedByName,omitempty" db:"acknowledged_by_name"`
	AcknowledgedAt     *time.Time `json:"acknowledgedAt,omitempty" db:"acknowledged_at"`
}
