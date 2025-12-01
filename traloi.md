# TRẢ LỜI CÁC CÂU HỎI VỀ CẤU HÌNH AWS

## 1. Cơ chế scale của các module khi triển khai trên Fargate

### Cấu hình hiện tại:
- **Desired Count**: Tất cả services đang được cấu hình với `desired-count: 1`
- **Auto-scaling**: Chưa được cấu hình trong scripts, nhưng có thể cấu hình qua ECS Console hoặc AWS CLI

### Cách cấu hình auto-scaling:
ECS Fargate hỗ trợ auto-scaling thông qua **Application Auto Scaling** với các metrics:
- CPU utilization
- Memory utilization  
- ALB request count per target
- Custom CloudWatch metrics

**Ví dụ cấu hình auto-scaling:**
```bash
# Tạo auto-scaling target
aws application-autoscaling register-scalable-target \
    --service-namespace ecs \
    --resource-id service/fieldkit-staging-app/fieldkit-staging-app-server \
    --scalable-dimension ecs:service:DesiredCount \
    --min-capacity 1 \
    --max-capacity 10

# Tạo scaling policy dựa trên CPU
aws application-autoscaling put-scaling-policy \
    --service-namespace ecs \
    --resource-id service/fieldkit-staging-app/fieldkit-staging-app-server \
    --scalable-dimension ecs:service:DesiredCount \
    --policy-name cpu-scaling-policy \
    --policy-type TargetTrackingScaling \
    --target-tracking-scaling-policy-configuration '{
        "TargetValue": 70.0,
        "PredefinedMetricSpecification": {
            "PredefinedMetricType": "ECSServiceAverageCPUUtilization"
        },
        "ScaleInCooldown": 300,
        "ScaleOutCooldown": 60
    }'
```

**Lưu ý**: Hiện tại hệ thống chưa có auto-scaling được cấu hình, tất cả services chạy với 1 task instance.

---

## 2. Bảng so sánh AWS vs Google Cloud

| AWS Service | Google Cloud Equivalent | Lý do chọn AWS |
|-------------|-------------------------|----------------|
| **ECS Fargate** | Cloud Run | Fargate tích hợp tốt với ECS ecosystem, hỗ trợ long-running tasks tốt hơn Cloud Run (có timeout limits) |
| **ECR** | Artifact Registry | ECR tích hợp native với ECS, không cần cấu hình thêm authentication |
| **Application Load Balancer (ALB)** | Cloud Load Balancing (HTTP(S)) | ALB có nhiều tính năng advanced routing, tích hợp tốt với ECS service discovery |
| **Network Load Balancer (NLB)** | Cloud Load Balancing (TCP/UDP) | NLB phù hợp cho database connections với low latency, high performance |
| **Secrets Manager** | Secret Manager | Tích hợp tốt với ECS task execution role, auto-rotation support |
| **CloudWatch Logs** | Cloud Logging | Tích hợp native với ECS, không cần cấu hình thêm logging drivers |
| **VPC** | Virtual Private Cloud (VPC) | AWS VPC có nhiều tính năng advanced networking, tích hợp tốt với các services khác |
| **IAM** | Cloud IAM | IAM có fine-grained permissions tốt hơn, tích hợp sâu với tất cả AWS services |
| **PostgreSQL trên Fargate** | Cloud SQL | Fargate cho phép custom PostgreSQL với TimescaleDB extension, linh hoạt hơn Cloud SQL |
| **TimescaleDB trên Fargate** | Cloud SQL (PostgreSQL) + TimescaleDB extension | Có thể cài TimescaleDB extension trên Cloud SQL, nhưng Fargate cho phép version control tốt hơn |

**Lý do tổng thể chọn AWS:**
- Ecosystem tích hợp tốt: Tất cả services tích hợp native với nhau
- Fargate phù hợp cho long-running database services (không có timeout như Cloud Run)
- IAM và networking mạnh mẽ hơn cho enterprise use cases
- Chi phí có thể tối ưu với Fargate Spot cho non-critical workloads
- Region ap-southeast-1 (Singapore) gần với khu vực Đông Nam Á

---

## 3. CloudWatch đang được set ngưỡng cảnh báo như nào

