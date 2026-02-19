# Quick Reference

## Authentication Flow

```
1. Get Token    → 2. Use Token       → 3. Server Validates → 4. Email Sent
   (OAuth2)        (API Request)         (App + User Auth)      (via SMTP)
```

## 1. Get Application Token

```bash
curl -k -X POST https://localhost:8090/oauth2/token \
  -d 'grant_type=client_credentials' \
  -u '<client_id>:<client_secret>'
```

**Response:**
```json
{"access_token": "...", "token_type": "Bearer", "expires_in": 3600}
```

## 2. Send Email

```bash
curl -X POST https://localhost:8080/notify \
  -H "Authorization: Bearer <access_token>" \
  -H "Content-Type: application/json" \
  -d '{
    "smtp_host": "smtp.gmail.com",
    "smtp_port": 587,
    "smtp_username": "user@gmail.com",
    "smtp_password": "app-password",
    "smtp_sender": "user@gmail.com",
    "recipient_email": "recipient@example.com",
    "recipient_name": "John Doe",
    "app_name": "MyApp"
  }'
```

**Response:**
```json
{
  "message": "Email queued successfully",
  "status": "ok"
}
```

## 3. Check Health

```bash
curl https://localhost:8080/health
```

## Required Fields

| Field | Example | Notes |
|-------|---------|-------|
| `smtp_host` | smtp.gmail.com | SMTP server |
| `smtp_port` | 587 | Use 587 for TLS |
| `smtp_username` | user@gmail.com | User's SMTP username |
| `smtp_password` | app-password | User's SMTP password |
| `smtp_sender` | user@gmail.com | From address |
| `recipient_email` | to@example.com | To address |

## Optional Fields

| Field | Default | Description |
|-------|---------|-------------|
| `recipient_name` | "User" | Display name |
| `app_name` | "Application" | App name in email |
| `template` | - | Custom template |
| `template_data` | - | Template variables |

## Server Startup

```bash
# Minimal
./api-server \
  -oauth2-client-id "id" \
  -oauth2-client-secret "secret"

# Full options
./api-server \
  -port 8080 \
  -cert /path/to/cert.pem \
  -key /path/to/key.pem \
  -oauth2-token-url "https://oauth2-server/token" \
  -oauth2-client-id "client-id" \
  -oauth2-client-secret "client-secret"
```

## Docker Compose

```bash
# Setup
cp .env.example .env
# Edit .env with your credentials

# Run
docker compose -f docker-compose.https.yml up -d

# Logs
docker logs pingmailer-api-server -f
```

## HTTP Status Codes

| Code | Meaning |
|------|---------|
| 200 | Success - Email queued |
| 400 | Bad Request - Missing/invalid fields |
| 401 | Unauthorized - Missing/invalid token |
| 405 | Method Not Allowed - Use POST |
| 500 | Server Error - Check logs |

## Common Errors

### "missing Authorization header"
**Fix:** Add `-H "Authorization: Bearer <token>"`

### "invalid or expired token"
**Fix:** Get a new token from OAuth2 server

### "Missing required field"
**Fix:** Check required fields in request body

### "OAuth2 client credentials must be provided"
**Fix:** Start server with `-oauth2-client-id` and `-oauth2-client-secret`

## Environment Variables

```bash
# For Docker Compose
DOMAIN=yourdomain.com
CERT_PATH=/path/to/certs
OAUTH2_TOKEN_URL=https://oauth2-server/token
OAUTH2_CLIENT_ID=your-client-id
OAUTH2_CLIENT_SECRET=your-client-secret
```

## Example Scripts

### Bash
```bash
cd examples
./test-auth.sh
```

### Python
```bash
cd examples
pip install requests
python client.py
```

## Security Checklist

- [x] Application authenticated via OAuth2 Bearer token
- [x] User authenticated via SMTP credentials
- [x] Tokens cached and auto-refreshed
- [x] HTTPS/TLS for production
- [x] Email validation
- [x] Asynchronous email sending
- [x] Health check endpoint

## Monitoring

```bash
# Health check
watch -n 5 'curl -sk https://localhost:8080/health | jq'

# Logs
docker logs pingmailer-api-server -f --tail 100
```

## Links

- [AUTH.md](AUTH.md) - Full authentication documentation
- [TESTING.md](TESTING.md) - Testing guide
- [README.md](README.md) - Complete documentation
