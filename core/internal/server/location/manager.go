package location

import (
	"time"

	"github.com/AvengeMedia/DankMaterialShell/core/internal/geolocation"
	"github.com/AvengeMedia/DankMaterialShell/core/internal/log"
)

func NewManager(client geolocation.Client) (*Manager, error) {
	currLocation, err := client.GetLocation()
	if err != nil {
		log.Warnf("Failed to get initial location: %v", err)
	}

	m := &Manager{
		client:   client,
		dirty:    make(chan struct{}),
		stopChan: make(chan struct{}),

		state: &State{
			Latitude:  currLocation.Latitude,
			Longitude: currLocation.Longitude,
		},
	}

	if err := m.startSignalPump(); err != nil {
		return nil, err
	}

	m.notifierWg.Add(1)
	go m.notifier()

	return m, nil
}

func (m *Manager) Close() {
	close(m.stopChan)
	m.notifierWg.Wait()

	m.sigWG.Wait()

	m.subscribers.Range(func(key string, ch chan State) bool {
		close(ch)
		m.subscribers.Delete(key)
		return true
	})
}

func (m *Manager) Subscribe(id string) chan State {
	ch := make(chan State, 64)
	m.subscribers.Store(id, ch)
	return ch
}

func (m *Manager) Unsubscribe(id string) {
	if ch, ok := m.subscribers.LoadAndDelete(id); ok {
		close(ch)
	}
}

func (m *Manager) startSignalPump() error {
	m.sigWG.Add(1)
	go func() {
		defer m.sigWG.Done()

		subscription := m.client.Subscribe("locationManager")
		defer m.client.Unsubscribe("locationManager")

		for {
			select {
			case <-m.stopChan:
				return
			case location, ok := <-subscription:
				if !ok {
					return
				}

				m.handleLocationChange(location)
			}
		}
	}()

	return nil
}

func (m *Manager) handleLocationChange(location geolocation.Location) {
	m.stateMutex.Lock()
	defer m.stateMutex.Unlock()

	m.state.Latitude = location.Latitude
	m.state.Longitude = location.Longitude

	m.notifySubscribers()
}

func (m *Manager) notifySubscribers() {
	select {
	case m.dirty <- struct{}{}:
	default:
	}
}

func (m *Manager) GetState() State {
	m.stateMutex.RLock()
	defer m.stateMutex.RUnlock()
	if m.state == nil {
		return State{
			Latitude:  0.0,
			Longitude: 0.0,
		}
	}
	stateCopy := *m.state
	return stateCopy
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

			currentState := m.GetState()

			if m.lastNotified != nil && !stateChanged(m.lastNotified, &currentState) {
				pending = false
				continue
			}

			m.subscribers.Range(func(key string, ch chan State) bool {
				select {
				case ch <- currentState:
				default:
					log.Warn("Location: subscriber channel full, dropping update")
				}
				return true
			})

			stateCopy := currentState
			m.lastNotified = &stateCopy
			pending = false
		}
	}
}

func stateChanged(old, new *State) bool {
	if old == nil || new == nil {
		return true
	}
	if old.Latitude != new.Latitude {
		return true
	}
	if old.Longitude != new.Longitude {
		return true
	}

	return false
}
