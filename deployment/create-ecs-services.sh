#!/bin/bash

# Script để tạo ECS cluster, services và task definitions ban đầu
# Chạy một lần để setup infrastructure
# Sử dụng: ./deployment/create-ecs-services.sh [ENVIRONMENT]

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

CLUSTER_NAME="fieldkit-${ENVIRONMENT}-app"
VPC_ID=${VPC_ID:-""}
SUBNET_IDS=${SUBNET_IDS:-""}
SECURITY_GROUP_ID=${SECURITY_GROUP_ID:-""}

# Nếu thiếu các giá trị, thử tự động lấy
if [ -z "$VPC_ID" ] || [ -z "$SUBNET_IDS" ] || [ -z "$SECURITY_GROUP_ID" ]; then
    echo "=========================================="
    echo "Thiếu thông tin VPC và Networking"
    echo "=========================================="
    echo ""
    
    # Thử lấy VPC mặc định
    if [ -z "$VPC_ID" ]; then
        DEFAULT_VPC=$(aws ec2 describe-vpcs \
            --region ${AWS_REGION} \
            --filters "Name=isDefault,Values=true" \
            --query 'Vpcs[0].VpcId' \
            --output text 2>/dev/null || echo "")
        
        if [ -n "$DEFAULT_VPC" ] && [ "$DEFAULT_VPC" != "None" ]; then
            echo "💡 Tìm thấy default VPC: ${DEFAULT_VPC}"
            echo "   Sử dụng: export VPC_ID=\"${DEFAULT_VPC}\""
            
            # Thử lấy subnets trong VPC này
            if [ -z "$SUBNET_IDS" ]; then
                DEFAULT_SUBNETS=$(aws ec2 describe-subnets \
                    --region ${AWS_REGION} \
                    --filters "Name=vpc-id,Values=${DEFAULT_VPC}" \
                    --query 'Subnets[*].SubnetId' \
                    --output text 2>/dev/null | tr '\t' ',' || echo "")
                
                if [ -n "$DEFAULT_SUBNETS" ] && [ "$DEFAULT_SUBNETS" != "None" ]; then
                    echo "💡 Tìm thấy subnets: ${DEFAULT_SUBNETS}"
                    echo "   Sử dụng: export SUBNET_IDS=\"${DEFAULT_SUBNETS}\""
                    
                    # Thử lấy hoặc tạo security group
                    if [ -z "$SECURITY_GROUP_ID" ]; then
                        DEFAULT_SG=$(aws ec2 describe-security-groups \
                            --region ${AWS_REGION} \
                            --filters "Name=vpc-id,Values=${DEFAULT_VPC}" "Name=group-name,Values=default" \
                            --query 'SecurityGroups[0].GroupId' \
                            --output text 2>/dev/null || echo "")
                        
                        if [ -n "$DEFAULT_SG" ] && [ "$DEFAULT_SG" != "None" ]; then
                            echo "💡 Tìm thấy default security group: ${DEFAULT_SG}"
                            echo "   Sử dụng: export SECURITY_GROUP_ID=\"${DEFAULT_SG}\""
                        fi
                    fi
                fi
            fi
        fi
        echo ""
    fi
    
    echo "Cần thiết lập các biến môi trường sau:"
    echo "  - VPC_ID: VPC ID để deploy ECS tasks"
    echo "  - SUBNET_IDS: Danh sách subnet IDs (phân cách bằng dấu phẩy)"
    echo "  - SECURITY_GROUP_ID: Security group ID cho ECS tasks"
    echo ""
    echo "Cách lấy các giá trị này:"
    echo ""
    echo "1. Lấy VPC_ID:"
    echo "   aws ec2 describe-vpcs --region ${AWS_REGION} --query 'Vpcs[0].VpcId' --output text"
    echo ""
    echo "2. Lấy SUBNET_IDS (chọn ít nhất 2 subnets trong cùng VPC):"
    echo "   aws ec2 describe-subnets --region ${AWS_REGION} --filters \"Name=vpc-id,Values=YOUR_VPC_ID\" --query 'Subnets[*].SubnetId' --output text | tr '\\t' ','"
    echo ""
    echo "3. Lấy SECURITY_GROUP_ID (hoặc tạo mới):"
    echo "   aws ec2 describe-security-groups --region ${AWS_REGION} --filters \"Name=vpc-id,Values=YOUR_VPC_ID\" --query 'SecurityGroups[0].GroupId' --output text"
    echo ""
    echo "Hoặc tạo security group mới:"
    echo "   aws ec2 create-security-group --group-name fieldkit-ecs-sg --description \"Security group for FieldKit ECS tasks\" --vpc-id YOUR_VPC_ID --region ${AWS_REGION}"
    echo ""
    echo "Ví dụ sử dụng:"
    echo "   export VPC_ID=\"vpc-12345678\""
    echo "   export SUBNET_IDS=\"subnet-11111111,subnet-22222222\""
    echo "   export SECURITY_GROUP_ID=\"sg-12345678\""
    echo "   ./deployment/create-ecs-services.sh ${ENVIRONMENT}"
    echo ""
    exit 1
