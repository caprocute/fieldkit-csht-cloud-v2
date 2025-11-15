# Các Công Nghệ AWS Sử Dụng Trong Dự Án FieldKit

Tài liệu này mô tả chi tiết tất cả các công nghệ AWS được sử dụng trong dự án FieldKit, từ các services lớn đến các tính năng nhỏ.

## Bảng Tổng Hợp

| STT | Tên Công Nghệ | Mô Tả Chức Năng | Vai Trò Trong Dự Án | Module Trực Tiếp Sử Dụng |
|-----|---------------|-----------------|---------------------|--------------------------|
| 1 | **ECS (Elastic Container Service)** | Dịch vụ quản lý container orchestration, cho phép chạy và scale containerized applications | Nền tảng chính để deploy và quản lý các services (server, charting, database) | `aws/create-ecs-services.sh`, `aws/deploy.sh`, `aws/deploy-database.sh`, `aws/stop-and-cleanup.sh` |
| 2 | **ECR (Elastic Container Registry)** | Dịch vụ lưu trữ Docker images, tương tự Docker Hub nhưng tích hợp với AWS | Lưu trữ và quản lý Docker images cho server, charting, và migrations | `aws/build-and-push.sh`, `aws/build-and-push-server.sh`, `aws/test-ecr-permissions.sh`, `aws/fix-ecr-403.sh`, `aws/list-ecr-images.sh` |
| 3 | **Fargate** | Serverless compute engine cho containers, không cần quản lý servers | Compute platform để chạy ECS tasks mà không cần quản lý EC2 instances | `aws/ecs-task-definitions/*.json` (requiresCompatibilities: ["FARGATE"]) |
| 4 | **IAM (Identity and Access Management)** | Dịch vụ quản lý quyền truy cập và bảo mật, kiểm soát ai có thể làm gì với tài nguyên AWS | Quản lý permissions cho deployment user, ECS task execution roles, và task roles | `aws/setup-iam-policy.sh`, `aws/setup-ecs-roles.sh`, `aws/iam-policies/*.json` |
| 5 | **Secrets Manager** | Dịch vụ lưu trữ và quản lý secrets (passwords, API keys, connection strings) một cách an toàn | Lưu trữ database connection strings, session keys, và các credentials khác | `aws/setup-session-key.sh`, `aws/setup-database-secrets.sh`, `aws/create-database-secrets-from-services.sh`, `aws/export-database-urls.sh` |
| 6 | **CloudWatch Logs** | Dịch vụ logging tập trung, thu thập và lưu trữ logs từ các ứng dụng và services | Thu thập và lưu trữ logs từ ECS tasks (server, charting, postgres, timescale) | `aws/ecs-task-definitions/*.json` (logConfiguration với awslogs driver) |
| 7 | **Application Load Balancer (ALB)** | Load balancer layer 7 (HTTP/HTTPS), phân phối traffic đến multiple targets, hỗ trợ routing dựa trên content | Expose server service ra internet, phân phối traffic đến các ECS tasks | `aws/setup-load-balancer.sh`, `aws/test-create-station-api.sh`, `aws/test-sensors-recently-api.sh` |
| 8 | **Network Load Balancer (NLB)** | Load balancer layer 4 (TCP/UDP), xử lý traffic ở network level, phù hợp cho high performance | Expose PostgreSQL và TimescaleDB services ra internet qua TCP port 5432 | `aws/setup-postgres-public.sh`, `aws/setup-timescale-public.sh` |
| 9 | **VPC (Virtual Private Cloud)** | Mạng ảo riêng biệt và cô lập trong AWS, cho phép kiểm soát network topology | Tạo network isolation cho ECS tasks, quản lý network connectivity | `aws/create-ecs-services.sh`, `aws/deploy-database.sh`, `aws/setup-postgres-public.sh`, `aws/setup-timescale-public.sh` |
| 10 | **EC2 (Elastic Compute Cloud)** | Dịch vụ cung cấp virtual servers trong cloud | Tạo bastion host để truy cập database một cách an toàn (optional) | `aws/create-bastion-host.sh` |
| 11 | **Security Groups** | Virtual firewall kiểm soát inbound và outbound traffic cho EC2 instances và ECS tasks | Bảo mật network, kiểm soát traffic vào/ra ECS tasks và load balancers | `aws/create-ecs-services.sh`, `aws/setup-postgres-public.sh`, `aws/setup-timescale-public.sh` |
| 12 | **Subnets** | Phân đoạn mạng con trong VPC, cho phép tổ chức và cô lập resources | Phân bổ ECS tasks vào các subnets, hỗ trợ high availability với multiple AZs | `aws/create-ecs-services.sh`, `aws/deploy-database.sh`, `aws/setup-load-balancer.sh` |
| 13 | **Target Groups** | Nhóm các targets (ECS tasks, EC2 instances) để nhận traffic từ load balancer | Định nghĩa các targets cho ALB và NLB, health checks | `aws/setup-load-balancer.sh`, `aws/setup-postgres-public.sh`, `aws/setup-timescale-public.sh` |
| 14 | **Listeners** | Cấu hình lắng nghe traffic trên load balancer, định nghĩa rules để route traffic | Cấu hình HTTP/HTTPS listeners cho ALB và TCP listeners cho NLB | `aws/setup-load-balancer.sh`, `aws/setup-postgres-public.sh`, `aws/setup-timescale-public.sh` |
| 15 | **ECS Clusters** | Logical grouping của ECS tasks và services, quản lý capacity providers | Tổ chức services thành clusters riêng biệt (database cluster và application cluster) | `aws/create-ecs-services.sh`, `aws/deploy-database.sh`, `aws/deploy.sh` |
| 16 | **ECS Services** | Long-running tasks được quản lý bởi ECS, tự động maintain desired count | Quản lý server, charting, postgres, và timescale services | `aws/create-ecs-services.sh`, `aws/deploy-database.sh`, `aws/deploy.sh`, `aws/stop-and-cleanup.sh` |
| 17 | **ECS Task Definitions** | Blueprint cho containers, định nghĩa CPU, memory, images, environment variables | Định nghĩa cấu hình cho server, charting, postgres, và timescale containers | `aws/ecs-task-definitions/*.json`, `aws/deploy.sh`, `aws/update-server-task-definition.sh` |
| 18 | **ECS Tasks** | Instance của task definition đang chạy, là containerized application | Các container instances đang chạy của server, charting, database services | `aws/stop-and-cleanup.sh`, `aws/port-forward-postgres.sh` |
| 19 | **ECS Service-Linked Roles** | IAM roles được tạo tự động bởi AWS services để access các AWS services khác | Role cho ECS service để quản lý load balancers và các resources khác | `aws/setup-ecs-service-linked-role.sh`, `aws/create-ecs-services.sh` |
| 20 | **ECS Task Execution Role** | IAM role cho ECS agent để pull images từ ECR và write logs | Pull Docker images từ ECR, ghi logs vào CloudWatch, lấy secrets từ Secrets Manager | `aws/setup-ecs-roles.sh`, `aws/ecs-task-definitions/*.json` (executionRoleArn) |
| 21 | **ECS Task Role** | IAM role cho containers để access AWS services | Cho phép containers access S3, Secrets Manager, và các AWS services khác | `aws/setup-ecs-roles.sh`, `aws/ecs-task-definitions/*.json` (taskRoleArn) |
| 22 | **AWS CLI** | Command-line interface để tương tác với AWS services | Tool chính để thực hiện tất cả các operations với AWS (deploy, manage, monitor) | Tất cả scripts trong `aws/` directory |
| 23 | **AWS Regions** | Vị trí địa lý nơi AWS resources được deploy | Chọn region để deploy (mặc định: ap-southeast-1) | Tất cả scripts (AWS_REGION environment variable) |
| 24 | **AWS Account ID** | Unique identifier cho AWS account | Xác định account để tạo ARNs cho resources (ECR registry, IAM roles, secrets) | Tất cả scripts (tự động detect từ credentials) |
| 25 | **IAM Policies** | Documents định nghĩa permissions cho users, groups, và roles | Định nghĩa quyền cho deployment user và ECS roles | `aws/iam-policies/*.json`, `aws/setup-iam-policy.sh` |
| 26 | **IAM Roles** | Identity với permissions được gán, có thể được assume bởi services | ECS task execution role và task role để access AWS services | `aws/setup-ecs-roles.sh`, `aws/iam-policies/*.json` |
| 27 | **IAM Trust Policies** | Policies định nghĩa ai có thể assume một role | Cho phép ECS service assume task execution role và task role | `aws/iam-policies/ecs-task-execution-trust-policy.json`, `aws/iam-policies/ecs-task-trust-policy.json` |
| 28 | **Secrets Manager Secrets** | Individual secret objects chứa sensitive data | Lưu trữ database URLs, session keys, và credentials | `aws/setup-session-key.sh`, `aws/setup-database-secrets.sh`, `aws/create-database-secrets-from-services.sh` |
| 29 | **CloudWatch Log Groups** | Containers cho log streams, tổ chức logs theo application/service | Tổ chức logs theo service: /ecs/fieldkit-server, /ecs/fieldkit-charting, etc. | `aws/create-ecs-services.sh`, `aws/ecs-task-definitions/*.json` |
| 30 | **CloudWatch Log Streams** | Individual log streams trong log groups | Log streams cho từng ECS task instance | `aws/ecs-task-definitions/*.json` (awslogs-stream-prefix) |
| 31 | **CloudWatch Log Driver** | Docker logging driver để gửi logs đến CloudWatch | Tích hợp container logs với CloudWatch Logs | `aws/ecs-task-definitions/*.json` (logDriver: "awslogs") |
| 32 | **ELBv2 API** | API để quản lý Application Load Balancers và Network Load Balancers | Tạo và quản lý ALB và NLB thông qua AWS CLI | `aws/setup-load-balancer.sh`, `aws/setup-postgres-public.sh`, `aws/setup-timescale-public.sh` |
| 33 | **VPC Default VPC** | VPC mặc định được tạo tự động khi tạo AWS account | Sử dụng default VPC nếu không có VPC tùy chỉnh | `aws/setup-postgres-public.sh`, `aws/setup-timescale-public.sh` |
| 34 | **VPC Subnets** | Phân đoạn IP address range trong VPC | Phân bổ ECS tasks vào subnets, hỗ trợ multi-AZ deployment | `aws/create-ecs-services.sh`, `aws/deploy-database.sh` |
| 35 | **Availability Zones (AZs)** | Data centers riêng biệt trong một region | Deploy tasks vào multiple AZs để high availability | `aws/create-ecs-services.sh` (subnets trong multiple AZs) |
| 36 | **Public IP Addresses** | IP addresses có thể truy cập từ internet | Gán public IP cho ECS tasks để access internet (pull images, etc.) | `aws/create-ecs-services.sh` (assignPublicIp: ENABLED) |
| 37 | **Private IP Addresses** | IP addresses chỉ truy cập được trong VPC | IP addresses nội bộ cho ECS tasks trong VPC | `aws/create-ecs-services.sh` (awsvpc network mode) |
| 38 | **ECS Capacity Providers** | Định nghĩa infrastructure strategy cho ECS tasks (Fargate, Fargate Spot, EC2) | Chọn Fargate hoặc Fargate Spot để chạy tasks | `aws/create-ecs-services.sh` (capacity-providers: FARGATE, FARGATE_SPOT) |
| 39 | **Fargate Spot** | Cost-effective option của Fargate với khả năng bị interrupt | Tùy chọn để giảm chi phí cho non-critical workloads | `aws/create-ecs-services.sh` (capacity-providers) |
| 40 | **ECS Service Discovery** | Tự động discover services thông qua DNS names | Có thể được sử dụng để services discover nhau (database connection) | `aws/create-database-secrets-from-services.sh` (có thể sử dụng service discovery) |
| 41 | **S3 (Simple Storage Service)** | Object storage service để lưu trữ files và data | Lưu trữ media files, streams, và static assets (được đề cập trong docs) | `cloud/server/` (code xử lý S3, không có script riêng trong aws/) |
| 42 | **STS (Security Token Service)** | Dịch vụ tạo temporary credentials để access AWS resources | Xác thực và lấy caller identity để detect AWS Account ID | `aws/check-prerequisites.sh`, tất cả scripts (aws sts get-caller-identity) |
| 43 | **ECR Image Scanning** | Tự động scan Docker images để tìm vulnerabilities | Bảo mật: scan images khi push lên ECR | `aws/build-and-push.sh` (image-scanning-configuration: scanOnPush=true) |
| 44 | **ECR Image Encryption** | Mã hóa images trong ECR | Bảo mật: mã hóa images ở rest | `aws/build-and-push.sh` (encryption-configuration: encryptionType=AES256) |
| 45 | **ECR Repository Lifecycle Policies** | Tự động xóa old images để tiết kiệm storage | Quản lý storage costs (có thể được cấu hình) | Có thể được cấu hình trong ECR console |
| 46 | **ECS Service Auto Scaling** | Tự động scale services dựa trên metrics | Tự động scale services khi cần (có thể được cấu hình) | Có thể được cấu hình thông qua ECS console hoặc scripts |
| 47 | **ECS Rolling Updates** | Update strategy để deploy new versions không downtime | Zero-downtime deployments khi update services | `aws/deploy.sh` (force-new-deployment) |
| 48 | **ECS Health Checks** | Kiểm tra health của containers và tasks | Đảm bảo chỉ healthy tasks nhận traffic | `aws/ecs-task-definitions/*.json` (healthCheck configuration) |
| 49 | **ALB Health Checks** | Kiểm tra health của targets trong target group | Chỉ route traffic đến healthy targets | `aws/setup-load-balancer.sh` (health check configuration) |
| 50 | **NLB Health Checks** | Kiểm tra health của targets cho NLB | Đảm bảo database connections chỉ đến healthy instances | `aws/setup-postgres-public.sh`, `aws/setup-timescale-public.sh` |
| 51 | **Target Group Health Checks** | Cấu hình health check cho target groups | Định nghĩa health check path, interval, timeout | `aws/setup-load-balancer.sh`, `aws/setup-postgres-public.sh` |
| 52 | **Port Forwarding** | Chuyển tiếp port từ local đến remote service | Truy cập database từ local machine qua ECS task | `aws/port-forward-postgres.sh` |
| 53 | **ECS Exec** | Execute commands trong running containers | Debug và troubleshoot containers (có thể được sử dụng) | Có thể được sử dụng với AWS CLI |
| 54 | **CloudWatch Metrics** | Metrics về performance và health của resources | Monitor ECS services, ALB, và các resources khác | Có thể được xem trong CloudWatch console |
| 55 | **CloudWatch Alarms** | Cảnh báo khi metrics vượt ngưỡng | Alert khi services có vấn đề (có thể được cấu hình) | Có thể được cấu hình trong CloudWatch console |
| 56 | **AWS Resource Tags** | Metadata gắn vào resources để tổ chức và quản lý | Tag resources để dễ quản lý và cost tracking | Có thể được thêm vào resources |
| 57 | **AWS Resource ARNs** | Amazon Resource Names - unique identifiers cho resources | Định danh resources trong IAM policies và configurations | Tất cả scripts (ARNs cho secrets, roles, tasks) |
| 58 | **AWS Service Endpoints** | URLs để access AWS services | Kết nối đến AWS services từ applications | Tất cả scripts (sử dụng AWS CLI endpoints) |
| 59 | **Docker Registry Authentication** | Xác thực để push/pull images từ ECR | Đăng nhập vào ECR để push Docker images | `aws/build-and-push.sh` (aws ecr get-login-password) |
| 60 | **ECR Authorization Tokens** | Temporary tokens để authenticate với ECR | Token có hiệu lực 12 giờ để push/pull images | `aws/build-and-push.sh`, `aws/test-ecr-permissions.sh` |

