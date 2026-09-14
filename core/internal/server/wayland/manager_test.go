package wayland

import (
	"errors"
	"os"
	"path/filepath"
	"sync"
	"testing"
	"time"

	"github.com/stretchr/testify/assert"

	"github.com/AvengeMedia/DankMaterialShell/core/internal/icc"
	mocks_wlclient "github.com/AvengeMedia/DankMaterialShell/core/internal/mocks/wlclient"
	"github.com/AvengeMedia/DankMaterialShell/core/internal/proto/wlr_gamma_control"
)

func TestManager_ActorSerializesOutputStateAccess(t *testing.T) {
	m := &Manager{
		cmdq:     make(chan cmd, 8192),
		stopChan: make(chan struct{}),
	}

	m.wg.Add(1)
	go m.waylandActor()

	state := &outputState{
		id:           1,
		registryName: 100,
		rampSize:     256,
	}
	m.outputs.Store(state.id, state)

	var wg sync.WaitGroup
	const goroutines = 50
	const iterations = 100

	for i := range goroutines {
		wg.Add(1)
		go func(id int) {
			defer wg.Done()
			for j := range iterations {
				m.post(func() {
					if out, ok := m.outputs.Load(state.id); ok {
						out.rampSize = uint32(j)
						out.failed = j%2 == 0
						out.retryCount = j
						out.lastFailTime = time.Now()
					}
				})
			}
		}(i)
	}

	wg.Wait()

	done := make(chan struct{})
	m.post(func() { close(done) })
	<-done

	close(m.stopChan)
	m.wg.Wait()
}

