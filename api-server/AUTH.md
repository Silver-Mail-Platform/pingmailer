# API Server Authentication Guide

## Overview

The PingMailer API server now implements dual authentication to ensure secure access:

1. **Application-level authentication**: OAuth2 client credentials flow to verify the calling application
2. **User-level authentication**: SMTP credentials passed in the request body to authenticate the email sender

## Authentication Flow

### 1. Application Authentication (OAuth2 Client Credentials)

The API validates that requests come from authorized applications using OAuth2 Bearer tokens via **token introspection**.

#### Getting an Application Access Token

```bash
curl -k -X POST https://localhost:8090/oauth2/token \
  -d 'grant_type=client_credentials' \
  -u '<client_id>:<client_secret>'
```

**Response:**
```json
{
  "access_token": "eyJhbGciOiJSUzI1NiIsInR5cCI6IkpXVCJ9...",
  "token_type": "Bearer",
  "expires_in": 3600
}
```

#### Token Validation (Server-Side)

When a client makes a request, the API server validates the token by calling the OAuth2 introspection endpoint:

```bash
curl -k -X POST https://localhost:8090/oauth2/introspect \
  -u '<server_client_id>:<server_client_secret>' \
  -d "token=eyJhbGciOiJSUzI1NiIsInR5cCI6IkpXVCJ9..."
```

**Introspection Response:**
```json
{
  "active": true,
  "client_id": "myclient_id",
  "token_type": "Bearer",
  "exp": 1771499415,
  "iat": 1771495815,
  "nbf": 1771495815,
  "sub": "myclient_id",
  "aud": "myclient_id",
  "iss": "https://aravindahwk.org:8090",
  "jti": "019c7560-f99f-70bd-a5cc-2a0b941acbe2"
}
```

The server checks:
- `active` is `true`
- Token has not expired (`exp` > current time)


### 2. User Authentication (SMTP Credentials)

User SMTP credentials are provided in the request body and used to authenticate with the SMTP server when sending emails.

## API Endpoints

### POST /notify

Send an email notification using provided SMTP credentials.

**Authentication Required:** Yes (Bearer token)

**Headers:**
```
Authorization: Bearer <access_token>
Content-Type: application/json
```

**Request Body:**
```json
{
  "smtp_host": "smtp.example.com",
  "smtp_port": 587,
  "smtp_username": "user@example.com",
  "smtp_password": "user_smtp_password",
  "smtp_sender": "sender@example.com",
  "recipient_name": "John Doe",
  "recipient_email": "recipient@example.com",
  "app_name": "MyApplication",
  "template": "optional custom template",
  "template_data": {
    "custom_field": "custom_value"
  }
}
```

**Required Fields:**
- `smtp_host`: SMTP server hostname
- `smtp_port`: SMTP server port
- `smtp_username`: User's SMTP username
- `smtp_password`: User's SMTP password
- `smtp_sender`: Email address to send from
- `recipient_email`: Email address to send to

**Optional Fields:**
- `recipient_name`: Recipient's display name (default: "User")
- `app_name`: Application name (default: "Application")
- `template`: Custom email template
- `template_data`: Custom data for template rendering

**Example:**
```bash
# First, get an application token
TOKEN=$(curl -k -X POST https://localhost:8090/oauth2/token \
  -d 'grant_type=client_credentials' \
  -u 'my-client-id:my-client-secret' \
  | jq -r '.access_token')

# Then, send the notification with user SMTP credentials
curl -k -X POST https://localhost:8080/notify \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "smtp_host": "smtp.gmail.com",
    "smtp_port": 587,
    "smtp_username": "user@gmail.com",
    "smtp_password": "user_app_password",
    "smtp_sender": "user@gmail.com",
    "recipient_name": "Jane Doe",
    "recipient_email": "jane@example.com",
    "app_name": "WelcomeApp"
  }'
```

**Response:**
- `200 OK`: Email queued successfully
- `400 Bad Request`: Invalid request body or missing required fields
- `401 Unauthorized`: Missing, invalid, or expired access token

### GET /health

Health check endpoint (no authentication required).

**Response:**
```json
{
  "status": "ok",
  "version": "0.1.0"
}
```

## Running the Server

### Required Configuration

The server requires OAuth2 client credentials to be configured at startup:

```bash
./api-server \
  -port 8080 \
  -oauth2-token-url "https://localhost:8090/oauth2/token" \
  -oauth2-client-id "your-client-id" \
  -oauth2-client-secret "your-client-secret" \
  -cert "/path/to/cert.pem" \
  -key "/path/to/key.pem"
```

### Command-line Flags

