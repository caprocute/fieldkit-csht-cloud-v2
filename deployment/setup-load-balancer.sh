#!/bin/bash

# Script để tạo Application Load Balancer cho server service
# Sử dụng: ./deployment/setup-load-balancer.sh [ENVIRONMENT]
# Ví dụ: ./deployment/setup-load-balancer.sh staging

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

AWS_ACCOUNT_ID="$DETECTED_ACCOUNT_ID"

CLUSTER_NAME="fieldkit-${ENVIRONMENT}-app"
SERVICE_NAME="${CLUSTER_NAME}-server"
VPC_ID=${VPC_ID:-""}
SUBNET_IDS=${SUBNET_IDS:-""}
SECURITY_GROUP_ID=${SECURITY_GROUP_ID:-""}

if [ -z "$VPC_ID" ] || [ -z "$SUBNET_IDS" ] || [ -z "$SECURITY_GROUP_ID" ]; then
    echo "Error: VPC_ID, SUBNET_IDS, và SECURITY_GROUP_ID phải được đặt."
    exit 1
fi

echo "=========================================="
echo "Setup Load Balancer cho Server"
echo "=========================================="
echo "Environment: ${ENVIRONMENT}"
echo "Cluster: ${CLUSTER_NAME}"
echo "Service: ${SERVICE_NAME}"
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
    echo "✅ ECS service-linked role đã được tạo."
fi

# Kiểm tra cluster tồn tại
CLUSTER_INFO=$(aws ecs describe-clusters --clusters ${CLUSTER_NAME} --region ${AWS_REGION} --query 'clusters[0]' --output json 2>/dev/null || echo "{}")
CLUSTER_STATUS=$(echo "$CLUSTER_INFO" | jq -r '.status // "NOT_FOUND"')

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
elif [ "$CLUSTER_STATUS" != "ACTIVE" ]; then
    echo "⚠️  Cluster ${CLUSTER_NAME} có status: ${CLUSTER_STATUS}"
    if [ "$CLUSTER_STATUS" = "INACTIVE" ]; then
        echo "   Cluster đang inactive. Không thể kích hoạt lại cluster inactive."
        echo "   Đang xóa cluster cũ và tạo lại..."
        
        # Xóa cluster cũ (nếu có thể)
        aws ecs delete-cluster --cluster ${CLUSTER_NAME} --region ${AWS_REGION} --force 2>/dev/null || true
        
        # Đợi một chút để đảm bảo cluster đã được xóa
        sleep 5
        
        # Tạo cluster mới
        aws ecs create-cluster \
            --cluster-name ${CLUSTER_NAME} \
            --region ${AWS_REGION} \
            --capacity-providers FARGATE FARGATE_SPOT \
            --default-capacity-provider-strategy capacityProvider=FARGATE,weight=1 capacityProvider=FARGATE_SPOT,weight=0
        echo "✅ Cluster ${CLUSTER_NAME} đã được tạo lại."
        sleep 5  # Đợi cluster active
    else
        echo "   Cluster có status không hợp lệ: ${CLUSTER_STATUS}"
        echo "   Cần status ACTIVE để tiếp tục."
        exit 1
    fi
else
    echo "✅ Cluster ${CLUSTER_NAME} đã tồn tại và đang ACTIVE."
fi

# Kiểm tra service tồn tại
SERVICE_STATUS=$(aws ecs describe-services \
    --cluster ${CLUSTER_NAME} \
    --services ${SERVICE_NAME} \
    --region ${AWS_REGION} \
    --query 'services[0].status' \
    --output text 2>/dev/null || echo "NOT_FOUND")

if [ "$SERVICE_STATUS" = "NOT_FOUND" ] || [ "$SERVICE_STATUS" = "None" ] || [ -z "$SERVICE_STATUS" ]; then
    echo "⚠️  Service ${SERVICE_NAME} chưa tồn tại."
    echo "   Để tạo service, chạy:"
    echo "   ./deployment/create-ecs-services.sh ${ENVIRONMENT}"
    echo ""
    echo "   Sau đó chạy lại script này để setup load balancer."
    exit 1
fi

# Tạo security group cho ALB
ALB_SG_NAME="fieldkit-${ENVIRONMENT}-alb-sg"
ALB_SG_ID=$(aws ec2 describe-security-groups \
    --filters "Name=group-name,Values=${ALB_SG_NAME}" "Name=vpc-id,Values=${VPC_ID}" \
    --region ${AWS_REGION} \
    --query 'SecurityGroups[0].GroupId' \
    --output text 2>/dev/null || echo "")

if [ -z "$ALB_SG_ID" ] || [ "$ALB_SG_ID" = "None" ]; then
    echo "Đang tạo security group cho ALB..."
    ALB_SG_ID=$(aws ec2 create-security-group \
        --group-name ${ALB_SG_NAME} \
        --description "Security group for FieldKit Application Load Balancer" \
        --vpc-id ${VPC_ID} \
        --region ${AWS_REGION} \
        --query 'GroupId' \
        --output text)
    
    # Cho phép HTTP và HTTPS từ internet
    aws ec2 authorize-security-group-ingress \
        --group-id ${ALB_SG_ID} \
        --protocol tcp \
        --port 80 \
        --cidr 0.0.0.0/0 \
        --region ${AWS_REGION} > /dev/null
    
    aws ec2 authorize-security-group-ingress \
        --group-id ${ALB_SG_ID} \
        --protocol tcp \
        --port 443 \
        --cidr 0.0.0.0/0 \
        --region ${AWS_REGION} > /dev/null
    
    echo "✅ Đã tạo security group: ${ALB_SG_ID}"