fi

ECR_REGISTRY="${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com"

echo "=========================================="
echo "Creating ECS Infrastructure"
echo "=========================================="
echo "Environment: ${ENVIRONMENT}"
echo "Cluster: ${CLUSTER_NAME}"
echo "=========================================="

# Kiểm tra và tạo ECS service-linked role nếu chưa có
if ! aws iam get-role --role-name aws-service-role/ecs.amazonaws.com/AWSServiceRoleForECS &>/dev/null; then
    echo "ECS service-linked role chưa tồn tại. Đang tạo..."
    aws iam create-service-linked-role \
        --aws-service-name ecs.amazonaws.com \
        --region ${AWS_REGION} 2>/dev/null || {
        echo "Đang thử tạo với description..."
        aws iam create-service-linked-role \
            --aws-service-name ecs.amazonaws.com \
            --description "Service-linked role for Amazon ECS" \
            --region ${AWS_REGION} 2>/dev/null || true
    }
    echo "✅ Đã tạo ECS service-linked role"
fi

# Tạo CloudWatch Log Groups
echo "Đang tạo CloudWatch log groups..."
for log_group in "/ecs/fieldkit-server" "/ecs/fieldkit-charting" "/ecs/fieldkit-postgres" "/ecs/fieldkit-timescale"; do
    # Thử tạo log group trực tiếp (sẽ thành công nếu chưa tồn tại, hoặc báo lỗi nếu đã tồn tại)
    if aws logs create-log-group \
        --log-group-name ${log_group} \
        --region ${AWS_REGION} 2>/dev/null; then
        echo "✅ Log group ${log_group} đã được tạo."
    else
        # Kiểm tra xem có phải lỗi "đã tồn tại" không
        if aws logs describe-log-groups \
            --log-group-name-prefix ${log_group} \
            --region ${AWS_REGION} \
            --query "logGroups[?logGroupName=='${log_group}'].logGroupName" \
            --output text 2>/dev/null | grep -q "${log_group}"; then
            echo "✅ Log group ${log_group} đã tồn tại."
        else
            # Nếu không có quyền DescribeLogGroups, vẫn thử tạo và bỏ qua lỗi nếu đã tồn tại
            echo "⚠️  Không thể kiểm tra log group ${log_group} (có thể thiếu quyền logs:DescribeLogGroups)"
            echo "   Giả định log group đã tồn tại hoặc sẽ được tạo tự động khi service chạy."
        fi
    fi
done

# Đăng ký Task Definitions
echo "Đang đăng ký task definitions..."

# Server Task Definition
SERVER_TASK_DEF="deployment/ecs-task-definitions/server-task.json"
if [ -f "${SERVER_TASK_DEF}" ]; then
    # Thay thế placeholders
    sed -e "s/ACCOUNT_ID/${AWS_ACCOUNT_ID}/g" \
        -e "s/REGION/${AWS_REGION}/g" \
        -e "s/NAMESPACE/${ENVIRONMENT}/g" \
        ${SERVER_TASK_DEF} > /tmp/server-task.json
    
    aws ecs register-task-definition \
        --cli-input-json file:///tmp/server-task.json \
        --region ${AWS_REGION} > /dev/null
    echo "Server task definition đã được đăng ký."
    rm /tmp/server-task.json
fi

# Charting Task Definition
CHARTING_TASK_DEF="deployment/ecs-task-definitions/charting-task.json"
if [ -f "${CHARTING_TASK_DEF}" ]; then
    sed -e "s/ACCOUNT_ID/${AWS_ACCOUNT_ID}/g" \
        -e "s/REGION/${AWS_REGION}/g" \
        ${CHARTING_TASK_DEF} > /tmp/charting-task.json
    
    aws ecs register-task-definition \
        --cli-input-json file:///tmp/charting-task.json \
        --region ${AWS_REGION} > /dev/null
    echo "Charting task definition đã được đăng ký."
    rm /tmp/charting-task.json
