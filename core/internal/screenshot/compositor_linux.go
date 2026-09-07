package screenshot

import (
	"context"
	"net"
	"os"
	"path/filepath"
	"strconv"
	"strings"
	"time"

	"github.com/AvengeMedia/DankMaterialShell/core/internal"
	"golang.org/x/sys/unix"
)

func waylandSocketOwner() string {
	display := os.Getenv("WAYLAND_DISPLAY")
	if display == "" {
		display = "wayland-0"
	}
	if !filepath.IsAbs(display) {
		display = filepath.Join(os.Getenv("XDG_RUNTIME_DIR"), display)
	}
	connection, err := net.DialTimeout("unix", display, time.Second)
	if err != nil {
		return ""
	}
	defer connection.Close()
	raw, err := connection.(*net.UnixConn).SyscallConn()
	if err != nil {
		return ""
	}
	var pid int32
	err = raw.Control(func(fd uintptr) {
		cred, err := unix.GetsockoptUcred(int(fd), unix.SOL_SOCKET, unix.SO_PEERCRED)
		if err == nil {
			pid = cred.Pid
		}
	})
	if err != nil || pid <= 0 {
		return ""
	}
	comm, err := os.ReadFile(filepath.Join("/proc", strconv.Itoa(int(pid)), "comm"))
	if err != nil {
		return ""
	}
	return strings.ToLower(strings.TrimSpace(string(comm)))
}

func aqueousSnapshot(ctx context.Context) (aqueousSnapshotModel, error) {
	data, err := internal.AqueousSnapshot(ctx)
	if err != nil {
		return aqueousSnapshotModel{}, err
	}
	return parseAqueousSnapshot(data)
}
