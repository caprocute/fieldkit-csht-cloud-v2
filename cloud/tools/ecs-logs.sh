#!/bin/bash

# Script để xem logs của ECS task
# Usage: ./ecs-logs.sh <task-arn> [options]
# Example: ./ecs-logs.sh arn:aws:ecs:ap-southeast-1:585768163363:task/fieldkit-staging-app/f2ba5288b031438580b07dde1fed8b15

set -e

# Colors for output
RED='\033[0;31m'
BOLD_RED='\033[1;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Function to highlight error lines
highlight_errors() {
    # Patterns for errors (case insensitive)
    local error_patterns=(
        'error'
        'ERROR'
        'fatal'
        'FATAL'
        'exception'
        'Exception'
        'panic'
        'PANIC'
        'fail'
        'FAIL'
        'failed'
        'FAILED'
        'critical'
        'CRITICAL'
        'alert'
        'ALERT'
        'emergency'
        'EMERGENCY'
    )
    
    # Build sed command to highlight errors
    local sed_cmd=""
    for pattern in "${error_patterns[@]}"; do
        if [ -z "$sed_cmd" ]; then
            sed_cmd="s/(.*${pattern}.*)/${BOLD_RED}\\1${NC}/gi"
        else
            sed_cmd="${sed_cmd}; s/(.*${pattern}.*)/${BOLD_RED}\\1${NC}/gi"
        fi
    done
    
    # Apply highlighting
    while IFS= read -r line; do
        # Check if line contains any error pattern
        local is_error=false
        local upper_line=$(echo "$line" | tr '[:lower:]' '[:upper:]')
        for pattern in "${error_patterns[@]}"; do
            if echo "$upper_line" | grep -qi "$pattern"; then
                is_error=true
                break
            fi
        done
        
        if [ "$is_error" = true ]; then
            echo -e "${BOLD_RED}${line}${NC}"
        else
            echo "$line"
        fi
    done
}

# Parse task ARN
TASK_ARN="${1}"
if [ -z "$TASK_ARN" ]; then
    echo -e "${RED}Error: Task ARN is required${NC}"
    echo "Usage: $0 <task-arn> [--no-follow] [--since <time>] [--region <region>]"
    echo "Default: --follow (real-time), --since 1m (last 1 minute)"
    echo "Example: $0 arn:aws:ecs:ap-southeast-1:585768163363:task/fieldkit-staging-app/f2ba5288b031438580b07dde1fed8b15"
    exit 1
fi

# Extract components from ARN
# Format: arn:aws:ecs:region:account:task/cluster/task-id
REGION=$(echo "$TASK_ARN" | cut -d: -f4)
CLUSTER=$(echo "$TASK_ARN" | cut -d: -f6 | cut -d/ -f2)
TASK_ID=$(echo "$TASK_ARN" | cut -d: -f6 | cut -d/ -f3)

# Default options
FOLLOW=true
SINCE="1m"
CUSTOM_REGION=""

# Parse additional arguments
shift
while [[ $# -gt 0 ]]; do
    case $1 in
        --follow|-f)
            FOLLOW=true
            shift
            ;;
        --no-follow)
            FOLLOW=false
            shift
            ;;
        --since|-s)
            SINCE="$2"
            shift 2
            ;;
        --region|-r)
            CUSTOM_REGION="$2"
            shift 2
            ;;
        *)
            echo -e "${YELLOW}Unknown option: $1${NC}"
            shift
            ;;
    esac
done

# Use custom region if provided
if [ -n "$CUSTOM_REGION" ]; then
    REGION="$CUSTOM_REGION"
fi

echo -e "${GREEN}Fetching logs for ECS task...${NC}"
echo "  Task ARN: $TASK_ARN"
echo "  Cluster: $CLUSTER"
echo "  Task ID: $TASK_ID"
echo "  Region: $REGION"
echo ""

# Get task details to find log configuration
echo -e "${GREEN}Getting task details...${NC}"
TASK_INFO=$(aws ecs describe-tasks \
    --cluster "$CLUSTER" \
    --tasks "$TASK_ID" \
    --region "$REGION" \
    --output json)

# Check if task exists
if [ -z "$TASK_INFO" ] || [ "$(echo "$TASK_INFO" | jq -r '.tasks | length')" -eq 0 ]; then
    echo -e "${RED}Error: Task not found${NC}"
    exit 1
fi

# Get task definition
TASK_DEF_ARN=$(echo "$TASK_INFO" | jq -r '.tasks[0].taskDefinitionArn')
echo "  Task Definition: $TASK_DEF_ARN"

# Get log configuration from task definition
TASK_DEF=$(aws ecs describe-task-definition \
    --task-definition "$TASK_DEF_ARN" \
    --region "$REGION" \
    --output json)

