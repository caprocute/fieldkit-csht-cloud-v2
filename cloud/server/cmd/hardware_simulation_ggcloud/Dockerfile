# Build stage
FROM golang:1.22-alpine AS builder
WORKDIR /build

# Copy go mod files from server root
COPY go.mod go.sum ./

# Copy all required server packages
COPY backend ./backend
COPY common ./common
COPY data ./data
COPY files ./files

# Download dependencies
RUN go mod download

# Copy source code
COPY cmd/hardware_simulation_ggcloud/src ./src

# Build binary
WORKDIR /build/src
RUN CGO_ENABLED=0 GOOS=linux go build -o /hardware-sim .

# Runtime stage
FROM gcr.io/distroless/static-debian12:latest
WORKDIR /app
COPY --from=builder /hardware-sim /app/hardware-sim
USER nonroot:nonroot
ENTRYPOINT ["/app/hardware-sim"]
