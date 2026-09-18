package server

import (
	"sync"
	"testing"
	"testing/synctest"

	"github.com/stretchr/testify/require"
)

func TestForwardSubscriptionOrder(t *testing.T) {
	source := make(chan int, 2)
	source <- 2
	events := make(chan ServiceEvent, 3)
	var wg sync.WaitGroup
	releases := 0
	forwardSubscription(&wg, events, nil, "state", source, func() {
		releases++
	}, func() int {
		source <- 3
		close(source)
		return 1
	})
	wg.Wait()
	require.Equal(t, 1, releases)
	require.Equal(t, 3, len(events))
	for _, value := range []int{1, 2, 3} {
		require.Equal(t, ServiceEvent{Service: "state", Data: value}, <-events)
	}
}

func TestForwardSubscriptionEvents(t *testing.T) {
	source := make(chan string, 2)
	source <- "first"
	source <- "second"
	close(source)
	events := make(chan ServiceEvent, 2)
	var wg sync.WaitGroup
	releases := 0
	forwardSubscription(&wg, events, nil, "event", source, func() {
		releases++
	}, nil)
	wg.Wait()
	require.Equal(t, 1, releases)
	require.Equal(t, 2, len(events))
	for _, value := range []string{"first", "second"} {
		require.Equal(t, ServiceEvent{Service: "event", Data: value}, <-events)
	}
}

func TestForwardSubscriptionStop(t *testing.T) {
	for _, blocked := range []string{"source", "snapshot", "event"} {
		t.Run(blocked, func(t *testing.T) {
			synctest.Test(t, func(t *testing.T) {
				source := make(chan int, 1)
				events := make(chan ServiceEvent, 1)
				events <- ServiceEvent{Service: "full"}
				stop := make(chan struct{})
				var snapshot func() int
				switch blocked {
				case "snapshot":
					snapshot = func() int { return 1 }
				case "event":
					source <- 1
				}
				var wg sync.WaitGroup
				releases := 0
				forwardSubscription(&wg, events, stop, "state", source, func() {
					releases++
				}, snapshot)
				synctest.Wait()
				require.Empty(t, source)
				require.Zero(t, releases)
				close(stop)
				wg.Wait()
				require.Equal(t, 1, releases)
				require.Equal(t, ServiceEvent{Service: "full"}, <-events)
				require.Empty(t, events)
			})
		})
	}
}