func TestManager_ConcurrentSubscriberAccess(t *testing.T) {
	m := &Manager{
		stopChan:      make(chan struct{}),
		dirty:         make(chan struct{}, 1),
		updateTrigger: make(chan struct{}, 1),
	}

	var wg sync.WaitGroup
	const goroutines = 20

	for i := range goroutines {
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
			CurrentTemp: 5000,
			IsDay:       true,
		},
	}

	var wg sync.WaitGroup
	const goroutines = 50
	const iterations = 100

	for range goroutines / 2 {
		wg.Go(func() {
			for range iterations {
				s := m.GetState()
				assert.GreaterOrEqual(t, s.CurrentTemp, 0)
			}
		})
	}

	for i := range goroutines / 2 {
		wg.Add(1)
		go func(i int) {
			defer wg.Done()
			for j := range iterations {
				m.stateMutex.Lock()
				m.state = &State{
					CurrentTemp: 4000 + i*100,
					IsDay:       j%2 == 0,
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

	for range goroutines / 2 {
		wg.Go(func() {
			for range iterations {
				m.configMutex.RLock()
				_ = m.config.LowTemp
				_ = m.config.HighTemp
				_ = m.config.Enabled
				m.configMutex.RUnlock()
			}
		})
	}

	for i := range goroutines / 2 {
		wg.Add(1)
		go func(i int) {
			defer wg.Done()
			for j := range iterations {
				m.configMutex.Lock()
				m.config.LowTemp = 3000 + j
				m.config.HighTemp = 7000 - j
				m.config.Enabled = j%2 == 0
				m.configMutex.Unlock()
			}
		}(i)
	}

	wg.Wait()
}

func TestManager_SyncmapOutputsConcurrentAccess(t *testing.T) {
	m := &Manager{}

	var wg sync.WaitGroup
	const goroutines = 30
	const iterations = 50

	for i := range goroutines {
		wg.Add(1)
		go func(id int) {
			defer wg.Done()
			key := uint32(id)

			for j := range iterations {
				state := &outputState{
					id:       key,
					rampSize: uint32(j),
					failed:   j%2 == 0,
				}
				m.outputs.Store(key, state)

				if loaded, ok := m.outputs.Load(key); ok {
					assert.Equal(t, key, loaded.id)
				}

				m.outputs.Range(func(k uint32, v *outputState) bool {
					_ = v.rampSize
					_ = v.failed
					return true
				})
			}

			m.outputs.Delete(key)
		}(i)
	}

	wg.Wait()
}

func TestManager_LocationCacheConcurrentAccess(t *testing.T) {
	m := &Manager{}

	var wg sync.WaitGroup
	const goroutines = 20
	const iterations = 100

	for range goroutines / 2 {
		wg.Go(func() {
			for range iterations {
				m.locationMutex.RLock()
				_ = m.cachedIPLat
				_ = m.cachedIPLon
				m.locationMutex.RUnlock()
			}
		})
	}

	for i := range goroutines / 2 {
		wg.Add(1)
		go func(i int) {
			defer wg.Done()
			for j := range iterations {
				lat := float64(40 + i)
				lon := float64(-74 + j)
				m.locationMutex.Lock()
				m.cachedIPLat = &lat
				m.cachedIPLon = &lon
				m.locationMutex.Unlock()
			}
		}(i)
	}

	wg.Wait()
}

func TestManager_ScheduleConcurrentAccess(t *testing.T) {
	now := time.Now()
	m := &Manager{
		schedule: sunSchedule{
			times: SunTimes{
				Dawn:    now,
				Sunrise: now.Add(time.Hour),
				Sunset:  now.Add(12 * time.Hour),
				Night:   now.Add(13 * time.Hour),
			},
		},
	}

	var wg sync.WaitGroup
	const goroutines = 20
	const iterations = 100

	for range goroutines / 2 {
		wg.Go(func() {
			for range iterations {
				m.scheduleMutex.RLock()
				_ = m.schedule.times.Dawn
				_ = m.schedule.times.Sunrise
				_ = m.schedule.times.Sunset
				_ = m.schedule.condition
				m.scheduleMutex.RUnlock()
			}
		})
	}

	for range goroutines / 2 {
		wg.Go(func() {
			for range iterations {
				m.scheduleMutex.Lock()
				m.schedule.times.Dawn = time.Now()
				m.schedule.times.Sunrise = time.Now().Add(time.Hour)
				m.schedule.condition = SunNormal
				m.scheduleMutex.Unlock()
			}
		})
	}

	wg.Wait()
}

func TestInterpolate_EdgeCases(t *testing.T) {
	now := time.Now()

	tests := []struct {
		name     string
		now      time.Time
		start    time.Time
		stop     time.Time
		expected float64
	}{
		{
			name:     "same start and stop",
			now:      now,
			start:    now,
			stop:     now,
			expected: 1.0,
		},
		{
			name:     "now before start",
			now:      now,
			start:    now.Add(time.Hour),
			stop:     now.Add(2 * time.Hour),
			expected: 0.0,
		},
		{
			name:     "now after stop",
			now:      now.Add(3 * time.Hour),
			start:    now,
			stop:     now.Add(time.Hour),
			expected: 1.0,
		},
		{
			name:     "now at midpoint",
			now:      now.Add(30 * time.Minute),
			start:    now,
			stop:     now.Add(time.Hour),
			expected: 0.5,
		},
		{
			name:     "now equals start",
			now:      now,
			start:    now,
			stop:     now.Add(time.Hour),
			expected: 0.0,
		},
		{
			name:     "now equals stop",
			now:      now.Add(time.Hour),
			start:    now,
			stop:     now.Add(time.Hour),
			expected: 1.0,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			result := interpolate(tt.now, tt.start, tt.stop)
			assert.InDelta(t, tt.expected, result, 0.01)
		})
	}
}

func TestGenerateGammaRamp_ZeroSize(t *testing.T) {
	ramp := GenerateGammaRamp(0, 5000, 1.0, 1.0)
	assert.Empty(t, ramp.Red)
	assert.Empty(t, ramp.Green)
	assert.Empty(t, ramp.Blue)
}

func TestGenerateGammaRamp_ValidSizes(t *testing.T) {
	sizes := []uint32{1, 256, 1024}
	temps := []int{1000, 4000, 6500, 10000}
	gammas := []float64{0.5, 1.0, 2.0}

	for _, size := range sizes {
		for _, temp := range temps {
			for _, gamma := range gammas {
				ramp := GenerateGammaRamp(size, temp, gamma, 1.0)
				assert.Len(t, ramp.Red, int(size))
				assert.Len(t, ramp.Green, int(size))
				assert.Len(t, ramp.Blue, int(size))
			}
		}
	}
}

func TestNotifySubscribers_NonBlocking(t *testing.T) {
	m := &Manager{
		dirty: make(chan struct{}, 1),
	}

	for range 10 {
		m.notifySubscribers()
	}

	assert.Len(t, m.dirty, 1)
}

func TestNewManager_GetRegistryError(t *testing.T) {
	mockDisplay := mocks_wlclient.NewMockWaylandDisplay(t)

	mockDisplay.EXPECT().Context().Return(nil)
	mockDisplay.EXPECT().GetRegistry().Return(nil, errors.New("failed to get registry"))

	config := DefaultConfig()
	_, err := NewManager(mockDisplay, config)
	assert.Error(t, err)
	assert.Contains(t, err.Error(), "get registry")
}

func TestNewManager_InvalidConfig(t *testing.T) {
	mockDisplay := mocks_wlclient.NewMockWaylandDisplay(t)

	config := Config{
		LowTemp:  500,
		HighTemp: 6500,
		Gamma:    1.0,
		Contrast: 1.0,
	}

	_, err := NewManager(mockDisplay, config)
	assert.Error(t, err)
}

func TestSetters_RejectedValuesLeaveConfigUntouched(t *testing.T) {
	newManager := func() *Manager {
		return &Manager{
			config:        DefaultConfig(),
			updateTrigger: make(chan struct{}, 1),
		}
	}

	t.Run("SetTemperature", func(t *testing.T) {
		m := newManager()
		before := m.config

		err := m.SetTemperature(3200, 2500)
		assert.Error(t, err)
		assert.Equal(t, before, m.config)
		assert.Empty(t, m.updateTrigger)
	})

	t.Run("SetLocation", func(t *testing.T) {
		m := newManager()
		before := m.config

		err := m.SetLocation(120.0, 10.0)
		assert.Error(t, err)
		assert.Equal(t, before, m.config)
		assert.Empty(t, m.updateTrigger)
	})

	t.Run("SetAdjustments", func(t *testing.T) {
		m := newManager()
		before := m.config

		err := m.SetAdjustments(-1.0, 1.0)
		assert.Error(t, err)
		assert.Equal(t, before, m.config)
		assert.Empty(t, m.updateTrigger)
	})
}

func TestSetters_ValidValuesCommitAndTrigger(t *testing.T) {
	m := &Manager{
		config:        DefaultConfig(),
		updateTrigger: make(chan struct{}, 1),
	}

	err := m.SetTemperature(3000, 6000)
	assert.NoError(t, err)
	assert.Equal(t, 3000, m.config.LowTemp)
	assert.Equal(t, 6000, m.config.HighTemp)
	assert.Len(t, m.updateTrigger, 1)
}

func TestApplyGamma_SkipsUnchangedTempAndGamma(t *testing.T) {
	m := &Manager{config: DefaultConfig()}
	m.controlsInitialized = true

	out := &outputState{
		id:           1,
		rampSize:     256,
		gammaControl: &wlr_gamma_control.ZwlrGammaControlV1{},
		lastTemp:     5000,
		lastGamma:    m.config.Gamma,
	}
	m.outputs.Store(out.id, out)

	m.applyGamma(5000)

	assert.False(t, out.failed, "unchanged temp must not reach the compositor write path")
	assert.Equal(t, 5000, out.lastTemp)
	assert.Equal(t, uint32(256), out.rampSize)
}

func TestNeedsControls(t *testing.T) {
	tests := []struct {
		name     string
		enabled  bool
		gamma    float64
		contrast float64
		want     bool
	}{
		{"all_neutral_disabled", false, 1.0, 1.0, false},
		{"enabled", true, 1.0, 1.0, true},
		{"gamma_only", false, 1.2, 1.0, true},
		{"contrast_only", false, 1.0, 1.3, true},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			cfg := DefaultConfig()
			cfg.Enabled = tt.enabled
			cfg.Gamma = tt.gamma
			cfg.Contrast = tt.contrast
			m := &Manager{config: cfg}
			assert.Equal(t, tt.want, m.needsControls())
		})
	}
}

