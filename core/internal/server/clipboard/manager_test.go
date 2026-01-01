package clipboard

import (
	"sync"
	"sync/atomic"
	"testing"
	"time"

	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/mock"

	mocks_wlcontext "github.com/AvengeMedia/DankMaterialShell/core/internal/mocks/wlcontext"
)

func TestEncodeDecodeEntry_Roundtrip(t *testing.T) {
	original := Entry{
		ID:        12345,
		Data:      []byte("hello world"),
		MimeType:  "text/plain;charset=utf-8",
		Preview:   "hello world",
		Size:      11,
		Timestamp: time.Now().Truncate(time.Second),
		IsImage:   false,
	}

	encoded, err := encodeEntry(original)
	assert.NoError(t, err)

	decoded, err := decodeEntry(encoded)
	assert.NoError(t, err)

	assert.Equal(t, original.ID, decoded.ID)
	assert.Equal(t, original.Data, decoded.Data)
	assert.Equal(t, original.MimeType, decoded.MimeType)
	assert.Equal(t, original.Preview, decoded.Preview)
	assert.Equal(t, original.Size, decoded.Size)
	assert.Equal(t, original.Timestamp.Unix(), decoded.Timestamp.Unix())
	assert.Equal(t, original.IsImage, decoded.IsImage)
}

func TestEncodeDecodeEntry_Image(t *testing.T) {
	original := Entry{
		ID:        99999,
		Data:      []byte{0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A},
		MimeType:  "image/png",
		Preview:   "[[ image 8 B png 100x100 ]]",
		Size:      8,
		Timestamp: time.Now().Truncate(time.Second),
		IsImage:   true,
	}

	encoded, err := encodeEntry(original)
	assert.NoError(t, err)

	decoded, err := decodeEntry(encoded)
	assert.NoError(t, err)

	assert.Equal(t, original.ID, decoded.ID)
	assert.Equal(t, original.Data, decoded.Data)
	assert.True(t, decoded.IsImage)
	assert.Equal(t, original.Preview, decoded.Preview)
}

func TestEncodeDecodeEntry_EmptyData(t *testing.T) {
	original := Entry{
		ID:        1,
		Data:      []byte{},
		MimeType:  "text/plain",
		Preview:   "",
		Size:      0,
		Timestamp: time.Now().Truncate(time.Second),
		IsImage:   false,
	}

	encoded, err := encodeEntry(original)
	assert.NoError(t, err)

	decoded, err := decodeEntry(encoded)
	assert.NoError(t, err)

	assert.Equal(t, original.ID, decoded.ID)
	assert.Empty(t, decoded.Data)
}

func TestEncodeDecodeEntry_LargeData(t *testing.T) {
	largeData := make([]byte, 100000)
	for i := range largeData {
		largeData[i] = byte(i % 256)
	}

	original := Entry{
		ID:        777,
		Data:      largeData,
		MimeType:  "application/octet-stream",
		Preview:   "binary data...",
		Size:      len(largeData),
		Timestamp: time.Now().Truncate(time.Second),
		IsImage:   false,
	}

	encoded, err := encodeEntry(original)
	assert.NoError(t, err)

	decoded, err := decodeEntry(encoded)
	assert.NoError(t, err)

	assert.Equal(t, original.Data, decoded.Data)
	assert.Equal(t, original.Size, decoded.Size)
}

func TestStateEqual_BothNil(t *testing.T) {
	assert.False(t, stateEqual(nil, nil))
}

func TestStateEqual_OneNil(t *testing.T) {
	s := &State{Enabled: true}
	assert.False(t, stateEqual(s, nil))
	assert.False(t, stateEqual(nil, s))
}

func TestStateEqual_EnabledDiffers(t *testing.T) {
	a := &State{Enabled: true, History: []Entry{}}
	b := &State{Enabled: false, History: []Entry{}}
	assert.False(t, stateEqual(a, b))
}

func TestStateEqual_HistoryLengthDiffers(t *testing.T) {
	a := &State{Enabled: true, History: []Entry{{ID: 1}}}
	b := &State{Enabled: true, History: []Entry{}}
	assert.False(t, stateEqual(a, b))
}

func TestStateEqual_BothEqual(t *testing.T) {
	a := &State{Enabled: true, History: []Entry{{ID: 1}, {ID: 2}}}
	b := &State{Enabled: true, History: []Entry{{ID: 3}, {ID: 4}}}
	assert.True(t, stateEqual(a, b))
}

func TestManager_ConcurrentSubscriberAccess(t *testing.T) {
	m := &Manager{
		subscribers: make(map[string]chan State),
		dirty:       make(chan struct{}, 1),
	}

	var wg sync.WaitGroup
	const goroutines = 20

	for i := 0; i < goroutines; i++ {
		wg.Add(1)
		go func(id int) {
			defer wg.Done()
			subID := string(rune('a' + id))
			ch := m.Subscribe(subID)
			assert.NotNil(t, ch)
			time.Sleep(time.Millisecond)
			m.Unsubscribe(subID)
		}(i)
	}

	wg.Wait()
}

