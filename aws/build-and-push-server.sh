#!/bin/bash

# Script để build và push chỉ Server image (không build migration)
# Sử dụng: ./deployment/build-and-push-server.sh [VERSION] [ENVIRONMENT]
# Ví dụ: ./deployment/build-and-push-server.sh latest staging

set -e

VERSION=${1:-$(git describe --tags --always --dirty || echo "dev")}
ENVIRONMENT=${2:-staging}
GIT_HASH=$(git rev-parse --short HEAD 2>/dev/null || echo "unknown")

# AWS Configuration
AWS_REGION=${AWS_REGION:-ap-southeast-1}

# Xử lý AWS_PROFILE (optional)
if [ -n "$AWS_PROFILE" ]; then
    if ! aws configure list-profiles 2>/dev/null | grep -q "^${AWS_PROFILE}$"; then
        echo "⚠️  Warning: AWS_PROFILE '${AWS_PROFILE}' không tồn tại."
        echo "   Đang sử dụng default credentials thay vì profile."
        unset AWS_PROFILE
    else
        export AWS_PROFILE
        echo "✅ Sử dụng AWS profile: ${AWS_PROFILE}"
    fi
fi

# Validate AWS_ACCOUNT_ID - Luôn lấy từ AWS credentials
echo "Đang lấy AWS Account ID từ credentials..."
DETECTED_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text 2>/dev/null || echo "")

if [ -z "$DETECTED_ACCOUNT_ID" ]; then
    echo "Error: Không thể lấy AWS_ACCOUNT_ID từ AWS credentials."
    echo "Kiểm tra:"
    echo "  1. AWS credentials đã được cấu hình: aws configure"
    echo "  2. AWS CLI có quyền sts:GetCallerIdentity"
    exit 1
fi

AWS_ACCOUNT_ID="$DETECTED_ACCOUNT_ID"
echo "✅ AWS Account ID: ${AWS_ACCOUNT_ID}"

# Validate AWS_ACCOUNT_ID format
if ! [[ "$AWS_ACCOUNT_ID" =~ ^[0-9]{12}$ ]]; then
    echo "Error: AWS_ACCOUNT_ID không hợp lệ: ${AWS_ACCOUNT_ID}"
    exit 1
fi

ECR_REGISTRY="${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com"
REPO_PREFIX="hieuhk_fieldkit"

# Validate ECR_REGISTRY
if [ -z "$ECR_REGISTRY" ] || [[ "$ECR_REGISTRY" == ".dkr.ecr"* ]] || [[ ! "$ECR_REGISTRY" =~ ^[0-9]+\.dkr\.ecr\. ]]; then
    echo "Error: ECR_REGISTRY không hợp lệ: '${ECR_REGISTRY}'"
    exit 1
fi

# Image names
SERVER_IMAGE="${REPO_PREFIX}/server"

# Full image tags
SERVER_TAG="${ECR_REGISTRY}/${SERVER_IMAGE}:${VERSION}"
SERVER_LATEST="${ECR_REGISTRY}/${SERVER_IMAGE}:latest"

echo "=========================================="
echo "Building and Pushing Server Image Only"
echo "=========================================="
echo "Version: ${VERSION}"
echo "Environment: ${ENVIRONMENT}"
echo "Git Hash: ${GIT_HASH}"
echo "AWS Account ID: ${AWS_ACCOUNT_ID}"
echo "AWS Region: ${AWS_REGION}"
echo "ECR Registry: ${ECR_REGISTRY}"
echo "=========================================="

# Login to ECR
echo "Đang đăng nhập vào AWS ECR..."
if ! aws ecr get-login-password --region ${AWS_REGION} | docker login --username AWS --password-stdin ${ECR_REGISTRY}; then
    echo "Error: Không thể đăng nhập vào ECR."
    exit 1
fi
echo "✅ Đăng nhập ECR thành công"

# Tạo ECR repository nếu chưa tồn tại
echo "Đang kiểm tra và tạo ECR repository..."
if ! aws ecr describe-repositories --repository-names ${SERVER_IMAGE} --region ${AWS_REGION} &>/dev/null; then
    echo "Tạo repository: ${SERVER_IMAGE}"
    if ! aws ecr create-repository \
        --repository-name ${SERVER_IMAGE} \
        --region ${AWS_REGION} \
        --image-scanning-configuration scanOnPush=true \
        --encryption-configuration encryptionType=AES256; then
        echo "Error: Không thể tạo repository ${SERVER_IMAGE}."
        exit 1
    fi
    echo "✅ Repository ${SERVER_IMAGE} đã được tạo"
else
    echo "✅ Repository ${SERVER_IMAGE} đã tồn tại"
fi

# Build Server Image
echo "Đang build Server image..."
cp portal/src/secrets.ts.aws portal/src/secrets.ts 2>/dev/null || cp portal/src/secrets.ts.template portal/src/secrets.ts
docker build \
    --platform linux/amd64 \
    -t ${SERVER_TAG} \
    -t ${SERVER_LATEST} \
    --build-arg GIT_HASH=${GIT_HASH} \
    --build-arg VERSION=${VERSION} \
    -f Dockerfile \
    .

# Push Server Image
echo "Đang push Server image..."
if ! docker push ${SERVER_TAG}; then
    echo "Error: Không thể push ${SERVER_TAG}"
    exit 1
fi
if ! docker push ${SERVER_LATEST}; then
    echo "Warning: Không thể push ${SERVER_LATEST}, nhưng ${SERVER_TAG} đã thành công"
fi
echo "✅ Server image đã được push"

echo "=========================================="
echo "Build và Push hoàn tất!"
echo "=========================================="
echo "Server: ${SERVER_TAG}"
echo ""
echo "Để deploy, chạy: ./deployment/update-server-task-definition.sh ${ENVIRONMENT} ${VERSION}"
echo "Hoặc: ./deployment/deploy-server-only.sh ${VERSION} ${ENVIRONMENT}"
echo "=========================================="

