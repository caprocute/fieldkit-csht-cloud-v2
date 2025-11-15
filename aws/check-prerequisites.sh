#!/bin/bash

# Script để kiểm tra các prerequisites trước khi deploy
# Sử dụng: ./deployment/check-prerequisites.sh

# Không dùng set -e vì cần xử lý lỗi permissions một cách graceful

echo "=========================================="
echo "Checking Deployment Prerequisites"
echo "=========================================="

ERRORS=0

# Check AWS CLI
echo ""
echo "1. Checking AWS CLI..."
if ! command -v aws &> /dev/null; then
    echo "   ❌ AWS CLI chưa được cài đặt"
    echo "      Cài đặt: https://aws.amazon.com/cli/"
    ERRORS=$((ERRORS + 1))
else
    AWS_VERSION=$(aws --version)
    echo "   ✅ AWS CLI: $AWS_VERSION"
fi

# Check AWS credentials
echo ""
echo "2. Checking AWS credentials..."
if ! aws sts get-caller-identity &> /dev/null; then
    echo "   ❌ AWS credentials chưa được cấu hình"
    echo "      Chạy: aws configure"
    ERRORS=$((ERRORS + 1))
else
    CALLER_IDENTITY=$(aws sts get-caller-identity)
    ACCOUNT_ID=$(echo $CALLER_IDENTITY | jq -r '.Account')
    USER_ARN=$(echo $CALLER_IDENTITY | jq -r '.Arn')
    echo "   ✅ AWS Account ID: $ACCOUNT_ID"
    echo "   ✅ User/Role: $USER_ARN"
    
    # Check if AWS_ACCOUNT_ID matches
    if [ -n "$AWS_ACCOUNT_ID" ] && [ "$AWS_ACCOUNT_ID" != "$ACCOUNT_ID" ]; then
        echo "   ⚠️  Warning: AWS_ACCOUNT_ID ($AWS_ACCOUNT_ID) không khớp với account hiện tại ($ACCOUNT_ID)"
    fi
fi

# Check AWS permissions
echo ""
echo "3. Checking AWS permissions..."
AWS_REGION=${AWS_REGION:-ap-southeast-1}

# ECR permissions
if aws ecr describe-repositories --region $AWS_REGION &> /dev/null; then
    echo "   ✅ ECR permissions: OK"
else
    echo "   ❌ ECR permissions: FAILED"
    echo "      Cần quyền: ecr:DescribeRepositories, ecr:GetAuthorizationToken, ecr:CreateRepository"
    echo "      Xem hướng dẫn: deployment/iam-policies/README.md"
    echo "      Hoặc chạy: cat deployment/iam-policies/deployment-full-policy.json"
    ERRORS=$((ERRORS + 1))
fi

# ECS permissions
if aws ecs list-clusters --region $AWS_REGION &> /dev/null; then
    echo "   ✅ ECS permissions: OK"
else
    echo "   ❌ ECS permissions: FAILED"
    echo "      Cần quyền: ecs:ListClusters, ecs:DescribeClusters"
    ERRORS=$((ERRORS + 1))
fi

# Secrets Manager permissions
if aws secretsmanager list-secrets --region $AWS_REGION --max-items 1 &> /dev/null; then
    echo "   ✅ Secrets Manager permissions: OK"
else
    ERROR_MSG=$(aws secretsmanager list-secrets --region $AWS_REGION --max-items 1 2>&1 || true)
    if echo "$ERROR_MSG" | grep -q "AccessDenied\|UnauthorizedOperation"; then
        echo "   ❌ Secrets Manager permissions: FAILED"
        echo "      Cần quyền: secretsmanager:ListSecrets, secretsmanager:GetSecretValue"
        echo "      Xem: deployment/iam-policies/secrets-policy.json"
        ERRORS=$((ERRORS + 1))
    else
        echo "   ⚠️  Secrets Manager permissions: Limited (có thể cần quyền cụ thể)"
        echo "      Lỗi: $ERROR_MSG"
    fi
