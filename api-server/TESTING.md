# Testing Guide

This guide helps you test the dual authentication implementation.

## Prerequisites

1. **OAuth2 Server** running at `https://localhost:8090/oauth2/token`
2. **Valid OAuth2 credentials**: client_id and client_secret
3. **SMTP server** for sending emails (or use a test SMTP service)

## Setup

### 1. Configure Environment

```bash
cd api-server
cp .env.example .env
```

Edit `.env` and set:
```bash
OAUTH2_TOKEN_URL=https://localhost:8090/oauth2/token
OAUTH2_CLIENT_ID=your-actual-client-id
OAUTH2_CLIENT_SECRET=your-actual-client-secret
```

### 2. Start the API Server

#### Option A: Run locally

```bash
source .env  # Load environment variables

go run . \
  -oauth2-client-id "$OAUTH2_CLIENT_ID" \
  -oauth2-client-secret "$OAUTH2_CLIENT_SECRET" \
  -oauth2-token-url "$OAUTH2_TOKEN_URL"
```

#### Option B: Run with Docker Compose

```bash
docker compose -f docker-compose.https.yml up -d
docker logs pingmailer-api-server -f
```

## Test Cases

### Test 1: Health Check (No Auth Required)

```bash
curl -k https://localhost:8080/health
```

**Expected Result:**
```json
{
  "status": "ok",
  "version": "0.1.0"
}
```

### Test 2: Get Application Access Token

```bash
curl -k -X POST https://localhost:8090/oauth2/token \
  -d 'grant_type=client_credentials' \
  -u 'your-client-id:your-client-secret'
```

**Expected Result:**
```json
{
  "access_token": "eyJhbGciOiJSUzI1NiIsInR5cCI6IkpXVCJ9...",
  "token_type": "Bearer",
  "expires_in": 3600
}
```

### Test 3: Send Email with Valid Authentication

```bash
# Get token
TOKEN=$(curl -sk -X POST https://localhost:8090/oauth2/token \
  -d 'grant_type=client_credentials' \
  -u 'your-client-id:your-client-secret' \
  | jq -r '.access_token')

# Send email
curl -k -X POST https://localhost:8080/notify \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "smtp_host": "smtp.gmail.com",
    "smtp_port": 587,
    "smtp_username": "your-email@gmail.com",
    "smtp_password": "your-app-password",
    "smtp_sender": "your-email@gmail.com",
    "recipient_email": "recipient@example.com",
    "recipient_name": "Test User",
    "app_name": "TestApp"
  }'
```

**Expected Result:**
```
HTTP/1.1 200 OK
```

### Test 4: Request Without Bearer Token (Should Fail)

```bash
curl -k -X POST https://localhost:8080/notify \
  -H "Content-Type: application/json" \
  -d '{
    "smtp_host": "smtp.gmail.com",
    "smtp_port": 587,
    "smtp_username": "user@gmail.com",
    "smtp_password": "password",
    "smtp_sender": "user@gmail.com",
    "recipient_email": "recipient@example.com"
  }'
```

**Expected Result:**
```
HTTP/1.1 401 Unauthorized
Unauthorized: missing Authorization header
```

### Test 5: Request with Invalid Token (Should Fail)

```bash
curl -k -X POST https://localhost:8080/notify \
  -H "Authorization: Bearer invalid-token-12345" \
  -H "Content-Type: application/json" \
  -d '{
    "smtp_host": "smtp.gmail.com",
    "smtp_port": 587,
    "smtp_username": "user@gmail.com",
    "smtp_password": "password",
    "smtp_sender": "user@gmail.com",
    "recipient_email": "recipient@example.com"
  }'
```

**Expected Result:**
```
HTTP/1.1 401 Unauthorized
Unauthorized: invalid or expired token
```

### Test 6: Request with Invalid SMTP Credentials (Should Fail at SMTP)

```bash
TOKEN=$(curl -sk -X POST https://localhost:8090/oauth2/token \
  -d 'grant_type=client_credentials' \
  -u 'your-client-id:your-client-secret' \
  | jq -r '.access_token')

curl -k -X POST https://localhost:8080/notify \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "smtp_host": "smtp.gmail.com",
    "smtp_port": 587,
    "smtp_username": "wrong@gmail.com",
    "smtp_password": "wrong-password",
    "smtp_sender": "wrong@gmail.com",
    "recipient_email": "recipient@example.com"
  }'
```

**Expected Result:**
```
HTTP/1.1 200 OK
```
Note: Returns 200 because email is queued asynchronously. Check server logs for SMTP authentication failure.

### Test 7: Missing Required Fields (Should Fail)

```bash
TOKEN=$(curl -sk -X POST https://localhost:8090/oauth2/token \
  -d 'grant_type=client_credentials' \
  -u 'your-client-id:your-client-secret' \
  | jq -r '.access_token')

curl -k -X POST https://localhost:8080/notify \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "smtp_host": "smtp.gmail.com",
    "recipient_email": "recipient@example.com"
  }'
```

