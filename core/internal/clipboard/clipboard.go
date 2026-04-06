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

func Copy(data []byte, mimeType string) error {
	return copyForkCached(data, mimeType, false)
}

func CopyOpts(data []byte, mimeType string, foreground, pasteOnce bool) error {
	if foreground {
		return copyServeWithWriter(func(writer io.Writer) error {
			total := 0
			for total < len(data) {
				n, err := writer.Write(data[total:])
				total += n
				if err != nil {
					return err
				}
			}
			if total != len(data) {
				return io.ErrShortWrite
			}
			return nil
		}, mimeType, pasteOnce)
	}
	return copyForkCached(data, mimeType, pasteOnce)
}

func CopyReader(data io.Reader, mimeType string, foreground, pasteOnce bool) error {
	if !foreground {
		return copyFork(data, mimeType, pasteOnce)
	}
	return copyServeReader(data, mimeType, pasteOnce)
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

	args := []string{os.Args[0], "cl", "copy", "--foreground", "--cache-file", cachePath}
	if pasteOnce {
		args = append(args, "--paste-once")
	}
	args = append(args, "--type", mimeType)

	cmd := exec.Command(args[0], args[1:]...)
	cmd.Stdin = nil
	cmd.Stderr = nil
	cmd.SysProcAttr = &syscall.SysProcAttr{Setsid: true}
	cmd.Env = append(os.Environ(), "DMS_CLIP_FORKED=1")

	stdout, err := cmd.StdoutPipe()
	if err != nil {
		os.Remove(cachePath)
		return fmt.Errorf("stdout pipe: %w", err)
	}

	if err := cmd.Start(); err != nil {
		os.Remove(cachePath)
		return fmt.Errorf("start: %w", err)
	}

	var buf [1]byte
	if _, err := stdout.Read(buf[:]); err != nil {
		return fmt.Errorf("waiting for clipboard ready: %w", err)
	}
	return nil
}

func copyFork(data io.Reader, mimeType string, pasteOnce bool) error {
	args := []string{os.Args[0], "cl", "copy", "--foreground"}
	if pasteOnce {
		args = append(args, "--paste-once")
	}
	args = append(args, "--type", mimeType)

	cmd := exec.Command(args[0], args[1:]...)
	cmd.Stderr = nil
	cmd.SysProcAttr = &syscall.SysProcAttr{Setsid: true}
	cmd.Env = append(os.Environ(), "DMS_CLIP_FORKED=1")

	stdout, err := cmd.StdoutPipe()
	if err != nil {
		return fmt.Errorf("stdout pipe: %w", err)
	}

	switch src := data.(type) {
	case *os.File:
		cmd.Stdin = src
		if err := cmd.Start(); err != nil {
			return fmt.Errorf("start: %w", err)
		}

	default:
		stdin, err := cmd.StdinPipe()
		if err != nil {
			return fmt.Errorf("stdin pipe: %w", err)
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
	}

	var buf [1]byte
	if _, err := stdout.Read(buf[:]); err != nil {
		return fmt.Errorf("waiting for clipboard ready: %w", err)
	}
	return nil
}

func signalReady() {
	if os.Getenv("DMS_CLIP_FORKED") == "" {
		return
	}
	os.Stdout.Write([]byte{1})
}

func ServeCacheFile(path, mimeType string, pasteOnce bool) error {
	defer os.Remove(path)
	return copyServeWithWriter(func(writer io.Writer) error {
		f, err := os.Open(path)
		if err != nil {
			return fmt.Errorf("open cache file: %w", err)
		}
		defer f.Close()
		_, err = io.Copy(writer, f)
		return err
	}, mimeType, pasteOnce)
}

func copyServeReader(data io.Reader, mimeType string, pasteOnce bool) error {
	cachedData, err := createClipboardCacheFile()
	if err != nil {
		return fmt.Errorf("create clipboard cache file: %w", err)
	}
	defer os.Remove(cachedData.Name())

	if _, err := io.Copy(cachedData, data); err != nil {
		return fmt.Errorf("cache clipboard data: %w", err)
	}
	if err := cachedData.Close(); err != nil {
		return fmt.Errorf("close temp cache file: %w", err)
	}

	return copyServeWithWriter(func(writer io.Writer) error {
		cachedFile, err := os.Open(cachedData.Name())
		if err != nil {
			return fmt.Errorf("open temp cache file: %w", err)
		}
		defer cachedFile.Close()

		if _, err := io.Copy(writer, cachedFile); err != nil {
			return fmt.Errorf("write clipboard data: %w", err)
		}
		return nil
	}, mimeType, pasteOnce)
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

func copyServeWithWriter(writeTo func(io.Writer) error, mimeType string, pasteOnce bool) error {
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
	sendErr := make(chan error, 1)

	source.SetSendHandler(func(e ext_data_control.ExtDataControlSourceV1SendEvent) {
		defer syscall.Close(e.Fd)
		file := os.NewFile(uintptr(e.Fd), "pipe")
		defer file.Close()
		if err := writeTo(file); err != nil {
			select {
			case sendErr <- err:
			default:
			}
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
	signalReady()

	for {
		select {
		case <-cancelled:
			return nil
		case err := <-sendErr:
			return err
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
		defer syscall.Close(e.Fd)
		file := os.NewFile(uintptr(e.Fd), "pipe")
		defer file.Close()

		if data, ok := offerMap[e.MimeType]; ok {
			file.Write(data)
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
