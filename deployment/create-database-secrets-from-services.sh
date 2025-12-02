#!/bin/bash

# Script để tự động tạo database secrets từ ECS service endpoints
# Sử dụng: ./deployment/create-database-secrets-from-services.sh [ENVIRONMENT]
# Ví dụ: ./deployment/create-database-secrets-from-services.sh staging

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

CLUSTER_NAME="fieldkit-${ENVIRONMENT}-db-v1"
NAMESPACE="${ENVIRONMENT}"

echo "=========================================="
echo "Tạo Database Secrets từ ECS Services"
echo "=========================================="
echo "Environment: ${ENVIRONMENT}"
echo "Namespace: ${NAMESPACE}"
echo "Cluster: ${CLUSTER_NAME}"
echo "=========================================="

# Lấy service endpoints
POSTGRES_SERVICE="${CLUSTER_NAME}-postgres"
TIMESCALE_SERVICE="${CLUSTER_NAME}-timescale"

# Kiểm tra services có tồn tại không
POSTGRES_SERVICE_EXISTS=$(aws ecs describe-services \
    --cluster ${CLUSTER_NAME} \
    --services ${POSTGRES_SERVICE} \
    --region ${AWS_REGION} \
    --query 'services[0].status' \
    --output text 2>/dev/null || echo "NOT_FOUND")

TIMESCALE_SERVICE_EXISTS=$(aws ecs describe-services \
    --cluster ${CLUSTER_NAME} \
    --services ${TIMESCALE_SERVICE} \
    --region ${AWS_REGION} \
    --query 'services[0].status' \
    --output text 2>/dev/null || echo "NOT_FOUND")

if [ "$POSTGRES_SERVICE_EXISTS" = "NOT_FOUND" ] || [ -z "$POSTGRES_SERVICE_EXISTS" ] || [ "$POSTGRES_SERVICE_EXISTS" = "None" ]; then
    echo "⚠️  Warning: Service ${POSTGRES_SERVICE} chưa tồn tại."
    echo "   Chạy: ./deployment/deploy-database.sh ${ENVIRONMENT}"
    exit 1
fi

if [ "$TIMESCALE_SERVICE_EXISTS" = "NOT_FOUND" ] || [ -z "$TIMESCALE_SERVICE_EXISTS" ] || [ "$TIMESCALE_SERVICE_EXISTS" = "None" ]; then
    echo "⚠️  Warning: Service ${TIMESCALE_SERVICE} chưa tồn tại."
    echo "   Chạy: ./deployment/deploy-database.sh ${ENVIRONMENT}"
    exit 1
fi

# Lấy NLB DNS name cho PostgreSQL (nếu có)
echo "Đang kiểm tra NLB cho PostgreSQL..."
NLB_NAME="fieldkit-${ENVIRONMENT}-postgres-nlb"
NLB_DNS=$(aws elbv2 describe-load-balancers \
    --names ${NLB_NAME} \
    --region ${AWS_REGION} \
    --query 'LoadBalancers[0].DNSName' \
    --output text 2>/dev/null || echo "")

if [ -n "$NLB_DNS" ] && [ "$NLB_DNS" != "None" ] && [ "$NLB_DNS" != "null" ]; then
    POSTGRES_HOST="${NLB_DNS}"
    echo "✅ Sử dụng PostgreSQL NLB DNS: ${POSTGRES_HOST}"
else
    # Fallback: Sử dụng IP addresses hoặc service discovery name
    echo "⚠️  NLB chưa được setup. Đang lấy IP addresses..."
    
    POSTGRES_TASK_ARN=$(aws ecs list-tasks \
        --cluster ${CLUSTER_NAME} \
        --service-name ${POSTGRES_SERVICE} \
        --region ${AWS_REGION} \
        --query 'taskArns[0]' \
        --output text 2>/dev/null || echo "")
    
    if [ -n "$POSTGRES_TASK_ARN" ] && [ "$POSTGRES_TASK_ARN" != "None" ] && [ "$POSTGRES_TASK_ARN" != "null" ]; then
        # Lấy IP address từ task
        POSTGRES_IP=$(aws ecs describe-tasks \
            --cluster ${CLUSTER_NAME} \
            --tasks ${POSTGRES_TASK_ARN} \
            --region ${AWS_REGION} \
            --query 'tasks[0].attachments[0].details[] | [?name==`privateIPv4Address`].value' \
            --output text 2>/dev/null || echo "")
        
        if [ -n "$POSTGRES_IP" ] && [ "$POSTGRES_IP" != "None" ]; then
            POSTGRES_HOST="${POSTGRES_IP}"
            echo "✅ Sử dụng PostgreSQL IP address: ${POSTGRES_HOST}"
        else
            POSTGRES_HOST="${POSTGRES_SERVICE}.ecs.internal"
            echo "⚠️  Không thể lấy IP address, sử dụng service discovery name: ${POSTGRES_HOST}"
        fi
    else
        POSTGRES_HOST="${POSTGRES_SERVICE}.ecs.internal"
        echo "⚠️  Không tìm thấy running task, sử dụng service discovery name: ${POSTGRES_HOST}"
    fi
fi

# Lấy NLB DNS name cho TimescaleDB (nếu có) - tạm thời dùng IP vì chưa có NLB riêng
TIMESCALE_TASK_ARN=$(aws ecs list-tasks \
    --cluster ${CLUSTER_NAME} \
    --service-name ${TIMESCALE_SERVICE} \
    --region ${AWS_REGION} \
    --query 'taskArns[0]' \
    --output text 2>/dev/null || echo "")

