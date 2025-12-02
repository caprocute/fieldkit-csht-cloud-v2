#!/bin/bash

# Script để chạy database migrations tự động
# Sử dụng: ./deployment/run-migrations.sh [ENVIRONMENT]
# Ví dụ: ./deployment/run-migrations.sh staging

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
NAMESPACE="${ENVIRONMENT}"
VPC_ID=${VPC_ID:-""}
SUBNET_IDS=${SUBNET_IDS:-""}
SECURITY_GROUP_ID=${SECURITY_GROUP_ID:-""}

if [ -z "$VPC_ID" ] || [ -z "$SUBNET_IDS" ] || [ -z "$SECURITY_GROUP_ID" ]; then
    echo "Error: VPC_ID, SUBNET_IDS, và SECURITY_GROUP_ID phải được đặt."
    exit 1
fi

ECR_REGISTRY="${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com"
REPO_PREFIX="hieuhk_fieldkit"
MIGRATIONS_IMAGE="${ECR_REGISTRY}/${REPO_PREFIX}/migrations:latest"

echo "=========================================="
echo "Running Database Migrations"
echo "=========================================="
echo "Environment: ${ENVIRONMENT}"
echo "Cluster: ${CLUSTER_NAME}"
echo "Migrations Image: ${MIGRATIONS_IMAGE}"
echo "=========================================="

# Kiểm tra migrations image có tồn tại không
if ! aws ecr describe-images \
    --repository-name ${REPO_PREFIX}/migrations \
    --image-ids imageTag=latest \
    --region ${AWS_REGION} &>/dev/null; then
    echo "⚠️  Migrations image chưa tồn tại trong ECR."
    echo "   Chạy: ./deployment/build-and-push.sh latest ${ENVIRONMENT}"
    exit 1
fi

# Lấy connection strings từ Secrets Manager
echo "Đang lấy database connection strings..."
POSTGRES_URL=$(aws secretsmanager get-secret-value \
    --secret-id "fieldkit/${NAMESPACE}/database/postgres" \
    --region ${AWS_REGION} \
    --query 'SecretString' \
    --output text 2>/dev/null || echo "")

TIMESCALE_URL=$(aws secretsmanager get-secret-value \
    --secret-id "fieldkit/${NAMESPACE}/database/timescale" \
    --region ${AWS_REGION} \
    --query 'SecretString' \
    --output text 2>/dev/null || echo "")

if [ -z "$POSTGRES_URL" ]; then
    echo "⚠️  PostgreSQL connection string chưa được setup."
    echo "   Chạy: ./deployment/create-database-secrets-from-services.sh ${ENVIRONMENT}"
    exit 1
fi

if [ -z "$TIMESCALE_URL" ]; then
    echo "⚠️  TimescaleDB connection string chưa được setup."
    echo "   Chạy: ./deployment/create-database-secrets-from-services.sh ${ENVIRONMENT}"
    exit 1
fi

echo "✅ Đã lấy connection strings"

# Tạo CloudWatch Log Group cho migrations nếu chưa tồn tại
echo "Đang kiểm tra CloudWatch log group cho migrations..."
MIGRATIONS_LOG_GROUP="/ecs/fieldkit-migrations"
if aws logs describe-log-groups \
    --log-group-name-prefix ${MIGRATIONS_LOG_GROUP} \
    --region ${AWS_REGION} \
    --query "logGroups[?logGroupName=='${MIGRATIONS_LOG_GROUP}'].logGroupName" \
    --output text 2>/dev/null | grep -q "${MIGRATIONS_LOG_GROUP}"; then
    echo "✅ Log group ${MIGRATIONS_LOG_GROUP} đã tồn tại."
else
    echo "Đang tạo log group ${MIGRATIONS_LOG_GROUP}..."
    if aws logs create-log-group \
        --log-group-name ${MIGRATIONS_LOG_GROUP} \
        --region ${AWS_REGION} 2>/dev/null; then
        echo "✅ Log group ${MIGRATIONS_LOG_GROUP} đã được tạo."
    else
        echo "⚠️  Không thể tạo log group (có thể đã tồn tại hoặc thiếu quyền)"
    fi