## Chi Tiết Các Công Nghệ Chính

### 1. ECS (Elastic Container Service)

**Mô tả:** Dịch vụ container orchestration của AWS, cho phép chạy và scale containerized applications mà không cần quản lý infrastructure.

**Vai trò trong dự án:**
- Deploy server service (Go backend + Vue.js portal)
- Deploy charting service (TypeScript service)
- Deploy PostgreSQL và TimescaleDB services
- Quản lý lifecycle của containers
- Auto-scaling và load balancing

**Module sử dụng:**
- `aws/create-ecs-services.sh` - Tạo clusters và services
- `aws/deploy.sh` - Deploy new versions
- `aws/deploy-database.sh` - Deploy database services
- `aws/stop-and-cleanup.sh` - Stop và cleanup services
- `aws/ecs-task-definitions/*.json` - Task definitions

### 2. ECR (Elastic Container Registry)

**Mô tả:** Fully managed Docker container registry để lưu trữ, quản lý, và deploy Docker images.

**Vai trò trong dự án:**
- Lưu trữ Docker images cho server, charting, và migrations
- Version control cho images
- Image scanning và encryption
- Integration với ECS để pull images

**Module sử dụng:**
- `aws/build-and-push.sh` - Build và push images
- `aws/list-ecr-images.sh` - List images
- `aws/test-ecr-permissions.sh` - Test permissions
- `aws/fix-ecr-403.sh` - Fix permission errors

