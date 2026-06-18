package network

import (
	"fmt"
	"time"

	"github.com/godbus/dbus/v5"
)

func (b *IWDBackend) StartMonitoring(onStateChange func()) error {
	b.onStateChange = onStateChange

	if b.promptBroker != nil {
		agent, err := NewIWDAgent(b.conn, b.promptBroker)
		if err != nil {
			return fmt.Errorf("failed to start IWD agent: %w", err)
		}
		agent.onUserCanceled = b.OnUserCanceledPrompt
		agent.onPromptRetry = b.OnPromptRetry
		b.iwdAgent = agent
	}

	sigChan := make(chan *dbus.Signal, 100)
	b.conn.Signal(sigChan)

	if b.devicePath != "" {
		err := b.conn.AddMatchSignal(
			dbus.WithMatchObjectPath(b.devicePath),
			dbus.WithMatchInterface(dbusPropertiesInterface),
			dbus.WithMatchMember("PropertiesChanged"),
		)
		if err != nil {
			return fmt.Errorf("failed to add device signal match: %w", err)
		}
	}

	if b.stationPath != "" {
		err := b.conn.AddMatchSignal(
			dbus.WithMatchObjectPath(b.stationPath),
			dbus.WithMatchInterface(dbusPropertiesInterface),
			dbus.WithMatchMember("PropertiesChanged"),
		)
		if err != nil {
			return fmt.Errorf("failed to add station signal match: %w", err)
		}
	}

	if err := b.conn.AddMatchSignal(
		dbus.WithMatchInterface(dbusPropertiesInterface),
		dbus.WithMatchMember("PropertiesChanged"),
		dbus.WithMatchArg(0, iwdKnownNetworkInterface),
	); err != nil {
		return fmt.Errorf("failed to add known network signal match: %w", err)
	}

	if err := b.conn.AddMatchSignal(
		dbus.WithMatchInterface(dbusObjectManager),
		dbus.WithMatchMember("InterfacesAdded"),
	); err != nil {
		return fmt.Errorf("failed to add iwd interfaces-added signal match: %w", err)
	}

	if err := b.conn.AddMatchSignal(
		dbus.WithMatchInterface(dbusObjectManager),
		dbus.WithMatchMember("InterfacesRemoved"),
	); err != nil {
		return fmt.Errorf("failed to add iwd interfaces-removed signal match: %w", err)
	}

	b.sigWG.Add(1)
	go b.signalHandler(sigChan)

	return nil
}

func (b *IWDBackend) refreshWiFiNetworkState() bool {
	_, err := b.updateWiFiNetworks()
	if err == nil {
		return true
	}
	return b.updateSavedWiFiNetworks() == nil
}

