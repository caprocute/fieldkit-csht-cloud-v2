#!/bin/bash

# Script để kiểm tra địa chỉ truy cập của Server Service từ internet
# Sử dụng: ./deployment/check-server-access.sh [ENVIRONMENT]
# Ví dụ: ./deployment/check-server-access.sh staging

set -e

ENVIRONMENT=${1:-staging}
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

CLUSTER_NAME="fieldkit-${ENVIRONMENT}-app"
SERVICE_NAME="${CLUSTER_NAME}-server"

echo "=========================================="
echo "Kiểm tra Server Service Access"
echo "=========================================="
echo "Environment: ${ENVIRONMENT}"
echo "Cluster: ${CLUSTER_NAME}"
echo "Service: ${SERVICE_NAME}"
echo "=========================================="
echo ""

# Kiểm tra service tồn tại
SERVICE_STATUS=$(aws ecs describe-services \
    --cluster ${CLUSTER_NAME} \
    --services ${SERVICE_NAME} \
    --region ${AWS_REGION} \
    --query 'services[0].status' \
    --output text 2>/dev/null || echo "NOT_FOUND")

if [ "$SERVICE_STATUS" = "NOT_FOUND" ] || [ "$SERVICE_STATUS" = "None" ] || [ -z "$SERVICE_STATUS" ]; then
    echo "❌ Service ${SERVICE_NAME} không tồn tại."
    echo "   Chạy: ./deployment/create-ecs-services.sh ${ENVIRONMENT}"
    exit 1
fi

echo "✅ Service status: ${SERVICE_STATUS}"
echo ""

# Kiểm tra load balancer
SERVICE_INFO=$(aws ecs describe-services \
    --cluster ${CLUSTER_NAME} \
    --services ${SERVICE_NAME} \
    --region ${AWS_REGION} \
    --query 'services[0]' \
    --output json)

LOAD_BALANCERS=$(echo "$SERVICE_INFO" | jq -r '.loadBalancers // []')

if [ "$LOAD_BALANCERS" = "[]" ] || [ -z "$LOAD_BALANCERS" ] || [ "$LOAD_BALANCERS" = "null" ]; then
    echo "⚠️  Service chưa có Load Balancer được cấu hình."
    echo "   Chạy: ./deployment/setup-load-balancer.sh ${ENVIRONMENT}"
    echo ""
    exit 1
fi

echo "✅ Service đã có Load Balancer được cấu hình."
echo ""

# Lấy thông tin Load Balancer
TG_ARN=$(echo "$LOAD_BALANCERS" | jq -r '.[0].targetGroupArn // empty')

if [ -z "$TG_ARN" ] || [ "$TG_ARN" = "null" ]; then
    echo "❌ Không thể lấy Target Group ARN từ service."
    exit 1
fi

echo "Target Group ARN: ${TG_ARN}"
echo ""

# Lấy Load Balancer ARN từ Target Group
LB_ARN=$(aws elbv2 describe-target-groups \
    --target-group-arns ${TG_ARN} \
    --region ${AWS_REGION} \
    --query 'TargetGroups[0].LoadBalancerArns[0]' \
    --output text 2>/dev/null || echo "")

if [ -z "$LB_ARN" ] || [ "$LB_ARN" = "None" ] || [ "$LB_ARN" = "null" ]; then
    echo "❌ Không thể lấy Load Balancer ARN từ Target Group."
    exit 1
fi

echo "Load Balancer ARN: ${LB_ARN}"
echo ""

# Lấy thông tin Load Balancer
LB_INFO=$(aws elbv2 describe-load-balancers \
    --load-balancer-arns ${LB_ARN} \
    --region ${AWS_REGION} \
    --query 'LoadBalancers[0]' \
    --output json)

LB_DNS=$(echo "$LB_INFO" | jq -r '.DNSName // empty')
LB_SCHEME=$(echo "$LB_INFO" | jq -r '.Scheme // empty')
LB_TYPE=$(echo "$LB_INFO" | jq -r '.Type // empty')
LB_STATE=$(echo "$LB_INFO" | jq -r '.State.Code // empty')

