# Hardware Simulation Tool

Tài liệu mô tả tool giả lập Hardware trong `cloud/server/cmd/hardware_sim/` - công cụ mô phỏng các FieldKit stations gửi dữ liệu sensor lên server theo chu kỳ.

## Tổng Quan

Hardware Simulator là một Go application mô phỏng hành vi của FieldKit hardware stations, tự động tạo và gửi dữ liệu sensor readings lên server thông qua ingestion API. Tool này hữu ích cho:
- Testing và development
- Demo và presentation
- Load testing
- Data generation cho testing

## Thông Tin Server

### API Endpoint
```
http://fieldkit-staging-alb-1189893191.ap-southeast-1.elb.amazonaws.com/
```

### Database Connection (Public Endpoint)
```
postgres://user:password@fieldkit-staging-postgres-nlb-2e92e35ac371a189.elb.ap-southeast-1.amazonaws.com:5432/fieldkit?sslmode=disable
```

**Lưu ý**: Database được expose qua Network Load Balancer (NLB) public endpoint. Thay thế `user:password` bằng credentials thực tế.

### Credentials
- **User**: `floodnet@test.local`
- **Password**: `test123456` (mặc định của user floodnet@test.local trong project)

### Lấy JWT Token

```bash
curl -X POST 'http://fieldkit-staging-alb-1189893191.ap-southeast-1.elb.amazonaws.com/user/login' \
  -H 'Content-Type: application/json' \
  -d '{"email":"floodnet@test.local","password":"test123456"}'
```

Response sẽ chứa JWT token trong field `token`.

## Luồng Chạy Chi Tiết

### 1. Khởi Tạo (Initialization)

```
┌─────────────────────────────────────────────────────────┐
│ 1. Parse Command Line Arguments                          │
│    - api: API base URL                                  │
│    - token: JWT token (required)                        │
│    - db: PostgreSQL connection URL (required)           │
│    - station-id: Station ID (0 = all stations)           │
│    - interval: Upload interval (default: 15m)           │
│    - batch: Readings per batch (default: 10)            │
└─────────────────────────────────────────────────────────┘
                    │
                    ▼
┌─────────────────────────────────────────────────────────┐
│ 2. Normalize API URL                                    │
│    - Remove path và query string                        │
│    - Keep only scheme + host + port                     │
└─────────────────────────────────────────────────────────┘
                    │
                    ▼
┌─────────────────────────────────────────────────────────┐
│ 3. Connect to Database                                  │
│    - Open PostgreSQL connection                         │
│    - Initialize repositories                            │
└─────────────────────────────────────────────────────────┘
                    │
                    ▼
┌─────────────────────────────────────────────────────────┐
│ 4. Load Station Information                             │
│    IF station-id > 0:                                   │
│      - Load single station by ID                        │
│    ELSE:                                                │
│      - Query all stations from DB                       │
│      - Filter: hidden IS FALSE OR NULL                  │
│    FOR EACH station:                                    │
│      - Load Provision (generation ID)                   │
│      - Load StationConfiguration                        │
│      - Load MetaRecord (meta number)                    │
│      - Load Location (GPS coordinates)                 │
└─────────────────────────────────────────────────────────┘
```

### 2. Khởi Tạo Simulator Cho Mỗi Station

```
┌─────────────────────────────────────────────────────────┐
│ FOR EACH Station:                                       │
│   1. Create HardwareSimulator instance                  │
│      - APIURL: Normalized API URL                       │
│      - Token: JWT token                                 │
│      - StationInfo: Loaded station data                │
│      - Client: HTTP client với 30s timeout             │
│      - ReadingNum: 1 (bắt đầu từ reading 1)            │
│      - LastUpload: Current time                         │
│                                                          │
│   2. Initialize Simulator                               │
│      - Check và upload meta nếu cần                     │
│                                                          │
│   3. Start Upload Loop (Goroutine)                      │
│      - Upload immediately (first batch)                 │
│      - Setup ticker với interval                        │
│      - Loop:                                            │
│        * Wait for ticker                                │
│        * Generate và upload batch                       │
│        * Handle signals (SIGINT, SIGTERM)               │
└─────────────────────────────────────────────────────────┘
```

### 3. Generate Readings

```
┌─────────────────────────────────────────────────────────┐
│ generateReadings(count)                                 │
│                                                          │
│ FOR i = 0 to count:                                     │
│   1. Calculate Record Time                              │
│      - Base: Current time (GMT+7)                       │
│      - Offset: i seconds (mỗi reading cách nhau 1s)     │
│                                                          │
│   2. Generate Random Seed                               │
│      - Based on: station ID + timestamp + reading num   │
│      - Đảm bảo mỗi station có dữ liệu khác nhau        │
│                                                          │
│   3. Get Base Location                                  │
│      - From station.Location (nếu có)                   │
│      - Default: Hanoi (105.8412, 21.0285)              │
│                                                          │
│   4. Calculate Base Values                              │
│      - Base depth: 8.0 + stationOffset                  │
│      - Base battery: 70.0 + stationOffset*2            │
│      - Base humidity: 50.0 + stationOffset*3            │
│      - Base pressure: 101.3 + stationOffset*0.1        │
│      - Base temp: 20.0 + stationOffset*1.5             │
│                                                          │
│   5. Simulate Tidal Variation                           │
│      - Tide variation: sin wave theo giờ                │
│      - Minute variation: sin wave theo phút             │
│      - Depth = baseDepth + tideVariation + random       │
│                                                          │
│   6. Generate Sensor Values                             │
│      Sensor 0: depth (calibrated)                       │
│        - Value: depthInches                             │
│        - Flood events: 5% chance (+8-12 inches)         │
│                                                          │
│      Sensor 1: depthUnfiltered (uncalibrated)           │
│        - Value: depth + noise (±1.5 inches)            │
│                                                          │
│      Sensor 2: distance (uncalibrated)                  │
│        - Value: depth * 25.4mm + noise (±5mm)           │
│                                                          │
│      Sensor 3: battery (calibrated)                     │
│        - Value: baseBattery - drain + noise             │
│        - Drain: 0.1% per 100 readings                  │
│                                                          │
│      Sensor 4: tideFeet (calibrated)                    │
│        - Value: tideBase / 12.0 + noise                 │
│                                                          │
│      Sensor 5: humidity (uncalibrated)                  │
│        - Value: baseHumidity + hourVariation + noise    │
│                                                          │
│      Sensor 6: pressure (uncalibrated)                  │
│        - Value: basePressure + noise (±1.5 kPa)        │
│                                                          │
│      Sensor 7: altitude (uncalibrated)                 │
│        - Value: altitude + noise (±2m)                  │
│                                                          │
│      Sensor 8: temperature (uncalibrated)              │
│        - Value: baseTemp + hourVariation + noise        │
│                                                          │
│      Sensor 9: sdError (uncalibrated)                   │
│        - Value: 0 (normal) hoặc 1-3 (error)             │
│        - Error chance: 2%                               │
│                                                          │
│   7. Create DataRecord                                  │
│      - Time: Unix timestamp                             │
│      - Reading: ReadingNum (increment)                  │
│      - Meta: MetaRecord.Number (từ DB)                  │
│      - Location: GPS coordinates với variation          │
│      - SensorGroups: Array of sensor readings           │
│                                                          │
│   8. Increment ReadingNum                               │
└─────────────────────────────────────────────────────────┘
```

