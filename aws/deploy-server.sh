#!/bin/bash

# Script để build và deploy server service với code mới
# Sử dụng: ./deployment/deploy-server.sh [VERSION] [ENVIRONMENT]
# Ví dụ: ./deployment/deploy-server.sh latest staging

set -e

VERSION=${1:-latest}
ENVIRONMENT=${2:-staging}
AWS_REGION=${AWS_REGION:-ap-southeast-1}

echo "=========================================="
echo "Build và Deploy Server Service"
echo "=========================================="
echo "Version: ${VERSION}"
echo "Environment: ${ENVIRONMENT}"
echo "=========================================="
echo ""

# Bước 1: Build và push image
echo "📦 Bước 1: Build và push Docker image..."
echo ""

if ! ./deployment/build-and-push.sh ${VERSION} ${ENVIRONMENT}; then
    echo "❌ Lỗi khi build và push image"
    exit 1
fi

echo ""
echo "✅ Đã build và push image thành công"
echo ""

# Bước 2: Update task definition và deploy
echo "🚀 Bước 2: Update task definition và deploy service..."
echo ""

if ! ./deployment/update-server-task-definition.sh ${ENVIRONMENT} ${VERSION}; then
    echo "❌ Lỗi khi update task definition và deploy"
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
echo "  - FIELDKIT_WORKERS: 5"
echo ""
echo "Kiểm tra service status:"
echo "  aws ecs describe-services --cluster fieldkit-${ENVIRONMENT}-app --services fieldkit-${ENVIRONMENT}-app-server --region ${AWS_REGION}"
echo ""
echo "Kiểm tra logs (sau 2-3 phút):"
echo "  ./docs/check-server-logs.sh ${ENVIRONMENT} 5m"

