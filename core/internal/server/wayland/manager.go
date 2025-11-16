package wayland

import (
	"bytes"
	"encoding/binary"
	"fmt"
	"os"
	"syscall"
	"time"

	wlclient "github.com/AvengeMedia/DankMaterialShell/core/pkg/go-wayland/wayland/client"
	"github.com/godbus/dbus/v5"
	"golang.org/x/sys/unix"

	"github.com/AvengeMedia/DankMaterialShell/core/internal/errdefs"
	"github.com/AvengeMedia/DankMaterialShell/core/internal/log"
	"github.com/AvengeMedia/DankMaterialShell/core/internal/proto/wlr_gamma_control"
)

func NewManager(display *wlclient.Display, config Config) (*Manager, error) {
	if err := config.Validate(); err != nil {
		return nil, err
	}

	m := &Manager{
		config:        config,
		display:       display,
		ctx:           display.Context(),
		cmdq:          make(chan cmd, 128),
		stopChan:      make(chan struct{}),
		updateTrigger: make(chan struct{}, 1),

		dirty:          make(chan struct{}, 1),
		dbusSignal:     make(chan *dbus.Signal, 16),
		transitionChan: make(chan int, 1),
	}

	if err := m.setupRegistry(); err != nil {
		return nil, err
	}

	// Setup D-Bus monitoring for suspend/resume events
	if err := m.setupDBusMonitor(); err != nil {
		log.Warnf("Failed to setup D-Bus monitoring for suspend/resume: %v", err)
		// Don't fail initialization if D-Bus setup fails, just continue without it
	}

	// Initialize currentTemp and targetTemp before starting any goroutines
	now := time.Now()
	initial := m.calculateTemperature(now)
	m.transitionMutex.Lock()
	m.currentTemp = initial
	m.targetTemp = initial
	m.transitionMutex.Unlock()

	m.alive = true
	m.updateState()

	m.notifierWg.Add(1)
	go m.notifier()

	m.wg.Add(1)
	go m.updateLoop()

	if m.dbusConn != nil {
		m.wg.Add(1)
		go m.dbusMonitor()
	}

	m.wg.Add(1)
	go m.waylandActor()

	m.wg.Add(1)
	go m.transitionWorker()

	if config.Enabled {
		m.post(func() {
			log.Info("Gamma control enabled at startup, initializing controls")
			gammaMgr := m.gammaControl.(*wlr_gamma_control.ZwlrGammaControlManagerV1)
			if err := func() error {
				var outputs []*wlclient.Output = m.availableOutputs
				return m.setupOutputControls(outputs, gammaMgr)
			}(); err != nil {
				log.Errorf("Failed to initialize gamma controls: %v", err)
			} else {
				m.controlsInitialized = true
			}
		})
	}

	return m, nil
}

