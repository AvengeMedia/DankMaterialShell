package server

import "sync"

func forwardSubscription[T any](wg *sync.WaitGroup, events chan<- ServiceEvent, stop <-chan struct{}, service string, source <-chan T, release func(), snapshot func() T) {
	wg.Go(func() {
		defer release()

		if snapshot != nil {
			state := snapshot()
			select {
			case events <- ServiceEvent{Service: service, Data: state}:
			case <-stop:
				return
			}
		}

		for {
			select {
			case value, ok := <-source:
				if !ok {
					return
				}
				select {
				case events <- ServiceEvent{Service: service, Data: value}:
				case <-stop:
					return
				}
			case <-stop:
				return
			}
		}
	})
}
