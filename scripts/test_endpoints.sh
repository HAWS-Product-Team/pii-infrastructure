#!/bin/bash

# Script to test API Gateway endpoints and verify mock responses.
# Usage: ./test_endpoints.sh [api_id] [region] [stage]

API_ID=$1
REGION=${2:-"us-east-1"}
STAGE=${3:-"dev"}
APP_NAME="pii" # Default app name from terraform variables

# If API_ID is not provided, try to discover it using AWS CLI
if [ -z "$API_ID" ]; then
    echo "No API_ID provided. Attempting to discover it using AWS CLI..."
    API_NAME="${APP_NAME}-${STAGE}-api"
    
    API_ID=$(aws apigateway get-rest-apis --region "${REGION}" \
        --query "items[?name=='${API_NAME}'].id" --output text)

    if [ -z "$API_ID" ] || [ "$API_ID" == "None" ]; then
        echo "Error: Could not discover API_ID for API named '${API_NAME}' in region '${REGION}'."
        echo "Usage: $0 [api_id] [region] [stage]"
        echo "Example: $0 abc123def4 us-east-1 dev"
        exit 1
    fi
    echo "Discovered API_ID: ${API_ID}"
    echo "Note: if you see a blank space between two IDs, then there are two api gateways with the same name in your cloud."
    echo "This script doesn't handle that case so you should copy the ID you care about, then calle the script again with the ID."
fi

BASE_URL="https://${API_ID}.execute-api.${REGION}.amazonaws.com/${STAGE}"

echo "Testing API Gateway at: ${BASE_URL}"
echo "--------------------------------------------------"

# 1. Welcome Page (Root)
echo "Testing Endpoint 1: Welcome Page (GET /)"
echo "Command: curl -s -X GET \"${BASE_URL}/\" -H \"Content-Type: application/json\""
curl -s -X GET "${BASE_URL}/" -H "Content-Type: application/json" | jq .
echo -e "\n--------------------------------------------------"

# 2. Submit Spending History (/spending-history)
echo "Testing Endpoint 2: Submit Spending History (POST /spending-history)"
# Mock response includes a sample Bearer token in the header
echo "Command: curl -s -i -X POST \"${BASE_URL}/spending-history\" -H \"Content-Type: application/json\" -d '{\"data\": \"sample\"}'"
curl -s -i -X POST "${BASE_URL}/spending-history" -H "Content-Type: application/json" -d '{"data": "sample"}' | grep -iE "HTTP/|Authorization|{"
echo -e "\n--------------------------------------------------"

# 3. PII Report Status (/pii-report-status)
echo "Testing Endpoint 3: PII Report Status (GET /pii-report-status)"
# This endpoint requires a CUSTOM authorizer (Bearer token)
# Using the example token from mocks.tf
TOKEN="Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiIxMjM0NTY3ODkwIiwibmFtZSI6IkpvaG4gRG9lIiwiaWF0IjoyMDE2MjMyMTIzfQ.example_signature"

echo "Command: curl -s -X GET \"${BASE_URL}/pii-report-status\" -H \"Authorization: \${TOKEN}\" -H \"Content-Type: application/json\""
curl -s -X GET "${BASE_URL}/pii-report-status" \
     -H "Authorization: ${TOKEN}" \
     -H "Content-Type: application/json" | jq .
echo -e "\n--------------------------------------------------"
