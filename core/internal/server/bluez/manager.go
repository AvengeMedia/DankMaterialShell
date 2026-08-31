package bluez

import (
	"fmt"
	"slices"
	"strings"
	"sync"
	"time"

	"github.com/AvengeMedia/DankMaterialShell/core/internal/log"
	"github.com/AvengeMedia/dankgo/dbusutil"
	"github.com/godbus/dbus/v5"
)

const (
	adapter1Iface   = "org.bluez.Adapter1"
	objectMgrIface  = "org.freedesktop.DBus.ObjectManager"
	propertiesIface = "org.freedesktop.DBus.Properties"
)

var bluezMatchRules = [][]dbus.MatchOption{
	{dbus.WithMatchInterface(propertiesIface), dbus.WithMatchMember("PropertiesChanged")},
	{dbus.WithMatchInterface(objectMgrIface), dbus.WithMatchMember("InterfacesAdded")},
	{dbus.WithMatchInterface(objectMgrIface), dbus.WithMatchMember("InterfacesRemoved")},
}

func NewManager() (*Manager, error) {
	conn, err := dbus.SystemBus()
	if err != nil {
		return nil, fmt.Errorf("system bus connection failed: %w", err)
	}

	m := &Manager{
		state: &BluetoothState{
			Powered:          false,
			Discovering:      false,
			Adapters:         []AdapterInfo{},
			Devices:          []Device{},
			PairedDevices:    []Device{},
			ConnectedDevices: []Device{},
		},
		stateMutex: sync.RWMutex{},

		stopChan:   make(chan struct{}),
		dbusConn:   conn,
		signals:    make(chan *dbus.Signal, 256),
		dirty:      make(chan struct{}, 1),
		eventQueue: make(chan func(), 32),
	}

	broker := NewSubscriptionBroker(m.broadcastPairingPrompt)
	m.promptBroker = broker

	adapters, err := scanAdapters(conn)
	if err != nil {
		return nil, fmt.Errorf("%w: %v", ErrNoAdapter, err)
	}
	if len(adapters) == 0 {
		return nil, ErrNoAdapter
	}
	m.adapterPaths = adapters
	log.Infof("[BluezManager] adapters: %v (default: %s)", adapters, adapters[0])

	if err := m.initialize(); err != nil {
		return nil, err
	}

	if err := m.startAgent(); err != nil {
		return nil, fmt.Errorf("agent start failed: %w", err)
	}

	if err := m.startSignalPump(); err != nil {
		m.Close()
		return nil, err
	}

	m.notifierWg.Add(1)
	go m.notifier()

	m.eventWg.Add(1)
	go m.eventWorker()

	return m, nil
}

func scanAdapters(conn *dbus.Conn) ([]dbus.ObjectPath, error) {
	obj := conn.Object(bluezService, dbus.ObjectPath("/"))
	var objects map[dbus.ObjectPath]map[string]map[string]dbus.Variant

	if err := obj.Call(objectMgrIface+".GetManagedObjects", 0).Store(&objects); err != nil {
		return nil, err
	}

	paths := []dbus.ObjectPath{}
	for path, interfaces := range objects {
		if _, ok := interfaces[adapter1Iface]; ok {
			paths = append(paths, path)
		}
	}
	slices.Sort(paths)
	return paths, nil
}

func (m *Manager) adapterPathsSnapshot() []dbus.ObjectPath {
	m.stateMutex.RLock()
	defer m.stateMutex.RUnlock()
	return append([]dbus.ObjectPath(nil), m.adapterPaths...)
}

func (m *Manager) resolveAdapter(adapterPath string) (dbus.ObjectPath, error) {
	m.stateMutex.RLock()
	defer m.stateMutex.RUnlock()

	if len(m.adapterPaths) == 0 {
		return "", ErrNoAdapter
	}
	if adapterPath == "" {
		return m.adapterPaths[0], nil
	}
	if !slices.Contains(m.adapterPaths, dbus.ObjectPath(adapterPath)) {
		return "", fmt.Errorf("unknown adapter: %s", adapterPath)
	}
	return dbus.ObjectPath(adapterPath), nil
}