fi

# Tạo task definition cho migrations
echo "Đang tạo task definition cho migrations..."
TASK_DEF_FILE=$(mktemp)
cat > ${TASK_DEF_FILE} <<EOF
{
  "family": "fieldkit-migrations-${ENVIRONMENT}",
  "networkMode": "awsvpc",
  "requiresCompatibilities": ["FARGATE"],
  "cpu": "256",
  "memory": "512",
  "executionRoleArn": "arn:aws:iam::${AWS_ACCOUNT_ID}:role/ecsTaskExecutionRole",
  "taskRoleArn": "arn:aws:iam::${AWS_ACCOUNT_ID}:role/ecsTaskRole",
  "containerDefinitions": [
    {
      "name": "migrations",
      "image": "${MIGRATIONS_IMAGE}",
      "essential": true,
      "command": ["migrate"],
      "environment": [
        {
          "name": "MIGRATE_DATABASE_URL",
          "value": "${POSTGRES_URL}"
        },
        {
          "name": "MIGRATE_PATH",
          "value": "/work/primary"
        }
      ],
      "logConfiguration": {
        "logDriver": "awslogs",
        "options": {
          "awslogs-group": "/ecs/fieldkit-migrations",
          "awslogs-region": "${AWS_REGION}",
          "awslogs-stream-prefix": "ecs"
        }
      }
    }
  ]
}
EOF

# Đăng ký task definition
aws ecs register-task-definition \
    --cli-input-json file://${TASK_DEF_FILE} \
    --region ${AWS_REGION} > /dev/null

rm ${TASK_DEF_FILE}

echo "✅ Task definition đã được đăng ký"

# Chạy migration cho PostgreSQL
echo ""
echo "Đang chạy migrations cho PostgreSQL..."
TASK_ARN=$(aws ecs run-task \
    --cluster ${CLUSTER_NAME} \
    --task-definition fieldkit-migrations-${ENVIRONMENT} \
    --launch-type FARGATE \
    --network-configuration "awsvpcConfiguration={subnets=[${SUBNET_IDS}],securityGroups=[${SECURITY_GROUP_ID}],assignPublicIp=ENABLED}" \
    --region ${AWS_REGION} \
    --query 'tasks[0].taskArn' \
    --output text)

if [ -z "$TASK_ARN" ] || [ "$TASK_ARN" = "None" ]; then
    echo "Error: Không thể chạy migration task"
    exit 1
fi

echo "✅ Migration task đã được khởi động: ${TASK_ARN}"
echo "   Đang đợi task hoàn thành..."

# Đợi task hoàn thành (tối đa 10 phút)
TIMEOUT=600
ELAPSED=0
while [ $ELAPSED -lt $TIMEOUT ]; do
    TASK_STATUS=$(aws ecs describe-tasks \
        --cluster ${CLUSTER_NAME} \
        --tasks ${TASK_ARN} \
        --region ${AWS_REGION} \
        --query 'tasks[0].lastStatus' \
        --output text 2>/dev/null || echo "UNKNOWN")
    
    if [ "$TASK_STATUS" = "STOPPED" ]; then
        break
    fi
    
    echo "   Task status: ${TASK_STATUS} (${ELAPSED}s)..."
    sleep 10
    ELAPSED=$((ELAPSED + 10))
done

if [ $ELAPSED -ge $TIMEOUT ]; then
    echo "⚠️  Timeout đợi task hoàn thành"
    echo "   Xem logs:"
    echo "   aws logs tail /ecs/fieldkit-migrations --follow --region ${AWS_REGION}"
    exit 1
fi

# Lấy task details để kiểm tra
TASK_DETAILS=$(aws ecs describe-tasks \
    --cluster ${CLUSTER_NAME} \
    --tasks ${TASK_ARN} \
    --region ${AWS_REGION} \
    --query 'tasks[0]' \
    --output json)

