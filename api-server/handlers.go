package main

import (
	"encoding/json"
	"net/http"
	"net/mail"

	"github.com/maneeshaxyz/outgoing-email-example/internal/emailer"
)

type user struct {
	Name  string
	Email string
	APP   string
}

type notifyRequest struct {
	SMTPHost       string                 `json:"smtp_host"`
	SMTPPort       int                    `json:"smtp_port"`
	SMTPUsername   string                 `json:"smtp_username"`
	SMTPPassword   string                 `json:"smtp_password"`
	SMTPSender     string                 `json:"smtp_sender"`
	RecipientName  string                 `json:"recipient_name"`
	RecipientEmail string                 `json:"recipient_email"`
	AppName        string                 `json:"app_name"`
	Template       string                 `json:"template,omitempty"`        // Optional: custom template content
	TemplateData   map[string]interface{} `json:"template_data,omitempty"`   // Optional: custom template data
}

func (app *application) handleNotify(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodPost {
		w.Header().Set("Allow", http.MethodPost)
		http.Error(w, http.StatusText(http.StatusMethodNotAllowed), http.StatusMethodNotAllowed)
		return
	}

	var req notifyRequest
	err := json.NewDecoder(r.Body).Decode(&req)
	if err != nil {
		app.logger.Error("failed to decode request body", "error", err)
		http.Error(w, "Invalid request body: "+err.Error(), http.StatusBadRequest)
		return
	}

	// Validate required fields with specific error messages
	if req.SMTPHost == "" {
		http.Error(w, "Missing required field: smtp_host", http.StatusBadRequest)
		return
	}
	if req.SMTPPort == 0 {
		http.Error(w, "Missing required field: smtp_port", http.StatusBadRequest)
		return
	}
	if req.SMTPUsername == "" {
		http.Error(w, "Missing required field: smtp_username", http.StatusBadRequest)
		return
	}
	if req.SMTPPassword == "" {
		http.Error(w, "Missing required field: smtp_password", http.StatusBadRequest)
		return
	}
	if req.SMTPSender == "" {
		http.Error(w, "Missing required field: smtp_sender", http.StatusBadRequest)
		return
	}
	if req.RecipientEmail == "" {
		http.Error(w, "Missing required field: recipient_email", http.StatusBadRequest)
		return
	}

	// Validate email formats
	if _, err := mail.ParseAddress(req.SMTPSender); err != nil {
		http.Error(w, "Invalid smtp_sender email format: "+err.Error(), http.StatusBadRequest)
		return
	}
	if _, err := mail.ParseAddress(req.RecipientEmail); err != nil {
		http.Error(w, "Invalid recipient_email format: "+err.Error(), http.StatusBadRequest)
		return
	}

	// Set default values if not provided
	if req.RecipientName == "" {
		req.RecipientName = "User"
	}
	if req.AppName == "" {
		req.AppName = "Application"
	}

	// Create a new mailer instance with the provided SMTP configuration
	mailer := emailer.NewMailer(req.SMTPHost, req.SMTPPort, req.SMTPUsername, req.SMTPPassword, req.SMTPSender)

	// Use custom template if provided, otherwise use default template data
	if req.Template != "" {
		// If custom template is provided, use template_data if available, otherwise use default user data
		var templateData interface{}
		if len(req.TemplateData) > 0 {
			templateData = req.TemplateData
		} else {
			// Fallback to default user struct
			templateData = user{
				Name:  req.RecipientName,
				Email: req.RecipientEmail,
				APP:   req.AppName,
			}
		}
		
		err = mailer.SendWithCustomTemplate(req.RecipientEmail, req.Template, templateData)
	} else {
		// Use default welcome template
		var usr = user{
			Name:  req.RecipientName,
			Email: req.RecipientEmail,
			APP:   req.AppName,
		}
		err = mailer.Send(usr.Email, "welcome.tmpl", usr)
	}
	
	if err != nil {
		app.logger.Error("failed to send email", "error", err)
		http.Error(w, "Failed to send email", http.StatusInternalServerError)
		return
	}

	w.WriteHeader(http.StatusOK)
	w.Write([]byte("Email sent successfully"))
}
