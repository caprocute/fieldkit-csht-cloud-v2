#!/bin/bash

# Script để kiểm tra trạng thái public của các dịch vụ
# Sử dụng: ./deployment/check-public-services.sh [ENVIRONMENT]
# Ví dụ: ./deployment/check-public-services.sh staging

set -e

ENVIRONMENT=${1:-staging}
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

# Validate AWS credentials
DETECTED_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text 2>/dev/null || echo "")

if [ -z "$DETECTED_ACCOUNT_ID" ]; then
    echo "❌ Error: Không thể lấy AWS credentials."
    exit 1
fi

APP_CLUSTER_NAME="fieldkit-${ENVIRONMENT}-app"
DB_CLUSTER_NAME="fieldkit-${ENVIRONMENT}-db-v1"

echo "=========================================="
echo "Kiểm tra Public Services Status"
echo "=========================================="
echo "Environment: ${ENVIRONMENT}"
echo "Region: ${AWS_REGION}"
echo "=========================================="
echo ""

# Function để kiểm tra Load Balancer
check_load_balancer() {
    local lb_name=$1
    local lb_type=$2
    local service_name=$3
    local cluster_name=$4
    local container_port=$5
    
    echo "----------------------------------------"
    echo "📋 ${service_name}"
    echo "----------------------------------------"
    
    # Kiểm tra Load Balancer
    LB_ARN=$(aws elbv2 describe-load-balancers \
        --names ${lb_name} \
        --region ${AWS_REGION} \
        --query 'LoadBalancers[0].LoadBalancerArn' \
        --output text 2>/dev/null || echo "")
    
    if [ -z "$LB_ARN" ] || [ "$LB_ARN" = "None" ] || [ "$LB_ARN" = "null" ]; then
        echo "❌ Load Balancer '${lb_name}' chưa được tạo"
        echo "   Chạy: ./deployment/setup-${service_name,,}-public.sh ${ENVIRONMENT}"
        echo ""
        return 1
    fi
    
    # Lấy thông tin Load Balancer
    LB_INFO=$(aws elbv2 describe-load-balancers \
        --load-balancer-arns ${LB_ARN} \
        --region ${AWS_REGION} \
        --query 'LoadBalancers[0]' \
        --output json)
    
    LB_DNS=$(echo "$LB_INFO" | jq -r '.DNSName // empty')
    LB_SCHEME=$(echo "$LB_INFO" | jq -r '.Scheme // empty')
    LB_STATE=$(echo "$LB_INFO" | jq -r '.State.Code // empty')
    
    echo "✅ Load Balancer: ${lb_name}"
    echo "   Type: ${lb_type}"
    echo "   Scheme: ${LB_SCHEME}"
    echo "   State: ${LB_STATE}"
    echo "   DNS: ${LB_DNS}"
    echo ""
    
    # Kiểm tra Target Group
    TG_NAME="fieldkit-${ENVIRONMENT}-${service_name,,}-tg"
    TG_ARN=$(aws elbv2 describe-target-groups \
        --names ${TG_NAME} \
        --region ${AWS_REGION} \
        --query 'TargetGroups[0].TargetGroupArn' \
        --output text 2>/dev/null || echo "")
    
    if [ -z "$TG_ARN" ] || [ "$TG_ARN" = "None" ] || [ "$TG_ARN" = "null" ]; then
        echo "⚠️  Target Group '${TG_NAME}' chưa được tạo"
        echo ""
        return 1
    fi
    
    echo "✅ Target Group: ${TG_NAME}"
    
    # Kiểm tra health của targets
    HEALTH_CHECK=$(aws elbv2 describe-target-health \
        --target-group-arn ${TG_ARN} \
        --region ${AWS_REGION} \
        --query 'TargetHealthDescriptions' \
        --output json 2>/dev/null || echo "[]")
    
    HEALTHY_COUNT=$(echo "$HEALTH_CHECK" | jq '[.[] | select(.TargetHealth.State=="healthy")] | length')
    TOTAL_COUNT=$(echo "$HEALTH_CHECK" | jq 'length')
    UNHEALTHY_COUNT=$((TOTAL_COUNT - HEALTHY_COUNT))
    
    echo "   Healthy targets: ${HEALTHY_COUNT}/${TOTAL_COUNT}"
    
    if [ "$TOTAL_COUNT" -eq 0 ]; then
        echo "   ⚠️  Chưa có targets được register"
    elif [ "$HEALTHY_COUNT" -eq 0 ]; then
        echo "   ❌ Không có healthy targets"
        if [ "$UNHEALTHY_COUNT" -gt 0 ]; then
            echo "   ⚠️  Có ${UNHEALTHY_COUNT} unhealthy target(s)"
        fi
    else
        echo "   ✅ Có ${HEALTHY_COUNT} healthy target(s)"
        if [ "$UNHEALTHY_COUNT" -gt 0 ]; then
            echo "   ⚠️  Có ${UNHEALTHY_COUNT} unhealthy target(s)"
        fi
    fi
    echo ""
    
    # Kiểm tra Service có attach vào Load Balancer không
    if [ "$service_name" = "server" ]; then
        SERVICE_NAME="${cluster_name}-server"
    else
        SERVICE_NAME="${cluster_name}-${service_name,,}"
    fi
    
    SERVICE_INFO=$(aws ecs describe-services \
        --cluster ${cluster_name} \
        --services ${SERVICE_NAME} \
        --region ${AWS_REGION} \
        --query 'services[0]' \
        --output json 2>/dev/null || echo "{}")
    
    SERVICE_STATUS=$(echo "$SERVICE_INFO" | jq -r '.status // "NOT_FOUND"')
    
    if [ "$SERVICE_STATUS" = "NOT_FOUND" ] || [ "$SERVICE_STATUS" = "null" ]; then
        echo "⚠️  Service '${SERVICE_NAME}' chưa tồn tại"
        echo ""
        return 1
    fi
    
    LOAD_BALANCERS=$(echo "$SERVICE_INFO" | jq -r '.loadBalancers // []')
    
    if [ "$LOAD_BALANCERS" = "[]" ] || [ -z "$LOAD_BALANCERS" ] || [ "$LOAD_BALANCERS" = "null" ]; then
        echo "⚠️  Service chưa được attach vào Load Balancer"
        echo "   Chạy: ./deployment/setup-${service_name,,}-public.sh ${ENVIRONMENT}"
        echo ""
        return 1
    fi
    
    ATTACHED_TG=$(echo "$LOAD_BALANCERS" | jq -r '.[0].targetGroupArn // empty')
    
    if [ "$ATTACHED_TG" = "$TG_ARN" ]; then
        echo "✅ Service đã được attach vào Target Group"
    else
        echo "⚠️  Service được attach vào Target Group khác: ${ATTACHED_TG}"
    fi
    echo ""
    
    # Hiển thị connection info
    if [ "$LB_SCHEME" = "internet-facing" ]; then
        echo "🌐 Public Access:"
        if [ "$lb_type" = "application" ]; then
            echo "   URL: http://${LB_DNS}"
            echo "   Health check: http://${LB_DNS}/status"
        else
            echo "   Host: ${LB_DNS}"
            echo "   Port: ${container_port}"
            if [ "$service_name" = "postgres" ]; then
                echo "   Connection: postgres://fieldkit:PASSWORD@${LB_DNS}:${container_port}/fieldkit?sslmode=disable"
            elif [ "$service_name" = "timescale" ]; then
                echo "   Connection: postgres://postgres:PASSWORD@${LB_DNS}:${container_port}/fk?sslmode=disable"
            fi
        fi
        echo ""
    else
        echo "⚠️  Load Balancer là internal (chỉ truy cập được từ trong VPC)"
        echo ""
    fi
    
    return 0
}

