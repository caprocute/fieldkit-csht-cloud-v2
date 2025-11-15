package design

import (
	. "goa.design/goa/v3/dsl"
)

var _ = Service("admin", func() {
	Method("health", func() {
		Security(JWTAuth, func() {
			Scope("api:admin")
		})

		Payload(func() {
			Token("auth")
			Required("auth")
		})

		Result(Health)

		HTTP(func() {
			GET("admin/health")

			httpAuthentication()
		})
	})

	Method("upload backup", func() {
		Security(JWTAuth, func() {
			Scope("api:admin")
		})

		Payload(func() {
			Token("auth")
			Required("auth")
			Attribute("contentLength", Int64)
			Required("contentLength")
			Attribute("contentType", String)
			Required("contentType")
		})

		Result(BackupCheck)

		HTTP(func() {
			POST("admin/backup")

			Header("contentType:Content-Type")
			Header("contentLength:Content-Length")

			SkipRequestBodyEncodeDecode()

			httpAuthentication()
		})
	})

	commonOptions()
})

var Health = ResultType("application/vnd.app.health+json", func() {
	TypeName("Health")
	Attributes(func() {
		Attribute("queue", QueueHealth)
		Required("queue")
	})
	View("default", func() {
		Attribute("queue")
	})
})

var BackupCheck = ResultType("application/vnd.app.backup.check+json", func() {
	TypeName("BackupCheck")
	Attributes(func() {
		Attribute("deviceName", String)
		Attribute("deviceId", String)
		Attribute("generationId", String)
		Attribute("records", ArrayOf(Int32))
		Attribute("errors", ArrayOf(String))
		Required("errors")
	})
	View("default", func() {
		Attribute("deviceName")
		Attribute("deviceId")
		Attribute("generationId")
		Attribute("records")
		Attribute("errors")
	})
})

var QueueHealth = Type("QueueHealth", func() {
	Attribute("pending", Int64)
	Attribute("errors", Int64)
	Required("pending", "errors")
})
