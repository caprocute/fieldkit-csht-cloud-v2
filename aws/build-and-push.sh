#!/bin/bash

# Script để build và push Docker images lên AWS ECR
# Sử dụng: ./deployment/build-and-push.sh [VERSION] [ENVIRONMENT]
# Ví dụ: ./deployment/build-and-push.sh v1.0.0 staging

set -e

VERSION=${1:-$(git describe --tags --always --dirty || echo "dev")}
ENVIRONMENT=${2:-staging}
GIT_HASH=$(git rev-parse --short HEAD 2>/dev/null || echo "unknown")

# AWS Configuration
AWS_REGION=${AWS_REGION:-ap-southeast-1}
AWS_ACCOUNT_ID=${AWS_ACCOUNT_ID:-"arn:aws:iam::585768163363"}

# Xử lý AWS_PROFILE (optional)
if [ -n "$AWS_PROFILE" ]; then
    # Kiểm tra profile có tồn tại không
    if ! aws configure list-profiles 2>/dev/null | grep -q "^${AWS_PROFILE}$"; then
        echo "⚠️  Warning: AWS_PROFILE '${AWS_PROFILE}' không tồn tại."
        echo "   Đang sử dụng default credentials thay vì profile."
        echo "   Để tạo profile, chạy: aws configure --profile ${AWS_PROFILE}"
        echo ""
        unset AWS_PROFILE
    else
        export AWS_PROFILE
        echo "✅ Sử dụng AWS profile: ${AWS_PROFILE}"
    fi
fi

# Validate AWS_ACCOUNT_ID - Luôn lấy từ AWS credentials để đảm bảo đúng
echo "Đang lấy AWS Account ID từ credentials..."
DETECTED_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text 2>/dev/null || echo "")

if [ -z "$DETECTED_ACCOUNT_ID" ]; then
    echo "Error: Không thể lấy AWS_ACCOUNT_ID từ AWS credentials."
    echo "Kiểm tra:"
    echo "  1. AWS credentials đã được cấu hình: aws configure"
    echo "  2. AWS CLI có quyền sts:GetCallerIdentity"
    exit 1
fi

# Nếu AWS_ACCOUNT_ID được set nhưng khác với detected, cảnh báo
if [ -n "$AWS_ACCOUNT_ID" ] && [ "$AWS_ACCOUNT_ID" != "$DETECTED_ACCOUNT_ID" ]; then
    echo "⚠️  Warning: AWS_ACCOUNT_ID từ environment (${AWS_ACCOUNT_ID}) khác với Account ID thực tế (${DETECTED_ACCOUNT_ID})"
    echo "   Đang sử dụng Account ID thực tế: ${DETECTED_ACCOUNT_ID}"
fi

# Luôn sử dụng Account ID từ credentials
AWS_ACCOUNT_ID="$DETECTED_ACCOUNT_ID"
echo "✅ AWS Account ID: ${AWS_ACCOUNT_ID}"

# Validate AWS_ACCOUNT_ID format (phải là 12 chữ số)
if ! [[ "$AWS_ACCOUNT_ID" =~ ^[0-9]{12}$ ]]; then
    echo "Error: AWS_ACCOUNT_ID không hợp lệ: ${AWS_ACCOUNT_ID}"
    echo "AWS_ACCOUNT_ID phải là 12 chữ số (ví dụ: 123456789012)"
    exit 1
fi

ECR_REGISTRY="${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com"
REPO_PREFIX="hieuhk_fieldkit"

# Validate ECR_REGISTRY không rỗng và có đầy đủ thông tin
if [ -z "$ECR_REGISTRY" ] || [[ "$ECR_REGISTRY" == ".dkr.ecr"* ]] || [[ ! "$ECR_REGISTRY" =~ ^[0-9]+\.dkr\.ecr\. ]]; then
    echo "Error: ECR_REGISTRY không hợp lệ: '${ECR_REGISTRY}'"
    echo "Kiểm tra AWS_ACCOUNT_ID: '${AWS_ACCOUNT_ID}'"
    echo "Kiểm tra AWS_REGION: '${AWS_REGION}'"
    exit 1
fi

# Image names
SERVER_IMAGE="${REPO_PREFIX}/server"
PORTAL_IMAGE="${REPO_PREFIX}/portal"
CHARTING_IMAGE="${REPO_PREFIX}/charting"
MIGRATIONS_IMAGE="${REPO_PREFIX}/migrations"

# Full image tags
SERVER_TAG="${ECR_REGISTRY}/${SERVER_IMAGE}:${VERSION}"
SERVER_LATEST="${ECR_REGISTRY}/${SERVER_IMAGE}:latest"
CHARTING_TAG="${ECR_REGISTRY}/${CHARTING_IMAGE}:${VERSION}"
CHARTING_LATEST="${ECR_REGISTRY}/${CHARTING_IMAGE}:latest"
MIGRATIONS_TAG="${ECR_REGISTRY}/${MIGRATIONS_IMAGE}:${VERSION}"
MIGRATIONS_LATEST="${ECR_REGISTRY}/${MIGRATIONS_IMAGE}:latest"