func TestSetAdjustments_UnchangedValuesDoNotTouchActor(t *testing.T) {
	m := &Manager{config: DefaultConfig(), cmdq: make(chan cmd, 1)}

	assert.NoError(t, m.SetAdjustments(1.0, 1.0))
	assert.Empty(t, m.cmdq, "neutral defaults resent must not schedule any work")

	assert.Error(t, m.SetAdjustments(1.0, 3.0))
	assert.Equal(t, DefaultConfig(), m.config)
	assert.Empty(t, m.cmdq)

	assert.NoError(t, m.SetAdjustments(1.2, 1.5))
	assert.Equal(t, 1.2, m.config.Gamma)
	assert.Equal(t, 1.5, m.config.Contrast)
	assert.Len(t, m.cmdq, 1, "one change must schedule exactly one sync")

	assert.NoError(t, m.SetAdjustments(1.2, 1.5))
	assert.Len(t, m.cmdq, 1, "resending the same values must not schedule more work")
}

func TestOutputState_RampCurrent(t *testing.T) {
	out := &outputState{lastTemp: 5000, lastGamma: 1.0, lastContrast: 1.0}

	assert.True(t, out.rampCurrent(5000, 1.0, 1.0))
	assert.False(t, out.rampCurrent(4500, 1.0, 1.0))
	assert.False(t, out.rampCurrent(5000, 1.2, 1.0))
	assert.False(t, out.rampCurrent(5000, 1.0, 1.4))
}

