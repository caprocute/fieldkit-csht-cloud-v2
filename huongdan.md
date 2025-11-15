# Hướng Dẫn Chạy Tools Gen Dữ Liệu Test - FieldKit

## Build Tools

```bash
cd cloud/server

# Build auto_seed
go build -o bin/auto_seed ./cmd/auto_seed

# Build api_client
go build -o bin/api_client ./cmd/api_client

# Build hardware_sim
go build -o bin/hardware_sim ./cmd/hardware_sim

# Build cleanup
go build -o bin/cleanup ./cmd/cleanup

# Build process_meta
go build -o bin/process_meta ./cmd/process_meta

# Build check_sensors
go build -o bin/check_sensors ./cmd/check_sensors

# Build fix_meta_processing
go build -o bin/fix_meta_processing ./cmd/fix_meta_processing
```

## 1. auto_seed - Tạo toàn bộ dữ liệu tự động

```bash
cd cloud/server

./bin/auto_seed \
  -api="http://fieldkit-staging-alb-1189893191.ap-southeast-1.elb.amazonaws.com" \
  -db="$FIELDKIT_POSTGRES_URL" \
  -stations=5 \
  -readings=1000 \
  -project="FloodNet NYC Monitoring" \
  -user="floodnet@test.local" \
  -name="FloodNet Test User" \
  -password="test123456"
```

**Flags**:
- `-api`: API base URL (required)
- `-db`: PostgreSQL connection URL (required)
- `-stations`: Số lượng stations (default: 5)
- `-readings`: Số lượng readings mỗi station (default: 1000)
- `-project`: Tên project (default: "FloodNet NYC Monitoring")
- `-user`: Email user (default: "floodnet@test.local")
- `-name`: Tên user (default: "FloodNet Test User")
- `-password`: Password user (default: "test123456")

## 2. api_client - Upload data qua API

```bash
cd cloud/server

# Sử dụng station có sẵn
./bin/api_client \
  -api="http://fieldkit-staging-alb-1189893191.ap-southeast-1.elb.amazonaws.com" \
  -token="$(cat .fieldkit_token)" \
  -station-id=1 \
  -readings=100

# Tạo station mới
./bin/api_client \
  -api="http://fieldkit-staging-alb-1189893191.ap-southeast-1.elb.amazonaws.com" \
  -token="$(cat .fieldkit_token)" \
  -device-id="a1b2c3d4e5f6..." \
  -readings=100

# Chạy liên tục
./bin/api_client \
  -api="http://fieldkit-staging-alb-1189893191.ap-southeast-1.elb.amazonaws.com" \
  -token="$(cat .fieldkit_token)" \
  -station-id=1 \
  -readings=10 \
  -interval=5m \
  -continuous=true
```

**Flags**:
- `-api`: API base URL (default: "http://localhost:8080")
- `-token`: JWT token (required)
- `-device-id`: Device ID hex string (auto-generated nếu empty)
- `-station-id`: Station ID có sẵn (0 để tạo mới)
- `-readings`: Số readings mỗi batch (default: 100)
- `-interval`: Interval giữa các uploads (default: 1m)
- `-continuous`: Chạy liên tục (default: false)

## 3. hardware_sim - Simulate hardware gửi data theo chu kỳ

```bash
cd cloud/server

# Chạy với default settings
./bin/hardware_sim \
  -api="http://fieldkit-staging-alb-1189893191.ap-southeast-1.elb.amazonaws.com" \
  -token="$(cat .fieldkit_token)" \
  -station="FloodNet Station 1" \
  -interval=5m \
  -batch=10

# Chạy với device ID cụ thể
./bin/hardware_sim \
  -api="http://fieldkit-staging-alb-1189893191.ap-southeast-1.elb.amazonaws.com" \
  -token="$(cat .fieldkit_token)" \
  -device-id="a1b2c3d4e5f6..." \
  -station="FloodNet Station 1" \
  -interval=1m \
  -batch=20
```

**Flags**:
- `-api`: API base URL (default: "http://localhost:8080")
- `-token`: JWT token (required)
- `-device-id`: Device ID hex string (auto-generated nếu empty)
- `-station`: Tên station (default: "FloodNet Simulator")
- `-interval`: Interval giữa các uploads (default: 5m)
- `-batch`: Số readings mỗi upload (default: 10)

## 4. process_meta - Trigger processing lại cho meta ingestions chưa được xử lý

Tool này dùng để trigger processing lại cho tất cả meta ingestions chưa được xử lý (tạo sensors).

