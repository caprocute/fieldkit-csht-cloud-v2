#!/bin/bash

# Script để setup IAM policy cho deployment
# Sử dụng: ./deployment/setup-iam-policy.sh [USER_NAME_OR_ROLE_NAME] [USER|ROLE]

set -e

TARGET_NAME=${1:-""}
TARGET_TYPE=${2:-"USER"}

if [ -z "$TARGET_NAME" ]; then
    echo "Error: Cần cung cấp IAM user hoặc role name"
    echo "Sử dụng: ./deployment/setup-iam-policy.sh USER_NAME [USER|ROLE]"
    exit 1
fi

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

if [ -z "$AWS_ACCOUNT_ID" ]; then
    # Lấy account ID từ credentials
    AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text 2>/dev/null || echo "")
    if [ -z "$AWS_ACCOUNT_ID" ]; then
        echo "Error: Không thể lấy AWS_ACCOUNT_ID. Vui lòng set biến môi trường."
        exit 1
    fi
fi

POLICY_NAME="FieldKitDeploymentPolicyV5"
POLICY_FILE="deployment/iam-policies/deployment-full-policy.json"

echo "=========================================="
echo "Setting up IAM Policy for Deployment"
echo "=========================================="
echo "Target: ${TARGET_TYPE} ${TARGET_NAME}"
echo "Account ID: ${AWS_ACCOUNT_ID}"
echo "Region: ${AWS_REGION}"
echo "=========================================="

# Kiểm tra policy file tồn tại
if [ ! -f "$POLICY_FILE" ]; then
    echo "Error: Policy file không tồn tại: $POLICY_FILE"
    exit 1
fi

# Tạo policy document với ACCOUNT_ID đã thay thế
TEMP_POLICY=$(mktemp)
sed "s/ACCOUNT_ID/${AWS_ACCOUNT_ID}/g" "$POLICY_FILE" > "$TEMP_POLICY"

# Kiểm tra policy đã tồn tại chưa
POLICY_ARN="arn:aws:iam::${AWS_ACCOUNT_ID}:policy/${POLICY_NAME}"
if aws iam get-policy --policy-arn "$POLICY_ARN" &> /dev/null; then
    echo "Policy ${POLICY_NAME} đã tồn tại."
    echo "Đang kiểm tra và cập nhật policy version..."
    
    # Lấy danh sách policy versions
    POLICY_VERSIONS=$(aws iam list-policy-versions --policy-arn "$POLICY_ARN" --query 'Versions[?IsDefaultVersion==`false`].VersionId' --output text 2>/dev/null || echo "")
    
    # Kiểm tra số lượng versions (AWS giới hạn 5 versions)
    VERSION_COUNT=$(aws iam list-policy-versions --policy-arn "$POLICY_ARN" --query 'length(Versions)' --output text 2>/dev/null || echo "0")
    
    if [ "$VERSION_COUNT" -ge 5 ]; then
        echo "⚠️  Policy đã có 5 versions (giới hạn của AWS). Đang xóa version cũ nhất..."
        # Tìm version cũ nhất (không phải default)
        OLDEST_VERSION=$(aws iam list-policy-versions --policy-arn "$POLICY_ARN" \
            --query 'Versions[?IsDefaultVersion==`false`] | sort_by(@, &CreateDate) | [0].VersionId' \
            --output text 2>/dev/null || echo "")
        
        if [ -n "$OLDEST_VERSION" ]; then
            aws iam delete-policy-version \
                --policy-arn "$POLICY_ARN" \
                --version-id "$OLDEST_VERSION" &>/dev/null || true
            echo "✅ Đã xóa version cũ: ${OLDEST_VERSION}"
        fi
    fi
    
    # So sánh policy document hiện tại với policy mới
    CURRENT_POLICY=$(aws iam get-policy-version \
        --policy-arn "$POLICY_ARN" \
        --version-id $(aws iam get-policy --policy-arn "$POLICY_ARN" --query 'Policy.DefaultVersionId' --output text) \
        --query 'PolicyVersion.Document' --output json 2>/dev/null || echo "{}")
    
    NEW_POLICY=$(cat "$TEMP_POLICY")
    
    # Normalize JSON để so sánh (bỏ qua whitespace và thứ tự)
    CURRENT_NORMALIZED=$(echo "$CURRENT_POLICY" | jq -cS . 2>/dev/null || echo "")
    NEW_NORMALIZED=$(echo "$NEW_POLICY" | jq -cS . 2>/dev/null || echo "")
    
    if [ "$CURRENT_NORMALIZED" = "$NEW_NORMALIZED" ]; then
        echo "✅ Policy đã là version mới nhất, không cần cập nhật."
    else
        # Tạo version mới
        echo "Đang tạo policy version mới..."
        NEW_VERSION_ID=$(aws iam create-policy-version \
            --policy-arn "$POLICY_ARN" \
            --policy-document file://"$TEMP_POLICY" \
            --set-as-default \
            --query 'PolicyVersion.VersionId' \
            --output text 2>/dev/null || echo "")
        
        if [ -n "$NEW_VERSION_ID" ]; then
            echo "✅ Policy đã được cập nhật. Version mới: ${NEW_VERSION_ID}"
        else
            echo "❌ Không thể tạo policy version mới. Kiểm tra permissions."
            rm "$TEMP_POLICY"
            exit 1
        fi
    fi
