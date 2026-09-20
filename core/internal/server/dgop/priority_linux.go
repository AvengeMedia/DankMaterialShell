//go:build linux

package dgop

import "golang.org/x/sys/unix"

func lowerThreadPriority() {
	_ = unix.Setpriority(unix.PRIO_PROCESS, unix.Gettid(), 19)
}