### Cấu hình hiện tại:
**CloudWatch Alarms chưa được cấu hình trong scripts**. Hệ thống chỉ sử dụng CloudWatch Logs để lưu trữ logs.

### Các metrics có thể monitor:
- **ECS Service Metrics**:
  - `CPUUtilization` - CPU usage của tasks
  - `MemoryUtilization` - Memory usage của tasks
  - `RunningTaskCount` - Số lượng tasks đang chạy
  - `DesiredTaskCount` - Số lượng tasks mong muốn

- **ALB Metrics**:
  - `TargetResponseTime` - Thời gian phản hồi
  - `HTTPCode_Target_2XX_Count` - Số request thành công
  - `HTTPCode_Target_4XX_Count` - Số request lỗi client
  - `HTTPCode_Target_5XX_Count` - Số request lỗi server
  - `HealthyHostCount` - Số healthy targets
  - `UnHealthyHostCount` - Số unhealthy targets

- **Database Metrics** (nếu có):
  - Connection count
  - Query performance
  - Storage usage

### Ví dụ cấu hình alarm:
```bash
# Alarm khi CPU > 80%
aws cloudwatch put-metric-alarm \
    --alarm-name fieldkit-server-high-cpu \
    --alarm-description "Alert when CPU exceeds 80%" \
    --metric-name CPUUtilization \
    --namespace AWS/ECS \
    --statistic Average \
    --period 300 \
    --threshold 80 \
    --comparison-operator GreaterThanThreshold \
    --evaluation-periods 2 \
    --dimensions Name=ServiceName,Value=fieldkit-staging-app-server Name=ClusterName,Value=fieldkit-staging-app

# Alarm khi có unhealthy targets
aws cloudwatch put-metric-alarm \
    --alarm-name fieldkit-server-unhealthy-targets \
    --alarm-description "Alert when unhealthy targets > 0" \
    --metric-name UnHealthyHostCount \
    --namespace AWS/ApplicationELB \
    --statistic Average \
    --period 60 \
    --threshold 0 \
    --comparison-operator GreaterThanThreshold \
    --evaluation-periods 1
```

**Lưu ý**: Hiện tại chưa có CloudWatch Alarms được cấu hình, cần setup thủ công hoặc qua Infrastructure as Code.

---

## 4. Server và DB đang được cấu hình bao nhiêu RAM, bao nhiêu CPU?

### Server Service (`fieldkit-server`):
- **CPU**: 512 (0.5 vCPU)
- **Memory**: 1024 MB (1 GB)

### Charting Service (`fieldkit-charting`):
- **CPU**: 256 (0.25 vCPU)
- **Memory**: 512 MB (0.5 GB)

### PostgreSQL Service (`fieldkit-postgres`):
- **CPU**: 512 (0.5 vCPU)
- **Memory**: 2048 MB (2 GB)

### TimescaleDB Service (`fieldkit-timescale`):
- **CPU**: 512 (0.5 vCPU)
- **Memory**: 2048 MB (2 GB)

### Tổng tài nguyên (khi tất cả services chạy):
- **Total CPU**: 1.75 vCPU (512 + 256 + 512 + 512)
- **Total Memory**: 6 GB (1024 + 512 + 2048 + 2048)

**Lưu ý**: 
- Fargate có giới hạn: CPU từ 0.25-16 vCPU, Memory từ 0.5-120 GB
- Tỷ lệ CPU/Memory phải tuân theo quy tắc của Fargate (ví dụ: 512 CPU có thể có 1-4 GB memory)

---

## 5. Có sử dụng cơ chế High Availability multiple zone không?

### Cấu hình hiện tại:
**Có hỗ trợ multi-AZ deployment**, nhưng **chưa được tận dụng đầy đủ** vì `desired-count: 1`.

### Chi tiết:

**A. Network Configuration:**
- Services được deploy với `subnets=[${SUBNET_IDS}]` - có thể chứa subnets từ nhiều Availability Zones
- Scripts yêu cầu ít nhất 2 subnets (có thể từ 2 AZs khác nhau)
- Network mode: `awsvpc` - mỗi task có network interface riêng

**B. High Availability:**
- **Hiện tại**: `desired-count: 1` → Chỉ có 1 task instance, không có HA thực sự
- **Để có HA**: Cần set `desired-count >= 2` và đảm bảo subnets nằm ở các AZs khác nhau

