#!/bin/bash

# Script để export database connection URLs từ AWS Secrets Manager
# Sử dụng: source ./deployment/export-database-urls.sh [ENVIRONMENT]
# Hoặc: ./deployment/export-database-urls.sh [ENVIRONMENT]
#
# Ví dụ:
#   source ./deployment/export-database-urls.sh staging
#   echo $FIELDKIT_POSTGRES_URL
#   echo $FIELDKIT_TIME_SCALE_URL

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
    echo ""
    echo "Các cách khắc phục:"
    echo "1. Cấu hình AWS credentials:"
    echo "   aws configure"
    echo ""
    echo "2. Hoặc set AWS_PROFILE:"
    echo "   export AWS_PROFILE=your-profile-name"
    echo ""
    exit 1
fi

NAMESPACE="${ENVIRONMENT}"

# Secret names
POSTGRES_SECRET_NAME="fieldkit/${NAMESPACE}/database/postgres"
TIMESCALE_SECRET_NAME="fieldkit/${NAMESPACE}/database/timescale"

echo "=========================================="
echo "Export Database Connection URLs"
echo "=========================================="
echo "Environment: ${ENVIRONMENT}"
echo "Region: ${AWS_REGION}"
echo "=========================================="
echo ""

# Lấy PostgreSQL connection URL
echo "Đang lấy PostgreSQL connection URL..."
POSTGRES_URL=$(aws secretsmanager get-secret-value \
    --secret-id ${POSTGRES_SECRET_NAME} \
    --region ${AWS_REGION} \
    --query 'SecretString' \
    --output text 2>/dev/null || echo "")

if [ -z "$POSTGRES_URL" ] || [ "$POSTGRES_URL" = "None" ] || [ "$POSTGRES_URL" = "null" ]; then
    echo "❌ Không thể lấy PostgreSQL connection string từ secret: ${POSTGRES_SECRET_NAME}"
    echo "   Chạy: ./deployment/create-database-secrets-from-services.sh ${ENVIRONMENT}"
    exit 1
fi

echo "✅ Đã lấy PostgreSQL connection URL"

# Lấy TimescaleDB connection URL
echo "Đang lấy TimescaleDB connection URL..."
TIMESCALE_URL=$(aws secretsmanager get-secret-value \
    --secret-id ${TIMESCALE_SECRET_NAME} \
    --region ${AWS_REGION} \
    --query 'SecretString' \
    --output text 2>/dev/null || echo "")

if [ -z "$TIMESCALE_URL" ] || [ "$TIMESCALE_URL" = "None" ] || [ "$TIMESCALE_URL" = "null" ]; then
    echo "❌ Không thể lấy TimescaleDB connection string từ secret: ${TIMESCALE_SECRET_NAME}"
    echo "   Chạy: ./deployment/create-database-secrets-from-services.sh ${ENVIRONMENT}"
    exit 1
fi

echo "✅ Đã lấy TimescaleDB connection URL"
echo ""

# Export biến môi trường
export FIELDKIT_POSTGRES_URL="${POSTGRES_URL}"
export FIELDKIT_TIME_SCALE_URL="${TIMESCALE_URL}"

# Kiểm tra xem script được source hay chạy trực tiếp
if [ "${BASH_SOURCE[0]}" = "${0}" ]; then
    # Script được chạy trực tiếp, hiển thị thông tin
    echo "=========================================="
    echo "✅ Database URLs đã được export!"
    echo "=========================================="
    echo ""
    echo "Để sử dụng các biến này, hãy source script:"
    echo "  source ./deployment/export-database-urls.sh ${ENVIRONMENT}"
    echo ""
    echo "Hoặc export thủ công:"
    echo "  export FIELDKIT_POSTGRES_URL=\"${POSTGRES_URL}\""
    echo "  export FIELDKIT_TIME_SCALE_URL=\"${TIMESCALE_URL}\""
    echo ""
    echo "Connection URLs (ẩn password):"
    echo "  FIELDKIT_POSTGRES_URL: $(echo ${POSTGRES_URL} | sed 's/:[^:@]*@/:***@/g')"
    echo "  FIELDKIT_TIME_SCALE_URL: $(echo ${TIMESCALE_URL} | sed 's/:[^:@]*@/:***@/g')"
    echo ""
else
    # Script được source, biến đã được export
    echo "=========================================="
    echo "✅ Database URLs đã được export!"
    echo "=========================================="
    echo ""
    echo "Các biến môi trường đã sẵn sàng:"
    echo "  FIELDKIT_POSTGRES_URL"
    echo "  FIELDKIT_TIME_SCALE_URL"
    echo ""
    echo "Sử dụng:"
    echo "  echo \$FIELDKIT_POSTGRES_URL"
    echo "  echo \$FIELDKIT_TIME_SCALE_URL"
    echo ""
fi

