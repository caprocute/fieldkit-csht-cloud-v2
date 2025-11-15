#!/bin/bash

# Script để expose TimescaleDB ra public qua Network Load Balancer
# Sử dụng: ./deployment/setup-timescale-public.sh [ENVIRONMENT]
# Ví dụ: ./deployment/setup-timescale-public.sh staging

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
        echo "✅ Sử dụng AWS_PROFILE: ${AWS_PROFILE}"
    fi
fi

# Validate AWS_ACCOUNT_ID - Luôn lấy từ AWS credentials
echo "Đang kiểm tra AWS credentials..."
DETECTED_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text 2>/dev/null || echo "")

if [ -z "$DETECTED_ACCOUNT_ID" ]; then
    echo ""
    echo "❌ Error: Không thể lấy AWS_ACCOUNT_ID từ AWS credentials."
    echo ""
    echo "Các cách khắc phục:"
    echo "1. Cấu hình AWS credentials:"
    echo "   aws configure"
    echo ""
    echo "2. Hoặc set AWS_PROFILE:"
    echo "   export AWS_PROFILE=your-profile-name"
    echo "   ./deployment/setup-timescale-public.sh ${ENVIRONMENT}"
    echo ""
    echo "3. Hoặc set AWS credentials trực tiếp:"
    echo "   export AWS_ACCESS_KEY_ID=your-access-key"
    echo "   export AWS_SECRET_ACCESS_KEY=your-secret-key"
    echo "   export AWS_REGION=${AWS_REGION}"
    echo ""
    echo "4. Kiểm tra credentials hiện tại:"
    echo "   aws sts get-caller-identity"
    echo ""
    exit 1
fi

AWS_ACCOUNT_ID="$DETECTED_ACCOUNT_ID"
echo "✅ AWS Account ID: ${AWS_ACCOUNT_ID}"

CLUSTER_NAME="fieldkit-${ENVIRONMENT}-db-v1"
SERVICE_NAME="${CLUSTER_NAME}-timescale"
VPC_ID=${VPC_ID:-""}
SUBNET_IDS=${SUBNET_IDS:-""}
SECURITY_GROUP_ID=${SECURITY_GROUP_ID:-""}

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
    echo "  - SUBNET_IDS: Danh sách subnet IDs (phân cách bằng dấu phẩy, cần ít nhất 2 subnets)"
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
    echo "3. Lấy SECURITY_GROUP_ID từ ECS service (nếu đã có service):"
    echo "   # Lấy security group từ service hiện tại"
    echo "   aws ecs describe-services --cluster ${CLUSTER_NAME} --services ${SERVICE_NAME} --region ${AWS_REGION} --query 'services[0].networkConfiguration.awsvpcConfiguration.securityGroups[0]' --output text"
    echo ""
    echo "   Hoặc tạo security group mới:"
    echo "   aws ec2 create-security-group --group-name fieldkit-${ENVIRONMENT}-timescale-sg --description \"Security group for FieldKit TimescaleDB\" --vpc-id YOUR_VPC_ID --region ${AWS_REGION}"
    echo ""
    echo "Ví dụ sử dụng:"
    echo "   export VPC_ID=\"vpc-12345678\""
    echo "   export SUBNET_IDS=\"subnet-11111111,subnet-22222222\""
    echo "   export SECURITY_GROUP_ID=\"sg-12345678\""
    echo "   ./deployment/setup-timescale-public.sh ${ENVIRONMENT}"
    echo ""
    exit 1
fi

echo "=========================================="
echo "Setup Public Access cho TimescaleDB"
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
    echo "   ./deployment/deploy-database.sh ${ENVIRONMENT}"
    echo ""
    echo "   Sau đó chạy lại script này để setup public access."
    exit 1
fi

# Tạo security group cho NLB
NLB_SG_NAME="fieldkit-${ENVIRONMENT}-timescale-nlb-sg"
NLB_SG_ID=$(aws ec2 describe-security-groups \
    --filters "Name=group-name,Values=${NLB_SG_NAME}" "Name=vpc-id,Values=${VPC_ID}" \
    --region ${AWS_REGION} \
    --query 'SecurityGroups[0].GroupId' \
    --output text 2>/dev/null || echo "")

