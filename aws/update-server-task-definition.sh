#!/bin/bash

# Script để cập nhật Server task definition
# Sử dụng: ./deployment/update-server-task-definition.sh [ENVIRONMENT] [VERSION]
# Ví dụ: ./deployment/update-server-task-definition.sh staging latest

set -e

ENVIRONMENT=${1:-staging}
VERSION=${2:-latest}
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

# Lấy ECR registry
ECR_REGISTRY="${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com"
REPO_PREFIX="hieuhk_fieldkit"

echo "=========================================="
echo "Cập nhật Server Task Definition"
echo "=========================================="
echo "Environment: ${ENVIRONMENT}"
echo "Version: ${VERSION}"
echo "AWS Account ID: ${AWS_ACCOUNT_ID}"
echo "Region: ${AWS_REGION}"
echo "ECR Registry: ${ECR_REGISTRY}"
echo "=========================================="
echo ""

# Kiểm tra task definition file
TASK_DEF_FILE="deployment/ecs-task-definitions/server-task.json"
if [ ! -f "$TASK_DEF_FILE" ]; then
    echo "❌ Task definition file không tồn tại: ${TASK_DEF_FILE}"
    exit 1
fi

# Thay thế placeholders
TEMP_TASK_DEF=$(mktemp)
sed -e "s/ACCOUNT_ID/${AWS_ACCOUNT_ID}/g" \
    -e "s/REGION/${AWS_REGION}/g" \
    -e "s/NAMESPACE/${ENVIRONMENT}/g" \
    "$TASK_DEF_FILE" > "$TEMP_TASK_DEF"

# Cập nhật image URI với version
IMAGE_URI="${ECR_REGISTRY}/${REPO_PREFIX}/server:${VERSION}"
jq --arg img "$IMAGE_URI" '.containerDefinitions[0].image = $img' "$TEMP_TASK_DEF" > "${TEMP_TASK_DEF}.tmp"
mv "${TEMP_TASK_DEF}.tmp" "$TEMP_TASK_DEF"

echo "✅ Đã thay thế placeholders và cập nhật image: ${IMAGE_URI}"
echo ""

# Đăng ký task definition mới
echo "Đang đăng ký task definition mới..."
NEW_TASK_DEF_ARN=$(aws ecs register-task-definition \
    --cli-input-json file://"$TEMP_TASK_DEF" \
    --region ${AWS_REGION} \
    --query 'taskDefinition.taskDefinitionArn' \
    --output text 2>/dev/null)

if [ $? -eq 0 ] && [ -n "$NEW_TASK_DEF_ARN" ]; then
    echo "✅ Task definition đã được đăng ký: ${NEW_TASK_DEF_ARN}"
    rm "$TEMP_TASK_DEF"
else
    echo "❌ Lỗi khi đăng ký task definition"
    rm "$TEMP_TASK_DEF"
    exit 1
fi

echo ""
echo "=========================================="
echo "Cập nhật Server Service"
echo "=========================================="

CLUSTER_NAME="fieldkit-${ENVIRONMENT}-app"
SERVICE_NAME="${CLUSTER_NAME}-server"

# Kiểm tra service có tồn tại không
SERVICE_EXISTS=$(aws ecs describe-services \
    --cluster ${CLUSTER_NAME} \
    --services ${SERVICE_NAME} \
    --region ${AWS_REGION} \
    --query 'services[0].status' \
    --output text 2>/dev/null || echo "NOT_FOUND")

if [ "$SERVICE_EXISTS" = "NOT_FOUND" ] || [ "$SERVICE_EXISTS" = "None" ] || [ "$SERVICE_EXISTS" = "null" ] || [ -z "$SERVICE_EXISTS" ]; then
    echo "⚠️  Service ${SERVICE_NAME} chưa tồn tại."
    echo "   Cần tạo service trước. Chạy:"
    echo "   ./deployment/create-ecs-services.sh ${ENVIRONMENT}"
    echo ""
    echo "Task definition đã được đăng ký và sẵn sàng sử dụng."
    exit 0
fi

echo "✅ Service ${SERVICE_NAME} đã tồn tại"
echo ""

# Cập nhật service với task definition mới
echo "Đang cập nhật service với task definition mới..."
aws ecs update-service \
    --cluster ${CLUSTER_NAME} \
    --service ${SERVICE_NAME} \
    --task-definition ${NEW_TASK_DEF_ARN} \
    --force-new-deployment \
    --region ${AWS_REGION} > /dev/null

if [ $? -eq 0 ]; then
    echo "✅ Service đã được cập nhật và đang restart với task definition mới"
    echo ""
    echo "Đang đợi service stable (có thể mất vài phút)..."
    echo "   (Nhấn Ctrl+C để bỏ qua và kiểm tra sau)"
    echo ""
    
    # Đợi service stable (có timeout)
    aws ecs wait services-stable \
        --cluster ${CLUSTER_NAME} \
        --services ${SERVICE_NAME} \
        --region ${AWS_REGION} 2>/dev/null || {
        echo ""
        echo "⚠️  Service đang restart. Kiểm tra status:"
        echo "   aws ecs describe-services --cluster ${CLUSTER_NAME} --services ${SERVICE_NAME} --region ${AWS_REGION}"
    }
    
    echo ""
    echo "=========================================="
    echo "✅ Hoàn tất!"
    echo "=========================================="
    echo ""
    echo "Server service đã được cập nhật với:"
    echo "  - Task definition mới: ${NEW_TASK_DEF_ARN}"
    echo "  - Image: ${IMAGE_URI}"
    echo "  - FIELDKIT_TIME_SCALE_URL trỏ về cùng database với FIELDKIT_POSTGRES_URL"
    echo ""
    echo "Kiểm tra service status:"
    echo "   aws ecs describe-services --cluster ${CLUSTER_NAME} --services ${SERVICE_NAME} --region ${AWS_REGION}"
else
    echo "❌ Lỗi khi cập nhật service"
    exit 1
fi

