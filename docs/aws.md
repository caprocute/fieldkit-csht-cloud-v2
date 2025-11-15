# Hướng dẫn Deploy FieldKit lên AWS

Hướng dẫn đóng gói và triển khai các thành phần ứng dụng FieldKit lên AWS ECS.

## Kiến trúc Deployment

```
┌─────────────────────────────────────────────────┐
│           Build Local (Docker)                  │
│  - Build Docker images                        │
│  - Tag với version                              │
│  - Push lên AWS ECR                            │
└─────────────────────────────────────────────────┘
                    │
                    ▼
┌─────────────────────────────────────────────────┐
│              AWS ECR Registry                  │
│  - fieldkit/server:latest                       │
│  - fieldkit/charting:latest                     │
│  - fieldkit/migrations:latest                  │
└─────────────────────────────────────────────────┘
                    │
                    ▼
┌─────────────────────────────────────────────────┐
│          AWS ECS Deployment                    │
│  - ECS Cluster (Fargate)                       │
│  - Services (server, charting)                 │
│  - Task Definitions                            │
└─────────────────────────────────────────────────┘
```

## Yêu cầu

1. **AWS CLI** đã được cài đặt và cấu hình với credentials có quyền:
   - ECR (push/pull images)
   - ECS (create/update services)
   - IAM (roles cho ECS tasks)
   - Secrets Manager (để lưu secrets)
   - CloudWatch Logs (để logging)

   **Cách lấy AWS Access Key ID và Secret Access Key:**
   
   **Bước 1: Đăng nhập AWS Console**
   - Truy cập: https://console.aws.amazon.com
   - Đăng nhập với tài khoản AWS của bạn
   
   **Bước 2: Tạo Access Key**
   - Click vào tên user ở góc trên bên phải (hoặc vào IAM service)
   - Chọn "Security credentials" tab
   - Scroll xuống phần "Access keys"
   - Click "Create access key"
   - Chọn use case (ví dụ: "Command Line Interface (CLI)")
   - Click "Next" và "Create access key"
   - **QUAN TRỌNG**: Download hoặc copy ngay Access Key ID và Secret Access Key
     - Secret Access Key chỉ hiển thị 1 lần duy nhất
     - Nếu mất, phải tạo access key mới
   
   **Bước 3: Cấu hình AWS CLI**
   ```bash
   # Cấu hình default credentials
   aws configure
   
   # Hoặc tạo profile riêng
   aws configure --profile fieldkit
   ```
   
   Khi được hỏi, nhập:
   - **AWS Access Key ID**: [Paste Access Key ID đã copy]
   - **AWS Secret Access Key**: [Paste Secret Access Key đã copy]
   - **Default region name**: `ap-southeast-1` (hoặc region bạn muốn)
   - **Default output format**: `json`
   
   **Lưu ý bảo mật:**
   - Không commit Access Keys vào Git
   - Không chia sẻ Access Keys qua email/chat
   - Nếu nghi ngờ bị lộ, xóa access key ngay và tạo mới
   - Sử dụng IAM roles thay vì access keys khi có thể (trên EC2/ECS)
   
   **Kiểm tra quyền AWS CLI:**
   ```bash
   # Kiểm tra AWS CLI đã được cài đặt
   aws --version
   
   # Kiểm tra credentials hiện tại
   aws sts get-caller-identity
   # Kết quả sẽ hiển thị Account ID, User/Role ARN
   
   # Kiểm tra quyền ECR
   aws ecr describe-repositories --region ap-southeast-1
   
   # Kiểm tra quyền ECS
   aws ecs list-clusters --region ap-southeast-1
   
   # Kiểm tra quyền Secrets Manager
   aws secretsmanager list-secrets --region ap-southeast-1
   
   # Kiểm tra quyền CloudWatch Logs
   aws logs describe-log-groups --region ap-southeast-1 --max-items 1
   
   # Kiểm tra quyền IAM (xem roles)
   aws iam list-roles --max-items 1
   
   # Nếu có lỗi permission denied, cần cập nhật IAM policy cho user/role
   ```