# Kiểm tra Server Service (ALB)
check_load_balancer \
    "fieldkit-${ENVIRONMENT}-server-alb" \
    "application" \
    "server" \
    "${APP_CLUSTER_NAME}" \
    "80"

# Kiểm tra PostgreSQL (NLB)
check_load_balancer \
    "fieldkit-${ENVIRONMENT}-postgres-nlb" \
    "network" \
    "postgres" \
    "${DB_CLUSTER_NAME}" \
    "5432"

# Kiểm tra TimescaleDB (NLB)
check_load_balancer \
    "fieldkit-${ENVIRONMENT}-timescale-nlb" \
    "network" \
    "timescale" \
    "${DB_CLUSTER_NAME}" \
    "5432"

echo "=========================================="
echo "✅ Kiểm tra hoàn tất!"
echo "=========================================="
echo ""
echo "Để xem chi tiết hơn:"
echo "  - Server: ./deployment/check-server-access.sh ${ENVIRONMENT}"
echo "  - PostgreSQL: aws elbv2 describe-load-balancers --names fieldkit-${ENVIRONMENT}-postgres-nlb --region ${AWS_REGION}"
echo "  - TimescaleDB: aws elbv2 describe-load-balancers --names fieldkit-${ENVIRONMENT}-timescale-nlb --region ${AWS_REGION}"
echo ""