### 4. Upload Batch

```
┌─────────────────────────────────────────────────────────┐
│ uploadBatch(batchSize)                                  │
│                                                          │
│ 1. Generate Readings                                    │
│    - Call generateReadings(batchSize)                    │
│    - Lock mutex để thread-safe                         │
│                                                          │
│ 2. Log JSON của từng Reading                            │
│    - Format: Station info + sensor data                 │
│    - Time: GMT+7 format                                 │
│    - Location: lat/long/alt                            │
│    - Sensors: Array với values                         │
│                                                          │
│ 3. Encode Readings                                      │
│    - Use Protocol Buffers                               │
│    - Encode each DataRecord                             │
│    - Combine into single binary buffer                  │
│                                                          │
│ 4. Upload to Ingestion API                              │
│    - Endpoint: {APIURL}/ingestion                        │
│    - Method: POST                                       │
│    - Headers:                                           │
│      * Authorization: Bearer {token}                    │
│      * Content-Type: application/x-fieldkit-data        │
│      * Content-Length: {size}                          │
│      * Fk-DeviceId: {hex device ID}                     │
│      * Fk-Generation: {hex generation ID}              │
│      * Fk-Type: "data"                                 │
│      * Fk-Blocks: "1,{readingNum}"                      │
│    - Body: Binary protobuf data                         │
│                                                          │
│ 5. Handle Response                                      │
│    - Parse JSON response                                │
│    - Extract Ingestion ID                               │
│    - Log success với timing info                        │
│                                                          │
│ 6. Update State                                         │
│    - Update LastUpload time                             │
│    - Increment ReadingNum                               │
└─────────────────────────────────────────────────────────┘
```

### 5. Upload Ingestion API Call

```
┌─────────────────────────────────────────────────────────┐
│ uploadIngestion(dataType, data)                        │
│                                                          │
│ 1. Build Request                                        │
│    - URL: {APIURL}/ingestion                            │
│    - Method: POST                                       │
│    - Body: Binary data (protobuf encoded)              │
│                                                          │
│ 2. Set Headers                                          │
│    - Authorization: Bearer {JWT token}                  │
│    - Content-Type: application/x-fieldkit-data         │
│    - Content-Length: {data length}                      │
│    - Fk-DeviceId: Hex encoded device ID                │
│    - Fk-Generation: Hex encoded generation ID          │
│    - Fk-Type: "data" hoặc "meta"                       │
│    - Fk-Blocks: "1,{readingNum}" hoặc "1,1" (meta)    │
│                                                          │
│ 3. Send HTTP Request                                    │
│    - Timeout: 30 seconds                                │
│    - Handle errors                                      │
│                                                          │
│ 4. Parse Response                                       │
│    - Status 200: Success                                │
│    - Parse JSON: {id, upload_id}                        │
│    - Status != 200: Error với body message             │
└─────────────────────────────────────────────────────────┘
```

## Cấu Trúc Code

### Main Components

1. **HardwareSimulator Struct**
   ```go
   type HardwareSimulator struct {
       APIURL      string        // API base URL
       Token       string        // JWT token
       StationInfo *StationInfo  // Station metadata
       Client      *http.Client  // HTTP client
       ReadingNum  uint64        // Current reading number
       LastUpload  time.Time     // Last upload timestamp
       mu          sync.Mutex    // Mutex for thread safety
   }
   ```

2. **StationInfo Struct**
   ```go
   type StationInfo struct {
       Station       *data.Station
       Provision     *data.Provision
       MetaRecord    *data.MetaRecord
       Configuration *data.StationConfiguration
       Location      *data.Location
   }
   ```

### Key Functions

- `main()`: Entry point, parse flags, load stations, start simulators
- `loadStationInfo()`: Load station metadata from database
- `initialize()`: Initialize simulator (upload meta if needed)
- `uploadBatch()`: Generate và upload batch of readings
- `generateReadings()`: Generate sensor readings với realistic values
- `uploadIngestion()`: Upload data to ingestion API
- `normalizeAPIURL()`: Normalize API URL format

## Cấu Trúc Bản Tin và Validation

### Cấu Trúc DataRecord (Protocol Buffers)

Bản tin được encode bằng Protocol Buffers với cấu trúc sau:

