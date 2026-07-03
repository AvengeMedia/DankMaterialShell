package loginctl

import (
	"encoding/json"
	"fmt"
	"net"

	"github.com/AvengeMedia/DankMaterialShell/core/internal/server/models"
	"github.com/AvengeMedia/DankMaterialShell/core/internal/server/params"
)

func HandleRequest(conn net.Conn, req models.Request, manager *Manager) {
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
	case "loginctl.setLockedHint":
		handleSetLockedHint(conn, req, manager)
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

func handleGetState(conn net.Conn, req models.Request, manager *Manager) {
	models.Respond(conn, req.ID, manager.GetState())
}

func handleLock(conn net.Conn, req models.Request, manager *Manager) {
	if err := manager.Lock(); err != nil {
		models.RespondError(conn, req.ID, err.Error())
		return
	}
	models.Respond(conn, req.ID, models.SuccessResult{Success: true, Message: "locked"})
}

func handleUnlock(conn net.Conn, req models.Request, manager *Manager) {
	if err := manager.Unlock(); err != nil {
		models.RespondError(conn, req.ID, err.Error())
		return
	}
	models.Respond(conn, req.ID, models.SuccessResult{Success: true, Message: "unlocked"})
}

func handleActivate(conn net.Conn, req models.Request, manager *Manager) {
	if err := manager.Activate(); err != nil {
		models.RespondError(conn, req.ID, err.Error())
		return
	}
	models.Respond(conn, req.ID, models.SuccessResult{Success: true, Message: "activated"})
}

func handleSetIdleHint(conn net.Conn, req models.Request, manager *Manager) {
	idle, err := params.Bool(req.Params, "idle")
	if err != nil {
		models.RespondError(conn, req.ID, err.Error())
		return
	}

	if err := manager.SetIdleHint(idle); err != nil {
		models.RespondError(conn, req.ID, err.Error())
		return
	}
	models.Respond(conn, req.ID, models.SuccessResult{Success: true, Message: "idle hint set"})
}

func handleSetLockedHint(conn net.Conn, req models.Request, manager *Manager) {
	locked, err := params.Bool(req.Params, "locked")
	if err != nil {
		models.RespondError(conn, req.ID, err.Error())
		return
	}

	if err := manager.SetLockedHint(locked); err != nil {
		models.RespondError(conn, req.ID, err.Error())
		return
	}
	models.Respond(conn, req.ID, models.SuccessResult{Success: true, Message: "locked hint set"})
}

func handleSetLockBeforeSuspend(conn net.Conn, req models.Request, manager *Manager) {
	enabled, err := params.Bool(req.Params, "enabled")
	if err != nil {
		models.RespondError(conn, req.ID, err.Error())
		return
	}

	manager.SetLockBeforeSuspend(enabled)
	models.Respond(conn, req.ID, models.SuccessResult{Success: true, Message: "lock before suspend set"})
}

func handleSetSleepInhibitorEnabled(conn net.Conn, req models.Request, manager *Manager) {
	enabled, err := params.Bool(req.Params, "enabled")
	if err != nil {
		models.RespondError(conn, req.ID, err.Error())
		return
	}

	manager.SetSleepInhibitorEnabled(enabled)
	models.Respond(conn, req.ID, models.SuccessResult{Success: true, Message: "sleep inhibitor setting updated"})
}

func handleLockerReady(conn net.Conn, req models.Request, manager *Manager) {
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
	models.Respond(conn, req.ID, models.SuccessResult{Success: true, Message: "ok"})
}

func handleTerminate(conn net.Conn, req models.Request, manager *Manager) {
	if err := manager.Terminate(); err != nil {
		models.RespondError(conn, req.ID, err.Error())
		return
	}
	models.Respond(conn, req.ID, models.SuccessResult{Success: true, Message: "terminated"})
}

func handleSubscribe(conn net.Conn, req models.Request, manager *Manager) {
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
