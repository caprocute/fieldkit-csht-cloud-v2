#!/bin/bash

# Script để stop và cleanup các dịch vụ ECS để tránh phát sinh chi phí
# Sử dụng: ./deployment/stop-and-cleanup.sh [ENVIRONMENT] [OPTIONS]
# Options:
#   --delete-services: Xóa services (default: chỉ scale về 0)
#   --delete-cluster: Xóa cluster (default: giữ lại cluster)
#   --all: Xóa tất cả (services + cluster)

set -e

ENVIRONMENT=${1:-staging}
AWS_REGION=${AWS_REGION:-ap-southeast-1}

# Parse options
DELETE_SERVICES=false
DELETE_CLUSTER=false
DELETE_ALL=false

for arg in "$@"; do
    case $arg in
        --delete-services)
            DELETE_SERVICES=true
            ;;
        --delete-cluster)
            DELETE_CLUSTER=true
            ;;
        --all)
            DELETE_ALL=true
            DELETE_SERVICES=true
            DELETE_CLUSTER=true
            ;;
    esac
done

# Lấy Account ID từ credentials
AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text 2>/dev/null || echo "")
if [ -z "$AWS_ACCOUNT_ID" ]; then
    echo "Error: Không thể lấy AWS_ACCOUNT_ID từ credentials"
    exit 1
fi

CLUSTER_NAME="fieldkit-${ENVIRONMENT}"
SERVER_SERVICE="${CLUSTER_NAME}-server"
CHARTING_SERVICE="${CLUSTER_NAME}-charting"

echo "=========================================="
echo "Stop and Cleanup ECS Services"
echo "=========================================="
echo "Environment: ${ENVIRONMENT}"
echo "Cluster: ${CLUSTER_NAME}"
echo "Region: ${AWS_REGION}"
echo ""
echo "Actions:"
echo "  - Scale services về 0: YES"
[ "$DELETE_SERVICES" = true ] && echo "  - Xóa services: YES" || echo "  - Xóa services: NO"
[ "$DELETE_CLUSTER" = true ] && echo "  - Xóa cluster: YES" || echo "  - Xóa cluster: NO"
echo "=========================================="
echo ""

# Kiểm tra cluster tồn tại
CLUSTER_STATUS=$(aws ecs describe-clusters --clusters ${CLUSTER_NAME} --region ${AWS_REGION} --query 'clusters[0].status' --output text 2>/dev/null || echo "NOT_FOUND")

if [ "$CLUSTER_STATUS" != "ACTIVE" ] && [ "$CLUSTER_STATUS" != "INACTIVE" ]; then
    echo "⚠️  Cluster ${CLUSTER_NAME} không tồn tại. Không có gì để cleanup."
    exit 0
fi

# Stop và Scale Down Services
echo "1. Stopping services và scaling về 0..."

for service in "${SERVER_SERVICE}" "${CHARTING_SERVICE}"; do
    SERVICE_EXISTS=$(aws ecs describe-services \
        --cluster ${CLUSTER_NAME} \
        --services ${service} \
        --region ${AWS_REGION} \
        --query 'services[0].status' \
        --output text 2>/dev/null || echo "NOT_FOUND")
    
    if [ "$SERVICE_EXISTS" != "NOT_FOUND" ] && [ -n "$SERVICE_EXISTS" ]; then
        echo "   Đang scale ${service} về 0..."
        aws ecs update-service \
            --cluster ${CLUSTER_NAME} \
            --service ${service} \
            --desired-count 0 \
            --region ${AWS_REGION} > /dev/null
        
        echo "   ✅ ${service} đã được scale về 0"
        
        # Wait for tasks to stop
        echo "   Đang chờ tasks dừng..."
        aws ecs wait services-stable \
            --cluster ${CLUSTER_NAME} \
            --services ${service} \
            --region ${AWS_REGION} 2>/dev/null || true
        
        # Stop all running tasks
        RUNNING_TASKS=$(aws ecs list-tasks \
            --cluster ${CLUSTER_NAME} \
            --service-name ${service} \
            --region ${AWS_REGION} \
            --query 'taskArns[*]' \
            --output text 2>/dev/null || echo "")
        
        if [ -n "$RUNNING_TASKS" ]; then
            for task in $RUNNING_TASKS; do
                echo "   Đang stop task: ${task}"
                aws ecs stop-task \
                    --cluster ${CLUSTER_NAME} \
                    --task ${task} \
                    --region ${AWS_REGION} > /dev/null || true
            done
        fi
        
        echo "   ✅ ${service} đã được stop hoàn toàn"
    else
        echo "   ⚠️  Service ${service} không tồn tại, bỏ qua"
    fi
done

# Delete Services (nếu được yêu cầu)
if [ "$DELETE_SERVICES" = true ]; then
    echo ""
    echo "2. Xóa services..."
    
    for service in "${SERVER_SERVICE}" "${CHARTING_SERVICE}"; do
        SERVICE_EXISTS=$(aws ecs describe-services \
            --cluster ${CLUSTER_NAME} \
            --services ${service} \
            --region ${AWS_REGION} \
            --query 'services[0].status' \
            --output text 2>/dev/null || echo "NOT_FOUND")
        
        if [ "$SERVICE_EXISTS" != "NOT_FOUND" ] && [ -n "$SERVICE_EXISTS" ]; then
            echo "   Đang xóa service: ${service}..."
            aws ecs delete-service \
                --cluster ${CLUSTER_NAME} \
                --service ${service} \
                --force \
                --region ${AWS_REGION} > /dev/null
            
            echo "   ✅ Service ${service} đã được xóa"
        fi
    done
fi

# Delete Cluster (nếu được yêu cầu)
if [ "$DELETE_CLUSTER" = true ]; then
    echo ""
    echo "3. Xóa cluster..."
    
    # Kiểm tra còn services không
    REMAINING_SERVICES=$(aws ecs list-services \
        --cluster ${CLUSTER_NAME} \
        --region ${AWS_REGION} \
        --query 'length(serviceArns)' \
        --output text 2>/dev/null || echo "0")
    
    if [ "$REMAINING_SERVICES" != "0" ] && [ "$REMAINING_SERVICES" != "" ]; then
        echo "   ⚠️  Cluster vẫn còn ${REMAINING_SERVICES} services. Xóa services trước."
        echo "   Chạy lại với --delete-services để xóa services trước khi xóa cluster."
    else
        echo "   Đang xóa cluster: ${CLUSTER_NAME}..."
        aws ecs delete-cluster \
            --cluster ${CLUSTER_NAME} \
            --region ${AWS_REGION} > /dev/null
        
        echo "   ✅ Cluster ${CLUSTER_NAME} đã được xóa"
    fi
fi

# Summary
echo ""
echo "=========================================="
echo "Cleanup hoàn tất!"
echo "=========================================="
echo ""
echo "Tổng kết:"
echo "  - Services đã được scale về 0"
[ "$DELETE_SERVICES" = true ] && echo "  - Services đã được xóa"
[ "$DELETE_CLUSTER" = true ] && echo "  - Cluster đã được xóa"
echo ""
echo "Để khởi động lại:"
if [ "$DELETE_SERVICES" = true ]; then
    echo "  1. ./deployment/create-ecs-services.sh ${ENVIRONMENT}"
fi
echo "  2. ./deployment/build-and-push.sh v1.0.0 ${ENVIRONMENT}"
echo "  3. ./deployment/deploy.sh v1.0.0 ${ENVIRONMENT}"
echo "=========================================="