2. **Docker** đã được cài đặt và chạy

   **Kiểm tra Docker:**
   ```bash
   docker --version
   docker info
   docker ps
   ```

3. **jq** để xử lý JSON

   **Kiểm tra jq:**
   ```bash
   jq --version
   # Nếu chưa có: brew install jq (macOS) hoặc apt-get install jq (Linux)
   ```

4. **Biến môi trường**:
   ```bash
   # AWS_ACCOUNT_ID sẽ được tự động lấy từ AWS credentials
   # Không cần set nếu đã cấu hình AWS credentials đúng
   
   export AWS_REGION="ap-southeast-1"
   export AWS_PROFILE="fieldkit"  # Optional - chỉ dùng nếu profile đã được tạo
   
   # Kiểm tra Account ID thực tế
   aws sts get-caller-identity --query Account --output text
   
   # Kiểm tra biến môi trường
   echo "AWS Region: $AWS_REGION"
   
   # Nếu muốn dùng AWS_PROFILE, tạo profile trước:
   aws configure --profile fieldkit
   # Nhập AWS Access Key ID, Secret Access Key, region, output format
   ```
   
   **Lưu ý**: Scripts sẽ tự động lấy AWS Account ID từ credentials. Nếu set `AWS_ACCOUNT_ID` trong environment nhưng khác với Account ID thực tế, script sẽ cảnh báo và sử dụng Account ID thực tế.

## Kiểm tra Prerequisites

Trước khi deploy, chạy script kiểm tra:

```bash
cd /Users/ultravious/development/8.fieldKit/full_group/gitlab-fieldkit
./aws/check-prerequisites.sh
```

Script này sẽ kiểm tra:
- AWS CLI đã được cài đặt
- AWS credentials đã được cấu hình
- AWS permissions (ECR, ECS, Secrets Manager, CloudWatch, IAM)
- Docker đã được cài đặt và đang chạy
- jq đã được cài đặt
- Environment variables đã được set

## Kiến trúc Deployment

Ứng dụng được chia thành **2 cluster riêng biệt**:

1. **Database Cluster** (`fieldkit-{ENV}-db-v1`):
   - PostgreSQL service
   - TimescaleDB service

2. **Application Cluster** (`fieldkit-{ENV}-app`):
   - Server service (expose qua Application Load Balancer)
   - Charting service

### Kiến trúc Server và Portal

**Tại sao đóng gói cả Server và Portal trong 1 image?**

Server và Portal được đóng gói trong cùng một Docker image (`hieuhk_fieldkit/server`) vì:

1. **Kiến trúc Monolithic**: Server (Go) serve cả API và Portal static files (Vue.js)
2. **Routing thông minh**: 
   - API requests → Server xử lý
   - Portal requests → Server serve static files từ `/portal`
   - Default route → Portal SPA (Single Page Application)
3. **Lợi ích**:
   - Đơn giản hóa deployment (chỉ cần 1 service)
   - Giảm latency (không cần network hop giữa server và portal)
   - Dễ quản lý version (server và portal cùng version)

**Cấu hình:**

- **Port**: Server chạy ở port 80 (HTTP standard)
- **Portal Root**: Portal files được copy vào `/portal` trong image
- **Environment Variable**: `FIELDKIT_PORTAL_ROOT=/portal` (bắt buộc để server biết đường dẫn portal)
- **Health Check**: `/status` endpoint để kiểm tra server health
- **Routing**:
  - `/status` → Health check endpoint
  - `/robots.txt` → Robots.txt
  - `/.well-known/*` → Well-known files
  - `api.{domain}/*` → API endpoints
  - `*` → Portal SPA (fallback)

**Lưu ý quan trọng:**

- Nếu `FIELDKIT_PORTAL_ROOT` không được set, server sẽ không serve portal files và trả về 404
- Health check endpoint là `/status`, không phải `/health`
- Portal được serve như một SPA, tất cả routes không match API sẽ fallback về portal

## Quy trình Deployment

### Bước 1: Setup Infrastructure

#### 1.1. Setup Database Cluster và Services

