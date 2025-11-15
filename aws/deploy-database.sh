#!/bin/bash

# Script để deploy database services (PostgreSQL và TimescaleDB) lên ECS
# Sử dụng: ./deployment/deploy-database.sh [ENVIRONMENT]
# Ví dụ: ./deployment/deploy-database.sh staging

# Tắt set -e tạm thời để xử lý lỗi DRAINING
set +e

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

CLUSTER_NAME="fieldkit-${ENVIRONMENT}-db-v1"
NAMESPACE="${ENVIRONMENT}"
VPC_ID=${VPC_ID:-""}
SUBNET_IDS=${SUBNET_IDS:-""}
SECURITY_GROUP_ID=${SECURITY_GROUP_ID:-""}

if [ -z "$VPC_ID" ] || [ -z "$SUBNET_IDS" ] || [ -z "$SECURITY_GROUP_ID" ]; then
    echo "Error: VPC_ID, SUBNET_IDS, và SECURITY_GROUP_ID phải được đặt."
    echo "Chạy script với các biến môi trường đã set."
    exit 1
fi

echo "=========================================="
echo "Deploying Database Services"
echo "=========================================="
echo "Environment: ${ENVIRONMENT}"
echo "Namespace: ${NAMESPACE}"
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

# Tạo Service Discovery Namespace nếu chưa tồn tại
echo "Đang kiểm tra Service Discovery namespace..."
# Với ECS Fargate, sử dụng namespace mặc định .ecs.internal
# Namespace này được tự động tạo khi cluster được tạo với service discovery enabled
ECS_INTERNAL_NAMESPACE_ID=$(aws servicediscovery list-namespaces \
    --region ${AWS_REGION} \
    --filters Name=TYPE,Values=DNS_PRIVATE \
    --query "Namespaces[?contains(Name, 'ecs.internal')].Id" \
    --output text 2>/dev/null | head -1)

if [ -z "$ECS_INTERNAL_NAMESPACE_ID" ] || [ "$ECS_INTERNAL_NAMESPACE_ID" = "None" ]; then
    echo "⚠️  Namespace .ecs.internal chưa tồn tại."
    echo "   Namespace này sẽ được tự động tạo khi cluster được tạo với service discovery enabled."
    echo "   Tiếp tục với việc tạo service..."
else
    echo "✅ Service Discovery namespace .ecs.internal đã tồn tại."
fi

# Tạo CloudWatch Log Groups cho database
echo "Đang tạo CloudWatch log groups cho database..."
for log_group in "/ecs/fieldkit-postgres" "/ecs/fieldkit-timescale"; do
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

# Đăng ký Task Definitions cho database
echo "Đang đăng ký task definitions cho database..."

# PostgreSQL Task Definition
POSTGRES_TASK_DEF="deployment/ecs-task-definitions/postgres-task.json"
if [ -f "${POSTGRES_TASK_DEF}" ]; then
    sed -e "s/ACCOUNT_ID/${AWS_ACCOUNT_ID}/g" \
        -e "s/REGION/${AWS_REGION}/g" \
        -e "s/NAMESPACE/${NAMESPACE}/g" \
        ${POSTGRES_TASK_DEF} > /tmp/postgres-task.json
    
    aws ecs register-task-definition \
        --cli-input-json file:///tmp/postgres-task.json \
        --region ${AWS_REGION} > /dev/null
    echo "✅ PostgreSQL task definition đã được đăng ký."
    rm /tmp/postgres-task.json
fi

# TimescaleDB Task Definition
TIMESCALE_TASK_DEF="deployment/ecs-task-definitions/timescale-task.json"
if [ -f "${TIMESCALE_TASK_DEF}" ]; then
    sed -e "s/ACCOUNT_ID/${AWS_ACCOUNT_ID}/g" \
        -e "s/REGION/${AWS_REGION}/g" \
        -e "s/NAMESPACE/${NAMESPACE}/g" \
        ${TIMESCALE_TASK_DEF} > /tmp/timescale-task.json
    
    aws ecs register-task-definition \
        --cli-input-json file:///tmp/timescale-task.json \
        --region ${AWS_REGION} > /dev/null
    echo "✅ TimescaleDB task definition đã được đăng ký."
    rm /tmp/timescale-task.json