func (m *Manager) refreshAdapters() {
	paths, err := scanAdapters(m.dbusConn)
	if err != nil {
		log.Warnf("[BluezManager] adapter scan failed: %v", err)
		return
	}

	m.stateMutex.Lock()
	changed := !slices.Equal(m.adapterPaths, paths)
	m.adapterPaths = paths
	m.stateMutex.Unlock()

	if !changed {
		return
	}
	log.Infof("[BluezManager] adapters changed: %v", paths)
	if err := m.updateAdapterState(); err != nil {
		log.Warnf("[BluezManager] adapter state refresh failed: %v", err)
	}
	m.notifySubscribers()
}

func (m *Manager) initialize() error {
	if err := m.updateAdapterState(); err != nil {
		return err
	}

	if err := m.updateDevices(); err != nil {
		return err
	}

	return nil
}

func (m *Manager) updateAdapterState() error {
	paths := m.adapterPathsSnapshot()
	adapters := make([]AdapterInfo, 0, len(paths))

	for _, path := range paths {
		obj := m.dbusConn.Object(bluezService, path)

		poweredVar, err := obj.GetProperty(adapter1Iface + ".Powered")
		if err != nil {
			return err
		}
		discoveringVar, err := obj.GetProperty(adapter1Iface + ".Discovering")
		if err != nil {
			return err
		}
		aliasVar, _ := obj.GetProperty(adapter1Iface + ".Alias")
		addressVar, _ := obj.GetProperty(adapter1Iface + ".Address")

		adapters = append(adapters, AdapterInfo{
			Path:        string(path),
			Name:        dbusutil.AsOr(aliasVar, ""),
			Address:     dbusutil.AsOr(addressVar, ""),
			Powered:     dbusutil.AsOr(poweredVar, false),
			Discovering: dbusutil.AsOr(discoveringVar, false),
		})
	}

	m.stateMutex.Lock()
	m.state.Adapters = adapters
	m.state.Powered = len(adapters) > 0 && adapters[0].Powered
	m.state.Discovering = len(adapters) > 0 && adapters[0].Discovering
	m.stateMutex.Unlock()

	return nil
}

func (m *Manager) updateDevices() error {
	obj := m.dbusConn.Object(bluezService, dbus.ObjectPath("/"))
	var objects map[dbus.ObjectPath]map[string]map[string]dbus.Variant

	if err := obj.Call(objectMgrIface+".GetManagedObjects", 0).Store(&objects); err != nil {
		return err
	}

	adapters := m.adapterPathsSnapshot()
	devices := []Device{}
	paired := []Device{}
	connected := []Device{}

	for path, interfaces := range objects {
		devProps, ok := interfaces[device1Iface]
		if !ok {
			continue
		}

		if !deviceOnAnyAdapter(path, adapters) {
			continue
		}

		dev := m.deviceFromProps(string(path), devProps)
		devices = append(devices, dev)

		if dev.Paired {
			paired = append(paired, dev)
		}
		if dev.Connected {
			connected = append(connected, dev)
		}
	}

	m.stateMutex.Lock()
	m.state.Devices = devices
	m.state.PairedDevices = paired
	m.state.ConnectedDevices = connected
	m.stateMutex.Unlock()

	return nil
}

func deviceOnAnyAdapter(path dbus.ObjectPath, adapters []dbus.ObjectPath) bool {
	for _, adapter := range adapters {
		if strings.HasPrefix(string(path), string(adapter)+"/") {
			return true
		}
	}
	return false
}

func (m *Manager) deviceFromProps(path string, props map[string]dbus.Variant) Device {
	return Device{
		Path:          path,
		Address:       dbusutil.GetOr(props, "Address", ""),
		Name:          dbusutil.GetOr(props, "Name", ""),
		Alias:         dbusutil.GetOr(props, "Alias", ""),
		Paired:        dbusutil.GetOr(props, "Paired", false),
		Trusted:       dbusutil.GetOr(props, "Trusted", false),
		Blocked:       dbusutil.GetOr(props, "Blocked", false),
		Connected:     dbusutil.GetOr(props, "Connected", false),
		Class:         dbusutil.GetOr(props, "Class", uint32(0)),
		Icon:          dbusutil.GetOr(props, "Icon", ""),
		RSSI:          dbusutil.GetOr(props, "RSSI", int16(0)),
		LegacyPairing: dbusutil.GetOr(props, "LegacyPairing", false),
	}
}