```bash
cd /Users/ultravious/development/8.fieldKit/full_group/gitlab-fieldkit

# Set environment variables
export VPC_ID="vpc-xxxxx"
export SUBNET_IDS="subnet-xxxxx,subnet-yyyyy"
export SECURITY_GROUP_ID="sg-xxxxx"

# Deploy database services
./aws/deploy-database.sh staging
```

Script này sẽ:
- Tạo cluster `fieldkit-staging-db-v1` (nếu chưa có)
- Đăng ký task definitions cho PostgreSQL và TimescaleDB
- Tạo services cho PostgreSQL và TimescaleDB

#### 1.2. Setup Application Cluster và Services

```bash
# Deploy application services
./aws/create-ecs-services.sh staging
```

Script này sẽ:
- Tạo cluster `fieldkit-staging-app` (nếu chưa có)
- Đăng ký task definitions cho server và charting
- Tạo services cho server và charting

### Bước 2: Setup Load Balancers

Sau khi tạo database và server services, setup Load Balancers ngay để có thể truy cập các dịch vụ.

#### 2.1. Setup Application Load Balancer cho Server

```bash
./aws/setup-load-balancer.sh staging
```

Script này sẽ:
- Tạo Application Load Balancer (ALB) internet-facing
- Tạo target group cho server service
- Cấu hình HTTP listener (port 80)
- Cập nhật server service để sử dụng load balancer

Sau khi hoàn thành, bạn sẽ nhận được ALB DNS name để truy cập web application.

#### 2.2. Setup Public Access cho PostgreSQL (Optional)

**Trước khi chạy script, cần set các biến môi trường:**

```bash
# Lấy VPC_ID
export VPC_ID=$(aws ec2 describe-vpcs --region ap-southeast-1 --filters "Name=isDefault,Values=true" --query 'Vpcs[0].VpcId' --output text)

# Lấy SUBNET_IDS (cần ít nhất 2 subnets)
export SUBNET_IDS=$(aws ec2 describe-subnets --region ap-southeast-1 --filters "Name=vpc-id,Values=${VPC_ID}" --query 'Subnets[*].SubnetId' --output text | tr '\t' ',')

# Lấy SECURITY_GROUP_ID từ service hiện tại (nếu đã có)
export SECURITY_GROUP_ID=$(aws ecs describe-services \
  --cluster fieldkit-staging-db-v1 \
  --services fieldkit-staging-db-v1-postgres \
  --region ap-southeast-1 \
  --query 'services[0].networkConfiguration.awsvpcConfiguration.securityGroups[0]' \
  --output text)
```

**Chạy script:**

```bash
./aws/setup-postgres-public.sh staging
```

Script này sẽ:
- Tự động tìm default VPC và subnets nếu chưa set biến môi trường
- Hiển thị hướng dẫn chi tiết nếu thiếu thông tin
- Tạo Network Load Balancer (NLB) internet-facing
- Tạo target group cho PostgreSQL service
- Cấu hình TCP listener (port 5432)
- Cập nhật PostgreSQL service để sử dụng load balancer

**⚠️ Cảnh báo bảo mật**: Expose PostgreSQL ra internet có rủi ro bảo mật. Nên:
- Giới hạn IP source trong security group
- Sử dụng SSL/TLS connection
- Xem xét sử dụng VPN hoặc Bastion Host thay vì public access

#### 2.3. Setup Public Access cho TimescaleDB (Optional)

Tương tự như PostgreSQL, chạy:

```bash
./aws/setup-timescale-public.sh staging
```

### Bước 3: Setup Secrets

#### 3.1. Setup Session Key

```bash
./aws/setup-session-key.sh staging
```

#### 3.2. Setup Database Connection Strings

```bash
# Tự động tạo connection strings từ service discovery
./aws/create-database-secrets-from-services.sh staging
```

Hoặc setup thủ công:

```bash
./aws/setup-database-secrets.sh staging
```

### Bước 4: Chạy Database Migrations

Có 2 cách để chạy migrations:

#### Cách 1: Chạy từ máy local (Khuyến nghị)

Chạy migrations trực tiếp từ máy tính của bạn, kết nối đến database trên AWS:

```bash
# Chạy migrations cho database (PostgreSQL với TimescaleDB extension)
./aws/run-migrations-local.sh staging
```

