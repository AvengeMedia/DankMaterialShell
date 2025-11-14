package extworkspace

import (
	"fmt"
	"time"

	"github.com/AvengeMedia/DankMaterialShell/core/internal/log"
	"github.com/AvengeMedia/DankMaterialShell/core/internal/proto/ext_workspace"
	wlclient "github.com/yaslama/go-wayland/wayland/client"
)

func NewManager(display *wlclient.Display) (*Manager, error) {
	m := &Manager{
		display:     display,
		outputs:     make(map[uint32]*wlclient.Output),
		outputNames: make(map[uint32]string),
		groups:      make(map[uint32]*workspaceGroupState),
		workspaces:  make(map[uint32]*workspaceState),
		cmdq:        make(chan cmd, 128),
		stopChan:    make(chan struct{}),
		subscribers: make(map[string]chan State),
		dirty:       make(chan struct{}, 1),
	}

	m.wg.Add(1)
	go m.waylandActor()

	if err := m.setupRegistry(); err != nil {
		close(m.stopChan)
		m.wg.Wait()
		return nil, err
	}

	m.updateState()

	m.notifierWg.Add(1)
	go m.notifier()

	return m, nil
}

func (m *Manager) post(fn func()) {
	select {
	case m.cmdq <- cmd{fn: fn}:
	default:
		log.Warn("ExtWorkspace actor command queue full, dropping command")
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

func (m *Manager) setupRegistry() error {
	log.Info("ExtWorkspace: starting registry setup")
	ctx := m.display.Context()

	registry, err := m.display.GetRegistry()
	if err != nil {
		return fmt.Errorf("failed to get registry: %w", err)
	}
	m.registry = registry

	registry.SetGlobalHandler(func(e wlclient.RegistryGlobalEvent) {
		if e.Interface == "wl_output" {
			output := wlclient.NewOutput(ctx)
			if err := registry.Bind(e.Name, e.Interface, 4, output); err == nil {
				outputID := output.ID()

				output.SetNameHandler(func(ev wlclient.OutputNameEvent) {
					m.outputsMutex.Lock()
					m.outputNames[outputID] = ev.Name
					m.outputsMutex.Unlock()
					log.Debugf("ExtWorkspace: Output %d (%s) name received", outputID, ev.Name)
				})
			}
			return
		}

		if e.Interface == ext_workspace.ExtWorkspaceManagerV1InterfaceName {
			log.Infof("ExtWorkspace: found %s", ext_workspace.ExtWorkspaceManagerV1InterfaceName)
			manager := ext_workspace.NewExtWorkspaceManagerV1(ctx)
			version := e.Version
			if version > 1 {
				version = 1
			}

			manager.SetWorkspaceGroupHandler(func(e ext_workspace.ExtWorkspaceManagerV1WorkspaceGroupEvent) {
				m.handleWorkspaceGroup(e)
			})

			manager.SetWorkspaceHandler(func(e ext_workspace.ExtWorkspaceManagerV1WorkspaceEvent) {
				m.handleWorkspace(e)
			})

			manager.SetDoneHandler(func(e ext_workspace.ExtWorkspaceManagerV1DoneEvent) {
				log.Debug("ExtWorkspace: done event received")
				m.post(func() {
					m.updateState()
				})
			})

			manager.SetFinishedHandler(func(e ext_workspace.ExtWorkspaceManagerV1FinishedEvent) {
				log.Info("ExtWorkspace: finished event received")
			})

			if err := registry.Bind(e.Name, e.Interface, version, manager); err == nil {
				m.manager = manager
				log.Info("ExtWorkspace: manager bound successfully")
			} else {
				log.Errorf("ExtWorkspace: failed to bind manager: %v", err)
			}
		}
	})

	log.Info("ExtWorkspace: registry setup complete (events will be processed async)")
	return nil
}

func (m *Manager) handleWorkspaceGroup(e ext_workspace.ExtWorkspaceManagerV1WorkspaceGroupEvent) {
	handle := e.WorkspaceGroup
	groupID := handle.ID()

	log.Debugf("ExtWorkspace: New workspace group (id=%d)", groupID)

	group := &workspaceGroupState{
		id:           groupID,
		handle:       handle,
		outputIDs:    make(map[uint32]bool),
		workspaceIDs: make([]uint32, 0),
	}

	m.groupsMutex.Lock()
	m.groups[groupID] = group
	m.groupsMutex.Unlock()

	handle.SetCapabilitiesHandler(func(e ext_workspace.ExtWorkspaceGroupHandleV1CapabilitiesEvent) {
		log.Debugf("ExtWorkspace: Group %d capabilities: %d", groupID, e.Capabilities)
	})

	handle.SetOutputEnterHandler(func(e ext_workspace.ExtWorkspaceGroupHandleV1OutputEnterEvent) {
		outputID := e.Output.ID()
		log.Debugf("ExtWorkspace: Group %d output enter (output=%d)", groupID, outputID)

		m.post(func() {
			group.outputIDs[outputID] = true
			m.updateState()
		})
	})

	handle.SetOutputLeaveHandler(func(e ext_workspace.ExtWorkspaceGroupHandleV1OutputLeaveEvent) {
		outputID := e.Output.ID()
		log.Debugf("ExtWorkspace: Group %d output leave (output=%d)", groupID, outputID)
		m.post(func() {
			delete(group.outputIDs, outputID)
			m.updateState()
		})
	})

	handle.SetWorkspaceEnterHandler(func(e ext_workspace.ExtWorkspaceGroupHandleV1WorkspaceEnterEvent) {
		workspaceID := e.Workspace.ID()
		log.Debugf("ExtWorkspace: Group %d workspace enter (workspace=%d)", groupID, workspaceID)

		m.post(func() {
			m.workspacesMutex.Lock()
			if ws, exists := m.workspaces[workspaceID]; exists {
				ws.groupID = groupID
			}
			m.workspacesMutex.Unlock()

			group.workspaceIDs = append(group.workspaceIDs, workspaceID)
			m.updateState()
		})
	})

	handle.SetWorkspaceLeaveHandler(func(e ext_workspace.ExtWorkspaceGroupHandleV1WorkspaceLeaveEvent) {
		workspaceID := e.Workspace.ID()
		log.Debugf("ExtWorkspace: Group %d workspace leave (workspace=%d)", groupID, workspaceID)

		m.post(func() {
			m.workspacesMutex.Lock()
			if ws, exists := m.workspaces[workspaceID]; exists {
				ws.groupID = 0
			}
			m.workspacesMutex.Unlock()

			for i, id := range group.workspaceIDs {
				if id == workspaceID {
					group.workspaceIDs = append(group.workspaceIDs[:i], group.workspaceIDs[i+1:]...)
					break
				}
			}
			m.updateState()
		})
	})

	handle.SetRemovedHandler(func(e ext_workspace.ExtWorkspaceGroupHandleV1RemovedEvent) {
		log.Debugf("ExtWorkspace: Group %d removed", groupID)

		m.post(func() {
			group.removed = true

			m.groupsMutex.Lock()
			delete(m.groups, groupID)
			m.groupsMutex.Unlock()

			m.wlMutex.Lock()
			handle.Destroy()
			m.wlMutex.Unlock()

			m.updateState()
		})
	})
}

func (m *Manager) handleWorkspace(e ext_workspace.ExtWorkspaceManagerV1WorkspaceEvent) {
	handle := e.Workspace
	workspaceID := handle.ID()

	log.Debugf("ExtWorkspace: New workspace (proxy_id=%d)", workspaceID)

	ws := &workspaceState{
		id:          workspaceID,
		handle:      handle,
		coordinates: make([]uint32, 0),
	}

	m.workspacesMutex.Lock()
	m.workspaces[workspaceID] = ws
	m.workspacesMutex.Unlock()

	handle.SetIdHandler(func(e ext_workspace.ExtWorkspaceHandleV1IdEvent) {
		log.Debugf("ExtWorkspace: Workspace %d id: %s", workspaceID, e.Id)
		m.post(func() {
			ws.workspaceID = e.Id
			m.updateState()
		})
	})

	handle.SetNameHandler(func(e ext_workspace.ExtWorkspaceHandleV1NameEvent) {
		log.Debugf("ExtWorkspace: Workspace %d name: %s", workspaceID, e.Name)
		m.post(func() {
			ws.name = e.Name
			m.updateState()
		})
	})

	handle.SetCoordinatesHandler(func(e ext_workspace.ExtWorkspaceHandleV1CoordinatesEvent) {
		coords := make([]uint32, 0)
		for i := 0; i < len(e.Coordinates); i += 4 {
			if i+4 <= len(e.Coordinates) {
				val := uint32(e.Coordinates[i]) |
					uint32(e.Coordinates[i+1])<<8 |
					uint32(e.Coordinates[i+2])<<16 |
					uint32(e.Coordinates[i+3])<<24
				coords = append(coords, val)
			}
		}
		log.Debugf("ExtWorkspace: Workspace %d coordinates: %v", workspaceID, coords)
		m.post(func() {
			ws.coordinates = coords
			m.updateState()
		})
	})

	handle.SetStateHandler(func(e ext_workspace.ExtWorkspaceHandleV1StateEvent) {
		log.Debugf("ExtWorkspace: Workspace %d state: %d", workspaceID, e.State)
		m.post(func() {
			ws.state = e.State
			m.updateState()
		})
	})

	handle.SetCapabilitiesHandler(func(e ext_workspace.ExtWorkspaceHandleV1CapabilitiesEvent) {
		log.Debugf("ExtWorkspace: Workspace %d capabilities: %d", workspaceID, e.Capabilities)
	})

	handle.SetRemovedHandler(func(e ext_workspace.ExtWorkspaceHandleV1RemovedEvent) {
		log.Debugf("ExtWorkspace: Workspace %d removed", workspaceID)

		m.post(func() {
			ws.removed = true

			m.workspacesMutex.Lock()
			delete(m.workspaces, workspaceID)
			m.workspacesMutex.Unlock()

			m.wlMutex.Lock()
			handle.Destroy()
			m.wlMutex.Unlock()

			m.updateState()
		})
	})
}

func (m *Manager) updateState() {
	m.groupsMutex.RLock()
	m.workspacesMutex.RLock()

	groups := make([]*WorkspaceGroup, 0)

	for _, group := range m.groups {
		if group.removed {
			continue
		}

		outputs := make([]string, 0)
		for outputID := range group.outputIDs {
			m.outputsMutex.RLock()
			name := m.outputNames[outputID]
			m.outputsMutex.RUnlock()
			if name != "" {
				outputs = append(outputs, name)
			} else {
				outputs = append(outputs, fmt.Sprintf("output-%d", outputID))
			}
		}

		workspaces := make([]*Workspace, 0)
		for _, wsID := range group.workspaceIDs {
			ws, exists := m.workspaces[wsID]
			if !exists || ws.removed {
				continue
			}

			workspace := &Workspace{
				ID:          ws.workspaceID,
				Name:        ws.name,
				Coordinates: ws.coordinates,
				State:       ws.state,
				Active:      ws.state&uint32(ext_workspace.ExtWorkspaceHandleV1StateActive) != 0,
				Urgent:      ws.state&uint32(ext_workspace.ExtWorkspaceHandleV1StateUrgent) != 0,
				Hidden:      ws.state&uint32(ext_workspace.ExtWorkspaceHandleV1StateHidden) != 0,
			}
			workspaces = append(workspaces, workspace)
		}

		groupState := &WorkspaceGroup{
			ID:         fmt.Sprintf("group-%d", group.id),
			Outputs:    outputs,
			Workspaces: workspaces,
		}
		groups = append(groups, groupState)
	}

	m.workspacesMutex.RUnlock()
	m.groupsMutex.RUnlock()

	newState := State{
		Groups: groups,
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
			m.subMutex.RLock()
			subCount := len(m.subscribers)
			m.subMutex.RUnlock()

			if subCount == 0 {
				pending = false
				continue
			}

			currentState := m.GetState()

			if m.lastNotified != nil && !stateChanged(m.lastNotified, &currentState) {
				pending = false
				continue
			}

			m.subMutex.RLock()
			for _, ch := range m.subscribers {
				select {
				case ch <- currentState:
				default:
					log.Warn("ExtWorkspace: subscriber channel full, dropping update")
				}
			}
			m.subMutex.RUnlock()

			stateCopy := currentState
			m.lastNotified = &stateCopy
			pending = false
		}
	}
}

func (m *Manager) ActivateWorkspace(groupID, workspaceID string) error {
	errChan := make(chan error, 1)

	m.post(func() {
		m.workspacesMutex.RLock()
		defer m.workspacesMutex.RUnlock()

		var targetGroupID uint32
		if groupID != "" {
			var parsedID uint32
			if _, err := fmt.Sscanf(groupID, "group-%d", &parsedID); err == nil {
				targetGroupID = parsedID
			}
		}

		for _, ws := range m.workspaces {
			if targetGroupID != 0 && ws.groupID != targetGroupID {
				continue
			}
			if ws.workspaceID == workspaceID || ws.name == workspaceID {
				m.wlMutex.Lock()
				err := ws.handle.Activate()
				if err == nil {
					err = m.manager.Commit()
				}
				m.wlMutex.Unlock()
				errChan <- err
				return
			}
		}

		errChan <- fmt.Errorf("workspace not found: %s in group %s", workspaceID, groupID)
	})

	return <-errChan
}

func (m *Manager) DeactivateWorkspace(groupID, workspaceID string) error {
	errChan := make(chan error, 1)

	m.post(func() {
		m.workspacesMutex.RLock()
		defer m.workspacesMutex.RUnlock()

		var targetGroupID uint32
		if groupID != "" {
			var parsedID uint32
			if _, err := fmt.Sscanf(groupID, "group-%d", &parsedID); err == nil {
				targetGroupID = parsedID
			}
		}

		for _, ws := range m.workspaces {
			if targetGroupID != 0 && ws.groupID != targetGroupID {
				continue
			}
			if ws.workspaceID == workspaceID || ws.name == workspaceID {
				m.wlMutex.Lock()
				err := ws.handle.Deactivate()
				if err == nil {
					err = m.manager.Commit()
				}
				m.wlMutex.Unlock()
				errChan <- err
				return
			}
		}

		errChan <- fmt.Errorf("workspace not found: %s in group %s", workspaceID, groupID)
	})

	return <-errChan
}

func (m *Manager) RemoveWorkspace(groupID, workspaceID string) error {
	errChan := make(chan error, 1)

	m.post(func() {
		m.workspacesMutex.RLock()
		defer m.workspacesMutex.RUnlock()

		var targetGroupID uint32
		if groupID != "" {
			var parsedID uint32
			if _, err := fmt.Sscanf(groupID, "group-%d", &parsedID); err == nil {
				targetGroupID = parsedID
			}
		}

		for _, ws := range m.workspaces {
			if targetGroupID != 0 && ws.groupID != targetGroupID {
				continue
			}
			if ws.workspaceID == workspaceID || ws.name == workspaceID {
				m.wlMutex.Lock()
				err := ws.handle.Remove()
				if err == nil {
					err = m.manager.Commit()
				}
				m.wlMutex.Unlock()
				errChan <- err
				return
			}
		}

		errChan <- fmt.Errorf("workspace not found: %s in group %s", workspaceID, groupID)
	})

	return <-errChan
}

func (m *Manager) CreateWorkspace(groupID, workspaceName string) error {
	errChan := make(chan error, 1)

	m.post(func() {
		m.groupsMutex.RLock()
		defer m.groupsMutex.RUnlock()

		for _, group := range m.groups {
			if fmt.Sprintf("group-%d", group.id) == groupID {
				m.wlMutex.Lock()
				err := group.handle.CreateWorkspace(workspaceName)
				if err == nil {
					err = m.manager.Commit()
				}
				m.wlMutex.Unlock()
				errChan <- err
				return
			}
		}

		errChan <- fmt.Errorf("workspace group not found: %s", groupID)
	})

	return <-errChan
}

func (m *Manager) Close() {
	close(m.stopChan)
	m.wg.Wait()
	m.notifierWg.Wait()

	m.subMutex.Lock()
	for _, ch := range m.subscribers {
		close(ch)
	}
	m.subscribers = make(map[string]chan State)
	m.subMutex.Unlock()

	m.workspacesMutex.Lock()
	for _, ws := range m.workspaces {
		if ws.handle != nil {
			ws.handle.Destroy()
		}
	}
	m.workspaces = make(map[uint32]*workspaceState)
	m.workspacesMutex.Unlock()

	m.groupsMutex.Lock()
	for _, group := range m.groups {
		if group.handle != nil {
			group.handle.Destroy()
		}
	}
	m.groups = make(map[uint32]*workspaceGroupState)
	m.groupsMutex.Unlock()

	if m.manager != nil {
		m.manager.Stop()
	}
}