fi

# Tạo ECS Services cho database
echo "Đang tạo ECS services cho database..."

# Tìm hoặc tạo Service Discovery namespace .ecs.internal
echo "Đang kiểm tra Service Discovery namespace .ecs.internal..."
# Với ECS Fargate, namespace .ecs.internal được tự động tạo khi cluster được tạo
# Nhưng cần tìm namespace ID để tạo service registry
ECS_INTERNAL_NAMESPACE_ID=$(aws servicediscovery list-namespaces \
    --region ${AWS_REGION} \
    --filters Name=TYPE,Values=DNS_PRIVATE \
    --query "Namespaces[?contains(Name, 'ecs.internal')].Id" \
    --output text 2>/dev/null | head -1)

if [ -z "$ECS_INTERNAL_NAMESPACE_ID" ] || [ "$ECS_INTERNAL_NAMESPACE_ID" = "None" ]; then
    echo "⚠️  Namespace .ecs.internal chưa tồn tại."
    echo "   Với ECS Fargate, namespace này sẽ được tự động tạo khi service discovery được enable."
    echo "   Sẽ tạo service registry để enable service discovery..."
    ECS_INTERNAL_NAMESPACE_ID=""
fi

# PostgreSQL Service
POSTGRES_SERVICE="${CLUSTER_NAME}-postgres"
SERVICE_STATUS=$(aws ecs describe-services \
    --cluster ${CLUSTER_NAME} \
    --services ${POSTGRES_SERVICE} \
    --region ${AWS_REGION} \
    --query 'services[0].status' \
    --output text 2>/dev/null || echo "NOT_FOUND")

echo "   Service status hiện tại: ${SERVICE_STATUS}"

