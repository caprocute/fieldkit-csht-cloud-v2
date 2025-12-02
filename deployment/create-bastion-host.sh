#!/bin/bash

# Script để tạo bastion host để truy cập PostgreSQL từ internet
# Sử dụng: ./deployment/create-bastion-host.sh [ENVIRONMENT]
# Ví dụ: ./deployment/create-bastion-host.sh staging

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

CLUSTER_NAME="fieldkit-${ENVIRONMENT}"
VPC_ID=${VPC_ID:-""}
SUBNET_IDS=${SUBNET_IDS:-""}
SECURITY_GROUP_ID=${SECURITY_GROUP_ID:-""}

if [ -z "$VPC_ID" ] || [ -z "$SUBNET_IDS" ] || [ -z "$SECURITY_GROUP_ID" ]; then
    echo "Error: VPC_ID, SUBNET_IDS, và SECURITY_GROUP_ID phải được đặt."
    exit 1
fi

echo "=========================================="
echo "Tạo Bastion Host để truy cập PostgreSQL"
echo "=========================================="
echo "Environment: ${ENVIRONMENT}"
echo "VPC: ${VPC_ID}"
echo "=========================================="
echo ""
echo "⚠️  Lưu ý: Bastion host sẽ tốn chi phí (~$0.01/giờ cho t2.micro)"
echo "   Nhớ dừng instance khi không dùng!"
echo ""
read -p "Bạn có muốn tiếp tục? (y/n) " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    exit 1
fi

# Lấy subnet đầu tiên (thường là public subnet)
FIRST_SUBNET=$(echo $SUBNET_IDS | cut -d',' -f1)

# Tạo security group cho bastion (cho phép SSH từ internet)
BASTION_SG_NAME="fieldkit-${ENVIRONMENT}-bastion-sg"
BASTION_SG_ID=$(aws ec2 describe-security-groups \
    --filters "Name=group-name,Values=${BASTION_SG_NAME}" "Name=vpc-id,Values=${VPC_ID}" \
    --region ${AWS_REGION} \
    --query 'SecurityGroups[0].GroupId' \
    --output text 2>/dev/null || echo "")

if [ -z "$BASTION_SG_ID" ] || [ "$BASTION_SG_ID" = "None" ]; then
    echo "Đang tạo security group cho bastion..."
    BASTION_SG_ID=$(aws ec2 create-security-group \
        --group-name ${BASTION_SG_NAME} \
        --description "Security group for FieldKit bastion host" \
        --vpc-id ${VPC_ID} \
        --region ${AWS_REGION} \
        --query 'GroupId' \
        --output text)
    
    # Cho phép SSH từ internet
    MY_IP=$(curl -s https://checkip.amazonaws.com)
    aws ec2 authorize-security-group-ingress \
        --group-id ${BASTION_SG_ID} \
        --protocol tcp \
        --port 22 \
        --cidr ${MY_IP}/32 \
        --region ${AWS_REGION} > /dev/null
    
    echo "✅ Đã tạo security group: ${BASTION_SG_ID}"
    echo "   SSH chỉ cho phép từ IP của bạn: ${MY_IP}"
else
    echo "✅ Security group đã tồn tại: ${BASTION_SG_ID}"
fi

# Tạo key pair nếu chưa có
KEY_NAME="fieldkit-${ENVIRONMENT}-bastion-key"
if ! aws ec2 describe-key-pairs --key-names ${KEY_NAME} --region ${AWS_REGION} &>/dev/null; then
    echo "Đang tạo key pair..."
    aws ec2 create-key-pair \
        --key-name ${KEY_NAME} \
        --region ${AWS_REGION} \
        --query 'KeyMaterial' \
        --output text > /tmp/${KEY_NAME}.pem
    chmod 400 /tmp/${KEY_NAME}.pem
    echo "✅ Đã tạo key pair: ${KEY_NAME}"
    echo "   Private key saved tại: /tmp/${KEY_NAME}.pem"
    echo "   ⚠️  Lưu key này cẩn thận!"
else
    echo "✅ Key pair đã tồn tại: ${KEY_NAME}"
fi

# Tạo EC2 instance (t2.micro - free tier eligible)
INSTANCE_NAME="fieldkit-${ENVIRONMENT}-bastion"
echo "Đang tạo EC2 instance..."

# Tìm latest Amazon Linux 2023 AMI
AMI_ID=$(aws ec2 describe-images \
    --owners amazon \
    --filters "Name=name,Values=al2023-ami-2023*" "Name=architecture,Values=x86_64" \
    --region ${AWS_REGION} \
    --query 'Images | sort_by(@, &CreationDate) | [-1].ImageId' \
    --output text)

INSTANCE_ID=$(aws ec2 run-instances \
    --image-id ${AMI_ID} \
    --instance-type t2.micro \
    --key-name ${KEY_NAME} \
    --security-group-ids ${BASTION_SG_ID} \
    --subnet-id ${FIRST_SUBNET} \
    --associate-public-ip-address \
    --tag-specifications "ResourceType=instance,Tags=[{Key=Name,Value=${INSTANCE_NAME}}]" \
    --region ${AWS_REGION} \
    --query 'Instances[0].InstanceId' \
    --output text)

echo "✅ Đã tạo EC2 instance: ${INSTANCE_ID}"
echo "   Đang đợi instance running..."

aws ec2 wait instance-running --instance-ids ${INSTANCE_ID} --region ${AWS_REGION}

# Lấy public IP
PUBLIC_IP=$(aws ec2 describe-instances \
    --instance-ids ${INSTANCE_ID} \
    --region ${AWS_REGION} \
    --query 'Reservations[0].Instances[0].PublicIpAddress' \
    --output text)

echo ""
echo "=========================================="
echo "✅ Bastion host đã sẵn sàng!"
echo "=========================================="
echo ""
echo "Public IP: ${PUBLIC_IP}"
echo "Instance ID: ${INSTANCE_ID}"
echo ""
echo "Để SSH vào bastion:"
echo "  ssh -i /tmp/${KEY_NAME}.pem ec2-user@${PUBLIC_IP}"
echo ""
echo "Từ bastion, bạn có thể kết nối đến PostgreSQL:"
echo "  # Cài đặt PostgreSQL client"
echo "  sudo yum install -y postgresql15"
echo ""
echo "  # Lấy connection string từ Secrets Manager"
echo "  aws secretsmanager get-secret-value --secret-id fieldkit/${ENVIRONMENT}/database/postgres --region ${AWS_REGION} --query SecretString --output text"
echo ""
echo "  # Hoặc kết nối trực tiếp"
echo "  psql -h fieldkit-${ENVIRONMENT}-postgres.ecs.internal -U fieldkit -d fieldkit"
echo ""
echo "⚠️  Nhớ dừng instance khi không dùng:"
echo "  aws ec2 stop-instances --instance-ids ${INSTANCE_ID} --region ${AWS_REGION}"
echo ""

