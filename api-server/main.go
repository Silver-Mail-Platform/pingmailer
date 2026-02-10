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
	config config
	logger *slog.Logger
}

type config struct {
	port     int
	version  string
	certFile string
	keyFile  string
}

func main() {
	var cfg config
	flag.IntVar(&cfg.port, "port", 8080, "API server port")
	flag.StringVar(&cfg.certFile, "cert", "", "Path to TLS certificate file (e.g., /path/to/fullchain.pem)")
	flag.StringVar(&cfg.keyFile, "key", "", "Path to TLS key file (e.g., /path/to/privkey.pem)")

	flag.Parse()

	logger := slog.New(slog.NewTextHandler(os.Stdout, nil))

	app := &application{
		config: cfg,
		logger: logger,
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
	if cfg.certFile != "" && cfg.keyFile != "" {
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
