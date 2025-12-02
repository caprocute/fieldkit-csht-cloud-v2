#!/bin/bash

# Script để kiểm tra và troubleshoot connection timeout đến PostgreSQL
# Sử dụng: ./deployment/check-postgres-connection.sh [ENVIRONMENT]
# Ví dụ: ./deployment/check-postgres-connection.sh staging

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

CLUSTER_NAME="fieldkit-${ENVIRONMENT}-db-v1"
SERVICE_NAME="${CLUSTER_NAME}-postgres"
NAMESPACE="${ENVIRONMENT}"

echo "=========================================="
echo "Kiểm tra PostgreSQL Connection"
echo "=========================================="
echo "Environment: ${ENVIRONMENT}"
echo "Cluster: ${CLUSTER_NAME}"
echo "Service: ${SERVICE_NAME}"
echo "=========================================="
echo ""

# 1. Kiểm tra service status
echo "1. Kiểm tra Service Status..."
SERVICE_INFO=$(aws ecs describe-services \
    --cluster ${CLUSTER_NAME} \
    --services ${SERVICE_NAME} \
    --region ${AWS_REGION} \
    --query 'services[0]' \
    --output json 2>/dev/null || echo "{}")

SERVICE_STATUS=$(echo "$SERVICE_INFO" | jq -r '.status // "NOT_FOUND"')
DESIRED_COUNT=$(echo "$SERVICE_INFO" | jq -r '.desiredCount // 0')
RUNNING_COUNT=$(echo "$SERVICE_INFO" | jq -r '.runningCount // 0')

if [ "$SERVICE_STATUS" = "NOT_FOUND" ] || [ "$SERVICE_STATUS" = "null" ] || [ -z "$SERVICE_STATUS" ]; then
    echo "❌ Service ${SERVICE_NAME} không tồn tại!"
    echo "   Chạy: ./deployment/deploy-database.sh ${ENVIRONMENT}"
    exit 1
fi

echo "   Status: ${SERVICE_STATUS}"
echo "   Desired Count: ${DESIRED_COUNT}"
echo "   Running Count: ${RUNNING_COUNT}"

if [ "$RUNNING_COUNT" -eq 0 ]; then
    echo "❌ Không có task nào đang chạy!"
    echo ""
    echo "   Kiểm tra events:"
    aws ecs describe-services \
        --cluster ${CLUSTER_NAME} \
        --services ${SERVICE_NAME} \
        --region ${AWS_REGION} \
        --query 'services[0].events[0:5]' \
        --output table
    exit 1
fi

echo "✅ Service đang chạy"
echo ""

# 2. Kiểm tra task status và health
echo "2. Kiểm tra Task Status và Health..."
TASK_ARN=$(aws ecs list-tasks \
    --cluster ${CLUSTER_NAME} \
    --service-name ${SERVICE_NAME} \
    --region ${AWS_REGION} \
    --query 'taskArns[0]' \
    --output text 2>/dev/null || echo "")

if [ -z "$TASK_ARN" ] || [ "$TASK_ARN" = "None" ]; then
    echo "❌ Không tìm thấy running task!"
    exit 1
fi

TASK_INFO=$(aws ecs describe-tasks \
    --cluster ${CLUSTER_NAME} \
    --tasks ${TASK_ARN} \
    --region ${AWS_REGION} \
    --query 'tasks[0]' \
    --output json)

LAST_STATUS=$(echo "$TASK_INFO" | jq -r '.lastStatus // "UNKNOWN"')
HEALTH_STATUS=$(echo "$TASK_INFO" | jq -r '.healthStatus // "UNKNOWN"')
CONTAINER_NAME=$(echo "$TASK_INFO" | jq -r '.containers[0].name // "postgres"')

echo "   Task ARN: ${TASK_ARN}"
echo "   Last Status: ${LAST_STATUS}"
echo "   Health Status: ${HEALTH_STATUS}"
echo "   Container Name: ${CONTAINER_NAME}"

