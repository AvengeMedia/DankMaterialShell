package loginctl

import (
	"encoding/json"
	"fmt"
	"net"

	"github.com/AvengeMedia/DankMaterialShell/core/internal/server/models"
)

type Request struct {
	ID     int            `json:"id,omitempty"`
	Method string         `json:"method"`
	Params map[string]any `json:"params,omitempty"`
}

type SuccessResult struct {
	Success bool   `json:"success"`
	Message string `json:"message"`
}

func HandleRequest(conn net.Conn, req Request, manager *Manager) {
	switch req.Method {
	case "loginctl.getState":
		handleGetState(conn, req, manager)
	case "loginctl.lock":
		handleLock(conn, req, manager)
	case "loginctl.unlock":
		handleUnlock(conn, req, manager)
	case "loginctl.activate":
		handleActivate(conn, req, manager)
	case "loginctl.setIdleHint":
		handleSetIdleHint(conn, req, manager)
	case "loginctl.setLockBeforeSuspend":
		handleSetLockBeforeSuspend(conn, req, manager)
	case "loginctl.setSleepInhibitorEnabled":
		handleSetSleepInhibitorEnabled(conn, req, manager)
	case "loginctl.lockerReady":
		handleLockerReady(conn, req, manager)
	case "loginctl.terminate":
		handleTerminate(conn, req, manager)
	case "loginctl.subscribe":
		handleSubscribe(conn, req, manager)
	default:
		models.RespondError(conn, req.ID, fmt.Sprintf("unknown method: %s", req.Method))
	}
}

func handleGetState(conn net.Conn, req Request, manager *Manager) {
	state := manager.GetState()
	models.Respond(conn, req.ID, state)
}

func handleLock(conn net.Conn, req Request, manager *Manager) {
	if err := manager.Lock(); err != nil {
		models.RespondError(conn, req.ID, err.Error())
		return
	}
	models.Respond(conn, req.ID, SuccessResult{Success: true, Message: "locked"})
}

func handleUnlock(conn net.Conn, req Request, manager *Manager) {
	if err := manager.Unlock(); err != nil {
		models.RespondError(conn, req.ID, err.Error())
		return
	}
	models.Respond(conn, req.ID, SuccessResult{Success: true, Message: "unlocked"})
}

func handleActivate(conn net.Conn, req Request, manager *Manager) {
	if err := manager.Activate(); err != nil {
		models.RespondError(conn, req.ID, err.Error())
		return
	}
	models.Respond(conn, req.ID, SuccessResult{Success: true, Message: "activated"})
}

func handleSetIdleHint(conn net.Conn, req Request, manager *Manager) {
	idle, ok := req.Params["idle"].(bool)
	if !ok {
		models.RespondError(conn, req.ID, "missing or invalid 'idle' parameter")
		return
	}

	if err := manager.SetIdleHint(idle); err != nil {
		models.RespondError(conn, req.ID, err.Error())
		return
	}
	models.Respond(conn, req.ID, SuccessResult{Success: true, Message: "idle hint set"})
}

func handleSetLockBeforeSuspend(conn net.Conn, req Request, manager *Manager) {
	enabled, ok := req.Params["enabled"].(bool)
	if !ok {
		models.RespondError(conn, req.ID, "missing or invalid 'enabled' parameter")
		return
	}

	manager.SetLockBeforeSuspend(enabled)
	models.Respond(conn, req.ID, SuccessResult{Success: true, Message: "lock before suspend set"})
}

func handleSetSleepInhibitorEnabled(conn net.Conn, req Request, manager *Manager) {
	enabled, ok := req.Params["enabled"].(bool)
	if !ok {
		models.RespondError(conn, req.ID, "missing or invalid 'enabled' parameter")
		return
	}

	manager.SetSleepInhibitorEnabled(enabled)
	models.Respond(conn, req.ID, SuccessResult{Success: true, Message: "sleep inhibitor setting updated"})
}

func handleLockerReady(conn net.Conn, req Request, manager *Manager) {
	manager.lockTimerMu.Lock()
	if manager.lockTimer != nil {
		manager.lockTimer.Stop()
		manager.lockTimer = nil
	}
	manager.lockTimerMu.Unlock()

	id := manager.sleepCycleID.Load()
	manager.releaseForCycle(id)

	if manager.inSleepCycle.Load() {
		manager.signalLockerReady()
	}
	models.Respond(conn, req.ID, SuccessResult{Success: true, Message: "ok"})
}

func handleTerminate(conn net.Conn, req Request, manager *Manager) {
	if err := manager.Terminate(); err != nil {
		models.RespondError(conn, req.ID, err.Error())
		return
	}
	models.Respond(conn, req.ID, SuccessResult{Success: true, Message: "terminated"})
}

func handleSubscribe(conn net.Conn, req Request, manager *Manager) {
	clientID := fmt.Sprintf("client-%p", conn)
	stateChan := manager.Subscribe(clientID)
	defer manager.Unsubscribe(clientID)

	initialState := manager.GetState()
	event := SessionEvent{
		Type: EventStateChanged,
		Data: initialState,
	}
	if err := json.NewEncoder(conn).Encode(models.Response[SessionEvent]{
		ID:     req.ID,
		Result: &event,
	}); err != nil {
		return
	}

	for state := range stateChan {
		event := SessionEvent{
			Type: EventStateChanged,
			Data: state,
		}
		if err := json.NewEncoder(conn).Encode(models.Response[SessionEvent]{
			Result: &event,
		}); err != nil {
			return
		}
	}
}
