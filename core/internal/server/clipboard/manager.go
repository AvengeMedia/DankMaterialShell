package clipboard

import (
	"bytes"
	"encoding/binary"
	"fmt"
	"image"
	_ "image/gif"
	_ "image/jpeg"
	_ "image/png"
	"io"
	"os"
	"path/filepath"
	"slices"
	"strings"
	"syscall"
	"time"

	"hash/fnv"

	"github.com/fsnotify/fsnotify"
	_ "golang.org/x/image/bmp"
	_ "golang.org/x/image/tiff"

	bolt "go.etcd.io/bbolt"

	"github.com/AvengeMedia/DankMaterialShell/core/internal/log"
	"github.com/AvengeMedia/DankMaterialShell/core/internal/proto/ext_data_control"
	"github.com/AvengeMedia/DankMaterialShell/core/internal/server/wlcontext"
	wlclient "github.com/AvengeMedia/DankMaterialShell/core/pkg/go-wayland/wayland/client"
)

// These mime types wont be stored in history
var sensitiveMimeTypes = []string{
	"x-kde-passwordManagerHint",
}

func NewManager(wlCtx wlcontext.WaylandContext, config Config) (*Manager, error) {
	display := wlCtx.Display()
	dbPath, err := getDBPath()
	if err != nil {
		return nil, fmt.Errorf("failed to get db path: %w", err)
	}

	configPath, _ := getConfigPath()

	m := &Manager{
		config:         config,
		configPath:     configPath,
		display:        display,
		wlCtx:          wlCtx,
		stopChan:       make(chan struct{}),
		subscribers:    make(map[string]chan State),
		dirty:          make(chan struct{}, 1),
		offerMimeTypes: make(map[any][]string),
		offerRegistry:  make(map[uint32]any),
		dbPath:         dbPath,
	}

	if !config.Disabled {
		if err := m.setupRegistry(); err != nil {
			return nil, err
		}
	}

	m.notifierWg.Add(1)
	go m.notifier()

	go m.watchConfig()

	db, err := openDB(dbPath)
	if err != nil {
		return nil, fmt.Errorf("failed to open db: %w", err)
	}
	m.db = db

	if err := m.migrateHashes(); err != nil {
		log.Errorf("Failed to migrate hashes: %v", err)
	}

	if !config.Disabled {
		if config.ClearAtStartup {
			if err := m.clearHistoryInternal(); err != nil {
				log.Errorf("Failed to clear history at startup: %v", err)
			}
		}

		if config.AutoClearDays > 0 {
			if err := m.clearOldEntries(config.AutoClearDays); err != nil {
				log.Errorf("Failed to clear old entries: %v", err)
			}
		}
	}

	m.alive = true
	m.updateState()

	if !config.Disabled && m.dataControlMgr != nil && m.seat != nil {
		m.setupDataDeviceSync()
	}

	return m, nil
}

func getDBPath() (string, error) {
	cacheDir := os.Getenv("XDG_CACHE_HOME")
	if cacheDir == "" {
		homeDir, err := os.UserHomeDir()
		if err != nil {
			return "", err
		}
		cacheDir = filepath.Join(homeDir, ".cache")
	}

	dbDir := filepath.Join(cacheDir, "dms-clipboard")
	if err := os.MkdirAll(dbDir, 0700); err != nil {
		return "", err
	}

	return filepath.Join(dbDir, "db"), nil
}

func openDB(path string) (*bolt.DB, error) {
	db, err := bolt.Open(path, 0644, &bolt.Options{
		Timeout: 1 * time.Second,
	})
	if err != nil {
		return nil, err
	}

	err = db.Update(func(tx *bolt.Tx) error {
		_, err := tx.CreateBucketIfNotExists([]byte("clipboard"))
		return err
	})
	if err != nil {
		db.Close()
		return nil, err
	}

	return db, nil
}

func (m *Manager) post(fn func()) {
	m.wlCtx.Post(fn)
}

