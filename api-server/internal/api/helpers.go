package api

import "fmt"

func (app *App) background(fn func()) {
	app.wg.Add(1)
	// Launch a background goroutine.
	go func() {
		// defer to decrement the WaitGroup counter before the goroutine returns.
		defer app.wg.Done()
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
