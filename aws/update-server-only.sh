#!/bin/bash

# Script để build và deploy chỉ server service (không build migration)
# Sử dụng: ./deployment/update-server-only.sh [VERSION] [ENVIRONMENT]
# Ví dụ: ./deployment/update-server-only.sh latest staging

set -e

VERSION=${1:-latest}
ENVIRONMENT=${2:-staging}
AWS_REGION=${AWS_REGION:-ap-southeast-1}

# Xử lý AWS_PROFILE (optional)
if [ -n "$AWS_PROFILE" ]; then
    if ! aws configure list-profiles 2>/dev/null | grep -q "^${AWS_PROFILE}$"; then
        echo "⚠️  Warning: AWS_PROFILE '${AWS_PROFILE}' không tồn tại. Sử dụng default credentials."
        unset AWS_PROFILE
    else
        export AWS_PROFILE
    fi
fi

# Validate AWS_ACCOUNT_ID - Luôn lấy từ AWS credentials
DETECTED_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text 2>/dev/null || echo "")

if [ -z "$DETECTED_ACCOUNT_ID" ]; then
    echo "Error: Không thể lấy AWS_ACCOUNT_ID từ AWS credentials."
    exit 1
fi

AWS_ACCOUNT_ID="$DETECTED_ACCOUNT_ID"

# Validate format
if ! [[ "$AWS_ACCOUNT_ID" =~ ^[0-9]{12}$ ]]; then
    echo "Error: AWS_ACCOUNT_ID không hợp lệ: ${AWS_ACCOUNT_ID}"
    exit 1
fi

ECR_REGISTRY="${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com"
REPO_PREFIX="hieuhk_fieldkit"
SERVER_IMAGE="${REPO_PREFIX}/server"
SERVER_TAG="${ECR_REGISTRY}/${SERVER_IMAGE}:${VERSION}"
SERVER_LATEST="${ECR_REGISTRY}/${SERVER_IMAGE}:latest"

echo "=========================================="
echo "Build và Deploy Server Service"
echo "=========================================="
echo "Version: ${VERSION}"
echo "Environment: ${ENVIRONMENT}"
echo "AWS Account ID: ${AWS_ACCOUNT_ID}"
echo "Region: ${AWS_REGION}"
echo "ECR Registry: ${ECR_REGISTRY}"
echo "=========================================="
echo ""

# Bước 1: Login to ECR
echo "📦 Bước 1: Đăng nhập vào AWS ECR..."
if ! aws ecr get-login-password --region ${AWS_REGION} | docker login --username AWS --password-stdin ${ECR_REGISTRY}; then
    echo "❌ Lỗi: Không thể đăng nhập vào ECR"
    exit 1
fi
echo "✅ Đăng nhập ECR thành công"
echo ""

# Bước 2: Kiểm tra và tạo ECR repository nếu chưa có
echo "📦 Bước 2: Kiểm tra ECR repository..."
if ! aws ecr describe-repositories --repository-names ${SERVER_IMAGE} --region ${AWS_REGION} &>/dev/null; then
    echo "Tạo repository: ${SERVER_IMAGE}"
    if ! aws ecr create-repository \
        --repository-name ${SERVER_IMAGE} \
        --region ${AWS_REGION} \
        --image-scanning-configuration scanOnPush=true \
        --encryption-configuration encryptionType=AES256; then
        echo "❌ Lỗi: Không thể tạo repository ${SERVER_IMAGE}"
        exit 1
    fi
    echo "✅ Repository ${SERVER_IMAGE} đã được tạo"
else
    echo "✅ Repository ${SERVER_IMAGE} đã tồn tại"
fi
echo ""

# Bước 3: Build Server Image
echo "📦 Bước 3: Build Server Docker image..."
cp portal/src/secrets.ts.aws portal/src/secrets.ts 2>/dev/null || cp portal/src/secrets.ts.template portal/src/secrets.ts

GIT_HASH=$(git rev-parse --short HEAD 2>/dev/null || echo "unknown")

if ! docker build \
    --platform linux/amd64 \
    -t ${SERVER_TAG} \
    -t ${SERVER_LATEST} \
    --build-arg GIT_HASH=${GIT_HASH} \
    --build-arg VERSION=${VERSION} \
    -f Dockerfile \
    .; then
    echo "❌ Lỗi: Không thể build Docker image"
    exit 1
fi
echo "✅ Build image thành công"
echo ""

# Bước 4: Push Server Image
echo "📦 Bước 4: Push Server image lên ECR..."
if ! docker push ${SERVER_TAG}; then
    echo "❌ Lỗi: Không thể push image ${SERVER_TAG}"
    exit 1
fi

if [ "$VERSION" != "latest" ]; then
    if ! docker push ${SERVER_LATEST}; then
        echo "⚠️  Warning: Không thể push latest tag"
    fi
fi
echo "✅ Push image thành công"
echo ""

# Bước 5: Update task definition và deploy
echo "🚀 Bước 5: Update task definition và deploy service..."
if ! ./deployment/update-server-task-definition.sh ${ENVIRONMENT} ${VERSION}; then
    echo "❌ Lỗi: Không thể update task definition và deploy"
    exit 1
fi

echo ""
echo "=========================================="
echo "✅ Hoàn tất!"
echo "=========================================="
echo ""
echo "Server service đã được deploy với:"
echo "  - Version: ${VERSION}"
echo "  - Environment: ${ENVIRONMENT}"
echo "  - Image: ${SERVER_TAG}"
echo "  - FIELDKIT_WORKERS: 5"
echo ""
echo "Kiểm tra service status:"
echo "  aws ecs describe-services --cluster fieldkit-${ENVIRONMENT}-app --services fieldkit-${ENVIRONMENT}-app-server --region ${AWS_REGION}"
echo ""
echo "Kiểm tra logs (sau 2-3 phút):"
echo "  ./docs/check-server-logs.sh ${ENVIRONMENT} 5m"