- `-port`: API server port (default: 8080)
- `-version`: Application version (default: "0.1.0")
- `-cert`: Path to TLS certificate file (optional, enables HTTPS)
- `-key`: Path to TLS key file (optional, required if cert is provided)
- `-oauth2-token-url`: OAuth2 token endpoint URL (default: "https://localhost:8090/oauth2/token")
- `-oauth2-introspect-url`: OAuth2 introspection endpoint URL (default: "https://localhost:8090/oauth2/introspect")
- `-oauth2-client-id`: OAuth2 client ID (required)
- `-oauth2-client-secret`: OAuth2 client secret (required)

### Environment Variables (Alternative)

You can also use environment variables:

```bash
export OAUTH2_CLIENT_ID="your-client-id"
export OAUTH2_CLIENT_SECRET="your-client-secret"

./api-server \
  -oauth2-client-id "$OAUTH2_CLIENT_ID" \
  -oauth2-client-secret "$OAUTH2_CLIENT_SECRET"
```

## Security Considerations

1. **Token Introspection**: Tokens are validated in real-time using OAuth2 introspection endpoint
2. **No Token Caching**: Each request is validated against the OAuth2 server for maximum security
3. **HTTPS Only**: Always use HTTPS in production to protect tokens and credentials in transit
4. **Credential Separation**: Application credentials (client_id/secret) are separate from user SMTP credentials
5. **Token Validation**: Each request validates the Bearer token via introspection before processing
6. **SMTP Authentication**: User SMTP credentials are validated when connecting to the SMTP server

## Error Handling

### Authentication Errors

**401 Unauthorized:**
- Missing Authorization header
- Invalid Authorization header format
- Invalid or expired access token

**Example:**
```json
{
  "error": "Unauthorized: invalid or expired token"
}
```

### Validation Errors

**400 Bad Request:**
- Missing required fields
- Invalid email format
- Invalid JSON body

**Example:**
```json
{
  "error": "Missing required field: smtp_host"
}
```

## Testing

### 1. Check Server Health

```bash
curl -k https://localhost:8080/health
```

### 2. Test Authentication Flow

```bash
# Step 1: Get application token
TOKEN=$(curl -k -X POST https://localhost:8090/oauth2/token \
  -d 'grant_type=client_credentials' \
  -u 'client-id:client-secret' \
  | jq -r '.access_token')

# Step 2: Test with valid token
curl -k -X POST https://localhost:8080/notify \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "smtp_host": "smtp.example.com",
    "smtp_port": 587,
    "smtp_username": "user@example.com",
    "smtp_password": "password",
    "smtp_sender": "sender@example.com",
    "recipient_email": "recipient@example.com"
  }'

# Step 3: Test without token (should fail)
curl -k -X POST https://localhost:8080/notify \
  -H "Content-Type: application/json" \
  -d '{
    "smtp_host": "smtp.example.com",
    "smtp_port": 587,
    "smtp_username": "user@example.com",
    "smtp_password": "password",
    "smtp_sender": "sender@example.com",
    "recipient_email": "recipient@example.com"
  }'
```

## Architecture

```
┌─────────────┐
│   Client    │
└──────┬──────┘
       │
       │ 1. Request app token
       ▼
┌─────────────────────┐
│  OAuth2 Server      │
│  (port 8090)        │
└──────┬──────────────┘
       │
       │ 2. Return access_token
       ▼
┌─────────────┐
│   Client    │
└──────┬──────┘
       │
       │ 3. POST /notify with Bearer token + SMTP creds
       ▼
┌─────────────────────┐
│  API Server         │
│  (port 8080)        │
│  - Validates token  │
│  - Uses SMTP creds  │
└──────┬──────────────┘
       │
       │ 4. Send email
       ▼
┌─────────────────────┐
│  SMTP Server        │
│  (uses user creds)  │
└─────────────────────┘
```

## Migration from Previous Version

If you're upgrading from a version without OAuth2 authentication:

1. **Set up OAuth2 server** at `https://localhost:8090/oauth2/token`
2. **Obtain client credentials** (client_id and client_secret)
3. **Update server startup** to include OAuth2 configuration flags
4. **Update API clients** to:
   - First request an application token
   - Include the Bearer token in all API requests
5. **Keep SMTP credentials** in the request body (no changes needed)

## Troubleshooting

### "OAuth2 client credentials must be provided"

**Cause:** Missing `-oauth2-client-id` or `-oauth2-client-secret` flags

**Solution:**
```bash
./api-server \
  -oauth2-client-id "your-id" \
  -oauth2-client-secret "your-secret"
```

### "Unauthorized: invalid or expired token"

**Cause:** Token validation failed

**Solution:**
1. Request a new access token from the OAuth2 server
2. Verify the OAuth2 server is running and accessible
3. Check that client credentials are correct

### "failed to get application token"

**Cause:** Cannot connect to OAuth2 server or invalid credentials

**Solution:**
1. Verify OAuth2 server is running at the configured URL
2. Check client_id and client_secret are correct
3. Check network connectivity and TLS certificates
