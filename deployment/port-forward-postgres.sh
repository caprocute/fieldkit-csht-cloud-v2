#!/bin/bash

# Script để port forward PostgreSQL từ ECS Fargate container ra localhost
# Sử dụng: ./deployment/port-forward-postgres.sh [ENVIRONMENT] [LOCAL_PORT]
# Ví dụ: ./deployment/port-forward-postgres.sh staging 5432

set -e

ENVIRONMENT=${1:-staging}
LOCAL_PORT=${2:-5432}

AWS_REGION=${AWS_REGION:-ap-southeast-1}
AWS_ACCOUNT_ID=${AWS_ACCOUNT_ID:-""}

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

CLUSTER_NAME="fieldkit-${ENVIRONMENT}-db-v1"
SERVICE_NAME="${CLUSTER_NAME}-postgres"

echo "=========================================="
echo "Port Forward PostgreSQL từ ECS"
echo "=========================================="
echo "Environment: ${ENVIRONMENT}"
echo "Cluster: ${CLUSTER_NAME}"
echo "Service: ${SERVICE_NAME}"
echo "Local Port: ${LOCAL_PORT}"
echo "=========================================="

# Lấy task ARN
echo "Đang tìm PostgreSQL task..."
TASK_ARN=$(aws ecs list-tasks \
    --cluster ${CLUSTER_NAME} \
    --service-name ${SERVICE_NAME} \
    --region ${AWS_REGION} \
    --query 'taskArns[0]' \
    --output text 2>/dev/null || echo "")

if [ -z "$TASK_ARN" ] || [ "$TASK_ARN" = "None" ] || [ "$TASK_ARN" = "null" ]; then
    echo "⚠️  Không tìm thấy running task cho service ${SERVICE_NAME}"
    echo ""
    echo "Kiểm tra service status:"
    aws ecs describe-services \
        --cluster ${CLUSTER_NAME} \
        --services ${SERVICE_NAME} \
        --region ${AWS_REGION} \
        --query 'services[0].{Status:status,DesiredCount:desiredCount,RunningCount:runningCount}' \
        --output table
    echo ""
    echo "Nếu service chưa chạy, đảm bảo:"
    echo "  1. Database services đã được deploy: ./deployment/deploy-database.sh ${ENVIRONMENT}"
    echo "  2. Database secrets đã được setup"
    echo "  3. ECS roles đã được tạo: ./deployment/setup-ecs-roles.sh"
    exit 1
fi

echo "✅ Tìm thấy task: ${TASK_ARN}"

# Lấy task details để check container name
CONTAINER_NAME=$(aws ecs describe-tasks \
    --cluster ${CLUSTER_NAME} \
    --tasks ${TASK_ARN} \
    --region ${AWS_REGION} \
    --query 'tasks[0].containers[0].name' \
    --output text)

echo "✅ Container name: ${CONTAINER_NAME}"

echo ""
echo "Đang thiết lập port forwarding..."
echo "PostgreSQL sẽ accessible tại: localhost:${LOCAL_PORT}"
echo ""
echo "Để kết nối:"
echo "  psql -h localhost -p ${LOCAL_PORT} -U fieldkit -d fieldkit"
echo ""
echo "Hoặc với connection string:"
echo "  postgres://fieldkit:PASSWORD@localhost:${LOCAL_PORT}/fieldkit"
echo ""
echo "⚠️  Lưu ý: Cần PostgreSQL password từ Secrets Manager:"
echo "  aws secretsmanager get-secret-value --secret-id fieldkit/${ENVIRONMENT}/database/postgres/password --region ${AWS_REGION} --query SecretString --output text"
echo ""
echo "Nhấn Ctrl+C để dừng port forwarding..."
echo ""

# Port forward sử dụng ECS Exec
aws ecs execute-command \
    --cluster ${CLUSTER_NAME} \
    --task ${TASK_ARN} \
    --container ${CONTAINER_NAME} \
    --interactive \
    --command "/bin/sh" \
    --region ${AWS_REGION} || {
    echo ""
    echo "⚠️  ECS Exec không khả dụng. Sử dụng phương pháp khác..."
    echo ""
    echo "Option 1: Sử dụng AWS Systems Manager Session Manager (nếu có EC2 bastion)"
    echo "Option 2: Tạo bastion host trong public subnet"
    echo "Option 3: Sử dụng AWS RDS thay vì container (khuyến nghị cho production)"
    echo ""
    echo "Để enable ECS Exec, cần:"
    echo "  1. Enable ECS Exec trên service:"
    echo "     aws ecs update-service --cluster ${CLUSTER_NAME} --service ${SERVICE_NAME} --enable-execute-command --region ${AWS_REGION}"
    echo "  2. Đảm bảo task role có quyền ssm:StartSession"
    exit 1
}