// needsControls decides whether gamma controls are created at all. ICC
// profiles and per-output temperatures apply independently of the night light
// schedule, so they have to keep the controls alive: otherwise turning the
// night light off tears the controls down and drops the ICC ramps.
func TestManager_NeedsControlsCoversICCAndOutputTemps(t *testing.T) {
	base := Config{Enabled: false, Gamma: 1.0, Contrast: 1.0}

	cases := []struct {
		name string
		cfg  Config
		want bool
	}{
		{"idle", base, false},
		{"night light on", Config{Enabled: true, Gamma: 1.0, Contrast: 1.0}, true},
		{"gamma tweak", Config{Gamma: 1.2, Contrast: 1.0}, true},
		{"contrast tweak", Config{Gamma: 1.0, Contrast: 1.2}, true},
		{"icc profile only", Config{Gamma: 1.0, Contrast: 1.0, ICCProfiles: map[string]string{"DP-1": "/tmp/display.icc"}}, true},
		{"output temp only", Config{Gamma: 1.0, Contrast: 1.0, OutputTemps: map[string]int{"DP-1": 7000}}, true},
	}

	for _, tc := range cases {
		t.Run(tc.name, func(t *testing.T) {
			m := &Manager{config: tc.cfg}
			assert.Equal(t, tc.want, m.needsControls())
		})
	}
}

// The registry handler can establish the gamma controls before the startup post
// runs, so loading the configured ICC profiles and temperatures must not depend
// on the controls still being uninitialized.
func TestManager_LoadConfiguredICCWhenControlsAlreadyExist(t *testing.T) {
	dir := t.TempDir()
	m := &Manager{config: Config{
		ICCProfiles: map[string]string{"DP-2": filepath.Join(dir, "missing.icm")},
		OutputTemps: map[string]int{"DP-1": 7000},
	}}
	m.controlsInitialized = true

	dp1 := &outputState{id: 1}
	m.outputs.Store(1, dp1)
	m.outputNames.Store(1, "DP-1")

	dp2 := &outputState{id: 2}
	m.outputs.Store(2, dp2)
	m.outputNames.Store(2, "DP-2")

	if !m.loadConfiguredICC() {
		t.Fatal("loadConfiguredICC() = false, want true")
	}
	assert.Equal(t, 7000, dp1.outputTemp, "configured temperature should attach")

	// An unreadable profile must be skipped without aborting the rest.
	assert.Empty(t, dp2.iccPath, "unparsable profile should not attach")
}