**Expected Result:**
```
HTTP/1.1 400 Bad Request
Missing required field: smtp_port
```

## Automated Testing

### Using the Bash Script

```bash
cd examples
chmod +x test-auth.sh

# Update script variables
export OAUTH2_CLIENT_ID="your-client-id"
export OAUTH2_CLIENT_SECRET="your-client-secret"

./test-auth.sh
```

### Using the Python Client

```bash
cd examples
pip install requests

# Set environment variables
export OAUTH2_CLIENT_ID="your-client-id"
export OAUTH2_CLIENT_SECRET="your-client-secret"
export SMTP_USERNAME="your-email@gmail.com"
export SMTP_PASSWORD="your-app-password"

python client.py
```

## Troubleshooting

### Problem: "OAuth2 client credentials must be provided"

**Cause:** Server started without OAuth2 credentials

**Solution:**
```bash
go run . \
  -oauth2-client-id "your-id" \
  -oauth2-client-secret "your-secret"
```

### Problem: "failed to get application token"

**Cause:** Cannot connect to OAuth2 server

**Solutions:**
1. Check OAuth2 server is running: `curl -k https://localhost:8090/oauth2/token`
2. Verify credentials are correct
3. Check network connectivity
4. For self-signed certs, use `-k` flag with curl

### Problem: "Unauthorized: invalid or expired token"

**Cause:** Token validation failed

**Solutions:**
1. Get a fresh token from OAuth2 server
2. Check token hasn't expired
3. Verify OAuth2 server configuration matches API server

### Problem: Email sending fails silently

**Cause:** Asynchronous email sending - check server logs

**Solution:**
```bash
# Check logs for SMTP errors
docker logs pingmailer-api-server -f

# Or if running locally, check console output
```

### Problem: "x509: certificate signed by unknown authority"

**Cause:** Self-signed certificates

**Solution:**
Use `-k` flag with curl or configure proper TLS certificates

## Performance Testing

### Load Test with Multiple Requests

```bash
TOKEN=$(curl -sk -X POST https://localhost:8090/oauth2/token \
  -d 'grant_type=client_credentials' \
  -u 'your-client-id:your-client-secret' \
  | jq -r '.access_token')

# Send 10 requests
for i in {1..10}; do
  curl -sk -X POST https://localhost:8080/notify \
    -H "Authorization: Bearer $TOKEN" \
    -H "Content-Type: application/json" \
    -d '{
      "smtp_host": "smtp.gmail.com",
      "smtp_port": 587,
      "smtp_username": "user@gmail.com",
      "smtp_password": "password",
      "smtp_sender": "user@gmail.com",
      "recipient_email": "recipient'$i'@example.com"
    }' &
done
wait
```

### Token Caching Test

The server caches application tokens. Test by:

1. Making multiple requests
2. Checking server logs - should only see one "fetched new application access token" message
3. Wait for token to expire
4. Make another request - should see new token fetch

```bash
TOKEN=$(curl -sk -X POST https://localhost:8090/oauth2/token \
  -d 'grant_type=client_credentials' \
  -u 'your-client-id:your-client-secret' \
  | jq -r '.access_token')

# First request - server fetches and caches token
curl -sk -X POST https://localhost:8080/notify \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{...}'

# Second request - should use cached token
curl -sk -X POST https://localhost:8080/notify \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{...}'
```

## Security Testing

### Test 1: Verify Authorization Header Format

```bash
# Missing "Bearer" prefix
curl -k -X POST https://localhost:8080/notify \
  -H "Authorization: token123" \
  -H "Content-Type: application/json" \
  -d '{...}'
# Expected: 401 Unauthorized
```

### Test 2: Verify Email Address Validation

```bash
TOKEN=$(curl -sk -X POST https://localhost:8090/oauth2/token \
  -d 'grant_type=client_credentials' \
  -u 'your-client-id:your-client-secret' \
  | jq -r '.access_token')

# Invalid email format
curl -k -X POST https://localhost:8080/notify \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "smtp_host": "smtp.gmail.com",
    "smtp_port": 587,
    "smtp_username": "user@gmail.com",
    "smtp_password": "password",
    "smtp_sender": "invalid-email",
    "recipient_email": "recipient@example.com"
  }'
# Expected: 400 Bad Request
```

## Monitoring

### Check Server Health

```bash
watch -n 5 'curl -sk https://localhost:8080/health | jq'
```

### Monitor Logs

```bash
# Docker
docker logs pingmailer-api-server -f --tail 100

# Local
# Server outputs to stdout with structured logging
```

### Key Log Messages

- `"fetched new application access token"` - Token refreshed
- `"authentication failed"` - Client auth attempt failed
- `"token validation failed"` - Invalid token provided
- `"failed to send email"` - Email sending error (check SMTP credentials)