```protobuf
DataRecord {
  Readings {
    Time: int64              // Unix timestamp (seconds)
    Reading: uint64          // Reading number (bắt đầu từ 1, tăng dần)
    Meta: uint64             // Meta record number (PHẢI tồn tại trong DB)
    Flags: uint32            // Flags (thường là 0)
    Location {
      Fix: uint32            // GPS fix status (1 = fixed)
      Time: int64            // GPS timestamp
      Longitude: float32     // GPS longitude
      Latitude: float32      // GPS latitude
      Altitude: float32      // GPS altitude (meters)
      Satellites: uint32     // Number of satellites (6-9)
    }
    SensorGroups [
      {
        Module: uint32        // Module ID (0 = main module)
        Time: int64          // Sensor group timestamp
        Readings [
          {
            Sensor: uint32   // Sensor ID (0-9)
            Calibrated: float32  // Calibrated value (nếu có)
            Uncalibrated: float32 // Uncalibrated value (nếu có)
          }
        ]
      }
    ]
  }
}
```

### Headers Bắt Buộc Khi Upload

Khi gửi bản tin lên `/ingestion` endpoint, **PHẢI** có các headers sau:

| Header | Giá Trị | Mô Tả | Ví Dụ |
|--------|---------|-------|-------|
| `Authorization` | `Bearer {JWT_TOKEN}` | JWT token từ login | `Bearer eyJhbGc...` |
| `Content-Type` | `application/vnd.fk.data+binary` | Content type cho binary data | `application/vnd.fk.data+binary` |
| `Content-Length` | `{size}` | Size của body (bytes) | `1024` |
| `Fk-DeviceId` | `{hex}` | Device ID (hex encoded) | `a1b2c3d4...` |
| `Fk-Generation` | `{hex}` | Generation ID (hex encoded) | `e5f6g7h8...` |
| `Fk-Type` | `data` hoặc `meta` | Loại ingestion | `data` |
| `Fk-Blocks` | `1,{readingNum}` | Block range | `1,10` (cho data) hoặc `1,1` (cho meta) |

**Lưu ý quan trọng:**
- `Fk-DeviceId` và `Fk-Generation` phải match với `station.device_id` và `provision.generation` trong database
- `Fk-Blocks` cho data: `"1,{reading_number}"` (ví dụ: `"1,10"` nếu reading number là 10)
- `Fk-Blocks` cho meta: `"1,1"` (luôn là block đầu tiên)

### Cách Tạo Bản Tin Đúng Chuẩn

#### 1. Đảm Bảo Meta Record Tồn Tại

**QUAN TRỌNG**: Mỗi data record phải reference đến một meta record đã tồn tại trong database.

```go
// ✅ ĐÚNG: Lấy meta record number từ database
metaRecordNumber := uint64(s.StationInfo.MetaRecord.Number)
reading := &pb.DataRecord{
    Readings: &pb.Readings{
        Meta: metaRecordNumber, // Sử dụng số từ DB
        Reading: s.ReadingNum,
        // ...
    },
}

// ❌ SAI: Hardcode meta number
reading := &pb.DataRecord{
    Readings: &pb.Readings{
        Meta: 1, // SAI - có thể không tồn tại
        // ...
    },
}
```

**Kiểm tra meta record:**
```sql
-- Kiểm tra meta record có tồn tại không
SELECT id, number, provision_id 
FROM fieldkit.meta_record 
WHERE provision_id = (
    SELECT id FROM fieldkit.provision 
    WHERE device_id = '\x...' AND generation = '\x...'
)
ORDER BY number DESC 
LIMIT 1;
```

#### 2. Đảm Bảo Device ID và Generation Đúng

```go
// ✅ ĐÚNG: Lấy từ database
deviceID := s.StationInfo.Station.DeviceID
generationID := s.StationInfo.Provision.GenerationID

// Encode thành hex cho header
req.Header.Set("Fk-DeviceId", hex.EncodeToString(deviceID))
req.Header.Set("Fk-Generation", hex.EncodeToString(generationID))
```

**Kiểm tra trong database:**
```sql
-- Kiểm tra station và provision
SELECT 
    s.id AS station_id,
    s.device_id,
    p.generation,
    p.id AS provision_id
FROM fieldkit.station s
JOIN fieldkit.provision p ON (p.device_id = s.device_id)
WHERE s.id = {station_id};
```

#### 3. Đảm Bảo Sensor IDs Đúng

Sensors phải match với module meta trong database. Với FloodNet:
- Module: `manufacturer=0, kind=0`
- Sensors: 0-9 (10 sensors)

```go
// ✅ ĐÚNG: Sử dụng sensor IDs từ 0-9
SensorGroups: []*pb.SensorGroup{
    {
        Module: 0, // Main module
        Readings: []*pb.SensorAndValue{
            {Sensor: 0, Calibrated: &pb.SensorAndValue_CalibratedValue{...}},   // depth
            {Sensor: 1, Uncalibrated: &pb.SensorAndValue_UncalibratedValue{...}}, // depthUnfiltered
            {Sensor: 2, Uncalibrated: &pb.SensorAndValue_UncalibratedValue{...}}, // distance
            {Sensor: 3, Calibrated: &pb.SensorAndValue_CalibratedValue{...}},   // battery
            {Sensor: 4, Calibrated: &pb.SensorAndValue_CalibratedValue{...}},   // tideFeet
            {Sensor: 5, Uncalibrated: &pb.SensorAndValue_UncalibratedValue{...}}, // humidity
            {Sensor: 6, Uncalibrated: &pb.SensorAndValue_UncalibratedValue{...}}, // pressure
            {Sensor: 7, Uncalibrated: &pb.SensorAndValue_UncalibratedValue{...}}, // altitude
            {Sensor: 8, Uncalibrated: &pb.SensorAndValue_UncalibratedValue{...}}, // temperature
            {Sensor: 9, Uncalibrated: &pb.SensorAndValue_UncalibratedValue{...}}, // sdError
        },
    },
}
```