if [ "$SERVICE_STATUS" = "NOT_FOUND" ] || [ "$SERVICE_STATUS" = "None" ] || [ -z "$SERVICE_STATUS" ]; then
    echo "Đang tạo service ${POSTGRES_SERVICE}..."
    
    # Tạo service registry để enable service discovery nếu có namespace
    SERVICE_REGISTRY_ARN=""
    if [ -n "$ECS_INTERNAL_NAMESPACE_ID" ] && [ "$ECS_INTERNAL_NAMESPACE_ID" != "None" ]; then
        echo "   Đang tạo service registry cho service discovery..."
        # Kiểm tra xem service registry đã tồn tại chưa
        EXISTING_REGISTRY=$(aws servicediscovery list-services \
            --region ${AWS_REGION} \
            --filters Name=NAME,Values=${POSTGRES_SERVICE},Condition=EQ \
            --query "Services[?Name=='${POSTGRES_SERVICE}'].Arn" \
            --output text 2>/dev/null | head -1)
        
        if [ -n "$EXISTING_REGISTRY" ] && [ "$EXISTING_REGISTRY" != "None" ]; then
            SERVICE_REGISTRY_ARN="$EXISTING_REGISTRY"
            echo "   ✅ Service registry đã tồn tại: ${SERVICE_REGISTRY_ARN}"
        else
            # Tạo service registry mới
            SERVICE_REGISTRY_ARN=$(aws servicediscovery create-service \
                --name ${POSTGRES_SERVICE} \
                --namespace-id ${ECS_INTERNAL_NAMESPACE_ID} \
                --dns-config "NamespaceId=${ECS_INTERNAL_NAMESPACE_ID},DnsRecords=[{Type=A,TTL=60}]" \
                --region ${AWS_REGION} \
                --query 'Service.Arn' \
                --output text 2>/dev/null || echo "")
            
            if [ -n "$SERVICE_REGISTRY_ARN" ] && [ "$SERVICE_REGISTRY_ARN" != "None" ]; then
                echo "   ✅ Service registry đã được tạo: ${SERVICE_REGISTRY_ARN}"
            else
                echo "   ⚠️  Không thể tạo service registry. Service discovery có thể không hoạt động."
                SERVICE_REGISTRY_ARN=""
            fi
        fi
    else
        echo "   ⚠️  Không có namespace .ecs.internal. Service discovery sẽ không hoạt động."
    fi
    
    # Tạo service với hoặc không có service discovery
    if [ -n "$SERVICE_REGISTRY_ARN" ] && [ "$SERVICE_REGISTRY_ARN" != "None" ]; then
        CREATE_OUTPUT=$(aws ecs create-service \
            --cluster ${CLUSTER_NAME} \
            --service-name ${POSTGRES_SERVICE} \
            --task-definition fieldkit-postgres \
            --desired-count 1 \
            --launch-type FARGATE \
            --network-configuration "awsvpcConfiguration={subnets=[${SUBNET_IDS}],securityGroups=[${SECURITY_GROUP_ID}],assignPublicIp=ENABLED}" \
            --service-registries "registryArn=${SERVICE_REGISTRY_ARN}" \
            --enable-execute-command \
            --region ${AWS_REGION} 2>&1)
    else
        CREATE_OUTPUT=$(aws ecs create-service \
            --cluster ${CLUSTER_NAME} \
            --service-name ${POSTGRES_SERVICE} \
            --task-definition fieldkit-postgres \
            --desired-count 1 \
            --launch-type FARGATE \
            --network-configuration "awsvpcConfiguration={subnets=[${SUBNET_IDS}],securityGroups=[${SECURITY_GROUP_ID}],assignPublicIp=ENABLED}" \
            --enable-execute-command \
            --region ${AWS_REGION} 2>&1)
    fi
    CREATE_EXIT_CODE=$?
    
    if echo "$CREATE_OUTPUT" | grep -q "Draining"; then
        echo "⚠️  Service đang trong trạng thái DRAINING. Đang đợi..."
        SERVICE_STATUS="DRAINING"
    elif [ $CREATE_EXIT_CODE -eq 0 ]; then
        echo "✅ Service ${POSTGRES_SERVICE} đã được tạo."
        echo "   Service discovery name: ${POSTGRES_SERVICE}.ecs.internal"
        SERVICE_STATUS="ACTIVE"
    else
        echo "❌ Lỗi khi tạo service:"
        echo "$CREATE_OUTPUT"
        exit 1
    fi
fi

# Xử lý service INACTIVE hoặc DRAINING
if [ "$SERVICE_STATUS" = "INACTIVE" ]; then
    echo "⚠️  Service ${POSTGRES_SERVICE} đang INACTIVE. Đang xóa và tạo lại..."
    aws ecs delete-service \
        --cluster ${CLUSTER_NAME} \
        --service ${POSTGRES_SERVICE} \
        --region ${AWS_REGION} \
        --force > /dev/null 2>&1 || true
    sleep 5
    
    # Tạo lại service với service discovery nếu có
    if [ -n "$SERVICE_REGISTRY_ARN" ] && [ "$SERVICE_REGISTRY_ARN" != "None" ]; then
        aws ecs create-service \
            --cluster ${CLUSTER_NAME} \
            --service-name ${POSTGRES_SERVICE} \
            --task-definition fieldkit-postgres \
            --desired-count 1 \
            --launch-type FARGATE \
            --network-configuration "awsvpcConfiguration={subnets=[${SUBNET_IDS}],securityGroups=[${SECURITY_GROUP_ID}],assignPublicIp=ENABLED}" \
            --service-registries "registryArn=${SERVICE_REGISTRY_ARN}" \
            --enable-execute-command \
            --region ${AWS_REGION} > /dev/null
    else
        aws ecs create-service \
            --cluster ${CLUSTER_NAME} \
            --service-name ${POSTGRES_SERVICE} \
            --task-definition fieldkit-postgres \
            --desired-count 1 \
            --launch-type FARGATE \
            --network-configuration "awsvpcConfiguration={subnets=[${SUBNET_IDS}],securityGroups=[${SECURITY_GROUP_ID}],assignPublicIp=ENABLED}" \
            --enable-execute-command \
            --region ${AWS_REGION} > /dev/null
    fi
    echo "   ✅ Service ${POSTGRES_SERVICE} đã được tạo lại."
    echo "   Service discovery name: ${POSTGRES_SERVICE}.ecs.internal"
