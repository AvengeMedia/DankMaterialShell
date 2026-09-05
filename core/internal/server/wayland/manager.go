package wayland

import (
	"bytes"
	"encoding/binary"
	"errors"
	"fmt"
	"io"
	"os"
	"slices"
	"syscall"
	"time"

	"github.com/AvengeMedia/dankgo/boottimer"
	wlclient "github.com/AvengeMedia/dankgo/wayland/client"
	"github.com/godbus/dbus/v5"

	"github.com/AvengeMedia/DankMaterialShell/core/internal/errdefs"
	"github.com/AvengeMedia/DankMaterialShell/core/internal/geolocation"
	"github.com/AvengeMedia/DankMaterialShell/core/internal/log"
	"github.com/AvengeMedia/DankMaterialShell/core/internal/proto/wlr_gamma_control"
	"github.com/AvengeMedia/DankMaterialShell/core/internal/wayland/shm"
)

const animKelvinStep = 25

const neutralTemp = 6500

func NewManager(display wlclient.WaylandDisplay, config Config) (*Manager, error) {
	if err := config.Validate(); err != nil {
		return nil, err
	}

	if config.ElevationTwilight == 0 {
		config.ElevationTwilight = -6.0
	}
	if config.ElevationDaylight == 0 {
		config.ElevationDaylight = 3.0
	}

	m := &Manager{
		config:        config,
		display:       display,
		ctx:           display.Context(),
		cmdq:          make(chan cmd, 128),
		stopChan:      make(chan struct{}),
		updateTrigger: make(chan struct{}, 1),
		dirty:         make(chan struct{}, 1),
		dbusSignal:    make(chan *dbus.Signal, 16),
	}

	if err := m.setupRegistry(); err != nil {
		return nil, err
	}

	if err := m.setupDBusMonitor(); err != nil {
		log.Warnf("Failed to setup D-Bus monitoring: %v", err)
	}

	m.alive = true
	m.recalcSchedule(time.Now())
	m.updateStateFromSchedule()

	m.notifierWg.Add(1)
	go m.notifier()

	m.wg.Add(1)
	go m.schedulerLoop()

	if m.dbusConn != nil {
		m.wg.Add(1)
		go m.dbusMonitor()
	}

	m.wg.Add(1)
	go m.waylandActor()

	if m.needsControls() {
		m.post(func() {
			if m.controlsInitialized {
				return
			}
			log.Info("Gamma control enabled at startup")
			m.createControls()
		})
	}

	return m, nil
}

func (m *Manager) post(fn func()) {
	select {
	case m.cmdq <- cmd{fn: fn}:
	default:
		log.Warn("Actor command queue full")
	}
}

func (m *Manager) waylandActor() {
	defer m.wg.Done()
	for {
		select {
		case <-m.stopChan:
			return
		case c := <-m.cmdq:
			c.fn()
		}
	}
}

func (m *Manager) anyOutputReady() bool {
	anyReady := false
	m.outputs.Range(func(_ uint32, out *outputState) bool {
		if out.rampSize > 0 && !out.failed {
			anyReady = true
			return false // stop iteration
		}
		return true
	})
	return anyReady
}

const prepareForSleepMatchRule = "type='signal',interface='org.freedesktop.login1.Manager',member='PrepareForSleep',path='/org/freedesktop/login1'"

func (m *Manager) setupDBusMonitor() error {
	conn, err := dbus.SystemBus()
	if err != nil {
		return fmt.Errorf("system bus: %w", err)
	}

	if err := conn.BusObject().Call("org.freedesktop.DBus.AddMatch", 0, prepareForSleepMatchRule).Err; err != nil {
		return fmt.Errorf("add match: %w", err)
	}

	conn.Signal(m.dbusSignal)
	m.dbusConn = conn
	return nil
}