if [ -z "$LB_DNS" ] || [ "$LB_DNS" = "null" ]; then
    echo "❌ Không thể lấy DNS name của Load Balancer."
    exit 1
fi

echo "=========================================="
echo "✅ Thông tin truy cập Server Service"
echo "=========================================="
echo ""
echo "Load Balancer Type: ${LB_TYPE}"
echo "Scheme: ${LB_SCHEME}"
echo "State: ${LB_STATE}"
echo ""
echo "DNS Name: ${LB_DNS}"
echo ""

# Xác định protocol dựa trên scheme
if [ "$LB_SCHEME" = "internet-facing" ]; then
    echo "✅ Load Balancer là internet-facing (có thể truy cập từ internet)"
    echo ""
    
    # Kiểm tra listeners để xác định port
    LISTENERS=$(aws elbv2 describe-listeners \
        --load-balancer-arn ${LB_ARN} \
        --region ${AWS_REGION} \
        --query 'Listeners' \
        --output json)
    
    HTTP_PORT=$(echo "$LISTENERS" | jq -r '.[] | select(.Protocol=="HTTP") | .Port // empty' | head -1)
    HTTPS_PORT=$(echo "$LISTENERS" | jq -r '.[] | select(.Protocol=="HTTPS") | .Port // empty' | head -1)
    
    if [ -n "$HTTP_PORT" ] && [ "$HTTP_PORT" != "null" ]; then
        echo "🌐 HTTP URL:"
        echo "   http://${LB_DNS}"
        if [ "$HTTP_PORT" != "80" ]; then
            echo "   http://${LB_DNS}:${HTTP_PORT}"
        fi
        echo ""
    fi
    
    if [ -n "$HTTPS_PORT" ] && [ "$HTTPS_PORT" != "null" ]; then
        echo "🔒 HTTPS URL:"
        echo "   https://${LB_DNS}"
        if [ "$HTTPS_PORT" != "443" ]; then
            echo "   https://${LB_DNS}:${HTTPS_PORT}"
        fi
        echo ""
    fi
    
    # Kiểm tra health check
    echo "Đang kiểm tra health check..."
    HEALTH_CHECK=$(aws elbv2 describe-target-health \
        --target-group-arn ${TG_ARN} \
        --region ${AWS_REGION} \
        --query 'TargetHealthDescriptions' \
        --output json 2>/dev/null || echo "[]")
    
    HEALTHY_COUNT=$(echo "$HEALTH_CHECK" | jq '[.[] | select(.TargetHealth.State=="healthy")] | length')
    TOTAL_COUNT=$(echo "$HEALTH_CHECK" | jq 'length')
    
    echo "   Healthy targets: ${HEALTHY_COUNT}/${TOTAL_COUNT}"
    
    if [ "$HEALTHY_COUNT" -eq 0 ] && [ "$TOTAL_COUNT" -gt 0 ]; then
        echo "   ⚠️  Không có healthy targets. Service có thể chưa sẵn sàng."
        echo "   Đợi vài phút để service register với target group."
    elif [ "$HEALTHY_COUNT" -gt 0 ]; then
        echo "   ✅ Có ${HEALTHY_COUNT} healthy target(s). Service đã sẵn sàng!"
    fi
    echo ""
    
else
    echo "⚠️  Load Balancer là internal (chỉ truy cập được từ trong VPC)"
    echo ""
    echo "DNS Name: ${LB_DNS}"
    echo ""
fi

echo "=========================================="
echo "📋 Thông tin bổ sung"
echo "=========================================="
echo ""
echo "Để xem chi tiết Load Balancer:"
echo "  aws elbv2 describe-load-balancers --load-balancer-arns ${LB_ARN} --region ${AWS_REGION}"
echo ""
echo "Để xem Target Group health:"
echo "  aws elbv2 describe-target-health --target-group-arn ${TG_ARN} --region ${AWS_REGION}"
echo ""
echo "Để xem Service details:"
echo "  aws ecs describe-services --cluster ${CLUSTER_NAME} --services ${SERVICE_NAME} --region ${AWS_REGION}"
echo ""

