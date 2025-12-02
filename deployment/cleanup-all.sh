#!/bin/bash

# Script để cleanup toàn bộ các dịch vụ và resources liên quan để tránh phát sinh chi phí
# Sử dụng: ./aws/cleanup-all.sh [ENVIRONMENT] [OPTIONS]
# Options:
#   --delete-ecr: Xóa ECR repositories (default: giữ lại)
#   --delete-secrets: Xóa Secrets Manager secrets (default: giữ lại)
#   --confirm: Bỏ qua confirmation prompt (nguy hiểm!)

set -e

ENVIRONMENT=${1:-staging}
AWS_REGION=${AWS_REGION:-ap-southeast-1}

# Parse options
DELETE_ECR=false
DELETE_SECRETS=false
SKIP_CONFIRM=false

for arg in "$@"; do
    case $arg in
        --delete-ecr)
            DELETE_ECR=true
            ;;
        --delete-secrets)
            DELETE_SECRETS=true
            ;;
        --confirm)
            SKIP_CONFIRM=true
            ;;
    esac
done

# Lấy Account ID từ credentials
AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text 2>/dev/null || echo "")
if [ -z "$AWS_ACCOUNT_ID" ]; then
    echo "❌ Error: Không thể lấy AWS_ACCOUNT_ID từ credentials"
    exit 1
fi

# Cluster names
APP_CLUSTER="fieldkit-${ENVIRONMENT}-app"
DB_CLUSTER="fieldkit-${ENVIRONMENT}-db-v1"

# Service names
APP_SERVER_SERVICE="${APP_CLUSTER}-server"
APP_CHARTING_SERVICE="${APP_CLUSTER}-charting"
DB_POSTGRES_SERVICE="${DB_CLUSTER}-postgres"
DB_TIMESCALE_SERVICE="${DB_CLUSTER}-timescale"

# Load balancer names
ALB_NAME="fieldkit-${ENVIRONMENT}-server-alb"
NLB_POSTGRES_NAME="fieldkit-${ENVIRONMENT}-postgres-nlb"
NLB_TIMESCALE_NAME="fieldkit-${ENVIRONMENT}-timescale-nlb"

# Target group names
TG_SERVER_NAME="fieldkit-${ENVIRONMENT}-server-tg"
TG_POSTGRES_NAME="fieldkit-${ENVIRONMENT}-postgres-tg"
TG_TIMESCALE_NAME="fieldkit-${ENVIRONMENT}-timescale-tg"

# Log group prefix
LOG_GROUP_PREFIX="/ecs/fieldkit-${ENVIRONMENT}"

# ECR repositories
ECR_REPOS=(
    "fieldkit/server"
    "fieldkit/charting"
    "fieldkit/postgres"
    "fieldkit/timescale"
)

# Secrets names
SECRET_NAMES=(
    "fieldkit/${ENVIRONMENT}/database/postgres"
    "fieldkit/${ENVIRONMENT}/database/timescale"
    "fieldkit/${ENVIRONMENT}/session/key"
)

echo "=========================================="
echo "🧹 Cleanup Toàn Bộ Resources"
echo "=========================================="
echo "Environment: ${ENVIRONMENT}"
echo "Region: ${AWS_REGION}"
echo "Account ID: ${AWS_ACCOUNT_ID}"
echo ""
echo "Resources sẽ bị xóa:"
echo "  ✅ Application Cluster: ${APP_CLUSTER}"
echo "  ✅ Database Cluster: ${DB_CLUSTER}"
echo "  ✅ Load Balancers (ALB/NLB)"
echo "  ✅ Target Groups"
echo "  ✅ CloudWatch Log Groups"
[ "$DELETE_ECR" = true ] && echo "  ✅ ECR Repositories" || echo "  ⚠️  ECR Repositories: GIỮ LẠI"
[ "$DELETE_SECRETS" = true ] && echo "  ✅ Secrets Manager Secrets" || echo "  ⚠️  Secrets Manager: GIỮ LẠI"
echo "=========================================="
echo ""

