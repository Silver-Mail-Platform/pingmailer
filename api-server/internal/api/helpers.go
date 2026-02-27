package api

import "fmt"

func (app *App) background(fn func()) {
	// Launch a background goroutine.
	go func() {
		// Recover any panic.
		defer func() {
			if err := recover(); err != nil {
				app.logger.Error(fmt.Sprintf("%v", err))
			}
		}()
		// Execute the arbitrary function that we passed as the parameter.
		fn()
	}()
}