if [ -z "$NLB_SG_ID" ] || [ "$NLB_SG_ID" = "None" ]; then
    echo "Đang tạo security group cho NLB..."
    NLB_SG_ID=$(aws ec2 create-security-group \
        --group-name ${NLB_SG_NAME} \
        --description "Security group for FieldKit TimescaleDB NLB" \
        --vpc-id ${VPC_ID} \
        --region ${AWS_REGION} \
        --query 'GroupId' \
        --output text)
    
    # Cho phép TimescaleDB từ internet (⚠️  Cảnh báo bảo mật!)
    echo "⚠️  Cho phép TimescaleDB port 5432 từ internet (khuyến nghị chỉ cho phép IP cụ thể)"
    read -p "Bạn có muốn cho phép từ tất cả IP (0.0.0.0/0)? (y/n) " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        aws ec2 authorize-security-group-ingress \
            --group-id ${NLB_SG_ID} \
            --protocol tcp \
            --port 5432 \
            --cidr 0.0.0.0/0 \
            --region ${AWS_REGION} > /dev/null
    else
        MY_IP=$(curl -s https://checkip.amazonaws.com)
        echo "Cho phép từ IP của bạn: ${MY_IP}"
        aws ec2 authorize-security-group-ingress \
            --group-id ${NLB_SG_ID} \
            --protocol tcp \
            --port 5432 \
            --cidr ${MY_IP}/32 \
            --region ${AWS_REGION} > /dev/null
    fi
    
    echo "✅ Đã tạo security group: ${NLB_SG_ID}"
else
    echo "✅ Security group đã tồn tại: ${NLB_SG_ID}"
fi

# Cập nhật security group của service để cho phép traffic từ NLB
echo "Đang cập nhật security group của TimescaleDB service..."
aws ec2 authorize-security-group-ingress \
    --group-id ${SECURITY_GROUP_ID} \
    --protocol tcp \
    --port 5432 \
    --source-group ${NLB_SG_ID} \
    --region ${AWS_REGION} 2>/dev/null || echo "   Rule đã tồn tại"

# Tạo Network Load Balancer
NLB_NAME="fieldkit-${ENVIRONMENT}-timescale-nlb"
NLB_ARN=$(aws elbv2 describe-load-balancers \
    --names ${NLB_NAME} \
    --region ${AWS_REGION} \
    --query 'LoadBalancers[0].LoadBalancerArn' \
    --output text 2>/dev/null || echo "")

if [ -z "$NLB_ARN" ] || [ "$NLB_ARN" = "None" ]; then
    echo "Đang tạo Network Load Balancer..."
    
    # Convert subnet IDs từ comma-separated sang array
    SUBNET_ARRAY=($(echo $SUBNET_IDS | tr ',' ' '))
    
    NLB_ARN=$(aws elbv2 create-load-balancer \
        --name ${NLB_NAME} \
        --subnets ${SUBNET_ARRAY[@]} \
        --security-groups ${NLB_SG_ID} \
        --scheme internet-facing \
        --type network \
        --ip-address-type ipv4 \
        --region ${AWS_REGION} \
        --query 'LoadBalancers[0].LoadBalancerArn' \
        --output text)
    
    echo "✅ Đã tạo NLB: ${NLB_ARN}"
    
    # Đợi NLB active
    echo "Đang đợi NLB active..."
    aws elbv2 wait load-balancer-available --load-balancer-arns ${NLB_ARN} --region ${AWS_REGION}
else
    echo "✅ NLB đã tồn tại: ${NLB_ARN}"
fi

# Lấy DNS name của NLB
NLB_DNS=$(aws elbv2 describe-load-balancers \
    --load-balancer-arns ${NLB_ARN} \
    --region ${AWS_REGION} \
    --query 'LoadBalancers[0].DNSName' \
    --output text)

# Tạo target group
TG_NAME="fieldkit-${ENVIRONMENT}-timescale-tg"
TG_ARN=$(aws elbv2 describe-target-groups \
    --names ${TG_NAME} \
    --region ${AWS_REGION} \
    --query 'TargetGroups[0].TargetGroupArn' \
    --output text 2>/dev/null || echo "")

if [ -z "$TG_ARN" ] || [ "$TG_ARN" = "None" ]; then
    echo "Đang tạo target group..."
    TG_ARN=$(aws elbv2 create-target-group \
        --name ${TG_NAME} \
        --protocol TCP \
        --port 5432 \
        --vpc-id ${VPC_ID} \
        --target-type ip \
        --health-check-protocol TCP \
        --health-check-interval-seconds 30 \
        --health-check-timeout-seconds 10 \
        --healthy-threshold-count 2 \
        --unhealthy-threshold-count 3 \
        --region ${AWS_REGION} \
        --query 'TargetGroups[0].TargetGroupArn' \
        --output text)
    
    echo "✅ Đã tạo target group: ${TG_ARN}"
else
    echo "✅ Target group đã tồn tại: ${TG_ARN}"
fi

# Tạo listener cho TCP (port 5432)
LISTENER_ARN=$(aws elbv2 describe-listeners \
    --load-balancer-arn ${NLB_ARN} \
    --region ${AWS_REGION} \
    --query 'Listeners[?Port==`5432`].ListenerArn' \
    --output text 2>/dev/null || echo "")

if [ -z "$LISTENER_ARN" ] || [ "$LISTENER_ARN" = "None" ]; then
    echo "Đang tạo TCP listener..."
    aws elbv2 create-listener \
        --load-balancer-arn ${NLB_ARN} \
        --protocol TCP \
        --port 5432 \
        --default-actions Type=forward,TargetGroupArn=${TG_ARN} \
        --region ${AWS_REGION} > /dev/null
    echo "✅ Đã tạo TCP listener"
else
    echo "✅ TCP listener đã tồn tại"
fi

# Cập nhật service để sử dụng load balancer
echo "Đang cập nhật service để sử dụng load balancer..."
aws ecs update-service \
    --cluster ${CLUSTER_NAME} \
    --service ${SERVICE_NAME} \
    --load-balancers targetGroupArn=${TG_ARN},containerName=timescale,containerPort=5432 \
    --region ${AWS_REGION} > /dev/null

echo ""
echo "=========================================="
echo "✅ TimescaleDB Public Access setup hoàn tất!"
echo "=========================================="
echo ""
echo "NLB DNS: ${NLB_DNS}"
echo "Connection string:"
echo "  postgres://postgres:PASSWORD@${NLB_DNS}:5432/fk"
echo ""
echo "Để lấy password:"
echo "  aws secretsmanager get-secret-value --secret-id fieldkit/${ENVIRONMENT}/database/timescale/password --region ${AWS_REGION} --query SecretString --output text"
echo ""
echo "⚠️  Lưu ý bảo mật:"
echo "  - TimescaleDB đang expose ra internet"
echo "  - Nên sử dụng SSL/TLS connection"
echo "  - Nên giới hạn IP source trong security group"
echo "=========================================="

