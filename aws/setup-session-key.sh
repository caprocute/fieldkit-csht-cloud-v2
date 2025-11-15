#!/bin/bash

# Script để setup session key secret trong AWS Secrets Manager
# Sử dụng: ./deployment/setup-session-key.sh [ENVIRONMENT] [SESSION_KEY]
# Ví dụ: ./deployment/setup-session-key.sh staging "your-secret-key-here"

set -e

ENVIRONMENT=${1:-staging}
SESSION_KEY=${2:-""}

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

NAMESPACE="${ENVIRONMENT}"

echo "=========================================="
echo "Setup Session Key Secret"
echo "=========================================="
echo "Environment: ${ENVIRONMENT}"
echo "Namespace: ${NAMESPACE}"
echo "AWS Region: ${AWS_REGION}"
echo "=========================================="

# Generate session key nếu không được cung cấp
if [ -z "$SESSION_KEY" ]; then
    SESSION_KEY=$(openssl rand -base64 32 | tr -d "=+/" | cut -c1-32)
    echo "✅ Generated SESSION_KEY: ${SESSION_KEY}"
else
    echo "✅ Sử dụng SESSION_KEY được cung cấp"
fi

SECRET_NAME="fieldkit/${NAMESPACE}/session/key"

# Function để tạo hoặc cập nhật secret
if aws secretsmanager describe-secret --secret-id "${SECRET_NAME}" --region ${AWS_REGION} &>/dev/null; then
    echo "⚠️  Secret ${SECRET_NAME} đã tồn tại. Đang cập nhật..."
    aws secretsmanager update-secret \
        --secret-id "${SECRET_NAME}" \
        --secret-string "${SESSION_KEY}" \
        --description "Session encryption key for FieldKit ${NAMESPACE}" \
        --region ${AWS_REGION} > /dev/null
    echo "✅ Đã cập nhật secret: ${SECRET_NAME}"
else
    echo "Đang tạo secret: ${SECRET_NAME}"
    aws secretsmanager create-secret \
        --name "${SECRET_NAME}" \
        --secret-string "${SESSION_KEY}" \
        --description "Session encryption key for FieldKit ${NAMESPACE}" \
        --region ${AWS_REGION} > /dev/null
    echo "✅ Đã tạo secret: ${SECRET_NAME}"
fi

echo ""
echo "=========================================="
echo "✅ Setup hoàn tất!"
echo "=========================================="
echo ""
echo "Secret đã được tạo/cập nhật:"
echo "  - ${SECRET_NAME}"
echo ""