**C. Load Balancer:**
- **ALB**: Được cấu hình với multiple subnets (từ các AZs khác nhau) → Có HA
- **NLB**: Được cấu hình với multiple subnets → Có HA
- Load balancers tự động distribute traffic đến healthy targets ở các AZs

**D. Database:**
- PostgreSQL và TimescaleDB hiện tại chỉ có 1 instance (`desired-count: 1`)
- **Không có HA** cho database layer
- Để có HA database, cần:
  - Set `desired-count: 2` hoặc nhiều hơn
  - Sử dụng PostgreSQL streaming replication
  - Hoặc migrate sang RDS với Multi-AZ deployment

### Cách enable High Availability:

**1. Enable HA cho Application Services:**
```bash
# Update service với desired-count = 2
aws ecs update-service \
    --cluster fieldkit-staging-app \
    --service fieldkit-staging-app-server \
    --desired-count 2 \
    --region ap-southeast-1
```

**2. Đảm bảo subnets ở multiple AZs:**
```bash
# Kiểm tra subnets ở các AZs khác nhau
aws ec2 describe-subnets \
    --subnet-ids subnet-xxx,subnet-yyy \
    --query 'Subnets[*].[SubnetId,AvailabilityZone]' \
    --output table
```

**3. Enable HA cho Database (phức tạp hơn):**
- Cần setup PostgreSQL replication
- Hoặc migrate sang RDS với Multi-AZ
- Hoặc sử dụng managed database service

### Tóm tắt:
- ✅ **Network layer**: Có hỗ trợ multi-AZ (subnets có thể ở nhiều AZs)
- ✅ **Load Balancers**: Có HA (ALB/NLB deploy ở multiple AZs)
- ❌ **Application Services**: Chưa có HA (desired-count = 1)
- ❌ **Database Services**: Chưa có HA (desired-count = 1, không có replication)

**Khuyến nghị**: Để có HA đầy đủ, cần:
1. Tăng `desired-count` lên 2+ cho application services
2. Đảm bảo subnets nằm ở ít nhất 2 AZs khác nhau
3. Setup database replication hoặc migrate sang managed database service

---

## 6. Hướng dẫn sử dụng script stop-and-cleanup.sh

### Mục đích:
Script `stop-and-cleanup.sh` dùng để dừng và dọn dẹp các dịch vụ ECS để tránh phát sinh chi phí khi không sử dụng.

### Cú pháp:
```bash
./aws/stop-and-cleanup.sh [ENVIRONMENT] [OPTIONS]
```

### Tham số:
- **ENVIRONMENT** (optional): Môi trường cần cleanup (mặc định: `staging`)
  - Ví dụ: `staging`, `production`, `development`

### Options:
- **Không có option** (mặc định): Chỉ scale services về 0, giữ lại services và cluster
- **`--delete-services`**: Xóa services (nhưng giữ lại cluster)
- **`--delete-cluster`**: Xóa cluster (chỉ khi không còn services)
- **`--all`**: Xóa tất cả (services + cluster)

### Các cách sử dụng:

#### 1. Scale services về 0 (giữ lại services và cluster)
```bash
# Chạy với environment mặc định (staging)
./aws/stop-and-cleanup.sh

# Hoặc chỉ định environment
./aws/stop-and-cleanup.sh staging
```

**Hành động:**
- Scale `fieldkit-staging-app-server` về 0 tasks
- Scale `fieldkit-staging-app-charting` về 0 tasks
- Dừng tất cả running tasks
- **Giữ lại**: Services, Cluster, Task Definitions, Load Balancers

**Chi phí:**
- ✅ Không tốn chi phí cho ECS tasks
- ⚠️ Vẫn tốn chi phí cho ALB/NLB (nếu có)
- ⚠️ Vẫn tốn chi phí cho database services (nếu chạy)

**Khi nào dùng:**
- Tạm dừng trong thời gian ngắn (vài giờ/ngày)
- Muốn khởi động lại nhanh (không cần tạo lại services)

#### 2. Xóa services (giữ lại cluster)
```bash
./aws/stop-and-cleanup.sh staging --delete-services
```