EXIT_CODE=$(echo "$TASK_DETAILS" | jq -r '.containers[0].exitCode // "null"')
STOP_REASON=$(echo "$TASK_DETAILS" | jq -r '.stoppedReason // "N/A"')
STOP_CODE=$(echo "$TASK_DETAILS" | jq -r '.stopCode // "N/A"')

if [ "$EXIT_CODE" = "0" ] || [ "$EXIT_CODE" = "null" ]; then
    if [ "$EXIT_CODE" = "0" ]; then
        echo "✅ PostgreSQL migrations đã hoàn thành thành công!"
    else
        echo "⚠️  PostgreSQL migrations có exit code: ${EXIT_CODE}"
        echo "   Stop reason: ${STOP_REASON}"
        echo "   Stop code: ${STOP_CODE}"
        echo ""
        echo "   Xem logs qua AWS Console:"
        echo "   https://${AWS_REGION}.console.aws.amazon.com/cloudwatch/home?region=${AWS_REGION}#logsV2:log-groups/log-group/%2Fecs%2Ffieldkit-migrations"
        echo ""
        echo "   Hoặc nếu có quyền logs:FilterLogEvents:"
        echo "   aws logs tail /ecs/fieldkit-migrations --follow --region ${AWS_REGION}"
        exit 1
    fi
else
    echo "⚠️  PostgreSQL migrations có lỗi (exit code: ${EXIT_CODE})"
    echo "   Stop reason: ${STOP_REASON}"
    echo "   Stop code: ${STOP_CODE}"
    echo ""
    echo "   Xem logs qua AWS Console:"
    echo "   https://${AWS_REGION}.console.aws.amazon.com/cloudwatch/home?region=${AWS_REGION}#logsV2:log-groups/log-group/%2Fecs%2Ffieldkit-migrations"
    echo ""
    echo "   Hoặc nếu có quyền logs:FilterLogEvents:"
    echo "   aws logs tail /ecs/fieldkit-migrations --follow --region ${AWS_REGION}"
    exit 1
fi

# Chạy migration cho TimescaleDB
echo ""
echo "Đang chạy migrations cho TimescaleDB..."
TASK_DEF_FILE=$(mktemp)
cat > ${TASK_DEF_FILE} <<EOF
{
  "family": "fieldkit-migrations-tsdb-${ENVIRONMENT}",
  "networkMode": "awsvpc",
  "requiresCompatibilities": ["FARGATE"],
  "cpu": "256",
  "memory": "512",
  "executionRoleArn": "arn:aws:iam::${AWS_ACCOUNT_ID}:role/ecsTaskExecutionRole",
  "taskRoleArn": "arn:aws:iam::${AWS_ACCOUNT_ID}:role/ecsTaskRole",
  "containerDefinitions": [
    {
      "name": "migrations",
      "image": "${MIGRATIONS_IMAGE}",
      "essential": true,
      "command": ["migrate"],
      "environment": [
        {
          "name": "MIGRATE_DATABASE_URL",
          "value": "${TIMESCALE_URL}"
        },
        {
          "name": "MIGRATE_PATH",
          "value": "/work/tsdb"
        }
      ],
      "logConfiguration": {
        "logDriver": "awslogs",
        "options": {
          "awslogs-group": "/ecs/fieldkit-migrations",
          "awslogs-region": "${AWS_REGION}",
          "awslogs-stream-prefix": "ecs"
        }
      }
    }
  ]
}
EOF

aws ecs register-task-definition \
    --cli-input-json file://${TASK_DEF_FILE} \
    --region ${AWS_REGION} > /dev/null

rm ${TASK_DEF_FILE}

