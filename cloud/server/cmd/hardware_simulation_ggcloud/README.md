# Hardware Simulator - Cloud Deployment

## Prerequisites
```bash
# Install gcloud CLI and authenticate
gcloud auth login
gcloud config set project YOUR_PROJECT_ID

# Enable required APIs
gcloud services enable run.googleapis.com
gcloud services enable containerregistry.googleapis.com
```

## Quick Deploy
```bash
# 1. Edit deploy.sh with your PROJECT_ID
nano deploy.sh

# 2. Make executable and run
chmod +x deploy.sh
./deploy.sh
```

## Manual Build & Deploy
```bash
# Build
docker build -t gcr.io/PROJECT_ID/hardware-sim:latest .

# Push
docker push gcr.io/PROJECT_ID/hardware-sim:latest

# Deploy
gcloud run deploy hardware-sim \
  --image gcr.io/PROJECT_ID/hardware-sim:latest \
  --region asia-southeast1 \
  --platform managed \
  --allow-unauthenticated \
  --set-env-vars "API_URL=http://...,DATABASE_URL=postgres://...,EMAIL=user@test.local,PASSWORD=pass,STATION_ID=112,INTERVAL=90s,BATCH=100"
```

## Environment Variables
- `API_URL`: Target API endpoint
- `DATABASE_URL`: PostgreSQL connection string
- `EMAIL`: Login email (auto-login if TOKEN not set)
- `PASSWORD`: Login password
- `STATION_ID`: Station to simulate (0 = all)
- `INTERVAL`: Upload interval (e.g., 30s, 5m)
- `BATCH`: Readings per upload

## Test Locally
```bash
docker build -t hardware-sim .
docker run -e API_URL=http://... -e DATABASE_URL=postgres://... hardware-sim
```