else
    echo "✅ Security group đã tồn tại: ${ALB_SG_ID}"
fi

# Cập nhật security group của service để cho phép traffic từ ALB
echo "Đang cập nhật security group của service..."
aws ec2 authorize-security-group-ingress \
    --group-id ${SECURITY_GROUP_ID} \
    --protocol tcp \
    --port 80 \
    --source-group ${ALB_SG_ID} \
    --region ${AWS_REGION} 2>/dev/null || echo "   Rule đã tồn tại"

# Tạo Application Load Balancer
ALB_NAME="fieldkit-${ENVIRONMENT}-alb"
ALB_ARN=$(aws elbv2 describe-load-balancers \
    --names ${ALB_NAME} \
    --region ${AWS_REGION} \
    --query 'LoadBalancers[0].LoadBalancerArn' \
    --output text 2>/dev/null || echo "")

if [ -z "$ALB_ARN" ] || [ "$ALB_ARN" = "None" ]; then
    echo "Đang tạo Application Load Balancer..."
    
    # Convert subnet IDs từ comma-separated sang array
    SUBNET_ARRAY=($(echo $SUBNET_IDS | tr ',' ' '))
    
    ALB_ARN=$(aws elbv2 create-load-balancer \
        --name ${ALB_NAME} \
        --subnets ${SUBNET_ARRAY[@]} \
        --security-groups ${ALB_SG_ID} \
        --scheme internet-facing \
        --type application \
        --ip-address-type ipv4 \
        --region ${AWS_REGION} \
        --query 'LoadBalancers[0].LoadBalancerArn' \
        --output text)
    
    echo "✅ Đã tạo ALB: ${ALB_ARN}"
    
    # Đợi ALB active
    echo "Đang đợi ALB active..."
    aws elbv2 wait load-balancer-available --load-balancer-arns ${ALB_ARN} --region ${AWS_REGION}
else
    echo "✅ ALB đã tồn tại: ${ALB_ARN}"
fi

# Lấy DNS name của ALB
ALB_DNS=$(aws elbv2 describe-load-balancers \
    --load-balancer-arns ${ALB_ARN} \
    --region ${AWS_REGION} \
    --query 'LoadBalancers[0].DNSName' \
    --output text)

# Tạo target group
TG_NAME="fieldkit-${ENVIRONMENT}-server-tg"
TG_ARN=$(aws elbv2 describe-target-groups \
    --names ${TG_NAME} \
    --region ${AWS_REGION} \
    --query 'TargetGroups[0].TargetGroupArn' \
    --output text 2>/dev/null || echo "")

if [ -z "$TG_ARN" ] || [ "$TG_ARN" = "None" ]; then
    echo "Đang tạo target group..."
    TG_ARN=$(aws elbv2 create-target-group \
        --name ${TG_NAME} \
        --protocol HTTP \
        --port 80 \
        --vpc-id ${VPC_ID} \
        --target-type ip \
        --health-check-path /status \
        --health-check-interval-seconds 30 \
        --health-check-timeout-seconds 5 \
        --healthy-threshold-count 2 \
        --unhealthy-threshold-count 3 \
        --region ${AWS_REGION} \
        --query 'TargetGroups[0].TargetGroupArn' \
        --output text)
    
    echo "✅ Đã tạo target group: ${TG_ARN}"
else
    echo "✅ Target group đã tồn tại: ${TG_ARN}"
fi

# Tạo listener cho HTTP (port 80)
LISTENER_ARN=$(aws elbv2 describe-listeners \
    --load-balancer-arn ${ALB_ARN} \
    --region ${AWS_REGION} \
    --query 'Listeners[?Port==`80`].ListenerArn' \
    --output text 2>/dev/null || echo "")

if [ -z "$LISTENER_ARN" ] || [ "$LISTENER_ARN" = "None" ]; then
    echo "Đang tạo HTTP listener..."
    aws elbv2 create-listener \
        --load-balancer-arn ${ALB_ARN} \
        --protocol HTTP \
        --port 80 \
        --default-actions Type=forward,TargetGroupArn=${TG_ARN} \
        --region ${AWS_REGION} > /dev/null
    echo "✅ Đã tạo HTTP listener"
else
    echo "✅ HTTP listener đã tồn tại"
fi

# Cập nhật service để sử dụng load balancer
echo "Đang cập nhật service để sử dụng load balancer..."
aws ecs update-service \
    --cluster ${CLUSTER_NAME} \
    --service ${SERVICE_NAME} \
    --load-balancers targetGroupArn=${TG_ARN},containerName=server,containerPort=80 \
    --region ${AWS_REGION} > /dev/null

echo ""
echo "=========================================="
echo "✅ Load Balancer setup hoàn tất!"
echo "=========================================="
echo ""
echo "ALB DNS: ${ALB_DNS}"
echo "URL: http://${ALB_DNS}"
echo ""
echo "Target Group: ${TG_ARN}"
echo ""
echo "⚠️  Lưu ý: Service sẽ tự động register với target group."
echo "   Đợi vài phút để service healthy trước khi truy cập."
echo "=========================================="