# Confirmation
if [ "$SKIP_CONFIRM" != true ]; then
    echo "⚠️  CẢNH BÁO: Script này sẽ xóa TẤT CẢ resources liên quan!"
    echo "   Điều này không thể hoàn tác!"
    echo ""
    read -p "Bạn có chắc chắn muốn tiếp tục? (yes/no): " CONFIRM
    if [ "$CONFIRM" != "yes" ]; then
        echo "❌ Đã hủy."
        exit 0
    fi
    echo ""
fi

# Function to scale down and delete service
cleanup_service() {
    local CLUSTER=$1
    local SERVICE=$2
    
    SERVICE_EXISTS=$(aws ecs describe-services \
        --cluster ${CLUSTER} \
        --services ${SERVICE} \
        --region ${AWS_REGION} \
        --query 'services[0].status' \
        --output text 2>/dev/null || echo "NOT_FOUND")
    
    if [ "$SERVICE_EXISTS" != "NOT_FOUND" ] && [ -n "$SERVICE_EXISTS" ] && [ "$SERVICE_EXISTS" != "None" ]; then
        echo "   📦 Đang xóa service: ${SERVICE}..."
        
        # Scale to 0 first
        aws ecs update-service \
            --cluster ${CLUSTER} \
            --service ${SERVICE} \
            --desired-count 0 \
            --region ${AWS_REGION} > /dev/null 2>&1 || true
        
        # Wait a bit
        sleep 5
        
        # Delete service
        aws ecs delete-service \
            --cluster ${CLUSTER} \
            --service ${SERVICE} \
            --force \
            --region ${AWS_REGION} > /dev/null 2>&1 || true
        
        echo "   ✅ Service ${SERVICE} đã được xóa"
    else
        echo "   ⚠️  Service ${SERVICE} không tồn tại, bỏ qua"
    fi
}

# Function to delete cluster
cleanup_cluster() {
    local CLUSTER=$1
    
    CLUSTER_STATUS=$(aws ecs describe-clusters \
        --clusters ${CLUSTER} \
        --region ${AWS_REGION} \
        --query 'clusters[0].status' \
        --output text 2>/dev/null || echo "NOT_FOUND")
    
    if [ "$CLUSTER_STATUS" = "ACTIVE" ] || [ "$CLUSTER_STATUS" = "INACTIVE" ]; then
        echo "   🗑️  Đang xóa cluster: ${CLUSTER}..."
        
        # Check remaining services
        REMAINING_SERVICES=$(aws ecs list-services \
            --cluster ${CLUSTER} \
            --region ${AWS_REGION} \
            --query 'length(serviceArns)' \
            --output text 2>/dev/null || echo "0")
        
        if [ "$REMAINING_SERVICES" != "0" ] && [ "$REMAINING_SERVICES" != "" ]; then
            echo "   ⚠️  Cluster vẫn còn ${REMAINING_SERVICES} services. Đang xóa services trước..."
            # List and delete all services
            SERVICE_ARNS=$(aws ecs list-services \
                --cluster ${CLUSTER} \
                --region ${AWS_REGION} \
                --query 'serviceArns[*]' \
                --output text 2>/dev/null || echo "")
            
            if [ -n "$SERVICE_ARNS" ]; then
                for SERVICE_ARN in $SERVICE_ARNS; do
                    SERVICE_NAME=$(basename $SERVICE_ARN)
                    cleanup_service ${CLUSTER} ${SERVICE_NAME}
                done
            fi
            
            # Wait for services to be deleted
            echo "   ⏳ Đang đợi services được xóa hoàn toàn..."
            sleep 10
        fi
        
        # Delete cluster
        aws ecs delete-cluster \
            --cluster ${CLUSTER} \
            --region ${AWS_REGION} > /dev/null 2>&1 || true
        
        echo "   ✅ Cluster ${CLUSTER} đã được xóa"
    else
        echo "   ⚠️  Cluster ${CLUSTER} không tồn tại, bỏ qua"
    fi
}

