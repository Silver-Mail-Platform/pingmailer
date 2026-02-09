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
	port    int
	version string
}

func main() {
	var cfg config
	flag.IntVar(&cfg.port, "port", 8080, "API server port")

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

	logger.Info("starting server", "addr", srv.Addr, "version", cfg.version)

	err := srv.ListenAndServe()
	logger.Error(err.Error())
	os.Exit(1)
}
