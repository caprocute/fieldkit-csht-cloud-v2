#!/bin/bash

# Script để deploy images đã build lên AWS ECS
# Sử dụng: ./deployment/deploy.sh [VERSION] [ENVIRONMENT]
# Ví dụ: ./deployment/deploy.sh v1.0.0 staging

set -e

VERSION=${1:-latest}
ENVIRONMENT=${2:-staging}

AWS_REGION=${AWS_REGION:-ap-southeast-1}
AWS_ACCOUNT_ID=${AWS_ACCOUNT_ID:-""}
CLUSTER_NAME=${CLUSTER_NAME:-"fieldkit-${ENVIRONMENT}-app"}

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

ECR_REGISTRY="${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com"
REPO_PREFIX="hieuhk_fieldkit"

# Service names
SERVER_SERVICE="${CLUSTER_NAME}-server"
CHARTING_SERVICE="${CLUSTER_NAME}-charting"

echo "=========================================="
echo "Deploying to AWS ECS"
echo "=========================================="
echo "Version: ${VERSION}"
echo "Environment: ${ENVIRONMENT}"
echo "Cluster: ${CLUSTER_NAME}"
echo "=========================================="

# Kiểm tra cluster tồn tại
CLUSTER_INFO=$(aws ecs describe-clusters --clusters ${CLUSTER_NAME} --region ${AWS_REGION} --query 'clusters[0]' --output json 2>/dev/null || echo "{}")
CLUSTER_STATUS=$(echo "$CLUSTER_INFO" | jq -r '.status // "NOT_FOUND"')

if [ "$CLUSTER_STATUS" = "NOT_FOUND" ] || [ "$CLUSTER_STATUS" = "null" ] || [ -z "$CLUSTER_STATUS" ] || [ "$CLUSTER_STATUS" = "None" ]; then
        echo "⚠️  Cluster ${CLUSTER_NAME} không tồn tại."
        echo ""
        echo "Để tạo cluster và setup infrastructure, chạy:"
        echo "  ./deployment/create-ecs-services.sh ${ENVIRONMENT}"
        echo ""
        echo "Hoặc tạo cluster thủ công:"
        echo "  aws ecs create-cluster --cluster-name ${CLUSTER_NAME} --region ${AWS_REGION}"
        echo ""
        read -p "Bạn có muốn tạo cluster ngay bây giờ? (y/n) " -n 1 -r
        echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        echo "Đang kiểm tra ECS service-linked role..."
        
        # Kiểm tra và tạo ECS service-linked role nếu chưa có
        if ! aws iam get-role --role-name aws-service-role/ecs.amazonaws.com/AWSServiceRoleForECS &>/dev/null; then
            echo "   ECS service-linked role chưa tồn tại. Đang tạo..."
            aws iam create-service-linked-role \
                --aws-service-name ecs.amazonaws.com \
                --region ${AWS_REGION} 2>/dev/null || {
                echo "   ⚠️  Không thể tự động tạo role. Đang thử với description..."
                aws iam create-service-linked-role \
                    --aws-service-name ecs.amazonaws.com \
                    --description "Service-linked role for Amazon ECS" \
                    --region ${AWS_REGION} 2>/dev/null || true
            }
            echo "   ✅ Đã tạo ECS service-linked role (hoặc đã tồn tại)"
        else
            echo "   ✅ ECS service-linked role đã tồn tại"
        fi
        
        echo "Đang tạo cluster..."
        aws ecs create-cluster \
            --cluster-name ${CLUSTER_NAME} \
            --region ${AWS_REGION} \
            --capacity-providers FARGATE FARGATE_SPOT \
            --default-capacity-provider-strategy capacityProvider=FARGATE,weight=1
        echo "✅ Cluster đã được tạo."
        echo "⚠️  Lưu ý: Bạn vẫn cần chạy './deployment/create-ecs-services.sh ${ENVIRONMENT}' để setup services và task definitions."
        echo ""
        echo "Đang chờ cluster active..."
        sleep 5
    else
        exit 1
    fi
