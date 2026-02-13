package notify

import (
	"fmt"
	"os"
	"os/exec"
	"path/filepath"
	"strconv"
	"syscall"

	"github.com/godbus/dbus/v5"
)

const (
	notifyDest      = "org.freedesktop.Notifications"
	notifyPath      = "/org/freedesktop/Notifications"
	notifyInterface = "org.freedesktop.Notifications"

	maxSummaryLen = 29
	maxBodyLen    = 80
)

type Notification struct {
	AppName  string
	Icon     string
	Summary  string
	Body     string
	FilePath string
	Timeout  int32
}

func Send(n Notification) error {
	conn, err := dbus.SessionBus()
	if err != nil {
		return fmt.Errorf("dbus session failed: %w", err)
	}

	if n.AppName == "" {
		n.AppName = "DMS"
	}
	if n.Timeout == 0 {
		n.Timeout = 5000
	}

	if len(n.Summary) > maxSummaryLen {
		n.Summary = n.Summary[:maxSummaryLen-3] + "..."
	}
	if len(n.Body) > maxBodyLen {
		n.Body = n.Body[:maxBodyLen-3] + "..."
	}

	var actions []string
	if n.FilePath != "" {
		actions = []string{
			"open", "Open",
			"folder", "Open Folder",
		}
	}

	hints := map[string]dbus.Variant{}
	if n.FilePath != "" {
		hints["image_path"] = dbus.MakeVariant(n.FilePath)
	}

	obj := conn.Object(notifyDest, notifyPath)
	call := obj.Call(
		notifyInterface+".Notify",
		0,
		n.AppName,
		uint32(0),
		n.Icon,
		n.Summary,
		n.Body,
		actions,
		hints,
		n.Timeout,
	)

	if call.Err != nil {
		return fmt.Errorf("notify call failed: %w", call.Err)
	}

	var notificationID uint32
	if err := call.Store(&notificationID); err != nil {
		return fmt.Errorf("failed to get notification id: %w", err)
	}

	if len(actions) > 0 && n.FilePath != "" {
		spawnActionListener(notificationID, n.FilePath)
	}

	return nil
}

func spawnActionListener(notificationID uint32, filePath string) {
	exe, err := os.Executable()
	if err != nil {
		return
	}

	cmd := exec.Command(exe, "notify-action-generic", fmt.Sprintf("%d", notificationID), filePath)
	cmd.SysProcAttr = &syscall.SysProcAttr{
		Setsid: true,
	}
	cmd.Start()
}

func RunActionListener(args []string) {
	if len(args) < 2 {
		return
	}

	notificationID, err := strconv.ParseUint(args[0], 10, 32)
	if err != nil {
		return
	}

	filePath := args[1]

	conn, err := dbus.SessionBus()
	if err != nil {
		return
	}

	if err := conn.AddMatchSignal(
		dbus.WithMatchObjectPath(notifyPath),
		dbus.WithMatchInterface(notifyInterface),
	); err != nil {
		return
	}

	signals := make(chan *dbus.Signal, 10)
	conn.Signal(signals)

	for sig := range signals {
		switch sig.Name {
		case notifyInterface + ".ActionInvoked":
			if len(sig.Body) < 2 {
				continue
			}
			id, ok := sig.Body[0].(uint32)
			if !ok || id != uint32(notificationID) {
				continue
			}
			action, ok := sig.Body[1].(string)
			if !ok {
				continue
			}
			handleAction(action, filePath)
			return

		case notifyInterface + ".NotificationClosed":
			if len(sig.Body) < 1 {
				continue
			}
			id, ok := sig.Body[0].(uint32)
			if !ok || id != uint32(notificationID) {
				continue
			}
			return
		}
	}
}

func handleAction(action, filePath string) {
	switch action {
	case "open", "default":
		openPath(filePath)
	case "folder":
		openPath(filepath.Dir(filePath))
	}
}

func openPath(path string) {
	cmd := exec.Command("xdg-open", path)
	cmd.SysProcAttr = &syscall.SysProcAttr{
		Setsid: true,
	}
	cmd.Start()
}
