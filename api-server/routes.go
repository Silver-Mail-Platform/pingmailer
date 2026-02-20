package main

import "net/http"

func (app *application) routes() http.Handler {
	mux := http.NewServeMux()
	
	// Protected endpoint - requires Bearer token authentication
	mux.HandleFunc("/notify", app.authMiddleware(app.handleNotify))
	
	// Health check endpoint (unprotected)
	mux.HandleFunc("/health", app.handleHealth)
	
	return mux
}
