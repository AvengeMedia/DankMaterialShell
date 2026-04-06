package clipboard

import (
	"fmt"
	"io"
	"os"
	"os/exec"
	"path/filepath"
	"syscall"

	"github.com/AvengeMedia/DankMaterialShell/core/internal/proto/ext_data_control"
	wlclient "github.com/AvengeMedia/DankMaterialShell/core/pkg/go-wayland/wayland/client"
)

const envServe = "_DMS_CLIPBOARD_SERVE"
const envMime = "_DMS_CLIPBOARD_MIME"
const envPasteOnce = "_DMS_CLIPBOARD_PASTE_ONCE"
const envCacheFile = "_DMS_CLIPBOARD_CACHE"

// MaybeServeAndExit intercepts before cobra when re-exec'd as a clipboard
// child. Reads source data into memory, deletes any cache file, then serves.
func MaybeServeAndExit() {
	if os.Getenv(envServe) == "" {
		return
	}

	mimeType := os.Getenv(envMime)
	pasteOnce := os.Getenv(envPasteOnce) == "1"
	cachePath := os.Getenv(envCacheFile)

	var data []byte
	var err error

	switch {
	case cachePath != "":
		data, err = os.ReadFile(cachePath)
		os.Remove(cachePath)
	default:
		data, err = io.ReadAll(os.Stdin)
	}

	if err != nil {
		fmt.Fprintf(os.Stderr, "clipboard: read source: %v\n", err)
		os.Exit(1)
	}

	if err := serveClipboard(data, mimeType, pasteOnce); err != nil {
		fmt.Fprintf(os.Stderr, "clipboard: serve: %v\n", err)
		os.Exit(1)
	}
	os.Exit(0)
}

func Copy(data []byte, mimeType string) error {
	return copyForkCached(data, mimeType, false)
}

func CopyOpts(data []byte, mimeType string, foreground, pasteOnce bool) error {
	if foreground {
		return serveClipboard(data, mimeType, pasteOnce)
	}
	return copyForkCached(data, mimeType, pasteOnce)
}

func CopyReader(data io.Reader, mimeType string, foreground, pasteOnce bool) error {
	if foreground {
		buf, err := io.ReadAll(data)
		if err != nil {
			return fmt.Errorf("read source: %w", err)
		}
		return serveClipboard(buf, mimeType, pasteOnce)
	}
	return copyFork(data, mimeType, pasteOnce)
}

func newForkCmd(mimeType string, pasteOnce bool, extra ...string) *exec.Cmd {
	cmd := exec.Command(os.Args[0])
	cmd.Stderr = nil
	cmd.SysProcAttr = &syscall.SysProcAttr{Setsid: true}
	cmd.Env = append(os.Environ(),
		envServe+"=1",
		envMime+"="+mimeType,
	)
	if pasteOnce {
		cmd.Env = append(cmd.Env, envPasteOnce+"=1")
	}
	cmd.Env = append(cmd.Env, extra...)
	return cmd
}

func waitReady(cmd *exec.Cmd) error {
	stdout, err := cmd.StdoutPipe()
	if err != nil {
		return fmt.Errorf("stdout pipe: %w", err)
	}
	if err := cmd.Start(); err != nil {
		return fmt.Errorf("start: %w", err)
	}
	var buf [1]byte
	if _, err := stdout.Read(buf[:]); err != nil {
		return fmt.Errorf("waiting for clipboard ready: %w", err)
	}
	return nil
}

func copyForkCached(data []byte, mimeType string, pasteOnce bool) error {
	cacheFile, err := createClipboardCacheFile()
	if err != nil {
		return fmt.Errorf("create cache file: %w", err)
	}
	cachePath := cacheFile.Name()

	if _, err := cacheFile.Write(data); err != nil {
		cacheFile.Close()
		os.Remove(cachePath)
		return fmt.Errorf("write cache file: %w", err)
	}
	if err := cacheFile.Close(); err != nil {
		os.Remove(cachePath)
		return fmt.Errorf("close cache file: %w", err)
	}

	cmd := newForkCmd(mimeType, pasteOnce, envCacheFile+"="+cachePath)
	cmd.Stdin = nil
	if err := waitReady(cmd); err != nil {
		os.Remove(cachePath)
		return err
	}
	return nil
}

