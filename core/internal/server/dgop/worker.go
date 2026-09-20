package dgop

import (
	"runtime"
	"sync"
)

var (
	startWorker sync.Once
	jobs        chan func()
)

func runLowPriority(job func()) {
	startWorker.Do(func() {
		jobs = make(chan func())
		go worker()
	})
	done := make(chan struct{})
	jobs <- func() {
		defer close(done)
		job()
	}
	<-done
}

// Sampling must never preempt a foreground app, so it runs on one OS thread with lowered priority.
func worker() {
	runtime.LockOSThread()
	lowerThreadPriority()
	for job := range jobs {
		job()
	}
}