**Hành động:**
- Scale services về 0
- Xóa `fieldkit-staging-app-server` service
- Xóa `fieldkit-staging-app-charting` service
- **Giữ lại**: Cluster, Task Definitions, Load Balancers

**Chi phí:**
- ✅ Không tốn chi phí cho services
- ✅ Không tốn chi phí cho ECS tasks
- ⚠️ Vẫn tốn chi phí cho ALB/NLB (nếu có)
- ⚠️ Vẫn tốn chi phí cho database services (nếu chạy)

**Khi nào dùng:**
- Không dùng trong thời gian trung bình (vài ngày/tuần)
- Muốn tiết kiệm chi phí nhưng giữ cluster để deploy nhanh hơn

#### 3. Xóa cluster (chỉ khi không còn services)
```bash
./aws/stop-and-cleanup.sh staging --delete-cluster
```

**Hành động:**
- Scale services về 0
- Xóa services (nếu còn)
- Xóa cluster `fieldkit-staging-app`
- **Lưu ý**: Chỉ xóa được cluster khi không còn services

**Chi phí:**
- ✅ Không tốn chi phí cho cluster
- ✅ Không tốn chi phí cho services
- ⚠️ Vẫn tốn chi phí cho ALB/NLB (nếu có)
- ⚠️ Vẫn tốn chi phí cho database services (nếu chạy)

**Khi nào dùng:**
- Không dùng trong thời gian dài
- Muốn cleanup hoàn toàn application cluster

#### 4. Xóa tất cả (services + cluster)
```bash
./aws/stop-and-cleanup.sh staging --all
```

**Hành động:**
- Scale services về 0
- Xóa tất cả services
- Xóa cluster
- **Tương đương**: `--delete-services --delete-cluster`

**Chi phí:**
- ✅ Không tốn chi phí cho cluster
- ✅ Không tốn chi phí cho services
- ⚠️ Vẫn tốn chi phí cho ALB/NLB (nếu có)
- ⚠️ Vẫn tốn chi phí cho database services (nếu chạy)

**Khi nào dùng:**
- Không dùng trong thời gian rất dài
- Muốn cleanup hoàn toàn để tiết kiệm chi phí tối đa

### Quy trình khởi động lại sau khi cleanup:

#### Nếu chỉ scale về 0:
```bash
# Chỉ cần deploy lại
./aws/deploy.sh latest staging
```

#### Nếu đã xóa services (`--delete-services` hoặc `--all`):
```bash
# 1. Tạo lại services
./aws/create-ecs-services.sh staging

# 2. Build và push images
./aws/build-and-push.sh latest staging

# 3. Deploy
./aws/deploy.sh latest staging
```

#### Nếu đã xóa cluster (`--all`):
```bash
# 1. Tạo lại cluster và services
./aws/create-ecs-services.sh staging

# 2. Setup load balancers (nếu cần)
./aws/setup-load-balancer.sh staging

# 3. Build và push images
./aws/build-and-push.sh latest staging

# 4. Deploy
./aws/deploy.sh latest staging
```

### Lưu ý quan trọng:

1. **Database services không bị ảnh hưởng**: Script này chỉ cleanup application cluster (`fieldkit-{ENV}-app`), không ảnh hưởng đến database cluster (`fieldkit-{ENV}-db-v1`)

2. **Load Balancers không bị xóa**: ALB và NLB không được xóa bởi script này, cần xóa thủ công nếu muốn

3. **Task Definitions không bị xóa**: Task definitions được giữ lại, có thể sử dụng lại khi deploy

4. **Secrets Manager không bị ảnh hưởng**: Secrets vẫn được giữ lại trong AWS Secrets Manager

5. **ECR Images không bị xóa**: Docker images trong ECR vẫn được giữ lại

### Ví dụ output:

```
==========================================
Stop and Cleanup ECS Services
==========================================
Environment: staging
Cluster: fieldkit-staging-app
Region: ap-southeast-1

Actions:
  - Scale services về 0: YES
  - Xóa services: NO
  - Xóa cluster: NO
==========================================

1. Stopping services và scaling về 0...
   Đang scale fieldkit-staging-app-server về 0...
   ✅ fieldkit-staging-app-server đã được scale về 0
   Đang chờ tasks dừng...
   ✅ fieldkit-staging-app-server đã được stop hoàn toàn
   Đang scale fieldkit-staging-app-charting về 0...
   ✅ fieldkit-staging-app-charting đã được scale về 0
   Đang chờ tasks dừng...
   ✅ fieldkit-staging-app-charting đã được stop hoàn toàn

==========================================
Cleanup hoàn tất!
==========================================

Tổng kết:
  - Services đã được scale về 0

Để khởi động lại:
  2. ./deployment/build-and-push.sh v1.0.0 staging
  3. ./deployment/deploy.sh v1.0.0 staging
==========================================
```

### Khuyến nghị sử dụng:

- **Tạm dừng ngắn hạn (< 1 ngày)**: Chỉ scale về 0 (không dùng option)
- **Tạm dừng trung bình (1-7 ngày)**: `--delete-services`
- **Tạm dừng dài hạn (> 1 tuần)**: `--all`

---

## 7. Script cleanup toàn bộ resources (cleanup-all.sh)

### Mục đích:
Script `cleanup-all.sh` dùng để xóa **TẤT CẢ** resources liên quan đến FieldKit deployment để không phát sinh bất kỳ chi phí nào.

### Cú pháp:
```bash
./aws/cleanup-all.sh [ENVIRONMENT] [OPTIONS]
```

### Tham số:
- **ENVIRONMENT** (optional): Môi trường cần cleanup (mặc định: `staging`)

### Options:
- **`--delete-ecr`**: Xóa ECR repositories (mặc định: giữ lại)
- **`--delete-secrets`**: Xóa Secrets Manager secrets (mặc định: giữ lại)
- **`--confirm`**: Bỏ qua confirmation prompt (nguy hiểm!)

### Resources sẽ bị xóa:

#### 1. Application Cluster và Services:
- Cluster: `fieldkit-{ENV}-app`
- Services: `fieldkit-{ENV}-app-server`, `fieldkit-{ENV}-app-charting`

#### 2. Database Cluster và Services:
- Cluster: `fieldkit-{ENV}-db-v1`
- Services: `fieldkit-{ENV}-db-v1-postgres`, `fieldkit-{ENV}-db-v1-timescale`

#### 3. Load Balancers:
- ALB: `fieldkit-{ENV}-server-alb`
- NLB: `fieldkit-{ENV}-postgres-nlb` (nếu có)
- NLB: `fieldkit-{ENV}-timescale-nlb` (nếu có)

#### 4. Target Groups:
- `fieldkit-{ENV}-server-tg`
- `fieldkit-{ENV}-postgres-tg` (nếu có)
- `fieldkit-{ENV}-timescale-tg` (nếu có)

#### 5. CloudWatch Log Groups:
- Tất cả log groups với prefix `/ecs/fieldkit-{ENV}*`

#### 6. ECR Repositories (optional):
- `fieldkit/server`
- `fieldkit/charting`
- `fieldkit/postgres`
- `fieldkit/timescale`

#### 7. Secrets Manager Secrets (optional):
- `fieldkit/{ENV}/database/postgres`
- `fieldkit/{ENV}/database/timescale`
- `fieldkit/{ENV}/session/key`

### Các cách sử dụng:

#### 1. Cleanup cơ bản (giữ lại ECR và Secrets):
```bash
./aws/cleanup-all.sh staging
```

**Hành động:**
- Xóa tất cả clusters, services, load balancers, target groups, log groups
- **Giữ lại**: ECR repositories, Secrets Manager secrets, IAM roles, VPC resources

**Chi phí:**
- ✅ Không tốn chi phí cho ECS
- ✅ Không tốn chi phí cho Load Balancers
- ✅ Không tốn chi phí cho CloudWatch Logs
- ⚠️ Vẫn tốn chi phí cho ECR storage (nếu có images)
- ⚠️ Vẫn tốn chi phí cho Secrets Manager (rất nhỏ)

**Khi nào dùng:**
- Muốn cleanup toàn bộ nhưng giữ lại images và secrets để deploy lại nhanh

#### 2. Cleanup hoàn toàn (bao gồm ECR):
```bash
./aws/cleanup-all.sh staging --delete-ecr
```