func copyFork(data io.Reader, mimeType string, pasteOnce bool) error {
	cmd := newForkCmd(mimeType, pasteOnce)

	switch src := data.(type) {
	case *os.File:
		cmd.Stdin = src
		return waitReady(cmd)

	default:
		stdin, err := cmd.StdinPipe()
		if err != nil {
			return fmt.Errorf("stdin pipe: %w", err)
		}

		stdout, err := cmd.StdoutPipe()
		if err != nil {
			return fmt.Errorf("stdout pipe: %w", err)
		}

		if err := cmd.Start(); err != nil {
			return fmt.Errorf("start: %w", err)
		}
		if _, err := io.Copy(stdin, data); err != nil {
			stdin.Close()
			return fmt.Errorf("write stdin: %w", err)
		}
		if err := stdin.Close(); err != nil {
			return fmt.Errorf("close stdin: %w", err)
		}

		var buf [1]byte
		if _, err := stdout.Read(buf[:]); err != nil {
			return fmt.Errorf("waiting for clipboard ready: %w", err)
		}
		return nil
	}
}

func signalReady() {
	if os.Getenv(envServe) == "" {
		return
	}
	os.Stdout.Write([]byte{1})
}

func createClipboardCacheFile() (*os.File, error) {
	preferredDirs := []string{}

	if cacheDir, err := os.UserCacheDir(); err == nil {
		preferredDirs = append(preferredDirs, filepath.Join(cacheDir, "dms", "clipboard"))
	}
	preferredDirs = append(preferredDirs, "/var/tmp/dms/clipboard")

	for _, dir := range preferredDirs {
		if err := os.MkdirAll(dir, 0o700); err != nil {
			continue
		}
		cachedData, err := os.CreateTemp(dir, "dms-clipboard-*")
		if err == nil {
			return cachedData, nil
		}
	}
	return os.CreateTemp("", "dms-clipboard-*")
}

func serveClipboard(data []byte, mimeType string, pasteOnce bool) error {
	display, err := wlclient.Connect("")
	if err != nil {
		return fmt.Errorf("wayland connect: %w", err)
	}
	defer display.Destroy()

	ctx := display.Context()
	registry, err := display.GetRegistry()
	if err != nil {
		return fmt.Errorf("get registry: %w", err)
	}
	defer registry.Destroy()

	var dataControlMgr *ext_data_control.ExtDataControlManagerV1
	var seat *wlclient.Seat
	var bindErr error

	registry.SetGlobalHandler(func(e wlclient.RegistryGlobalEvent) {
		switch e.Interface {
		case "ext_data_control_manager_v1":
			dataControlMgr = ext_data_control.NewExtDataControlManagerV1(ctx)
			if err := registry.Bind(e.Name, e.Interface, e.Version, dataControlMgr); err != nil {
				bindErr = err
			}
		case "wl_seat":
			if seat != nil {
				return
			}
			seat = wlclient.NewSeat(ctx)
			if err := registry.Bind(e.Name, e.Interface, e.Version, seat); err != nil {
				bindErr = err
			}
		}
	})

	display.Roundtrip()
	display.Roundtrip()

	if bindErr != nil {
		return fmt.Errorf("registry bind: %w", bindErr)
	}
	if dataControlMgr == nil {
		return fmt.Errorf("compositor does not support ext_data_control_manager_v1")
	}
	defer dataControlMgr.Destroy()
	if seat == nil {
		return fmt.Errorf("no seat available")
	}

	device, err := dataControlMgr.GetDataDevice(seat)
	if err != nil {
		return fmt.Errorf("get data device: %w", err)
	}
	defer device.Destroy()

	source, err := dataControlMgr.CreateDataSource()
	if err != nil {
		return fmt.Errorf("create data source: %w", err)
	}

	if err := source.Offer(mimeType); err != nil {
		return fmt.Errorf("offer mime type: %w", err)
	}
	if mimeType == "text/plain;charset=utf-8" || mimeType == "text/plain" {
		if err := source.Offer("text/plain"); err != nil {
			return fmt.Errorf("offer text/plain: %w", err)
		}
		if err := source.Offer("text/plain;charset=utf-8"); err != nil {
			return fmt.Errorf("offer text/plain;charset=utf-8: %w", err)
		}
		if err := source.Offer("UTF8_STRING"); err != nil {
			return fmt.Errorf("offer UTF8_STRING: %w", err)
		}
		if err := source.Offer("STRING"); err != nil {
			return fmt.Errorf("offer STRING: %w", err)
		}
		if err := source.Offer("TEXT"); err != nil {
			return fmt.Errorf("offer TEXT: %w", err)
		}
	}

	cancelled := make(chan struct{})
	pasted := make(chan struct{}, 1)

	source.SetSendHandler(func(e ext_data_control.ExtDataControlSourceV1SendEvent) {
		_ = syscall.SetNonblock(e.Fd, false)
		file := os.NewFile(uintptr(e.Fd), "pipe")
		defer file.Close()
		_, _ = file.Write(data)
		select {
		case pasted <- struct{}{}:
		default:
		}
	})

	source.SetCancelledHandler(func(e ext_data_control.ExtDataControlSourceV1CancelledEvent) {
		close(cancelled)
	})

	if err := device.SetSelection(source); err != nil {
		return fmt.Errorf("set selection: %w", err)
	}

	display.Roundtrip()
	signalReady()

	for {
		select {
		case <-cancelled:
			return nil
		case <-pasted:
			if pasteOnce {
				return nil
			}
		default:
			if err := ctx.Dispatch(); err != nil {
				return nil
			}
		}
	}
}

