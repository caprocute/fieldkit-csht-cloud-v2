#!/bin/bash

# Script để lấy JWT token từ API

API_URL="${FIELDKIT_API_URL:-http://localhost:8080}"
EMAIL="${1:-floodnet@test.local}"
PASSWORD="${2:-test123456}"

TOKEN=$(curl -s -X POST "$API_URL/user/login" \
    -H "Content-Type: application/json" \
    -d "{\"email\":\"$EMAIL\",\"password\":\"$PASSWORD\"}" \
    | jq -r '.token')

if [ -z "$TOKEN" ] || [ "$TOKEN" = "null" ]; then
    echo "Error: Failed to get token" >&2
    exit 1
fi

echo "$TOKEN"