**Kiểm tra sensors trong database:**
```sql
-- Kiểm tra sensors của station
SELECT 
    sm.id,
    sm.sensor_id,
    sm.module_id,
    m.manufacturer,
    m.kind
FROM fieldkit.station_module sm
JOIN fieldkit.module m ON (m.id = sm.module_id)
WHERE sm.station_id = {station_id}
ORDER BY sm.sensor_id;
```

#### 4. Đảm Bảo Reading Number Tăng Dần

```go
// ✅ ĐÚNG: Reading number tăng dần, không được reset
s.ReadingNum++ // Increment sau mỗi reading
reading := &pb.DataRecord{
    Readings: &pb.Readings{
        Reading: s.ReadingNum, // Số tăng dần
        // ...
    },
}
```

#### 5. Đảm Bảo Timestamp Hợp Lệ

```go
// ✅ ĐÚNG: Sử dụng Unix timestamp (seconds)
recordTime := time.Now().In(vietnamTZ)
reading := &pb.DataRecord{
    Readings: &pb.Readings{
        Time: int64(recordTime.Unix()), // Unix timestamp
        Location: &pb.DeviceLocation{
            Time: int64(recordTime.Unix()), // GPS time
            // ...
        },
    },
}
```

### Các Lỗi Thường Gặp và Cách Tránh

#### 1. Lỗi "meta-missing"

**Nguyên nhân:**
- Data record reference đến meta record number không tồn tại trong database
- Meta record chưa được upload trước khi upload data

**Cách tránh:**
```go
// ✅ ĐÚNG: Luôn lấy meta number từ database
metaRecordNumber := uint64(s.StationInfo.MetaRecord.Number)

// ❌ SAI: Hardcode hoặc dùng số không tồn tại
metaRecordNumber := 1 // Có thể không tồn tại
```

**Kiểm tra:**
```sql
-- Kiểm tra meta record có tồn tại không
SELECT COUNT(*) 
FROM fieldkit.meta_record 
WHERE provision_id = {provision_id} 
  AND number = {meta_number};
```

#### 2. Lỗi "missing-station"

**Nguyên nhân:**
- Device ID trong header không match với station trong database
- Station chưa được tạo

**Cách tránh:**
```go
// ✅ ĐÚNG: Sử dụng device_id từ database
deviceID := s.StationInfo.Station.DeviceID
req.Header.Set("Fk-DeviceId", hex.EncodeToString(deviceID))
```

**Kiểm tra:**
```sql
-- Kiểm tra station có tồn tại không
SELECT id, name, device_id 
FROM fieldkit.station 
WHERE device_id = '\x{device_id_hex}';
```

#### 3. Lỗi "missing-provision"

**Nguyên nhân:**
- Generation ID không match với provision trong database
- Provision chưa được tạo (thường do meta chưa được upload)

**Cách tránh:**
```go
// ✅ ĐÚNG: Sử dụng generation từ database
generationID := s.StationInfo.Provision.GenerationID
req.Header.Set("Fk-Generation", hex.EncodeToString(generationID))
```

**Kiểm tra:**
```sql
-- Kiểm tra provision có tồn tại không
SELECT id, generation 
FROM fieldkit.provision 
WHERE device_id = '\x{device_id}' 
  AND generation = '\x{generation_id}';
```

#### 4. Lỗi "MalformedMetaError" hoặc "MissingSensorMetaError"

**Nguyên nhân:**
- Meta record thiếu thông tin (identity, header, sensors)
- Sensor IDs trong data không match với sensors trong meta

**Cách tránh:**
- Đảm bảo meta record đã được upload đầy đủ trước khi upload data
- Sử dụng đúng sensor IDs từ module meta

**Kiểm tra:**
```sql
-- Kiểm tra meta record có đầy đủ thông tin không
SELECT 
    mr.id,
    mr.number,
    mr.provision_id,
    sc.id AS config_id
FROM fieldkit.meta_record mr
LEFT JOIN fieldkit.station_configuration sc ON (sc.meta_record_id = mr.id)
WHERE mr.provision_id = {provision_id}
ORDER BY mr.number DESC
LIMIT 1;
```

## Cách Kiểm Tra Bản Tin Được Xử Lý Thành Công

### 1. Kiểm Tra Ingestion Queue

Sau khi upload, kiểm tra bảng `ingestion_queue` để xem ingestion có được xử lý thành công không:

```sql
-- Kiểm tra trạng thái ingestion
SELECT 
    iq.id AS queue_id,
    iq.ingestion_id,
    i.type,
    i.device_id,
    iq.queued,
    iq.attempted,
    iq.completed,
    iq.total_records,
    iq.other_errors,
    iq.meta_errors,
    iq.data_errors,
    CASE 
        WHEN iq.completed IS NULL THEN '⏳ Pending'
        WHEN iq.total_records > 0 AND iq.other_errors = 0 THEN '✅ Success'
        WHEN iq.other_errors = 1 THEN '❌ Error'
        ELSE '⚠️ Warning'
    END AS status
FROM fieldkit.ingestion_queue iq
JOIN fieldkit.ingestion i ON (i.id = iq.ingestion_id)
WHERE i.device_id = '\x{device_id_hex}'
ORDER BY iq.id DESC
LIMIT 10;
```

**Trạng thái thành công:**
```
✅ Success:
- total_records > 0
- other_errors = 0
- meta_errors = 0 (hoặc NULL cho data ingestion)
- data_errors = 0 (hoặc NULL cho meta ingestion)
- completed IS NOT NULL
```

**Trạng thái lỗi:**
```
❌ Error:
- total_records IS NULL
- other_errors = 1
- completed IS NOT NULL
```

### 2. Kiểm Tra Data Records Đã Được Lưu