func (m *Manager) setupRegistry() error {
	registry, err := m.display.GetRegistry()
	if err != nil {
		return fmt.Errorf("get registry: %w", err)
	}
	m.registry = registry

	outputs := make([]*wlclient.Output, 0)
	outputNames := make(map[uint32]string)
	var gammaMgr *wlr_gamma_control.ZwlrGammaControlManagerV1

	registry.SetGlobalHandler(func(e wlclient.RegistryGlobalEvent) {
		switch e.Interface {
		case wlr_gamma_control.ZwlrGammaControlManagerV1InterfaceName:
			manager := wlr_gamma_control.NewZwlrGammaControlManagerV1(m.ctx)
			version := min(e.Version, 1)
			if err := registry.Bind(e.Name, e.Interface, version, manager); err == nil {
				gammaMgr = manager
			}
		case "wl_output":
			output := wlclient.NewOutput(m.ctx)
			version := min(e.Version, 4)
			if err := registry.Bind(e.Name, e.Interface, version, output); err != nil {
				return
			}
			outputID := output.ID()
			output.SetNameHandler(func(ev wlclient.OutputNameEvent) {
				outputNames[outputID] = ev.Name
			})
			if gammaMgr != nil {
				outputs = append(outputs, output)
				m.addAvailableOutput(output)
			}
			m.outputRegNames.Store(outputID, e.Name)

			if !m.needsControls() {
				return
			}
			m.post(func() {
				if err := m.addOutputControl(output); err != nil {
					log.Warnf("gamma: failed to add output control: %v", err)
					return
				}
				if m.controlsInitialized {
					return
				}
				// All outputs had been torn down (monitor sleep/disconnect),
				// clearing controlsInitialized. Mark it ready again so the
				// gamma_size event that follows control creation drives the
				// reapply, instead of waiting for a manual toggle. No explicit
				// apply here: applyGamma's dedup would suppress a no-change
				// write anyway, and the new control isn't ready until gamma_size.
				log.Info("gamma: output returned, re-establishing controls")
				m.controlsInitialized = true
			})
		}
	})

	registry.SetGlobalRemoveHandler(func(e wlclient.RegistryGlobalRemoveEvent) {
		m.post(func() {
			var foundID uint32
			var foundOut *outputState
			m.outputs.Range(func(id uint32, out *outputState) bool {
				if out.registryName == e.Name {
					foundID = id
					foundOut = out
					return false
				}
				return true
			})
			if foundOut == nil {
				return
			}
			if foundOut.gammaControl != nil {
				foundOut.gammaControl.(*wlr_gamma_control.ZwlrGammaControlV1).Destroy()
				foundOut.gammaControl = nil
			}
			m.removeAvailableOutput(foundOut.output)
			if foundOut.output != nil && !foundOut.output.IsZombie() {
				_ = foundOut.output.Release()
			}
			m.outputs.Delete(foundID)

			hasOutputs := false
			m.outputs.Range(func(_ uint32, _ *outputState) bool {
				hasOutputs = true
				return false
			})
			if !hasOutputs {
				m.controlsInitialized = false
			}
		})
	})

	if err := m.display.Roundtrip(); err != nil {
		return fmt.Errorf("roundtrip 1: %w", err)
	}
	if err := m.display.Roundtrip(); err != nil {
		return fmt.Errorf("roundtrip 2: %w", err)
	}

	if gammaMgr == nil {
		return errdefs.ErrNoGammaControl
	}
	if len(outputs) == 0 {
		return fmt.Errorf("no outputs")
	}

	physicalOutputs := make([]*wlclient.Output, 0, len(outputs))
	for _, output := range outputs {
		name := outputNames[output.ID()]
		if len(name) >= 9 && name[:9] == "HEADLESS-" {
			continue
		}
		physicalOutputs = append(physicalOutputs, output)
	}

	m.gammaControl = gammaMgr
	m.availableOutputs = physicalOutputs
	return nil
}

func (m *Manager) setupOutputControls(outputs []*wlclient.Output, manager *wlr_gamma_control.ZwlrGammaControlManagerV1) error {
	for _, output := range outputs {
		control, err := manager.GetGammaControl(output)
		if err != nil {
			continue
		}
		outputID := output.ID()
		registryName, _ := m.outputRegNames.Load(outputID)
		outState := &outputState{
			id:           outputID,
			registryName: registryName,
			output:       output,
			gammaControl: control,
		}
		m.setupControlHandlers(outState, control)
		m.outputs.Store(outputID, outState)
	}
	return nil
}

func (m *Manager) setupControlHandlers(state *outputState, control *wlr_gamma_control.ZwlrGammaControlV1) {
	outputID := state.id

	control.SetGammaSizeHandler(func(e wlr_gamma_control.ZwlrGammaControlV1GammaSizeEvent) {
		size := e.Size
		m.post(func() {
			if out, ok := m.outputs.Load(outputID); ok {
				out.rampSize = size
				out.failed = false
				out.retryCount = 0
				out.lastTemp = 0
			}
			m.applyCurrentTemp("gamma_size")
		})
	})

	control.SetFailedHandler(func(_ wlr_gamma_control.ZwlrGammaControlV1FailedEvent) {
		m.post(func() {
			out, ok := m.outputs.Load(outputID)
			if !ok {
				return
			}
			if ctrl, ok := out.gammaControl.(*wlr_gamma_control.ZwlrGammaControlV1); ok && ctrl != nil && !ctrl.IsZombie() {
				ctrl.Destroy()
			}
			out.gammaControl = nil
			out.failed = true
			out.rampSize = 0
			out.retryCount++
			out.lastFailTime = time.Now()

			if !m.outputStillValid(out) {
				return
			}

			backoff := time.Duration(300<<uint(min(out.retryCount-1, 4))) * time.Millisecond
			time.AfterFunc(backoff, func() {
				m.post(func() {
					if !m.outputStillValid(out) {
						return
					}
					if _, stillTracked := m.outputs.Load(outputID); !stillTracked {
						return
					}
					m.recreateOutputControl(out)
				})
			})
		})
	})
}

