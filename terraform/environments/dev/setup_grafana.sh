#!/bin/bash

GRAFANA_URL="http://16.22.20.11:3000"
USER_PASS="admin:admin"

echo "1. Creating CloudWatch Datasource..."
curl -s -X POST "$GRAFANA_URL/api/datasources" \
  -H "Content-Type: application/json" \
  -u "$USER_PASS" \
  -d '{
    "name": "CloudWatch",
    "type": "cloudwatch",
    "access": "proxy",
    "isDefault": true,
    "jsonData": {
      "authType": "default",
      "defaultRegion": "eu-south-1"
    }
  }' | jq .

echo ""
echo "2. Creating Service Account..."
SA_RES=$(curl -s -X POST "$GRAFANA_URL/api/serviceaccounts" \
  -H "Content-Type: application/json" \
  -u "$USER_PASS" \
  -d '{
    "name": "n8n-integrator",
    "role": "Editor"
  }')
echo $SA_RES | jq .

SA_ID=$(echo $SA_RES | jq -r .id)

echo ""
echo "3. Generating API Token..."
curl -s -X POST "$GRAFANA_URL/api/serviceaccounts/${SA_ID}/tokens" \
  -H "Content-Type: application/json" \
  -u "$USER_PASS" \
  -d '{
    "name": "n8n-token",
    "role": "Editor"
  }' > grafana_token.json

cat grafana_token.json | jq .