// A hotplugged output gets its configured profile and temperature attached as
// soon as its name is known.
func TestManager_AttachConfiguredICCForNamedOutput(t *testing.T) {
	m := &Manager{config: Config{OutputTemps: map[string]int{"DP-3": 6500}}}

	configured := &outputState{id: 3}
	m.outputs.Store(3, configured)
	m.outputNames.Store(3, "DP-3")

	m.attachConfiguredICC(3, "DP-3")
	assert.Equal(t, 6500, configured.outputTemp)

	plain := &outputState{id: 4}
	m.outputs.Store(4, plain)
	m.attachConfiguredICC(4, "HDMI-A-1")
	assert.Zero(t, plain.outputTemp, "outputs without configuration are left alone")
}

// Each display can keep its own temperature: a per-output override wins over the
// night light schedule, and 0 means "no override" rather than 0K.
func TestEffectiveTempTarget(t *testing.T) {
	cases := []struct {
		name         string
		outputTemp   int
		scheduleTemp int
		want         int
	}{
		{"override wins over the schedule", 7000, 5000, 7000},
		{"override applies without a schedule", 7000, noTempTarget, 7000},
		{"schedule applies without an override", 0, 5000, 5000},
		{"neither configured", 0, noTempTarget, noTempTarget},
	}

	for _, tc := range cases {
		t.Run(tc.name, func(t *testing.T) {
			out := &outputState{outputTemp: tc.outputTemp}
			assert.Equal(t, tc.want, effectiveTempTarget(out, tc.scheduleTemp))
		})
	}
}

// A re-created gamma control (night light toggled, outputs re-enumerated) must
// not drop the configured ICC state of the output it belongs to.
func TestManager_ControlStateReuseKeepsAttachedICC(t *testing.T) {
	m := &Manager{}
	existing := &outputState{
		id:           1,
		registryName: 10,
		iccPath:      "/tmp/display.icm",
		iccProfile:   &icc.Profile{Description: "Test Display"},
		outputTemp:   7000,
		rampSize:     256,
		failed:       true,
		retryCount:   3,
		lastFailTime: time.Now(),
		lastTemp:     7000,
		lastGamma:    1.1,
		lastContrast: 0.9,
	}
	m.outputs.Store(1, existing)

	got := m.controlStateFor(1, 10, nil, "control-2")

	assert.Same(t, existing, got, "the output keeps its state across control re-creation")
	assert.Equal(t, "/tmp/display.icm", got.iccPath, "the attached profile survives")
	assert.Equal(t, 7000, got.outputTemp, "the per-output temperature survives")
	assert.Equal(t, "control-2", got.gammaControl, "the new control is attached")

	assert.Zero(t, got.rampSize, "the new control has not reported gamma_size yet")
	assert.False(t, got.failed)
	assert.Zero(t, got.retryCount)
	assert.Zero(t, got.lastTemp, "the ramp has to be written again")

	fresh := m.controlStateFor(2, 20, nil, "control-3")
	assert.NotSame(t, existing, fresh)
	assert.Empty(t, fresh.iccPath, "an output seen for the first time starts clean")
	assert.Zero(t, fresh.outputTemp)
}

// The status payload is what the settings UI shows for a profile, so the
// descriptive metadata has to be carried through.
func TestManager_GetICCStatusDescribesProfile(t *testing.T) {
	dir := t.TempDir()
	profilePath := filepath.Join(dir, "display.icm")
	if err := os.WriteFile(profilePath, []byte("stub"), 0o644); err != nil {
		t.Fatalf("write stub profile: %v", err)
	}

	gamma := icc.Curve{Type: icc.CurveParametric, Gamma: 2.2}
	m := &Manager{}
	m.outputs.Store(1, &outputState{
		id:      1,
		iccPath: profilePath,
		iccProfile: &icc.Profile{
			Description: "Test Display",
			Version:     "2.1.0",
			Class:       "mntr",
			ColorSpace:  "RGB",
			HasTRC:      true,
			TRC:         [3]icc.Curve{gamma, gamma, gamma},
			HasVCGT:     true,
			VCGT:        &icc.VCGT{Channels: 3, Entries: 1024},
			WhitePoint:  [3]float64{0.9505, 1.0, 1.0890},
		},
	})
	m.outputNames.Store(1, "DP-2")
	m.publishICCState()

	status := m.GetICCStatus()["DP-2"]
	if status == nil {
		t.Fatal("no status for DP-2")
	}

	assert.True(t, status.Active)
	assert.Equal(t, "mntr", status.Class)
	assert.Equal(t, "gamma", status.TRCKind)
	assert.Equal(t, 2.2, status.TRCGamma)
	assert.Equal(t, 3, status.VCGTChannels)
	assert.Equal(t, 1024, status.VCGTEntries)
	assert.Equal(t, "D65", status.WhitePointName)
	assert.Equal(t, int64(4), status.Size)
	assert.NotZero(t, status.Modified)
}