elif [ "$CLUSTER_STATUS" != "ACTIVE" ]; then
    echo "⚠️  Cluster ${CLUSTER_NAME} có status: ${CLUSTER_STATUS}"
    echo ""
    if [ "$CLUSTER_STATUS" = "INACTIVE" ]; then
        echo "Cluster đang inactive. Đang thử kích hoạt..."
        # Có thể cần tạo lại cluster nếu inactive
        read -p "Bạn có muốn tạo lại cluster? (y/n) " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            # Xóa cluster cũ nếu cần
            aws ecs delete-cluster --cluster ${CLUSTER_NAME} --region ${AWS_REGION} 2>/dev/null || true
            # Tạo lại
            aws ecs create-cluster \
                --cluster-name ${CLUSTER_NAME} \
                --region ${AWS_REGION} \
                --capacity-providers FARGATE FARGATE_SPOT \
                --default-capacity-provider-strategy capacityProvider=FARGATE,weight=1
            echo "✅ Cluster đã được tạo lại."
            sleep 5
        else
            exit 1
        fi
    else
        echo "Error: Cluster ${CLUSTER_NAME} có status không hợp lệ: ${CLUSTER_STATUS}"
        echo "Cần status ACTIVE để deploy."
        exit 1
    fi
fi

# Update Server Service
echo "Đang cập nhật Server service..."

# Kiểm tra task definition có tồn tại không (không phụ thuộc vào service)
TASK_DEF_FAMILY="fieldkit-server"
TASK_DEF_EXISTS=$(aws ecs describe-task-definition \
    --task-definition ${TASK_DEF_FAMILY} \
    --region ${AWS_REGION} \
    --query 'taskDefinition.taskDefinitionArn' \
    --output text 2>/dev/null || echo "NOT_FOUND")

if [ "$TASK_DEF_EXISTS" = "NOT_FOUND" ] || [ -z "$TASK_DEF_EXISTS" ]; then
    echo "⚠️  Task definition '${TASK_DEF_FAMILY}' chưa tồn tại."
    echo "   Đang tạo task definition từ template..."
    
    # Load task definition từ file
    TASK_DEF_FILE="deployment/ecs-task-definitions/server-task.json"
    if [ ! -f "$TASK_DEF_FILE" ]; then
        echo "Error: Task definition file không tồn tại: ${TASK_DEF_FILE}"
        exit 1
    fi
    
    # Replace placeholders
    TEMP_TASK_DEF=$(mktemp)
    sed "s/ACCOUNT_ID/${AWS_ACCOUNT_ID}/g; s/REGION/${AWS_REGION}/g; s/NAMESPACE/${ENVIRONMENT}/g" "$TASK_DEF_FILE" > "$TEMP_TASK_DEF"
    
    # Update image URI
    IMAGE_URI="${ECR_REGISTRY}/${REPO_PREFIX}/server:${VERSION}"
    jq --arg img "$IMAGE_URI" '.containerDefinitions[0].image = $img' "$TEMP_TASK_DEF" > "${TEMP_TASK_DEF}.tmp"
    mv "${TEMP_TASK_DEF}.tmp" "$TEMP_TASK_DEF"
    
    # Register task definition
    NEW_TASK_DEF_ARN=$(aws ecs register-task-definition \
        --cli-input-json file://"$TEMP_TASK_DEF" \
        --region ${AWS_REGION} \
        --query 'taskDefinition.taskDefinitionArn' \
        --output text)
    
    rm "$TEMP_TASK_DEF"
    echo "✅ Task definition đã được tạo: ${NEW_TASK_DEF_ARN}"