```bash
cd cloud/server

# Chỉ liệt kê meta ingestions chưa được xử lý
./bin/process_meta \
  -db="$FIELDKIT_POSTGRES_URL"

# Trigger processing qua API
./bin/process_meta \
  -db="$FIELDKIT_POSTGRES_URL" \
  -api="http://fieldkit-staging-alb-1189893191.ap-southeast-1.elb.amazonaws.com" \
  -token="$(cat .fieldkit_token)"
```

**Flags**:
- `-db`: PostgreSQL connection URL (required)
- `-api`: API base URL (optional, required để trigger processing)
- `-token`: JWT token (required nếu dùng -api)

**Khi nào dùng**:
- Sau khi chạy `auto_seed` nhưng sensors chưa được tạo
- Khi `data_integrity` báo "thiếu configuration, thiếu module, thiếu sensor"
- Khi UI hiển thị "Oh snap, this station doesn't appear to have any sensors"

## 5. check_sensors - Kiểm tra sensors của stations

Tool này dùng để debug tại sao UI hiển thị "Oh snap, this station doesn't appear to have any sensors".

```bash
cd cloud/server

# Kiểm tra tất cả stations
./bin/check_sensors \
  -db="$FIELDKIT_POSTGRES_URL"

# Kiểm tra một station cụ thể
./bin/check_sensors \
  -db="$FIELDKIT_POSTGRES_URL" \
  -station=1
```

**Flags**:
- `-db`: PostgreSQL connection URL (required)
- `-station`: Station ID để kiểm tra (0 = kiểm tra tất cả, default: 0)

**Khi nào dùng**:
- Khi UI hiển thị "Oh snap, this station doesn't appear to have any sensors"
- Để kiểm tra xem station có `visible_configuration`, `station_module`, `module_sensor` không
- Để debug tại sao sensors không hiển thị trong UI

**Output**:
- Liệt kê tất cả sensors của station(s)
- Hiển thị `module_id`, `sensor_id`, `sensor_key`
- Cảnh báo nếu sensors không có `module_id` (sẽ không hiển thị trong UI)

## 6. fix_meta_processing - Fix meta processing cho các meta_record đã có

Tool này dùng để manually trigger handler `OnMeta` cho các `meta_record` đã có nhưng chưa có `station_configuration`.

```bash
cd cloud/server

# Fix tất cả stations
./bin/fix_meta_processing \
  -db="$FIELDKIT_POSTGRES_URL"

# Fix một station cụ thể
./bin/fix_meta_processing \
  -db="$FIELDKIT_POSTGRES_URL" \
  -station=51
```

**Flags**:
- `-db`: PostgreSQL connection URL (required)
- `-station`: Station ID để fix (0 = fix tất cả, default: 0)

**Khi nào dùng**:
- Sau khi chạy `auto_seed` nhưng sensors chưa được tạo
- Khi `check_sensors` báo "Meta ingestion chưa được xử lý"
- Khi có `meta_record` nhưng không có `station_configuration`

**Cách hoạt động**:
- Query các `meta_record` chưa có `station_configuration`
- Extract `metadata.modules` từ `meta_record.raw` JSON
- Tạo `pb.DataRecord` với `Modules` field từ `metadata.modules`
- Gọi handler `OnMeta` để tạo `station_configuration`, `station_module`, `module_sensor`
- Set `visible_configuration` cho station

## 7. cleanup - Xóa tất cả users và dữ liệu liên quan

**⚠️ CẢNH BÁO**: Tool này xóa TẤT CẢ users và dữ liệu liên quan!

```bash
cd cloud/server

./bin/cleanup \
  -db="postgres://fieldkit:password@host:5432/fieldkit?sslmode=disable" \
  -confirm=true
```

**Flags**:
- `-db`: PostgreSQL connection URL (required)
- `-confirm`: Phải set `true` để xác nhận xóa (required)

## Lấy JWT Token

```bash
# Login để lấy token
curl -X POST http://localhost:8080/user/login \
  -H "Content-Type: application/json" \
  -d '{"email":"floodnet@test.local","password":"test123456"}' \
  | jq -r '.token'

# Lưu token vào file
TOKEN=$(curl -s -X POST http://localhost:8080/user/login \
  -H "Content-Type: application/json" \
  -d '{"email":"floodnet@test.local","password":"test123456"}' \
  | jq -r '.token')
echo "$TOKEN" > .fieldkit_token
```
