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
  -db="postgres://user:password@host:5432/fieldkit?sslmode=disable" \
  -station-id=1 \
  -interval=15m \
  -batch=10
```

### Chạy với Tất Cả Stations

```bash
./bin/hardware-sim \
  -api="http://fieldkit-staging-alb-1189893191.ap-southeast-1.elb.amazonaws.com" \
  -token="YOUR_JWT_TOKEN" \
  -db="postgres://user:password@host:5432/fieldkit?sslmode=disable" \
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
  -db="postgres://user:password@host:5432/fieldkit?sslmode=disable" \
  -station-id=0 \
  -interval=15m \
  -batch=10
```

## Chuyển Đổi Sang AWS Lambda Function

### Tổng Quan

Để chuyển đổi tool này từ Go application sang AWS Lambda function, chúng ta sẽ:
1. Tạo Lambda function với Go runtime
2. Sử dụng EventBridge (CloudWatch Events) để trigger theo schedule
3. Tích hợp với RDS (PostgreSQL) qua VPC
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
│ - VPC: Attach to same VPC as RDS                        │
└─────────────────────────────────────────────────────────┘
                    │
        ┌───────────┴───────────┐
        │                       │
        ▼                       ▼
┌───────────────┐    ┌──────────────────────┐
│ RDS PostgreSQL│    │ Secrets Manager      │
│ (VPC)         │    │ - DB credentials     │
│               │    │ - API token          │
└───────────────┘    └──────────────────────┘
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
    },
    {
      "Effect": "Allow",
      "Action": [
        "ec2:CreateNetworkInterface",
        "ec2:DescribeNetworkInterfaces",
        "ec2:DeleteNetworkInterface"
      ],
      "Resource": "*"
    }
  ]
}
```

### Bước 4: Tạo Secrets trong Secrets Manager

```bash
aws secretsmanager create-secret \
  --name fieldkit/hardware-sim \
  --secret-string '{
    "database_url": "postgres://user:password@rds-endpoint:5432/fieldkit?sslmode=disable",
    "api_token": "YOUR_JWT_TOKEN"
  }' \
  --region ap-southeast-1
```

**Lưu ý**: JWT token có thể được refresh tự động bằng cách:
- Tạo Lambda function riêng để refresh token
- Hoặc lưu user credentials và login mỗi lần chạy

### Bước 5: Deploy Lambda Function

```bash
# Tạo Lambda function
aws lambda create-function \
  --function-name fieldkit-hardware-sim \
  --runtime provided.al2 \
  --role arn:aws:iam::ACCOUNT_ID:role/lambda-execution-role \
  --handler bootstrap \
  --zip-file fileb://hardware-sim-lambda.zip \
  --timeout 300 \
  --memory-size 512 \
  --vpc-config SubnetIds=subnet-xxx,subnet-yyy,SecurityGroupIds=sg-xxx \
  --environment Variables='{
    "API_URL":"http://fieldkit-staging-alb-1189893191.ap-southeast-1.elb.amazonaws.com",
    "SECRETS_NAME":"fieldkit/hardware-sim"
  }' \
  --region ap-southeast-1
```

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

#### Option 1: Gọi Trực Tiếp ALB

Lambda function gọi trực tiếp đến ALB endpoint:
- **Pros**: Đơn giản, không cần thay đổi server
- **Cons**: Cần public ALB hoặc VPC endpoint

#### Option 2: Tích Hợp Qua API Gateway

Tạo API Gateway endpoint và tích hợp với server:
- **Pros**: Có thể thêm authentication, rate limiting
- **Cons**: Phức tạp hơn, cần cấu hình API Gateway

#### Option 3: Sử Dụng VPC Endpoint

Tạo VPC endpoint để Lambda access ALB trong VPC:
- **Pros**: Secure, không cần public ALB
- **Cons**: Cần VPC endpoint (chi phí)

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
- [ ] Cấu hình VPC (nếu cần access RDS)
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

### VPC Connection Issues

- Kiểm tra security groups
- Kiểm tra subnet configuration
- Kiểm tra NAT Gateway (nếu cần internet access)

### Secrets Manager Access

- Kiểm tra IAM permissions
- Kiểm tra secret ARN
- Kiểm tra VPC endpoint (nếu dùng VPC)

### API Connection Issues

- Kiểm tra ALB security group
- Kiểm tra VPC routing
- Kiểm tra NAT Gateway

## Kết Luận

Chuyển đổi Hardware Simulator từ Go application sang AWS Lambda function mang lại nhiều lợi ích:
- **Cost-effective**: Pay per use thay vì 24/7 server
- **Scalable**: Auto-scaling với demand
- **Reliable**: High availability với AWS infrastructure
- **Maintainable**: Fully managed service

Tuy nhiên, cần lưu ý:
- Lambda có timeout limit (15 minutes)
- VPC configuration phức tạp hơn
- Cold start latency (có thể dùng Provisioned Concurrency)

Với kiến trúc hiện tại của FieldKit trên AWS, việc tích hợp Lambda function sẽ seamless và không cần thay đổi server code.