// The exported getters serve the published snapshot, so callers on other
// goroutines (IPC handlers, the scheduler) never read the per-output fields the
// actor mutates. A profile therefore appears in the status only once the actor
// has published it, and an empty snapshot has to clear the previous one.
func TestManager_ICCStatusServesPublishedSnapshot(t *testing.T) {
	m := &Manager{}
	out := &outputState{id: 1, iccPath: "/tmp/display.icm", outputTemp: 7000}
	m.outputs.Store(1, out)
	m.outputNames.Store(1, "DP-1")

	assert.Empty(t, m.GetICCStatus(), "nothing is published before the first publish")
	assert.Empty(t, m.GetOutputTemps())

	m.publishICCState()
	assert.Contains(t, m.GetICCStatus(), "DP-1")
	assert.Equal(t, 7000, m.GetOutputTemps()["DP-1"])

	// A mutation the actor has not published yet is invisible to callers.
	out.outputTemp = 5000
	out.iccPath = ""
	assert.Equal(t, 7000, m.GetOutputTemps()["DP-1"])

	m.publishICCState()
	assert.Equal(t, 5000, m.GetOutputTemps()["DP-1"])
	assert.Empty(t, m.GetICCStatus(), "the removed profile is gone from the snapshot")
}

// Outputs that go away (unplugged, monitor sleep) must not stay in the name
// maps: they are what `dms icc listOutputs` and `status` enumerate, and a
// rebound wl_output reusing the object ID would attach the previous monitor's
// profile from the stale name.
func TestManager_RemoveOutputByRegistryNamePrunesNames(t *testing.T) {
	m := &Manager{}
	out := &outputState{id: 7, registryName: 42, iccPath: "/tmp/display.icm", outputTemp: 6500}
	m.outputs.Store(7, out)
	m.outputNames.Store(7, "DP-1")
	m.outputRegNames.Store(7, 42)
	m.controlsInitialized = true
	m.publishICCState()

	m.removeOutputByRegistryName(42)

	_, stillStored := m.outputs.Load(7)
	assert.False(t, stillStored, "the output state should be gone")
	_, nameStored := m.outputNames.Load(7)
	assert.False(t, nameStored, "the output name should be gone")
	_, regNameStored := m.outputRegNames.Load(7)
	assert.False(t, regNameStored, "the registry name should be gone")
	assert.Empty(t, m.ListOutputs(), "a disconnected monitor must not be listed")
	assert.Empty(t, m.GetICCStatus(), "nor reported as a profiled output")
	assert.Empty(t, m.GetOutputTemps())
	assert.False(t, m.controlsInitialized, "the last output going away clears the controls")

	// A registry name that no output uses is a no-op.
	m.removeOutputByRegistryName(99)
}

// The getters are called from the scheduler and the IPC handlers while the
// actor publishes, so they must not share unsynchronised state with it (run
// with -race).
func TestManager_ICCStatusConcurrentPublishAndRead(t *testing.T) {
	m := &Manager{}
	out := &outputState{id: 1, iccPath: "/tmp/display.icm"}
	m.outputs.Store(1, out)
	m.outputNames.Store(1, "DP-1")

	var wg sync.WaitGroup
	wg.Add(1)
	go func() {
		defer wg.Done()
		for i := range 500 {
			out.outputTemp = 6000 + i
			out.iccProfile = nil
			m.publishICCState()
		}
	}()

	for range 500 {
		_ = m.GetICCStatus()
		_ = m.GetOutputTemps()
		_ = m.ListOutputs()
	}
	wg.Wait()
}