if [ "$LAST_STATUS" != "RUNNING" ]; then
    echo "❌ Task không ở trạng thái RUNNING!"
    echo "   Stop Reason: $(echo "$TASK_INFO" | jq -r '.stoppedReason // "N/A"')"
    echo ""
    echo "   Xem logs:"
    echo "   aws logs tail /ecs/fieldkit-postgres --follow --region ${AWS_REGION}"
    exit 1
fi

if [ "$HEALTH_STATUS" != "HEALTHY" ] && [ "$HEALTH_STATUS" != "UNKNOWN" ]; then
    echo "⚠️  Task health status: ${HEALTH_STATUS}"
    echo "   Health check có thể đang fail"
fi

echo "✅ Task đang chạy"
echo ""

# 3. Kiểm tra network configuration
echo "3. Kiểm tra Network Configuration..."
ENI_ID=$(echo "$TASK_INFO" | jq -r '.attachments[0].details[] | select(.name=="networkInterfaceId") | .value' 2>/dev/null || echo "")

if [ -z "$ENI_ID" ] || [ "$ENI_ID" = "null" ]; then
    echo "⚠️  Không tìm thấy Network Interface ID"
else
    echo "   Network Interface ID: ${ENI_ID}"
    
    # Lấy security groups từ ENI
    SECURITY_GROUPS=$(aws ec2 describe-network-interfaces \
        --network-interface-ids ${ENI_ID} \
        --region ${AWS_REGION} \
        --query 'NetworkInterfaces[0].Groups[*].GroupId' \
        --output text 2>/dev/null || echo "")
    
    if [ -n "$SECURITY_GROUPS" ]; then
        echo "   Security Groups: ${SECURITY_GROUPS}"
        echo ""
        echo "   Kiểm tra Security Group Rules..."
        
        for SG_ID in $SECURITY_GROUPS; do
            echo "   Security Group: ${SG_ID}"
            
            # Kiểm tra inbound rules cho port 5432
            INBOUND_RULES=$(aws ec2 describe-security-groups \
                --group-ids ${SG_ID} \
                --region ${AWS_REGION} \
                --query 'SecurityGroups[0].IpPermissions[?FromPort==`5432` || ToPort==`5432`]' \
                --output json 2>/dev/null || echo "[]")
            
            RULE_COUNT=$(echo "$INBOUND_RULES" | jq '. | length')
            
            if [ "$RULE_COUNT" -eq 0 ]; then
                echo "   ⚠️  Không có inbound rule cho port 5432!"
                echo "   Cần thêm rule để cho phép traffic từ:"
                echo "     - Security group của client (nếu trong cùng VPC)"
                echo "     - IP cụ thể (nếu từ internet)"
                echo "     - CIDR block (nếu từ subnet cụ thể)"
            else
                echo "   ✅ Có ${RULE_COUNT} inbound rule(s) cho port 5432:"
                echo "$INBOUND_RULES" | jq -r '.[] | "     - From: \(.IpRanges[0].CidrIp // .UserIdGroupPairs[0].GroupId // "N/A") Port: \(.FromPort)-\(.ToPort) Protocol: \(.IpProtocol)"'
            fi
        done
    fi
fi

echo ""

# 4. Kiểm tra connection string
echo "4. Kiểm tra Connection String..."
POSTGRES_URL=$(aws secretsmanager get-secret-value \
    --secret-id "fieldkit/${NAMESPACE}/database/postgres" \
    --region ${AWS_REGION} \
    --query 'SecretString' \
    --output text 2>/dev/null || echo "")

if [ -z "$POSTGRES_URL" ]; then
    echo "❌ Connection string chưa được setup!"
    echo "   Chạy: ./deployment/create-database-secrets-from-services.sh ${ENVIRONMENT}"
    exit 1
fi

echo "   Connection URL: ${POSTGRES_URL}"

