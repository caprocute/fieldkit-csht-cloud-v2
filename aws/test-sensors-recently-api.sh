#!/bin/bash

# Script để kiểm tra API /sensors/data/recently
# Sử dụng: ./deployment/test-sensors-recently-api.sh [ENVIRONMENT] [API_URL] [STATION_IDS] [JWT_TOKEN]
# Ví dụ: ./deployment/test-sensors-recently-api.sh staging "" "1,2,3" "Bearer YOUR_JWT_TOKEN"

set -e

ENVIRONMENT=${1:-staging}
API_URL=${2:-""}
STATION_IDS=${3:-""}
JWT_TOKEN=${4:-""}

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
echo "Kiểm tra API /sensors/data/recently"
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

# Kiểm tra station IDs
if [ -z "$STATION_IDS" ]; then
    echo "⚠️  Station IDs chưa được cung cấp"
    echo ""
    echo "Để test API, bạn cần:"
    echo "1. Lấy danh sách station IDs từ API hoặc database"
    echo "2. Chạy lại script với station IDs:"
    echo "   ./deployment/test-sensors-recently-api.sh ${ENVIRONMENT} ${API_URL} \"1,2,3\" \"Bearer YOUR_JWT_TOKEN\""
    echo ""
    echo "Hoặc test thủ công với curl:"
    echo ""
    echo "curl -X GET '${API_URL}/sensors/data/recently?stations=1,2,3&windows=1,24' \\"
    echo "  -H 'Authorization: Bearer YOUR_JWT_TOKEN'"
    echo ""
    exit 0
fi

# Build query string
QUERY_PARAMS="stations=${STATION_IDS}"
WINDOWS=${WINDOWS:-"1,24"}  # Default: 1 hour and 24 hours
QUERY_PARAMS="${QUERY_PARAMS}&windows=${WINDOWS}"

ENDPOINT_URL="${API_URL}/sensors/data/recently?${QUERY_PARAMS}"

echo "=========================================="
echo "Đang gửi request đến API..."
echo "=========================================="
echo "URL: ${ENDPOINT_URL}"
echo "Method: GET"
echo "Query Parameters:"
echo "  stations: ${STATION_IDS}"
echo "  windows: ${WINDOWS} (hours)"
echo ""

# Test API
if [ -z "$JWT_TOKEN" ]; then
    echo "⚠️  JWT Token chưa được cung cấp (sẽ test không có auth)"
    echo ""
    RESPONSE=$(curl -s -w "\n%{http_code}" \
        -X GET "${ENDPOINT_URL}" || echo "")
else
    RESPONSE=$(curl -s -w "\n%{http_code}" \
        -X GET "${ENDPOINT_URL}" \
        -H "Authorization: ${JWT_TOKEN}" || echo "")
fi

HTTP_CODE=$(echo "$RESPONSE" | tail -n1)
BODY=$(echo "$RESPONSE" | sed '$d')

echo "HTTP Status Code: ${HTTP_CODE}"
echo ""

if [ "$HTTP_CODE" = "200" ]; then
    echo "✅ API request thành công!"
    echo ""
    echo "Response:"
    
    # Try to parse JSON
    if command -v jq &> /dev/null; then
        echo "$BODY" | jq . 2>/dev/null || echo "$BODY"
        
        # Parse và hiển thị thông tin hữu ích
        WINDOWS_COUNT=$(echo "$BODY" | jq '.object.windows | length' 2>/dev/null || echo "0")
        STATIONS_COUNT=$(echo "$BODY" | jq '.object.stations | length' 2>/dev/null || echo "0")
        
        if [ "$WINDOWS_COUNT" != "0" ] || [ "$STATIONS_COUNT" != "0" ]; then
            echo ""
            echo "📊 Summary:"
            echo "  Windows: ${WINDOWS_COUNT}"
            echo "  Stations: ${STATIONS_COUNT}"
        fi
    else
        echo "$BODY"
    fi
elif [ "$HTTP_CODE" = "400" ]; then
    echo "❌ Bad Request (400)"
    echo ""
    echo "Response:"
    echo "$BODY" | jq . 2>/dev/null || echo "$BODY"
    echo ""
    echo "Có thể do:"
    echo "  - Station IDs không hợp lệ hoặc không tồn tại"
    echo "  - Query parameters không đúng format"
    echo "  - Windows parameter không hợp lệ"
elif [ "$HTTP_CODE" = "401" ] || [ "$HTTP_CODE" = "403" ]; then
    echo "⚠️  Authentication/Authorization (${HTTP_CODE})"
    echo "   Endpoint này có thể hoạt động không cần auth, nhưng một số dữ liệu có thể bị giới hạn"
    echo ""
    echo "Response:"
    echo "$BODY" | jq . 2>/dev/null || echo "$BODY"
elif [ "$HTTP_CODE" = "000" ]; then
    echo "❌ Không thể kết nối đến API"
    echo "   Kiểm tra:"
    echo "   - API URL có đúng không: ${API_URL}"
    echo "   - Network connectivity"
    echo "   - ALB có đang hoạt động không"
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
echo "Endpoint: GET /sensors/data/recently"
echo "URL: ${API_URL}/sensors/data/recently"
echo ""
echo "Query Parameters:"
echo "  - stations: string (required, comma-separated station IDs)"
echo "    Ví dụ: stations=1,2,3"
echo ""
echo "  - windows: string (optional, comma-separated hours)"
echo "    Ví dụ: windows=1,24,168 (1 hour, 24 hours, 1 week)"
echo "    Default: 1,24"
echo ""
echo "Authentication:"
echo "  - Optional (JWT Bearer token)"
echo "  - Nếu không có auth, chỉ trả về dữ liệu public"
echo ""
echo "Response Format:"
echo "  {"
echo "    \"object\": {"
echo "      \"windows\": {"
echo "        \"3600000000000\": [...],  // 1 hour in nanoseconds"
echo "        \"86400000000000\": [...]  // 24 hours in nanoseconds"
echo "      },"
echo "      \"stations\": {"
echo "        \"1\": { \"last\": ... },"
echo "        \"2\": { \"last\": ... }"
echo "      }"
echo "    }"
echo "  }"
echo ""

