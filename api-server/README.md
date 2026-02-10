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