### 3. Fargate

**Mô tả:** Serverless compute engine cho containers, không cần quản lý servers, EC2 instances, hoặc clusters.

**Vai trò trong dự án:**
- Compute platform cho tất cả ECS tasks
- Không cần quản lý EC2 instances
- Auto-scaling infrastructure
- Pay-per-use pricing

**Module sử dụng:**
- `aws/ecs-task-definitions/*.json` - Tất cả task definitions sử dụng Fargate
- `aws/create-ecs-services.sh` - Launch type: FARGATE

### 4. IAM (Identity and Access Management)

**Mô tả:** Dịch vụ quản lý quyền truy cập và bảo mật, kiểm soát ai có thể làm gì với tài nguyên AWS.

**Vai trò trong dự án:**
- Quản lý permissions cho deployment user
- ECS task execution roles để pull images và write logs
- ECS task roles để access AWS services
- Fine-grained access control

**Module sử dụng:**
- `aws/setup-iam-policy.sh` - Setup deployment permissions
- `aws/setup-ecs-roles.sh` - Setup ECS roles
- `aws/iam-policies/*.json` - Policy definitions

### 5. Secrets Manager

**Mô tả:** Dịch vụ lưu trữ và quản lý secrets (passwords, API keys, connection strings) một cách an toàn với encryption và rotation.

