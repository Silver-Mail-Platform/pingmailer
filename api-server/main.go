package main

import (
	"flag"
	"fmt"
	"log/slog"
	"net/http"
	"os"
	"time"
)

type application struct {
	config     config
	logger     *slog.Logger
	httpClient *http.Client
}

type config struct {
	port     int
	version  string
	certFile string
	keyFile  string
	oauth2   OAuth2Config
}

func main() {
	var cfg config
	flag.IntVar(&cfg.port, "port", 8080, "API server port")
	flag.StringVar(&cfg.version, "version", "0.1.0", "Version")
	flag.StringVar(&cfg.certFile, "cert", "", "Path to TLS certificate file (e.g., /path/to/fullchain.pem)")
	flag.StringVar(&cfg.keyFile, "key", "", "Path to TLS key file (e.g., /path/to/privkey.pem)")
	flag.StringVar(&cfg.oauth2.IntrospectURL, "oauth2-introspect-url", "", "OAuth2 token introspection endpoint URL")

	flag.Parse()

	logger := slog.New(slog.NewTextHandler(os.Stdout, nil))

	// Validate OAuth2 introspection URL
	if cfg.oauth2.IntrospectURL == "" {
		logger.Error("OAuth2 introspection URL must be provided via -oauth2-introspect-url flag")
		os.Exit(1)
	}

	// Create a shared HTTP client for token introspection
	httpClient := &http.Client{
		Timeout: 10 * time.Second,
	}

	app := &application{
		config:     cfg,
		logger:     logger,
		httpClient: httpClient,
	}

	srv := &http.Server{
		Addr:         fmt.Sprintf(":%d", cfg.port),
		Handler:      app.routes(),
		IdleTimeout:  time.Minute,
		ReadTimeout:  10 * time.Second,
		WriteTimeout: 30 * time.Second,
		ErrorLog:     slog.NewLogLogger(logger.Handler(), slog.LevelError),
	}

	// Check if both cert and key files are provided for HTTPS
	if cfg.certFile != "" || cfg.keyFile != "" {
		if cfg.certFile == "" || cfg.keyFile == "" {
			logger.Error("for HTTPS, both certificate and key files must be provided")
			os.Exit(1)
		}
		logger.Info("starting HTTPS server", "addr", srv.Addr, "version", cfg.version, "cert", cfg.certFile, "key", cfg.keyFile)
		err := srv.ListenAndServeTLS(cfg.certFile, cfg.keyFile)
		logger.Error(err.Error())
		os.Exit(1)
	}

	logger.Info("starting HTTP server", "addr", srv.Addr, "version", cfg.version)

	err := srv.ListenAndServe()
	logger.Error(err.Error())
	os.Exit(1)
}