func (m *Manager) addAvailableOutput(o *wlclient.Output) {
	if o == nil {
		return
	}
	m.availOutputsMu.Lock()
	defer m.availOutputsMu.Unlock()
	if slices.Contains(m.availableOutputs, o) {
		return
	}
	m.availableOutputs = append(m.availableOutputs, o)
}

func (m *Manager) removeAvailableOutput(o *wlclient.Output) {
	if o == nil {
		return
	}
	m.availOutputsMu.Lock()
	defer m.availOutputsMu.Unlock()
	m.availableOutputs = slices.DeleteFunc(m.availableOutputs, func(existing *wlclient.Output) bool {
		return existing == o
	})
}

func (m *Manager) outputStillValid(out *outputState) bool {
	switch {
	case out == nil:
		return false
	case out.output == nil:
		return false
	case out.output.IsZombie():
		return false
	}
	m.availOutputsMu.RLock()
	defer m.availOutputsMu.RUnlock()
	return slices.Contains(m.availableOutputs, out.output)
}

func isConnectionDeadErr(err error) bool {
	switch {
	case err == nil:
		return false
	case errors.Is(err, syscall.EPIPE):
		return true
	case errors.Is(err, syscall.ECONNRESET):
		return true
	case errors.Is(err, syscall.EBADF):
		return true
	case errors.Is(err, io.EOF):
		return true
	}
	return false
}

func (m *Manager) addOutputControl(output *wlclient.Output) error {
	switch {
	case m.connectionDead.Load():
		return nil
	case output == nil || output.IsZombie():
		return nil
	}

	outputID := output.ID()
	gammaMgr := m.gammaControl.(*wlr_gamma_control.ZwlrGammaControlManagerV1)

	control, err := gammaMgr.GetGammaControl(output)
	if err != nil {
		if isConnectionDeadErr(err) {
			m.markConnectionDead(err)
		}
		return err
	}

	registryName, _ := m.outputRegNames.Load(outputID)
	outState := &outputState{
		id:           outputID,
		registryName: registryName,
		output:       output,
		gammaControl: control,
	}
	m.setupControlHandlers(outState, control)
	m.outputs.Store(outputID, outState)
	return nil
}

func (m *Manager) recreateOutputControl(out *outputState) error {
	m.configMutex.RLock()
	enabled := m.config.Enabled
	m.configMutex.RUnlock()

	switch {
	case m.connectionDead.Load():
		return nil
	case !enabled || !m.controlsInitialized:
		return nil
	case out.isVirtual:
		return nil
	case out.retryCount >= 10:
		return nil
	case !m.outputStillValid(out):
		return nil
	}
	if _, ok := m.outputs.Load(out.id); !ok {
		return nil
	}

	gammaMgr, ok := m.gammaControl.(*wlr_gamma_control.ZwlrGammaControlManagerV1)
	if !ok {
		return fmt.Errorf("no gamma manager")
	}

	if existing, ok := out.gammaControl.(*wlr_gamma_control.ZwlrGammaControlV1); ok && existing != nil && !existing.IsZombie() {
		existing.Destroy()
		out.gammaControl = nil
	}

	control, err := gammaMgr.GetGammaControl(out.output)
	if err != nil {
		if isConnectionDeadErr(err) {
			m.markConnectionDead(err)
		}
		return err
	}

	m.setupControlHandlers(out, control)
	out.gammaControl = control
	out.failed = false
	return nil
}

func (m *Manager) markConnectionDead(err error) {
	if m.connectionDead.Swap(true) {
		return
	}
	log.Errorf("gamma: wayland connection appears dead (%v); pausing gamma operations", err)
}