# Extract log group and container name
LOG_GROUP=$(echo "$TASK_DEF" | jq -r '.taskDefinition.containerDefinitions[0].logConfiguration.options."awslogs-group" // empty')
CONTAINER_NAME=$(echo "$TASK_DEF" | jq -r '.taskDefinition.containerDefinitions[0].name // "app"')

if [ -z "$LOG_GROUP" ] || [ "$LOG_GROUP" == "null" ]; then
    echo -e "${YELLOW}Warning: Log group not found in task definition, trying default pattern...${NC}"
    # Try common log group patterns
    LOG_GROUP="/ecs/$CLUSTER"
fi

echo "  Log Group: $LOG_GROUP"
echo "  Container: $CONTAINER_NAME"
echo ""

# Find log stream
echo -e "${GREEN}Finding log stream...${NC}"

# Try multiple patterns
PATTERNS=(
    "ecs/$CONTAINER_NAME/$TASK_ID"
    "$CONTAINER_NAME/$TASK_ID"
    "$TASK_ID"
)

LOG_STREAM=""
for PATTERN in "${PATTERNS[@]}"; do
    echo "  Trying pattern: $PATTERN"
    FOUND=$(aws logs describe-log-streams \
        --log-group-name "$LOG_GROUP" \
        --log-stream-name-prefix "$PATTERN" \
        --region "$REGION" \
        --order-by LastEventTime \
        --descending \
        --max-items 1 \
        --query 'logStreams[0].logStreamName' \
        --output text 2>/dev/null || echo "")
    
    if [ -n "$FOUND" ] && [ "$FOUND" != "None" ]; then
        LOG_STREAM="$FOUND"
        echo "  Found: $LOG_STREAM"
        break
    fi
done

# If still not found, search by task ID in any stream
if [ -z "$LOG_STREAM" ] || [ "$LOG_STREAM" == "None" ]; then
    echo -e "${YELLOW}Warning: Prefix search failed, searching for any stream with task ID...${NC}"
    # Get recent streams and filter
    ALL_STREAMS=$(aws logs describe-log-streams \
        --log-group-name "$LOG_GROUP" \
        --region "$REGION" \
        --order-by LastEventTime \
        --descending \
        --max-items 50 \
        --query 'logStreams[*].logStreamName' \
        --output text 2>/dev/null || echo "")
    
    if [ -n "$ALL_STREAMS" ]; then
        LOG_STREAM=$(echo "$ALL_STREAMS" | tr '\t' '\n' | grep "$TASK_ID" | head -1)
    fi
fi

# Verify log stream exists
if [ -z "$LOG_STREAM" ] || [ "$LOG_STREAM" == "None" ]; then
    echo -e "${RED}Error: Could not find log stream for task $TASK_ID${NC}"
    echo ""
    echo "Recent log streams in $LOG_GROUP:"
    aws logs describe-log-streams \
        --log-group-name "$LOG_GROUP" \
        --region "$REGION" \
        --order-by LastEventTime \
        --descending \
        --max-items 10 \
        --query 'logStreams[*].[logStreamName, lastEventTime]' \
        --output table 2>/dev/null || echo "  (Could not list log streams)"
    exit 1
fi

# Verify the log stream actually exists
echo "  Verifying log stream exists..."
STREAM_CHECK=$(aws logs describe-log-streams \
    --log-group-name "$LOG_GROUP" \
    --log-stream-name-prefix "$LOG_STREAM" \
    --region "$REGION" \
    --max-items 1 \
    --query 'logStreams[0].logStreamName' \
    --output text 2>/dev/null || echo "")

if [ -z "$STREAM_CHECK" ] || [ "$STREAM_CHECK" == "None" ]; then
    echo -e "${RED}Error: Log stream $LOG_STREAM does not exist or is not accessible${NC}"
    echo ""
    echo "Recent log streams in $LOG_GROUP:"
    aws logs describe-log-streams \
        --log-group-name "$LOG_GROUP" \
        --region "$REGION" \
        --order-by LastEventTime \
        --descending \
        --max-items 10 \
        --query 'logStreams[*].logStreamName' \
        --output table 2>/dev/null || echo "  (Could not list log streams)"
    exit 1
fi

echo "  Log Stream: $LOG_STREAM"
echo ""

# Display logs
echo -e "${GREEN}Fetching logs...${NC}"
echo "  Since: $SINCE"
echo "  Follow: $FOLLOW"
echo ""

if [ "$FOLLOW" = true ]; then
    echo -e "${GREEN}Following logs (Ctrl+C to stop)...${NC}"
    echo ""
    aws logs tail "$LOG_GROUP" \
        --log-stream-names "$LOG_STREAM" \
        --follow \
        --since "$SINCE" \
        --region "$REGION" \
        --format short | highlight_errors
else
    aws logs tail "$LOG_GROUP" \
        --log-stream-names "$LOG_STREAM" \
        --since "$SINCE" \
        --region "$REGION" \
        --format short | highlight_errors
fi

