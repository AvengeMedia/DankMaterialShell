package extworkspace

import (
	"fmt"
	"time"

	"github.com/AvengeMedia/DankMaterialShell/core/internal/log"
	"github.com/AvengeMedia/DankMaterialShell/core/internal/proto/ext_workspace"
	wlclient "github.com/AvengeMedia/DankMaterialShell/core/pkg/go-wayland/wayland/client"
)

func NewManager(display *wlclient.Display) (*Manager, error) {
	m := &Manager{
		display:  display,
		ctx:      display.Context(),
		cmdq:     make(chan cmd, 128),
		stopChan: make(chan struct{}),

		dirty: make(chan struct{}, 1),
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

	registry, err := m.display.GetRegistry()
	if err != nil {
		return fmt.Errorf("failed to get registry: %w", err)
	}
	m.registry = registry

	registry.SetGlobalHandler(func(e wlclient.RegistryGlobalEvent) {
		if e.Interface == "wl_output" {
			output := wlclient.NewOutput(m.ctx)
			if err := registry.Bind(e.Name, e.Interface, 4, output); err == nil {
				outputID := output.ID()

				output.SetNameHandler(func(ev wlclient.OutputNameEvent) {
					m.outputNames.Store(outputID, ev.Name)
					log.Debugf("ExtWorkspace: Output %d (%s) name received", outputID, ev.Name)
				})
			}
			return
		}

		if e.Interface == ext_workspace.ExtWorkspaceManagerV1InterfaceName {
			log.Infof("ExtWorkspace: found %s", ext_workspace.ExtWorkspaceManagerV1InterfaceName)
			manager := ext_workspace.NewExtWorkspaceManagerV1(m.ctx)
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

	m.groups.Store(groupID, group)

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
			if ws, ok := m.workspaces.Load(workspaceID); ok {
				ws.groupID = groupID
			}

			group.workspaceIDs = append(group.workspaceIDs, workspaceID)
			m.updateState()
		})
	})

	handle.SetWorkspaceLeaveHandler(func(e ext_workspace.ExtWorkspaceGroupHandleV1WorkspaceLeaveEvent) {
		workspaceID := e.Workspace.ID()
		log.Debugf("ExtWorkspace: Group %d workspace leave (workspace=%d)", groupID, workspaceID)

		m.post(func() {
			if ws, ok := m.workspaces.Load(workspaceID); ok {
				ws.groupID = 0
			}

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

			m.groups.Delete(groupID)

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

	m.workspaces.Store(workspaceID, ws)

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

			m.workspaces.Delete(workspaceID)

			m.wlMutex.Lock()
			handle.Destroy()
			m.wlMutex.Unlock()

			m.updateState()
		})
	})
}

func (m *Manager) updateState() {
	groups := make([]*WorkspaceGroup, 0)

	m.groups.Range(func(key uint32, group *workspaceGroupState) bool {
		if group.removed {
			return true
		}

		outputs := make([]string, 0)
		for outputID := range group.outputIDs {
			if name, ok := m.outputNames.Load(outputID); ok {
				if name != "" {
					outputs = append(outputs, name)
				} else {
					outputs = append(outputs, fmt.Sprintf("output-%d", outputID))
				}
			} else {
				outputs = append(outputs, fmt.Sprintf("output-%d", outputID))
			}
		}

		workspaces := make([]*Workspace, 0)
		for _, wsID := range group.workspaceIDs {
			ws, exists := m.workspaces.Load(wsID)
			if !exists {
				continue
			}
			if ws.removed {
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
		return true
	})

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

			currentState := m.GetState()

			if m.lastNotified != nil && !stateChanged(m.lastNotified, &currentState) {
				pending = false
				continue
			}

			m.subscribers.Range(func(key string, ch chan State) bool {
				select {
				case ch <- currentState:
				default:
					log.Warn("ExtWorkspace: subscriber channel full, dropping update")
				}
				return true
			})

			stateCopy := currentState
			m.lastNotified = &stateCopy
			pending = false
		}
	}
}

