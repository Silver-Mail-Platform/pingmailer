package api

import "net/http"

func (app *App) routes() http.Handler {
	mux := http.NewServeMux()

	if app.config.Dev {
		// Development mode: bypass auth middleware.
		mux.HandleFunc("/notify", app.handleNotify)
	} else {
		// Protected endpoint - requires Bearer token authentication.
		mux.HandleFunc("/notify", app.authMiddleware(app.handleNotify))
	}

	// Health check endpoint (unprotected)
	mux.HandleFunc("/health", app.handleHealth)

	return mux
}
