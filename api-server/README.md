# PingMailer API

A generic Go API service for sending emails via SMTP. This service allows clients to send emails by providing their own SMTP configuration, recipient details, and optional custom email templates through a RESTful API.

## Features

- ✉️ Send emails via any SMTP server
- 🔧 Fully configurable via API requests (no hardcoded credentials)
- 📝 Support for custom email templates
- 🎨 HTML and plain text email formats
- 🚀 Stateless design - perfect for microservices
- 🔒 HTTPS/TLS support with Let's Encrypt certificates
- 🐳 Docker support for easy deployment

## Quick Links

- [Docker Deployment Guide](DOCKER.md) - Complete Docker deployment instructions
- [API Documentation](#api-usage) - API endpoint details

## Running the Server

You can run the server in three ways:
1. **Directly with Go** (for development)
2. **With Docker** (recommended for production)
3. **With Docker Compose** (easiest for production)

### Method 1: Direct Go Execution

#### HTTP Mode (Development)

Start the server in HTTP mode with:

```sh
make
```

Or manually:

```sh
go run .
```

By default, the server runs on port 8080. You can change this with the `-port` flag:

```sh
go run . -port 3000
```

### HTTPS Mode (Production)

To run the server with HTTPS using TLS certificates from Let's Encrypt (certbot):

```sh
make run-https
```

Or manually with custom certificate paths:

```sh
go run . -port 8443 \
  -cert /path/to/fullchain.pem \
  -key /path/to/privkey.pem
```

Or using the provided startup script:

```sh
# Set your domain name and run
DOMAIN=yourdomain.com ./run-https.sh

# Or export the domain and port as environment variables
export DOMAIN=yourdomain.com
export PORT=8443
./run-https.sh
```

For the mail infrastructure setup, certificates are typically located at:
```
../mail-infra/services/silver-config/certbot/keys/etc/live/yourdomain.com/
```

Replace `yourdomain.com` with your actual domain name.

**Note:** Make sure to update the Makefile or set the DOMAIN environment variable with your actual domain name before running in HTTPS mode.

### Method 2: Docker

#### Build Docker Image

```sh
make docker-build
# or
docker build -t pingmailer-api .
```

#### Run with Docker (HTTP)

```sh
make docker-run
# or
docker run -d -p 8080:8080 --name pingmailer-api pingmailer-api
```

#### Run with Docker (HTTPS)

```sh
# Update yourdomain.com with your actual domain in the Makefile first
make docker-run-https

# Or manually
docker run -d \
  -p 8443:8443 \
  -e PORT=8443 \
  -e CERT_FILE=/certs/fullchain.pem \
  -e KEY_FILE=/certs/privkey.pem \
  -v $(pwd)/../mail-infra/services/silver-config/certbot/keys/etc/live/aravindahwk.org:/certs:ro \
  --name pingmailer-api \
  pingmailer-api
```

### Method 3: Docker Compose (Recommended for Production)

#### HTTP Mode

```sh
docker-compose up -d
```

#### HTTPS Mode

```sh
# 1. Update domain in docker-compose.https.yml
sed -i 's/yourdomain.com/aravindahwk.org/g' docker-compose.https.yml

# 2. Create network if needed
docker network create mail-network

# 3. Start the service
docker-compose -f docker-compose.https.yml up -d

# Or use make
make docker-compose-https
```

#### View Logs

```sh
docker-compose logs -f
# or
make docker-logs
```

For complete Docker documentation, see [DOCKER.md](DOCKER.md).

## API Usage

### Endpoint

**HTTP (Development):**
```
POST http://localhost:8080/notify
```

**HTTPS (Production):**
```
POST https://yourdomain.com:8443/notify
```

Replace `yourdomain.com` and port number with your actual domain and configured port.

### Request Body

The API accepts a JSON payload with the following fields:

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `smtp_host` | string | ✅ Yes | SMTP server hostname (e.g., "smtp.gmail.com") |
| `smtp_port` | integer | ✅ Yes | SMTP server port (e.g., 587 for TLS) |
| `smtp_username` | string | ✅ Yes | SMTP authentication username |
| `smtp_password` | string | ✅ Yes | SMTP authentication password |
| `smtp_sender` | string | ✅ Yes | Sender email address |
| `recipient_email` | string | ✅ Yes | Recipient's email address |
| `recipient_name` | string | No | Recipient's name (defaults to "User") |
| `app_name` | string | No | Application name (defaults to "Application") |
| `template` | string | No | Custom email template (see Template Format below) |
| `template_data` | object | No | Custom data for template rendering |

### Example 1: Using Default Template

```sh
curl -X POST "http://localhost:8080/notify" \
  -H "Content-Type: application/json" \
  -d '{
    "smtp_host": "smtp.example.com",
    "smtp_port": 587,
    "smtp_username": "user@example.com",
    "smtp_password": "your-password",
    "smtp_sender": "noreply@example.com",
    "recipient_email": "recipient@example.com",
    "recipient_name": "John Doe",
    "app_name": "MyAwesomeApp"
  }'
```

### Example 2: Using Custom Template with Default Data

```sh
curl -X POST "http://localhost:8080/notify" \
  -H "Content-Type: application/json" \
  -d '{
    "smtp_host": "smtp.example.com",
    "smtp_port": 587,
    "smtp_username": "user@example.com",
    "smtp_password": "your-password",
    "smtp_sender": "noreply@example.com",
    "recipient_email": "john@example.com",
    "recipient_name": "John Doe",
    "app_name": "MyApp",
    "template": "{{define \"subject\"}}Welcome to {{.APP}}!{{end}}\n\n{{define \"plainBody\"}}Hi {{.Name}},\n\nThank you for joining {{.APP}}. We are excited to have you!\n\nBest regards,\nThe Team{{end}}\n\n{{define \"htmlBody\"}}<!DOCTYPE html><html><body><h1>Welcome {{.Name}}!</h1><p>Thank you for joining {{.APP}}.</p><p>Best regards,<br>The Team</p></body></html>{{end}}"
  }'
```

### Example 3: Using Custom Template with Custom Data

```sh
curl -X POST "http://localhost:8080/notify" \
  -H "Content-Type: application/json" \
  -d '{
    "smtp_host": "smtp.example.com",
    "smtp_port": 587,
    "smtp_username": "user@example.com",
    "smtp_password": "your-password",
    "smtp_sender": "orders@example.com",
    "recipient_email": "customer@example.com",
    "template": "{{define \"subject\"}}Order #{{.OrderID}} Confirmed{{end}}\n\n{{define \"plainBody\"}}Dear {{.CustomerName}},\n\nYour order #{{.OrderID}} has been confirmed!\n\nOrder Details:\n- Product: {{.ProductName}}\n- Quantity: {{.Quantity}}\n- Total: ${{.Total}}\n\nThank you for your purchase!{{end}}\n\n{{define \"htmlBody\"}}<!DOCTYPE html><html><body><h1>Order Confirmed!</h1><p>Dear {{.CustomerName}},</p><p>Your order #{{.OrderID}} has been confirmed!</p><h2>Order Details:</h2><ul><li>Product: {{.ProductName}}</li><li>Quantity: {{.Quantity}}</li><li>Total: ${{.Total}}</li></ul><p>Thank you for your purchase!</p></body></html>{{end}}",
    "template_data": {
      "OrderID": "12345",
      "CustomerName": "Jane Smith",
      "ProductName": "Widget Pro",
      "Quantity": "2",
      "Total": "49.99"
    }
  }'
```

## Template Format

Email templates must define three Go template blocks:

1. **`subject`** - The email subject line
2. **`plainBody`** - Plain text version of the email
3. **`htmlBody`** - HTML version of the email

### Template Variables

When using the default template (without `template_data`), these variables are available:

- `{{.Name}}` - Recipient's name
- `{{.Email}}` - Recipient's email
- `{{.APP}}` - Application name

When using custom `template_data`, any fields you provide in the JSON object will be available as template variables.

### Default Template

The default welcome template is located at `internal/emailer/templates/welcome.tmpl`:

```go
{{define "subject"}}Welcome to {{.APP}}!{{end}}

{{define "plainBody"}}
Hi,
Thanks for signing up for a {{.APP}} account. We're excited to have you on board!
Thanks,
The {{.APP}} Team
{{end}}

{{define "htmlBody"}}
<!doctype html>
<html>
<head>
<meta name="viewport" content="width=device-width" />
<meta http-equiv="Content-Type" content="text/html; charset=UTF-8" />
</head>
<body>
<p>Hi,</p>
<p>Thanks for signing up for a {{.APP}} account. We're excited to have you on board!</p>
<p>Thanks,</p>
<p>The {{.APP}} Team</p>
</body>
</html>
{{end}}
```

## Response Codes

| Status Code | Description |
|-------------|-------------|
| 200 OK | Email sent successfully |
| 400 Bad Request | Invalid request body or missing required fields |
| 405 Method Not Allowed | Only POST requests are accepted |
| 500 Internal Server Error | Failed to send email (check SMTP credentials) |

## Project Structure

```
.
├── main.go                          # Server initialization
├── routes.go                        # Route definitions
├── handlers.go                      # Request handlers
├── internal/
│   └── emailer/
│       ├── emailer.go              # Email sending logic
│       └── templates/
│           └── welcome.tmpl        # Default email template
├── go.mod
├── go.sum
├── Makefile
└── README.md
```

## Notes

- The service is stateless - SMTP credentials are not stored and must be provided with each request
- Templates are embedded in the binary using `embed.FS` for the default template
- For production use with many templates, consider storing them in a database
- The SMTP connection timeout is set to 2 seconds
- Both HTML and plain text versions are sent (multipart email)

