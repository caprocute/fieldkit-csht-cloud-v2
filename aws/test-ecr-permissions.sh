#!/bin/bash

# Script để test ECR permissions chi tiết
# Sử dụng: ./deployment/test-ecr-permissions.sh

set -e

AWS_REGION=${AWS_REGION:-ap-southeast-1}
AWS_ACCOUNT_ID=${AWS_ACCOUNT_ID:-""}

if [ -z "$AWS_ACCOUNT_ID" ]; then
    AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text 2>/dev/null || echo "")
    if [ -z "$AWS_ACCOUNT_ID" ]; then
        echo "Error: Không thể lấy AWS_ACCOUNT_ID"
        exit 1
    fi
fi

ECR_REGISTRY="${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com"
REPO_NAME="hieuhk_fieldkit/server"

echo "=========================================="
echo "Testing ECR Permissions"
echo "=========================================="
echo "Account ID: ${AWS_ACCOUNT_ID}"
echo "Region: ${AWS_REGION}"
echo "Repository: ${REPO_NAME}"
echo "=========================================="
echo ""

# Test 1: Get Authorization Token
echo "1. Testing ecr:GetAuthorizationToken..."
if aws ecr get-authorization-token --region ${AWS_REGION} &>/dev/null; then
    echo "   ✅ ecr:GetAuthorizationToken: OK"
else
    echo "   ❌ ecr:GetAuthorizationToken: FAILED"
    echo "      Cần quyền: ecr:GetAuthorizationToken với Resource: *"
fi

# Test 2: Describe Repositories
echo ""
echo "2. Testing ecr:DescribeRepositories..."
if aws ecr describe-repositories --repository-names ${REPO_NAME} --region ${AWS_REGION} &>/dev/null; then
    echo "   ✅ ecr:DescribeRepositories: OK"
    REPO_URI=$(aws ecr describe-repositories --repository-names ${REPO_NAME} --region ${AWS_REGION} --query 'repositories[0].repositoryUri' --output text)
    echo "   Repository URI: ${REPO_URI}"
else
    echo "   ❌ ecr:DescribeRepositories: FAILED"
    echo "      Cần quyền: ecr:DescribeRepositories"
fi

# Test 3: Batch Check Layer Availability
echo ""
echo "3. Testing ecr:BatchCheckLayerAvailability..."
# Tạo một test layer digest
TEST_DIGEST="sha256:1234567890123456789012345678901234567890123456789012345678901234"
if aws ecr batch-check-layer-availability \
    --repository-name ${REPO_NAME} \
    --layer-digests ${TEST_DIGEST} \
    --region ${AWS_REGION} &>/dev/null; then
    echo "   ✅ ecr:BatchCheckLayerAvailability: OK"
else
    ERROR_MSG=$(aws ecr batch-check-layer-availability \
        --repository-name ${REPO_NAME} \
        --layer-digests ${TEST_DIGEST} \
        --region ${AWS_REGION} 2>&1 || true)
    if echo "$ERROR_MSG" | grep -q "AccessDenied\|UnauthorizedOperation"; then
        echo "   ❌ ecr:BatchCheckLayerAvailability: FAILED (Access Denied)"
        echo "      Cần quyền: ecr:BatchCheckLayerAvailability"
    else
        echo "   ⚠️  ecr:BatchCheckLayerAvailability: Test inconclusive (layer không tồn tại là bình thường)"
    fi
fi

# Test 4: List Images
echo ""
echo "4. Testing ecr:ListImages..."
if aws ecr list-images --repository-name ${REPO_NAME} --region ${AWS_REGION} &>/dev/null; then
    echo "   ✅ ecr:ListImages: OK"
    IMAGE_COUNT=$(aws ecr list-images --repository-name ${REPO_NAME} --region ${AWS_REGION} --query 'length(imageIds)' --output text)
    echo "   Số images trong repository: ${IMAGE_COUNT}"
else
    ERROR_MSG=$(aws ecr list-images --repository-name ${REPO_NAME} --region ${AWS_REGION} 2>&1 || true)
    if echo "$ERROR_MSG" | grep -q "AccessDenied\|UnauthorizedOperation"; then
        echo "   ❌ ecr:ListImages: FAILED (Access Denied)"
    else
        echo "   ⚠️  ecr:ListImages: Error (không phải permission): $ERROR_MSG"
    fi
fi

# Test 5: Docker Login
echo ""
echo "5. Testing Docker login to ECR..."
if aws ecr get-login-password --region ${AWS_REGION} | docker login --username AWS --password-stdin ${ECR_REGISTRY} &>/dev/null; then
    echo "   ✅ Docker login: OK"
else
    echo "   ❌ Docker login: FAILED"
    echo "      Cần quyền: ecr:GetAuthorizationToken"
fi

# Test 6: Check IAM Policy
echo ""
echo "6. Checking IAM permissions..."
CALLER_ARN=$(aws sts get-caller-identity --query Arn --output text)
echo "   Current identity: ${CALLER_ARN}"

# Test push một image nhỏ (nếu có)
echo ""
echo "7. Testing push capability..."
if docker images | grep -q "alpine"; then
    echo "   Testing với alpine image..."
    docker tag alpine:latest ${ECR_REGISTRY}/${REPO_NAME}:test-permissions 2>/dev/null || true
    if docker push ${ECR_REGISTRY}/${REPO_NAME}:test-permissions 2>&1 | grep -q "403\|Forbidden\|AccessDenied"; then
        echo "   ❌ Push test: FAILED (403 Forbidden)"
        echo "      Cần các quyền:"
        echo "      - ecr:PutImage"
        echo "      - ecr:InitiateLayerUpload"
        echo "      - ecr:UploadLayerPart"
        echo "      - ecr:CompleteLayerUpload"
        echo "      - ecr:BatchCheckLayerAvailability"
    elif docker push ${ECR_REGISTRY}/${REPO_NAME}:test-permissions 2>&1 | grep -q "pushed\|digest"; then
        echo "   ✅ Push test: OK"
        # Cleanup
        aws ecr batch-delete-image \
            --repository-name ${REPO_NAME} \
            --image-ids imageTag=test-permissions \
            --region ${AWS_REGION} &>/dev/null || true
    else
        echo "   ⚠️  Push test: Inconclusive"
    fi
else
    echo "   ⚠️  Skipping push test (không có alpine image)"
fi

echo ""
echo "=========================================="
echo "Test hoàn tất!"
echo "=========================================="
echo ""
echo "Nếu có lỗi, kiểm tra:"
echo "1. IAM policy đã được attach đúng chưa"
echo "2. Resource ARN trong policy khớp với repository name"
echo "3. Account ID đúng trong policy"
echo ""
echo "Để setup IAM policy:"
echo "  ./deployment/setup-iam-policy.sh YOUR_USERNAME USER"