**Yêu cầu:**
- Go đã được cài đặt (`go version`)
- Database connection string đã được setup trong Secrets Manager
- Network có thể kết nối đến database (qua NLB hoặc VPN)

**Lợi ích:**
- Nhanh hơn (không cần build/push Docker image)
- Dễ debug (xem logs trực tiếp)
- Không tốn chi phí ECS task

**Lưu ý**: Hệ thống hiện tại chỉ sử dụng 1 database duy nhất (PostgreSQL với TimescaleDB extension), không còn database TimescaleDB riêng biệt.

#### Cách 2: Chạy trên ECS (Tự động)

Chạy migrations như một ECS task:

```bash
# Chạy migrations cho database
./aws/run-migrations.sh staging
```

Script này sẽ:
- Lấy connection string từ Secrets Manager
- Tạo task definition cho migrations
- Chạy migrations cho database (từ `/work/primary`)
- Đợi và kiểm tra kết quả

**Lưu ý**: Migrations image cần được build với migrations files đã được copy vào image (đã được cập nhật trong `migrations/Dockerfile`).

### Bước 5: Build và Push Images

**Lưu ý quan trọng**: Scripts build cần chạy từ thư mục `cloud/` vì chúng cần truy cập Dockerfile và source code.

```bash
cd /Users/ultravious/development/8.fieldKit/cloud

# Build và push tất cả images
./deployment/build-and-push.sh latest staging
```

Hoặc với version cụ thể:

```bash
./deployment/build-and-push.sh v1.0.0 staging
```

### Bước 6: Deploy Images lên ECS

```bash
cd /Users/ultravious/development/8.fieldKit/full_group/gitlab-fieldkit

# Deploy images đã build
./aws/deploy.sh latest staging
```

Script này sẽ:
- Đăng ký task definitions mới với images mới
- Cập nhật services để sử dụng task definitions mới
- ECS sẽ tự động thực hiện rolling update

## Cấu trúc Files

```
aws/
├── build-and-push.sh              # Build và push Docker images lên ECR
├── deploy.sh                       # Deploy images lên ECS
├── create-ecs-services.sh         # Setup application cluster và services
├── deploy-database.sh              # Deploy database cluster và services
├── setup-load-balancer.sh          # Setup ALB cho server service
├── setup-postgres-public.sh       # Setup NLB cho PostgreSQL (optional)
├── setup-timescale-public.sh      # Setup NLB cho TimescaleDB (optional)
├── export-database-urls.sh         # Export database URLs từ Secrets Manager
├── check-public-services.sh        # Kiểm tra trạng thái public của các dịch vụ
├── check-server-access.sh          # Kiểm tra server service access
├── test-create-station-api.sh      # Test API tạo station
├── test-sensors-recently-api.sh    # Test API /sensors/data/recently
├── run-migrations.sh               # Chạy database migrations trên ECS
├── run-migrations-local.sh         # Chạy database migrations từ máy local
├── setup-session-key.sh            # Tạo session key secret
├── setup-database-secrets.sh       # Setup database secrets thủ công
├── create-database-secrets-from-services.sh  # Tạo secrets từ service discovery
├── setup-ecs-roles.sh              # Setup ECS task roles
├── setup-ecs-service-linked-role.sh # Setup ECS service-linked role
├── check-prerequisites.sh           # Kiểm tra prerequisites
├── setup-iam-policy.sh             # Setup IAM policy
├── test-ecr-permissions.sh         # Test ECR permissions
├── fix-ecr-403.sh                  # Fix ECR 403 errors
├── list-ecr-images.sh              # List images trong ECR
├── stop-and-cleanup.sh             # Stop và cleanup services
├── port-forward-postgres.sh        # Port forward đến PostgreSQL
├── create-bastion-host.sh          # Tạo bastion host để access database
├── ecs-task-definitions/           # Task definition templates
│   ├── server-task.json
│   ├── charting-task.json
│   ├── postgres-task.json
│   └── timescale-task.json
├── iam-policies/                   # IAM policy templates
│   ├── deployment-full-policy.json
│   ├── ecr-policy.json
│   ├── ecs-policy.json
│   ├── secrets-policy.json
│   ├── cloudwatch-policy.json
│   ├── ecs-execution-policy.json
│   ├── ecs-task-execution-trust-policy.json
│   ├── ecs-task-trust-policy.json
│   ├── ecs-task-execution-policy.json
│   └── ecs-task-policy.json
├── troubleshooting-ecr-403.md     # Troubleshooting ECR 403
└── troubleshooting-aws-profile.md  # Troubleshooting AWS profile
```