# Function to delete load balancer
cleanup_load_balancer() {
    local LB_NAME=$1
    local LB_TYPE=$2
    
    LB_ARN=$(aws elbv2 describe-load-balancers \
        --names ${LB_NAME} \
        --region ${AWS_REGION} \
        --query 'LoadBalancers[0].LoadBalancerArn' \
        --output text 2>/dev/null || echo "")
    
    if [ -n "$LB_ARN" ] && [ "$LB_ARN" != "None" ]; then
        echo "   🗑️  Đang xóa ${LB_TYPE}: ${LB_NAME}..."
        
        # Delete load balancer
        aws elbv2 delete-load-balancer \
            --load-balancer-arn ${LB_ARN} \
            --region ${AWS_REGION} > /dev/null 2>&1 || true
        
        echo "   ✅ ${LB_TYPE} ${LB_NAME} đã được xóa"
    else
        echo "   ⚠️  ${LB_TYPE} ${LB_NAME} không tồn tại, bỏ qua"
    fi
}

# Function to delete target group
cleanup_target_group() {
    local TG_NAME=$1
    
    TG_ARN=$(aws elbv2 describe-target-groups \
        --names ${TG_NAME} \
        --region ${AWS_REGION} \
        --query 'TargetGroups[0].TargetGroupArn' \
        --output text 2>/dev/null || echo "")
    
    if [ -n "$TG_ARN" ] && [ "$TG_ARN" != "None" ]; then
        echo "   🗑️  Đang xóa target group: ${TG_NAME}..."
        
        # Delete target group
        aws elbv2 delete-target-group \
            --target-group-arn ${TG_ARN} \
            --region ${AWS_REGION} > /dev/null 2>&1 || true
        
        echo "   ✅ Target group ${TG_NAME} đã được xóa"
    else
        echo "   ⚠️  Target group ${TG_NAME} không tồn tại, bỏ qua"
    fi
}

# Function to delete log groups
cleanup_log_groups() {
    echo "   📋 Đang tìm log groups với prefix: ${LOG_GROUP_PREFIX}..."
    
    LOG_GROUPS=$(aws logs describe-log-groups \
        --log-group-name-prefix ${LOG_GROUP_PREFIX} \
        --region ${AWS_REGION} \
        --query 'logGroups[*].logGroupName' \
        --output text 2>/dev/null || echo "")
    
    if [ -n "$LOG_GROUPS" ]; then
        for LOG_GROUP in $LOG_GROUPS; do
            echo "   🗑️  Đang xóa log group: ${LOG_GROUP}..."
            aws logs delete-log-group \
                --log-group-name ${LOG_GROUP} \
                --region ${AWS_REGION} > /dev/null 2>&1 || true
            echo "   ✅ Log group ${LOG_GROUP} đã được xóa"
        done
    else
        echo "   ⚠️  Không tìm thấy log groups với prefix ${LOG_GROUP_PREFIX}"
    fi
}

# Function to delete ECR repositories
cleanup_ecr_repos() {
    if [ "$DELETE_ECR" != true ]; then
        return
    fi
    
    echo "   📦 Đang xóa ECR repositories..."
    
    for REPO in "${ECR_REPOS[@]}"; do
        REPO_EXISTS=$(aws ecr describe-repositories \
            --repository-names ${REPO} \
            --region ${AWS_REGION} \
            --query 'repositories[0].repositoryName' \
            --output text 2>/dev/null || echo "")
        
        if [ -n "$REPO_EXISTS" ] && [ "$REPO_EXISTS" != "None" ]; then
            echo "   🗑️  Đang xóa repository: ${REPO}..."
            aws ecr delete-repository \
                --repository-name ${REPO} \
                --force \
                --region ${AWS_REGION} > /dev/null 2>&1 || true
            echo "   ✅ Repository ${REPO} đã được xóa"
        else
            echo "   ⚠️  Repository ${REPO} không tồn tại, bỏ qua"
        fi
    done
}

# Function to delete secrets
cleanup_secrets() {
    if [ "$DELETE_SECRETS" != true ]; then
        return
    fi
    
    echo "   🔐 Đang xóa Secrets Manager secrets..."
    
    for SECRET_NAME in "${SECRET_NAMES[@]}"; do
        SECRET_EXISTS=$(aws secretsmanager describe-secret \
            --secret-id ${SECRET_NAME} \
            --region ${AWS_REGION} \
            --query 'Name' \
            --output text 2>/dev/null || echo "")
        
        if [ -n "$SECRET_EXISTS" ] && [ "$SECRET_EXISTS" != "None" ]; then
            echo "   🗑️  Đang xóa secret: ${SECRET_NAME}..."
            aws secretsmanager delete-secret \
                --secret-id ${SECRET_NAME} \
                --force-delete-without-recovery \
                --region ${AWS_REGION} > /dev/null 2>&1 || true
            echo "   ✅ Secret ${SECRET_NAME} đã được xóa"
        else
            echo "   ⚠️  Secret ${SECRET_NAME} không tồn tại, bỏ qua"
        fi
    done
}