func (m *Manager) recalcSchedule(now time.Time) {
	m.configMutex.RLock()
	config := m.config
	m.configMutex.RUnlock()

	m.scheduleMutex.Lock()
	defer m.scheduleMutex.Unlock()

	dayStart := time.Date(now.Year(), now.Month(), now.Day(), 0, 0, 0, 0, now.Location())
	alreadyValid := !m.schedule.times.Sunrise.IsZero()
	if m.schedule.calcDay.Equal(dayStart) && alreadyValid {
		return
	}

	var times SunTimes
	var cond SunCondition

	if config.ManualSunrise != nil && config.ManualSunset != nil {
		dur := time.Hour
		if config.ManualDuration != nil {
			dur = *config.ManualDuration
		}
		sunrise := time.Date(now.Year(), now.Month(), now.Day(),
			config.ManualSunrise.Hour(), config.ManualSunrise.Minute(), config.ManualSunrise.Second(), 0, now.Location())
		sunset := time.Date(now.Year(), now.Month(), now.Day(),
			config.ManualSunset.Hour(), config.ManualSunset.Minute(), config.ManualSunset.Second(), 0, now.Location())
		if !sunset.After(sunrise) {
			// night start past midnight belongs to the next day
			sunset = sunset.Add(24 * time.Hour)
		}
		times = SunTimes{
			Dawn:    sunrise.Add(-dur),
			Sunrise: sunrise,
			Sunset:  sunset,
			Night:   sunset.Add(dur),
		}
		cond = SunNormal
	} else {
		lat, lon := m.getLocation()
		if lat == nil || lon == nil {
			m.gammaState = StateStatic
			// stale times from a previous config must not drive applies
			m.schedule = sunSchedule{}
			return
		}
		times, cond = CalculateSunTimesWithTwilight(*lat, *lon, now, config.ElevationTwilight, config.ElevationDaylight)
	}

	m.schedule.calcDay = dayStart
	m.schedule.times = times
	m.schedule.condition = cond

	switch cond {
	case SunNormal:
		m.gammaState = StateNormal
		tempDiff := config.HighTemp - config.LowTemp
		if tempDiff > 0 {
			dawnDur := times.Sunrise.Sub(times.Dawn)
			nightDur := times.Night.Sub(times.Sunset)
			m.schedule.dawnStepTime = time.Duration(max(1, int(dawnDur.Seconds())*animKelvinStep/tempDiff)) * time.Second
			m.schedule.nightStepTime = time.Duration(max(1, int(nightDur.Seconds())*animKelvinStep/tempDiff)) * time.Second
		}
	case SunMidnightSun:
		m.gammaState = StateStatic
	case SunPolarNight:
		m.gammaState = StateStatic
	}
}

func (m *Manager) SetGeoClient(client geolocation.Client) {
	m.geoClient = client
}

func (m *Manager) getLocation() (*float64, *float64) {
	m.configMutex.RLock()
	config := m.config
	m.configMutex.RUnlock()

	if config.Latitude != nil && config.Longitude != nil {
		return config.Latitude, config.Longitude
	}
	if !config.UseIPLocation {
		return nil, nil
	}
	if m.geoClient == nil {
		return nil, nil
	}

	m.locationMutex.RLock()
	if m.cachedIPLat != nil && m.cachedIPLon != nil {
		lat, lon := m.cachedIPLat, m.cachedIPLon
		m.locationMutex.RUnlock()
		return lat, lon
	}
	m.locationMutex.RUnlock()

	location, err := m.geoClient.GetLocation()
	if err != nil {
		return nil, nil
	}

	m.locationMutex.Lock()
	m.cachedIPLat = &location.Latitude
	m.cachedIPLon = &location.Longitude
	m.locationMutex.Unlock()
	return m.cachedIPLat, m.cachedIPLon
}

func (m *Manager) hasValidSchedule() bool {
	m.scheduleMutex.RLock()
	defer m.scheduleMutex.RUnlock()
	return !m.schedule.times.Sunrise.IsZero()
}

func (m *Manager) getSunPosition(now time.Time) float64 {
	m.scheduleMutex.RLock()
	sched := m.schedule
	state := m.gammaState
	m.scheduleMutex.RUnlock()

	if sched.times.Sunrise.IsZero() {
		return 1.0
	}

	switch state {
	case StateStatic:
		if sched.condition == SunMidnightSun {
			return 1.0
		}
		return 0.0
	case StateNormal:
		return m.getSunPositionNormal(now, sched.times)
	}
	return 1.0
}

func shiftTimes(times SunTimes, d time.Duration) SunTimes {
	return SunTimes{
		Dawn:    times.Dawn.Add(d),
		Sunrise: times.Sunrise.Add(d),
		Sunset:  times.Sunset.Add(d),
		Night:   times.Night.Add(d),
	}
}

// activeCycle maps early-morning hours back to yesterday's cycle when the
// schedule crosses midnight.
func activeCycle(now time.Time, times SunTimes) SunTimes {
	if now.Before(times.Night.Add(-24 * time.Hour)) {
		return shiftTimes(times, -24*time.Hour)
	}
	return times
}