func (m *Manager) setupRegistry() error {
	ctx := m.display.Context()

	registry, err := m.display.GetRegistry()
	if err != nil {
		return fmt.Errorf("failed to get registry: %w", err)
	}
	m.registry = registry

	registry.SetGlobalHandler(func(e wlclient.RegistryGlobalEvent) {
		switch e.Interface {
		case "ext_data_control_manager_v1":
			if e.Version < 1 {
				return
			}
			dataControlMgr := ext_data_control.NewExtDataControlManagerV1(ctx)
			if err := registry.Bind(e.Name, e.Interface, e.Version, dataControlMgr); err != nil {
				log.Errorf("Failed to bind ext_data_control_manager_v1: %v", err)
				return
			}
			m.dataControlMgr = dataControlMgr
			log.Info("Bound ext_data_control_manager_v1")
		case "wl_seat":
			seat := wlclient.NewSeat(ctx)
			if err := registry.Bind(e.Name, e.Interface, e.Version, seat); err != nil {
				log.Errorf("Failed to bind wl_seat: %v", err)
				return
			}
			m.seat = seat
			m.seatName = e.Name
			log.Info("Bound wl_seat")
		}
	})

	m.display.Roundtrip()
	m.display.Roundtrip()

	if m.dataControlMgr == nil {
		return fmt.Errorf("compositor does not support ext_data_control_manager_v1")
	}

	if m.seat == nil {
		return fmt.Errorf("no seat available")
	}

	return nil
}

func (m *Manager) setupDataDeviceSync() {
	if m.dataControlMgr == nil || m.seat == nil {
		return
	}

	ctx := m.display.Context()
	dataMgr := m.dataControlMgr.(*ext_data_control.ExtDataControlManagerV1)

	dataDevice := ext_data_control.NewExtDataControlDeviceV1(ctx)

	dataDevice.SetDataOfferHandler(func(e ext_data_control.ExtDataControlDeviceV1DataOfferEvent) {
		if e.Id == nil {
			return
		}

		m.offerMutex.Lock()
		m.offerRegistry[e.Id.ID()] = e.Id
		m.offerMimeTypes[e.Id] = make([]string, 0)
		m.offerMutex.Unlock()

		e.Id.SetOfferHandler(func(me ext_data_control.ExtDataControlOfferV1OfferEvent) {
			m.offerMutex.Lock()
			m.offerMimeTypes[e.Id] = append(m.offerMimeTypes[e.Id], me.MimeType)
			m.offerMutex.Unlock()
		})
	})

	dataDevice.SetSelectionHandler(func(e ext_data_control.ExtDataControlDeviceV1SelectionEvent) {
		if !m.initialized {
			m.initialized = true
			return
		}

		var offer any
		if e.Id != nil {
			offer = e.Id
		} else if e.OfferId != 0 {
			m.offerMutex.RLock()
			offer = m.offerRegistry[e.OfferId]
			m.offerMutex.RUnlock()
		}

		m.ownerLock.Lock()
		wasOwner := m.isOwner
		m.ownerLock.Unlock()

		if offer == nil {
			return
		}

		if wasOwner {
			return
		}

		m.currentOffer = offer

		m.offerMutex.RLock()
		mimes := m.offerMimeTypes[offer]
		m.offerMutex.RUnlock()

		m.mimeTypes = mimes

		if len(mimes) == 0 {
			return
		}

		if m.hasSensitiveMimeType(mimes) {
			return
		}

		preferredMime := m.selectMimeType(mimes)
		if preferredMime == "" {
			return
		}

		typedOffer := offer.(*ext_data_control.ExtDataControlOfferV1)

		r, w, err := os.Pipe()
		if err != nil {
			return
		}

		if err := typedOffer.Receive(preferredMime, int(w.Fd())); err != nil {
			r.Close()
			w.Close()
			return
		}
		w.Close()

		go m.readAndStore(r, preferredMime)
	})

	if err := dataMgr.GetDataDeviceWithProxy(dataDevice, m.seat); err != nil {
		log.Errorf("Failed to send get_data_device request: %v", err)
		return
	}

	m.dataDevice = dataDevice

	if err := ctx.Dispatch(); err != nil {
		log.Errorf("Failed to dispatch initial events: %v", err)
		return
	}

	log.Info("Data device setup complete")
}