func (m *Manager) startAgent() error {
	if m.promptBroker == nil {
		return fmt.Errorf("prompt broker not initialized")
	}

	agent, err := NewBluezAgent(m.promptBroker)
	if err != nil {
		return err
	}

	m.agent = agent
	return nil
}

func (m *Manager) startSignalPump() error {
	m.dbusConn.Signal(m.signals)

	for _, rule := range bluezMatchRules {
		if err := m.dbusConn.AddMatchSignal(rule...); err != nil {
			return err
		}
	}

	m.sigWG.Go(func() {
		for {
			select {
			case <-m.stopChan:
				return
			case sig, ok := <-m.signals:
				if !ok {
					return
				}
				if sig == nil {
					continue
				}
				m.handleSignal(sig)
			}
		}
	})

	return nil
}

func (m *Manager) handleSignal(sig *dbus.Signal) {
	switch sig.Name {
	case propertiesIface + ".PropertiesChanged":
		if len(sig.Body) < 2 {
			return
		}

		iface, ok := sig.Body[0].(string)
		if !ok {
			return
		}

		changed, ok := sig.Body[1].(map[string]dbus.Variant)
		if !ok {
			return
		}

		switch iface {
		case adapter1Iface:
			m.handleAdapterPropertiesChanged(sig.Path, changed)
		case device1Iface:
			m.handleDevicePropertiesChanged(sig.Path, changed)
		}

	case objectMgrIface + ".InterfacesAdded":
		m.maybeRefreshAdapters(sig)
		m.notifySubscribers()

	case objectMgrIface + ".InterfacesRemoved":
		m.maybeRefreshAdapters(sig)
		m.notifySubscribers()
	}
}

func (m *Manager) maybeRefreshAdapters(sig *dbus.Signal) {
	if !signalTouchesAdapter(sig) {
		return
	}
	select {
	case m.eventQueue <- m.refreshAdapters:
	default:
	}
}

func signalTouchesAdapter(sig *dbus.Signal) bool {
	if len(sig.Body) < 2 {
		return false
	}
	switch ifaces := sig.Body[1].(type) {
	case map[string]map[string]dbus.Variant:
		_, ok := ifaces[adapter1Iface]
		return ok
	case []string:
		return slices.Contains(ifaces, adapter1Iface)
	default:
		return false
	}
}

func (m *Manager) handleAdapterPropertiesChanged(path dbus.ObjectPath, changed map[string]dbus.Variant) {
	powered, hasPowered := dbusutil.Get[bool](changed, "Powered")
	discovering, hasDiscovering := dbusutil.Get[bool](changed, "Discovering")
	if !hasPowered && !hasDiscovering {
		return
	}

	m.stateMutex.Lock()
	dirty := false
	for i := range m.state.Adapters {
		if m.state.Adapters[i].Path != string(path) {
			continue
		}
		if hasPowered {
			m.state.Adapters[i].Powered = powered
		}
		if hasDiscovering {
			m.state.Adapters[i].Discovering = discovering
		}
		dirty = true
	}
	if len(m.adapterPaths) > 0 && m.adapterPaths[0] == path {
		if hasPowered {
			m.state.Powered = powered
		}
		if hasDiscovering {
			m.state.Discovering = discovering
		}
		dirty = true
	}
	m.stateMutex.Unlock()

	if !dirty {
		return
	}
	m.notifySubscribers()
}

func (m *Manager) handleDevicePropertiesChanged(path dbus.ObjectPath, changed map[string]dbus.Variant) {
	paired, hasPaired := dbusutil.Get[bool](changed, "Paired")
	_, hasConnected := changed["Connected"]
	_, hasTrusted := changed["Trusted"]

	if hasPaired {
		devicePath := string(path)
		if paired {
			_, wasPending := m.pendingPairings.LoadAndDelete(devicePath)
			if wasPending {
				select {
				case m.eventQueue <- func() {
					time.Sleep(300 * time.Millisecond)
					log.Infof("[Bluetooth] Auto-trusting newly paired device: %s", devicePath)
					if err := m.TrustDevice(devicePath, true); err != nil {
						log.Warnf("[Bluetooth] Auto-trust failed: %v", err)
					}
					log.Infof("[Bluetooth] Auto-connecting newly paired device: %s", devicePath)
					if err := m.ConnectDevice(devicePath); err != nil {
						log.Warnf("[Bluetooth] Auto-connect failed: %v", err)
					}
				}:
				default:
				}
			}
		} else {
			m.pendingPairings.Delete(devicePath)
		}
	}

	if hasPaired || hasConnected || hasTrusted {
		select {
		case m.eventQueue <- func() {
			time.Sleep(100 * time.Millisecond)
			m.updateDevices()
			m.notifySubscribers()
		}:
		default:
		}
	}
}