**Hành động:**
- Xóa tất cả như trên + ECR repositories
- **Giữ lại**: Secrets Manager secrets, IAM roles, VPC resources

**Chi phí:**
- ✅ Không tốn chi phí cho ECS
- ✅ Không tốn chi phí cho Load Balancers
- ✅ Không tốn chi phí cho CloudWatch Logs
- ✅ Không tốn chi phí cho ECR storage
- ⚠️ Vẫn tốn chi phí cho Secrets Manager (rất nhỏ)

**Khi nào dùng:**
- Muốn cleanup hoàn toàn, không cần giữ lại Docker images
- Sẽ phải build và push images lại từ đầu khi deploy

#### 3. Cleanup hoàn toàn (bao gồm ECR và Secrets):
```bash
./aws/cleanup-all.sh staging --delete-ecr --delete-secrets
```

**Hành động:**
- Xóa TẤT CẢ resources liên quan
- **Giữ lại**: IAM roles, VPC resources (không tốn chi phí)

**Chi phí:**
- ✅ Không tốn chi phí cho bất kỳ resource nào

**Khi nào dùng:**
- Muốn cleanup hoàn toàn, không còn gì liên quan đến FieldKit
- Sẽ phải setup lại từ đầu khi deploy (database secrets, session key, etc.)

#### 4. Cleanup với auto-confirm (nguy hiểm):
```bash
./aws/cleanup-all.sh staging --delete-ecr --delete-secrets --confirm
```

**Hành động:**
- Tương tự như trên nhưng bỏ qua confirmation prompt
- **Nguy hiểm**: Không có cơ hội xác nhận lại

**Khi nào dùng:**
- Chỉ dùng trong automation/CI/CD
- **KHÔNG BAO GIỜ** dùng trong môi trường production mà không kiểm tra kỹ

### Quy trình khởi động lại sau khi cleanup:

#### Nếu đã xóa ECR (`--delete-ecr`):
```bash
# 1. Deploy database
./aws/deploy-database.sh staging

# 2. Tạo application services
./aws/create-ecs-services.sh staging

# 3. Setup load balancer
./aws/setup-load-balancer.sh staging

# 4. Build và push images (phải build lại)
./aws/build-and-push.sh latest staging

# 5. Deploy
./aws/deploy.sh latest staging
```

#### Nếu đã xóa Secrets (`--delete-secrets`):
```bash
# 1. Setup database secrets
./aws/setup-database-secrets.sh staging
# Hoặc
./aws/create-database-secrets-from-services.sh staging

# 2. Setup session key
./aws/setup-session-key.sh staging

# 3. Tiếp tục với các bước deploy như trên
```

#### Nếu đã xóa cả ECR và Secrets:
```bash
# Phải setup lại từ đầu hoàn toàn
# Xem hướng dẫn trong aws/README.md
```

### Lưu ý quan trọng:

1. **Không thể hoàn tác**: Script này xóa resources vĩnh viễn, không thể khôi phục

2. **Confirmation prompt**: Script sẽ hỏi xác nhận trước khi xóa (trừ khi dùng `--confirm`)

3. **Thứ tự xóa**: Script tự động xóa theo thứ tự đúng:
   - Services trước (scale về 0)
   - Target groups trước load balancers
   - Load balancers trước clusters
   - Clusters cuối cùng

4. **Resources không bị xóa**:
   - IAM roles và policies (không tốn chi phí)
   - VPC, subnets, security groups (có thể dùng chung)
   - Task definitions (không tốn chi phí, chỉ metadata)

5. **ECR và Secrets**: Mặc định được giữ lại để deploy lại nhanh hơn

6. **Database data**: Script chỉ xóa services, không xóa data trong database. Nếu muốn xóa data, cần xóa volumes thủ công.

### Ví dụ output:

