package api

import (
	"encoding/json"
	"fmt"
	"io"
	"net/http"
	"net/url"
	"strings"
	"time"
)

// IntrospectionResponse represents the OAuth2 token introspection response
type IntrospectionResponse struct {
	Active    bool   `json:"active"`
	ClientID  string `json:"client_id,omitempty"`
	TokenType string `json:"token_type,omitempty"`
	Exp       int64  `json:"exp,omitempty"`
	Iat       int64  `json:"iat,omitempty"`
	Nbf       int64  `json:"nbf,omitempty"`
	Sub       string `json:"sub,omitempty"`
	Aud       string `json:"aud,omitempty"`
	Iss       string `json:"iss,omitempty"`
	Jti       string `json:"jti,omitempty"`
}

// extractBearerToken extracts the Bearer token from the Authorization header
func extractBearerToken(r *http.Request) (string, error) {
	authHeader := r.Header.Get("Authorization")
	if authHeader == "" {
		return "", fmt.Errorf("missing Authorization header")
	}

	parts := strings.SplitN(authHeader, " ", 2)
	if len(parts) != 2 || strings.ToLower(parts[0]) != "bearer" {
		return "", fmt.Errorf("invalid Authorization header format, expected 'Bearer <token>'")
	}

	return parts[1], nil
}

// validateAccessToken validates the provided access token using OAuth2 token introspection
func (app *App) validateAccessToken(token string) error {
	// Create form data with the token
	data := url.Values{}
	data.Set("token", token)

	// #nosec G704 -- IntrospectURL is from server configuration, not user input
	req, err := http.NewRequest("POST", app.config.OAuth2.IntrospectURL, strings.NewReader(data.Encode()))
	if err != nil {
		return fmt.Errorf("failed to create introspection request: %w", err)
	}

	req.Header.Set("Content-Type", "application/x-www-form-urlencoded")

	// #nosec G704 -- IntrospectURL is from server configuration, validated at startup
	resp, err := app.httpClient.Do(req)
	if err != nil {
		return fmt.Errorf("failed to introspect token: %w", err)
	}
	defer func() {
		if closeErr := resp.Body.Close(); closeErr != nil {
			app.logger.Warn("failed to close response body", "error", closeErr)
		}
	}()

	if resp.StatusCode != http.StatusOK {
		bodyBytes, _ := io.ReadAll(resp.Body)
		return fmt.Errorf("introspection failed with status %d: %s", resp.StatusCode, string(bodyBytes))
	}

	var introspection IntrospectionResponse
	if err := json.NewDecoder(resp.Body).Decode(&introspection); err != nil {
		return fmt.Errorf("failed to decode introspection response: %w", err)
	}

	// Check if token is active
	if !introspection.Active {
		return fmt.Errorf("token is not active")
	}

	// Optionally validate additional claims
	if introspection.Exp > 0 && time.Now().Unix() > introspection.Exp {
		return fmt.Errorf("token has expired")
	}

	app.logger.Info("token validated successfully",
		"client_id", introspection.ClientID,
		"sub", introspection.Sub,
		"exp", introspection.Exp)

	return nil
}

// authMiddleware validates the Bearer token before allowing access to protected endpoints
func (app *App) authMiddleware(next http.HandlerFunc) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		token, err := extractBearerToken(r)
		if err != nil {
			app.logger.Warn("authentication failed", "error", err)
			http.Error(w, "Unauthorized: invalid authorization token", http.StatusUnauthorized)
			return
		}

		if err := app.validateAccessToken(token); err != nil {
			app.logger.Warn("token validation failed", "error", err)
			http.Error(w, "Unauthorized: invalid or expired token", http.StatusUnauthorized)
			return
		}

		next(w, r)
	}
}
