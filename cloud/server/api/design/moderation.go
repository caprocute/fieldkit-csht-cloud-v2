package design

import (
	. "goa.design/goa/v3/dsl"
)

var ModerationRequest = Type("ModerationRequest", func() {
	Attribute("id", Int32)
	Attribute("postId", Int32)
	Attribute("postType", String)
	Attribute("reportedBy", Int32)
	Attribute("reportedByName", String)
	Attribute("reportedAt", String)
	Attribute("acknowledgedBy", Int32)
	Attribute("acknowledgedByUser", UserInfo)
	Attribute("acknowledgedAt", String)
	Required("id", "postId", "postType", "reportedBy", "reportedAt")
})

var ModerationAddPayload = Type("ModerationAddPayload", func() {
	Token("auth")
	Attribute("postId", Int32)
	Attribute("postType", String)
	Required("postId", "postType")
})

var ModerationRequestsResponse = ResultType("application/vnd.moderation.requests", func() {
	Description("Response containing a list of moderation requests")
	Attributes(func() {
		Attribute("requests", ArrayOf(ModerationRequest))
		Attribute("total_pages", Int)
		Required("requests", "total_pages")
	})
})

var ModerationRequestDetail = Type("ModerationRequestDetail", func() {
	Field(1, "id", Int32)
	Field(2, "postId", Int32)
	Field(3, "postType", String)
	Field(4, "reportedBy", Int32)
	Field(5, "reportedByUser", UserInfo)
	Field(6, "reportedAt", String)
	Field(7, "acknowledgedBy", Int32)
	Field(8, "acknowledgedByUser", UserInfo)
	Field(9, "acknowledgedAt", String)
	Required("id", "postId", "postType", "reportedBy", "reportedAt")
})

var UserInfo = Type("UserInfo", func() {
	Field(1, "name", String)
	Required("name")
})

var CheckUserReportResult = Type("CheckUserReportResult", func() {
	Attribute("hasReported", Boolean)
	Attribute("canWithdraw", Boolean)
	Required("hasReported", "canWithdraw")
})

var _ = Service("moderation", func() {
	Method("add", func() {
		Security(JWTAuth, func() {
			Scope("api:access")
		})

		Payload(ModerationAddPayload)

		Result(ModerationRequest)

		HTTP(func() {
			POST("moderation")
			httpAuthentication()
		})
	})

	Method("cancel", func() {
		Description("Cancel a moderation request")
		Security(JWTAuth)

		Payload(func() {
			TokenField(1, "auth", String, "JWT token", func() {
				Pattern("^Bearer [^ ]+$")
			})
			Field(2, "postId", Int32, "Post ID")
			Field(3, "postType", String, "Post type")
			Required("auth", "postId", "postType")
		})

		Result(Empty)

		HTTP(func() {
			DELETE("/moderation/cancel")
			Param("postId")
			Param("postType")
			Response(StatusOK)
			Response(StatusNotFound)
			Response(StatusUnauthorized)
			Response(StatusForbidden)
		})
	})

	Method("checkUserReport", func() {
		Description("Check if user has reported a specific post")
		Security(JWTAuth)

		Payload(func() {
			TokenField(1, "auth", String, "JWT token", func() {
				Pattern("^Bearer [^ ]+$")
			})
			Field(2, "postId", Int32, "Post ID")
			Field(3, "postType", String, "Post type")
			Required("auth", "postId", "postType")
		})

		Result(CheckUserReportResult)

		HTTP(func() {
			GET("/moderation/check")
			Param("postId")
			Param("postType")
			Response(StatusOK)
			Response(StatusUnauthorized)
		})
	})

	Method("acknowledge", func() {
		Description("Acknowledge a moderation request with action")
		Security(JWTAuth)

		Payload(func() {
			TokenField(1, "auth", String, "JWT token", func() {
				Pattern("^Bearer [^ ]+$")
			})
			Field(2, "id", Int32, "Request ID")
			Field(3, "action", String, "Action to take (delete/keep)")
			Required("auth", "id", "action")
		})

		Result(ModerationRequest)

		HTTP(func() {
			POST("/moderation/requests/{id}/acknowledge")
			Param("action")
			Response(StatusOK)
			Response(StatusNotFound)
			Response(StatusUnauthorized)
			Response(StatusForbidden)
		})
	})

	Method("listRequests", func() {
		Description("List moderation requests")
		Security(JWTAuth)

		Payload(func() {
			TokenField(1, "auth", String, "JWT token", func() {
				Pattern("^Bearer [^ ]+$")
			})
			Field(2, "page", Int32, "Page number")
			Field(3, "pageSize", Int32, "Page size")
			Required("auth", "page", "pageSize")
		})

		Result(ModerationRequestsResponse)

		HTTP(func() {
			GET("/moderation/requests")
			Param("page")
			Param("pageSize")
			Response(StatusOK)
			Response(StatusUnauthorized)
			Response(StatusForbidden)
		})
	})

	Method("getContent", func() {
		Description("Get content for moderation review")
		Security(JWTAuth)

		Payload(func() {
			TokenField(1, "auth", String, "JWT token", func() {
				Pattern("^Bearer [^ ]+$")
			})
			Field(2, "postType", String, "Type of post")
			Field(3, "postId", Int32, "ID of the post")
			Required("auth", "postType", "postId")
		})

		Result(String)

		HTTP(func() {
			GET("/moderation/content/{postType}/{postId}")
			Response(StatusOK)
			Response(StatusNotFound)
			Response(StatusUnauthorized)
			Response(StatusForbidden)
		})
	})

	commonOptions()
})
