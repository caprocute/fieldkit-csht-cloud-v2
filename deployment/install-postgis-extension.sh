#!/bin/bash

# Script để cài PostGIS extension vào database remote
# Sử dụng: ./deployment/install-postgis-extension.sh [ENVIRONMENT]
# Ví dụ: ./deployment/install-postgis-extension.sh staging

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

echo "=========================================="
echo "Cài PostGIS Extension vào Database"
echo "=========================================="
echo "Environment: ${ENVIRONMENT}"
echo "Region: ${AWS_REGION}"
echo "=========================================="
echo ""

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

# Kiểm tra xem psql có sẵn không
if ! command -v psql &> /dev/null; then
    echo "❌ psql chưa được cài đặt."
    echo "   Cài đặt PostgreSQL client:"
    echo "   - macOS: brew install postgresql"
    echo "   - Ubuntu: sudo apt-get install postgresql-client"
    exit 1
fi

# Parse connection string để lấy thông tin
# Format: postgres://user:password@host:port/database?sslmode=disable
DB_INFO=$(echo "$POSTGRES_URL" | sed 's|postgres://||' | sed 's|?.*||')
DB_USER=$(echo "$DB_INFO" | cut -d: -f1)
DB_PASS=$(echo "$DB_INFO" | cut -d: -f2 | cut -d@ -f1)
DB_HOST_PORT=$(echo "$DB_INFO" | cut -d@ -f2 | cut -d/ -f1)
DB_HOST=$(echo "$DB_HOST_PORT" | cut -d: -f1)
DB_PORT=$(echo "$DB_HOST_PORT" | cut -d: -f2)
DB_NAME=$(echo "$DB_INFO" | cut -d/ -f2)

if [ -z "$DB_PORT" ]; then
    DB_PORT=5432
fi

echo "Thông tin database:"
echo "  Host: ${DB_HOST}"
echo "  Port: ${DB_PORT}"
echo "  Database: ${DB_NAME}"
echo "  User: ${DB_USER}"
echo ""

# Kiểm tra xem PostGIS extension đã có chưa
echo "Đang kiểm tra PostGIS extension..."

PGPASSWORD="${DB_PASS}" psql -h "${DB_HOST}" -p "${DB_PORT}" -U "${DB_USER}" -d "${DB_NAME}" -tAc \
    "SELECT EXISTS(SELECT 1 FROM pg_extension WHERE extname = 'postgis');" > /tmp/postgis_check.txt 2>&1 || true

POSTGIS_EXISTS=$(cat /tmp/postgis_check.txt | tr -d ' ')

if [ "$POSTGIS_EXISTS" = "t" ]; then
    echo "✅ PostGIS extension đã được cài đặt"
    
    # Kiểm tra TimescaleDB
    PGPASSWORD="${DB_PASS}" psql -h "${DB_HOST}" -p "${DB_PORT}" -U "${DB_USER}" -d "${DB_NAME}" -tAc \
        "SELECT EXISTS(SELECT 1 FROM pg_extension WHERE extname = 'timescaledb');" > /tmp/tsdb_check.txt 2>&1 || true
    
    TSDB_EXISTS=$(cat /tmp/tsdb_check.txt | tr -d ' ')
    
    if [ "$TSDB_EXISTS" = "t" ]; then
        echo "✅ TimescaleDB extension đã được cài đặt"
        echo ""
        echo "=========================================="
        echo "✅ Tất cả extensions đã sẵn sàng!"
        echo "=========================================="
        exit 0
    else
        echo "⚠️  TimescaleDB extension chưa được cài đặt"
        echo ""
        echo "Đang cài đặt TimescaleDB extension..."
        PGPASSWORD="${DB_PASS}" psql -h "${DB_HOST}" -p "${DB_PORT}" -U "${DB_USER}" -d "${DB_NAME}" -c \
            "CREATE EXTENSION IF NOT EXISTS timescaledb;" 2>&1
        
        if [ $? -eq 0 ]; then
            echo "✅ TimescaleDB extension đã được cài đặt"
        else
            echo "❌ Không thể cài đặt TimescaleDB extension"
            echo "   Có thể database image không hỗ trợ TimescaleDB"
            echo "   Cần cập nhật ECS task definition với image: parjom/timescaledb-postgis:2.17.2-pg16-postgis350"
            exit 1
        fi
    fi
else
    echo "⚠️  PostGIS extension chưa được cài đặt"
    echo ""
    echo "Đang cài đặt PostGIS extension..."
    
    # Thử cài PostGIS
    PGPASSWORD="${DB_PASS}" psql -h "${DB_HOST}" -p "${DB_PORT}" -U "${DB_USER}" -d "${DB_NAME}" -c \
        "CREATE EXTENSION IF NOT EXISTS postgis;" 2>&1
    
    if [ $? -eq 0 ]; then
        echo "✅ PostGIS extension đã được cài đặt"
        
        # Kiểm tra và cài TimescaleDB
        PGPASSWORD="${DB_PASS}" psql -h "${DB_HOST}" -p "${DB_PORT}" -U "${DB_USER}" -d "${DB_NAME}" -tAc \
            "SELECT EXISTS(SELECT 1 FROM pg_extension WHERE extname = 'timescaledb');" > /tmp/tsdb_check.txt 2>&1 || true
        
        TSDB_EXISTS=$(cat /tmp/tsdb_check.txt | tr -d ' ')
        
        if [ "$TSDB_EXISTS" != "t" ]; then
            echo "Đang cài đặt TimescaleDB extension..."
            PGPASSWORD="${DB_PASS}" psql -h "${DB_HOST}" -p "${DB_PORT}" -U "${DB_USER}" -d "${DB_NAME}" -c \
                "CREATE EXTENSION IF NOT EXISTS timescaledb;" 2>&1 || echo "⚠️  TimescaleDB có thể không có sẵn trong image này"
        fi
    else
        echo "❌ Không thể cài đặt PostGIS extension"
        echo ""
        echo "Nguyên nhân có thể:"
        echo "  1. Database image không có PostGIS extension"
        echo "  2. User không có quyền superuser"
        echo ""
        echo "Giải pháp:"
        echo "  1. Cập nhật ECS task definition với image có PostGIS:"
        echo "     Image: parjom/timescaledb-postgis:2.17.2-pg16-postgis350"
        echo "  2. Restart PostgreSQL service trên ECS"
        echo "  3. Chạy lại script này"
        exit 1
    fi
fi

echo ""
echo "=========================================="
echo "✅ Hoàn tất!"
echo "=========================================="
echo ""
echo "Bây giờ bạn có thể chạy migrations:"
echo "  ./deployment/run-migrations-local.sh ${ENVIRONMENT}"

rm -f /tmp/postgis_check.txt /tmp/tsdb_check.txt