func (m *Manager) readAndStore(r *os.File, mimeType string) {
	defer r.Close()

	cfg := m.getConfig()

	done := make(chan []byte, 1)
	go func() {
		data, _ := io.ReadAll(r)
		done <- data
	}()

	var data []byte
	select {
	case data = <-done:
	case <-time.After(500 * time.Millisecond):
		return
	}

	if len(data) == 0 || int64(len(data)) > cfg.MaxEntrySize {
		return
	}
	if len(bytes.TrimSpace(data)) == 0 {
		return
	}

	if !cfg.Disabled && m.db != nil {
		m.storeClipboardEntry(data, mimeType)
	}

	m.updateState()
	m.notifySubscribers()
}

func (m *Manager) storeClipboardEntry(data []byte, mimeType string) {
	entry := Entry{
		Data:      data,
		MimeType:  mimeType,
		Size:      len(data),
		Timestamp: time.Now(),
		IsImage:   m.isImageMimeType(mimeType),
	}

	switch {
	case entry.IsImage:
		entry.Preview = m.imagePreview(data, mimeType)
	default:
		entry.Preview = m.textPreview(data)
	}

	if err := m.storeEntry(entry); err != nil {
		log.Errorf("Failed to store clipboard entry: %v", err)
	}
}

func (m *Manager) storeEntry(entry Entry) error {
	if m.db == nil {
		return fmt.Errorf("database not available")
	}

	entry.Hash = computeHash(entry.Data)

	return m.db.Update(func(tx *bolt.Tx) error {
		b := tx.Bucket([]byte("clipboard"))

		if err := m.deduplicateInTx(b, entry.Hash); err != nil {
			return err
		}

		id, err := b.NextSequence()
		if err != nil {
			return err
		}

		entry.ID = id

		encoded, err := encodeEntry(entry)
		if err != nil {
			return err
		}

		if err := b.Put(itob(id), encoded); err != nil {
			return err
		}

		return m.trimLengthInTx(b)
	})
}

func (m *Manager) deduplicateInTx(b *bolt.Bucket, hash uint64) error {
	c := b.Cursor()
	for k, v := c.Last(); k != nil; k, v = c.Prev() {
		if extractHash(v) != hash {
			continue
		}
		if err := b.Delete(k); err != nil {
			return err
		}
	}
	return nil
}

func (m *Manager) trimLengthInTx(b *bolt.Bucket) error {
	if m.config.MaxHistory < 0 {
		return nil
	}
	c := b.Cursor()
	var count int
	for k, _ := c.Last(); k != nil; k, _ = c.Prev() {
		if count < m.config.MaxHistory {
			count++
			continue
		}
		if err := b.Delete(k); err != nil {
			return err
		}
	}
	return nil
}

func encodeEntry(e Entry) ([]byte, error) {
	buf := new(bytes.Buffer)

	binary.Write(buf, binary.BigEndian, e.ID)
	binary.Write(buf, binary.BigEndian, uint32(len(e.Data)))
	buf.Write(e.Data)
	binary.Write(buf, binary.BigEndian, uint32(len(e.MimeType)))
	buf.WriteString(e.MimeType)
	binary.Write(buf, binary.BigEndian, uint32(len(e.Preview)))
	buf.WriteString(e.Preview)
	binary.Write(buf, binary.BigEndian, int32(e.Size))
	binary.Write(buf, binary.BigEndian, e.Timestamp.Unix())
	if e.IsImage {
		buf.WriteByte(1)
	} else {
		buf.WriteByte(0)
	}
	binary.Write(buf, binary.BigEndian, e.Hash)

	return buf.Bytes(), nil
}