func (m *Manager) getSunPositionNormal(now time.Time, times SunTimes) float64 {
	times = activeCycle(now, times)
	if now.Before(times.Dawn) {
		return 0.0
	}
	if now.Before(times.Sunrise) {
		return interpolate(now, times.Dawn, times.Sunrise)
	}
	if now.Before(times.Sunset) {
		return 1.0
	}
	if now.Before(times.Night) {
		return interpolate(now, times.Night, times.Sunset)
	}
	return 0.0
}

func interpolate(now time.Time, start, stop time.Time) float64 {
	if start.Equal(stop) {
		return 1.0
	}
	pos := float64(now.Sub(start)) / float64(stop.Sub(start))
	switch {
	case pos > 1.0:
		return 1.0
	case pos < 0.0:
		return 0.0
	default:
		return pos
	}
}

func (m *Manager) getTempFromPosition(pos float64) int {
	m.configMutex.RLock()
	low, high := m.config.LowTemp, m.config.HighTemp
	m.configMutex.RUnlock()
	return low + int(float64(high-low)*pos)
}

func (m *Manager) getNextDeadline(now time.Time) time.Time {
	m.scheduleMutex.RLock()
	sched := m.schedule
	state := m.gammaState
	m.scheduleMutex.RUnlock()

	switch state {
	case StateStatic:
		return m.tomorrow(now)
	case StateNormal:
		return m.getDeadlineNormal(now, sched)
	default:
		return m.tomorrow(now)
	}
}

func (m *Manager) getDeadlineNormal(now time.Time, sched sunSchedule) time.Time {
	times := activeCycle(now, sched.times)
	switch {
	case now.Before(times.Dawn):
		return times.Dawn
	case now.Before(times.Sunrise):
		return now.Add(sched.dawnStepTime)
	case now.Before(times.Sunset):
		return times.Sunset
	case now.Before(times.Night):
		return now.Add(sched.nightStepTime)
	default:
		return m.tomorrowDawn(now)
	}
}

func (m *Manager) tomorrowDawn(now time.Time) time.Time {
	tomorrow := time.Date(now.Year(), now.Month(), now.Day()+1, 0, 0, 0, 0, now.Location())

	m.configMutex.RLock()
	config := m.config
	m.configMutex.RUnlock()

	if config.ManualSunrise != nil {
		dur := time.Hour
		if config.ManualDuration != nil {
			dur = *config.ManualDuration
		}
		return time.Date(tomorrow.Year(), tomorrow.Month(), tomorrow.Day(),
			config.ManualSunrise.Hour(), config.ManualSunrise.Minute(), config.ManualSunrise.Second(), 0, tomorrow.Location()).Add(-dur)
	}

	lat, lon := m.getLocation()
	if lat == nil || lon == nil {
		return tomorrow
	}

	times, cond := CalculateSunTimesWithTwilight(*lat, *lon, tomorrow, config.ElevationTwilight, config.ElevationDaylight)
	if cond != SunNormal {
		return tomorrow
	}
	return times.Dawn
}

func (m *Manager) tomorrow(now time.Time) time.Time {
	return time.Date(now.Year(), now.Month(), now.Day()+1, 0, 0, 0, 0, now.Location())
}

func (m *Manager) schedulerLoop() {
	defer m.wg.Done()

	if m.needsControls() {
		m.post(func() { m.applyCurrentTemp("startup") })
	}

	timer := boottimer.New(24 * time.Hour)
	defer timer.Stop()
	for {
		m.configMutex.RLock()
		enabled := m.config.Enabled
		m.configMutex.RUnlock()

		now := time.Now()
		m.recalcSchedule(now)
		// publish independent of output readiness so night status never
		// presents a stale schedule while applies are blocked (#2967)
		m.updateStateFromSchedule()

		waitDur := 24 * time.Hour
		if enabled {
			deadline := m.getNextDeadline(now)
			if waitDur = time.Until(deadline); waitDur < time.Second {
				waitDur = time.Second
			}
		}
		timer.Reset(waitDur)

		select {
		case <-m.stopChan:
			return
		case <-m.updateTrigger:
			m.scheduleMutex.Lock()
			m.schedule.calcDay = time.Time{}
			m.scheduleMutex.Unlock()
			m.recalcSchedule(time.Now())
			m.updateStateFromSchedule()
			if m.needsControls() {
				m.post(func() { m.applyCurrentTemp("updateTrigger") })
			}
		case <-timer.C:
			if m.needsControls() {
				m.post(func() { m.applyCurrentTemp("timer") })
			}
		}
	}
}