**Vai trò trong dự án:**
- Lưu trữ database connection strings
- Lưu trữ session encryption keys
- Secure credential management
- Integration với ECS để inject secrets vào containers

**Module sử dụng:**
- `aws/setup-session-key.sh` - Tạo session key secret
- `aws/setup-database-secrets.sh` - Setup database secrets
- `aws/create-database-secrets-from-services.sh` - Auto-create secrets
- `aws/export-database-urls.sh` - Export secrets để sử dụng

### 6. CloudWatch Logs

**Mô tả:** Dịch vụ logging tập trung, thu thập và lưu trữ logs từ các ứng dụng và services.

**Vai trò trong dự án:**
- Centralized logging cho tất cả services
- Log retention và search
- Integration với ECS tasks
- Debug và troubleshooting

**Module sử dụng:**
- `aws/ecs-task-definitions/*.json` - Log configuration
- `aws/create-ecs-services.sh` - Tạo log groups

### 7. Application Load Balancer (ALB)

**Mô tả:** Load balancer layer 7 (HTTP/HTTPS), phân phối traffic đến multiple targets, hỗ trợ content-based routing.

**Vai trò trong dự án:**
- Expose server service ra internet
- Health checks và auto failover
- SSL/TLS termination (có thể cấu hình)
- Path-based routing