# Start cleanup
echo "🚀 Bắt đầu cleanup..."
echo ""

# 1. Cleanup Application Services
echo "1️⃣  Cleanup Application Services..."
cleanup_service ${APP_CLUSTER} ${APP_SERVER_SERVICE}
cleanup_service ${APP_CLUSTER} ${APP_CHARTING_SERVICE}
echo ""

# 2. Cleanup Database Services
echo "2️⃣  Cleanup Database Services..."
cleanup_service ${DB_CLUSTER} ${DB_POSTGRES_SERVICE}
cleanup_service ${DB_CLUSTER} ${DB_TIMESCALE_SERVICE}
echo ""

# 3. Cleanup Target Groups (phải xóa trước load balancers)
echo "3️⃣  Cleanup Target Groups..."
cleanup_target_group ${TG_SERVER_NAME}
cleanup_target_group ${TG_POSTGRES_NAME}
cleanup_target_group ${TG_TIMESCALE_NAME}
echo ""

# 4. Cleanup Load Balancers
echo "4️⃣  Cleanup Load Balancers..."
cleanup_load_balancer ${ALB_NAME} "ALB"
cleanup_load_balancer ${NLB_POSTGRES_NAME} "NLB"
cleanup_load_balancer ${NLB_TIMESCALE_NAME} "NLB"
echo ""

# 5. Cleanup Clusters
echo "5️⃣  Cleanup Clusters..."
cleanup_cluster ${APP_CLUSTER}
cleanup_cluster ${DB_CLUSTER}
echo ""

# 6. Cleanup CloudWatch Log Groups
echo "6️⃣  Cleanup CloudWatch Log Groups..."
cleanup_log_groups
echo ""

# 7. Cleanup ECR Repositories (optional)
if [ "$DELETE_ECR" = true ]; then
    echo "7️⃣  Cleanup ECR Repositories..."
    cleanup_ecr_repos
    echo ""
fi

# 8. Cleanup Secrets (optional)
if [ "$DELETE_SECRETS" = true ]; then
    echo "8️⃣  Cleanup Secrets Manager Secrets..."
    cleanup_secrets
    echo ""
fi

# Summary
echo "=========================================="
echo "✅ Cleanup hoàn tất!"
echo "=========================================="
echo ""
echo "📊 Tổng kết:"
echo "  ✅ Application cluster và services đã được xóa"
echo "  ✅ Database cluster và services đã được xóa"
echo "  ✅ Load balancers đã được xóa"
echo "  ✅ Target groups đã được xóa"
echo "  ✅ CloudWatch log groups đã được xóa"
[ "$DELETE_ECR" = true ] && echo "  ✅ ECR repositories đã được xóa"
[ "$DELETE_SECRETS" = true ] && echo "  ✅ Secrets Manager secrets đã được xóa"
echo ""
echo "💡 Lưu ý:"
echo "  - Task definitions vẫn được giữ lại (không tốn chi phí)"
echo "  - IAM roles và policies vẫn được giữ lại"
echo "  - VPC, subnets, security groups vẫn được giữ lại"
[ "$DELETE_ECR" != true ] && echo "  - ECR repositories vẫn được giữ lại"
[ "$DELETE_SECRETS" != true ] && echo "  - Secrets Manager secrets vẫn được giữ lại"
echo ""
echo "🔄 Để deploy lại từ đầu:"
echo "  1. ./aws/deploy-database.sh ${ENVIRONMENT}"
echo "  2. ./aws/create-ecs-services.sh ${ENVIRONMENT}"
echo "  3. ./aws/setup-load-balancer.sh ${ENVIRONMENT}"
echo "  4. ./aws/build-and-push.sh latest ${ENVIRONMENT}"
echo "  5. ./aws/deploy.sh latest ${ENVIRONMENT}"
echo "=========================================="

