FROM golang:1.23-bookworm AS source

WORKDIR /work

COPY support/ /work/support
COPY cli/ /work/cli

RUN ls -alhR

WORKDIR /work/cli
RUN go get ./...
RUN go build -o migrate *.go

FROM ubuntu:22.04

COPY --from=source /work/cli/migrate /work/migrate

WORKDIR /work

ENTRYPOINT [ "/work/migrate" ]
