# outgoing-email-example

A generic Go API service for sending emails via SMTP. This service allows clients to send emails by providing their own SMTP configuration, recipient details, and optional custom email templates through a RESTful API.

## Features

- Send emails via any SMTP server
- Fully configurable via API requests (no hardcoded credentials)
- Support for custom email templates
- HTML and plain text email formats
- Stateless design

## Running the Server

```sh
go run .
```

By default, the server runs on port 8080. You can change this with the `-port` flag:

```sh
go run . -port 3000 # omit -port 3000 to run as default
```

Alternatively you can build from source with: 

```sh
make
```

## API Usage

### Endpoint

```
POST /notify
```

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
