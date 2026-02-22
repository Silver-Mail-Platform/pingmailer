package api

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

func (app *App) Serve() error {
	srv := &http.Server{
		Addr:         fmt.Sprintf(":%d", app.config.Port),
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
	if app.config.CertFile != "" || app.config.KeyFile != "" {
		if app.config.CertFile == "" || app.config.KeyFile == "" {
			return errors.New("for HTTPS, both certificate and key files must be provided")
		}
		app.logger.Info("starting HTTPS server", "addr", srv.Addr, "version", app.config.Version, "cert", app.config.CertFile, "key", app.config.KeyFile)
		err = srv.ListenAndServeTLS(app.config.CertFile, app.config.KeyFile)
	} else {
		app.logger.Info("starting HTTP server", "addr", srv.Addr, "version", app.config.Version)
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