func (m *Manager) ActivateWorkspace(groupID, workspaceID string) error {
	errChan := make(chan error, 1)

	m.post(func() {
		var targetGroupID uint32
		if groupID != "" {
			var parsedID uint32
			if _, err := fmt.Sscanf(groupID, "group-%d", &parsedID); err == nil {
				targetGroupID = parsedID
			}
		}

		var found bool
		m.workspaces.Range(func(key uint32, ws *workspaceState) bool {
			if targetGroupID != 0 && ws.groupID != targetGroupID {
				return true
			}
			if ws.workspaceID == workspaceID || ws.name == workspaceID {
				m.wlMutex.Lock()
				err := ws.handle.Activate()
				if err == nil {
					err = m.manager.Commit()
				}
				m.wlMutex.Unlock()
				errChan <- err
				found = true
				return false
			}
			return true
		})

		if !found {
			errChan <- fmt.Errorf("workspace not found: %s in group %s", workspaceID, groupID)
		}
	})

	return <-errChan
}

func (m *Manager) DeactivateWorkspace(groupID, workspaceID string) error {
	errChan := make(chan error, 1)

	m.post(func() {
		var targetGroupID uint32
		if groupID != "" {
			var parsedID uint32
			if _, err := fmt.Sscanf(groupID, "group-%d", &parsedID); err == nil {
				targetGroupID = parsedID
			}
		}

		var found bool
		m.workspaces.Range(func(key uint32, ws *workspaceState) bool {
			if targetGroupID != 0 && ws.groupID != targetGroupID {
				return true
			}
			if ws.workspaceID == workspaceID || ws.name == workspaceID {
				m.wlMutex.Lock()
				err := ws.handle.Deactivate()
				if err == nil {
					err = m.manager.Commit()
				}
				m.wlMutex.Unlock()
				errChan <- err
				found = true
				return false
			}
			return true
		})

		if !found {
			errChan <- fmt.Errorf("workspace not found: %s in group %s", workspaceID, groupID)
		}
	})

	return <-errChan
}

func (m *Manager) RemoveWorkspace(groupID, workspaceID string) error {
	errChan := make(chan error, 1)

	m.post(func() {
		var targetGroupID uint32
		if groupID != "" {
			var parsedID uint32
			if _, err := fmt.Sscanf(groupID, "group-%d", &parsedID); err == nil {
				targetGroupID = parsedID
			}
		}

		var found bool
		m.workspaces.Range(func(key uint32, ws *workspaceState) bool {
			if targetGroupID != 0 && ws.groupID != targetGroupID {
				return true
			}
			if ws.workspaceID == workspaceID || ws.name == workspaceID {
				m.wlMutex.Lock()
				err := ws.handle.Remove()
				if err == nil {
					err = m.manager.Commit()
				}
				m.wlMutex.Unlock()
				errChan <- err
				found = true
				return false
			}
			return true
		})

		if !found {
			errChan <- fmt.Errorf("workspace not found: %s in group %s", workspaceID, groupID)
		}
	})

	return <-errChan
}

func (m *Manager) CreateWorkspace(groupID, workspaceName string) error {
	errChan := make(chan error, 1)

	m.post(func() {
		var found bool
		m.groups.Range(func(key uint32, group *workspaceGroupState) bool {
			if fmt.Sprintf("group-%d", group.id) == groupID {
				m.wlMutex.Lock()
				err := group.handle.CreateWorkspace(workspaceName)
				if err == nil {
					err = m.manager.Commit()
				}
				m.wlMutex.Unlock()
				errChan <- err
				found = true
				return false
			}
			return true
		})

		if !found {
			errChan <- fmt.Errorf("workspace group not found: %s", groupID)
		}
	})

	return <-errChan
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

	m.workspaces.Range(func(key uint32, ws *workspaceState) bool {
		if ws.handle != nil {
			ws.handle.Destroy()
		}
		m.workspaces.Delete(key)
		return true
	})

	m.groups.Range(func(key uint32, group *workspaceGroupState) bool {
		if group.handle != nil {
			group.handle.Destroy()
		}
		m.groups.Delete(key)
		return true
	})

	if m.manager != nil {
		m.manager.Stop()
	}
}
