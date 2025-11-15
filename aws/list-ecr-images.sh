#!/bin/bash

# Script để list các Docker images đã push lên ECR
# Sử dụng: ./deployment/list-ecr-images.sh [REPOSITORY_NAME]

set -e

AWS_REGION=${AWS_REGION:-ap-southeast-1}

# Lấy Account ID từ credentials
AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text 2>/dev/null || echo "")
if [ -z "$AWS_ACCOUNT_ID" ]; then
    echo "Error: Không thể lấy AWS_ACCOUNT_ID từ credentials"
    exit 1
fi

ECR_REGISTRY="${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com"
REPO_PREFIX="hieuhk_fieldkit"

# Repository name (optional)
REPO_NAME=${1:-""}

echo "=========================================="
echo "ECR Images List"
echo "=========================================="
echo "Account ID: ${AWS_ACCOUNT_ID}"
echo "Region: ${AWS_REGION}"
echo "Registry: ${ECR_REGISTRY}"
echo "=========================================="
echo ""

if [ -n "$REPO_NAME" ]; then
    # List images trong một repository cụ thể
    FULL_REPO_NAME="${REPO_PREFIX}/${REPO_NAME}"
    echo "Images trong repository: ${FULL_REPO_NAME}"
    echo ""
    
    if aws ecr describe-repositories --repository-names "${FULL_REPO_NAME}" --region ${AWS_REGION} &>/dev/null; then
        # List images với tags
        aws ecr list-images \
            --repository-name "${FULL_REPO_NAME}" \
            --region ${AWS_REGION} \
            --query 'imageIds[*].[imageTag,imageDigest]' \
            --output table
        
        # List images với details
        echo ""
        echo "Chi tiết images:"
        IMAGE_TAGS=$(aws ecr list-images \
            --repository-name "${FULL_REPO_NAME}" \
            --region ${AWS_REGION} \
            --query 'imageIds[?imageTag!=`null`].imageTag' \
            --output text)
        
        if [ -n "$IMAGE_TAGS" ]; then
            for tag in $IMAGE_TAGS; do
                echo ""
                echo "Tag: ${tag}"
                aws ecr describe-images \
                    --repository-name "${FULL_REPO_NAME}" \
                    --image-ids imageTag="${tag}" \
                    --region ${AWS_REGION} \
                    --query 'imageDetails[0].[registryId,repositoryName,imageTags[0],imagePushedAt,imageSizeInBytes]' \
                    --output table
            done
        fi
    else
        echo "Repository không tồn tại: ${FULL_REPO_NAME}"
    fi
else
    # List tất cả repositories và images
    echo "Tất cả repositories:"
    echo ""
    
    REPOS=$(aws ecr describe-repositories \
        --region ${AWS_REGION} \
        --query "repositories[?starts_with(repositoryName, '${REPO_PREFIX}/')].repositoryName" \
        --output text)
    
    if [ -z "$REPOS" ]; then
        echo "Không tìm thấy repositories với prefix: ${REPO_PREFIX}/"
        exit 0
    fi
    
    for repo in $REPOS; do
        echo "=========================================="
        echo "Repository: ${repo}"
        echo "=========================================="
        
        # Count images
        IMAGE_COUNT=$(aws ecr list-images \
            --repository-name "${repo}" \
            --region ${AWS_REGION} \
            --query 'length(imageIds)' \
            --output text)
        
        echo "Tổng số images: ${IMAGE_COUNT}"
        
        if [ "$IMAGE_COUNT" -gt 0 ]; then
            # List tags
            TAGS=$(aws ecr list-images \
                --repository-name "${repo}" \
                --region ${AWS_REGION} \
                --query 'imageIds[?imageTag!=`null`].imageTag' \
                --output text)
            
            if [ -n "$TAGS" ]; then
                echo "Tags:"
                for tag in $TAGS; do
                    echo "  - ${tag}"
                done
            else
                echo "  (Không có tags)"
            fi
            
            # Show latest image
            LATEST=$(aws ecr describe-images \
                --repository-name "${repo}" \
                --region ${AWS_REGION} \
                --query 'sort_by(imageDetails, &imagePushedAt)[-1]' \
                --output json 2>/dev/null || echo "{}")
            
            if [ "$LATEST" != "{}" ]; then
                LATEST_TAG=$(echo "$LATEST" | jq -r '.imageTags[0] // "untagged"')
                LATEST_PUSHED=$(echo "$LATEST" | jq -r '.imagePushedAt')
                LATEST_SIZE=$(echo "$LATEST" | jq -r '.imageSizeInBytes')
                LATEST_SIZE_MB=$(echo "scale=2; $LATEST_SIZE / 1024 / 1024" | bc)
                
                echo ""
                echo "Latest image:"
                echo "  Tag: ${LATEST_TAG}"
                echo "  Pushed: ${LATEST_PUSHED}"
                echo "  Size: ${LATEST_SIZE_MB} MB"
            fi
        fi
        echo ""
    done
fi

echo ""
echo "=========================================="
echo "Full image URLs:"
echo "=========================================="
if [ -n "$REPO_NAME" ]; then
    FULL_REPO_NAME="${REPO_PREFIX}/${REPO_NAME}"
    TAGS=$(aws ecr list-images \
        --repository-name "${FULL_REPO_NAME}" \
        --region ${AWS_REGION} \
        --query 'imageIds[?imageTag!=`null`].imageTag' \
        --output text 2>/dev/null || echo "")
    
    if [ -n "$TAGS" ]; then
        for tag in $TAGS; do
            echo "${ECR_REGISTRY}/${FULL_REPO_NAME}:${tag}"
        done
    fi
else
    for repo in $REPOS; do
        TAGS=$(aws ecr list-images \
            --repository-name "${repo}" \
            --region ${AWS_REGION} \
            --query 'imageIds[?imageTag!=`null`].imageTag' \
            --output text 2>/dev/null || echo "")
        
        if [ -n "$TAGS" ]; then
            for tag in $TAGS; do
                echo "${ECR_REGISTRY}/${repo}:${tag}"
            done
        fi
    done
fi
echo "=========================================="

