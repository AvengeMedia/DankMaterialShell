package screenshot

import (
	"fmt"
	"os"
	"os/exec"
	"path/filepath"
	"strconv"
	"syscall"

	"github.com/AvengeMedia/DankMaterialShell/core/internal/log"
	"github.com/godbus/dbus/v5"
)

const (
	notifyDest      = "org.freedesktop.Notifications"
	notifyPath      = "/org/freedesktop/Notifications"
	notifyInterface = "org.freedesktop.Notifications"
)

type NotifyResult struct {
	FilePath  string
	Clipboard bool
	ImageData []byte
	Width     int
	Height    int
}

func SendNotification(result NotifyResult) {
	conn, err := dbus.SessionBus()
	if err != nil {
		log.Debug("dbus session failed", "err", err)
		return
	}

	var actions []string
	if result.FilePath != "" {
		actions = []string{"default", "Open"}
	}

	hints := map[string]dbus.Variant{}
	if len(result.ImageData) > 0 && result.Width > 0 && result.Height > 0 {
		rowstride := result.Width * 3
		hints["image_data"] = dbus.MakeVariant(struct {
			Width         int32
			Height        int32
			Rowstride     int32
			HasAlpha      bool
			BitsPerSample int32
			Channels      int32
			Data          []byte
		}{
			Width:         int32(result.Width),
			Height:        int32(result.Height),
			Rowstride:     int32(rowstride),
			HasAlpha:      false,
			BitsPerSample: 8,
			Channels:      3,
			Data:          result.ImageData,
		})
	} else if result.FilePath != "" {
		hints["image_path"] = dbus.MakeVariant(result.FilePath)
	}

	summary := "Screenshot captured"
	body := ""
	switch {
	case result.FilePath != "" && result.Clipboard:
		body = fmt.Sprintf("%s\nCopied to clipboard", filepath.Base(result.FilePath))
	case result.FilePath != "":
		body = filepath.Base(result.FilePath)
	case result.Clipboard:
		body = "Copied to clipboard"
	}

	obj := conn.Object(notifyDest, notifyPath)
	call := obj.Call(
		notifyInterface+".Notify",
		0,
		"DMS",
		uint32(0),
		"",
		summary,
		body,
		actions,
		hints,
		int32(5000),
	)

	if call.Err != nil {
		log.Debug("notify call failed", "err", call.Err)
		return
	}

	var notificationID uint32
	if err := call.Store(&notificationID); err != nil {
		log.Debug("failed to get notification id", "err", err)
		return
	}

	if len(actions) == 0 || result.FilePath == "" {
		return
	}

	spawnActionListener(notificationID, result.FilePath)
}

func spawnActionListener(notificationID uint32, filePath string) {
	exe, err := os.Executable()
	if err != nil {
		log.Debug("failed to get executable", "err", err)
		return
	}

	cmd := exec.Command(exe, "notify-action", fmt.Sprintf("%d", notificationID), filePath)
	cmd.SysProcAttr = &syscall.SysProcAttr{
		Setsid: true,
	}
	cmd.Start()
}

func RunNotifyActionListener(args []string) {
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
			openFile(filePath)
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

func openFile(filePath string) {
	cmd := exec.Command("xdg-open", filePath)
	cmd.SysProcAttr = &syscall.SysProcAttr{
		Setsid: true,
	}
	cmd.Start()
}