## ECS Task Definitions

Task definitions được định nghĩa trong `aws/ecs-task-definitions/`:

- **server-task.json**: Configuration cho server service
  - CPU: 512
  - Memory: 1024 MB
  - Port: 80
  - Health check: `/status`
  - Environment variables:
    - `FIELDKIT_ADDR`: `:80` (server listen address)
    - `FIELDKIT_HTTP_SCHEME`: `https` (HTTP scheme)
    - `FIELDKIT_PORTAL_ROOT`: `/portal` (portal static files path - **bắt buộc**)

- **charting-task.json**: Configuration cho charting service
  - CPU: 256
  - Memory: 512 MB
  - Port: 3000

## Secrets Management

Secrets được lưu trong AWS Secrets Manager:
- `fieldkit/database/postgres`: PostgreSQL connection string
- `fieldkit/database/timescale`: TimescaleDB connection string
- `fieldkit/session/key`: Session encryption key

Để tạo secrets:
```bash
aws secretsmanager create-secret \
    --name fieldkit/database/postgres \
    --secret-string "postgres://user:pass@host:5432/db" \
    --region ap-southeast-1
```

## IAM Policies và Roles

### Permissions cần thiết cho Deployment User/Role

Trước khi deploy, đảm bảo IAM user/role có đủ quyền. Xem chi tiết trong `aws/iam-policies/README.md`.

**Quick Setup (Tự động):**
```bash
# Setup IAM policy cho IAM user
./aws/setup-iam-policy.sh YOUR_USERNAME USER

# Hoặc cho IAM role
./aws/setup-iam-policy.sh YOUR_ROLE_NAME ROLE
```

**Minimum Permissions:**
- ECR: `GetAuthorizationToken`, `CreateRepository`, `DescribeRepositories`, `PutImage`
- ECS: `DescribeClusters`, `UpdateService`, `RegisterTaskDefinition`, `DescribeTaskDefinition`
- Secrets Manager: `GetSecretValue` (nếu dùng secrets)
- CloudWatch Logs: `CreateLogGroup`, `DescribeLogGroups`

### ECS Task Roles

Cần tạo các IAM roles sau:

1. **ECS Task Execution Role** (`ecsTaskExecutionRole`)
   - Permissions: ECR pull, CloudWatch Logs, Secrets Manager

2. **ECS Task Role** (`ecsTaskRole`)
   - Permissions cho ứng dụng (tùy theo nhu cầu)

Setup tự động:
```bash
./aws/setup-ecs-roles.sh
```

## Monitoring

Sau khi deploy, theo dõi:

1. **ECS Console**: https://console.aws.amazon.com/ecs/v2/clusters/
2. **CloudWatch Logs**: `/ecs/fieldkit-server` và `/ecs/fieldkit-charting`
3. **Service Events**: Xem trong ECS service details

## Rollback

Để rollback về version trước:

```bash
# List các task definition revisions
aws ecs list-task-definitions \
    --family-prefix fieldkit-server \
    --region ap-southeast-1

# Update service với revision cũ
aws ecs update-service \
    --cluster fieldkit-staging-app \
    --service fieldkit-staging-app-server \
    --task-definition fieldkit-server:PREVIOUS_REVISION \
    --force-new-deployment \
    --region ap-southeast-1
```

## Stop và Cleanup

Khi không sử dụng, có thể stop hoặc xóa các dịch vụ để tránh phát sinh chi phí:

```bash
# Chỉ scale services về 0 (giữ lại services và cluster)
./aws/stop-and-cleanup.sh staging

# Xóa services (giữ lại cluster)
./aws/stop-and-cleanup.sh staging --delete-services

# Xóa tất cả (services + cluster) - tiết kiệm chi phí nhất
./aws/stop-and-cleanup.sh staging --all
```