fi

# Kiểm tra cluster status
CLUSTER_STATUS=$(aws ecs describe-clusters --clusters ${CLUSTER_NAME} --region ${AWS_REGION} --query 'clusters[0].status' --output text 2>/dev/null || echo "NOT_FOUND")

if [ "$CLUSTER_STATUS" = "NOT_FOUND" ] || [ "$CLUSTER_STATUS" = "null" ] || [ -z "$CLUSTER_STATUS" ] || [ "$CLUSTER_STATUS" = "None" ]; then
    echo "⚠️  Cluster ${CLUSTER_NAME} không tồn tại."
    echo "   Đang tạo cluster mới..."
    aws ecs create-cluster \
        --cluster-name ${CLUSTER_NAME} \
        --region ${AWS_REGION} \
        --capacity-providers FARGATE FARGATE_SPOT \
        --default-capacity-provider-strategy capacityProvider=FARGATE,weight=1 capacityProvider=FARGATE_SPOT,weight=0
    echo "✅ Cluster ${CLUSTER_NAME} đã được tạo."
    sleep 5  # Đợi cluster active
elif [ "$CLUSTER_STATUS" = "INACTIVE" ]; then
    echo "⚠️  Cluster ${CLUSTER_NAME} đang INACTIVE."
    echo "   Đang xóa cluster cũ và tạo lại..."
    
    # Xóa tất cả services trong cluster trước (nếu có)
    echo "   Đang xóa các services trong cluster..."
    SERVICES=$(aws ecs list-services --cluster ${CLUSTER_NAME} --region ${AWS_REGION} --query 'serviceArns[]' --output text 2>/dev/null || echo "")
    if [ -n "$SERVICES" ] && [ "$SERVICES" != "None" ]; then
        for SERVICE_ARN in $SERVICES; do
            SERVICE_NAME=$(echo $SERVICE_ARN | awk -F'/' '{print $NF}')
            echo "     Đang xóa service: ${SERVICE_NAME}"
            aws ecs delete-service \
                --cluster ${CLUSTER_NAME} \
                --service ${SERVICE_NAME} \
                --region ${AWS_REGION} \
                --force > /dev/null 2>&1 || true
        done
        echo "   Đợi services được xóa..."
        sleep 10
    fi
    
    # Xóa cluster cũ
    aws ecs delete-cluster --cluster ${CLUSTER_NAME} --region ${AWS_REGION} --force 2>/dev/null || true
    
    # Đợi một chút để đảm bảo cluster đã được xóa
    echo "   Đợi cluster được xóa hoàn toàn..."
    sleep 10
    
    # Tạo cluster mới
    echo "   Đang tạo cluster mới..."
    aws ecs create-cluster \
        --cluster-name ${CLUSTER_NAME} \
        --region ${AWS_REGION} \
        --capacity-providers FARGATE FARGATE_SPOT \
        --default-capacity-provider-strategy capacityProvider=FARGATE,weight=1 capacityProvider=FARGATE_SPOT,weight=0
    echo "✅ Cluster ${CLUSTER_NAME} đã được tạo lại."
    sleep 5  # Đợi cluster active
elif [ "$CLUSTER_STATUS" != "ACTIVE" ]; then
    echo "⚠️  Cluster ${CLUSTER_NAME} có status: ${CLUSTER_STATUS}"
    echo "   Cluster có status không hợp lệ: ${CLUSTER_STATUS}"
    echo "   Cần status ACTIVE để tiếp tục."
    exit 1
else
    echo "✅ Cluster ${CLUSTER_NAME} đã tồn tại và đang ACTIVE."
fi

# Tạo ECS Services
echo "Đang tạo ECS services..."

# Server Service
SERVER_SERVICE="${CLUSTER_NAME}-server"
SERVICE_STATUS=$(aws ecs describe-services \
    --cluster ${CLUSTER_NAME} \
    --services ${SERVER_SERVICE} \
    --region ${AWS_REGION} \
    --query 'services[0].status' \
    --output text 2>/dev/null || echo "NOT_FOUND")