func (m *Manager) applyCurrentTemp(_ string) {
	if !m.controlsInitialized || !m.anyOutputReady() {
		return
	}

	// Ensure schedule is up-to-date (handles display wake after overnight sleep)
	m.recalcSchedule(time.Now())

	m.configMutex.RLock()
	enabled := m.config.Enabled
	low, high := m.config.LowTemp, m.config.HighTemp
	m.configMutex.RUnlock()

	if !enabled {
		m.applyGamma(neutralTemp)
		m.updateStateFromSchedule()
		return
	}

	if low == high {
		m.applyGamma(low)
		m.updateStateFromSchedule()
		return
	}

	if !m.hasValidSchedule() {
		m.updateStateFromSchedule()
		return
	}

	now := time.Now()
	pos := m.getSunPosition(now)
	temp := m.getTempFromPosition(pos)

	m.applyGamma(temp)
	m.updateStateFromSchedule()
}

func (m *Manager) applyGamma(temp int) {
	m.configMutex.RLock()
	gamma, contrast := m.config.Gamma, m.config.Contrast
	m.configMutex.RUnlock()

	switch {
	case m.connectionDead.Load():
		return
	case !m.controlsInitialized:
		return
	}

	var outs []*outputState
	m.outputs.Range(func(_ uint32, out *outputState) bool {
		outs = append(outs, out)
		return true
	})
	if len(outs) == 0 {
		return
	}

	type job struct {
		out  *outputState
		data []byte
	}
	var jobs []job

	for _, out := range outs {
		switch {
		case out.failed:
			continue
		case out.rampSize == 0:
			continue
		case out.gammaControl == nil:
			continue
		case out.rampCurrent(temp, gamma, contrast):
			continue
		case !m.outputStillValid(out):
			continue
		}
		ramp := GenerateGammaRamp(out.rampSize, temp, gamma, contrast)
		buf := bytes.NewBuffer(make([]byte, 0, int(out.rampSize)*6))
		for _, v := range ramp.Red {
			binary.Write(buf, binary.LittleEndian, v)
		}
		for _, v := range ramp.Green {
			binary.Write(buf, binary.LittleEndian, v)
		}
		for _, v := range ramp.Blue {
			binary.Write(buf, binary.LittleEndian, v)
		}
		jobs = append(jobs, job{out: out, data: buf.Bytes()})
	}

	for _, j := range jobs {
		err := m.setGammaBytes(j.out, j.data)
		if err == nil {
			j.out.lastTemp = temp
			j.out.lastGamma = gamma
			j.out.lastContrast = contrast
			continue
		}
		log.Warnf("gamma: failed to set output %d: %v", j.out.id, err)
		j.out.failed = true
		j.out.rampSize = 0
		j.out.lastTemp = 0
		if isConnectionDeadErr(err) {
			m.markConnectionDead(err)
			return
		}
	}
}

func (out *outputState) rampCurrent(temp int, gamma, contrast float64) bool {
	return out.lastTemp == temp && out.lastGamma == gamma && out.lastContrast == contrast
}

func (m *Manager) setGammaBytes(out *outputState, data []byte) error {
	if out.gammaControl == nil {
		return fmt.Errorf("no gamma control")
	}
	ctrl, ok := out.gammaControl.(*wlr_gamma_control.ZwlrGammaControlV1)
	if !ok || ctrl == nil || ctrl.IsZombie() {
		return fmt.Errorf("gamma control invalid")
	}

	fd, err := shm.CreateAnonFd("gamma-ramp")
	if err != nil {
		return err
	}
	defer syscall.Close(fd)

	if err := syscall.Ftruncate(fd, int64(len(data))); err != nil {
		return err
	}

	dupFd, err := syscall.Dup(fd)
	if err != nil {
		return err
	}
	f := os.NewFile(uintptr(dupFd), "gamma")
	defer f.Close()

	if _, err := f.Write(data); err != nil {
		return err
	}
	syscall.Seek(fd, 0, 0)

	return ctrl.SetGamma(fd)
}

func (m *Manager) updateStateFromSchedule() {
	now := time.Now()

	m.configMutex.RLock()
	config := m.config
	m.configMutex.RUnlock()

	m.scheduleMutex.RLock()
	times := m.schedule.times
	m.scheduleMutex.RUnlock()

	var pos float64
	var temp int
	var isDay bool
	var deadline time.Time

	if times.Sunrise.IsZero() {
		pos = 1.0
		temp = config.HighTemp
		isDay = true
		deadline = m.tomorrow(now)
	} else {
		pos = m.getSunPosition(now)
		temp = m.getTempFromPosition(pos)
		deadline = m.getNextDeadline(now)
		cycle := activeCycle(now, times)
		isDay = now.After(cycle.Sunrise) && now.Before(cycle.Sunset)
	}

	newState := State{
		Config:         config,
		CurrentTemp:    temp,
		NextTransition: deadline,
		SunriseTime:    times.Sunrise,
		SunsetTime:     times.Sunset,
		DawnTime:       times.Dawn,
		NightTime:      times.Night,
		IsDay:          isDay,
		SunPosition:    pos,
	}

	m.stateMutex.Lock()
	m.state = &newState
	m.stateMutex.Unlock()

	m.notifySubscribers()
}

