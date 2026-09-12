package wayland

import (
	"fmt"
	"time"

	"github.com/AvengeMedia/DankMaterialShell/core/internal/server/models"
	"github.com/AvengeMedia/dankgo/ipc/params"
)

func HandleRequest(conn *models.Conn, req models.Request, manager *Manager) {
	if manager == nil {
		models.RespondError(conn, req.ID, "wayland manager not initialized")
		return
	}

	switch req.Method {
	case "wayland.gamma.getState":
		handleGetState(conn, req, manager)
	case "wayland.gamma.setTemperature":
		handleSetTemperature(conn, req, manager)
	case "wayland.gamma.setLocation":
		handleSetLocation(conn, req, manager)
	case "wayland.gamma.setManualTimes":
		handleSetManualTimes(conn, req, manager)
	case "wayland.gamma.setUseIPLocation":
		handleSetUseIPLocation(conn, req, manager)
	case "wayland.gamma.setGamma":
		handleSetGamma(conn, req, manager)
	case "wayland.gamma.setEnabled":
		handleSetEnabled(conn, req, manager)
	case "wayland.gamma.subscribe":
		handleSubscribe(conn, req, manager)
	case "wayland.icc.getStatus":
		handleICCGetStatus(conn, req, manager)
	case "wayland.icc.apply":
		handleICCApply(conn, req, manager)
	case "wayland.icc.remove":
		handleICCRemove(conn, req, manager)
	case "wayland.icc.listOutputs":
		handleICCListOutputs(conn, req, manager)
	case "wayland.icc.setTemp":
		handleICCSetTemp(conn, req, manager)
	case "wayland.icc.getTemps":
		handleICCGetTemps(conn, req, manager)
	default:
		models.RespondError(conn, req.ID, fmt.Sprintf("unknown method: %s", req.Method))
	}
}

func handleGetState(conn *models.Conn, req models.Request, manager *Manager) {
	models.Respond(conn, req.ID, manager.GetState())
}

func handleSetTemperature(conn *models.Conn, req models.Request, manager *Manager) {
	var lowTemp, highTemp int

	if temp, ok := models.Get[float64](req, "temp"); ok {
		lowTemp = int(temp)
		highTemp = int(temp)
	} else {
		low, err := params.Float(req.Params, "low")
		if err != nil {
			models.RespondError(conn, req.ID, "missing temperature parameters (provide 'temp' or both 'low' and 'high')")
			return
		}
		high, err := params.Float(req.Params, "high")
		if err != nil {
			models.RespondError(conn, req.ID, "missing temperature parameters (provide 'temp' or both 'low' and 'high')")
			return
		}
		lowTemp = int(low)
		highTemp = int(high)
	}

	if err := manager.SetTemperature(lowTemp, highTemp); err != nil {
		models.RespondError(conn, req.ID, err.Error())
		return
	}

	models.Respond(conn, req.ID, models.SuccessResult{Success: true, Message: "temperature set"})
}

func handleSetLocation(conn *models.Conn, req models.Request, manager *Manager) {
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

	if err := manager.SetLocation(lat, lon); err != nil {
		models.RespondError(conn, req.ID, err.Error())
		return
	}

	models.Respond(conn, req.ID, models.SuccessResult{Success: true, Message: "location set"})
}

func handleSetManualTimes(conn *models.Conn, req models.Request, manager *Manager) {
	sunriseStr, sunriseOK := models.Get[string](req, "sunrise")
	sunsetStr, sunsetOK := models.Get[string](req, "sunset")

	if !sunriseOK || !sunsetOK || sunriseStr == "" || sunsetStr == "" {
		manager.ClearManualTimes()
		models.Respond(conn, req.ID, models.SuccessResult{Success: true, Message: "manual times cleared"})
		return
	}

	sunrise, err := time.Parse("15:04", sunriseStr)
	if err != nil {
		models.RespondError(conn, req.ID, "invalid sunrise format (use HH:MM)")
		return
	}

	sunset, err := time.Parse("15:04", sunsetStr)
	if err != nil {
		models.RespondError(conn, req.ID, "invalid sunset format (use HH:MM)")
		return
	}

	var duration *time.Duration
	if minutes, ok := models.Get[float64](req, "durationMinutes"); ok {
		d := time.Duration(minutes) * time.Minute
		duration = &d
	}

	if err := manager.SetManualTimes(sunrise, sunset, duration); err != nil {
		models.RespondError(conn, req.ID, err.Error())
		return
	}

	models.Respond(conn, req.ID, models.SuccessResult{Success: true, Message: "manual times set"})
}

