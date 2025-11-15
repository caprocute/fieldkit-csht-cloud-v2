GOARCH ?= amd64
GOOS ?= linux
GO ?= env GOOS=$(GOOS) GOARCH=$(GOARCH) go
BUILD ?= $(abspath build)
BINARY ?= fkc

all: $(BUILD)/$(BINARY)

ci: all

$(BUILD)/$(BINARY): cmd/*.go *.go
	go build -o $(BUILD)/$(BINARY) cmd/*.go

clean:
	rm -rf $(BUILD)

rebuild:
	go get github.com/fieldkit/app-protocol

.PHONY: all clean