else
    # Tạo policy mới
    echo "Đang tạo IAM policy..."
    aws iam create-policy \
        --policy-name "${POLICY_NAME}" \
        --policy-document file://"$TEMP_POLICY" \
        --description "Full permissions for FieldKit deployment to AWS ECS/ECR" \
        --region ${AWS_REGION} > /dev/null
    echo "✅ Policy ${POLICY_NAME} đã được tạo."
fi

# Attach policy vào user hoặc role
echo ""
echo "Đang attach policy vào ${TARGET_TYPE} ${TARGET_NAME}..."

if [ "$TARGET_TYPE" = "USER" ]; then
    # Kiểm tra user tồn tại
    if ! aws iam get-user --user-name "${TARGET_NAME}" &> /dev/null; then
        echo "Error: IAM user ${TARGET_NAME} không tồn tại."
        rm "$TEMP_POLICY"
        exit 1
    fi
    
    # Detach policy cũ nếu có (ignore error nếu chưa attach)
    aws iam detach-user-policy \
        --user-name "${TARGET_NAME}" \
        --policy-arn "$POLICY_ARN" 2>/dev/null || true
    
    # Attach policy mới
    aws iam attach-user-policy \
        --user-name "${TARGET_NAME}" \
        --policy-arn "$POLICY_ARN"
    echo "Policy đã được attach vào user ${TARGET_NAME}."
    
elif [ "$TARGET_TYPE" = "ROLE" ]; then
    # Kiểm tra role tồn tại
    if ! aws iam get-role --role-name "${TARGET_NAME}" &> /dev/null; then
        echo "Error: IAM role ${TARGET_NAME} không tồn tại."
        rm "$TEMP_POLICY"
        exit 1
    fi
    
    # Detach policy cũ nếu có
    aws iam detach-role-policy \
        --role-name "${TARGET_NAME}" \
        --policy-arn "$POLICY_ARN" 2>/dev/null || true
    
    # Attach policy mới
    aws iam attach-role-policy \
        --role-name "${TARGET_NAME}" \
        --policy-arn "$POLICY_ARN"
    echo "Policy đã được attach vào role ${TARGET_NAME}."
else
    echo "Error: TARGET_TYPE phải là USER hoặc ROLE"
    rm "$TEMP_POLICY"
    exit 1
fi

rm "$TEMP_POLICY"

# Hiển thị thông tin policy version
CURRENT_VERSION=$(aws iam get-policy --policy-arn "$POLICY_ARN" --query 'Policy.DefaultVersionId' --output text 2>/dev/null || echo "N/A")
ALL_VERSIONS=$(aws iam list-policy-versions --policy-arn "$POLICY_ARN" --query 'Versions[*].VersionId' --output text 2>/dev/null || echo "")

echo ""
echo "=========================================="
echo "IAM Policy setup hoàn tất!"
echo "=========================================="
echo "Policy ARN: ${POLICY_ARN}"
echo "Current Version: ${CURRENT_VERSION}"
if [ -n "$ALL_VERSIONS" ]; then
    echo "All Versions: ${ALL_VERSIONS}"
fi
echo ""
echo "Kiểm tra permissions:"
echo "  ./deployment/check-prerequisites.sh"
echo ""
echo "Test ECR permissions:"
echo "  ./deployment/test-ecr-permissions.sh"
echo "=========================================="

