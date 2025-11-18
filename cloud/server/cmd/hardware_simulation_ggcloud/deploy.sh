#!/bin/bash
set -e

PROJECT_ID="hardware-simulator-flood"
SERVICE_NAME="hw-sim-flood"
REGION="asia-east1"
IMAGE_NAME="gcr.io/${PROJECT_ID}/${SERVICE_NAME}:latest"

# Optional: Set these as env vars or pass via --set-env-vars
API_URL="http://fieldkit-staging-alb-1189893191.ap-southeast-1.elb.amazonaws.com"
DB_URL="postgresql://fieldkit:WxdI7USgPlkSVOcrE8cCcn2vA@fieldkit-staging-postgres-nlb-2e92e35ac371a189.elb.ap-southeast-1.amazonaws.com:5432/fieldkit?sslmode=disable"
EMAIL="floodnet@test.local"
PASSWORD="test123456"

echo "🔐 Configuring Docker authentication..."
gcloud auth configure-docker gcr.io --quiet

echo "🔨 Building Docker image for linux/amd64..."
cd ../../  # Go to server directory (context for build)
docker build --platform linux/amd64 -f cmd/hardware_simulation_ggcloud/Dockerfile -t ${IMAGE_NAME} .

echo "📤 Pushing to GCR..."
docker push ${IMAGE_NAME}

echo "🚀 Deploying to Cloud Run..."
gcloud run deploy ${SERVICE_NAME} \
  --image ${IMAGE_NAME} \
  --region ${REGION} \
  --platform managed \
  --allow-unauthenticated \
  --set-env-vars "API_URL=${API_URL},DATABASE_URL=${DB_URL},EMAIL=${EMAIL},PASSWORD=${PASSWORD},STATION_ID=112,INTERVAL=90s,BATCH=100" \
  --memory 512Mi \
  --cpu 1 \
  --timeout 3600 \
  --max-instances 1

echo "✅ Deployment complete!"
echo "Service URL:"
gcloud run services describe ${SERVICE_NAME} --region ${REGION} --format 'value(status.url)'