func handleSetUseIPLocation(conn *models.Conn, req models.Request, manager *Manager) {
	use, err := params.Bool(req.Params, "use")
	if err != nil {
		models.RespondError(conn, req.ID, err.Error())
		return
	}

	manager.SetUseIPLocation(use)
	models.Respond(conn, req.ID, models.SuccessResult{Success: true, Message: "IP location preference set"})
}

func handleSetGamma(conn *models.Conn, req models.Request, manager *Manager) {
	gamma, err := params.Float(req.Params, "gamma")
	if err != nil {
		models.RespondError(conn, req.ID, err.Error())
		return
	}

	_, contrast := manager.Adjustments()
	if v, ok := models.Get[float64](req, "contrast"); ok {
		contrast = v
	}

	if err := manager.SetAdjustments(gamma, contrast); err != nil {
		models.RespondError(conn, req.ID, err.Error())
		return
	}

	models.Respond(conn, req.ID, models.SuccessResult{Success: true, Message: "gamma set"})
}

func handleSetEnabled(conn *models.Conn, req models.Request, manager *Manager) {
	enabled, err := params.Bool(req.Params, "enabled")
	if err != nil {
		models.RespondError(conn, req.ID, err.Error())
		return
	}

	manager.SetEnabled(enabled)
	models.Respond(conn, req.ID, models.SuccessResult{Success: true, Message: "enabled state set"})
}

func handleSubscribe(conn *models.Conn, req models.Request, manager *Manager) {
	clientID := fmt.Sprintf("client-%p", conn)
	stateChan := manager.Subscribe(clientID)
	defer manager.Unsubscribe(clientID)

	initialState := manager.GetState()
	if err := conn.WriteResponse(models.Response[State]{
		ID:     req.ID,
		Result: &initialState,
	}); err != nil {
		return
	}

	for state := range stateChan {
		if err := conn.WriteResponse(models.Response[State]{
			Result: &state,
		}); err != nil {
			return
		}
	}
}

func handleICCGetStatus(conn *models.Conn, req models.Request, manager *Manager) {
	status := manager.GetICCStatus()
	outputs := manager.ListOutputs()
	result := map[string]any{
		"outputs":  outputs,
		"profiles": status,
	}
	models.Respond(conn, req.ID, result)
}

func handleICCApply(conn *models.Conn, req models.Request, manager *Manager) {
	output, err := params.String(req.Params, "output")
	if err != nil {
		models.RespondError(conn, req.ID, err.Error())
		return
	}

	path, err := params.String(req.Params, "path")
	if err != nil {
		models.RespondError(conn, req.ID, err.Error())
		return
	}

	if err := manager.ApplyICC(output, path); err != nil {
		models.RespondError(conn, req.ID, err.Error())
		return
	}

	models.Respond(conn, req.ID, models.SuccessResult{Success: true, Message: "ICC profile applied"})
}

func handleICCRemove(conn *models.Conn, req models.Request, manager *Manager) {
	output, err := params.String(req.Params, "output")
	if err != nil {
		models.RespondError(conn, req.ID, err.Error())
		return
	}

	if err := manager.RemoveICC(output); err != nil {
		models.RespondError(conn, req.ID, err.Error())
		return
	}

	models.Respond(conn, req.ID, models.SuccessResult{Success: true, Message: "ICC profile removed"})
}

func handleICCListOutputs(conn *models.Conn, req models.Request, manager *Manager) {
	outputs := manager.ListOutputs()
	models.Respond(conn, req.ID, outputs)
}

func handleICCSetTemp(conn *models.Conn, req models.Request, manager *Manager) {
	output, err := params.String(req.Params, "output")
	if err != nil {
		models.RespondError(conn, req.ID, err.Error())
		return
	}

	temp, err := params.Int(req.Params, "temp")
	if err != nil {
		models.RespondError(conn, req.ID, err.Error())
		return
	}

	if err := manager.SetOutputTemp(output, temp); err != nil {
		models.RespondError(conn, req.ID, err.Error())
		return
	}

	models.Respond(conn, req.ID, models.SuccessResult{Success: true, Message: "Output temperature set"})
}

func handleICCGetTemps(conn *models.Conn, req models.Request, manager *Manager) {
	temps := manager.GetOutputTemps()
	models.Respond(conn, req.ID, temps)
}
