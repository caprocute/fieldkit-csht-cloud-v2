#!/bin/bash

# Script để kiểm tra API tạo station
# Sử dụng: ./deployment/test-create-station-api.sh [ENVIRONMENT] [API_URL] [JWT_TOKEN]
# Ví dụ: ./deployment/test-create-station-api.sh staging http://fieldkit-staging-server-alb-xxx.elb.ap-southeast-1.amazonaws.com "Bearer YOUR_JWT_TOKEN"

set -e

ENVIRONMENT=${1:-staging}
API_URL=${2:-""}
JWT_TOKEN=${3:-""}

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

echo "=========================================="
echo "Kiểm tra API Tạo Station"
echo "=========================================="
echo "Environment: ${ENVIRONMENT}"
echo "=========================================="
echo ""

# Lấy ALB DNS nếu chưa có
if [ -z "$API_URL" ]; then
    echo "Đang lấy ALB DNS từ AWS..."
    APP_CLUSTER_NAME="fieldkit-${ENVIRONMENT}-app"
    ALB_NAME="fieldkit-${ENVIRONMENT}-server-alb"
    
    ALB_DNS=$(aws elbv2 describe-load-balancers \
        --names ${ALB_NAME} \
        --region ${AWS_REGION} \
        --query 'LoadBalancers[0].DNSName' \
        --output text 2>/dev/null || echo "")
    
    if [ -z "$ALB_DNS" ] || [ "$ALB_DNS" = "None" ] || [ "$ALB_DNS" = "null" ]; then
        echo "❌ Không tìm thấy ALB: ${ALB_NAME}"
        echo "   Chạy: ./deployment/setup-load-balancer.sh ${ENVIRONMENT}"
        exit 1
    fi
    
    API_URL="http://${ALB_DNS}"
    echo "✅ ALB DNS: ${ALB_DNS}"
    echo ""
fi

# Kiểm tra API health
echo "Đang kiểm tra API health..."
HEALTH_URL="${API_URL}/status"
HEALTH_RESPONSE=$(curl -s -o /dev/null -w "%{http_code}" "${HEALTH_URL}" || echo "000")

if [ "$HEALTH_RESPONSE" != "200" ]; then
    echo "⚠️  API health check failed (HTTP ${HEALTH_RESPONSE})"
    echo "   URL: ${HEALTH_URL}"
    echo ""
else
    echo "✅ API đang hoạt động (HTTP ${HEALTH_RESPONSE})"
    echo ""
fi

# Tạo test payload
DEVICE_ID=$(openssl rand -hex 16)
STATION_NAME="Test Station $(date +%Y%m%d-%H%M%S)"
LOCATION_NAME="Test Location"

PAYLOAD=$(cat <<EOF
{
  "name": "${STATION_NAME}",
  "deviceId": "${DEVICE_ID}",
  "locationName": "${LOCATION_NAME}",
  "description": "Test station created by script"
}
EOF
)

echo "=========================================="
echo "Test Payload:"
echo "=========================================="
echo "$PAYLOAD" | jq .
echo ""

# Kiểm tra JWT token
if [ -z "$JWT_TOKEN" ]; then
    echo "⚠️  JWT Token chưa được cung cấp"
    echo ""
    echo "Để test API, bạn cần:"
    echo "1. Đăng nhập và lấy JWT token từ API"
    echo "2. Chạy lại script với token:"
    echo "   ./deployment/test-create-station-api.sh ${ENVIRONMENT} ${API_URL} \"Bearer YOUR_JWT_TOKEN\""
    echo ""
    echo "Hoặc test thủ công với curl:"
    echo ""
    echo "curl -X POST '${API_URL}/stations' \\"
    echo "  -H 'Content-Type: application/json' \\"
    echo "  -H 'Authorization: Bearer YOUR_JWT_TOKEN' \\"
    echo "  -d '${PAYLOAD}'"
    echo ""
    exit 0
fi

# Test API
echo "=========================================="
echo "Đang gửi request đến API..."
echo "=========================================="
echo "URL: ${API_URL}/stations"
echo "Method: POST"
echo ""

RESPONSE=$(curl -s -w "\n%{http_code}" \
    -X POST "${API_URL}/stations" \
    -H "Content-Type: application/json" \
    -H "Authorization: ${JWT_TOKEN}" \
    -d "${PAYLOAD}" || echo "")

HTTP_CODE=$(echo "$RESPONSE" | tail -n1)
BODY=$(echo "$RESPONSE" | sed '$d')

echo "HTTP Status Code: ${HTTP_CODE}"
echo ""

if [ "$HTTP_CODE" = "200" ] || [ "$HTTP_CODE" = "201" ]; then
    echo "✅ API tạo station thành công!"
    echo ""
    echo "Response:"
    echo "$BODY" | jq . 2>/dev/null || echo "$BODY"
    echo ""
    
    # Parse station ID từ response
    STATION_ID=$(echo "$BODY" | jq -r '.id // empty' 2>/dev/null || echo "")
    if [ -n "$STATION_ID" ] && [ "$STATION_ID" != "null" ]; then
        echo "✅ Station ID: ${STATION_ID}"
        echo ""
        echo "Để xem station:"
        echo "  curl -X GET '${API_URL}/stations/${STATION_ID}' -H 'Authorization: ${JWT_TOKEN}'"
    fi
elif [ "$HTTP_CODE" = "400" ]; then
    echo "❌ Bad Request (400)"
    echo ""
    echo "Response:"
    echo "$BODY" | jq . 2>/dev/null || echo "$BODY"
    echo ""
    echo "Có thể do:"
    echo "  - Station với deviceId này đã tồn tại và thuộc về user khác"
    echo "  - Payload không hợp lệ"
elif [ "$HTTP_CODE" = "401" ] || [ "$HTTP_CODE" = "403" ]; then
    echo "❌ Authentication/Authorization failed (${HTTP_CODE})"
    echo ""
    echo "Response:"
    echo "$BODY" | jq . 2>/dev/null || echo "$BODY"
    echo ""
    echo "Có thể do:"
    echo "  - JWT token không hợp lệ hoặc đã hết hạn"
    echo "  - Token không có quyền 'api:access'"
else
    echo "❌ API request failed (HTTP ${HTTP_CODE})"
    echo ""
    echo "Response:"
    echo "$BODY" | jq . 2>/dev/null || echo "$BODY"
fi

echo ""
echo "=========================================="
echo "Thông tin API Endpoint"
echo "=========================================="
echo "Endpoint: POST /stations"
echo "URL: ${API_URL}/stations"
echo ""
echo "Required Headers:"
echo "  Content-Type: application/json"
echo "  Authorization: Bearer <JWT_TOKEN>"
echo ""
echo "Required Payload:"
echo "  - name: string (required)"
echo "  - deviceId: string (required, hex format)"
echo ""
echo "Optional Payload:"
echo "  - locationName: string"
echo "  - statusPb: string"
echo "  - description: string"
echo ""