fi

# CloudWatch Logs permissions
if aws logs describe-log-groups --region $AWS_REGION --max-items 1 &> /dev/null; then
    echo "   ✅ CloudWatch Logs permissions: OK"
else
    ERROR_MSG=$(aws logs describe-log-groups --region $AWS_REGION --max-items 1 2>&1 || true)
    if echo "$ERROR_MSG" | grep -q "AccessDenied\|UnauthorizedOperation"; then
        echo "   ❌ CloudWatch Logs permissions: FAILED"
        echo "      Cần quyền: logs:DescribeLogGroups, logs:CreateLogGroup"
        echo "      Xem: deployment/iam-policies/cloudwatch-policy.json"
        ERRORS=$((ERRORS + 1))
    else
        echo "   ⚠️  CloudWatch Logs permissions: Limited (có thể cần quyền cụ thể)"
        echo "      Lỗi: $ERROR_MSG"
    fi
fi

# IAM permissions
if aws iam list-roles --max-items 1 &> /dev/null; then
    echo "   ✅ IAM permissions: OK"
else
    ERROR_MSG=$(aws iam list-roles --max-items 1 2>&1 || true)
    if echo "$ERROR_MSG" | grep -q "AccessDenied\|UnauthorizedOperation"; then
        echo "   ⚠️  IAM permissions: Limited (không ảnh hưởng deployment, chỉ cần để check roles)"
        echo "      Lỗi: $ERROR_MSG"
    else
        echo "   ⚠️  IAM permissions: Limited (có thể cần quyền cụ thể)"
        echo "      Lỗi: $ERROR_MSG"
    fi
fi

# Check Docker
echo ""
echo "4. Checking Docker..."
if ! command -v docker &> /dev/null; then
    echo "   ❌ Docker chưa được cài đặt"
    echo "      Cài đặt: https://docs.docker.com/get-docker/"
    ERRORS=$((ERRORS + 1))
else
    DOCKER_VERSION=$(docker --version)
    echo "   ✅ Docker: $DOCKER_VERSION"
    
    # Check if Docker daemon is running
    if docker info &> /dev/null; then
        echo "   ✅ Docker daemon: Running"
    else
        echo "   ❌ Docker daemon: Not running"
        echo "      Khởi động Docker và thử lại"
        ERRORS=$((ERRORS + 1))
    fi
fi

# Check jq
echo ""
echo "5. Checking jq..."
if ! command -v jq &> /dev/null; then
    echo "   ❌ jq chưa được cài đặt"
    echo "      macOS: brew install jq"
    echo "      Linux: apt-get install jq hoặc yum install jq"
    ERRORS=$((ERRORS + 1))
else
    JQ_VERSION=$(jq --version)
    echo "   ✅ jq: $JQ_VERSION"
fi

# Check environment variables
echo ""
echo "6. Checking environment variables..."
if [ -z "$AWS_ACCOUNT_ID" ]; then
    echo "   ⚠️  AWS_ACCOUNT_ID chưa được set"
    echo "      export AWS_ACCOUNT_ID=\"123456789012\""
else
    echo "   ✅ AWS_ACCOUNT_ID: $AWS_ACCOUNT_ID"
fi

if [ -z "$AWS_REGION" ]; then
    echo "   ⚠️  AWS_REGION chưa được set (sử dụng mặc định: ap-southeast-1)"
else
    echo "   ✅ AWS_REGION: $AWS_REGION"
fi

# Summary
echo ""
echo "=========================================="
if [ $ERRORS -eq 0 ]; then
    echo "✅ Tất cả prerequisites đã sẵn sàng!"
    echo "=========================================="
    exit 0
else
    echo "❌ Có $ERRORS lỗi cần được khắc phục trước khi deploy"
    echo "=========================================="
    exit 1
fi