if [ -n "$TIMESCALE_TASK_ARN" ] && [ "$TIMESCALE_TASK_ARN" != "None" ] && [ "$TIMESCALE_TASK_ARN" != "null" ]; then
    # Lấy IP address từ task
    TIMESCALE_IP=$(aws ecs describe-tasks \
        --cluster ${CLUSTER_NAME} \
        --tasks ${TIMESCALE_TASK_ARN} \
        --region ${AWS_REGION} \
        --query 'tasks[0].attachments[0].details[] | [?name==`privateIPv4Address`].value' \
        --output text 2>/dev/null || echo "")
    
    if [ -n "$TIMESCALE_IP" ] && [ "$TIMESCALE_IP" != "None" ]; then
        TIMESCALE_HOST="${TIMESCALE_IP}"
        echo "✅ Sử dụng TimescaleDB IP address: ${TIMESCALE_HOST}"
    else
        TIMESCALE_HOST="${TIMESCALE_SERVICE}.ecs.internal"
        echo "⚠️  Không thể lấy IP address, sử dụng service discovery name: ${TIMESCALE_HOST}"
    fi
else
    TIMESCALE_HOST="${TIMESCALE_SERVICE}.ecs.internal"
    echo "⚠️  Không tìm thấy running task, sử dụng service discovery name: ${TIMESCALE_HOST}"
fi

echo ""
echo "✅ Database hosts:"
echo "   PostgreSQL: ${POSTGRES_HOST}"
echo "   TimescaleDB: ${TIMESCALE_HOST}"
echo ""

# Lấy passwords từ secrets hoặc generate mới
echo "Đang kiểm tra passwords trong secrets..."

POSTGRES_PASSWORD_SECRET="fieldkit/${NAMESPACE}/database/postgres/password"
TIMESCALE_PASSWORD_SECRET="fieldkit/${NAMESPACE}/database/timescale/password"

# Kiểm tra PostgreSQL password
if aws secretsmanager describe-secret --secret-id "${POSTGRES_PASSWORD_SECRET}" --region ${AWS_REGION} &>/dev/null; then
    POSTGRES_PASSWORD=$(aws secretsmanager get-secret-value \
        --secret-id "${POSTGRES_PASSWORD_SECRET}" \
        --region ${AWS_REGION} \
        --query 'SecretString' \
        --output text)
    echo "✅ Đã lấy PostgreSQL password từ secret"
else
    POSTGRES_PASSWORD=$(openssl rand -base64 32 | tr -d "=+/" | cut -c1-25)
    echo "💡 Generated PostgreSQL password"
fi

# Vì đã gộp về 1 database, TimescaleDB password = PostgreSQL password
# (Giữ lại logic này để backward compatibility, nhưng thực tế không dùng nữa)
if aws secretsmanager describe-secret --secret-id "${TIMESCALE_PASSWORD_SECRET}" --region ${AWS_REGION} &>/dev/null; then
    TIMESCALE_PASSWORD=$(aws secretsmanager get-secret-value \
        --secret-id "${TIMESCALE_PASSWORD_SECRET}" \
        --region ${AWS_REGION} \
        --query 'SecretString' \
        --output text)
    echo "✅ Đã lấy TimescaleDB password từ secret (sẽ không dùng vì đã gộp về 1 database)"
else
    # Set bằng PostgreSQL password vì cùng database
    TIMESCALE_PASSWORD="${POSTGRES_PASSWORD}"
    echo "💡 TimescaleDB password được set bằng PostgreSQL password (cùng database)"
fi

# Tạo connection strings
POSTGRES_URL="postgres://fieldkit:${POSTGRES_PASSWORD}@${POSTGRES_HOST}:5432/fieldkit?sslmode=disable"

# Vì đã gộp về 1 database (PostgreSQL với TimescaleDB extension), 
# TimescaleDB URL trỏ về cùng database với PostgreSQL
TIMESCALE_URL="${POSTGRES_URL}"
echo "💡 TimescaleDB URL được set bằng PostgreSQL URL (đã gộp về 1 database)"

# Function để tạo hoặc cập nhật secret
create_or_update_secret() {
    local secret_name=$1
    local secret_value=$2
    local description=$3
    
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

# Tạo các secrets
echo ""
echo "Đang tạo/cập nhật secrets..."

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

# TimescaleDB Password (set bằng PostgreSQL password vì cùng database)
create_or_update_secret \
    "fieldkit/${NAMESPACE}/database/timescale/password" \
    "${POSTGRES_PASSWORD}" \
    "TimescaleDB password for FieldKit ${NAMESPACE} (cùng với PostgreSQL vì đã gộp về 1 database)"

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
echo "Secrets đã được tạo/cập nhật:"
echo "  - fieldkit/${NAMESPACE}/database/postgres/password"
echo "  - fieldkit/${NAMESPACE}/database/postgres"
echo "  - fieldkit/${NAMESPACE}/database/timescale/password"
echo "  - fieldkit/${NAMESPACE}/database/timescale"
echo ""
echo "Connection URLs:"
echo "  PostgreSQL: ${POSTGRES_URL}"
echo "  TimescaleDB: ${TIMESCALE_URL} (trỏ về cùng database với PostgreSQL)"
echo ""
echo "Lưu ý: Vì đã gộp về 1 database, TimescaleDB URL trỏ về cùng database với PostgreSQL."
echo ""

