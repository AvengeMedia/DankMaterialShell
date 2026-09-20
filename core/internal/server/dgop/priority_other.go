//go:build !linux

package dgop

// Nice is per-process outside Linux, so lowering it here would slow the whole daemon.
func lowerThreadPriority() {}
