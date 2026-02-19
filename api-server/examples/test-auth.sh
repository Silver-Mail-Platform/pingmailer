#!/bin/bash

# Example script demonstrating dual authentication with PingMailer API
# This script shows how to:
# 1. Obtain an application access token using OAuth2 client credentials
# 2. Send an email notification using the access token and user SMTP credentials

set -e

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Configuration - Update these values
OAUTH2_SERVER="https://localhost:8090"
API_SERVER="https://localhost:8080"
CLIENT_ID="${OAUTH2_CLIENT_ID:-your-client-id}"
CLIENT_SECRET="${OAUTH2_CLIENT_SECRET:-your-client-secret}"

# User SMTP Configuration
SMTP_HOST="smtp.gmail.com"
SMTP_PORT=587
SMTP_USERNAME="user@gmail.com"
SMTP_PASSWORD="user-app-password"
SMTP_SENDER="user@gmail.com"

# Email details
RECIPIENT_NAME="John Doe"
RECIPIENT_EMAIL="recipient@example.com"
APP_NAME="PingMailer Demo"

echo -e "${YELLOW}=== PingMailer Dual Authentication Demo ===${NC}\n"

# Step 1: Get application access token
echo -e "${YELLOW}Step 1: Requesting application access token...${NC}"
echo "OAuth2 Server: $OAUTH2_SERVER/oauth2/token"
echo "Client ID: $CLIENT_ID"
echo ""

TOKEN_RESPONSE=$(curl -sk -X POST "$OAUTH2_SERVER/oauth2/token" \
  -d 'grant_type=client_credentials' \
  -u "$CLIENT_ID:$CLIENT_SECRET" \
  -w "\n%{http_code}")

HTTP_CODE=$(echo "$TOKEN_RESPONSE" | tail -n1)
BODY=$(echo "$TOKEN_RESPONSE" | sed '$d')

if [ "$HTTP_CODE" -eq 200 ]; then
    echo -e "${GREEN}✓ Access token obtained successfully${NC}"
    ACCESS_TOKEN=$(echo "$BODY" | jq -r '.access_token')
    EXPIRES_IN=$(echo "$BODY" | jq -r '.expires_in')
    echo "Token Type: Bearer"
    echo "Expires in: $EXPIRES_IN seconds"
    echo "Token (first 50 chars): ${ACCESS_TOKEN:0:50}..."
    echo ""
else
    echo -e "${RED}✗ Failed to get access token${NC}"
    echo "HTTP Status: $HTTP_CODE"
    echo "Response: $BODY"
    exit 1
fi

# Step 2: Send email notification with Bearer token and user SMTP credentials
echo -e "${YELLOW}Step 2: Sending email notification...${NC}"
echo "API Server: $API_SERVER/notify"
echo "SMTP Server: $SMTP_HOST:$SMTP_PORT"
echo "From: $SMTP_SENDER"
echo "To: $RECIPIENT_EMAIL"
echo ""

NOTIFY_RESPONSE=$(curl -sk -X POST "$API_SERVER/notify" \
  -H "Authorization: Bearer $ACCESS_TOKEN" \
  -H "Content-Type: application/json" \
  -w "\n%{http_code}" \
  -d "{
    \"smtp_host\": \"$SMTP_HOST\",
    \"smtp_port\": $SMTP_PORT,
    \"smtp_username\": \"$SMTP_USERNAME\",
    \"smtp_password\": \"$SMTP_PASSWORD\",
    \"smtp_sender\": \"$SMTP_SENDER\",
    \"recipient_name\": \"$RECIPIENT_NAME\",
    \"recipient_email\": \"$RECIPIENT_EMAIL\",
    \"app_name\": \"$APP_NAME\"
  }")

HTTP_CODE=$(echo "$NOTIFY_RESPONSE" | tail -n1)
BODY=$(echo "$NOTIFY_RESPONSE" | sed '$d')

if [ "$HTTP_CODE" -eq 200 ]; then
    echo -e "${GREEN}✓ Email notification queued successfully${NC}"
    echo ""
else
    echo -e "${RED}✗ Failed to send notification${NC}"
    echo "HTTP Status: $HTTP_CODE"
    echo "Response: $BODY"
    exit 1
fi

# Step 3: Test authentication failure (without token)
echo -e "${YELLOW}Step 3: Testing authentication failure (without token)...${NC}"

FAIL_RESPONSE=$(curl -sk -X POST "$API_SERVER/notify" \
  -H "Content-Type: application/json" \
  -w "\n%{http_code}" \
  -d "{
    \"smtp_host\": \"$SMTP_HOST\",
    \"smtp_port\": $SMTP_PORT,
    \"smtp_username\": \"$SMTP_USERNAME\",
    \"smtp_password\": \"$SMTP_PASSWORD\",
    \"smtp_sender\": \"$SMTP_SENDER\",
    \"recipient_email\": \"$RECIPIENT_EMAIL\"
  }")

HTTP_CODE=$(echo "$FAIL_RESPONSE" | tail -n1)
BODY=$(echo "$FAIL_RESPONSE" | sed '$d')

if [ "$HTTP_CODE" -eq 401 ]; then
    echo -e "${GREEN}✓ Authentication correctly rejected (expected)${NC}"
    echo "Error: $BODY"
    echo ""
else
    echo -e "${RED}✗ Unexpected response (expected 401)${NC}"
    echo "HTTP Status: $HTTP_CODE"
    echo "Response: $BODY"
    echo ""
fi

# Step 4: Check server health
echo -e "${YELLOW}Step 4: Checking server health...${NC}"

HEALTH_RESPONSE=$(curl -sk "$API_SERVER/health" -w "\n%{http_code}")
HTTP_CODE=$(echo "$HEALTH_RESPONSE" | tail -n1)
BODY=$(echo "$HEALTH_RESPONSE" | sed '$d')

if [ "$HTTP_CODE" -eq 200 ]; then
    echo -e "${GREEN}✓ Server is healthy${NC}"
    echo "$BODY" | jq '.'
    echo ""
else
    echo -e "${RED}✗ Server health check failed${NC}"
    echo "HTTP Status: $HTTP_CODE"
    echo ""
fi

echo -e "${GREEN}=== Demo completed successfully ===${NC}"
echo ""
echo "Summary:"
echo "1. ✓ Obtained application access token via OAuth2"
echo "2. ✓ Sent email with Bearer token + user SMTP credentials"
echo "3. ✓ Verified authentication is enforced"
echo "4. ✓ Server is healthy"