**Module sử dụng:**
- `aws/setup-load-balancer.sh` - Tạo và cấu hình ALB
- `aws/test-create-station-api.sh` - Test qua ALB
- `aws/test-sensors-recently-api.sh` - Test API qua ALB

### 8. Network Load Balancer (NLB)

**Mô tả:** Load balancer layer 4 (TCP/UDP), xử lý traffic ở network level, phù hợp cho high performance và low latency.

**Vai trò trong dự án:**
- Expose PostgreSQL và TimescaleDB ra internet
- TCP load balancing cho database connections
- High performance cho database traffic

**Module sử dụng:**
- `aws/setup-postgres-public.sh` - Setup NLB cho PostgreSQL
- `aws/setup-timescale-public.sh` - Setup NLB cho TimescaleDB

### 9. VPC (Virtual Private Cloud)

**Mô tả:** Mạng ảo riêng biệt và cô lập trong AWS, cho phép kiểm soát network topology, IP addressing, và routing.

**Vai trò trong dự án:**
- Network isolation cho ECS tasks
- Control network connectivity
- Security boundaries
- Multi-AZ deployment

**Module sử dụng:**
- `aws/create-ecs-services.sh` - Deploy vào VPC
- `aws/deploy-database.sh` - Database trong VPC
- `aws/setup-postgres-public.sh` - VPC configuration
- `aws/setup-timescale-public.sh` - VPC configuration

## Tổng Kết

Dự án FieldKit sử dụng **60+ công nghệ và tính năng AWS** để xây dựng một kiến trúc cloud-native hoàn chỉnh. Các công nghệ chính bao gồm:

- **Container Orchestration**: ECS với Fargate
- **Image Registry**: ECR
- **Networking**: VPC, ALB, NLB, Security Groups, Subnets
- **Security**: IAM, Secrets Manager
- **Monitoring**: CloudWatch Logs
- **Storage**: S3 (cho media files)

Kiến trúc này đảm bảo:
- **Scalability**: Auto-scaling với ECS và Fargate
- **Security**: IAM, Secrets Manager, Security Groups
- **Reliability**: Multi-AZ deployment, health checks, load balancing
- **Cost-effectiveness**: Pay-per-use với Fargate, không cần quản lý infrastructure
- **Operational Excellence**: Centralized logging, monitoring, và automation

