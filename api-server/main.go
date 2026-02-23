package main

import (
	"flag"
	"log/slog"
	"net/http"
	"net/url"
	"os"
	"time"

	"github.com/Silver-Mail-Platform/pingmailer/internal/api"
)

func main() {
	var cfg api.Config
	flag.IntVar(&cfg.Port, "port", 8080, "API server port")
	flag.BoolVar(&cfg.Dev, "dev", false, "Development mode: bypass OAuth token validation")
	flag.StringVar(&cfg.Version, "version", "0.1.0", "Version")
	flag.StringVar(&cfg.CertFile, "cert", "", "Path to TLS certificate file (e.g., /path/to/fullchain.pem)")
	flag.StringVar(&cfg.KeyFile, "key", "", "Path to TLS key file (e.g., /path/to/privkey.pem)")
	flag.StringVar(&cfg.OAuth2.IntrospectURL, "oauth2-introspect-url", "", "OAuth2 token introspection endpoint URL")

	flag.Parse()

	logger := slog.New(slog.NewTextHandler(os.Stdout, nil))

	if cfg.Dev {
		logger.Warn("dev mode enabled: OAuth validation is disabled")
	} else {
		// Validate OAuth2 introspection URL
		if cfg.OAuth2.IntrospectURL == "" {
			logger.Error("OAuth2 introspection URL must be provided via -oauth2-introspect-url flag")
			os.Exit(1)
		}

		// Validate that the introspection URL is properly formatted and uses HTTP/S.
		introspectURL, err := url.Parse(cfg.OAuth2.IntrospectURL)
		if err != nil {
			logger.Error("invalid OAuth2 introspection URL", "error", err)
			os.Exit(1)
		}
        if introspectURL.Scheme != "https" {
            logger.Error("OAuth2 introspection URL must use https scheme")
            os.Exit(1)
        }
	}

	// Create a shared HTTP client for token introspection.
	httpClient := &http.Client{
		Timeout: 10 * time.Second,
	}
	app := api.New(cfg, logger, httpClient)

	err := app.Serve()
	if err != nil {
		logger.Error(err.Error())
		os.Exit(1)
	}
}
