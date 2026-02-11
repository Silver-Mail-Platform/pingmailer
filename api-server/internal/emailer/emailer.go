package emailer

import (
	"bytes"
	"embed"
	"html/template"
	"time"

	"github.com/go-mail/mail/v2"
)

// templateFS holds the embedded email templates.
//
//go:embed "templates"
var templateFS embed.FS

// Mailer handles email delivery using SMTP and embedded templates.
type Mailer struct {
	dialer *mail.Dialer
	sender string
}

// New returns a new Mailer instance configured with the provided SMTP settings
// and a default 2-second connection timeout.
func NewMailer(host string, port int, username, password, sender string) Mailer {
	dialer := mail.NewDialer(host, port, username, password)
	dialer.Timeout = 2 * time.Second
	return Mailer{
		dialer: dialer,
		sender: sender,
	}
}

// Send renders the specified template with the provided data and delivers
// the email to the recipient. The template file must define "subject",
// "plainBody", and "htmlBody" blocks.
func (m Mailer) Send(recipient, templateFile string, data any) error {
	tmpl, err := template.New("email").ParseFS(templateFS, "templates/"+templateFile)
	if err != nil {
		return err
	}
	return m.send(recipient, tmpl, data)
}

// SendWithCustomTemplate renders a custom template string with the provided data
// and delivers the email to the recipient. The template must define "subject",
// "plainBody", and "htmlBody" blocks.
func (m Mailer) SendWithCustomTemplate(recipient, templateContent string, data any) error {
	tmpl, err := template.New("email").Parse(templateContent)
	if err != nil {
		return err
	}
	return m.send(recipient, tmpl, data)
}

// send is an internal method that handles the common email sending logic.
// It executes the template blocks and sends the email via SMTP.
func (m Mailer) send(recipient string, tmpl *template.Template, data any) error {
	subject := new(bytes.Buffer)
	err := tmpl.ExecuteTemplate(subject, "subject", data)
	if err != nil {
		return err
	}

	plainBody := new(bytes.Buffer)
	err = tmpl.ExecuteTemplate(plainBody, "plainBody", data)
	if err != nil {
		return err
	}

	htmlBody := new(bytes.Buffer)
	err = tmpl.ExecuteTemplate(htmlBody, "htmlBody", data)
	if err != nil {
		return err
	}

	msg := mail.NewMessage()
	msg.SetHeader("To", recipient)
	msg.SetHeader("From", m.sender)
	msg.SetHeader("Subject", subject.String())
	msg.SetBody("text/plain", plainBody.String())
	msg.AddAlternative("text/html", htmlBody.String())

	// retry sending mail logic
	const maxRetries = 3
	const retrySleep = 500 * time.Millisecond

	for i := range maxRetries {
		err = m.dialer.DialAndSend(msg)
		if err == nil {
			return nil
		}

		if i < maxRetries-1 {
			time.Sleep(retrySleep)
		}
	}
	return err
}