func decodeEntry(data []byte) (Entry, error) {
	buf := bytes.NewReader(data)
	var e Entry

	binary.Read(buf, binary.BigEndian, &e.ID)

	var dataLen uint32
	binary.Read(buf, binary.BigEndian, &dataLen)
	e.Data = make([]byte, dataLen)
	buf.Read(e.Data)

	var mimeLen uint32
	binary.Read(buf, binary.BigEndian, &mimeLen)
	mimeBytes := make([]byte, mimeLen)
	buf.Read(mimeBytes)
	e.MimeType = string(mimeBytes)

	var prevLen uint32
	binary.Read(buf, binary.BigEndian, &prevLen)
	prevBytes := make([]byte, prevLen)
	buf.Read(prevBytes)
	e.Preview = string(prevBytes)

	var size int32
	binary.Read(buf, binary.BigEndian, &size)
	e.Size = int(size)

	var timestamp int64
	binary.Read(buf, binary.BigEndian, &timestamp)
	e.Timestamp = time.Unix(timestamp, 0)

	var isImage byte
	binary.Read(buf, binary.BigEndian, &isImage)
	e.IsImage = isImage == 1

	if buf.Len() >= 8 {
		binary.Read(buf, binary.BigEndian, &e.Hash)
	}

	return e, nil
}

func itob(v uint64) []byte {
	b := make([]byte, 8)
	binary.BigEndian.PutUint64(b, v)
	return b
}

func computeHash(data []byte) uint64 {
	h := fnv.New64a()
	h.Write(data)
	return h.Sum64()
}

func extractHash(data []byte) uint64 {
	if len(data) < 8 {
		return 0
	}
	return binary.BigEndian.Uint64(data[len(data)-8:])
}

func (m *Manager) hasSensitiveMimeType(mimes []string) bool {
	return slices.ContainsFunc(mimes, func(mime string) bool {
		return slices.Contains(sensitiveMimeTypes, mime)
	})
}