func CopyText(text string) error {
	return Copy([]byte(text), "text/plain;charset=utf-8")
}

func Paste() ([]byte, string, error) {
	display, err := wlclient.Connect("")
	if err != nil {
		return nil, "", fmt.Errorf("wayland connect: %w", err)
	}
	defer display.Destroy()

	ctx := display.Context()
	registry, err := display.GetRegistry()
	if err != nil {
		return nil, "", fmt.Errorf("get registry: %w", err)
	}
	defer registry.Destroy()

	var dataControlMgr *ext_data_control.ExtDataControlManagerV1
	var seat *wlclient.Seat
	var bindErr error

	registry.SetGlobalHandler(func(e wlclient.RegistryGlobalEvent) {
		switch e.Interface {
		case "ext_data_control_manager_v1":
			dataControlMgr = ext_data_control.NewExtDataControlManagerV1(ctx)
			if err := registry.Bind(e.Name, e.Interface, e.Version, dataControlMgr); err != nil {
				bindErr = err
			}
		case "wl_seat":
			if seat != nil {
				return
			}
			seat = wlclient.NewSeat(ctx)
			if err := registry.Bind(e.Name, e.Interface, e.Version, seat); err != nil {
				bindErr = err
			}
		}
	})

	display.Roundtrip()
	display.Roundtrip()

	if bindErr != nil {
		return nil, "", fmt.Errorf("registry bind: %w", bindErr)
	}

	if dataControlMgr == nil {
		return nil, "", fmt.Errorf("compositor does not support ext_data_control_manager_v1")
	}
	defer dataControlMgr.Destroy()

	if seat == nil {
		return nil, "", fmt.Errorf("no seat available")
	}

	device, err := dataControlMgr.GetDataDevice(seat)
	if err != nil {
		return nil, "", fmt.Errorf("get data device: %w", err)
	}
	defer device.Destroy()

	offerMimeTypes := make(map[*ext_data_control.ExtDataControlOfferV1][]string)

	device.SetDataOfferHandler(func(e ext_data_control.ExtDataControlDeviceV1DataOfferEvent) {
		if e.Id == nil {
			return
		}
		offerMimeTypes[e.Id] = nil
		e.Id.SetOfferHandler(func(me ext_data_control.ExtDataControlOfferV1OfferEvent) {
			offerMimeTypes[e.Id] = append(offerMimeTypes[e.Id], me.MimeType)
		})
	})

	var selectionOffer *ext_data_control.ExtDataControlOfferV1
	gotSelection := false

	device.SetSelectionHandler(func(e ext_data_control.ExtDataControlDeviceV1SelectionEvent) {
		selectionOffer = e.Id
		gotSelection = true
	})

	display.Roundtrip()
	display.Roundtrip()

	if !gotSelection || selectionOffer == nil {
		return nil, "", fmt.Errorf("no clipboard data")
	}

	mimeTypes := offerMimeTypes[selectionOffer]
	selectedMime := selectPreferredMimeType(mimeTypes)
	if selectedMime == "" {
		return nil, "", fmt.Errorf("no supported mime type")
	}

	r, w, err := os.Pipe()
	if err != nil {
		return nil, "", fmt.Errorf("create pipe: %w", err)
	}
	defer r.Close()

	if err := selectionOffer.Receive(selectedMime, int(w.Fd())); err != nil {
		w.Close()
		return nil, "", fmt.Errorf("receive: %w", err)
	}
	w.Close()

	display.Roundtrip()

	data, err := io.ReadAll(r)
	if err != nil {
		return nil, "", fmt.Errorf("read: %w", err)
	}

	return data, selectedMime, nil
}

func PasteText() (string, error) {
	data, _, err := Paste()
	if err != nil {
		return "", err
	}
	return string(data), nil
}

func selectPreferredMimeType(mimes []string) string {
	preferred := []string{
		"text/plain;charset=utf-8",
		"text/plain",
		"UTF8_STRING",
		"STRING",
		"TEXT",
		"image/png",
		"image/jpeg",
	}

	for _, pref := range preferred {
		for _, mime := range mimes {
			if mime == pref {
				return mime
			}
		}
	}

	if len(mimes) > 0 {
		return mimes[0]
	}
	return ""
}

