#!/bin/bash

# Script để tạo ECS Task Execution Role và Task Role
# Sử dụng: ./deployment/setup-ecs-roles.sh

set -e

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

echo "=========================================="
echo "Setting up ECS IAM Roles"
echo "=========================================="
echo "Account ID: ${AWS_ACCOUNT_ID}"
echo "Region: ${AWS_REGION}"
echo "=========================================="

# Paths
POLICIES_DIR="deployment/iam-policies"
TRUST_POLICY_EXEC="${POLICIES_DIR}/ecs-task-execution-trust-policy.json"
POLICY_EXEC="${POLICIES_DIR}/ecs-task-execution-policy.json"
TRUST_POLICY_TASK="${POLICIES_DIR}/ecs-task-trust-policy.json"
POLICY_TASK="${POLICIES_DIR}/ecs-task-policy.json"

# Replace ACCOUNT_ID trong policy files
TEMP_EXEC_POLICY=$(mktemp)
sed "s/ACCOUNT_ID/${AWS_ACCOUNT_ID}/g" "${POLICY_EXEC}" > "${TEMP_EXEC_POLICY}"

TEMP_TASK_POLICY=$(mktemp)
sed "s/ACCOUNT_ID/${AWS_ACCOUNT_ID}/g" "${POLICY_TASK}" > "${TEMP_TASK_POLICY}"

# 1. Tạo ECS Task Execution Role
EXEC_ROLE_NAME="ecsTaskExecutionRole"
echo ""
echo "1. Kiểm tra ECS Task Execution Role: ${EXEC_ROLE_NAME}"

if aws iam get-role --role-name ${EXEC_ROLE_NAME} &>/dev/null; then
    echo "   ✅ Role ${EXEC_ROLE_NAME} đã tồn tại."
else
    echo "   Đang tạo role ${EXEC_ROLE_NAME}..."
    aws iam create-role \
        --role-name ${EXEC_ROLE_NAME} \
        --assume-role-policy-document file://${TRUST_POLICY_EXEC} \
        --description "ECS Task Execution Role for FieldKit" \
        --region ${AWS_REGION}
    echo "   ✅ Đã tạo role ${EXEC_ROLE_NAME}"
fi

# Gắn policy cho execution role
POLICY_NAME_EXEC="ECSTaskExecutionRolePolicy"
echo "   Đang kiểm tra policy ${POLICY_NAME_EXEC}..."

if aws iam get-policy --policy-arn "arn:aws:iam::${AWS_ACCOUNT_ID}:policy/${POLICY_NAME_EXEC}" &>/dev/null; then
    echo "   Policy ${POLICY_NAME_EXEC} đã tồn tại. Đang cập nhật..."
    aws iam create-policy-version \
        --policy-arn "arn:aws:iam::${AWS_ACCOUNT_ID}:policy/${POLICY_NAME_EXEC}" \
        --policy-document file://${TEMP_EXEC_POLICY} \
        --set-as-default 2>/dev/null || {
        echo "   Đang xóa policy version cũ và tạo mới..."
        LATEST_VERSION=$(aws iam list-policy-versions \
            --policy-arn "arn:aws:iam::${AWS_ACCOUNT_ID}:policy/${POLICY_NAME_EXEC}" \
            --query 'Versions[?IsDefaultVersion==`false`].VersionId' \
            --output text | head -n 1)
        if [ -n "$LATEST_VERSION" ]; then
            aws iam delete-policy-version \
                --policy-arn "arn:aws:iam::${AWS_ACCOUNT_ID}:policy/${POLICY_NAME_EXEC}" \
                --version-id "$LATEST_VERSION" 2>/dev/null || true
        fi
        aws iam create-policy-version \
            --policy-arn "arn:aws:iam::${AWS_ACCOUNT_ID}:policy/${POLICY_NAME_EXEC}" \
            --policy-document file://${TEMP_EXEC_POLICY} \
            --set-as-default
    }
else
    echo "   Đang tạo policy ${POLICY_NAME_EXEC}..."
    aws iam create-policy \
        --policy-name ${POLICY_NAME_EXEC} \
        --policy-document file://${TEMP_EXEC_POLICY} \
        --description "Policy for ECS Task Execution Role" \
        --region ${AWS_REGION} > /dev/null
    echo "   ✅ Đã tạo policy ${POLICY_NAME_EXEC}"
fi

# Gắn policy vào role
if aws iam list-attached-role-policies \
    --role-name ${EXEC_ROLE_NAME} \
    --query "AttachedPolicies[?PolicyArn=='arn:aws:iam::${AWS_ACCOUNT_ID}:policy/${POLICY_NAME_EXEC}'].PolicyArn" \
    --output text | grep -q "${POLICY_NAME_EXEC}"; then
    echo "   ✅ Policy đã được gắn vào role"
