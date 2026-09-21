//go:build !linux

package lowprio

// Nice is per-process outside Linux, so lowering it here would slow the whole daemon.
func LowerThreadPriority() {}