echo "=========================================="
echo "Building and Pushing Docker Images"
echo "=========================================="
echo "Version: ${VERSION}"
echo "Environment: ${ENVIRONMENT}"
echo "Git Hash: ${GIT_HASH}"
echo "AWS Account ID: ${AWS_ACCOUNT_ID}"
echo "AWS Region: ${AWS_REGION}"
echo "ECR Registry: ${ECR_REGISTRY}"
echo "=========================================="

# Final validation before proceeding
if [ -z "$AWS_ACCOUNT_ID" ] || [ -z "$ECR_REGISTRY" ]; then
    echo "Error: AWS_ACCOUNT_ID hoặc ECR_REGISTRY không hợp lệ"
    echo "AWS_ACCOUNT_ID: ${AWS_ACCOUNT_ID}"
    echo "ECR_REGISTRY: ${ECR_REGISTRY}"
    exit 1
fi

# Login to ECR
echo "Đang đăng nhập vào AWS ECR..."
if ! aws ecr get-login-password --region ${AWS_REGION} | docker login --username AWS --password-stdin ${ECR_REGISTRY}; then
    echo "Error: Không thể đăng nhập vào ECR. Kiểm tra:"
    echo "  1. AWS credentials đã được cấu hình đúng"
    echo "  2. Có quyền ecr:GetAuthorizationToken"
    echo "  3. AWS_ACCOUNT_ID và AWS_REGION đúng"
    exit 1
fi
echo "✅ Đăng nhập ECR thành công"

# Tạo ECR repositories nếu chưa tồn tại
echo "Đang kiểm tra và tạo ECR repositories..."
for repo in "${SERVER_IMAGE}" "${CHARTING_IMAGE}" "${MIGRATIONS_IMAGE}"; do
    if ! aws ecr describe-repositories --repository-names ${repo} --region ${AWS_REGION} &>/dev/null; then
        echo "Tạo repository: ${repo}"
        if ! aws ecr create-repository \
            --repository-name ${repo} \
            --region ${AWS_REGION} \
            --image-scanning-configuration scanOnPush=true \
            --encryption-configuration encryptionType=AES256; then
            echo "Error: Không thể tạo repository ${repo}. Kiểm tra quyền ecr:CreateRepository"
            exit 1
        fi
        echo "✅ Repository ${repo} đã được tạo"
    else
        echo "✅ Repository ${repo} đã tồn tại"
    fi
done

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
    echo "Kiểm tra:"
    echo "  1. Quyền ecr:PutImage, ecr:InitiateLayerUpload, ecr:UploadLayerPart, ecr:CompleteLayerUpload"
    echo "  2. Docker authentication token còn hiệu lực"
    echo "  3. Repository ARN đúng trong IAM policy"
    exit 1
fi
if ! docker push ${SERVER_LATEST}; then
    echo "Warning: Không thể push ${SERVER_LATEST}, nhưng ${SERVER_TAG} đã thành công"
fi
echo "✅ Server image đã được push"

# Build Charting Image
echo "Đang build Charting image..."
cd charting
tar -czh --exclude='./node_modules' . | docker build \
    --platform linux/amd64 \
    -t ${CHARTING_TAG} \
    -t ${CHARTING_LATEST} \
    --build-arg GIT_HASH=${GIT_HASH} \
    --build-arg VERSION=${VERSION} \
    -
cd ..

# Push Charting Image
echo "Đang push Charting image..."
if ! docker push ${CHARTING_TAG}; then
    echo "Error: Không thể push ${CHARTING_TAG}"
    echo "Kiểm tra quyền ECR và authentication"
    exit 1
fi
if ! docker push ${CHARTING_LATEST}; then
    echo "Warning: Không thể push ${CHARTING_LATEST}, nhưng ${CHARTING_TAG} đã thành công"
fi
echo "✅ Charting image đã được push"

# Build Migrations Image
echo "Đang build Migrations image..."
cd migrations
docker build \
    --platform linux/amd64 \
    -t ${MIGRATIONS_TAG} \
    -t ${MIGRATIONS_LATEST} \
    .
cd ..

# Push Migrations Image
echo "Đang push Migrations image..."
if ! docker push ${MIGRATIONS_TAG}; then
    echo "Error: Không thể push ${MIGRATIONS_TAG}"
    echo "Kiểm tra quyền ECR và authentication"
    exit 1
fi
if ! docker push ${MIGRATIONS_LATEST}; then
    echo "Warning: Không thể push ${MIGRATIONS_LATEST}, nhưng ${MIGRATIONS_TAG} đã thành công"
fi
echo "✅ Migrations image đã được push"

echo "=========================================="
echo "Build và Push hoàn tất!"
echo "=========================================="
echo "Server: ${SERVER_TAG}"
echo "Charting: ${CHARTING_TAG}"
echo "Migrations: ${MIGRATIONS_TAG}"
echo ""
echo "Để deploy, chạy: ./deployment/deploy.sh ${VERSION} ${ENVIRONMENT}"
echo "=========================================="