else
    echo "   Đang gắn policy vào role..."
    aws iam attach-role-policy \
        --role-name ${EXEC_ROLE_NAME} \
        --policy-arn "arn:aws:iam::${AWS_ACCOUNT_ID}:policy/${POLICY_NAME_EXEC}"
    echo "   ✅ Đã gắn policy vào role"
fi

# 2. Tạo ECS Task Role
TASK_ROLE_NAME="ecsTaskRole"
echo ""
echo "2. Kiểm tra ECS Task Role: ${TASK_ROLE_NAME}"

if aws iam get-role --role-name ${TASK_ROLE_NAME} &>/dev/null; then
    echo "   ✅ Role ${TASK_ROLE_NAME} đã tồn tại."
else
    echo "   Đang tạo role ${TASK_ROLE_NAME}..."
    aws iam create-role \
        --role-name ${TASK_ROLE_NAME} \
        --assume-role-policy-document file://${TRUST_POLICY_TASK} \
        --description "ECS Task Role for FieldKit" \
        --region ${AWS_REGION}
    echo "   ✅ Đã tạo role ${TASK_ROLE_NAME}"
fi

# Gắn policy cho task role
POLICY_NAME_TASK="ECSTaskRolePolicy"
echo "   Đang kiểm tra policy ${POLICY_NAME_TASK}..."

if aws iam get-policy --policy-arn "arn:aws:iam::${AWS_ACCOUNT_ID}:policy/${POLICY_NAME_TASK}" &>/dev/null; then
    echo "   Policy ${POLICY_NAME_TASK} đã tồn tại. Đang cập nhật..."
    aws iam create-policy-version \
        --policy-arn "arn:aws:iam::${AWS_ACCOUNT_ID}:policy/${POLICY_NAME_TASK}" \
        --policy-document file://${TEMP_TASK_POLICY} \
        --set-as-default 2>/dev/null || {
        LATEST_VERSION=$(aws iam list-policy-versions \
            --policy-arn "arn:aws:iam::${AWS_ACCOUNT_ID}:policy/${POLICY_NAME_TASK}" \
            --query 'Versions[?IsDefaultVersion==`false`].VersionId' \
            --output text | head -n 1)
        if [ -n "$LATEST_VERSION" ]; then
            aws iam delete-policy-version \
                --policy-arn "arn:aws:iam::${AWS_ACCOUNT_ID}:policy/${POLICY_NAME_TASK}" \
                --version-id "$LATEST_VERSION" 2>/dev/null || true
        fi
        aws iam create-policy-version \
            --policy-arn "arn:aws:iam::${AWS_ACCOUNT_ID}:policy/${POLICY_NAME_TASK}" \
            --policy-document file://${TEMP_TASK_POLICY} \
            --set-as-default
    }
else
    echo "   Đang tạo policy ${POLICY_NAME_TASK}..."
    aws iam create-policy \
        --policy-name ${POLICY_NAME_TASK} \
        --policy-document file://${TEMP_TASK_POLICY} \
        --description "Policy for ECS Task Role" \
        --region ${AWS_REGION} > /dev/null
    echo "   ✅ Đã tạo policy ${POLICY_NAME_TASK}"
fi

# Gắn policy vào role
if aws iam list-attached-role-policies \
    --role-name ${TASK_ROLE_NAME} \
    --query "AttachedPolicies[?PolicyArn=='arn:aws:iam::${AWS_ACCOUNT_ID}:policy/${POLICY_NAME_TASK}'].PolicyArn" \
    --output text | grep -q "${POLICY_NAME_TASK}"; then
    echo "   ✅ Policy đã được gắn vào role"
else
    echo "   Đang gắn policy vào role..."
    aws iam attach-role-policy \
        --role-name ${TASK_ROLE_NAME} \
        --policy-arn "arn:aws:iam::${AWS_ACCOUNT_ID}:policy/${POLICY_NAME_TASK}"
    echo "   ✅ Đã gắn policy vào role"
fi

# Cleanup
rm "${TEMP_EXEC_POLICY}" "${TEMP_TASK_POLICY}"

echo ""
echo "=========================================="
echo "✅ Setup hoàn tất!"
echo "=========================================="
echo ""
echo "Roles đã được tạo/cấu hình:"
echo "  - ${EXEC_ROLE_NAME} (arn:aws:iam::${AWS_ACCOUNT_ID}:role/${EXEC_ROLE_NAME})"
echo "  - ${TASK_ROLE_NAME} (arn:aws:iam::${AWS_ACCOUNT_ID}:role/${TASK_ROLE_NAME})"
echo ""
echo "Policies đã được tạo/cấu hình:"
echo "  - ${POLICY_NAME_EXEC}"
echo "  - ${POLICY_NAME_TASK}"
echo ""

