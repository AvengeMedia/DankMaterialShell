package client

import (
	"fmt"
	"log"
)

// Roundtrip blocks until all pending request are processed by the server.
// It is the implementation of [wl_display_roundtrip].
//
// [wl_display_roundtrip]: https://wayland.freedesktop.org/docs/html/apb.html#Client-classwl__display_1ab60f38c2f80980ac84f347e932793390
func (i *Display) Roundtrip() error {
	callback, err := i.Sync()
	if err != nil {
		return fmt.Errorf("unable to get sync callback: %w", err)
	}
	defer func() {
		if err2 := callback.Destroy(); err2 != nil {
			log.Printf("unable to destroy callback: %v\n", err2)
		}
	}()

	done := false
	callback.SetDoneHandler(func(_ CallbackDoneEvent) {
		done = true
	})

	// Wait for callback to return
	for !done {
		err := i.Context().GetDispatch()()
		if err != nil {
			return fmt.Errorf("roundtrip: failed to dispatch: %w", err)
		}
	}

	return nil
}