```
==========================================
🧹 Cleanup Toàn Bộ Resources
==========================================
Environment: staging
Region: ap-southeast-1
Account ID: 123456789012

Resources sẽ bị xóa:
  ✅ Application Cluster: fieldkit-staging-app
  ✅ Database Cluster: fieldkit-staging-db-v1
  ✅ Load Balancers (ALB/NLB)
  ✅ Target Groups
  ✅ CloudWatch Log Groups
  ⚠️  ECR Repositories: GIỮ LẠI
  ⚠️  Secrets Manager: GIỮ LẠI
==========================================

⚠️  CẢNH BÁO: Script này sẽ xóa TẤT CẢ resources liên quan!
   Điều này không thể hoàn tác!

Bạn có chắc chắn muốn tiếp tục? (yes/no): yes

🚀 Bắt đầu cleanup...

1️⃣  Cleanup Application Services...
   📦 Đang xóa service: fieldkit-staging-app-server...
   ✅ Service fieldkit-staging-app-server đã được xóa
   📦 Đang xóa service: fieldkit-staging-app-charting...
   ✅ Service fieldkit-staging-app-charting đã được xóa

2️⃣  Cleanup Database Services...
   📦 Đang xóa service: fieldkit-staging-db-v1-postgres...
   ✅ Service fieldkit-staging-db-v1-postgres đã được xóa
   📦 Đang xóa service: fieldkit-staging-db-v1-timescale...
   ✅ Service fieldkit-staging-db-v1-timescale đã được xóa

3️⃣  Cleanup Target Groups...
   🗑️  Đang xóa target group: fieldkit-staging-server-tg...
   ✅ Target group fieldkit-staging-server-tg đã được xóa

4️⃣  Cleanup Load Balancers...
   🗑️  Đang xóa ALB: fieldkit-staging-server-alb...
   ✅ ALB fieldkit-staging-server-alb đã được xóa

5️⃣  Cleanup Clusters...
   🗑️  Đang xóa cluster: fieldkit-staging-app...
   ✅ Cluster fieldkit-staging-app đã được xóa
   🗑️  Đang xóa cluster: fieldkit-staging-db-v1...
   ✅ Cluster fieldkit-staging-db-v1 đã được xóa

6️⃣  Cleanup CloudWatch Log Groups...
   📋 Đang tìm log groups với prefix: /ecs/fieldkit-staging...
   🗑️  Đang xóa log group: /ecs/fieldkit-staging-app-server...
   ✅ Log group /ecs/fieldkit-staging-app-server đã được xóa

==========================================
✅ Cleanup hoàn tất!
==========================================

📊 Tổng kết:
  ✅ Application cluster và services đã được xóa
  ✅ Database cluster và services đã được xóa
  ✅ Load balancers đã được xóa
  ✅ Target groups đã được xóa
  ✅ CloudWatch log groups đã được xóa

💡 Lưu ý:
  - Task definitions vẫn được giữ lại (không tốn chi phí)
  - IAM roles và policies vẫn được giữ lại
  - VPC, subnets, security groups vẫn được giữ lại
  - ECR repositories vẫn được giữ lại
  - Secrets Manager secrets vẫn được giữ lại

🔄 Để deploy lại từ đầu:
  1. ./aws/deploy-database.sh staging
  2. ./aws/create-ecs-services.sh staging
  3. ./aws/setup-load-balancer.sh staging
  4. ./aws/build-and-push.sh latest staging
  5. ./aws/deploy.sh latest staging
==========================================
```

### So sánh với stop-and-cleanup.sh:

| Tính năng | stop-and-cleanup.sh | cleanup-all.sh |
|----------|---------------------|----------------|
| **Phạm vi** | Chỉ application cluster | Tất cả clusters (app + db) |
| **Load Balancers** | Không xóa | Xóa ALB/NLB |
| **Target Groups** | Không xóa | Xóa target groups |
| **Log Groups** | Không xóa | Xóa CloudWatch log groups |
| **ECR** | Không xóa | Có option xóa |
| **Secrets** | Không xóa | Có option xóa |
| **Mục đích** | Tạm dừng để tiết kiệm chi phí | Cleanup hoàn toàn |

### Khuyến nghị sử dụng:

- **Tạm dừng ngắn hạn**: Dùng `stop-and-cleanup.sh` (giữ lại resources)
- **Tạm dừng dài hạn**: Dùng `cleanup-all.sh` (xóa hết để không tốn chi phí)
- **Cleanup hoàn toàn**: Dùng `cleanup-all.sh --delete-ecr --delete-secrets`
- **Production**: Cẩn thận khi dùng `cleanup-all.sh`, luôn backup data trước

