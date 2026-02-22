package main

import (
	"flag"
	"log/slog"
	"net/http"
	"net/url"
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

	// Validate that the introspection URL is properly formatted and uses HTTPS
	introspectURL, err := url.Parse(cfg.oauth2.IntrospectURL)
	if err != nil {
		logger.Error("invalid OAuth2 introspection URL", "error", err)
		os.Exit(1)
	}
	if introspectURL.Scheme != "http" && introspectURL.Scheme != "https" {
		logger.Error("OAuth2 introspection URL must use http or https scheme")
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

	err = app.serve()
	if err != nil {
		logger.Error(err.Error())
		os.Exit(1)
	}
}