func (m *Manager) eventWorker() {
	defer m.eventWg.Done()
	for {
		select {
		case <-m.stopChan:
			return
		case event := <-m.eventQueue:
			event()
		}
	}
}

func (m *Manager) notifier() {
	defer m.notifierWg.Done()
	const minGap = 200 * time.Millisecond
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
			m.updateDevices()

			currentState := m.snapshotState()

			if m.lastNotifiedState != nil && !stateChanged(m.lastNotifiedState, &currentState) {
				pending = false
				continue
			}

			m.subscribers.Range(func(key string, ch chan BluetoothState) bool {
				select {
				case ch <- currentState:
				default:
				}
				return true
			})

			stateCopy := currentState
			m.lastNotifiedState = &stateCopy
			pending = false
		}
	}
}

func (m *Manager) notifySubscribers() {
	select {
	case m.dirty <- struct{}{}:
	default:
	}
}

func (m *Manager) GetState() BluetoothState {
	return m.snapshotState()
}

func (m *Manager) snapshotState() BluetoothState {
	m.stateMutex.RLock()
	defer m.stateMutex.RUnlock()

	s := *m.state
	s.Devices = append([]Device(nil), m.state.Devices...)
	s.PairedDevices = append([]Device(nil), m.state.PairedDevices...)
	s.ConnectedDevices = append([]Device(nil), m.state.ConnectedDevices...)
	return s
}

func (m *Manager) Subscribe(id string) chan BluetoothState {
	ch := make(chan BluetoothState, 64)
	m.subscribers.Store(id, ch)
	return ch
}

func (m *Manager) Unsubscribe(id string) {
	if ch, ok := m.subscribers.LoadAndDelete(id); ok {
		close(ch)
	}
}

func (m *Manager) SubscribePairing(id string) chan PairingPrompt {
	ch := make(chan PairingPrompt, 16)
	m.pairingSubscribers.Store(id, ch)
	return ch
}

func (m *Manager) UnsubscribePairing(id string) {
	if ch, ok := m.pairingSubscribers.LoadAndDelete(id); ok {
		close(ch)
	}
}

func (m *Manager) broadcastPairingPrompt(prompt PairingPrompt) {
	m.pairingSubscribers.Range(func(key string, ch chan PairingPrompt) bool {
		select {
		case ch <- prompt:
		default:
		}
		return true
	})
}

func (m *Manager) SubmitPairing(token string, secrets map[string]string, accept bool) error {
	if m.promptBroker == nil {
		return fmt.Errorf("prompt broker not initialized")
	}

	return m.promptBroker.Resolve(token, PromptReply{
		Secrets: secrets,
		Accept:  accept,
		Cancel:  false,
	})
}

func (m *Manager) CancelPairing(token string) error {
	if m.promptBroker == nil {
		return fmt.Errorf("prompt broker not initialized")
	}

	return m.promptBroker.Resolve(token, PromptReply{
		Cancel: true,
	})
}

func (m *Manager) StartDiscovery(adapterPath string) error {
	path, err := m.resolveAdapter(adapterPath)
	if err != nil {
		return err
	}
	obj := m.dbusConn.Object(bluezService, path)
	return obj.Call(adapter1Iface+".StartDiscovery", 0).Err
}

func (m *Manager) StopDiscovery(adapterPath string) error {
	path, err := m.resolveAdapter(adapterPath)
	if err != nil {
		return err
	}
	obj := m.dbusConn.Object(bluezService, path)
	return obj.Call(adapter1Iface+".StopDiscovery", 0).Err
}

func (m *Manager) SetPowered(adapterPath string, powered bool) error {
	path, err := m.resolveAdapter(adapterPath)
	if err != nil {
		return err
	}
	return m.setPoweredAt(path, powered)
}