```sql
-- Kiểm tra data records đã được lưu
SELECT 
    dr.id,
    dr.number AS reading_number,
    dr.time,
    dr.meta_record_id,
    mr.number AS meta_number,
    COUNT(*) OVER () AS total_records
FROM fieldkit.data_record dr
JOIN fieldkit.meta_record mr ON (mr.id = dr.meta_record_id)
JOIN fieldkit.provision p ON (p.id = dr.provision_id)
WHERE p.device_id = '\x{device_id_hex}'
ORDER BY dr.number DESC
LIMIT 10;
```

### 3. Kiểm Tra Station Ingestion

```sql
-- Kiểm tra station_ingestion (được tạo khi ingestion thành công)
SELECT 
    si.id,
    si.station_id,
    si.data_ingestion_id,
    si.meta_ingestion_id,
    i.type,
    i.time AS ingestion_time
FROM fieldkit.station_ingestion si
JOIN fieldkit.ingestion i ON (i.id = si.data_ingestion_id OR i.id = si.meta_ingestion_id)
JOIN fieldkit.station s ON (s.id = si.station_id)
WHERE s.device_id = '\x{device_id_hex}'
ORDER BY si.id DESC
LIMIT 10;
```

### 4. Kiểm Tra Lỗi Chi Tiết

```sql
-- Kiểm tra ingestion có lỗi gì
SELECT 
    i.id AS ingestion_id,
    i.type,
    i.device_id,
    iq.total_records,
    iq.other_errors,
    iq.meta_errors,
    iq.data_errors,
    iq.completed,
    CASE 
        WHEN iq.other_errors = 1 THEN 'Other error (check logs)'
        WHEN iq.meta_errors > 0 THEN 'Meta errors'
        WHEN iq.data_errors > 0 THEN 'Data errors'
        ELSE 'OK'
    END AS error_type
FROM fieldkit.ingestion i
JOIN fieldkit.ingestion_queue iq ON (iq.ingestion_id = i.id)
WHERE i.device_id = '\x{device_id_hex}'
  AND iq.completed IS NOT NULL
  AND (iq.other_errors = 1 OR iq.meta_errors > 0 OR iq.data_errors > 0)
ORDER BY iq.completed DESC
LIMIT 10;
```

### 5. Script Kiểm Tra Tự Động

Tạo script để kiểm tra ingestion sau khi upload:

```bash
#!/bin/bash
# check_ingestion.sh

DEVICE_ID_HEX="$1"
DB_URL="$2"

if [ -z "$DEVICE_ID_HEX" ] || [ -z "$DB_URL" ]; then
    echo "Usage: $0 <device_id_hex> <db_url>"
    exit 1
fi

psql "$DB_URL" <<EOF
-- Kiểm tra ingestion mới nhất
SELECT 
    i.id AS ingestion_id,
    i.type,
    i.time AS uploaded_at,
    iq.queued,
    iq.completed,
    iq.total_records,
    iq.other_errors,
    iq.meta_errors,
    iq.data_errors,
    CASE 
        WHEN iq.completed IS NULL THEN '⏳ Pending'
        WHEN iq.total_records > 0 AND iq.other_errors = 0 THEN '✅ Success'
        WHEN iq.other_errors = 1 THEN '❌ Error'
        ELSE '⚠️ Warning'
    END AS status
FROM fieldkit.ingestion i
JOIN fieldkit.ingestion_queue iq ON (iq.ingestion_id = i.id)
WHERE i.device_id = decode('$DEVICE_ID_HEX', 'hex')
ORDER BY i.id DESC
LIMIT 5;
EOF
```

### 6. Kiểm Tra Từ Code

Sau khi upload, có thể kiểm tra response:

```go
type IngestionResponse struct {
    ID       int64  `json:"id"`        // Ingestion ID
    UploadID string `json:"upload_id"` // Upload ID
}

// Sau khi upload
ingestion, err := s.uploadIngestion("data", dataFile.Bytes())
if err != nil {
    log.Printf("❌ Upload failed: %v", err)
    return err
}

log.Printf("✅ Uploaded successfully: Ingestion ID=%d, UploadID=%s", 
    ingestion.ID, ingestion.UploadID)

// Sau đó có thể query database để kiểm tra status
```

### Checklist Trước Khi Upload

- [ ] **Meta record đã tồn tại**: Kiểm tra `meta_record` trong database
- [ ] **Device ID đúng**: Match với `station.device_id`
- [ ] **Generation ID đúng**: Match với `provision.generation`
- [ ] **Sensor IDs đúng**: Match với sensors trong module meta
- [ ] **Reading number tăng dần**: Không được reset hoặc duplicate
- [ ] **Timestamp hợp lệ**: Unix timestamp, không phải tương lai quá xa
- [ ] **Headers đầy đủ**: Tất cả headers bắt buộc đã được set
- [ ] **Content-Type đúng**: `application/vnd.fk.data+binary`
- [ ] **JWT token hợp lệ**: Token chưa expire

## Cách Sử Dụng

### Build Tool

```bash
cd cloud/server
go build -o bin/hardware-sim cmd/hardware_sim/hardware_sim.go
```

### Chạy với Single Station

```bash
./bin/hardware-sim \
  -api="http://fieldkit-staging-alb-1189893191.ap-southeast-1.elb.amazonaws.com" \
  -token="YOUR_JWT_TOKEN" \
  -db="postgres://user:password@fieldkit-staging-postgres-nlb-2e92e35ac371a189.elb.ap-southeast-1.amazonaws.com:5432/fieldkit?sslmode=disable" \
  -station-id=1 \
  -interval=15m \
  -batch=10
```

### Chạy với Tất Cả Stations

