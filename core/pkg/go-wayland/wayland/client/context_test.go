package client_test

import (
	"errors"
	"fmt"
	"log"

	"github.com/AvengeMedia/DankMaterialShell/core/pkg/go-wayland/wayland/client"
)

// Shows a dispatch loop that will block the goroutine.
// This approach has no risk of data races but the loop blocks the goroutine when no messages are
// received. This can be a valid approach if there are no more changes that need to be made after
// setting up and starting the loop.
// For a multi goroutine approach, use [client.Context.GetDispatch].
func ExampleContext_Dispatch() {
	display, err := client.Connect("")
	if err != nil {
		log.Fatalf("Error connecting to Wayland server: %v", err)
	}

	registry, err := display.GetRegistry()
	if err != nil {
		log.Fatalf("Error getting Wayland registry: %v", err)
	}

	var seat *client.Seat
	registry.SetGlobalHandler(func(e client.RegistryGlobalEvent) {
		switch e.Interface {
		case client.SeatInterfaceName:
			seat = client.NewSeat(display.Context())
			err := registry.Bind(e.Name, e.Interface, e.Version, seat)
			if err != nil {
				log.Fatalf("unable to bind %s interface: %v", client.SeatInterfaceName, err)
			}
		}
	})
	display.Roundtrip()
	display.Roundtrip()

	keyboard, err := seat.GetKeyboard()
	if err != nil {
		log.Printf("Error getting keyboard: %v", err)
	}
	log.Printf("Got keyboard: %v\n", keyboard)

	for {
		err := display.Context().Dispatch()
		if err != nil {
			log.Printf("Dispatch error: %v\n", err)
		}
	}
}

// Shows how the dispatch loop can be done in another goroutine.
// This prevents the goroutine from being blocked and allows making changes to wayland objects while
// the dispatch loop is blocking another goroutine.
func ExampleContext_GetDispatch() {
	display, err := client.Connect("")
	if err != nil {
		log.Fatalf("Error connecting to Wayland server: %v", err)
	}

	registry, err := display.GetRegistry()
	if err != nil {
		log.Fatalf("Error getting Wayland registry: %v", err)
	}

	var seat *client.Seat
	registry.SetGlobalHandler(func(e client.RegistryGlobalEvent) {
		switch e.Interface {
		case client.SeatInterfaceName:
			seat = client.NewSeat(display.Context())
			err := registry.Bind(e.Name, e.Interface, e.Version, seat)
			if err != nil {
				log.Fatalf("unable to bind %s interface: %v", client.SeatInterfaceName, err)
			}
		}
	})
	display.Roundtrip()
	display.Roundtrip()
	dispatchQueue := make(chan func() error)

	go func() {
		for {
			dispatchQueue <- display.Context().GetDispatch()
		}
	}()

	keyboard, err := seat.GetKeyboard()
	if err != nil {
		log.Printf("Error getting keyboard: %v", err)
	}
	log.Printf("Got keyboard: %v\n", keyboard)

	err = errors.Join(keyboard.Release(), seat.Release(), display.Context().Close())
	if err != nil {
		fmt.Printf("Error cleaning up: %v\n", err)
	}

	for {
		select {
		// Add other cases here to do other things
		case dispatchFunc := <-dispatchQueue:
			err := dispatchFunc()
			if err != nil {
				log.Printf("Dispatch error: %v\n", err)
			}
		}
	}
}
