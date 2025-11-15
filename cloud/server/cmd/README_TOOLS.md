# FieldKit Test Data Tools

Bộ công cụ tự động để tạo và quản lý dữ liệu test cho hệ thống FieldKit.

## Cài Đặt

```bash
cd cloud/server

# Build tất cả tools
go build -o bin/seed cmd/seed/seed.go
go build -o bin/api-client cmd/api_client/api_client.go
go build -o bin/hardware-sim cmd/hardware_sim/hardware_sim.go
```

## 1. Database Seeder (`seed`)

Seed dữ liệu trực tiếp vào database.

### Usage

```bash
./bin/seed \
  -db="postgres://user:password@localhost:5432/fieldkit?sslmode=disable" \
  -stations=10 \
  -readings=5000
```

### Options

- `-db`: PostgreSQL connection URL (required)
- `-stations`: Số lượng stations (default: 5)
- `-readings`: Số readings mỗi station (default: 1000)
- `-project`: Tên project (default: "FloodNet NYC Monitoring")
- `-user`: Email user (default: "floodnet@test.local")
- `-name`: Tên user (default: "FloodNet Test User")
- `-password`: Password (default: "test123456")

## 2. API Client (`api-client`)

Thêm dữ liệu qua API.

### Usage - Single Upload

```bash
./bin/api-client \
  -api="http://localhost:8080" \
  -token="YOUR_JWT_TOKEN" \
  -readings=100
```

### Usage - Continuous Mode

```bash
./bin/api-client \
  -api="http://localhost:8080" \
  -token="YOUR_JWT_TOKEN" \
  -readings=10 \
  -interval=5m \
  -continuous
```

### Options

- `-api`: API base URL (default: "http://localhost:8080")
- `-token`: JWT token (required)
- `-device-id`: Device ID hex (auto-generated if empty)
- `-station-id`: Existing station ID (0 to create new)
- `-readings`: Readings per batch (default: 100)
- `-interval`: Interval between uploads (default: 1m)
- `-continuous`: Run continuously

## 3. Hardware Simulator (`hardware-sim`)

Mô phỏng hardware gửi dữ liệu theo chu kỳ.

### Usage

```bash
./bin/hardware-sim \
  -api="http://localhost:8080" \
  -token="YOUR_JWT_TOKEN" \
  -station="FloodNet Station 1" \
  -interval=5m \
  -batch=10
```

### Options

- `-api`: API base URL (default: "http://localhost:8080")
- `-token`: JWT token (required)
- `-device-id`: Device ID hex (auto-generated if empty)
- `-station`: Station name (default: "FloodNet Simulator")
- `-interval`: Upload interval (default: 5m)
- `-batch`: Readings per upload (default: 10)

## Quick Start

### 1. Seed Database

```bash
./bin/seed -db="postgres://user:pass@localhost/fieldkit"
```

### 2. Get JWT Token

```bash
TOKEN=$(curl -s -X POST http://localhost:8080/user/login \
  -H "Content-Type: application/json" \
  -d '{"email":"floodnet@test.local","password":"test123456"}' \
  | jq -r '.token')
```

### 3. Run Simulator

```bash
./bin/hardware-sim \
  -api="http://localhost:8080" \
  -token="$TOKEN" \
  -interval=5m \
  -batch=10
```

## Examples

### Simulate Multiple Devices

```bash
# Terminal 1
./bin/hardware-sim -token="$TOKEN" -station="Station-1" -interval=5m

# Terminal 2
./bin/hardware-sim -token="$TOKEN" -station="Station-2" -interval=3m

# Terminal 3
./bin/hardware-sim -token="$TOKEN" -station="Station-3" -interval=10m
```

### Continuous Data Upload

```bash
./bin/api-client \
  -token="$TOKEN" \
  -readings=50 \
  -interval=2m \
  -continuous
```

