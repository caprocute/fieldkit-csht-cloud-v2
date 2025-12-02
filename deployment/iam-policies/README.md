# IAM Policies cho Deployment

Các IAM policies cần thiết để deploy FieldKit lên AWS.

## Setup IAM Policies

### 1. Tạo IAM Policy cho Deployment User/Role

#### Option A: Sử dụng Full Policy (Khuyến nghị)

```bash
# Thay thế ACCOUNT_ID trong file
sed 's/ACCOUNT_ID/123456789012/g' deployment/iam-policies/deployment-full-policy.json > /tmp/deployment-policy.json

# Tạo policy
aws iam create-policy \
    --policy-name FieldKitDeploymentPolicy \
    --policy-document file:///tmp/deployment-policy.json \
    --region ap-southeast-1

# Attach policy vào user hoặc role
# Với IAM User:
aws iam attach-user-policy \
    --user-name your-username \
    --policy-arn arn:aws:iam::123456789012:policy/FieldKitDeploymentPolicy

# Với IAM Role:
aws iam attach-role-policy \
    --role-name your-role-name \
    --policy-arn arn:aws:iam::123456789012:policy/FieldKitDeploymentPolicy
```

#### Option B: Sử dụng từng Policy riêng

Có thể tạo từng policy riêng cho ECR, ECS, Secrets Manager, CloudWatch:

```bash
# ECR Policy
aws iam create-policy \
    --policy-name FieldKitECRPolicy \
    --policy-document file://deployment/iam-policies/ecr-policy.json \
    --region ap-southeast-1

# ECS Policy  
aws iam create-policy \
    --policy-name FieldKitECSPolicy \
    --policy-document file://deployment/iam-policies/ecs-policy.json \
    --region ap-southeast-1

# Secrets Manager Policy
aws iam create-policy \
    --policy-name FieldKitSecretsPolicy \
    --policy-document file://deployment/iam-policies/secrets-policy.json \
    --region ap-southeast-1

# CloudWatch Logs Policy
aws iam create-policy \
    --policy-name FieldKitCloudWatchPolicy \
    --policy-document file://deployment/iam-policies/cloudwatch-policy.json \
    --region ap-southeast-1
```

## ECS Task Execution Role

Role này được sử dụng bởi ECS để pull images từ ECR và write logs.

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "ecr:GetAuthorizationToken",
        "ecr:BatchCheckLayerAvailability",
        "ecr:GetDownloadUrlForLayer",
        "ecr:BatchGetImage"
      ],
      "Resource": "*"
    },
    {
      "Effect": "Allow",
      "Action": [
        "logs:CreateLogStream",
        "logs:PutLogEvents"
      ],
      "Resource": "arn:aws:logs:ap-southeast-1:ACCOUNT_ID:log-group:/ecs/fieldkit-*:*"
    },
    {
      "Effect": "Allow",
      "Action": [
        "secretsmanager:GetSecretValue"
      ],
      "Resource": "arn:aws:secretsmanager:ap-southeast-1:ACCOUNT_ID:secret:fieldkit/*"
    }
  ]
}
```

Tạo role:
```bash
# Tạo trust policy
cat > /tmp/ecs-trust-policy.json <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "ecs-tasks.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
EOF

# Tạo role
aws iam create-role \
    --role-name ecsTaskExecutionRole \
    --assume-role-policy-document file:///tmp/ecs-trust-policy.json

# Attach AWS managed policy (ECR và CloudWatch)
aws iam attach-role-policy \
    --role-name ecsTaskExecutionRole \
    --policy-arn arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy

# Hoặc tạo custom policy và attach
aws iam put-role-policy \
    --role-name ecsTaskExecutionRole \
    --policy-name ECSExecutionPolicy \
    --policy-document file://deployment/iam-policies/ecs-execution-policy.json
```

## ECS Task Role

Role này được sử dụng bởi ứng dụng trong container (tùy chọn, nếu app cần access AWS services).

```bash
# Tạo role cho application
aws iam create-role \
    --role-name ecsTaskRole \
    --assume-role-policy-document file:///tmp/ecs-trust-policy.json

# Attach policies nếu cần (ví dụ: S3, Secrets Manager, etc.)
```

## Minimum Required Permissions

Nếu chỉ cần quyền tối thiểu để deploy:

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "ecr:GetAuthorizationToken",
        "ecr:CreateRepository",
        "ecr:DescribeRepositories",
        "ecr:BatchGetImage",
        "ecr:PutImage"
      ],
      "Resource": "*"
    },
    {
      "Effect": "Allow",
      "Action": [
        "ecs:DescribeClusters",
        "ecs:ListServices",
        "ecs:DescribeServices",
        "ecs:UpdateService",
        "ecs:RegisterTaskDefinition",
        "ecs:DescribeTaskDefinition"
      ],
      "Resource": "*"
    }
  ]
}
```

## Kiểm tra Permissions

Sau khi attach policies, kiểm tra lại:

```bash
# Kiểm tra user/role có policy chưa
aws iam list-attached-user-policies --user-name your-username
aws iam list-attached-role-policies --role-name your-role-name

# Test permissions
./deployment/check-prerequisites.sh
```

## Lưu ý

1. **ECR**: `GetAuthorizationToken` cần `Resource: *` (không thể scope)
2. **ECS**: Một số actions cần `Resource: *` hoặc wildcard cluster/service ARN
3. **Least Privilege**: Nên bắt đầu với full policy, sau đó thu hẹp theo nhu cầu thực tế
4. **Cross-account**: Nếu deploy từ account khác, cần thêm trust relationships

## Troubleshooting

Nếu gặp lỗi "Access Denied":

1. Kiểm tra policy đã được attach:
   ```bash
   aws iam list-attached-user-policies --user-name your-username
   ```

2. Kiểm tra inline policies:
   ```bash
   aws iam list-user-policies --user-name your-username
   ```

3. Test từng permission:
   ```bash
   aws ecr get-authorization-token --region ap-southeast-1
   aws ecr describe-repositories --region ap-southeast-1
   ```

4. Kiểm tra CloudTrail logs để xem action nào bị deny

