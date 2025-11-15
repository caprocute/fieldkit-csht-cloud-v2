FROM node:20.9.0 AS node
ENV PUBLIC_PATH /
WORKDIR /app

COPY ./portal/package*.json ./
RUN npm install

COPY ./portal/ ./
RUN npm run build

RUN for e in css csv html js json map svg txt; do find . -iname '*.$e' -exec gzip -k9 {} \; ; done

FROM golang:1.22-bookworm AS golang
WORKDIR /app

COPY ./migrations/ /app/migrations
COPY ./server/ /app/server

WORKDIR /app/server

RUN mkdir -p build
RUN ls -alh api
RUN mkdir -p api
RUN cd cmd/server && go build --ldflags '-linkmode external -extldflags "-static"' -o /app/server/build/server *.go
RUN cd cmd/ingester && go build --ldflags '-linkmode external -extldflags "-static"' -o /app/server/build/ingester *.go

FROM alpine:latest AS env
ARG GIT_HASH=missing
ARG VERSION=missing
WORKDIR /app

RUN echo "export GIT_HASH=$GIT_HASH" > static.env
RUN echo "export FIELDKIT_VERSION=$VERSION" >> static.env
RUN cat static.env

FROM scratch
COPY --from=golang /app/server/build/server /
COPY --from=golang /app/server/build/ingester /
COPY --from=node /app/build /portal
COPY --from=golang /etc/ssl/certs/ca-certificates.crt /etc/ssl/certs/
COPY --from=env /app/static.env /etc/
COPY --from=golang /app/server/api /api/

# Downstream Dockerfile's require this. I'd like to use the above paths, though.
COPY --from=golang /etc/ssl/certs/ca-certificates.crt /
COPY --from=env /app/static.env /

EXPOSE 80
ENTRYPOINT ["/server"]
