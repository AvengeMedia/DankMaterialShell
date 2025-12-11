package wlcontext

import (
	"sync"
	"testing"

	"github.com/stretchr/testify/assert"
)

func TestSharedContext_ConcurrentPostNonBlocking(t *testing.T) {
	sc := &SharedContext{
		cmdQueue: make(chan func(), 256),
		stopChan: make(chan struct{}),
	}

	var wg sync.WaitGroup
	const goroutines = 100
	const iterations = 50

	for i := 0; i < goroutines; i++ {
		wg.Add(1)
		go func(id int) {
			defer wg.Done()
			for j := 0; j < iterations; j++ {
				sc.Post(func() {
					_ = id + j
				})
			}
		}(i)
	}

	wg.Wait()
}

func TestSharedContext_PostQueueFull(t *testing.T) {
	sc := &SharedContext{
		cmdQueue: make(chan func(), 2),
		stopChan: make(chan struct{}),
	}

	sc.Post(func() {})
	sc.Post(func() {})
	sc.Post(func() {})
	sc.Post(func() {})

	assert.Len(t, sc.cmdQueue, 2)
}

func TestSharedContext_StartMultipleTimes(t *testing.T) {
	sc := &SharedContext{
		cmdQueue: make(chan func(), 256),
		stopChan: make(chan struct{}),
		started:  false,
	}

	var wg sync.WaitGroup
	const goroutines = 10

	for i := 0; i < goroutines; i++ {
		wg.Add(1)
		go func() {
			defer wg.Done()
			sc.Start()
		}()
	}

	wg.Wait()

	assert.True(t, sc.started)
}

func TestSharedContext_DrainCmdQueue(t *testing.T) {
	sc := &SharedContext{
		cmdQueue: make(chan func(), 256),
		stopChan: make(chan struct{}),
	}

	counter := 0
	for i := 0; i < 10; i++ {
		sc.cmdQueue <- func() {
			counter++
		}
	}

	sc.drainCmdQueue()

	assert.Equal(t, 10, counter)
	assert.Len(t, sc.cmdQueue, 0)
}

func TestSharedContext_DrainCmdQueueEmpty(t *testing.T) {
	sc := &SharedContext{
		cmdQueue: make(chan func(), 256),
		stopChan: make(chan struct{}),
	}

	sc.drainCmdQueue()

	assert.Len(t, sc.cmdQueue, 0)
}

func TestSharedContext_ConcurrentDrainAndPost(t *testing.T) {
	sc := &SharedContext{
		cmdQueue: make(chan func(), 256),
		stopChan: make(chan struct{}),
	}

	var wg sync.WaitGroup

	wg.Add(1)
	go func() {
		defer wg.Done()
		for i := 0; i < 100; i++ {
			sc.Post(func() {})
		}
	}()

	wg.Add(1)
	go func() {
		defer wg.Done()
		for i := 0; i < 50; i++ {
			sc.drainCmdQueue()
		}
	}()

	wg.Wait()
}