else
    echo "Lấy task definition hiện tại: ${TASK_DEF_EXISTS}"
    
    # Get current task definition
    CURRENT_TASK_DEF=$(aws ecs describe-task-definition \
        --task-definition ${TASK_DEF_FAMILY} \
        --region ${AWS_REGION} \
        --query 'taskDefinition' \
        --output json)
    
    # Load template để merge environment variables
    TASK_DEF_FILE="deployment/ecs-task-definitions/server-task.json"
    TEMPLATE_ENV=$(cat "$TASK_DEF_FILE" | jq '.containerDefinitions[0].environment // []')
    
    # Update image URI và merge environment variables từ template
    IMAGE_URI="${ECR_REGISTRY}/${REPO_PREFIX}/server:${VERSION}"
    NEW_TASK_DEF=$(echo "$CURRENT_TASK_DEF" | jq --arg img "$IMAGE_URI" --argjson env "$TEMPLATE_ENV" \
        '.containerDefinitions[0].image = $img | .containerDefinitions[0].environment = $env | del(.taskDefinitionArn) | del(.revision) | del(.status) | del(.requiresAttributes) | del(.compatibilities) | del(.registeredAt) | del(.registeredBy)')
    
    # Register new task definition (dùng temp file để tránh lỗi pipe)
    TEMP_TASK_DEF=$(mktemp)
    echo "$NEW_TASK_DEF" > "$TEMP_TASK_DEF"
    
    NEW_TASK_DEF_ARN=$(aws ecs register-task-definition \
        --cli-input-json file://"$TEMP_TASK_DEF" \
        --region ${AWS_REGION} \
        --query 'taskDefinition.taskDefinitionArn' \
        --output text)
    
    rm "$TEMP_TASK_DEF"
    
    echo "Task definition mới: ${NEW_TASK_DEF_ARN}"
fi

# Update service nếu tồn tại
SERVER_SERVICE_EXISTS=$(aws ecs describe-services \
    --cluster ${CLUSTER_NAME} \
    --services ${SERVER_SERVICE} \
    --region ${AWS_REGION} \
    --query 'services[0].status' \
    --output text 2>/dev/null || echo "NOT_FOUND")

# Kiểm tra service có tồn tại không (xử lý None, null, empty)
if [ "$SERVER_SERVICE_EXISTS" != "NOT_FOUND" ] && [ "$SERVER_SERVICE_EXISTS" != "None" ] && [ "$SERVER_SERVICE_EXISTS" != "null" ] && [ -n "$SERVER_SERVICE_EXISTS" ]; then
    echo "Đang cập nhật service ${SERVER_SERVICE}..."
    aws ecs update-service \
        --cluster ${CLUSTER_NAME} \
        --service ${SERVER_SERVICE} \
        --task-definition ${NEW_TASK_DEF_ARN} \
        --force-new-deployment \
        --region ${AWS_REGION} > /dev/null
    
    echo "✅ Server service đang được cập nhật..."
else
    echo "⚠️  Service ${SERVER_SERVICE} chưa tồn tại."
    echo "   Task definition đã được tạo: ${NEW_TASK_DEF_ARN}"
    echo "   Để tạo service, chạy: ./deployment/create-ecs-services.sh ${ENVIRONMENT}"
fi

# Update Charting Service
echo "Đang cập nhật Charting service..."

# Kiểm tra task definition có tồn tại không
TASK_DEF_FAMILY="fieldkit-charting"
TASK_DEF_EXISTS=$(aws ecs describe-task-definition \
    --task-definition ${TASK_DEF_FAMILY} \
    --region ${AWS_REGION} \
    --query 'taskDefinition.taskDefinitionArn' \
    --output text 2>/dev/null || echo "NOT_FOUND")