if [ "$SERVICE_STATUS" = "NOT_FOUND" ] || [ "$SERVICE_STATUS" = "None" ] || [ -z "$SERVICE_STATUS" ]; then
    echo "Đang tạo service ${SERVER_SERVICE}..."
    aws ecs create-service \
        --cluster ${CLUSTER_NAME} \
        --service-name ${SERVER_SERVICE} \
        --task-definition fieldkit-server \
        --desired-count 1 \
        --launch-type FARGATE \
        --network-configuration "awsvpcConfiguration={subnets=[${SUBNET_IDS}],securityGroups=[${SECURITY_GROUP_ID}],assignPublicIp=ENABLED}" \
        --region ${AWS_REGION} > /dev/null
    echo "✅ Service ${SERVER_SERVICE} đã được tạo."
elif [ "$SERVICE_STATUS" = "DRAINING" ]; then
    echo "⚠️  Service ${SERVER_SERVICE} đang trong trạng thái DRAINING."
    echo "   Đang đợi service hoàn thành draining..."
    while true; do
        CURRENT_STATUS=$(aws ecs describe-services \
            --cluster ${CLUSTER_NAME} \
            --services ${SERVER_SERVICE} \
            --region ${AWS_REGION} \
            --query 'services[0].status' \
            --output text 2>/dev/null || echo "NOT_FOUND")
        if [ "$CURRENT_STATUS" != "DRAINING" ]; then
            echo "   Service đã hoàn thành draining (status: ${CURRENT_STATUS})"
            break
        fi
        echo "   Đang đợi... (status: ${CURRENT_STATUS})"
        sleep 5
    done
    # Nếu service đã inactive sau khi draining, xóa và tạo lại
    if [ "$CURRENT_STATUS" = "INACTIVE" ]; then
        echo "   Service đã inactive. Đang xóa và tạo lại..."
        aws ecs delete-service \
            --cluster ${CLUSTER_NAME} \
            --service ${SERVER_SERVICE} \
            --region ${AWS_REGION} \
            --force > /dev/null 2>&1 || true
        sleep 5
        aws ecs create-service \
            --cluster ${CLUSTER_NAME} \
            --service-name ${SERVER_SERVICE} \
            --task-definition fieldkit-server \
            --desired-count 1 \
            --launch-type FARGATE \
            --network-configuration "awsvpcConfiguration={subnets=[${SUBNET_IDS}],securityGroups=[${SECURITY_GROUP_ID}],assignPublicIp=ENABLED}" \
            --region ${AWS_REGION} > /dev/null
        echo "   ✅ Service ${SERVER_SERVICE} đã được tạo lại."
    fi
elif [ "$SERVICE_STATUS" = "INACTIVE" ]; then
    echo "⚠️  Service ${SERVER_SERVICE} đang INACTIVE."
    echo "   Đang xóa và tạo lại service..."
    aws ecs delete-service \
        --cluster ${CLUSTER_NAME} \
        --service ${SERVER_SERVICE} \
        --region ${AWS_REGION} \
        --force > /dev/null 2>&1 || true
    sleep 5
    aws ecs create-service \
        --cluster ${CLUSTER_NAME} \
        --service-name ${SERVER_SERVICE} \
        --task-definition fieldkit-server \
        --desired-count 1 \
        --launch-type FARGATE \
        --network-configuration "awsvpcConfiguration={subnets=[${SUBNET_IDS}],securityGroups=[${SECURITY_GROUP_ID}],assignPublicIp=ENABLED}" \
        --region ${AWS_REGION} > /dev/null
    echo "   ✅ Service ${SERVER_SERVICE} đã được tạo lại."
else
    echo "✅ Service ${SERVER_SERVICE} đã tồn tại (status: ${SERVICE_STATUS})."
fi

# Charting Service
CHARTING_SERVICE="${CLUSTER_NAME}-charting"
SERVICE_STATUS=$(aws ecs describe-services \
    --cluster ${CLUSTER_NAME} \
    --services ${CHARTING_SERVICE} \
    --region ${AWS_REGION} \
    --query 'services[0].status' \
    --output text 2>/dev/null || echo "NOT_FOUND")

