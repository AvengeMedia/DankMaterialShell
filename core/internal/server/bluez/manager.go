package bluez

import (
	"fmt"
	"strings"
	"sync"
	"time"

	"github.com/AvengeMedia/DankMaterialShell/core/internal/log"
	"github.com/godbus/dbus/v5"
)

const (
	adapter1Iface   = "org.bluez.Adapter1"
	objectMgrIface  = "org.freedesktop.DBus.ObjectManager"
	propertiesIface = "org.freedesktop.DBus.Properties"
)

func NewManager() (*Manager, error) {
	conn, err := dbus.ConnectSystemBus()
	if err != nil {
		return nil, fmt.Errorf("system bus connection failed: %w", err)
	}

	m := &Manager{
		state: &BluetoothState{
			Powered:          false,
			Discovering:      false,
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

	adapter, err := m.findAdapter()
	if err != nil {
		conn.Close()
		return nil, fmt.Errorf("no bluetooth adapter found: %w", err)
	}
	m.adapterPath = adapter

	if err := m.initialize(); err != nil {
		conn.Close()
		return nil, err
	}

	if err := m.startAgent(); err != nil {
		conn.Close()
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

func (m *Manager) findAdapter() (dbus.ObjectPath, error) {
	obj := m.dbusConn.Object(bluezService, dbus.ObjectPath("/"))
	var objects map[dbus.ObjectPath]map[string]map[string]dbus.Variant

	if err := obj.Call(objectMgrIface+".GetManagedObjects", 0).Store(&objects); err != nil {
		return "", err
	}

	for path, interfaces := range objects {
		if _, ok := interfaces[adapter1Iface]; ok {
			log.Infof("[BluezManager] found adapter: %s", path)
			return path, nil
		}
	}

	return "", fmt.Errorf("no adapter found")
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
	obj := m.dbusConn.Object(bluezService, m.adapterPath)

	poweredVar, err := obj.GetProperty(adapter1Iface + ".Powered")
	if err != nil {
		return err
	}
	powered, _ := poweredVar.Value().(bool)

	discoveringVar, err := obj.GetProperty(adapter1Iface + ".Discovering")
	if err != nil {
		return err
	}
	discovering, _ := discoveringVar.Value().(bool)

	m.stateMutex.Lock()
	m.state.Powered = powered
	m.state.Discovering = discovering
	m.stateMutex.Unlock()

	return nil
}

func (m *Manager) updateDevices() error {
	obj := m.dbusConn.Object(bluezService, dbus.ObjectPath("/"))
	var objects map[dbus.ObjectPath]map[string]map[string]dbus.Variant

	if err := obj.Call(objectMgrIface+".GetManagedObjects", 0).Store(&objects); err != nil {
		return err
	}

	devices := []Device{}
	paired := []Device{}
	connected := []Device{}

	for path, interfaces := range objects {
		devProps, ok := interfaces[device1Iface]
		if !ok {
			continue
		}

		if !strings.HasPrefix(string(path), string(m.adapterPath)+"/") {
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

func (m *Manager) deviceFromProps(path string, props map[string]dbus.Variant) Device {
	dev := Device{Path: path}

	if v, ok := props["Address"]; ok {
		if addr, ok := v.Value().(string); ok {
			dev.Address = addr
		}
	}
	if v, ok := props["Name"]; ok {
		if name, ok := v.Value().(string); ok {
			dev.Name = name
		}
	}
	if v, ok := props["Alias"]; ok {
		if alias, ok := v.Value().(string); ok {
			dev.Alias = alias
		}
	}
	if v, ok := props["Paired"]; ok {
		if paired, ok := v.Value().(bool); ok {
			dev.Paired = paired
		}
	}
	if v, ok := props["Trusted"]; ok {
		if trusted, ok := v.Value().(bool); ok {
			dev.Trusted = trusted
		}
	}
	if v, ok := props["Blocked"]; ok {
		if blocked, ok := v.Value().(bool); ok {
			dev.Blocked = blocked
		}
	}
	if v, ok := props["Connected"]; ok {
		if connected, ok := v.Value().(bool); ok {
			dev.Connected = connected
		}
	}
	if v, ok := props["Class"]; ok {
		if class, ok := v.Value().(uint32); ok {
			dev.Class = class
		}
	}
	if v, ok := props["Icon"]; ok {
		if icon, ok := v.Value().(string); ok {
			dev.Icon = icon
		}
	}
	if v, ok := props["RSSI"]; ok {
		if rssi, ok := v.Value().(int16); ok {
			dev.RSSI = rssi
		}
	}
	if v, ok := props["LegacyPairing"]; ok {
		if legacy, ok := v.Value().(bool); ok {
			dev.LegacyPairing = legacy
		}
	}

	return dev
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

	if err := m.dbusConn.AddMatchSignal(
		dbus.WithMatchInterface(propertiesIface),
		dbus.WithMatchMember("PropertiesChanged"),
	); err != nil {
		return err
	}

	if err := m.dbusConn.AddMatchSignal(
		dbus.WithMatchInterface(objectMgrIface),
		dbus.WithMatchMember("InterfacesAdded"),
	); err != nil {
		return err
	}

	if err := m.dbusConn.AddMatchSignal(
		dbus.WithMatchInterface(objectMgrIface),
		dbus.WithMatchMember("InterfacesRemoved"),
	); err != nil {
		return err
	}

	m.sigWG.Add(1)
	go func() {
		defer m.sigWG.Done()
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
	}()

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
			if strings.HasPrefix(string(sig.Path), string(m.adapterPath)) {
				m.handleAdapterPropertiesChanged(changed)
			}
		case device1Iface:
			m.handleDevicePropertiesChanged(sig.Path, changed)
		}

	case objectMgrIface + ".InterfacesAdded":
		m.notifySubscribers()

	case objectMgrIface + ".InterfacesRemoved":
		m.notifySubscribers()
	}
}

func (m *Manager) handleAdapterPropertiesChanged(changed map[string]dbus.Variant) {
	m.stateMutex.Lock()
	dirty := false

	if v, ok := changed["Powered"]; ok {
		if powered, ok := v.Value().(bool); ok {
			m.state.Powered = powered
			dirty = true
		}
	}
	if v, ok := changed["Discovering"]; ok {
		if discovering, ok := v.Value().(bool); ok {
			m.state.Discovering = discovering
			dirty = true
		}
	}

	m.stateMutex.Unlock()

	if dirty {
		m.notifySubscribers()
	}
}

func (m *Manager) handleDevicePropertiesChanged(path dbus.ObjectPath, changed map[string]dbus.Variant) {
	pairedVar, hasPaired := changed["Paired"]
	_, hasConnected := changed["Connected"]
	_, hasTrusted := changed["Trusted"]

	if hasPaired {
		if paired, ok := pairedVar.Value().(bool); ok && paired {
			devicePath := string(path)
			_, wasPending := m.pendingPairings.LoadAndDelete(devicePath)

			if wasPending {
				select {
				case m.eventQueue <- func() {
					time.Sleep(300 * time.Millisecond)
					log.Infof("[Bluetooth] Auto-connecting newly paired device: %s", devicePath)
					if err := m.ConnectDevice(devicePath); err != nil {
						log.Warnf("[Bluetooth] Auto-connect failed: %v", err)
					}
				}:
				default:
				}
			}
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

func (m *Manager) StartDiscovery() error {
	obj := m.dbusConn.Object(bluezService, m.adapterPath)
	return obj.Call(adapter1Iface+".StartDiscovery", 0).Err
}

func (m *Manager) StopDiscovery() error {
	obj := m.dbusConn.Object(bluezService, m.adapterPath)
	return obj.Call(adapter1Iface+".StopDiscovery", 0).Err
}

func (m *Manager) SetPowered(powered bool) error {
	obj := m.dbusConn.Object(bluezService, m.adapterPath)
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
	obj := m.dbusConn.Object(bluezService, m.adapterPath)
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

	if m.dbusConn != nil {
		m.dbusConn.Close()
	}
}

func stateChanged(old, new *BluetoothState) bool {
	if old.Powered != new.Powered {
		return true
	}
	if old.Discovering != new.Discovering {
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