func (m *Manager) post(fn func()) {
	select {
	case m.cmdq <- cmd{fn: fn}:
	default:
		log.Warn("Actor command queue full, dropping command")
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

func (m *Manager) allOutputsReady() bool {
	hasOutputs := false
	allReady := true
	m.outputs.Range(func(key uint32, value *outputState) bool {
		hasOutputs = true
		if value.rampSize == 0 || value.failed {
			allReady = false
			return false
		}
		return true
	})
	return hasOutputs && allReady
}

func (m *Manager) setupDBusMonitor() error {
	conn, err := dbus.ConnectSystemBus()
	if err != nil {
		return fmt.Errorf("failed to connect to system bus: %w", err)
	}

	// Subscribe to PrepareForSleep signal
	matchRule := "type='signal',interface='org.freedesktop.login1.Manager',member='PrepareForSleep',path='/org/freedesktop/login1'"
	if err := conn.BusObject().Call("org.freedesktop.DBus.AddMatch", 0, matchRule).Err; err != nil {
		conn.Close()
		return fmt.Errorf("failed to add match rule: %w", err)
	}

	conn.Signal(m.dbusSignal)
	m.dbusConn = conn

	log.Info("D-Bus monitoring for suspend/resume events enabled")
	return nil
}

func (m *Manager) setupRegistry() error {
	log.Info("setupRegistry: starting registry setup")

	registry, err := m.display.GetRegistry()
	if err != nil {
		return fmt.Errorf("failed to get registry: %w", err)
	}
	m.registry = registry

	outputs := make([]*wlclient.Output, 0)
	outputNames := make(map[uint32]string)
	var gammaMgr *wlr_gamma_control.ZwlrGammaControlManagerV1

	registry.SetGlobalHandler(func(e wlclient.RegistryGlobalEvent) {
		switch e.Interface {
		case wlr_gamma_control.ZwlrGammaControlManagerV1InterfaceName:
			log.Infof("setupRegistry: found %s", wlr_gamma_control.ZwlrGammaControlManagerV1InterfaceName)
			manager := wlr_gamma_control.NewZwlrGammaControlManagerV1(m.ctx)
			version := e.Version
			if version > 1 {
				version = 1
			}
			if err := registry.Bind(e.Name, e.Interface, version, manager); err == nil {
				gammaMgr = manager
				log.Info("setupRegistry: gamma control manager bound successfully")
			} else {
				log.Errorf("setupRegistry: failed to bind gamma control: %v", err)
			}
		case "wl_output":
			log.Debugf("Global event: found wl_output (name=%d)", e.Name)
			output := wlclient.NewOutput(m.ctx)
			version := e.Version
			if version > 4 {
				version = 4
			}
			if err := registry.Bind(e.Name, e.Interface, version, output); err == nil {
				outputID := output.ID()
				log.Infof("Bound wl_output id=%d registry_name=%d", outputID, e.Name)

				output.SetNameHandler(func(ev wlclient.OutputNameEvent) {
					log.Infof("Output %d name: %s", outputID, ev.Name)
					outputNames[outputID] = ev.Name
					isVirtual := len(ev.Name) >= 9 && ev.Name[:9] == "HEADLESS-"
					if isVirtual {
						log.Infof("Output %d identified as virtual", outputID)
					}
				})

				if gammaMgr != nil {
					outputs = append(outputs, output)
				}

				m.outputRegNames.Store(outputID, e.Name)

				m.configMutex.RLock()
				enabled := m.config.Enabled
				m.configMutex.RUnlock()

				if enabled && m.controlsInitialized {
					m.post(func() {
						log.Infof("New output %d added, creating gamma control", outputID)
						if err := m.addOutputControl(output); err != nil {
							log.Errorf("Failed to add gamma control for new output %d: %v", outputID, err)
						}
					})
				} else if enabled && !m.controlsInitialized {
					m.post(func() {
						log.Infof("Output %d added after all were removed, creating gamma control", outputID)
						if err := m.addOutputControl(output); err != nil {
							log.Errorf("Failed to add gamma control for output %d: %v", outputID, err)
						} else {
							m.controlsInitialized = true
						}
					})
				}
			} else {
				log.Errorf("Failed to bind wl_output: %v", err)
			}
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

			if foundOut != nil {
				log.Infof("Output %d (registry name %d) removed, destroying gamma control", foundID, e.Name)
				if foundOut.gammaControl != nil {
					control := foundOut.gammaControl.(*wlr_gamma_control.ZwlrGammaControlV1)
					control.Destroy()
				}
				m.outputs.Delete(foundID)

				hasOutputs := false
				m.outputs.Range(func(key uint32, value *outputState) bool {
					hasOutputs = true
					return false
				})
				if !hasOutputs {
					m.controlsInitialized = false
					log.Info("All outputs removed, controls no longer initialized")
				}
			}
		})
	})

	if err := m.display.Roundtrip(); err != nil {
		return fmt.Errorf("first roundtrip failed: %w", err)
	}
	if err := m.display.Roundtrip(); err != nil {
		return fmt.Errorf("second roundtrip failed: %w", err)
	}

	log.Infof("setupRegistry: discovered gamma_manager=%v, outputs=%d", gammaMgr != nil, len(outputs))

	if gammaMgr == nil {
		log.Error("setupRegistry: gamma control manager not found in registry")
		return errdefs.ErrNoGammaControl
	}

	if len(outputs) == 0 {
		log.Error("setupRegistry: no wl_output objects found")
		return fmt.Errorf("no outputs available")
	}

	physicalOutputs := make([]*wlclient.Output, 0)
	for _, output := range outputs {
		outputID := output.ID()
		name := outputNames[outputID]
		if name != "" && (len(name) >= 9 && name[:9] == "HEADLESS-") {
			log.Infof("Skipping virtual output %d (name=%s) for gamma control", outputID, name)
			continue
		}
		physicalOutputs = append(physicalOutputs, output)
	}

	log.Infof("setupRegistry: filtered %d physical outputs from %d total outputs", len(physicalOutputs), len(outputs))

	m.gammaControl = gammaMgr
	m.availableOutputs = physicalOutputs

	log.Info("setupRegistry: completed successfully (gamma controls will be initialized when enabled)")
	return nil
}

func (m *Manager) setupOutputControls(outputs []*wlclient.Output, manager *wlr_gamma_control.ZwlrGammaControlManagerV1) error {
	log.Infof("setupOutputControls: creating gamma controls for %d outputs", len(outputs))

	for _, output := range outputs {
		control, err := manager.GetGammaControl(output)
		if err != nil {
			log.Warnf("Failed to get gamma control for output %d: %v", output.ID(), err)
			continue
		}

		outputID := output.ID()
		registryName, _ := m.outputRegNames.Load(outputID)

		outState := &outputState{
			id:           outputID,
			registryName: registryName,
			output:       output,
			gammaControl: control,
			isVirtual:    false,
		}

		func(state *outputState) {
			control.SetGammaSizeHandler(func(e wlr_gamma_control.ZwlrGammaControlV1GammaSizeEvent) {
				if outState, exists := m.outputs.Load(state.id); exists {
					outState.rampSize = e.Size
					outState.failed = false
					outState.retryCount = 0
					log.Infof("Output %d gamma_size=%d", state.id, e.Size)
				}

				m.transitionMutex.RLock()
				currentTemp := m.currentTemp
				m.transitionMutex.RUnlock()

				m.post(func() {
					m.applyNowOnActor(currentTemp)
				})
			})

			control.SetFailedHandler(func(e wlr_gamma_control.ZwlrGammaControlV1FailedEvent) {
				if outState, exists := m.outputs.Load(state.id); exists {
					outState.failed = true
					outState.rampSize = 0
					outState.retryCount++
					outState.lastFailTime = time.Now()

					retryCount := outState.retryCount
					if retryCount == 1 || retryCount%5 == 0 {
						log.Errorf("Gamma control failed for output %d (attempt %d)", state.id, retryCount)
					}

					backoff := time.Duration(300<<uint(min(retryCount-1, 4))) * time.Millisecond

					time.AfterFunc(backoff, func() {
						m.post(func() {
							m.recreateOutputControl(outState)
						})
					})
				}
			})
		}(outState)

		m.outputs.Store(outputID, outState)
	}

	return nil
}

func (m *Manager) addOutputControl(output *wlclient.Output) error {
	outputID := output.ID()

	var outputName string
	output.SetNameHandler(func(ev wlclient.OutputNameEvent) {
		outputName = ev.Name
		if outState, exists := m.outputs.Load(outputID); exists {
			outState.name = ev.Name
			if len(ev.Name) >= 9 && ev.Name[:9] == "HEADLESS-" {
				log.Infof("Detected virtual output %d (name=%s), marking for gamma control skip", outputID, ev.Name)
				outState.isVirtual = true
				outState.failed = true
			}
		}
	})

	gammaMgr := m.gammaControl.(*wlr_gamma_control.ZwlrGammaControlManagerV1)

	control, err := gammaMgr.GetGammaControl(output)
	if err != nil {
		return fmt.Errorf("failed to get gamma control: %w", err)
	}

	registryName, _ := m.outputRegNames.Load(outputID)

	outState := &outputState{
		id:           outputID,
		name:         outputName,
		registryName: registryName,
		output:       output,
		gammaControl: control,
		isVirtual:    false,
	}

	control.SetGammaSizeHandler(func(e wlr_gamma_control.ZwlrGammaControlV1GammaSizeEvent) {
		if out, exists := m.outputs.Load(outState.id); exists {
			out.rampSize = e.Size
			out.failed = false
			out.retryCount = 0
			log.Infof("Output %d gamma_size=%d", outState.id, e.Size)
		}

		m.transitionMutex.RLock()
		currentTemp := m.currentTemp
		m.transitionMutex.RUnlock()

		m.post(func() {
			m.applyNowOnActor(currentTemp)
		})
	})

	control.SetFailedHandler(func(e wlr_gamma_control.ZwlrGammaControlV1FailedEvent) {
		if out, exists := m.outputs.Load(outState.id); exists {
			out.failed = true
			out.rampSize = 0
			out.retryCount++
			out.lastFailTime = time.Now()

			retryCount := out.retryCount
			if retryCount == 1 || retryCount%5 == 0 {
				log.Errorf("Gamma control failed for output %d (attempt %d)", outState.id, retryCount)
			}

			backoff := time.Duration(300<<uint(min(retryCount-1, 4))) * time.Millisecond

			time.AfterFunc(backoff, func() {
				m.post(func() {
					m.recreateOutputControl(out)
				})
			})
		}
	})

	m.outputs.Store(outputID, outState)

	log.Infof("Added gamma control for output %d", output.ID())
	return nil
}

func (m *Manager) updateLoop() {
	defer m.wg.Done()

	targetTemp := m.calculateTemperature(time.Now())

	m.transitionMutex.Lock()
	m.currentTemp = targetTemp
	m.targetTemp = targetTemp
	m.transitionMutex.Unlock()

	m.applyGammaImmediate(targetTemp)

	var timer *time.Timer
	for {
		nextTransition := m.calculateNextTransition(time.Now())

		waitDuration := time.Until(nextTransition)
		if waitDuration < 0 {
			waitDuration = 1 * time.Second
		}

		if timer != nil {
			timer.Stop()
		}
		timer = time.NewTimer(waitDuration)

		select {
		case <-m.stopChan:
			if timer != nil {
				timer.Stop()
			}
			return
		case <-m.updateTrigger:
			debounceTimer := time.NewTimer(50 * time.Millisecond)
		drainLoop:
			for {
				select {
				case <-m.updateTrigger:
					debounceTimer.Reset(50 * time.Millisecond)
				case <-debounceTimer.C:
					break drainLoop
				case <-m.stopChan:
					debounceTimer.Stop()
					return
				}
			}

			m.configMutex.RLock()
			enabled := m.config.Enabled
			m.configMutex.RUnlock()
			if enabled {
				newTargetTemp := m.calculateTemperature(time.Now())
				m.startTransition(newTargetTemp)
			}
		case <-timer.C:
			// Drain any pending triggers to collapse bursts into one
			drain := true
			for drain {
				select {
				case <-m.updateTrigger:
					// keep draining
				default:
					drain = false
				}
			}
			// Recompute once, then kick a single transition (if enabled)
			m.configMutex.RLock()
			enabled := m.config.Enabled
			m.configMutex.RUnlock()
			if enabled {
				newTargetTemp := m.calculateTemperature(time.Now())
				m.startTransition(newTargetTemp)
			}
		}
	}
}

func (m *Manager) startTransition(targetTemp int) {
	if !m.controlsInitialized || !m.allOutputsReady() {
		m.transitionMutex.Lock()
		m.targetTemp = targetTemp
		m.transitionMutex.Unlock()
		log.Debugf("Controls not ready, deferring transition to %dK", targetTemp)
		return
	}

	m.transitionMutex.Lock()
	current := m.currentTemp
	m.targetTemp = targetTemp

	if current == targetTemp {
		m.transitionMutex.Unlock()
		log.Debugf("Skipping transition: already at %dK", targetTemp)
		return
	}
	m.transitionMutex.Unlock()

	select {
	case m.transitionChan <- targetTemp:
	default:
	}
}

func (m *Manager) transitionWorker() {
	defer m.wg.Done()
	const dur = 1 * time.Second
	const fps = 30
	steps := int(dur.Seconds() * fps)
	stepDur := dur / time.Duration(steps)

	for {
		select {
		case <-m.stopChan:
			return
		case targetTemp := <-m.transitionChan:
			m.transitionMutex.Lock()
			currentTemp := m.currentTemp
			m.targetTemp = targetTemp
			m.transitionMutex.Unlock()

			if currentTemp == targetTemp {
				continue
			}

			log.Debugf("Starting smooth transition: %dK -> %dK over %v", currentTemp, targetTemp, dur)

			for i := 0; i <= steps; i++ {
				select {
				case newTarget := <-m.transitionChan:
					m.transitionMutex.Lock()
					m.targetTemp = newTarget
					m.transitionMutex.Unlock()
					log.Debugf("Transition %dK -> %dK aborted (newer transition started)", currentTemp, targetTemp)
					break
				default:
				}

				m.transitionMutex.RLock()
				if m.targetTemp != targetTemp {
					m.transitionMutex.RUnlock()
					break
				}
				m.transitionMutex.RUnlock()

				progress := float64(i) / float64(steps)
				temp := currentTemp + int(float64(targetTemp-currentTemp)*progress)

				m.post(func() { m.applyNowOnActor(temp) })

				if i < steps {
					time.Sleep(stepDur)
				}
			}

			m.transitionMutex.RLock()
			finalTarget := m.targetTemp
			m.transitionMutex.RUnlock()

			if finalTarget == targetTemp {
				log.Debugf("Transition complete: now at %dK", targetTemp)

				m.configMutex.RLock()
				enabled := m.config.Enabled
				identityTemp := m.config.HighTemp
				m.configMutex.RUnlock()

				if !enabled && targetTemp == identityTemp && m.controlsInitialized {
					m.post(func() {
						log.Info("Destroying gamma controls after transition to identity")
						m.outputs.Range(func(id uint32, out *outputState) bool {
							if out.gammaControl != nil {
								control := out.gammaControl.(*wlr_gamma_control.ZwlrGammaControlV1)
								control.Destroy()
								log.Debugf("Destroyed gamma control for output %d", id)
							}
							return true
						})
						m.outputs.Range(func(key uint32, value *outputState) bool {
							m.outputs.Delete(key)
							return true
						})
						m.controlsInitialized = false

						m.transitionMutex.Lock()
						m.currentTemp = identityTemp
						m.targetTemp = identityTemp
						m.transitionMutex.Unlock()

						if _, err := m.display.Sync(); err != nil {
							log.Warnf("Failed to sync Wayland display after destroying controls: %v", err)
						}

						log.Info("All gamma controls destroyed")
					})
				}
			}
		}
	}
}

func (m *Manager) recreateOutputControl(out *outputState) error {
	m.configMutex.RLock()
	enabled := m.config.Enabled
	m.configMutex.RUnlock()

	if !enabled || !m.controlsInitialized {
		return nil
	}

	_, exists := m.outputs.Load(out.id)

	if !exists {
		return nil
	}

	if out.isVirtual {
		return nil
	}

	const maxRetries = 10
	if out.retryCount >= maxRetries {
		return nil
	}

	gammaMgr, ok := m.gammaControl.(*wlr_gamma_control.ZwlrGammaControlManagerV1)
	if !ok || gammaMgr == nil {
		return fmt.Errorf("gamma control manager not available")
	}
	control, err := gammaMgr.GetGammaControl(out.output)
	if err != nil {
		return fmt.Errorf("get gamma control: %w", err)
	}

	state := out
	control.SetGammaSizeHandler(func(e wlr_gamma_control.ZwlrGammaControlV1GammaSizeEvent) {
		if outState, exists := m.outputs.Load(state.id); exists {
			outState.rampSize = e.Size
			outState.failed = false
			outState.retryCount = 0
			log.Infof("Output %d gamma_size=%d (recreated)", state.id, e.Size)
		}

		m.transitionMutex.RLock()
		currentTemp := m.currentTemp
		m.transitionMutex.RUnlock()

		m.post(func() {
			m.applyNowOnActor(currentTemp)
		})
	})

	control.SetFailedHandler(func(e wlr_gamma_control.ZwlrGammaControlV1FailedEvent) {
		if outState, exists := m.outputs.Load(state.id); exists {
			outState.failed = true
			outState.rampSize = 0
			outState.retryCount++
			outState.lastFailTime = time.Now()

			retryCount := outState.retryCount
			if retryCount == 1 || retryCount%5 == 0 {
				log.Errorf("Gamma control failed for output %d (attempt %d)", state.id, retryCount)
			}

			backoff := time.Duration(300<<uint(min(retryCount-1, 4))) * time.Millisecond

			time.AfterFunc(backoff, func() {
				m.post(func() {
					m.recreateOutputControl(outState)
				})
			})
		}
	})

	out.gammaControl = control
	out.failed = false

	return nil
}

func (m *Manager) applyGammaImmediate(temp int) {
	m.post(func() { m.applyNowOnActor(temp) })
}

func (m *Manager) applyNowOnActor(temp int) {
	m.configMutex.RLock()
	gamma := m.config.Gamma
	m.configMutex.RUnlock()

	if !m.controlsInitialized {
		return
	}

	var outs []*outputState
	m.outputs.Range(func(key uint32, value *outputState) bool {
		outs = append(outs, value)
		return true
	})

	if len(outs) == 0 {
		return
	}

	// Collect ready outputs & pack their buffers first (atomic apply)
	type job struct {
		out  *outputState
		data []byte
	}
	var jobs []job

	for _, out := range outs {
		if out.failed || out.rampSize == 0 {
			continue
		}

		ramp := GenerateGammaRamp(out.rampSize, temp, gamma)

		// Pack once into []byte
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

	// Now send to all ready outputs in this tick
	for _, j := range jobs {
		if err := m.setGammaBytesActor(j.out, j.data); err != nil {
			log.Warnf("Failed to set gamma for output %d: %v", j.out.id, err)
			outID := j.out.id
			if out, exists := m.outputs.Load(outID); exists {
				out.failed = true
				out.rampSize = 0
			}

			time.AfterFunc(300*time.Millisecond, func() {
				m.post(func() {
					if out, exists := m.outputs.Load(outID); exists {
						if out.failed {
							m.recreateOutputControl(out)
						}
					}
				})
			})
		}
	}

	m.transitionMutex.Lock()
	m.currentTemp = temp
	m.transitionMutex.Unlock()

	m.updateState()
}

func (m *Manager) setGammaBytesActor(out *outputState, data []byte) error {
	fd, err := MemfdCreate("gamma-ramp", 0)
	if err != nil {
		return fmt.Errorf("memfd_create: %w", err)
	}
	defer syscall.Close(fd)

	if err := syscall.Ftruncate(fd, int64(len(data))); err != nil {
		return fmt.Errorf("ftruncate: %w", err)
	}

	dupFd, err := syscall.Dup(fd)
	if err != nil {
		return fmt.Errorf("dup: %w", err)
	}
	f := os.NewFile(uintptr(dupFd), "gamma")
	defer f.Close()

	n, err := f.Write(data)
	if err != nil || n != len(data) {
		return fmt.Errorf("write gamma: %w (n=%d want=%d)", err, n, len(data))
	}

	if _, err := syscall.Seek(fd, 0, 0); err != nil {
		return fmt.Errorf("seek: %w", err)
	}

	ctrl := out.gammaControl.(*wlr_gamma_control.ZwlrGammaControlV1)
	if err := ctrl.SetGamma(fd); err != nil {
		return fmt.Errorf("SetGamma: %w", err)
	}

	return nil
}

func (m *Manager) updateState() {
	now := time.Now()

	m.configMutex.RLock()
	configCopy := m.config
	m.configMutex.RUnlock()

	var sunrise, sunset time.Time
	if configCopy.ManualSunrise != nil && configCopy.ManualSunset != nil {
		year, month, day := now.Date()
		loc := now.Location()
		sunrise = time.Date(year, month, day,
			configCopy.ManualSunrise.Hour(),
			configCopy.ManualSunrise.Minute(),
			configCopy.ManualSunrise.Second(), 0, loc)
		sunset = time.Date(year, month, day,
			configCopy.ManualSunset.Hour(),
			configCopy.ManualSunset.Minute(),
			configCopy.ManualSunset.Second(), 0, loc)
	} else if configCopy.UseIPLocation {
		lat, lon, err := m.getIPLocation()
		if err == nil {
			times := CalculateSunTimes(*lat, *lon, now)
			sunrise = times.Sunrise
			sunset = times.Sunset
		}
	} else if configCopy.Latitude != nil && configCopy.Longitude != nil {
		times := CalculateSunTimes(*configCopy.Latitude, *configCopy.Longitude, now)
		sunrise = times.Sunrise
		sunset = times.Sunset
	}

	m.transitionMutex.RLock()
	temp := m.currentTemp
	m.transitionMutex.RUnlock()

	nextTransition := m.calculateNextTransition(now)
	isDay := now.After(sunrise) && now.Before(sunset)

	newState := State{
		Config:         configCopy,
		CurrentTemp:    temp,
		NextTransition: nextTransition,
		SunriseTime:    sunrise,
		SunsetTime:     sunset,
		IsDay:          isDay,
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

			m.subscribers.Range(func(key string, ch chan State) bool {
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
	const prepareForSleepSignal = "org.freedesktop.login1.Manager.PrepareForSleep"

	if sig.Name != prepareForSleepSignal {
		return
	}

	if len(sig.Body) == 0 {
		return
	}

	preparing, ok := sig.Body[0].(bool)
	if !ok {
		return
	}

	// When preparing=false, system is resuming from sleep
	if !preparing {
		log.Info("System resumed from suspend, recalculating gamma temperature")
		m.configMutex.RLock()
		enabled := m.config.Enabled
		m.configMutex.RUnlock()

		if enabled {
			m.triggerUpdate()
		}
	}
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
	m.config.LowTemp = low
	m.config.HighTemp = high
	err := m.config.Validate()
	m.configMutex.Unlock()

	if err != nil {
		return err
	}
	m.triggerUpdate()
	return nil
}

func (m *Manager) SetLocation(lat, lon float64) error {
	m.configMutex.Lock()
	m.config.Latitude = &lat
	m.config.Longitude = &lon
	m.config.UseIPLocation = false
	err := m.config.Validate()
	m.configMutex.Unlock()

	if err != nil {
		return err
	}
	m.triggerUpdate()
	return nil
}

func (m *Manager) SetUseIPLocation(use bool) {
	m.configMutex.Lock()
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

func (m *Manager) getIPLocation() (*float64, *float64, error) {
	m.locationMutex.RLock()
	if m.cachedIPLat != nil && m.cachedIPLon != nil {
		lat, lon := m.cachedIPLat, m.cachedIPLon
		m.locationMutex.RUnlock()
		return lat, lon, nil
	}
	m.locationMutex.RUnlock()

	lat, lon, err := FetchIPLocation()
	if err != nil {
		return nil, nil, err
	}

	m.locationMutex.Lock()
	m.cachedIPLat = lat
	m.cachedIPLon = lon
	m.locationMutex.Unlock()

	return lat, lon, nil
}

func (m *Manager) calculateTemperature(now time.Time) int {
	m.configMutex.RLock()
	config := m.config
	m.configMutex.RUnlock()

	if !config.Enabled {
		return config.HighTemp
	}

	var sunrise, sunset time.Time

	if config.ManualSunrise != nil && config.ManualSunset != nil {
		year, month, day := now.Date()
		loc := now.Location()

		sunrise = time.Date(year, month, day,
			config.ManualSunrise.Hour(),
			config.ManualSunrise.Minute(),
			config.ManualSunrise.Second(), 0, loc)
		sunset = time.Date(year, month, day,
			config.ManualSunset.Hour(),
			config.ManualSunset.Minute(),
			config.ManualSunset.Second(), 0, loc)

		if sunset.Before(sunrise) {
			sunset = sunset.Add(24 * time.Hour)
		}
	} else if config.UseIPLocation {
		lat, lon, err := m.getIPLocation()
		if err != nil {
			return config.HighTemp
		}
		times := CalculateSunTimes(*lat, *lon, now)
		sunrise = times.Sunrise
		sunset = times.Sunset
	} else if config.Latitude != nil && config.Longitude != nil {
		times := CalculateSunTimes(*config.Latitude, *config.Longitude, now)
		sunrise = times.Sunrise
		sunset = times.Sunset
	} else {
		return config.LowTemp
	}

	if now.Before(sunrise) || now.After(sunset) {
		return config.LowTemp
	}
	return config.HighTemp
}

func (m *Manager) calculateNextTransition(now time.Time) time.Time {
	m.configMutex.RLock()
	config := m.config
	m.configMutex.RUnlock()

	if !config.Enabled {
		return now.Add(24 * time.Hour)
	}

	var sunrise, sunset time.Time

	if config.ManualSunrise != nil && config.ManualSunset != nil {
		year, month, day := now.Date()
		loc := now.Location()

		sunrise = time.Date(year, month, day,
			config.ManualSunrise.Hour(),
			config.ManualSunrise.Minute(),
			config.ManualSunrise.Second(), 0, loc)
		sunset = time.Date(year, month, day,
			config.ManualSunset.Hour(),
			config.ManualSunset.Minute(),
			config.ManualSunset.Second(), 0, loc)

		if sunset.Before(sunrise) {
			sunset = sunset.Add(24 * time.Hour)
		}
	} else if config.UseIPLocation {
		lat, lon, err := m.getIPLocation()
		if err != nil {
			return now.Add(24 * time.Hour)
		}
		times := CalculateSunTimes(*lat, *lon, now)
		sunrise = times.Sunrise
		sunset = times.Sunset
	} else if config.Latitude != nil && config.Longitude != nil {
		times := CalculateSunTimes(*config.Latitude, *config.Longitude, now)
		sunrise = times.Sunrise
		sunset = times.Sunset
	} else {
		return now.Add(24 * time.Hour)
	}

	if now.Before(sunrise) {
		return sunrise
	}
	if now.Before(sunset) {
		return sunset
	}

	if config.ManualSunrise != nil && config.ManualSunset != nil {
		year, month, day := now.Add(24 * time.Hour).Date()
		loc := now.Location()
		nextSunrise := time.Date(year, month, day,
			config.ManualSunrise.Hour(),
			config.ManualSunrise.Minute(),
			config.ManualSunrise.Second(), 0, loc)
		return nextSunrise
	}

	if config.UseIPLocation {
		lat, lon, err := m.getIPLocation()
		if err != nil {
			return now.Add(24 * time.Hour)
		}
		nextDayTimes := CalculateSunTimes(*lat, *lon, now.Add(24*time.Hour))
		return nextDayTimes.Sunrise
	}

	if config.Latitude != nil && config.Longitude != nil {
		nextDayTimes := CalculateSunTimes(*config.Latitude, *config.Longitude, now.Add(24*time.Hour))
		return nextDayTimes.Sunrise
	}

	return now.Add(24 * time.Hour)
}

func (m *Manager) SetManualTimes(sunrise, sunset time.Time) error {
	m.configMutex.Lock()
	m.config.ManualSunrise = &sunrise
	m.config.ManualSunset = &sunset
	err := m.config.Validate()
	m.configMutex.Unlock()

	if err != nil {
		return err
	}
	m.triggerUpdate()
	return nil
}

func (m *Manager) ClearManualTimes() {
	m.configMutex.Lock()
	m.config.ManualSunrise = nil
	m.config.ManualSunset = nil
	m.configMutex.Unlock()
	m.triggerUpdate()
}

func (m *Manager) SetGamma(gamma float64) error {
	m.configMutex.Lock()
	m.config.Gamma = gamma
	err := m.config.Validate()
	m.configMutex.Unlock()

	if err != nil {
		return err
	}
	m.triggerUpdate()
	return nil
}

func (m *Manager) SetEnabled(enabled bool) {
	m.configMutex.Lock()
	m.config.Enabled = enabled
	m.configMutex.Unlock()

	if enabled {
		if !m.controlsInitialized {
			m.post(func() {
				log.Info("Creating gamma controls")
				gammaMgr := m.gammaControl.(*wlr_gamma_control.ZwlrGammaControlManagerV1)
				if err := func() error {
					var outputs []*wlclient.Output = m.availableOutputs
					return m.setupOutputControls(outputs, gammaMgr)
				}(); err != nil {
					log.Errorf("Failed to create gamma controls: %v", err)
				} else {
					m.controlsInitialized = true
				}
			})
		} else {
			m.triggerUpdate()
		}
	} else {
		if m.controlsInitialized {
			m.configMutex.RLock()
			identityTemp := m.config.HighTemp
			m.configMutex.RUnlock()

			m.transitionMutex.RLock()
			currentTemp := m.currentTemp
			m.transitionMutex.RUnlock()

			if currentTemp == identityTemp {
				m.post(func() {
					log.Infof("Already at %dK, destroying gamma controls immediately", identityTemp)
					m.outputs.Range(func(id uint32, out *outputState) bool {
						if out.gammaControl != nil {
							control := out.gammaControl.(*wlr_gamma_control.ZwlrGammaControlV1)
							control.Destroy()
							log.Debugf("Destroyed gamma control for output %d", id)
						}
						return true
					})
					m.outputs.Range(func(key uint32, value *outputState) bool {
						m.outputs.Delete(key)
						return true
					})
					m.controlsInitialized = false

					m.transitionMutex.Lock()
					m.currentTemp = identityTemp
					m.targetTemp = identityTemp
					m.transitionMutex.Unlock()

					if _, err := m.display.Sync(); err != nil {
						log.Warnf("Failed to sync Wayland display after destroying controls: %v", err)
					}

					log.Info("All gamma controls destroyed")
				})
			} else {
				log.Infof("Disabling: transitioning to %dK before destroying controls", identityTemp)
				m.startTransition(identityTemp)
			}
		}
	}
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

	m.outputs.Range(func(key uint32, out *outputState) bool {
		if control, ok := out.gammaControl.(*wlr_gamma_control.ZwlrGammaControlV1); ok {
			control.Destroy()
		}
		return true
	})
	m.outputs.Range(func(key uint32, value *outputState) bool {
		m.outputs.Delete(key)
		return true
	})

	if manager, ok := m.gammaControl.(*wlr_gamma_control.ZwlrGammaControlManagerV1); ok {
		manager.Destroy()
	}

	if m.dbusConn != nil {
		m.dbusConn.RemoveSignal(m.dbusSignal)
		m.dbusConn.Close()
	}
}

func MemfdCreate(name string, flags int) (int, error) {
	fd, err := unix.MemfdCreate(name, flags)
	if err != nil {
		return -1, err
	}
	return fd, nil
}