func (m *Manager) selectMimeType(mimes []string) string {
	preferredTypes := []string{
		"text/plain;charset=utf-8",
		"text/plain",
		"UTF8_STRING",
		"STRING",
		"TEXT",
		"image/png",
		"image/jpeg",
		"image/gif",
		"image/bmp",
		"image/tiff",
	}

	for _, pref := range preferredTypes {
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

func (m *Manager) isImageMimeType(mime string) bool {
	return strings.HasPrefix(mime, "image/")
}

func (m *Manager) textPreview(data []byte) string {
	text := string(data)
	text = strings.TrimSpace(text)
	text = strings.Join(strings.Fields(text), " ")

	if len(text) > 100 {
		return text[:100] + "…"
	}
	return text
}

func (m *Manager) imagePreview(data []byte, format string) string {
	config, imgFmt, err := image.DecodeConfig(bytes.NewReader(data))
	if err != nil {
		return fmt.Sprintf("[[ image %s %s ]]", sizeStr(len(data)), format)
	}
	return fmt.Sprintf("[[ image %s %s %dx%d ]]", sizeStr(len(data)), imgFmt, config.Width, config.Height)
}

func sizeStr(size int) string {
	units := []string{"B", "KiB", "MiB"}
	var i int
	fsize := float64(size)
	for fsize >= 1024 && i < len(units)-1 {
		fsize /= 1024
		i++
	}
	return fmt.Sprintf("%.0f %s", fsize, units[i])
}

func (m *Manager) updateState() {
	history := m.GetHistory()

	for i := range history {
		history[i].Data = nil
	}

	var current *Entry
	if len(history) > 0 {
		c := history[0]
		c.Data = nil
		current = &c
	}

	newState := &State{
		Enabled: m.alive,
		History: history,
		Current: current,
	}

	m.stateMutex.Lock()
	m.state = newState
	m.stateMutex.Unlock()
}

func (m *Manager) notifier() {
	defer m.notifierWg.Done()

	for range m.dirty {
		state := m.GetState()

		if m.lastState != nil && stateEqual(m.lastState, &state) {
			continue
		}

		m.lastState = &state

		m.subMutex.RLock()
		subs := make([]chan State, 0, len(m.subscribers))
		for _, ch := range m.subscribers {
			subs = append(subs, ch)
		}
		m.subMutex.RUnlock()

		for _, ch := range subs {
			select {
			case ch <- state:
			default:
			}
		}
	}
}

func stateEqual(a, b *State) bool {
	if a == nil || b == nil {
		return false
	}
	if a.Enabled != b.Enabled {
		return false
	}
	if len(a.History) != len(b.History) {
		return false
	}
	return true
}

func (m *Manager) GetHistory() []Entry {
	if m.db == nil {
		return nil
	}

	cfg := m.getConfig()
	var cutoff time.Time
	if cfg.AutoClearDays > 0 {
		cutoff = time.Now().AddDate(0, 0, -cfg.AutoClearDays)
	}

	var history []Entry
	var stale []uint64

	if err := m.db.View(func(tx *bolt.Tx) error {
		b := tx.Bucket([]byte("clipboard"))
		c := b.Cursor()

		for k, v := c.Last(); k != nil; k, v = c.Prev() {
			entry, err := decodeEntry(v)
			if err != nil {
				continue
			}
			if !cutoff.IsZero() && entry.Timestamp.Before(cutoff) {
				stale = append(stale, entry.ID)
				continue
			}
			history = append(history, entry)
		}
		return nil
	}); err != nil {
		log.Errorf("Failed to read clipboard history: %v", err)
	}

	if len(stale) > 0 {
		go m.deleteStaleEntries(stale)
	}

	return history
}

func (m *Manager) deleteStaleEntries(ids []uint64) {
	if m.db == nil {
		return
	}

	if err := m.db.Update(func(tx *bolt.Tx) error {
		b := tx.Bucket([]byte("clipboard"))
		for _, id := range ids {
			if err := b.Delete(itob(id)); err != nil {
				log.Errorf("Failed to delete stale entry %d: %v", id, err)
			}
		}
		return nil
	}); err != nil {
		log.Errorf("Failed to delete stale entries: %v", err)
	}
}

func (m *Manager) GetEntry(id uint64) (*Entry, error) {
	if m.db == nil {
		return nil, fmt.Errorf("database not available")
	}

	var entry Entry
	var found bool

	err := m.db.View(func(tx *bolt.Tx) error {
		b := tx.Bucket([]byte("clipboard"))
		v := b.Get(itob(id))
		if v == nil {
			return nil
		}

		var err error
		entry, err = decodeEntry(v)
		if err != nil {
			return err
		}
		found = true
		return nil
	})

	if err != nil {
		return nil, err
	}
	if !found {
		return nil, fmt.Errorf("entry not found")
	}

	return &entry, nil
}

func (m *Manager) DeleteEntry(id uint64) error {
	if m.db == nil {
		return fmt.Errorf("database not available")
	}

	err := m.db.Update(func(tx *bolt.Tx) error {
		b := tx.Bucket([]byte("clipboard"))
		return b.Delete(itob(id))
	})

	if err == nil {
		m.updateState()
		m.notifySubscribers()
	}

	return err
}

func (m *Manager) ClearHistory() {
	if m.db == nil {
		return
	}

	if err := m.db.Update(func(tx *bolt.Tx) error {
		if err := tx.DeleteBucket([]byte("clipboard")); err != nil {
			return err
		}
		_, err := tx.CreateBucket([]byte("clipboard"))
		return err
	}); err != nil {
		log.Errorf("Failed to clear clipboard history: %v", err)
		return
	}

	if err := m.compactDB(); err != nil {
		log.Errorf("Failed to compact database: %v", err)
	}

	m.updateState()
	m.notifySubscribers()
}

func (m *Manager) compactDB() error {
	m.db.Close()

	tmpPath := m.dbPath + ".compact"
	defer os.Remove(tmpPath)

	srcDB, err := bolt.Open(m.dbPath, 0644, &bolt.Options{ReadOnly: true, Timeout: time.Second})
	if err != nil {
		m.db, _ = bolt.Open(m.dbPath, 0644, &bolt.Options{Timeout: time.Second})
		return fmt.Errorf("open source: %w", err)
	}

	dstDB, err := bolt.Open(tmpPath, 0644, &bolt.Options{Timeout: time.Second})
	if err != nil {
		srcDB.Close()
		m.db, _ = bolt.Open(m.dbPath, 0644, &bolt.Options{Timeout: time.Second})
		return fmt.Errorf("open destination: %w", err)
	}

	if err := bolt.Compact(dstDB, srcDB, 0); err != nil {
		srcDB.Close()
		dstDB.Close()
		m.db, _ = bolt.Open(m.dbPath, 0644, &bolt.Options{Timeout: time.Second})
		return fmt.Errorf("compact: %w", err)
	}

	srcDB.Close()
	dstDB.Close()

	if err := os.Rename(tmpPath, m.dbPath); err != nil {
		m.db, _ = bolt.Open(m.dbPath, 0644, &bolt.Options{Timeout: time.Second})
		return fmt.Errorf("rename: %w", err)
	}

	m.db, err = bolt.Open(m.dbPath, 0644, &bolt.Options{Timeout: time.Second})
	if err != nil {
		return fmt.Errorf("reopen: %w", err)
	}

	return nil
}

func (m *Manager) SetClipboard(data []byte, mimeType string) error {
	if int64(len(data)) > m.config.MaxEntrySize {
		return fmt.Errorf("data too large")
	}

	dataCopy := make([]byte, len(data))
	copy(dataCopy, data)

	m.post(func() {
		if m.dataControlMgr == nil || m.dataDevice == nil {
			log.Error("Data control manager or device not initialized")
			return
		}

		dataMgr := m.dataControlMgr.(*ext_data_control.ExtDataControlManagerV1)

		source, err := dataMgr.CreateDataSource()
		if err != nil {
			log.Errorf("Failed to create data source: %v", err)
			return
		}

		if err := source.Offer(mimeType); err != nil {
			log.Errorf("Failed to offer mime type: %v", err)
			return
		}

		source.SetSendHandler(func(e ext_data_control.ExtDataControlSourceV1SendEvent) {
			fd := e.Fd
			defer syscall.Close(fd)

			file := os.NewFile(uintptr(fd), "clipboard-pipe")
			defer file.Close()

			if _, err := file.Write(dataCopy); err != nil {
				log.Errorf("Failed to write clipboard data: %v", err)
			}
		})

		m.currentSource = source
		m.sourceMutex.Lock()
		m.sourceMimeTypes = []string{mimeType}
		m.sourceMutex.Unlock()

		device := m.dataDevice.(*ext_data_control.ExtDataControlDeviceV1)
		if err := device.SetSelection(source); err != nil {
			log.Errorf("Failed to set selection: %v", err)
		}
	})

	return nil
}

func (m *Manager) CopyText(text string) error {
	if err := m.SetClipboard([]byte(text), "text/plain;charset=utf-8"); err != nil {
		return err
	}

	entry := Entry{
		Data:      []byte(text),
		MimeType:  "text/plain;charset=utf-8",
		Size:      len(text),
		Timestamp: time.Now(),
		IsImage:   false,
		Preview:   m.textPreview([]byte(text)),
	}

	if err := m.storeEntry(entry); err != nil {
		log.Errorf("Failed to store clipboard entry: %v", err)
	}

	m.updateState()
	m.notifySubscribers()

	return nil
}

func (m *Manager) PasteText() (string, error) {
	history := m.GetHistory()
	if len(history) == 0 {
		return "", fmt.Errorf("no clipboard data available")
	}

	entry := history[0]
	if entry.IsImage {
		return "", fmt.Errorf("clipboard contains image, not text")
	}

	fullEntry, err := m.GetEntry(entry.ID)
	if err != nil {
		return "", err
	}

	return string(fullEntry.Data), nil
}

func (m *Manager) Close() {
	if !m.alive {
		return
	}

	m.alive = false
	close(m.stopChan)

	close(m.dirty)
	m.notifierWg.Wait()

	m.subMutex.Lock()
	for _, ch := range m.subscribers {
		close(ch)
	}
	m.subscribers = make(map[string]chan State)
	m.subMutex.Unlock()

	if m.currentSource != nil {
		source := m.currentSource.(*ext_data_control.ExtDataControlSourceV1)
		source.Destroy()
	}

	if m.dataDevice != nil {
		device := m.dataDevice.(*ext_data_control.ExtDataControlDeviceV1)
		device.Destroy()
	}

	if m.dataControlMgr != nil {
		mgr := m.dataControlMgr.(*ext_data_control.ExtDataControlManagerV1)
		mgr.Destroy()
	}

	if m.registry != nil {
		m.registry.Destroy()
	}

	if m.db != nil {
		m.db.Close()
	}
}

func (m *Manager) clearHistoryInternal() error {
	return m.db.Update(func(tx *bolt.Tx) error {
		if err := tx.DeleteBucket([]byte("clipboard")); err != nil {
			return err
		}
		_, err := tx.CreateBucket([]byte("clipboard"))
		return err
	})
}

func (m *Manager) clearOldEntries(days int) error {
	cutoff := time.Now().AddDate(0, 0, -days)

	return m.db.Update(func(tx *bolt.Tx) error {
		b := tx.Bucket([]byte("clipboard"))
		if b == nil {
			return nil
		}

		var toDelete [][]byte
		c := b.Cursor()
		for k, v := c.First(); k != nil; k, v = c.Next() {
			entry, err := decodeEntry(v)
			if err != nil {
				continue
			}
			if entry.Timestamp.Before(cutoff) {
				toDelete = append(toDelete, k)
			}
		}

		for _, k := range toDelete {
			if err := b.Delete(k); err != nil {
				return err
			}
		}
		return nil
	})
}

func (m *Manager) migrateHashes() error {
	if m.db == nil {
		return nil
	}

	var needsMigration bool
	if err := m.db.View(func(tx *bolt.Tx) error {
		b := tx.Bucket([]byte("clipboard"))
		if b == nil {
			return nil
		}
		c := b.Cursor()
		for k, v := c.First(); k != nil; k, v = c.Next() {
			if extractHash(v) == 0 {
				needsMigration = true
				return nil
			}
		}
		return nil
	}); err != nil {
		return err
	}

	if !needsMigration {
		return nil
	}

	log.Info("Migrating clipboard entries to add hashes...")

	return m.db.Update(func(tx *bolt.Tx) error {
		b := tx.Bucket([]byte("clipboard"))
		if b == nil {
			return nil
		}

		var updates []struct {
			key   []byte
			entry Entry
		}

		c := b.Cursor()
		for k, v := c.First(); k != nil; k, v = c.Next() {
			entry, err := decodeEntry(v)
			if err != nil {
				continue
			}
			if entry.Hash != 0 {
				continue
			}
			entry.Hash = computeHash(entry.Data)
			keyCopy := make([]byte, len(k))
			copy(keyCopy, k)
			updates = append(updates, struct {
				key   []byte
				entry Entry
			}{keyCopy, entry})
		}

		for _, u := range updates {
			encoded, err := encodeEntry(u.entry)
			if err != nil {
				continue
			}
			if err := b.Put(u.key, encoded); err != nil {
				return err
			}
		}

		log.Infof("Migrated %d clipboard entries", len(updates))
		return nil
	})
}

func (m *Manager) Search(params SearchParams) SearchResult {
	if m.db == nil {
		return SearchResult{}
	}

	if params.Limit <= 0 {
		params.Limit = 50
	}
	if params.Limit > 500 {
		params.Limit = 500
	}

	query := strings.ToLower(params.Query)
	mimeFilter := strings.ToLower(params.MimeType)

	var all []Entry
	if err := m.db.View(func(tx *bolt.Tx) error {
		b := tx.Bucket([]byte("clipboard"))
		if b == nil {
			return nil
		}

		c := b.Cursor()
		for k, v := c.Last(); k != nil; k, v = c.Prev() {
			entry, err := decodeEntry(v)
			if err != nil {
				continue
			}

			if params.IsImage != nil && entry.IsImage != *params.IsImage {
				continue
			}

			if mimeFilter != "" && !strings.Contains(strings.ToLower(entry.MimeType), mimeFilter) {
				continue
			}

			if params.Before != nil && entry.Timestamp.Unix() >= *params.Before {
				continue
			}

			if params.After != nil && entry.Timestamp.Unix() <= *params.After {
				continue
			}

			if query != "" && !strings.Contains(strings.ToLower(entry.Preview), query) {
				continue
			}

			entry.Data = nil
			all = append(all, entry)
		}
		return nil
	}); err != nil {
		log.Errorf("Search failed: %v", err)
	}

	total := len(all)

	start := params.Offset
	if start > total {
		start = total
	}
	end := start + params.Limit
	if end > total {
		end = total
	}

	return SearchResult{
		Entries: all[start:end],
		Total:   total,
		HasMore: end < total,
	}
}

func (m *Manager) GetConfig() Config {
	return m.config
}

func (m *Manager) SetConfig(cfg Config) error {
	m.configMutex.Lock()
	m.config = cfg
	m.configMutex.Unlock()

	m.updateState()
	m.notifySubscribers()

	return SaveConfig(cfg)
}

func (m *Manager) getConfig() Config {
	m.configMutex.RLock()
	defer m.configMutex.RUnlock()
	return m.config
}

func (m *Manager) watchConfig() {
	if m.configPath == "" {
		return
	}

	watcher, err := fsnotify.NewWatcher()
	if err != nil {
		log.Warnf("Failed to create config watcher: %v", err)
		return
	}
	defer watcher.Close()

	configDir := filepath.Dir(m.configPath)
	if err := watcher.Add(configDir); err != nil {
		log.Warnf("Failed to watch config directory: %v", err)
		return
	}

	for {
		select {
		case <-m.stopChan:
			return
		case event, ok := <-watcher.Events:
			if !ok {
				return
			}
			if event.Name != m.configPath {
				continue
			}
			if event.Op&(fsnotify.Write|fsnotify.Create) == 0 {
				continue
			}
			newCfg := LoadConfig()
			m.applyConfigChange(newCfg)
		case err, ok := <-watcher.Errors:
			if !ok {
				return
			}
			log.Warnf("Config watcher error: %v", err)
		}
	}
}

func (m *Manager) applyConfigChange(newCfg Config) {
	m.configMutex.Lock()
	oldCfg := m.config
	m.config = newCfg
	m.configMutex.Unlock()

	switch {
	case newCfg.Disabled && !oldCfg.Disabled:
		log.Info("Clipboard tracking disabled")
	case !newCfg.Disabled && oldCfg.Disabled:
		log.Info("Clipboard tracking enabled")
	}

	m.updateState()
	m.notifySubscribers()
}

func (m *Manager) StoreData(data []byte, mimeType string) error {
	cfg := m.getConfig()

	if cfg.Disabled {
		return fmt.Errorf("clipboard tracking disabled")
	}

	if m.db == nil {
		return fmt.Errorf("database not available")
	}

	if len(data) == 0 {
		return nil
	}

	if int64(len(data)) > cfg.MaxEntrySize {
		return fmt.Errorf("data too large")
	}

	if len(bytes.TrimSpace(data)) == 0 {
		return nil
	}

	entry := Entry{
		Data:      data,
		MimeType:  mimeType,
		Size:      len(data),
		Timestamp: time.Now(),
		IsImage:   m.isImageMimeType(mimeType),
	}

	switch {
	case entry.IsImage:
		entry.Preview = m.imagePreview(data, mimeType)
	default:
		entry.Preview = m.textPreview(data)
	}

	if err := m.storeEntry(entry); err != nil {
		return err
	}

	m.updateState()
	m.notifySubscribers()

	return nil
}
