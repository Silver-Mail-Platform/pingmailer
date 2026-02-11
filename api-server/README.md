# PingMailer API Server

A simple REST API service for sending emails via SMTP. Part of the Silver Mail Platform.

## Quick Start

### Deploy with Docker Compose (Recommended)

```bash
# Update domain name in docker-compose.https.yml if needed
docker compose -f docker-compose.https.yml up -d

# View logs
docker logs pingmailer-api-server -f
```

The API will be available at `https://your-domain:8443/notify`

## API Usage

### Send Email

**Endpoint:** `POST /notify`

**Example Request:**

```bash
curl -X POST https://your-domain:8443/notify \
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

```bash
# Run with HTTP (default port 8080)
make run

# Run with HTTPS
make run-https DOMAIN=yourdomain.com

# Build binary
make build
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
