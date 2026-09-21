//go:build linux

package lowprio

import "golang.org/x/sys/unix"

func LowerThreadPriority() {
	_ = unix.Setpriority(unix.PRIO_PROCESS, unix.Gettid(), 19)
}