# Parse connection string
if [[ "$POSTGRES_URL" =~ postgres://([^:]+):([^@]+)@([^:]+):([^/]+)/(.+) ]]; then
    DB_USER="${BASH_REMATCH[1]}"
    DB_PASS="${BASH_REMATCH[2]}"
    DB_HOST="${BASH_REMATCH[3]}"
    DB_PORT="${BASH_REMATCH[4]}"
    DB_NAME="${BASH_REMATCH[5]}"
    
    echo "   Host: ${DB_HOST}"
    echo "   Port: ${DB_PORT}"
    echo "   Database: ${DB_NAME}"
    echo "   User: ${DB_USER}"
    
    # Kiểm tra host có phải service discovery name không
    if [[ "$DB_HOST" == *.ecs.internal ]]; then
        echo "   ✅ Sử dụng ECS Service Discovery (chỉ hoạt động trong cùng VPC)"
    else
        echo "   ⚠️  Host không phải service discovery name"
        echo "   Nếu kết nối từ bên ngoài VPC, cần sử dụng NLB DNS hoặc public IP"
    fi
else
    echo "   ⚠️  Không thể parse connection string"
fi

echo ""

# 5. Kiểm tra health check
echo "5. Kiểm tra Health Check..."
HEALTH_CHECK_INFO=$(aws ecs describe-task-definition \
    --task-definition fieldkit-postgres \
    --region ${AWS_REGION} \
    --query 'taskDefinition.containerDefinitions[0].healthCheck' \
    --output json 2>/dev/null || echo "{}")

if [ "$HEALTH_CHECK_INFO" != "{}" ]; then
    HEALTH_CHECK_CMD=$(echo "$HEALTH_CHECK_INFO" | jq -r '.command[0] // "N/A"')
    HEALTH_CHECK_INTERVAL=$(echo "$HEALTH_CHECK_INFO" | jq -r '.interval // "N/A"')
    HEALTH_CHECK_TIMEOUT=$(echo "$HEALTH_CHECK_INFO" | jq -r '.timeout // "N/A"')
    HEALTH_CHECK_RETRIES=$(echo "$HEALTH_CHECK_INFO" | jq -r '.retries // "N/A"')
    HEALTH_CHECK_START_PERIOD=$(echo "$HEALTH_CHECK_INFO" | jq -r '.startPeriod // "N/A"')
    
    echo "   Command: ${HEALTH_CHECK_CMD}"
    echo "   Interval: ${HEALTH_CHECK_INTERVAL}s"
    echo "   Timeout: ${HEALTH_CHECK_TIMEOUT}s"
    echo "   Retries: ${HEALTH_CHECK_RETRIES}"
    echo "   Start Period: ${HEALTH_CHECK_START_PERIOD}s"
    echo "   ✅ Health check được cấu hình"
else
    echo "   ⚠️  Health check chưa được cấu hình"
fi

echo ""

# 6. Tóm tắt và hướng dẫn
echo "=========================================="
echo "Tóm tắt và Hướng dẫn Troubleshooting"
echo "=========================================="
echo ""

if [ "$HEALTH_STATUS" != "HEALTHY" ] && [ "$HEALTH_STATUS" != "UNKNOWN" ]; then
    echo "⚠️  Task health check đang fail!"
    echo "   Xem logs để biết chi tiết:"
    echo "   aws logs tail /ecs/fieldkit-postgres --follow --region ${AWS_REGION}"
    echo ""
fi

echo "Nếu vẫn gặp connection timeout:"
echo ""
echo "1. Kiểm tra Security Group Rules:"
echo "   - Đảm bảo có inbound rule cho port 5432"
echo "   - Nếu kết nối từ bên ngoài VPC, cần rule cho IP/CIDR của bạn"
echo "   - Nếu kết nối từ service khác trong VPC, cần rule cho security group của service đó"
echo ""
echo "2. Kiểm tra Connection String:"
echo "   - Nếu kết nối từ trong VPC: sử dụng service discovery name (*.ecs.internal)"
echo "   - Nếu kết nối từ bên ngoài: sử dụng NLB DNS (sau khi setup public access)"
echo ""
echo "3. Kiểm tra Task Logs:"
echo "   aws logs tail /ecs/fieldkit-postgres --follow --region ${AWS_REGION}"
echo ""
echo "4. Test connection từ trong VPC:"
echo "   - Sử dụng ECS Exec để test từ task khác trong cùng VPC"
echo "   - Hoặc sử dụng bastion host"
echo ""
echo "5. Nếu cần expose ra public:"
echo "   ./deployment/setup-postgres-public.sh ${ENVIRONMENT}"
echo ""