```bash
./bin/hardware-sim \
  -api="http://fieldkit-staging-alb-1189893191.ap-southeast-1.elb.amazonaws.com" \
  -token="YOUR_JWT_TOKEN" \
  -db="postgres://user:password@fieldkit-staging-postgres-nlb-2e92e35ac371a189.elb.ap-southeast-1.amazonaws.com:5432/fieldkit?sslmode=disable" \
  -station-id=0 \
  -interval=15m \
  -batch=10
```

### Lấy JWT Token Tự Động

```bash
# Lấy token
TOKEN=$(curl -s -X POST 'http://fieldkit-staging-alb-1189893191.ap-southeast-1.elb.amazonaws.com/user/login' \
  -H 'Content-Type: application/json' \
  -d '{"email":"floodnet@test.local","password":"test123456"}' \
  | jq -r '.token')

# Chạy simulator
./bin/hardware-sim \
  -api="http://fieldkit-staging-alb-1189893191.ap-southeast-1.elb.amazonaws.com" \
  -token="$TOKEN" \
  -db="postgres://user:password@fieldkit-staging-postgres-nlb-2e92e35ac371a189.elb.ap-southeast-1.amazonaws.com:5432/fieldkit?sslmode=disable" \
  -station-id=0 \
  -interval=15m \
  -batch=10
```

## Chuyển Đổi Sang AWS Lambda Function

### Tổng Quan

Để chuyển đổi tool này từ Go application sang AWS Lambda function, chúng ta sẽ:
1. Tạo Lambda function với Go runtime
2. Sử dụng EventBridge (CloudWatch Events) để trigger theo schedule
3. Kết nối với PostgreSQL qua public NLB endpoint (không cần VPC)
4. Sử dụng Secrets Manager để lưu credentials
5. Tích hợp với API Gateway hoặc gọi trực tiếp ALB

### Kiến Trúc Lambda

```
┌─────────────────────────────────────────────────────────┐
│ EventBridge (CloudWatch Events)                         │
│ - Schedule: Every 15 minutes (hoặc configurable)      │
│ - Trigger Lambda function                               │
└─────────────────────────────────────────────────────────┘
                    │
                    ▼
┌─────────────────────────────────────────────────────────┐
│ AWS Lambda Function                                     │
│ - Runtime: Go 1.x                                       │
│ - Handler: main.Handler                                 │
│ - Timeout: 5 minutes                                    │
│ - Memory: 512 MB                                        │
│ - No VPC: Access database via public NLB endpoint      │
└─────────────────────────────────────────────────────────┘
                    │
        ┌───────────┴───────────┐
        │                       │
        ▼                       ▼
┌──────────────────────────────┐    ┌──────────────────────┐
│ PostgreSQL via Public NLB    │    │ Secrets Manager      │
│ fieldkit-staging-postgres-   │    │ - DB credentials     │
│ nlb-*.elb.amazonaws.com     │    │ - API token          │
│ Port: 5432                    │    └──────────────────────┘
└──────────────────────────────┘
        │
        ▼
┌─────────────────────────────────────────────────────────┐
│ Application Load Balancer                               │
│ - POST /ingestion                                       │
│ - Authentication: JWT token                             │
└─────────────────────────────────────────────────────────┘
```

### Bước 1: Tạo Lambda Function Code

Tạo file `lambda/hardware_sim_lambda/main.go`:

```go
package main

import (
	"context"
	"encoding/json"
	"fmt"
	"log"
	"os"
	"time"

	"github.com/aws/aws-lambda-go/events"
	"github.com/aws/aws-lambda-go/lambda"
	"github.com/aws/aws-sdk-go/aws"
	"github.com/aws/aws-sdk-go/aws/session"
	"github.com/aws/aws-sdk-go/service/secretsmanager"
	"github.com/aws/aws-sdk-go/service/rdsdataservice"
	
	"gitlab.com/fieldkit/cloud/server/common/sqlxcache"
	"gitlab.com/fieldkit/cloud/server/data"
	"gitlab.com/fieldkit/cloud/server/backend/repositories"
)

type LambdaHandler struct {
	secretsClient *secretsmanager.SecretsManager
	apiURL        string
}

type Secrets struct {
	DatabaseURL string `json:"database_url"`
	APIToken    string `json:"api_token"`
}

func (h *LambdaHandler) Handler(ctx context.Context, event events.CloudWatchEvent) error {
	log.Printf("Received event: %s", event.ID)
	
	// Get secrets from Secrets Manager
	secrets, err := h.getSecrets()
	if err != nil {
		return fmt.Errorf("failed to get secrets: %w", err)
	}
	
	// Connect to database
	db, err := sqlxcache.Open(ctx, "postgres", secrets.DatabaseURL)
	if err != nil {
		return fmt.Errorf("failed to connect to database: %w", err)
	}
	defer db.Close()
	
	// Load stations
	stations, err := h.loadStations(ctx, db)
	if err != nil {
		return fmt.Errorf("failed to load stations: %w", err)
	}
	
	// Process each station
	for _, station := range stations {
		if err := h.processStation(ctx, station, secrets.APIToken); err != nil {
			log.Printf("Error processing station %d: %v", station.ID, err)
			// Continue with other stations
		}
	}
	
	return nil
}

func (h *LambdaHandler) getSecrets() (*Secrets, error) {
	secretName := os.Getenv("SECRETS_NAME") // e.g., "fieldkit/hardware-sim"
	
	result, err := h.secretsClient.GetSecretValue(&secretsmanager.GetSecretValueInput{
		SecretId: aws.String(secretName),
	})
	if err != nil {
		return nil, err
	}
	
	var secrets Secrets
	if err := json.Unmarshal([]byte(*result.SecretString), &secrets); err != nil {
		return nil, err
	}
	
	return &secrets, nil
}

func (h *LambdaHandler) loadStations(ctx context.Context, db *sqlxcache.DB) ([]*data.Station, error) {
	// Query all non-hidden stations
	stations := []*data.Station{}
	err := db.SelectContext(ctx, &stations, `
		SELECT id, name, device_id, model_id, owner_id, created_at, updated_at, 
			battery, location_name, place_other, place_native, photo_id,
			recording_started_at, memory_used, memory_available, 
			firmware_number, firmware_time, ST_AsBinary(location) AS location, 
			hidden, description, status
		FROM fieldkit.station
		WHERE hidden IS FALSE OR hidden IS NULL
		ORDER BY id
	`)
	return stations, err
}

func (h *LambdaHandler) processStation(ctx context.Context, station *data.Station, token string) error {
	// Load station info (similar to original code)
	// Generate readings
	// Upload batch
	// Implementation similar to original HardwareSimulator
	return nil
}

func main() {
	sess := session.Must(session.NewSession())
	secretsClient := secretsmanager.New(sess)
	
	apiURL := os.Getenv("API_URL")
	if apiURL == "" {
		apiURL = "http://fieldkit-staging-alb-1189893191.ap-southeast-1.elb.amazonaws.com"
	}
	
	handler := &LambdaHandler{
		secretsClient: secretsClient,
		apiURL:        apiURL,
	}
	
	lambda.Start(handler.Handler)
}
```