func (m *Manager) notifier() {
	defer m.notifierWg.Done()
	const minGap = 100 * time.Millisecond
	timer := time.NewTimer(minGap)
	timer.Stop()
	var pending bool

	for {
		select {
		case <-m.stopChan:
			timer.Stop()
			return
		case <-m.dirty:
			if pending {
				continue
			}
			pending = true
			timer.Reset(minGap)
		case <-timer.C:
			if !pending {
				continue
			}
			currentState := m.GetState()
			if m.lastNotified != nil && !stateChanged(m.lastNotified, &currentState) {
				pending = false
				continue
			}
			m.subscribers.Range(func(_ string, ch chan State) bool {
				select {
				case ch <- currentState:
				default:
				}
				return true
			})
			stateCopy := currentState
			m.lastNotified = &stateCopy
			pending = false
		}
	}
}

func (m *Manager) dbusMonitor() {
	defer m.wg.Done()
	for {
		select {
		case <-m.stopChan:
			return
		case sig := <-m.dbusSignal:
			if sig == nil {
				continue
			}
			m.handleDBusSignal(sig)
		}
	}
}

func (m *Manager) handleDBusSignal(sig *dbus.Signal) {
	switch {
	case sig.Name != "org.freedesktop.login1.Manager.PrepareForSleep":
		return
	case len(sig.Body) == 0:
		return
	}
	preparing, ok := sig.Body[0].(bool)
	if !ok || preparing {
		return
	}
	if !m.needsControls() {
		return
	}
	time.AfterFunc(500*time.Millisecond, func() {
		m.post(m.handleResume)
	})
}

func (m *Manager) handleResume() {
	switch {
	case !m.needsControls():
		return
	case !m.controlsInitialized:
		return
	case m.connectionDead.Load():
		return
	}

	// Compositor gamma state is unknown after resume; force a resend (#1235)
	m.outputs.Range(func(_ uint32, out *outputState) bool {
		out.lastTemp = 0
		return true
	})
	m.applyCurrentTemp("resume")
}

func (m *Manager) triggerUpdate() {
	select {
	case m.updateTrigger <- struct{}{}:
	default:
	}
}

func (m *Manager) SetConfig(config Config) error {
	if err := config.Validate(); err != nil {
		return err
	}
	m.configMutex.Lock()
	m.config = config
	m.configMutex.Unlock()
	m.triggerUpdate()
	return nil
}

func (m *Manager) SetTemperature(low, high int) error {
	m.configMutex.Lock()
	if m.config.LowTemp == low && m.config.HighTemp == high {
		m.configMutex.Unlock()
		return nil
	}
	updated := m.config
	updated.LowTemp = low
	updated.HighTemp = high
	if err := updated.Validate(); err != nil {
		m.configMutex.Unlock()
		return err
	}
	m.config = updated
	m.configMutex.Unlock()
	m.triggerUpdate()
	return nil
}

func (m *Manager) SetLocation(lat, lon float64) error {
	m.configMutex.Lock()
	if m.config.Latitude != nil && m.config.Longitude != nil &&
		*m.config.Latitude == lat && *m.config.Longitude == lon && !m.config.UseIPLocation {
		m.configMutex.Unlock()
		return nil
	}
	updated := m.config
	updated.Latitude = &lat
	updated.Longitude = &lon
	updated.UseIPLocation = false
	if err := updated.Validate(); err != nil {
		m.configMutex.Unlock()
		return err
	}
	m.config = updated
	m.configMutex.Unlock()
	m.triggerUpdate()
	return nil
}

func (m *Manager) SetUseIPLocation(use bool) {
	m.configMutex.Lock()
	if m.config.UseIPLocation == use {
		m.configMutex.Unlock()
		return
	}
	m.config.UseIPLocation = use
	if use {
		m.config.Latitude = nil
		m.config.Longitude = nil
	}
	m.configMutex.Unlock()

	if use {
		m.locationMutex.Lock()
		m.cachedIPLat = nil
		m.cachedIPLon = nil
		m.locationMutex.Unlock()
	}
	m.triggerUpdate()
}