func (m *Manager) TogglePowered(adapterPath string) (bool, error) {
	path, err := m.resolveAdapter(adapterPath)
	if err != nil {
		return false, err
	}

	poweredVar, err := m.dbusConn.Object(bluezService, path).GetProperty(adapter1Iface + ".Powered")
	if err != nil {
		return false, err
	}

	target := !dbusutil.AsOr(poweredVar, false)
	if err := m.setPoweredAt(path, target); err != nil {
		return false, err
	}
	return target, nil
}

func (m *Manager) setPoweredAt(path dbus.ObjectPath, powered bool) error {
	if powered {
		if err := rfkillUnblockBluetooth(); err != nil {
			log.Debugf("[BluezManager] rfkill unblock failed: %v", err)
		}
	}
	obj := m.dbusConn.Object(bluezService, path)
	return obj.Call(propertiesIface+".Set", 0, adapter1Iface, "Powered", dbus.MakeVariant(powered)).Err
}

func (m *Manager) PairDevice(devicePath string) error {
	m.pendingPairings.Store(devicePath, true)

	obj := m.dbusConn.Object(bluezService, dbus.ObjectPath(devicePath))
	err := obj.Call(device1Iface+".Pair", 0).Err

	if err != nil {
		m.pendingPairings.Delete(devicePath)
	}

	return err
}

func (m *Manager) ConnectDevice(devicePath string) error {
	obj := m.dbusConn.Object(bluezService, dbus.ObjectPath(devicePath))
	return obj.Call(device1Iface+".Connect", 0).Err
}

func (m *Manager) DisconnectDevice(devicePath string) error {
	obj := m.dbusConn.Object(bluezService, dbus.ObjectPath(devicePath))
	return obj.Call(device1Iface+".Disconnect", 0).Err
}

func (m *Manager) RemoveDevice(devicePath string) error {
	idx := strings.LastIndex(devicePath, "/")
	if idx <= 0 {
		return fmt.Errorf("invalid device path: %s", devicePath)
	}
	obj := m.dbusConn.Object(bluezService, dbus.ObjectPath(devicePath[:idx]))
	return obj.Call(adapter1Iface+".RemoveDevice", 0, dbus.ObjectPath(devicePath)).Err
}

func (m *Manager) TrustDevice(devicePath string, trusted bool) error {
	obj := m.dbusConn.Object(bluezService, dbus.ObjectPath(devicePath))
	return obj.Call(propertiesIface+".Set", 0, device1Iface, "Trusted", dbus.MakeVariant(trusted)).Err
}

func (m *Manager) Close() {
	close(m.stopChan)
	m.notifierWg.Wait()
	m.eventWg.Wait()

	m.sigWG.Wait()

	if m.signals != nil {
		m.dbusConn.RemoveSignal(m.signals)
		close(m.signals)
	}
	for _, rule := range bluezMatchRules {
		_ = m.dbusConn.RemoveMatchSignal(rule...)
	}

	if m.agent != nil {
		m.agent.Close()
	}

	m.subscribers.Range(func(key string, ch chan BluetoothState) bool {
		close(ch)
		m.subscribers.Delete(key)
		return true
	})

	m.pairingSubscribers.Range(func(key string, ch chan PairingPrompt) bool {
		close(ch)
		m.pairingSubscribers.Delete(key)
		return true
	})
}

func stateChanged(old, new *BluetoothState) bool {
	if old.Powered != new.Powered {
		return true
	}
	if old.Discovering != new.Discovering {
		return true
	}
	if !slices.Equal(old.Adapters, new.Adapters) {
		return true
	}
	if len(old.Devices) != len(new.Devices) {
		return true
	}
	if len(old.PairedDevices) != len(new.PairedDevices) {
		return true
	}
	if len(old.ConnectedDevices) != len(new.ConnectedDevices) {
		return true
	}
	for i := range old.Devices {
		if old.Devices[i].Path != new.Devices[i].Path {
			return true
		}
		if old.Devices[i].Paired != new.Devices[i].Paired {
			return true
		}
		if old.Devices[i].Connected != new.Devices[i].Connected {
			return true
		}
	}
	return false
}