### Bước 2: Build Lambda Function

```bash
# Tạo thư mục cho Lambda
mkdir -p lambda/hardware_sim_lambda

# Copy code vào thư mục
# (code đã được viết ở trên)

# Build cho Linux (Lambda runtime)
GOOS=linux GOARCH=amd64 go build -o bootstrap lambda/hardware_sim_lambda/main.go

# Zip binary
zip hardware-sim-lambda.zip bootstrap
```

### Bước 3: Tạo IAM Role cho Lambda

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "secretsmanager:GetSecretValue"
      ],
      "Resource": "arn:aws:secretsmanager:REGION:ACCOUNT_ID:secret:fieldkit/hardware-sim*"
    },
    {
      "Effect": "Allow",
      "Action": [
        "logs:CreateLogGroup",
        "logs:CreateLogStream",
        "logs:PutLogEvents"
      ],
      "Resource": "arn:aws:logs:*:*:*"
    }
  ]
}
```

**Lưu ý**: Không cần VPC-related permissions (ec2:CreateNetworkInterface, etc.) vì Lambda function không chạy trong VPC. Function sẽ access database và API qua public endpoints.

### Bước 4: Tạo Secrets trong Secrets Manager

```bash
aws secretsmanager create-secret \
  --name fieldkit/hardware-sim \
  --secret-string '{
    "database_url": "postgres://user:password@fieldkit-staging-postgres-nlb-2e92e35ac371a189.elb.ap-southeast-1.amazonaws.com:5432/fieldkit?sslmode=disable",
    "api_token": "YOUR_JWT_TOKEN"
  }' \
  --region ap-southeast-1
```

**Lưu ý**: 
- Database URL sử dụng public NLB endpoint, không cần VPC configuration
- JWT token có thể được refresh tự động bằng cách:
  - Tạo Lambda function riêng để refresh token
  - Hoặc lưu user credentials và login mỗi lần chạy

### Bước 5: Deploy Lambda Function

```bash
# Tạo Lambda function (không cần VPC vì dùng public endpoint)
aws lambda create-function \
  --function-name fieldkit-hardware-sim \
  --runtime provided.al2 \
  --role arn:aws:iam::ACCOUNT_ID:role/lambda-execution-role \
  --handler bootstrap \
  --zip-file fileb://hardware-sim-lambda.zip \
  --timeout 300 \
  --memory-size 512 \
  --environment Variables='{
    "API_URL":"http://fieldkit-staging-alb-1189893191.ap-southeast-1.elb.amazonaws.com",
    "SECRETS_NAME":"fieldkit/hardware-sim",
    "DB_HOST":"fieldkit-staging-postgres-nlb-2e92e35ac371a189.elb.ap-southeast-1.amazonaws.com",
    "DB_PORT":"5432",
    "DB_NAME":"fieldkit"
  }' \
  --region ap-southeast-1
```

**Lưu ý**: Không cần `--vpc-config` vì database được access qua public NLB endpoint. Lambda function sẽ chạy trong default VPC với internet access để connect đến database.

### Bước 6: Tạo EventBridge Rule

```bash
# Tạo rule để trigger mỗi 15 phút
aws events put-rule \
  --name fieldkit-hardware-sim-schedule \
  --schedule-expression "rate(15 minutes)" \
  --region ap-southeast-1

# Gắn Lambda function vào rule
aws events put-targets \
  --rule fieldkit-hardware-sim-schedule \
  --targets "Id"="1","Arn"="arn:aws:lambda:ap-southeast-1:ACCOUNT_ID:function:fieldkit-hardware-sim" \
  --region ap-southeast-1

# Cho phép EventBridge invoke Lambda
aws lambda add-permission \
  --function-name fieldkit-hardware-sim \
  --statement-id allow-eventbridge \
  --action lambda:InvokeFunction \
  --principal events.amazonaws.com \
  --source-arn arn:aws:events:ap-southeast-1:ACCOUNT_ID:rule/fieldkit-hardware-sim-schedule \
  --region ap-southeast-1