**Lưu ý về chi phí:**
- **Scale về 0**: Không tốn chi phí cho tasks, nhưng vẫn tốn chi phí cho ALB (nếu có) và các resources khác
- **Xóa services**: Không tốn chi phí cho services, nhưng cluster vẫn tồn tại (chi phí minimal)
- **Xóa cluster**: Không tốn chi phí gì, nhưng cần setup lại khi deploy

## Troubleshooting

### Lỗi 403 Forbidden khi push images lên ECR

**Nguyên nhân phổ biến:**
1. Thiếu IAM permissions: `ecr:PutImage`, `ecr:InitiateLayerUpload`, `ecr:UploadLayerPart`, `ecr:CompleteLayerUpload`
2. Docker authentication token hết hạn (token chỉ có hiệu lực 12 giờ)
3. Repository ARN không khớp với IAM policy

**Quick Fix (Tự động):**
```bash
# Script tự động fix lỗi 403
./aws/fix-ecr-403.sh YOUR_USERNAME

# Hoặc để script tự detect user
./aws/fix-ecr-403.sh
```

**Manual Fix:**
```bash
# 1. Setup/Update IAM policy
./aws/setup-iam-policy.sh YOUR_USERNAME USER

# 2. Test ECR permissions chi tiết
./aws/test-ecr-permissions.sh

# 3. Re-authenticate Docker với ECR
aws ecr get-login-password --region ap-southeast-1 | \
  docker login --username AWS --password-stdin \
  ${AWS_ACCOUNT_ID}.dkr.ecr.ap-southeast-1.amazonaws.com

# 4. Kiểm tra permissions tổng quát
./aws/check-prerequisites.sh
```

### Lỗi "Không thể lấy AWS_ACCOUNT_ID từ AWS credentials"

**Nguyên nhân**: AWS CLI chưa được cấu hình với Access Key ID và Secret Access Key.

**Giải pháp**: Xem hướng dẫn chi tiết ở phần [Cách lấy AWS Access Key ID](#yêu-cầu) ở trên.

**Quick Fix:**
```bash
# 1. Lấy Access Key từ AWS Console (xem hướng dẫn ở trên)
# 2. Cấu hình AWS CLI
aws configure

# 3. Kiểm tra credentials
aws sts get-caller-identity

# 4. Chạy lại script
./aws/setup-timescale-public.sh staging
```

### Images không push được lên ECR
- Kiểm tra AWS credentials: `aws sts get-caller-identity`
- Kiểm tra ECR repository permissions
- Đảm bảo Docker đang chạy

### ECS services không start
- Kiểm tra task definition có đúng không
- Kiểm tra CloudWatch logs cho errors
- Kiểm tra IAM roles có đủ permissions
- Kiểm tra security groups và networking

### Secrets không được load
- Kiểm tra task execution role có permission `secretsmanager:GetSecretValue`
- Kiểm tra secret ARN trong task definition có đúng không
- Kiểm tra secrets tồn tại trong Secrets Manager

## Best Practices

1. **Versioning**: Luôn tag images với version cụ thể, không chỉ dùng `latest`
2. **Health Checks**: Đảm bảo health checks được cấu hình đúng
3. **Logging**: Sử dụng CloudWatch Logs để debug
4. **Secrets**: Không hardcode secrets, luôn dùng Secrets Manager
5. **Rolling Updates**: ECS sẽ tự động thực hiện rolling updates
6. **Resource Limits**: Đặt CPU và memory phù hợp với workload

## Notes

- **Không build trên AWS**: Tất cả images được build local và push lên ECR
- **Immutable Deployments**: Mỗi deployment tạo task definition mới
- **Zero Downtime**: ECS Fargate hỗ trợ rolling updates tự động
- **Scripts build**: Cần chạy từ thư mục `cloud/` vì cần truy cập Dockerfile và source code
- **Scripts deploy**: Có thể chạy từ thư mục root của repo (`gitlab-fieldkit/`)