TASK_ARN=$(aws ecs run-task \
    --cluster ${CLUSTER_NAME} \
    --task-definition fieldkit-migrations-tsdb-${ENVIRONMENT} \
    --launch-type FARGATE \
    --network-configuration "awsvpcConfiguration={subnets=[${SUBNET_IDS}],securityGroups=[${SECURITY_GROUP_ID}],assignPublicIp=ENABLED}" \
    --region ${AWS_REGION} \
    --query 'tasks[0].taskArn' \
    --output text)

echo "✅ TimescaleDB migration task đã được khởi động: ${TASK_ARN}"
echo "   Đang đợi task hoàn thành..."

# Đợi task hoàn thành (tối đa 10 phút)
TIMEOUT=600
ELAPSED=0
while [ $ELAPSED -lt $TIMEOUT ]; do
    TASK_STATUS=$(aws ecs describe-tasks \
        --cluster ${CLUSTER_NAME} \
        --tasks ${TASK_ARN} \
        --region ${AWS_REGION} \
        --query 'tasks[0].lastStatus' \
        --output text 2>/dev/null || echo "UNKNOWN")
    
    if [ "$TASK_STATUS" = "STOPPED" ]; then
        break
    fi
    
    echo "   Task status: ${TASK_STATUS} (${ELAPSED}s)..."
    sleep 10
    ELAPSED=$((ELAPSED + 10))
done

if [ $ELAPSED -ge $TIMEOUT ]; then
    echo "⚠️  Timeout đợi task hoàn thành"
    echo ""
    echo "   Xem logs qua AWS Console:"
    echo "   https://${AWS_REGION}.console.aws.amazon.com/cloudwatch/home?region=${AWS_REGION}#logsV2:log-groups/log-group/%2Fecs%2Ffieldkit-migrations"
    echo ""
    echo "   Hoặc nếu có quyền logs:FilterLogEvents:"
    echo "   aws logs tail /ecs/fieldkit-migrations --follow --region ${AWS_REGION}"
    exit 1
fi

# Lấy task details để kiểm tra
TASK_DETAILS=$(aws ecs describe-tasks \
    --cluster ${CLUSTER_NAME} \
    --tasks ${TASK_ARN} \
    --region ${AWS_REGION} \
    --query 'tasks[0]' \
    --output json)

if [ "$EXIT_CODE" = "0" ] || [ "$EXIT_CODE" = "null" ]; then
    if [ "$EXIT_CODE" = "0" ]; then
        echo "✅ TimescaleDB migrations đã hoàn thành thành công!"
    else
        echo "⚠️  TimescaleDB migrations có exit code: ${EXIT_CODE}"
        echo "   Stop reason: ${STOP_REASON}"
        echo "   Stop code: ${STOP_CODE}"
        echo ""
        echo "   Xem logs qua AWS Console:"
        echo "   https://${AWS_REGION}.console.aws.amazon.com/cloudwatch/home?region=${AWS_REGION}#logsV2:log-groups/log-group/%2Fecs%2Ffieldkit-migrations"
        echo ""
        echo "   Hoặc nếu có quyền logs:FilterLogEvents:"
        echo "   aws logs tail /ecs/fieldkit-migrations --follow --region ${AWS_REGION}"
        exit 1
    fi
else
    echo "⚠️  TimescaleDB migrations có lỗi (exit code: ${EXIT_CODE})"
    echo "   Stop reason: ${STOP_REASON}"
    echo "   Stop code: ${STOP_CODE}"
    echo ""
    echo "   Xem logs qua AWS Console:"
    echo "   https://${AWS_REGION}.console.aws.amazon.com/cloudwatch/home?region=${AWS_REGION}#logsV2:log-groups/log-group/%2Fecs%2Ffieldkit-migrations"
    echo ""
    echo "   Hoặc nếu có quyền logs:FilterLogEvents:"
    echo "   aws logs tail /ecs/fieldkit-migrations --follow --region ${AWS_REGION}"
    exit 1
fi

echo ""
echo "=========================================="
echo "✅ Tất cả migrations đã hoàn thành!"
echo "=========================================="