func (b *IWDBackend) signalHandler(sigChan chan *dbus.Signal) {
	defer b.sigWG.Done()

	for {
		select {
		case <-b.stopChan:
			b.conn.RemoveSignal(sigChan)
			close(sigChan)
			return

		case sig := <-sigChan:
			if sig == nil {
				return
			}

			if sig.Name == dbusObjectManager+".InterfacesAdded" {
				if len(sig.Body) >= 2 {
					if interfaces, ok := sig.Body[1].(map[string]map[string]dbus.Variant); ok {
						if _, ok := interfaces[iwdKnownNetworkInterface]; ok {
							if b.refreshWiFiNetworkState() && b.onStateChange != nil {
								b.onStateChange()
							}
						}
					}
				}
				continue
			}

			if sig.Name == dbusObjectManager+".InterfacesRemoved" {
				if len(sig.Body) >= 2 {
					if interfaces, ok := sig.Body[1].([]string); ok {
						for _, iface := range interfaces {
							if iface == iwdKnownNetworkInterface {
								if b.refreshWiFiNetworkState() && b.onStateChange != nil {
									b.onStateChange()
								}
								break
							}
						}
					}
				}
				continue
			}

			if sig.Name != dbusPropertiesInterface+".PropertiesChanged" || len(sig.Body) < 2 {
				continue
			}

			iface, ok := sig.Body[0].(string)
			if !ok {
				continue
			}

			changed, ok := sig.Body[1].(map[string]dbus.Variant)
			if !ok {
				continue
			}

			stateChanged := false

			switch iface {
			case iwdKnownNetworkInterface:
				stateChanged = b.refreshWiFiNetworkState()

			case iwdDeviceInterface:
				if sig.Path == b.devicePath {
					if poweredVar, ok := changed["Powered"]; ok {
						if powered, ok := poweredVar.Value().(bool); ok {
							b.stateMutex.Lock()
							if b.state.WiFiEnabled != powered {
								b.state.WiFiEnabled = powered
								stateChanged = true
							}
							b.stateMutex.Unlock()
						}
					}
				}

			case iwdStationInterface:
				if sig.Path == b.stationPath {
					if scanningVar, ok := changed["Scanning"]; ok {
						if scanning, ok := scanningVar.Value().(bool); ok && !scanning {
							stateChanged = b.refreshWiFiNetworkState() || stateChanged

							b.stateMutex.RLock()
							wifiConnected := b.state.WiFiConnected
							b.stateMutex.RUnlock()

							if wifiConnected {
								stationObj := b.conn.Object(iwdBusName, b.stationPath)
								connNetVar, err := stationObj.GetProperty(iwdStationInterface + ".ConnectedNetwork")
								if err == nil && connNetVar.Value() != nil {
									if netPath, ok := connNetVar.Value().(dbus.ObjectPath); ok && netPath != "/" {
										var orderedNetworks [][]dbus.Variant
										err = stationObj.Call(iwdStationInterface+".GetOrderedNetworks", 0).Store(&orderedNetworks)
										if err == nil {
											for _, netData := range orderedNetworks {
												if len(netData) < 2 {
													continue
												}
												currentNetPath, ok := netData[0].Value().(dbus.ObjectPath)
												if !ok || currentNetPath != netPath {
													continue
												}
												signalStrength, ok := netData[1].Value().(int16)
												if !ok {
													continue
												}
												signalDbm := signalStrength / 100
												signal := uint8(signalDbm + 100)
												if signalDbm > 0 {
													signal = 100
												} else if signalDbm < -100 {
													signal = 0
												}
												b.stateMutex.Lock()
												if b.state.WiFiSignal != signal {
													b.state.WiFiSignal = signal
													stateChanged = true
												}
												b.stateMutex.Unlock()
												break
											}
										}
									}
								}
							}
						}
					}

					if stateVar, ok := changed["State"]; ok {
						if state, ok := stateVar.Value().(string); ok {
							b.attemptMutex.RLock()
							att := b.curAttempt
							b.attemptMutex.RUnlock()

							var connPath dbus.ObjectPath
							if v, ok := changed["ConnectedNetwork"]; ok {
								if v.Value() != nil {
									if p, ok := v.Value().(dbus.ObjectPath); ok {
										connPath = p
									}
								}
							}
							if connPath == "" {
								station := b.conn.Object(iwdBusName, b.stationPath)
								if cnVar, err := station.GetProperty(iwdStationInterface + ".ConnectedNetwork"); err == nil && cnVar.Value() != nil {
									cnVar.Store(&connPath)
								}
							}

							b.stateMutex.RLock()
							prevConnected := b.state.WiFiConnected
							prevSSID := b.state.WiFiSSID
							b.stateMutex.RUnlock()

							targetPath := dbus.ObjectPath("")
							if att != nil {
								targetPath = att.netPath
							}

							isTarget := att != nil && targetPath != "" && connPath == targetPath

							if att != nil {
								switch state {
								case "authenticating", "associating", "associated", "roaming":
									att.mu.Lock()
									att.sawAuthish = true
									att.mu.Unlock()
								}
							}

							if att != nil && state == "connected" && isTarget {
								att.mu.Lock()
								if att.connectedAt.IsZero() {
									att.connectedAt = time.Now()
								}
								att.mu.Unlock()
							}

							if att != nil && state == "configuring" {
								att.mu.Lock()
								att.sawIPConfig = true
								att.mu.Unlock()
							}

							switch state {
							case "connected":
								b.stateMutex.Lock()
								b.state.WiFiConnected = true
								b.state.NetworkStatus = StatusWiFi
								b.state.IsConnecting = false
								b.state.ConnectingSSID = ""
								b.state.LastError = ""
								b.stateMutex.Unlock()

								if connPath != "" && connPath != "/" {
									netObj := b.conn.Object(iwdBusName, connPath)
									if nameVar, err := netObj.GetProperty(iwdNetworkInterface + ".Name"); err == nil {
										if name, ok := nameVar.Value().(string); ok {
											b.stateMutex.Lock()
											b.state.WiFiSSID = name
											b.stateMutex.Unlock()
										}
									}
								}

								b.refreshWiFiNetworkState()
								stateChanged = true

								if att != nil && isTarget {
									go func(attLocal *connectAttempt, tgt dbus.ObjectPath) {
										time.Sleep(3 * time.Second)
										station := b.conn.Object(iwdBusName, b.stationPath)
										var nowState string
										if stVar, err := station.GetProperty(iwdStationInterface + ".State"); err == nil {
											stVar.Store(&nowState)
										}
										var nowConn dbus.ObjectPath
										if cnVar, err := station.GetProperty(iwdStationInterface + ".ConnectedNetwork"); err == nil && cnVar.Value() != nil {
											cnVar.Store(&nowConn)
										}

										if nowState == "connected" && nowConn == tgt {
											b.finalizeAttempt(attLocal, "")
											b.attemptMutex.Lock()
											if b.curAttempt == attLocal {
												b.curAttempt = nil
											}
											b.attemptMutex.Unlock()
										}
									}(att, targetPath)
								}

							case "disconnecting", "disconnected":
								if att != nil {
									wasConnectedToTarget := prevConnected && prevSSID == att.ssid
									if wasConnectedToTarget || isTarget {
										code := b.classifyAttempt(att)
										b.finalizeAttempt(att, code)
										b.attemptMutex.Lock()
										if b.curAttempt == att {
											b.curAttempt = nil
										}
										b.attemptMutex.Unlock()
									}
								}

								b.stateMutex.Lock()
								b.state.WiFiConnected = false
								if state == "disconnected" {
									b.state.NetworkStatus = StatusDisconnected
								}
								b.stateMutex.Unlock()
								b.refreshWiFiNetworkState()
								stateChanged = true
							}
						}
					}

					if connNetVar, ok := changed["ConnectedNetwork"]; ok {
						if netPath, ok := connNetVar.Value().(dbus.ObjectPath); ok && netPath != "/" {
							netObj := b.conn.Object(iwdBusName, netPath)
							nameVar, err := netObj.GetProperty(iwdNetworkInterface + ".Name")
							if err == nil {
								if name, ok := nameVar.Value().(string); ok {
									b.stateMutex.Lock()
									if b.state.WiFiSSID != name {
										b.state.WiFiSSID = name
										stateChanged = true
									}
									b.stateMutex.Unlock()
								}
							}

							stationObj := b.conn.Object(iwdBusName, b.stationPath)
							var orderedNetworks [][]dbus.Variant
							err = stationObj.Call(iwdStationInterface+".GetOrderedNetworks", 0).Store(&orderedNetworks)
							if err == nil {
								for _, netData := range orderedNetworks {
									if len(netData) < 2 {
										continue
									}
									currentNetPath, ok := netData[0].Value().(dbus.ObjectPath)
									if !ok || currentNetPath != netPath {
										continue
									}
									signalStrength, ok := netData[1].Value().(int16)
									if !ok {
										continue
									}
									signalDbm := signalStrength / 100
									signal := uint8(signalDbm + 100)
									if signalDbm > 0 {
										signal = 100
									} else if signalDbm < -100 {
										signal = 0
									}
									b.stateMutex.Lock()
									if b.state.WiFiSignal != signal {
										b.state.WiFiSignal = signal
										stateChanged = true
									}
									b.stateMutex.Unlock()
									break
								}
							}
						} else {
							b.stateMutex.Lock()
							if b.state.WiFiSSID != "" {
								b.state.WiFiSSID = ""
								b.state.WiFiSignal = 0
								stateChanged = true
							}
							b.stateMutex.Unlock()
							b.refreshWiFiNetworkState()
						}
					}
				}
			}

			if stateChanged && b.onStateChange != nil {
				b.onStateChange()
			}
		}
	}
}
