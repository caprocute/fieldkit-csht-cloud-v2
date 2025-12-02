#!/bin/bash

# Script để fix lỗi 403 Forbidden khi push ECR
# Sử dụng: ./deployment/fix-ecr-403.sh [USER_NAME]

set -e

USER_NAME=${1:-""}
AWS_REGION=${AWS_REGION:-ap-southeast-1}

if [ -z "$USER_NAME" ]; then
    # Thử lấy user name từ current identity
    USER_ARN=$(aws sts get-caller-identity --query Arn --output text 2>/dev/null || echo "")
    if [[ "$USER_ARN" == *":user/"* ]]; then
        USER_NAME=$(echo "$USER_ARN" | cut -d'/' -f2)
        echo "Tự động detect user: ${USER_NAME}"
    else
        echo "Error: Cần cung cấp IAM user name"
        echo "Sử dụng: ./deployment/fix-ecr-403.sh USER_NAME"
        exit 1
    fi
fi

AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text 2>/dev/null || echo "")
if [ -z "$AWS_ACCOUNT_ID" ]; then
    echo "Error: Không thể lấy AWS_ACCOUNT_ID"
    exit 1
fi

echo "=========================================="
echo "Fixing ECR 403 Forbidden Error"
echo "=========================================="
echo "User: ${USER_NAME}"
echo "Account ID: ${AWS_ACCOUNT_ID}"
echo "Region: ${AWS_REGION}"
echo "=========================================="
echo ""

# Bước 1: Kiểm tra policy hiện tại
echo "1. Kiểm tra IAM policies hiện tại..."
ATTACHED_POLICIES=$(aws iam list-attached-user-policies --user-name "${USER_NAME}" --query 'AttachedPolicies[*].PolicyArn' --output text 2>/dev/null || echo "")
echo "   Attached policies: ${ATTACHED_POLICIES}"

# Bước 2: Setup IAM policy mới
echo ""
echo "2. Setup IAM policy mới..."
./deployment/setup-iam-policy.sh "${USER_NAME}" USER

# Bước 3: Kiểm tra policy document
echo ""
echo "3. Kiểm tra policy document..."
# Tìm policy name (có thể là FieldKitDeploymentPolicy hoặc FieldKitDeploymentPolicyV5)
POLICY_ARN=""
for policy_name in "FieldKitDeploymentPolicyV5" "FieldKitDeploymentPolicy"; do
    test_arn="arn:aws:iam::${AWS_ACCOUNT_ID}:policy/${policy_name}"
    if aws iam get-policy --policy-arn "$test_arn" &>/dev/null; then
        POLICY_ARN="$test_arn"
        echo "   Tìm thấy policy: ${policy_name}"
        break
    fi
done

if [ -z "$POLICY_ARN" ]; then
    echo "   ⚠️  Không tìm thấy policy. Sẽ tạo mới..."
    POLICY_ARN="arn:aws:iam::${AWS_ACCOUNT_ID}:policy/FieldKitDeploymentPolicyV5"
fi

if aws iam get-policy --policy-arn "$POLICY_ARN" &>/dev/null; then
    CURRENT_VERSION=$(aws iam get-policy --policy-arn "$POLICY_ARN" --query 'Policy.DefaultVersionId' --output text)
    POLICY_DOC=$(aws iam get-policy-version --policy-arn "$POLICY_ARN" --version-id "$CURRENT_VERSION" --query 'PolicyVersion.Document' --output json)
    
    # Kiểm tra Resource ARN có đúng không
    REPO_RESOURCE="arn:aws:ecr:${AWS_REGION}:${AWS_ACCOUNT_ID}:repository/hieuhk_fieldkit/*"
    if echo "$POLICY_DOC" | jq -e ".Statement[] | select(.Sid==\"ECRImagePushPull\") | .Resource[] | select(.==\"${REPO_RESOURCE}\")" &>/dev/null; then
        echo "   ✅ Resource ARN đúng: ${REPO_RESOURCE}"
    else
        echo "   ❌ Resource ARN không khớp trong policy"
        echo "   Expected: ${REPO_RESOURCE}"
    fi
    
    # Kiểm tra có đủ permissions không
    REQUIRED_ACTIONS=("ecr:PutImage" "ecr:InitiateLayerUpload" "ecr:UploadLayerPart" "ecr:CompleteLayerUpload" "ecr:BatchCheckLayerAvailability")
    for action in "${REQUIRED_ACTIONS[@]}"; do
        if echo "$POLICY_DOC" | jq -e ".Statement[] | select(.Sid==\"ECRImagePushPull\") | .Action[] | select(.==\"${action}\")" &>/dev/null; then
            echo "   ✅ Có quyền: ${action}"
        else
            echo "   ❌ Thiếu quyền: ${action}"
        fi
    done
else
    echo "   ❌ Policy không tồn tại"
fi

# Bước 4: Test ECR permissions
echo ""
echo "4. Testing ECR permissions..."
./deployment/test-ecr-permissions.sh

# Bước 5: Re-authenticate Docker
echo ""
echo "5. Re-authenticating Docker với ECR..."
ECR_REGISTRY="${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com"
if aws ecr get-login-password --region ${AWS_REGION} | docker login --username AWS --password-stdin ${ECR_REGISTRY} 2>&1 | grep -q "Succeeded"; then
    echo "   ✅ Docker login thành công"
else
    echo "   ❌ Docker login failed"
fi

# Bước 6: Test push với image nhỏ
echo ""
echo "6. Testing push capability..."
if docker images | grep -q "alpine"; then
    TEST_IMAGE="${ECR_REGISTRY}/hieuhk_fieldkit/server:test-permissions"
    docker tag alpine:latest ${TEST_IMAGE} 2>/dev/null || true
    
    if docker push ${TEST_IMAGE} 2>&1 | grep -qE "(pushed|digest|403|Forbidden)"; then
        PUSH_OUTPUT=$(docker push ${TEST_IMAGE} 2>&1 || true)
        if echo "$PUSH_OUTPUT" | grep -q "403\|Forbidden"; then
            echo "   ❌ Push test FAILED - Vẫn còn lỗi 403"
            echo "   Output: $PUSH_OUTPUT"
        else
            echo "   ✅ Push test OK"
            # Cleanup
            aws ecr batch-delete-image \
                --repository-name hieuhk_fieldkit/server \
                --image-ids imageTag=test-permissions \
                --region ${AWS_REGION} &>/dev/null || true
        fi
    fi
else
    echo "   ⚠️  Skipping push test (không có alpine image)"
fi

echo ""
echo "=========================================="
echo "Fix hoàn tất!"
echo "=========================================="
echo ""
echo "Nếu vẫn còn lỗi 403, kiểm tra:"
echo "1. Policy đã được attach đúng user chưa"
echo "2. Resource ARN trong policy khớp với repository name"
echo "3. Account ID đúng trong policy"
echo ""
echo "Để xem policy chi tiết:"
echo "  aws iam get-policy-version --policy-arn ${POLICY_ARN} --version-id <VERSION_ID>"

