package main

import (
	"encoding/json"
	"log"
	"net/http"
	"net/mail"

	"github.com/Silver-Mail-Platform/pingmailer/internal/emailer"
)

type user struct {
	Name  string
	Email string
	APP   string
}

type notifyRequest struct {
	SMTPHost       string         `json:"smtp_host"`
	SMTPPort       int            `json:"smtp_port"`
	SMTPUsername   string         `json:"smtp_username"`
	SMTPPassword   string         `json:"smtp_password"`
	SMTPSender     string         `json:"smtp_sender"`
	RecipientName  string         `json:"recipient_name"`
	RecipientEmail string         `json:"recipient_email"`
	AppName        string         `json:"app_name"`
	Template       string         `json:"template,omitempty"`      // Optional: custom template content
	TemplateData   map[string]any `json:"template_data,omitempty"` // Optional: custom template data
}

func (app *application) handleNotify(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodPost {
		w.Header().Set("Allow", http.MethodPost)
		http.Error(w, http.StatusText(http.StatusMethodNotAllowed), http.StatusMethodNotAllowed)
		return
	}

	req, err := decodeNotifyRequest(r)
	if err != nil {
		app.logger.Error("failed to decode request body", "error", err)
		http.Error(w, "Invalid request body: "+err.Error(), http.StatusBadRequest)
		return
	}

	if !validateNotifyRequest(w, req) {
		return
	}
	applyNotifyDefaults(&req)

	// Create a new mailer instance with the provided SMTP configuration
	mailer := emailer.NewMailer(req.SMTPHost, req.SMTPPort, req.SMTPUsername, req.SMTPPassword, req.SMTPSender)

	defaultUser := buildDefaultUser(req)

	err = sendNotifyEmail(mailer, req, defaultUser)

	if err != nil {
		app.logger.Error("failed to send email", "error", err)
		http.Error(w, "Failed to send email", http.StatusInternalServerError)
		return
	}

	w.WriteHeader(http.StatusOK)
	_, err = w.Write([]byte("Email sent successfully"))

	if err != nil {
		log.Println("Error in handleNotify, error in writing header.")
	}
}

func decodeNotifyRequest(r *http.Request) (notifyRequest, error) {
	var req notifyRequest
	err := json.NewDecoder(r.Body).Decode(&req)
	return req, err
}

func validateNotifyRequest(w http.ResponseWriter, req notifyRequest) bool {
	required := func(ok bool, message string) bool {
		if ok {
			return true
		}
		http.Error(w, message, http.StatusBadRequest)
		return false
	}
	if !required(req.SMTPHost != "", "Missing required field: smtp_host") {
		return false
	}
	if !required(req.SMTPPort != 0, "Missing required field: smtp_port") {
		return false
	}
	if !required(req.SMTPUsername != "", "Missing required field: smtp_username") {
		return false
	}
	if !required(req.SMTPPassword != "", "Missing required field: smtp_password") {
		return false
	}
	if !required(req.SMTPSender != "", "Missing required field: smtp_sender") {
		return false
	}
	if !required(req.RecipientEmail != "", "Missing required field: recipient_email") {
		return false
	}

	if _, err := mail.ParseAddress(req.SMTPSender); err != nil {
		http.Error(w, "Invalid smtp_sender email format: "+err.Error(), http.StatusBadRequest)
		return false
	}
	if _, err := mail.ParseAddress(req.RecipientEmail); err != nil {
		http.Error(w, "Invalid recipient_email format: "+err.Error(), http.StatusBadRequest)
		return false
	}

	return true
}

func applyNotifyDefaults(req *notifyRequest) {
	if req.RecipientName == "" {
		req.RecipientName = "User"
	}
	if req.AppName == "" {
		req.AppName = "Application"
	}
}

func buildDefaultUser(req notifyRequest) user {
	return user{
		Name:  req.RecipientName,
		Email: req.RecipientEmail,
		APP:   req.AppName,
	}
}

func sendNotifyEmail(mailer emailer.Mailer, req notifyRequest, defaultUser user) error {
	if req.Template == "" {
		return mailer.Send(defaultUser.Email, "welcome.tmpl", defaultUser)
	}

	templateData := any(defaultUser)
	if len(req.TemplateData) > 0 {
		templateData = req.TemplateData
	}
	return mailer.SendWithCustomTemplate(req.RecipientEmail, req.Template, templateData)
}
