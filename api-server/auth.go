package main

import (
	"encoding/json"
	"fmt"
	"io"
	"net/http"
	"strings"
	"time"
)

// OAuth2Config holds the OAuth2 server configuration
type OAuth2Config struct {
	TokenURL     string
	ClientID     string
	ClientSecret string
}

// TokenResponse represents the OAuth2 token response
type TokenResponse struct {
	AccessToken string `json:"access_token"`
	TokenType   string `json:"token_type"`
	ExpiresIn   int    `json:"expires_in"`
	Scope       string `json:"scope,omitempty"`
}

// TokenCache holds cached access tokens with expiration
type TokenCache struct {
	Token     string
	ExpiresAt time.Time
}

var tokenCache *TokenCache

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

// validateAccessToken validates the provided access token against the OAuth2 server
func (app *application) validateAccessToken(token string) error {
	// Get a valid application token from cache or fetch a new one
	appToken, err := app.getApplicationToken()
	if err != nil {
		return fmt.Errorf("failed to get application token: %w", err)
	}

	// Compare the provided token with the valid application token
	if token != appToken {
		return fmt.Errorf("invalid access token")
	}

	return nil
}

// getApplicationToken retrieves a valid application token from cache or fetches a new one
func (app *application) getApplicationToken() (string, error) {
	// Check if we have a valid cached token
	if tokenCache != nil && time.Now().Before(tokenCache.ExpiresAt) {
		return tokenCache.Token, nil
	}

	// Fetch a new token
	token, err := app.fetchApplicationToken()
	if err != nil {
		return "", err
	}

	return token, nil
}

// fetchApplicationToken fetches a new application access token from the OAuth2 server
func (app *application) fetchApplicationToken() (string, error) {
	client := &http.Client{
		Timeout: 10 * time.Second,
	}

	// Create the request body
	body := strings.NewReader("grant_type=client_credentials")

	req, err := http.NewRequest("POST", app.config.oauth2.TokenURL, body)
	if err != nil {
		return "", fmt.Errorf("failed to create token request: %w", err)
	}

	// Set Basic Auth with client credentials
	req.SetBasicAuth(app.config.oauth2.ClientID, app.config.oauth2.ClientSecret)
	req.Header.Set("Content-Type", "application/x-www-form-urlencoded")

	resp, err := client.Do(req)
	if err != nil {
		return "", fmt.Errorf("failed to request token: %w", err)
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusOK {
		bodyBytes, _ := io.ReadAll(resp.Body)
		return "", fmt.Errorf("token request failed with status %d: %s", resp.StatusCode, string(bodyBytes))
	}

	var tokenResp TokenResponse
	if err := json.NewDecoder(resp.Body).Decode(&tokenResp); err != nil {
		return "", fmt.Errorf("failed to decode token response: %w", err)
	}

	// Cache the token with a buffer before expiration (90% of the actual expiration time)
	expiresIn := time.Duration(tokenResp.ExpiresIn) * time.Second
	bufferTime := expiresIn * 9 / 10 // 90% of expiration time
	tokenCache = &TokenCache{
		Token:     tokenResp.AccessToken,
		ExpiresAt: time.Now().Add(bufferTime),
	}

	app.logger.Info("fetched new application access token", "expires_in", tokenResp.ExpiresIn)

	return tokenResp.AccessToken, nil
}

// authMiddleware validates the Bearer token before allowing access to protected endpoints
func (app *application) authMiddleware(next http.HandlerFunc) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		token, err := extractBearerToken(r)
		if err != nil {
			app.logger.Warn("authentication failed", "error", err)
			http.Error(w, "Unauthorized: "+err.Error(), http.StatusUnauthorized)
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
