#!/bin/bash

# Script để tạo ECS service-linked role nếu chưa có
# Sử dụng: ./deployment/setup-ecs-service-linked-role.sh

set -e

AWS_REGION=${AWS_REGION:-ap-southeast-1}

echo "=========================================="
echo "Setup ECS Service-Linked Role"
echo "=========================================="
echo "Region: ${AWS_REGION}"
echo "=========================================="
echo ""

ROLE_NAME="aws-service-role/ecs.amazonaws.com/AWSServiceRoleForECS"

# Kiểm tra role đã tồn tại chưa
if aws iam get-role --role-name ${ROLE_NAME} &>/dev/null; then
    echo "✅ ECS service-linked role đã tồn tại"
    aws iam get-role --role-name ${ROLE_NAME} --query 'Role.[RoleName,Arn]' --output table
else
    echo "Đang tạo ECS service-linked role..."
    
    # Thử tạo role
    if aws iam create-service-linked-role \
        --aws-service-name ecs.amazonaws.com \
        --region ${AWS_REGION} 2>&1 | tee /tmp/ecs-role-output.txt; then
        echo "✅ ECS service-linked role đã được tạo thành công"
    else
        ERROR_OUTPUT=$(cat /tmp/ecs-role-output.txt)
        if echo "$ERROR_OUTPUT" | grep -q "already exists"; then
            echo "✅ ECS service-linked role đã tồn tại (có thể đã được tạo tự động)"
        else
            echo "⚠️  Có thể role đã tồn tại hoặc cần quyền IAM. Thử với description..."
            aws iam create-service-linked-role \
                --aws-service-name ecs.amazonaws.com \
                --description "Service-linked role for Amazon ECS" \
                --region ${AWS_REGION} 2>&1 || {
                echo "❌ Không thể tạo role. Có thể:"
                echo "   1. Role đã tồn tại (check: aws iam get-role --role-name ${ROLE_NAME})"
                echo "   2. Thiếu quyền IAM: iam:CreateServiceLinkedRole"
                echo "   3. Role đang được tạo tự động bởi AWS"
                exit 1
            }
            echo "✅ ECS service-linked role đã được tạo"
        fi
    fi
    rm -f /tmp/ecs-role-output.txt
fi

echo ""
echo "=========================================="
echo "Setup hoàn tất!"
echo "=========================================="
echo ""
echo "Giờ bạn có thể tạo ECS cluster:"
echo "  aws ecs create-cluster --cluster-name fieldkit-staging --region ${AWS_REGION}"
echo ""