if [ "$SERVICE_STATUS" = "NOT_FOUND" ] || [ "$SERVICE_STATUS" = "None" ] || [ -z "$SERVICE_STATUS" ]; then
    echo "Đang tạo service ${CHARTING_SERVICE}..."
    aws ecs create-service \
        --cluster ${CLUSTER_NAME} \
        --service-name ${CHARTING_SERVICE} \
        --task-definition fieldkit-charting \
        --desired-count 1 \
        --launch-type FARGATE \
        --network-configuration "awsvpcConfiguration={subnets=[${SUBNET_IDS}],securityGroups=[${SECURITY_GROUP_ID}],assignPublicIp=ENABLED}" \
        --region ${AWS_REGION} > /dev/null
    echo "✅ Service ${CHARTING_SERVICE} đã được tạo."
elif [ "$SERVICE_STATUS" = "DRAINING" ]; then
    echo "⚠️  Service ${CHARTING_SERVICE} đang trong trạng thái DRAINING."
    echo "   Đang đợi service hoàn thành draining..."
    while true; do
        CURRENT_STATUS=$(aws ecs describe-services \
            --cluster ${CLUSTER_NAME} \
            --services ${CHARTING_SERVICE} \
            --region ${AWS_REGION} \
            --query 'services[0].status' \
            --output text 2>/dev/null || echo "NOT_FOUND")
        if [ "$CURRENT_STATUS" != "DRAINING" ]; then
            echo "   Service đã hoàn thành draining (status: ${CURRENT_STATUS})"
            break
        fi
        echo "   Đang đợi... (status: ${CURRENT_STATUS})"
        sleep 5
    done
    # Nếu service đã inactive sau khi draining, xóa và tạo lại
    if [ "$CURRENT_STATUS" = "INACTIVE" ]; then
        echo "   Service đã inactive. Đang xóa và tạo lại..."
        aws ecs delete-service \
            --cluster ${CLUSTER_NAME} \
            --service ${CHARTING_SERVICE} \
            --region ${AWS_REGION} \
            --force > /dev/null 2>&1 || true
        sleep 5
        aws ecs create-service \
            --cluster ${CLUSTER_NAME} \
            --service-name ${CHARTING_SERVICE} \
            --task-definition fieldkit-charting \
            --desired-count 1 \
            --launch-type FARGATE \
            --network-configuration "awsvpcConfiguration={subnets=[${SUBNET_IDS}],securityGroups=[${SECURITY_GROUP_ID}],assignPublicIp=ENABLED}" \
            --region ${AWS_REGION} > /dev/null
        echo "   ✅ Service ${CHARTING_SERVICE} đã được tạo lại."
    fi
elif [ "$SERVICE_STATUS" = "INACTIVE" ]; then
    echo "⚠️  Service ${CHARTING_SERVICE} đang INACTIVE."
    echo "   Đang xóa và tạo lại service..."
    aws ecs delete-service \
        --cluster ${CLUSTER_NAME} \
        --service ${CHARTING_SERVICE} \
        --region ${AWS_REGION} \
        --force > /dev/null 2>&1 || true
    sleep 5
    aws ecs create-service \
        --cluster ${CLUSTER_NAME} \
        --service-name ${CHARTING_SERVICE} \
        --task-definition fieldkit-charting \
        --desired-count 1 \
        --launch-type FARGATE \
        --network-configuration "awsvpcConfiguration={subnets=[${SUBNET_IDS}],securityGroups=[${SECURITY_GROUP_ID}],assignPublicIp=ENABLED}" \
        --region ${AWS_REGION} > /dev/null
    echo "   ✅ Service ${CHARTING_SERVICE} đã được tạo lại."
else
    echo "✅ Service ${CHARTING_SERVICE} đã tồn tại (status: ${SERVICE_STATUS})."
fi

echo ""
echo "=========================================="
echo "ECS Application Infrastructure setup hoàn tất!"
echo "=========================================="
echo ""
echo "Application Cluster: ${CLUSTER_NAME}"
echo "Services đã được tạo:"
echo "  - ${SERVER_SERVICE}"
echo "  - ${CHARTING_SERVICE}"
echo ""
echo "⚠️  Lưu ý: Database services cần được deploy riêng:"
echo "  ./deployment/deploy-database.sh ${ENVIRONMENT}"
echo ""
echo "Để setup Load Balancer cho server:"
echo "  ./deployment/setup-load-balancer.sh ${ENVIRONMENT}"
echo ""
echo "Để setup secrets:"
echo "  ./deployment/setup-session-key.sh ${ENVIRONMENT}"
echo "  ./deployment/create-database-secrets-from-services.sh ${ENVIRONMENT}"
echo "=========================================="