func IsImageMimeType(mime string) bool {
	return len(mime) > 6 && mime[:6] == "image/"
}

type Offer struct {
	MimeType string
	Data     []byte
}

func CopyMulti(offers []Offer, foreground, pasteOnce bool) error {
	if !foreground {
		return copyMultiFork(offers, pasteOnce)
	}
	return copyMultiServe(offers, pasteOnce)
}

func copyMultiFork(offers []Offer, pasteOnce bool) error {
	args := []string{os.Args[0], "cl", "copy", "--foreground", "--type", "__multi__"}
	if pasteOnce {
		args = append(args, "--paste-once")
	}

	cmd := exec.Command(args[0], args[1:]...)
	cmd.Stdin = nil
	cmd.Stdout = nil
	cmd.Stderr = nil
	cmd.SysProcAttr = &syscall.SysProcAttr{Setsid: true}

	stdin, err := cmd.StdinPipe()
	if err != nil {
		return fmt.Errorf("stdin pipe: %w", err)
	}

	if err := cmd.Start(); err != nil {
		return fmt.Errorf("start: %w", err)
	}

	for _, offer := range offers {
		fmt.Fprintf(stdin, "%s\x00%d\x00", offer.MimeType, len(offer.Data))
		if _, err := stdin.Write(offer.Data); err != nil {
			stdin.Close()
			return fmt.Errorf("write offer data: %w", err)
		}
	}
	stdin.Close()

	return nil
}

func copyMultiServe(offers []Offer, pasteOnce bool) error {
	display, err := wlclient.Connect("")
	if err != nil {
		return fmt.Errorf("wayland connect: %w", err)
	}
	defer display.Destroy()

	ctx := display.Context()
	registry, err := display.GetRegistry()
	if err != nil {
		return fmt.Errorf("get registry: %w", err)
	}
	defer registry.Destroy()

	var dataControlMgr *ext_data_control.ExtDataControlManagerV1
	var seat *wlclient.Seat
	var bindErr error

	registry.SetGlobalHandler(func(e wlclient.RegistryGlobalEvent) {
		switch e.Interface {
		case "ext_data_control_manager_v1":
			dataControlMgr = ext_data_control.NewExtDataControlManagerV1(ctx)
			if err := registry.Bind(e.Name, e.Interface, e.Version, dataControlMgr); err != nil {
				bindErr = err
			}
		case "wl_seat":
			if seat != nil {
				return
			}
			seat = wlclient.NewSeat(ctx)
			if err := registry.Bind(e.Name, e.Interface, e.Version, seat); err != nil {
				bindErr = err
			}
		}
	})

	display.Roundtrip()
	display.Roundtrip()

	if bindErr != nil {
		return fmt.Errorf("registry bind: %w", bindErr)
	}
	if dataControlMgr == nil {
		return fmt.Errorf("compositor does not support ext_data_control_manager_v1")
	}
	defer dataControlMgr.Destroy()
	if seat == nil {
		return fmt.Errorf("no seat available")
	}

	device, err := dataControlMgr.GetDataDevice(seat)
	if err != nil {
		return fmt.Errorf("get data device: %w", err)
	}
	defer device.Destroy()

	source, err := dataControlMgr.CreateDataSource()
	if err != nil {
		return fmt.Errorf("create data source: %w", err)
	}

	offerMap := make(map[string][]byte)
	for _, offer := range offers {
		if err := source.Offer(offer.MimeType); err != nil {
			return fmt.Errorf("offer %s: %w", offer.MimeType, err)
		}
		offerMap[offer.MimeType] = offer.Data
	}

	cancelled := make(chan struct{})
	pasted := make(chan struct{}, 1)

	source.SetSendHandler(func(e ext_data_control.ExtDataControlSourceV1SendEvent) {
		_ = syscall.SetNonblock(e.Fd, false)
		file := os.NewFile(uintptr(e.Fd), "pipe")
		defer file.Close()

		if data, ok := offerMap[e.MimeType]; ok {
			_, _ = file.Write(data)
		}

		select {
		case pasted <- struct{}{}:
		default:
		}
	})

	source.SetCancelledHandler(func(e ext_data_control.ExtDataControlSourceV1CancelledEvent) {
		close(cancelled)
	})

	if err := device.SetSelection(source); err != nil {
		return fmt.Errorf("set selection: %w", err)
	}

	display.Roundtrip()

	for {
		select {
		case <-cancelled:
			return nil
		case <-pasted:
			if pasteOnce {
				return nil
			}
		default:
			if err := ctx.Dispatch(); err != nil {
				return nil
			}
		}
	}
}