func TestManager_ConcurrentGetState(t *testing.T) {
	m := &Manager{
		state: &State{
			Enabled: true,
			History: []Entry{{ID: 1}, {ID: 2}},
		},
	}

	var wg sync.WaitGroup
	const goroutines = 50
	const iterations = 100

	for i := 0; i < goroutines/2; i++ {
		wg.Add(1)
		go func() {
			defer wg.Done()
			for j := 0; j < iterations; j++ {
				s := m.GetState()
				_ = s.Enabled
				_ = len(s.History)
			}
		}()
	}

	for i := 0; i < goroutines/2; i++ {
		wg.Add(1)
		go func(i int) {
			defer wg.Done()
			for j := 0; j < iterations; j++ {
				m.stateMutex.Lock()
				m.state = &State{
					Enabled: j%2 == 0,
					History: []Entry{{ID: uint64(j)}},
				}
				m.stateMutex.Unlock()
			}
		}(i)
	}

	wg.Wait()
}

func TestManager_ConcurrentConfigAccess(t *testing.T) {
	m := &Manager{
		config: DefaultConfig(),
	}

	var wg sync.WaitGroup
	const goroutines = 30
	const iterations = 100

	for i := 0; i < goroutines/2; i++ {
		wg.Add(1)
		go func() {
			defer wg.Done()
			for j := 0; j < iterations; j++ {
				cfg := m.getConfig()
				_ = cfg.MaxHistory
				_ = cfg.MaxEntrySize
			}
		}()
	}

	for i := 0; i < goroutines/2; i++ {
		wg.Add(1)
		go func(i int) {
			defer wg.Done()
			for j := 0; j < iterations; j++ {
				m.configMutex.Lock()
				m.config.MaxHistory = 50 + j
				m.config.MaxEntrySize = int64(1024 * j)
				m.configMutex.Unlock()
			}
		}(i)
	}

	wg.Wait()
}

func TestManager_NotifySubscribersNonBlocking(t *testing.T) {
	m := &Manager{
		dirty: make(chan struct{}, 1),
	}

	for i := 0; i < 10; i++ {
		m.notifySubscribers()
	}

	assert.Len(t, m.dirty, 1)
}

func TestManager_ConcurrentOfferAccess(t *testing.T) {
	m := &Manager{
		offerMimeTypes: make(map[any][]string),
		offerRegistry:  make(map[uint32]any),
	}

	var wg sync.WaitGroup
	const goroutines = 20
	const iterations = 50

	for i := 0; i < goroutines; i++ {
		wg.Add(1)
		go func(id int) {
			defer wg.Done()
			key := uint32(id)

			for j := 0; j < iterations; j++ {
				m.offerMutex.Lock()
				m.offerRegistry[key] = struct{}{}
				m.offerMimeTypes[key] = []string{"text/plain"}
				m.offerMutex.Unlock()

				m.offerMutex.RLock()
				_ = m.offerRegistry[key]
				_ = m.offerMimeTypes[key]
				m.offerMutex.RUnlock()

				m.offerMutex.Lock()
				delete(m.offerRegistry, key)
				delete(m.offerMimeTypes, key)
				m.offerMutex.Unlock()
			}
		}(i)
	}

	wg.Wait()
}

func TestManager_ConcurrentPersistAccess(t *testing.T) {
	m := &Manager{
		persistData:      make(map[string][]byte),
		persistMimeTypes: []string{},
	}

	var wg sync.WaitGroup
	const goroutines = 20
	const iterations = 50

	for i := 0; i < goroutines/2; i++ {
		wg.Add(1)
		go func() {
			defer wg.Done()
			for j := 0; j < iterations; j++ {
				m.persistMutex.RLock()
				_ = m.persistData
				_ = m.persistMimeTypes
				m.persistMutex.RUnlock()
			}
		}()
	}

	for i := 0; i < goroutines/2; i++ {
		wg.Add(1)
		go func(id int) {
			defer wg.Done()
			for j := 0; j < iterations; j++ {
				m.persistMutex.Lock()
				m.persistMimeTypes = []string{"text/plain", "text/html"}
				m.persistData = map[string][]byte{
					"text/plain": []byte("test"),
				}
				m.persistMutex.Unlock()
			}
		}(i)
	}

	wg.Wait()
}

func TestManager_ConcurrentOwnerAccess(t *testing.T) {
	m := &Manager{}

	var wg sync.WaitGroup
	const goroutines = 30
	const iterations = 100

	for i := 0; i < goroutines/2; i++ {
		wg.Add(1)
		go func() {
			defer wg.Done()
			for j := 0; j < iterations; j++ {
				m.ownerLock.Lock()
				_ = m.isOwner
				m.ownerLock.Unlock()
			}
		}()
	}

	for i := 0; i < goroutines/2; i++ {
		wg.Add(1)
		go func() {
			defer wg.Done()
			for j := 0; j < iterations; j++ {
				m.ownerLock.Lock()
				m.isOwner = j%2 == 0
				m.ownerLock.Unlock()
			}
		}()
	}

	wg.Wait()
}