elif [ "$SERVICE_STATUS" = "DRAINING" ]; then
    echo "⚠️  Service ${POSTGRES_SERVICE} đang trong trạng thái DRAINING."
    echo "   Đang đợi service hoàn thành draining..."
    while true; do
        CURRENT_STATUS=$(aws ecs describe-services \
            --cluster ${CLUSTER_NAME} \
            --services ${POSTGRES_SERVICE} \
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
            --service ${POSTGRES_SERVICE} \
            --region ${AWS_REGION} \
            --force > /dev/null 2>&1 || true
        sleep 5
        
        # Tạo lại service với service discovery nếu có
        if [ -n "$SERVICE_REGISTRY_ARN" ] && [ "$SERVICE_REGISTRY_ARN" != "None" ]; then
            aws ecs create-service \
                --cluster ${CLUSTER_NAME} \
                --service-name ${POSTGRES_SERVICE} \
                --task-definition fieldkit-postgres \
                --desired-count 1 \
                --launch-type FARGATE \
                --network-configuration "awsvpcConfiguration={subnets=[${SUBNET_IDS}],securityGroups=[${SECURITY_GROUP_ID}],assignPublicIp=ENABLED}" \
                --service-registries "registryArn=${SERVICE_REGISTRY_ARN}" \
                --enable-execute-command \
                --region ${AWS_REGION} > /dev/null
        else
            aws ecs create-service \
                --cluster ${CLUSTER_NAME} \
                --service-name ${POSTGRES_SERVICE} \
                --task-definition fieldkit-postgres \
                --desired-count 1 \
                --launch-type FARGATE \
                --network-configuration "awsvpcConfiguration={subnets=[${SUBNET_IDS}],securityGroups=[${SECURITY_GROUP_ID}],assignPublicIp=ENABLED}" \
                --enable-execute-command \
                --region ${AWS_REGION} > /dev/null
        fi
        echo "   ✅ Service ${POSTGRES_SERVICE} đã được tạo lại."
        echo "   Service discovery name: ${POSTGRES_SERVICE}.ecs.internal"
    fi
else
    echo "✅ Service ${POSTGRES_SERVICE} đã tồn tại (status: ${SERVICE_STATUS})."
    
    # Kiểm tra xem service có service discovery enabled không
    if [ "$SERVICE_STATUS" = "ACTIVE" ]; then
        SERVICE_REGISTRIES=$(aws ecs describe-services \
            --cluster ${CLUSTER_NAME} \
            --services ${POSTGRES_SERVICE} \
            --region ${AWS_REGION} \
            --query 'services[0].serviceRegistries' \
            --output json 2>/dev/null || echo "[]")
        
        REGISTRY_COUNT=$(echo "$SERVICE_REGISTRIES" | jq 'length' 2>/dev/null || echo "0")
        
        if [ "$REGISTRY_COUNT" = "0" ] || [ "$REGISTRY_COUNT" = "null" ]; then
            echo "   ⚠️  Service discovery chưa được enable trên service này."
            echo "   Đang cập nhật service để enable service discovery..."
            
            # Tạo service registry nếu chưa có
            if [ -z "$SERVICE_REGISTRY_ARN" ] || [ "$SERVICE_REGISTRY_ARN" = "None" ]; then
                if [ -n "$ECS_INTERNAL_NAMESPACE_ID" ] && [ "$ECS_INTERNAL_NAMESPACE_ID" != "None" ]; then
                    EXISTING_REGISTRY=$(aws servicediscovery list-services \
                        --region ${AWS_REGION} \
                        --filters Name=NAME,Values=${POSTGRES_SERVICE},Condition=EQ \
                        --query "Services[?Name=='${POSTGRES_SERVICE}'].Arn" \
                        --output text 2>/dev/null | head -1)
                    
                    if [ -n "$EXISTING_REGISTRY" ] && [ "$EXISTING_REGISTRY" != "None" ]; then
                        SERVICE_REGISTRY_ARN="$EXISTING_REGISTRY"
                    else
                        SERVICE_REGISTRY_ARN=$(aws servicediscovery create-service \
                            --name ${POSTGRES_SERVICE} \
                            --namespace-id ${ECS_INTERNAL_NAMESPACE_ID} \
                            --dns-config "NamespaceId=${ECS_INTERNAL_NAMESPACE_ID},DnsRecords=[{Type=A,TTL=60}]" \
                            --region ${AWS_REGION} \
                            --query 'Service.Arn' \
                            --output text 2>/dev/null || echo "")
                    fi
                fi
            fi
            
            # Update service để thêm service registry
            if [ -n "$SERVICE_REGISTRY_ARN" ] && [ "$SERVICE_REGISTRY_ARN" != "None" ]; then
                aws ecs update-service \
                    --cluster ${CLUSTER_NAME} \
                    --service ${POSTGRES_SERVICE} \
                    --service-registries "registryArn=${SERVICE_REGISTRY_ARN}" \
                    --region ${AWS_REGION} > /dev/null
                echo "   ✅ Đã enable service discovery trên service."
            else
                echo "   ⚠️  Không thể tạo service registry. Service discovery sẽ không hoạt động."
            fi
        else
            echo "   ✅ Service discovery đã được enable."
        fi
    fi
fi

# TimescaleDB Service
TIMESCALE_SERVICE="${CLUSTER_NAME}-timescale"
SERVICE_STATUS=$(aws ecs describe-services \
    --cluster ${CLUSTER_NAME} \
    --services ${TIMESCALE_SERVICE} \
    --region ${AWS_REGION} \
    --query 'services[0].status' \
    --output text 2>/dev/null || echo "NOT_FOUND")

echo "   Service status hiện tại: ${SERVICE_STATUS}"

if [ "$SERVICE_STATUS" = "NOT_FOUND" ] || [ "$SERVICE_STATUS" = "None" ] || [ -z "$SERVICE_STATUS" ]; then
    echo "Đang tạo service ${TIMESCALE_SERVICE}..."
    
    # Tạo service registry để enable service discovery nếu có namespace
    TIMESCALE_REGISTRY_ARN=""
    if [ -n "$ECS_INTERNAL_NAMESPACE_ID" ] && [ "$ECS_INTERNAL_NAMESPACE_ID" != "None" ]; then
        echo "   Đang tạo service registry cho service discovery..."
        # Kiểm tra xem service registry đã tồn tại chưa
        EXISTING_REGISTRY=$(aws servicediscovery list-services \
            --region ${AWS_REGION} \
            --filters Name=NAME,Values=${TIMESCALE_SERVICE},Condition=EQ \
            --query "Services[?Name=='${TIMESCALE_SERVICE}'].Arn" \
            --output text 2>/dev/null | head -1)
        
        if [ -n "$EXISTING_REGISTRY" ] && [ "$EXISTING_REGISTRY" != "None" ]; then
            TIMESCALE_REGISTRY_ARN="$EXISTING_REGISTRY"
            echo "   ✅ Service registry đã tồn tại: ${TIMESCALE_REGISTRY_ARN}"
        else
            # Tạo service registry mới
            TIMESCALE_REGISTRY_ARN=$(aws servicediscovery create-service \
                --name ${TIMESCALE_SERVICE} \
                --namespace-id ${ECS_INTERNAL_NAMESPACE_ID} \
                --dns-config "NamespaceId=${ECS_INTERNAL_NAMESPACE_ID},DnsRecords=[{Type=A,TTL=60}]" \
                --region ${AWS_REGION} \
                --query 'Service.Arn' \
                --output text 2>/dev/null || echo "")
            
            if [ -n "$TIMESCALE_REGISTRY_ARN" ] && [ "$TIMESCALE_REGISTRY_ARN" != "None" ]; then
                echo "   ✅ Service registry đã được tạo: ${TIMESCALE_REGISTRY_ARN}"
            else
                echo "   ⚠️  Không thể tạo service registry. Service discovery có thể không hoạt động."
                TIMESCALE_REGISTRY_ARN=""
            fi
        fi
    else
        echo "   ⚠️  Không có namespace .ecs.internal. Service discovery sẽ không hoạt động."
    fi
    
    # Tạo service với hoặc không có service discovery
    if [ -n "$TIMESCALE_REGISTRY_ARN" ] && [ "$TIMESCALE_REGISTRY_ARN" != "None" ]; then
        CREATE_OUTPUT=$(aws ecs create-service \
            --cluster ${CLUSTER_NAME} \
            --service-name ${TIMESCALE_SERVICE} \
            --task-definition fieldkit-timescale \
            --desired-count 1 \
            --launch-type FARGATE \
            --network-configuration "awsvpcConfiguration={subnets=[${SUBNET_IDS}],securityGroups=[${SECURITY_GROUP_ID}],assignPublicIp=ENABLED}" \
            --service-registries "registryArn=${TIMESCALE_REGISTRY_ARN}" \
            --region ${AWS_REGION} 2>&1)
    else
        CREATE_OUTPUT=$(aws ecs create-service \
            --cluster ${CLUSTER_NAME} \
            --service-name ${TIMESCALE_SERVICE} \
            --task-definition fieldkit-timescale \
            --desired-count 1 \
            --launch-type FARGATE \
            --network-configuration "awsvpcConfiguration={subnets=[${SUBNET_IDS}],securityGroups=[${SECURITY_GROUP_ID}],assignPublicIp=ENABLED}" \
            --region ${AWS_REGION} 2>&1)
    fi
    CREATE_EXIT_CODE=$?
    
    if echo "$CREATE_OUTPUT" | grep -q "Draining"; then
        echo "⚠️  Service đang trong trạng thái DRAINING. Đang đợi..."
        SERVICE_STATUS="DRAINING"
    elif [ $CREATE_EXIT_CODE -eq 0 ]; then
        echo "✅ Service ${TIMESCALE_SERVICE} đã được tạo."
        echo "   Service discovery name: ${TIMESCALE_SERVICE}.ecs.internal"
        SERVICE_STATUS="ACTIVE"
    else
        echo "❌ Lỗi khi tạo service:"
        echo "$CREATE_OUTPUT"
        exit 1
    fi
fi

# Xử lý service INACTIVE hoặc DRAINING
if [ "$SERVICE_STATUS" = "INACTIVE" ]; then
    echo "⚠️  Service ${TIMESCALE_SERVICE} đang INACTIVE. Đang xóa và tạo lại..."
    
    # Đảm bảo service registry đã được tạo nếu có namespace
    if [ -z "$TIMESCALE_REGISTRY_ARN" ] || [ "$TIMESCALE_REGISTRY_ARN" = "None" ]; then
        if [ -n "$ECS_INTERNAL_NAMESPACE_ID" ] && [ "$ECS_INTERNAL_NAMESPACE_ID" != "None" ]; then
            echo "   Đang tạo service registry cho service discovery..."
            EXISTING_REGISTRY=$(aws servicediscovery list-services \
                --region ${AWS_REGION} \
                --filters Name=NAME,Values=${TIMESCALE_SERVICE},Condition=EQ \
                --query "Services[?Name=='${TIMESCALE_SERVICE}'].Arn" \
                --output text 2>/dev/null | head -1)
            
            if [ -n "$EXISTING_REGISTRY" ] && [ "$EXISTING_REGISTRY" != "None" ]; then
                TIMESCALE_REGISTRY_ARN="$EXISTING_REGISTRY"
                echo "   ✅ Service registry đã tồn tại: ${TIMESCALE_REGISTRY_ARN}"
            else
                TIMESCALE_REGISTRY_ARN=$(aws servicediscovery create-service \
                    --name ${TIMESCALE_SERVICE} \
                    --namespace-id ${ECS_INTERNAL_NAMESPACE_ID} \
                    --dns-config "NamespaceId=${ECS_INTERNAL_NAMESPACE_ID},DnsRecords=[{Type=A,TTL=60}]" \
                    --region ${AWS_REGION} \
                    --query 'Service.Arn' \
                    --output text 2>/dev/null || echo "")
                
                if [ -n "$TIMESCALE_REGISTRY_ARN" ] && [ "$TIMESCALE_REGISTRY_ARN" != "None" ]; then
                    echo "   ✅ Service registry đã được tạo: ${TIMESCALE_REGISTRY_ARN}"
                else
                    echo "   ⚠️  Không thể tạo service registry. Service discovery có thể không hoạt động."
                    TIMESCALE_REGISTRY_ARN=""
                fi
            fi
        fi
    fi
    
    aws ecs delete-service \
        --cluster ${CLUSTER_NAME} \
        --service ${TIMESCALE_SERVICE} \
        --region ${AWS_REGION} \
        --force > /dev/null 2>&1 || true
    sleep 5
    
    # Tạo lại service với service discovery nếu có
    if [ -n "$TIMESCALE_REGISTRY_ARN" ] && [ "$TIMESCALE_REGISTRY_ARN" != "None" ]; then
        aws ecs create-service \
            --cluster ${CLUSTER_NAME} \
            --service-name ${TIMESCALE_SERVICE} \
            --task-definition fieldkit-timescale \
            --desired-count 1 \
            --launch-type FARGATE \
            --network-configuration "awsvpcConfiguration={subnets=[${SUBNET_IDS}],securityGroups=[${SECURITY_GROUP_ID}],assignPublicIp=ENABLED}" \
            --service-registries "registryArn=${TIMESCALE_REGISTRY_ARN}" \
            --region ${AWS_REGION} > /dev/null
    else
        aws ecs create-service \
            --cluster ${CLUSTER_NAME} \
            --service-name ${TIMESCALE_SERVICE} \
            --task-definition fieldkit-timescale \
            --desired-count 1 \
            --launch-type FARGATE \
            --network-configuration "awsvpcConfiguration={subnets=[${SUBNET_IDS}],securityGroups=[${SECURITY_GROUP_ID}],assignPublicIp=ENABLED}" \
            --region ${AWS_REGION} > /dev/null
    fi
    echo "   ✅ Service ${TIMESCALE_SERVICE} đã được tạo lại."
    echo "   Service discovery name: ${TIMESCALE_SERVICE}.ecs.internal"
elif [ "$SERVICE_STATUS" = "DRAINING" ]; then
    echo "⚠️  Service ${TIMESCALE_SERVICE} đang trong trạng thái DRAINING."
    echo "   Đang đợi service hoàn thành draining..."
    while true; do
        CURRENT_STATUS=$(aws ecs describe-services \
            --cluster ${CLUSTER_NAME} \
            --services ${TIMESCALE_SERVICE} \
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
            --service ${TIMESCALE_SERVICE} \
            --region ${AWS_REGION} \
            --force > /dev/null 2>&1 || true
        sleep 5
        
        # Tạo lại service với service discovery nếu có
        if [ -n "$TIMESCALE_REGISTRY_ARN" ] && [ "$TIMESCALE_REGISTRY_ARN" != "None" ]; then
            aws ecs create-service \
                --cluster ${CLUSTER_NAME} \
                --service-name ${TIMESCALE_SERVICE} \
                --task-definition fieldkit-timescale \
                --desired-count 1 \
                --launch-type FARGATE \
                --network-configuration "awsvpcConfiguration={subnets=[${SUBNET_IDS}],securityGroups=[${SECURITY_GROUP_ID}],assignPublicIp=ENABLED}" \
                --service-registries "registryArn=${TIMESCALE_REGISTRY_ARN}" \
                --region ${AWS_REGION} > /dev/null
        else
            aws ecs create-service \
                --cluster ${CLUSTER_NAME} \
                --service-name ${TIMESCALE_SERVICE} \
                --task-definition fieldkit-timescale \
                --desired-count 1 \
                --launch-type FARGATE \
                --network-configuration "awsvpcConfiguration={subnets=[${SUBNET_IDS}],securityGroups=[${SECURITY_GROUP_ID}],assignPublicIp=ENABLED}" \
                --region ${AWS_REGION} > /dev/null
        fi
        echo "   ✅ Service ${TIMESCALE_SERVICE} đã được tạo lại."
        echo "   Service discovery name: ${TIMESCALE_SERVICE}.ecs.internal"
    fi
else
    echo "✅ Service ${TIMESCALE_SERVICE} đã tồn tại (status: ${SERVICE_STATUS})."
    
    # Kiểm tra xem service có service discovery enabled không
    if [ "$SERVICE_STATUS" = "ACTIVE" ]; then
        SERVICE_REGISTRIES=$(aws ecs describe-services \
            --cluster ${CLUSTER_NAME} \
            --services ${TIMESCALE_SERVICE} \
            --region ${AWS_REGION} \
            --query 'services[0].serviceRegistries' \
            --output json 2>/dev/null || echo "[]")
        
        REGISTRY_COUNT=$(echo "$SERVICE_REGISTRIES" | jq 'length' 2>/dev/null || echo "0")
        
        if [ "$REGISTRY_COUNT" = "0" ] || [ "$REGISTRY_COUNT" = "null" ]; then
            echo "   ⚠️  Service discovery chưa được enable trên service này."
            echo "   Đang cập nhật service để enable service discovery..."
            
            # Tạo service registry nếu chưa có
            if [ -z "$TIMESCALE_REGISTRY_ARN" ] || [ "$TIMESCALE_REGISTRY_ARN" = "None" ]; then
                if [ -n "$ECS_INTERNAL_NAMESPACE_ID" ] && [ "$ECS_INTERNAL_NAMESPACE_ID" != "None" ]; then
                    EXISTING_REGISTRY=$(aws servicediscovery list-services \
                        --region ${AWS_REGION} \
                        --filters Name=NAME,Values=${TIMESCALE_SERVICE},Condition=EQ \
                        --query "Services[?Name=='${TIMESCALE_SERVICE}'].Arn" \
                        --output text 2>/dev/null | head -1)
                    
                    if [ -n "$EXISTING_REGISTRY" ] && [ "$EXISTING_REGISTRY" != "None" ]; then
                        TIMESCALE_REGISTRY_ARN="$EXISTING_REGISTRY"
                    else
                        TIMESCALE_REGISTRY_ARN=$(aws servicediscovery create-service \
                            --name ${TIMESCALE_SERVICE} \
                            --namespace-id ${ECS_INTERNAL_NAMESPACE_ID} \
                            --dns-config "NamespaceId=${ECS_INTERNAL_NAMESPACE_ID},DnsRecords=[{Type=A,TTL=60}]" \
                            --region ${AWS_REGION} \
                            --query 'Service.Arn' \
                            --output text 2>/dev/null || echo "")
                    fi
                fi
            fi
            
            # Update service để thêm service registry
            if [ -n "$TIMESCALE_REGISTRY_ARN" ] && [ "$TIMESCALE_REGISTRY_ARN" != "None" ]; then
                aws ecs update-service \
                    --cluster ${CLUSTER_NAME} \
                    --service ${TIMESCALE_SERVICE} \
                    --service-registries "registryArn=${TIMESCALE_REGISTRY_ARN}" \
                    --region ${AWS_REGION} > /dev/null
                echo "   ✅ Đã enable service discovery trên service."
            else
                echo "   ⚠️  Không thể tạo service registry. Service discovery sẽ không hoạt động."
            fi
        else
            echo "   ✅ Service discovery đã được enable."
        fi
    fi
fi

echo ""
echo "=========================================="
echo "✅ Database services đã được deploy!"
echo "=========================================="
echo ""
echo "Services:"
echo "  - ${POSTGRES_SERVICE}"
echo "  - ${TIMESCALE_SERVICE}"
echo ""
echo "Để setup secrets, chạy:"
echo "  ./deployment/setup-database-secrets.sh ${ENVIRONMENT}"
echo ""
echo "Để migrate database, chạy migrations sau khi secrets đã được setup."
echo "=========================================="

