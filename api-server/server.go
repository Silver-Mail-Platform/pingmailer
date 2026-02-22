package main

import (
	"context"
	"errors"
	"fmt"
	"log/slog"
	"net/http"
	"os"
	"os/signal"
	"syscall"
	"time"
)

func (app *application) serve() error {
	srv := &http.Server{
		Addr:         fmt.Sprintf(":%d", app.config.port),
		Handler:      app.routes(),
		IdleTimeout:  time.Minute,
		ReadTimeout:  10 * time.Second,
		WriteTimeout: 30 * time.Second,
		ErrorLog:     slog.NewLogLogger(app.logger.Handler(), slog.LevelError),
	}

	shutdownError := make(chan error, 1)

	//  background goroutine that catches signals.
	go func() {
		quit := make(chan os.Signal, 1)
		signal.Notify(quit, syscall.SIGINT, syscall.SIGTERM)
		s := <-quit
		app.logger.Info("shutting down server", "signal", s.String())
		ctx, cancel := context.WithTimeout(context.Background(), 30*time.Second)
		defer cancel()
		shutdownError <- srv.Shutdown(ctx)
	}()

	var err error
	if app.config.certFile != "" || app.config.keyFile != "" {
		if app.config.certFile == "" || app.config.keyFile == "" {
			return errors.New("for HTTPS, both certificate and key files must be provided")
		}
		app.logger.Info("starting HTTPS server", "addr", srv.Addr, "version", app.config.version, "cert", app.config.certFile, "key", app.config.keyFile)
		err = srv.ListenAndServeTLS(app.config.certFile, app.config.keyFile)
	} else {
		app.logger.Info("starting HTTP server", "addr", srv.Addr, "version", app.config.version)
		err = srv.ListenAndServe()
	}

	if !errors.Is(err, http.ErrServerClosed) {
		return err
	}

	err = <-shutdownError
	if err != nil {
		return err
	}

	app.logger.Info("stopped server", "addr", srv.Addr)
	return nil
}
