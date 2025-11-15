package design

import (
	. "goa.design/goa/v3/dsl"
)

var _ = Service("test", func() {
	Method("noop", func() {
		HTTP(func() {
			GET("test/noop")
		})
	})

	Error("unauthorized", String, "credentials are invalid")

	HTTP(func() {
		Response("unauthorized", StatusUnauthorized)
	})

	commonOptions()
})