func (m *Manager) SetManualTimes(sunrise, sunset time.Time, duration *time.Duration) error {
	m.configMutex.Lock()
	if m.config.ManualSunrise != nil && m.config.ManualSunset != nil &&
		m.config.ManualSunrise.Hour() == sunrise.Hour() && m.config.ManualSunrise.Minute() == sunrise.Minute() &&
		m.config.ManualSunset.Hour() == sunset.Hour() && m.config.ManualSunset.Minute() == sunset.Minute() &&
		durationEqual(m.config.ManualDuration, duration) {
		m.configMutex.Unlock()
		return nil
	}
	updated := m.config
	updated.ManualSunrise = &sunrise
	updated.ManualSunset = &sunset
	updated.ManualDuration = duration
	if err := updated.Validate(); err != nil {
		m.configMutex.Unlock()
		return err
	}
	m.config = updated
	m.configMutex.Unlock()
	m.triggerUpdate()
	return nil
}

func (m *Manager) ClearManualTimes() {
	m.configMutex.Lock()
	if m.config.ManualSunrise == nil && m.config.ManualSunset == nil && m.config.ManualDuration == nil {
		m.configMutex.Unlock()
		return
	}
	m.config.ManualSunrise = nil
	m.config.ManualSunset = nil
	m.config.ManualDuration = nil
	m.configMutex.Unlock()
	m.triggerUpdate()
}

func durationEqual(a, b *time.Duration) bool {
	if a == nil || b == nil {
		return a == b
	}
	return *a == *b
}

func (m *Manager) Adjustments() (gamma, contrast float64) {
	m.configMutex.RLock()
	defer m.configMutex.RUnlock()
	return m.config.Gamma, m.config.Contrast
}

func (m *Manager) SetAdjustments(gamma, contrast float64) error {
	m.configMutex.Lock()
	if m.config.Gamma == gamma && m.config.Contrast == contrast {
		m.configMutex.Unlock()
		return nil
	}
	updated := m.config
	updated.Gamma = gamma
	updated.Contrast = contrast
	if err := updated.Validate(); err != nil {
		m.configMutex.Unlock()
		return err
	}
	m.config = updated
	m.configMutex.Unlock()
	m.syncControls()
	return nil
}

func (m *Manager) SetEnabled(enabled bool) {
	m.configMutex.Lock()
	if m.config.Enabled == enabled {
		m.configMutex.Unlock()
		return
	}
	m.config.Enabled = enabled
	m.configMutex.Unlock()
	m.syncControls()
}

func (m *Manager) needsControls() bool {
	m.configMutex.RLock()
	defer m.configMutex.RUnlock()
	return m.config.Enabled || m.config.Gamma != 1.0 || m.config.Contrast != 1.0
}

func (m *Manager) syncControls() {
	m.post(func() {
		switch {
		case m.needsControls() && !m.controlsInitialized:
			m.createControls()
		case !m.needsControls() && m.controlsInitialized:
			m.destroyControls()
		default:
			m.triggerUpdate()
		}
	})
}

func (m *Manager) createControls() {
	gammaMgr := m.gammaControl.(*wlr_gamma_control.ZwlrGammaControlManagerV1)
	m.availOutputsMu.RLock()
	outs := slices.Clone(m.availableOutputs)
	m.availOutputsMu.RUnlock()
	if err := m.setupOutputControls(outs, gammaMgr); err != nil {
		log.Errorf("gamma: failed to create controls: %v", err)
		return
	}
	m.controlsInitialized = true
	m.triggerUpdate()
}

func (m *Manager) destroyControls() {
	m.outputs.Range(func(_ uint32, out *outputState) bool {
		if out.gammaControl != nil {
			out.gammaControl.(*wlr_gamma_control.ZwlrGammaControlV1).Destroy()
		}
		return true
	})
	m.outputs.Range(func(key uint32, _ *outputState) bool {
		m.outputs.Delete(key)
		return true
	})
	m.controlsInitialized = false
}

func (m *Manager) Close() {
	close(m.stopChan)
	m.wg.Wait()
	m.notifierWg.Wait()

	m.subscribers.Range(func(key string, ch chan State) bool {
		close(ch)
		m.subscribers.Delete(key)
		return true
	})

	m.outputs.Range(func(_ uint32, out *outputState) bool {
		if ctrl, ok := out.gammaControl.(*wlr_gamma_control.ZwlrGammaControlV1); ok {
			ctrl.Destroy()
		}
		return true
	})
	m.outputs.Range(func(key uint32, _ *outputState) bool {
		m.outputs.Delete(key)
		return true
	})

	if manager, ok := m.gammaControl.(*wlr_gamma_control.ZwlrGammaControlManagerV1); ok {
		manager.Destroy()
	}

	if m.dbusConn != nil {
		m.dbusConn.RemoveSignal(m.dbusSignal)
		m.dbusConn.BusObject().Call("org.freedesktop.DBus.RemoveMatch", 0, prepareForSleepMatchRule)
	}
}
