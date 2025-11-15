#!/bin/bash

# Script để chạy database migrations từ máy local
# Kết nối trực tiếp đến database trên AWS
# Sử dụng: ./deployment/run-migrations-local.sh [ENVIRONMENT]
# Ví dụ: ./deployment/run-migrations-local.sh staging

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

echo "=========================================="
echo "Running Database Migrations từ Local"
echo "=========================================="
echo "Environment: ${ENVIRONMENT}"
echo "AWS Region: ${AWS_REGION}"
echo "=========================================="
echo ""

# Kiểm tra Go đã được cài đặt
if ! command -v go &> /dev/null; then
    echo "❌ Go chưa được cài đặt."
    echo "   Cài đặt Go: https://golang.org/dl/"
    exit 1
fi

# Lấy connection string từ Secrets Manager
echo "Đang lấy database connection string từ AWS Secrets Manager..."

POSTGRES_SECRET_NAME="fieldkit/${ENVIRONMENT}/database/postgres"

POSTGRES_URL=$(aws secretsmanager get-secret-value \
    --secret-id ${POSTGRES_SECRET_NAME} \
    --region ${AWS_REGION} \
    --query 'SecretString' \
    --output text 2>/dev/null || echo "")

if [ -z "$POSTGRES_URL" ] || [ "$POSTGRES_URL" = "None" ]; then
    echo "❌ Không thể lấy PostgreSQL connection string từ secret: ${POSTGRES_SECRET_NAME}"
    echo "   Chạy: ./deployment/create-database-secrets-from-services.sh ${ENVIRONMENT}"
    exit 1
fi

echo "✅ Đã lấy connection string"
echo ""

# Kiểm tra migrations directory
PRIMARY_MIGRATIONS_PATH="$(pwd)/migrations/primary"

if [ ! -d "$PRIMARY_MIGRATIONS_PATH" ]; then
    echo "❌ Không tìm thấy migrations directory: ${PRIMARY_MIGRATIONS_PATH}"
    exit 1
fi

# Chạy migration cho database (PostgreSQL với TimescaleDB extension)
echo "=========================================="
echo "Chạy migrations cho Database"
echo "=========================================="
echo "Database: ${POSTGRES_URL}"
echo "Migrations path: ${PRIMARY_MIGRATIONS_PATH}"
echo ""

cd migrations/cli

export MIGRATE_PATH="${PRIMARY_MIGRATIONS_PATH}"
export MIGRATE_DATABASE_URL="${POSTGRES_URL}"

echo "Đang chạy migrations..."
if go run main.go migrate; then
    echo "✅ Migrations đã hoàn thành thành công!"
else
    echo "❌ Migrations có lỗi"
    exit 1
fi

echo "=========================================="
echo "✅ Migrations đã hoàn thành!"
echo "=========================================="