```

### Bước 7: Tích Hợp Với Server Hiện Tại

#### Option 1: Gọi Trực Tiếp ALB (Khuyến nghị)

Lambda function gọi trực tiếp đến ALB endpoint:
- **Pros**: Đơn giản, không cần thay đổi server, ALB đã public
- **Cons**: None (ALB đã được expose public)

#### Option 2: Tích Hợp Qua API Gateway

Tạo API Gateway endpoint và tích hợp với server:
- **Pros**: Có thể thêm authentication, rate limiting
- **Cons**: Phức tạp hơn, cần cấu hình API Gateway, không cần thiết vì ALB đã public

### Bước 8: Cải Thiện Lambda Function

#### Auto-Refresh JWT Token

Thay vì lưu JWT token (có thể expire), lưu user credentials và login mỗi lần:

```go
func (h *LambdaHandler) getAPIToken(ctx context.Context) (string, error) {
	secrets, err := h.getSecrets()
	if err != nil {
		return "", err
	}
	
	// Login để lấy token mới
	resp, err := http.Post(
		fmt.Sprintf("%s/user/login", h.apiURL),
		"application/json",
		strings.NewReader(fmt.Sprintf(`{"email":"%s","password":"%s"}`, 
			secrets.UserEmail, secrets.UserPassword)),
	)
	if err != nil {
		return "", err
	}
	defer resp.Body.Close()
	
	var result struct {
		Token string `json:"token"`
	}
	if err := json.NewDecoder(resp.Body).Decode(&result); err != nil {
		return "", err
	}
	
	return result.Token, nil
}
```

#### Batch Processing

Xử lý stations theo batch để tránh timeout:

```go
func (h *LambdaHandler) Handler(ctx context.Context, event events.CloudWatchEvent) error {
	// Get batch size from environment
	batchSize := 10
	if bs := os.Getenv("BATCH_SIZE"); bs != "" {
		batchSize, _ = strconv.Atoi(bs)
	}
	
	stations, err := h.loadStations(ctx, db)
	if err != nil {
		return err
	}
	
	// Process in batches
	for i := 0; i < len(stations); i += batchSize {
		end := i + batchSize
		if end > len(stations) {
			end = len(stations)
		}
		
		batch := stations[i:end]
		for _, station := range batch {
			// Process station
		}
	}
	
	return nil
}
```

#### Error Handling và Retry

Thêm retry logic cho failed uploads:

```go
func (h *LambdaHandler) uploadWithRetry(ctx context.Context, data []byte, maxRetries int) error {
	for i := 0; i < maxRetries; i++ {
		err := h.uploadIngestion(ctx, data)
		if err == nil {
			return nil
		}
		
		if i < maxRetries-1 {
			time.Sleep(time.Duration(i+1) * time.Second)
		}
	}
	return fmt.Errorf("failed after %d retries", maxRetries)
}
```

### Bước 9: Monitoring và Logging

#### CloudWatch Logs

Lambda tự động ghi logs vào CloudWatch Logs:
- Log group: `/aws/lambda/fieldkit-hardware-sim`
- Có thể tạo CloudWatch alarms cho errors

#### CloudWatch Metrics

Tạo custom metrics:
- Number of stations processed
- Number of readings uploaded
- Upload success/failure rate
- Execution duration

### Bước 10: Cost Optimization

1. **Reserved Concurrency**: Giới hạn concurrent executions
2. **Provisioned Concurrency**: Cho critical workloads
3. **Memory Optimization**: Tối ưu memory allocation
4. **Timeout Tuning**: Set timeout phù hợp

## So Sánh: Go Application vs Lambda

| Aspect | Go Application | AWS Lambda |
|--------|----------------|------------|
| **Deployment** | Manual hoặc CI/CD | Automated qua AWS |
| **Scaling** | Manual scaling | Auto-scaling |
| **Cost** | Server cost (24/7) | Pay per invocation |
| **Maintenance** | Server management | Fully managed |
| **Monitoring** | Custom logging | CloudWatch integration |
| **Reliability** | Depends on server | High availability |
| **Flexibility** | Full control | Lambda constraints |

## Migration Checklist

- [ ] Tạo Lambda function code
- [ ] Build và package Lambda function
- [ ] Tạo IAM role với đủ permissions
- [ ] Tạo secrets trong Secrets Manager
- [ ] Deploy Lambda function
- [ ] Test database connection từ Lambda (public NLB endpoint)
- [ ] Tạo EventBridge rule
- [ ] Test Lambda function manually
- [ ] Enable EventBridge schedule
- [ ] Setup CloudWatch alarms
- [ ] Monitor và optimize
- [ ] Document deployment process

## Troubleshooting

### Lambda Timeout

- Tăng timeout (max 15 minutes)
- Process stations in smaller batches
- Optimize database queries

### Database Connection Issues

- Kiểm tra NLB endpoint có accessible không
- Kiểm tra security group của NLB cho phép traffic từ internet
- Kiểm tra database credentials trong Secrets Manager
- Test connection từ local machine trước: `psql "postgres://user:password@fieldkit-staging-postgres-nlb-2e92e35ac371a189.elb.ap-southeast-1.amazonaws.com:5432/fieldkit?sslmode=disable"`

### Secrets Manager Access

- Kiểm tra IAM permissions
- Kiểm tra secret ARN
- Lambda function không cần VPC endpoint vì Secrets Manager có public endpoint

### API Connection Issues

- Kiểm tra ALB có accessible từ internet không
- Kiểm tra ALB security group cho phép traffic từ internet
- Test API endpoint từ local machine: `curl http://fieldkit-staging-alb-1189893191.ap-southeast-1.elb.amazonaws.com/status`

## Kết Luận

Chuyển đổi Hardware Simulator từ Go application sang AWS Lambda function mang lại nhiều lợi ích:
- **Cost-effective**: Pay per use thay vì 24/7 server
- **Scalable**: Auto-scaling với demand
- **Reliable**: High availability với AWS infrastructure
- **Maintainable**: Fully managed service

Tuy nhiên, cần lưu ý:
- Lambda có timeout limit (15 minutes)
- Database connection qua public endpoint (đảm bảo security group cho phép)
- Cold start latency (có thể dùng Provisioned Concurrency)
- Không cần VPC configuration vì dùng public endpoints cho cả database và API

Với kiến trúc hiện tại của FieldKit trên AWS, việc tích hợp Lambda function sẽ seamless và không cần thay đổi server code.

