#!/bin/bash

# Script để setup database secrets trong AWS Secrets Manager theo namespace/environment
# Sử dụng: ./deployment/setup-database-secrets.sh [ENVIRONMENT] [POSTGRES_HOST] [TIMESCALE_HOST] [POSTGRES_PASSWORD] [TIMESCALE_PASSWORD]
# Ví dụ: ./deployment/setup-database-secrets.sh staging postgres-service.ecs.internal timescale-service.ecs.internal mypass123 mypass456

set -e

ENVIRONMENT=${1:-staging}
POSTGRES_HOST=${2:-""}
TIMESCALE_HOST=${3:-""}
POSTGRES_PASSWORD=${4:-""}
TIMESCALE_PASSWORD=${5:-""}

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

if [ -n "$AWS_ACCOUNT_ID" ] && [ "$AWS_ACCOUNT_ID" != "$DETECTED_ACCOUNT_ID" ]; then
    echo "⚠️  Warning: AWS_ACCOUNT_ID từ environment (${AWS_ACCOUNT_ID}) khác với Account ID thực tế (${DETECTED_ACCOUNT_ID})"
    echo "   Đang unset AWS_ACCOUNT_ID và sử dụng Account ID từ credentials."
    unset AWS_ACCOUNT_ID
fi

AWS_ACCOUNT_ID="$DETECTED_ACCOUNT_ID"
echo "✅ AWS Account ID: ${AWS_ACCOUNT_ID}"

# Validate format
if ! [[ "$AWS_ACCOUNT_ID" =~ ^[0-9]{12}$ ]]; then
    echo "Error: AWS_ACCOUNT_ID không hợp lệ: ${AWS_ACCOUNT_ID}"
    exit 1
fi

# Namespace từ environment
NAMESPACE="${ENVIRONMENT}"

echo "=========================================="
echo "Setup Database Secrets cho Namespace"
echo "=========================================="
echo "Environment: ${ENVIRONMENT}"
echo "Namespace: ${NAMESPACE}"
echo "AWS Region: ${AWS_REGION}"
echo "=========================================="

# Generate passwords nếu không được cung cấp
if [ -z "$POSTGRES_PASSWORD" ]; then
    POSTGRES_PASSWORD=$(openssl rand -base64 32 | tr -d "=+/" | cut -c1-25)
    echo "✅ Generated POSTGRES_PASSWORD: ${POSTGRES_PASSWORD}"
fi

if [ -z "$TIMESCALE_PASSWORD" ]; then
    TIMESCALE_PASSWORD=$(openssl rand -base64 32 | tr -d "=+/" | cut -c1-25)
    echo "✅ Generated TIMESCALE_PASSWORD: ${TIMESCALE_PASSWORD}"
fi

# Nếu không có host, sử dụng service discovery names
if [ -z "$POSTGRES_HOST" ]; then
    CLUSTER_NAME="fieldkit-${ENVIRONMENT}"
    POSTGRES_SERVICE="${CLUSTER_NAME}-postgres"
    POSTGRES_HOST="${POSTGRES_SERVICE}.ecs.internal"
    echo "💡 Sử dụng service discovery host: ${POSTGRES_HOST}"
fi

if [ -z "$TIMESCALE_HOST" ]; then
    CLUSTER_NAME="fieldkit-${ENVIRONMENT}"
    TIMESCALE_SERVICE="${CLUSTER_NAME}-timescale"
    TIMESCALE_HOST="${TIMESCALE_SERVICE}.ecs.internal"
    echo "💡 Sử dụng service discovery host: ${TIMESCALE_HOST}"
fi

# Function để tạo hoặc cập nhật secret
create_or_update_secret() {
    local secret_name=$1
    local secret_value=$2
    local description=$3
    
    local secret_arn="arn:aws:secretsmanager:${AWS_REGION}:${AWS_ACCOUNT_ID}:secret:${secret_name}"
    
    # Kiểm tra secret đã tồn tại chưa
    if aws secretsmanager describe-secret --secret-id "${secret_name}" --region ${AWS_REGION} &>/dev/null; then
        echo "⚠️  Secret ${secret_name} đã tồn tại. Đang cập nhật..."
        aws secretsmanager update-secret \
            --secret-id "${secret_name}" \
            --secret-string "${secret_value}" \
            --description "${description}" \
            --region ${AWS_REGION} > /dev/null
        echo "✅ Đã cập nhật secret: ${secret_name}"
    else
        echo "Đang tạo secret: ${secret_name}"
        aws secretsmanager create-secret \
            --name "${secret_name}" \
            --secret-string "${secret_value}" \
            --description "${description}" \
            --region ${AWS_REGION} > /dev/null
        echo "✅ Đã tạo secret: ${secret_name}"
    fi
}

# Tạo connection strings
POSTGRES_URL="postgres://fieldkit:${POSTGRES_PASSWORD}@${POSTGRES_HOST}:5432/fieldkit?sslmode=disable"
TIMESCALE_URL="postgres://postgres:${TIMESCALE_PASSWORD}@${TIMESCALE_HOST}:5432/fk?sslmode=disable"

# Tạo các secrets
echo ""
echo "Đang tạo secrets..."

# PostgreSQL Password
create_or_update_secret \
    "fieldkit/${NAMESPACE}/database/postgres/password" \
    "${POSTGRES_PASSWORD}" \
    "PostgreSQL password for FieldKit ${NAMESPACE}"

# PostgreSQL Connection URL
create_or_update_secret \
    "fieldkit/${NAMESPACE}/database/postgres" \
    "${POSTGRES_URL}" \
    "PostgreSQL connection URL for FieldKit ${NAMESPACE}"

# TimescaleDB Password
create_or_update_secret \
    "fieldkit/${NAMESPACE}/database/timescale/password" \
    "${TIMESCALE_PASSWORD}" \
    "TimescaleDB password for FieldKit ${NAMESPACE}"

# TimescaleDB Connection URL
create_or_update_secret \
    "fieldkit/${NAMESPACE}/database/timescale" \
    "${TIMESCALE_URL}" \
    "TimescaleDB connection URL for FieldKit ${NAMESPACE}"

echo ""
echo "=========================================="
echo "✅ Setup hoàn tất!"
echo "=========================================="
echo ""
echo "Secrets đã được tạo:"
echo "  - fieldkit/${NAMESPACE}/database/postgres/password"
echo "  - fieldkit/${NAMESPACE}/database/postgres"
echo "  - fieldkit/${NAMESPACE}/database/timescale/password"
echo "  - fieldkit/${NAMESPACE}/database/timescale"
echo ""
echo "Connection URLs:"
echo "  PostgreSQL: ${POSTGRES_URL}"
echo "  TimescaleDB: ${TIMESCALE_URL}"
echo ""

