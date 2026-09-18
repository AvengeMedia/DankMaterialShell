package thememode

import (
	"fmt"

	"github.com/AvengeMedia/DankMaterialShell/core/internal/server/models"
	"github.com/AvengeMedia/dankgo/ipc"
	"github.com/AvengeMedia/dankgo/ipc/params"
)

func HandleRequest(conn *ipc.ConnWriter, req ipc.Request, manager *Manager) {
	if manager == nil {
		models.RespondError(conn, req.ID, "theme mode manager not initialized")
		return
	}

	switch req.Method {
	case "theme.auto.getState":
		handleGetState(conn, req, manager)
	case "theme.auto.setEnabled":
		handleSetEnabled(conn, req, manager)
	case "theme.auto.setMode":
		handleSetMode(conn, req, manager)
	case "theme.auto.setSchedule":
		handleSetSchedule(conn, req, manager)
	case "theme.auto.setLocation":
		handleSetLocation(conn, req, manager)
	case "theme.auto.setUseIPLocation":
		handleSetUseIPLocation(conn, req, manager)
	case "theme.auto.trigger":
		handleTrigger(conn, req, manager)
	case "theme.auto.subscribe":
		handleSubscribe(conn, req, manager)
	default:
		models.RespondError(conn, req.ID, fmt.Sprintf("unknown method: %s", req.Method))
	}
}

func handleGetState(conn *ipc.ConnWriter, req ipc.Request, manager *Manager) {
	models.Respond(conn, req.ID, manager.GetState())
}

func handleSetEnabled(conn *ipc.ConnWriter, req ipc.Request, manager *Manager) {
	enabled, err := params.Bool(req.Params, "enabled")
	if err != nil {
		models.RespondError(conn, req.ID, err.Error())
		return
	}

	manager.SetEnabled(enabled)
	models.Respond(conn, req.ID, models.SuccessResult{Success: true, Message: "theme auto enabled set"})
}

func handleSetMode(conn *ipc.ConnWriter, req ipc.Request, manager *Manager) {
	mode, err := params.String(req.Params, "mode")
	if err != nil {
		models.RespondError(conn, req.ID, err.Error())
		return
	}

	if mode != "time" && mode != "location" {
		models.RespondError(conn, req.ID, "invalid mode")
		return
	}

	manager.SetMode(mode)
	models.Respond(conn, req.ID, models.SuccessResult{Success: true, Message: "theme auto mode set"})
}

func handleSetSchedule(conn *ipc.ConnWriter, req ipc.Request, manager *Manager) {
	startHour, err := params.Int(req.Params, "startHour")
	if err != nil {
		models.RespondError(conn, req.ID, err.Error())
		return
	}
	startMinute, err := params.Int(req.Params, "startMinute")
	if err != nil {
		models.RespondError(conn, req.ID, err.Error())
		return
	}
	endHour, err := params.Int(req.Params, "endHour")
	if err != nil {
		models.RespondError(conn, req.ID, err.Error())
		return
	}
	endMinute, err := params.Int(req.Params, "endMinute")
	if err != nil {
		models.RespondError(conn, req.ID, err.Error())
		return
	}

	if err := manager.ValidateSchedule(startHour, startMinute, endHour, endMinute); err != nil {
		models.RespondError(conn, req.ID, err.Error())
		return
	}

	manager.SetSchedule(startHour, startMinute, endHour, endMinute)
	models.Respond(conn, req.ID, manager.GetState())
}

func handleSetLocation(conn *ipc.ConnWriter, req ipc.Request, manager *Manager) {
	lat, err := params.Float(req.Params, "latitude")
	if err != nil {
		models.RespondError(conn, req.ID, err.Error())
		return
	}
	lon, err := params.Float(req.Params, "longitude")
	if err != nil {
		models.RespondError(conn, req.ID, err.Error())
		return
	}

	manager.SetLocation(lat, lon)
	models.Respond(conn, req.ID, models.SuccessResult{Success: true, Message: "theme auto location set"})
}

func handleSetUseIPLocation(conn *ipc.ConnWriter, req ipc.Request, manager *Manager) {
	use, err := params.Bool(req.Params, "use")
	if err != nil {
		models.RespondError(conn, req.ID, err.Error())
		return
	}

	manager.SetUseIPLocation(use)
	models.Respond(conn, req.ID, models.SuccessResult{Success: true, Message: "theme auto IP location set"})
}

func handleTrigger(conn *ipc.ConnWriter, req ipc.Request, manager *Manager) {
	manager.TriggerUpdate()
	models.Respond(conn, req.ID, models.SuccessResult{Success: true, Message: "theme auto update triggered"})
}

func handleSubscribe(conn *ipc.ConnWriter, req ipc.Request, manager *Manager) {
	clientID := fmt.Sprintf("client-%p", conn)
	stateChan := manager.Subscribe(clientID)
	defer manager.Unsubscribe(clientID)

	initialState := manager.GetState()
	if err := conn.WriteResponse(ipc.Response[State]{
		ID:     req.ID,
		Result: &initialState,
	}); err != nil {
		return
	}

	for state := range stateChan {
		if err := conn.WriteResponse(ipc.Response[State]{
			Result: &state,
		}); err != nil {
			return
		}
	}
}