if [ "$TASK_DEF_EXISTS" = "NOT_FOUND" ] || [ -z "$TASK_DEF_EXISTS" ]; then
    echo "⚠️  Task definition '${TASK_DEF_FAMILY}' chưa tồn tại."
    echo "   Đang tạo task definition từ template..."
    
    # Load task definition từ file
    TASK_DEF_FILE="deployment/ecs-task-definitions/charting-task.json"
    if [ ! -f "$TASK_DEF_FILE" ]; then
        echo "Error: Task definition file không tồn tại: ${TASK_DEF_FILE}"
        exit 1
    fi
    
    # Replace placeholders
    TEMP_TASK_DEF=$(mktemp)
    sed "s/ACCOUNT_ID/${AWS_ACCOUNT_ID}/g; s/REGION/${AWS_REGION}/g; s/NAMESPACE/${ENVIRONMENT}/g" "$TASK_DEF_FILE" > "$TEMP_TASK_DEF"
    
    # Update image URI
    IMAGE_URI="${ECR_REGISTRY}/${REPO_PREFIX}/charting:${VERSION}"
    jq --arg img "$IMAGE_URI" '.containerDefinitions[0].image = $img' "$TEMP_TASK_DEF" > "${TEMP_TASK_DEF}.tmp"
    mv "${TEMP_TASK_DEF}.tmp" "$TEMP_TASK_DEF"
    
    # Register task definition
    NEW_TASK_DEF_ARN=$(aws ecs register-task-definition \
        --cli-input-json file://"$TEMP_TASK_DEF" \
        --region ${AWS_REGION} \
        --query 'taskDefinition.taskDefinitionArn' \
        --output text)
    
    rm "$TEMP_TASK_DEF"
    echo "✅ Task definition đã được tạo: ${NEW_TASK_DEF_ARN}"
else
    echo "Lấy task definition hiện tại: ${TASK_DEF_EXISTS}"
    
    # Get current task definition
    CURRENT_TASK_DEF=$(aws ecs describe-task-definition \
        --task-definition ${TASK_DEF_FAMILY} \
        --region ${AWS_REGION} \
        --query 'taskDefinition' \
        --output json)
    
    # Update image URI
    IMAGE_URI="${ECR_REGISTRY}/${REPO_PREFIX}/charting:${VERSION}"
    NEW_TASK_DEF=$(echo "$CURRENT_TASK_DEF" | jq --arg img "$IMAGE_URI" \
        '.containerDefinitions[0].image = $img | del(.taskDefinitionArn) | del(.revision) | del(.status) | del(.requiresAttributes) | del(.compatibilities) | del(.registeredAt) | del(.registeredBy)')
    
    # Register new task definition (dùng temp file để tránh lỗi pipe)
    TEMP_TASK_DEF=$(mktemp)
    echo "$NEW_TASK_DEF" > "$TEMP_TASK_DEF"
    
    NEW_TASK_DEF_ARN=$(aws ecs register-task-definition \
        --cli-input-json file://"$TEMP_TASK_DEF" \
        --region ${AWS_REGION} \
        --query 'taskDefinition.taskDefinitionArn' \
        --output text)
    
    rm "$TEMP_TASK_DEF"
    
    echo "Task definition mới: ${NEW_TASK_DEF_ARN}"
fi

# Update service nếu tồn tại
CHARTING_SERVICE_EXISTS=$(aws ecs describe-services \
    --cluster ${CLUSTER_NAME} \
    --services ${CHARTING_SERVICE} \
    --region ${AWS_REGION} \
    --query 'services[0].status' \
    --output text 2>/dev/null || echo "NOT_FOUND")

# Kiểm tra service có tồn tại không (xử lý None, null, empty)
if [ "$CHARTING_SERVICE_EXISTS" != "NOT_FOUND" ] && [ "$CHARTING_SERVICE_EXISTS" != "None" ] && [ "$CHARTING_SERVICE_EXISTS" != "null" ] && [ -n "$CHARTING_SERVICE_EXISTS" ]; then
    echo "Đang cập nhật service ${CHARTING_SERVICE}..."
    aws ecs update-service \
        --cluster ${CLUSTER_NAME} \
        --service ${CHARTING_SERVICE} \
        --task-definition ${NEW_TASK_DEF_ARN} \
        --force-new-deployment \
        --region ${AWS_REGION} > /dev/null
    
    echo "✅ Charting service đang được cập nhật..."
else
    echo "⚠️  Service ${CHARTING_SERVICE} chưa tồn tại."
    echo "   Task definition đã được tạo: ${NEW_TASK_DEF_ARN}"
    echo "   Để tạo service, chạy: ./deployment/create-ecs-services.sh ${ENVIRONMENT}"
fi

echo "=========================================="
echo "Deployment đã được khởi động!"
echo "=========================================="
echo "Theo dõi deployment tại: https://console.aws.amazon.com/ecs/v2/clusters/${CLUSTER_NAME}/services"
echo "=========================================="

