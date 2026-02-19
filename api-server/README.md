# PingMailer API Server

A REST API service for sending emails via SMTP with dual authentication. Part of the Silver Mail Platform.

## Features

- **Dual Authentication**: 
  - Application-level authentication via OAuth2 Bearer tokens
  - User-level authentication via SMTP credentials
- **Secure Email Delivery**: Send emails using user-provided SMTP credentials
- **Custom Templates**: Support for custom email templates
- **HTTPS Support**: TLS/SSL support for secure communications
- **Health Monitoring**: Built-in health check endpoint

## Authentication

This API implements dual authentication for enhanced security:

1. **Application Authentication**: OAuth2 client credentials flow validates the calling application
2. **User Authentication**: SMTP credentials in the request body authenticate the email sender

See [AUTH.md](AUTH.md) for detailed authentication documentation.

## Quick Start

### Deploy with Docker Compose (Recommended)

```bash
# 1. Configure your environment
cp .env.example .env

# 2. Edit .env and update these values:
#    - DOMAIN: your actual domain name
#    - CERT_PATH: path to your SSL certificates

# 3. Start the service
docker compose -f docker-compose.https.yml up -d

# View logs
docker logs pingmailer-api-server -f
```

The API will be available at `https://your-domain:8443/notify`

## API Usage

### Authentication Flow

Before making API requests, you need to:

1. **Obtain an application access token** from your OAuth2 server using your preferred OAuth2 flow (client credentials, authorization code, etc.)

2. **Use the access token** in your API requests:

```bash
curl -X POST https://your-domain:8443/notify \
  -H "Authorization: Bearer <access_token>" \
  -H "Content-Type: application/json" \
  -d '{...}'
```

See [AUTH.md](AUTH.md) for complete authentication details and examples.

### Send Email

**Endpoint:** `POST /notify`

**Authentication:** Required (Bearer token)

**Example Request:**

```bash
# First obtain an access token from your OAuth2 server
# (example assumes you already have a token)
TOKEN="your-access-token"

# Then send notification
curl -X POST https://your-domain:8443/notify \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "smtp_host": "smtp-server-container",
    "smtp_port": 587,
    "smtp_username": "user@yourdomain.com",
    "smtp_password": "your-password",
    "smtp_sender": "noreply@yourdomain.com",
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

### Health Check

**Endpoint:** `GET /health`

**Authentication:** Not required

**Example:**

```bash
curl https://your-domain:8443/health
```

### Required Fields

| Field | Type | Description |
|-------|------|-------------|
| `smtp_host` | string | SMTP server hostname |
| `smtp_port` | integer | SMTP server port (587 for TLS) |
| `smtp_username` | string | SMTP authentication username |
| `smtp_password` | string | SMTP authentication password |
| `smtp_sender` | string | Sender email address |
| `recipient_email` | string | Recipient's email address |

### Optional Fields

| Field | Type | Default | Description |
|-------|------|---------|-------------|
| `recipient_name` | string | "User" | Recipient's name |
| `app_name` | string | "Application" | Application name for email template |
| `template` | string | - | Custom email template |
| `template_data` | object | - | Data for custom template |

## Custom Templates

You can use custom email templates by providing the `template` and `template_data` fields.

### Template Format

Templates use Go's `text/template` syntax with three parts:

```go
{{define "subject"}}Your Subject Here{{end}}

{{define "plainBody"}}
Plain text version of your email
{{end}}

{{define "htmlBody"}}
<!doctype html>
<html>
<body>
HTML version of your email
</body>
</html>
{{end}}
```

### Template Variables

Access custom data in your template using `{{.FieldName}}`:

```bash
curl -X POST https://your-domain:8443/notify \
  -H "Content-Type: application/json" \
  -d '{
    "smtp_host": "smtp-server",
    "smtp_port": 587,
    "smtp_username": "user@domain.com",
    "smtp_password": "password",
    "smtp_sender": "noreply@domain.com",
    "recipient_email": "user@example.com",
    "template": "{{define \"subject\"}}Password Reset{{end}}{{define \"plainBody\"}}Hi {{.Name}}, your code is {{.Code}}{{end}}{{define \"htmlBody\"}}<p>Hi {{.Name}}, your code is <strong>{{.Code}}</strong></p>{{end}}",
    "template_data": {
      "Name": "John",
      "Code": "123456"
    }
  }'
```

## API Responses

### Success Response

**Status:** `200 OK`

```json
{
  "message": "Email sent successfully"
}
```

### Error Responses

**Status:** `400 Bad Request` - Invalid request data

```json
{
  "error": "invalid request data: missing required field"
}
```

**Status:** `500 Internal Server Error` - Email sending failed

```json
{
  "error": "failed to send email: connection timeout"
}
```

## Development

### Running Locally

The server requires the OAuth2 introspection URL to start:

```bash
# Set OAuth2 introspection URL
export OAUTH2_INTROSPECT_URL="https://localhost:8090/oauth2/introspect"

# Run with HTTP (default port 8080)
go run . \
  -oauth2-introspect-url "$OAUTH2_INTROSPECT_URL"

# Run with HTTPS
go run . \
  -cert /path/to/cert.pem \
  -key /path/to/key.pem \
  -oauth2-introspect-url "$OAUTH2_INTROSPECT_URL"

# Build binary
make build
```

### Command-line Flags

| Flag | Default | Description |
|------|---------|-------------|
| `-port` | 8080 | API server port |
| `-version` | 0.1.0 | Application version |
| `-cert` | - | Path to TLS certificate file |
| `-key` | - | Path to TLS key file |
| `-oauth2-introspect-url` | - | OAuth2 token introspection endpoint (required) |

### Example Scripts

See the `examples/` directory for usage examples:

- `test-auth.sh` - Bash script demonstrating the complete authentication flow
- `client.py` - Python client library with dual authentication

```bash
# Run bash example
cd examples
chmod +x test-auth.sh
./test-auth.sh

# Run Python example
pip install requests
python client.py
```

### Docker Commands

```bash
# Build image
make docker-build

# Run with HTTP
make docker-run

# Run with HTTPS
make docker-run-https DOMAIN=yourdomain.com

# View logs
make docker-logs

# Stop and remove container
make docker-stop
```