func TestItob(t *testing.T) {
	tests := []struct {
		input    uint64
		expected []byte
	}{
		{0, []byte{0, 0, 0, 0, 0, 0, 0, 0}},
		{1, []byte{0, 0, 0, 0, 0, 0, 0, 1}},
		{256, []byte{0, 0, 0, 0, 0, 0, 1, 0}},
		{0xFFFFFFFFFFFFFFFF, []byte{0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF}},
	}

	for _, tt := range tests {
		result := itob(tt.input)
		assert.Equal(t, tt.expected, result)
	}
}

func TestSizeStr(t *testing.T) {
	tests := []struct {
		input    int
		expected string
	}{
		{0, "0 B"},
		{100, "100 B"},
		{1024, "1 KiB"},
		{2048, "2 KiB"},
		{1048576, "1 MiB"},
		{5242880, "5 MiB"},
	}

	for _, tt := range tests {
		result := sizeStr(tt.input)
		assert.Equal(t, tt.expected, result)
	}
}

func TestSelectMimeType(t *testing.T) {
	m := &Manager{}

	tests := []struct {
		mimes    []string
		expected string
	}{
		{[]string{"text/plain;charset=utf-8", "text/html"}, "text/plain;charset=utf-8"},
		{[]string{"text/html", "text/plain"}, "text/plain"},
		{[]string{"text/html", "image/png"}, "image/png"},
		{[]string{"image/png", "image/jpeg"}, "image/png"},
		{[]string{"image/png"}, "image/png"},
		{[]string{"application/octet-stream"}, "application/octet-stream"},
		{[]string{}, ""},
	}

	for _, tt := range tests {
		result := m.selectMimeType(tt.mimes)
		assert.Equal(t, tt.expected, result)
	}
}

func TestIsImageMimeType(t *testing.T) {
	m := &Manager{}

	assert.True(t, m.isImageMimeType("image/png"))
	assert.True(t, m.isImageMimeType("image/jpeg"))
	assert.True(t, m.isImageMimeType("image/gif"))
	assert.False(t, m.isImageMimeType("text/plain"))
	assert.False(t, m.isImageMimeType("application/json"))
}

func TestTextPreview(t *testing.T) {
	m := &Manager{}

	short := m.textPreview([]byte("hello world"))
	assert.Equal(t, "hello world", short)

	withWhitespace := m.textPreview([]byte("  hello   world  "))
	assert.Equal(t, "hello world", withWhitespace)

	longText := make([]byte, 200)
	for i := range longText {
		longText[i] = 'a'
	}
	preview := m.textPreview(longText)
	assert.True(t, len(preview) > 100)
	assert.Contains(t, preview, "…")
}

func TestDefaultConfig(t *testing.T) {
	cfg := DefaultConfig()
	assert.Equal(t, 100, cfg.MaxHistory)
	assert.Equal(t, int64(5*1024*1024), cfg.MaxEntrySize)
	assert.Equal(t, 0, cfg.AutoClearDays)
	assert.False(t, cfg.ClearAtStartup)
	assert.False(t, cfg.Disabled)
}

func TestManager_PostDelegatesToWlContext(t *testing.T) {
	mockCtx := mocks_wlcontext.NewMockWaylandContext(t)

	var called atomic.Bool
	mockCtx.EXPECT().Post(mock.AnythingOfType("func()")).Run(func(fn func()) {
		called.Store(true)
		fn()
	}).Once()

	m := &Manager{
		wlCtx: mockCtx,
	}

	executed := false
	m.post(func() {
		executed = true
	})

	assert.True(t, called.Load())
	assert.True(t, executed)
}

func TestManager_PostExecutesFunctionViaContext(t *testing.T) {
	mockCtx := mocks_wlcontext.NewMockWaylandContext(t)

	var capturedFn func()
	mockCtx.EXPECT().Post(mock.AnythingOfType("func()")).Run(func(fn func()) {
		capturedFn = fn
	}).Times(3)

	m := &Manager{
		wlCtx: mockCtx,
	}

	counter := 0
	m.post(func() { counter++ })
	m.post(func() { counter += 10 })
	m.post(func() { counter += 100 })

	assert.NotNil(t, capturedFn)
	capturedFn()
	assert.Equal(t, 100, counter)
}

func TestManager_ConcurrentPostWithMock(t *testing.T) {
	mockCtx := mocks_wlcontext.NewMockWaylandContext(t)

	var postCount atomic.Int32
	mockCtx.EXPECT().Post(mock.AnythingOfType("func()")).Run(func(fn func()) {
		postCount.Add(1)
	}).Times(100)

	m := &Manager{
		wlCtx: mockCtx,
	}

	var wg sync.WaitGroup
	for i := 0; i < 10; i++ {
		wg.Add(1)
		go func() {
			defer wg.Done()
			for j := 0; j < 10; j++ {
				m.post(func() {})
			}
		}()
	}

	wg.Wait()
	assert.Equal(t, int32(100), postCount.Load())
}
