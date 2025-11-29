package wayland

import (
	"encoding/json"
	"fmt"
	"net"
	"time"

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
	default:
		models.RespondError(conn, req.ID, fmt.Sprintf("unknown method: %s", req.Method))
	}
}

func handleGetState(conn net.Conn, req Request, manager *Manager) {
	state := manager.GetState()
	models.Respond(conn, req.ID, state)
}

func handleSetTemperature(conn net.Conn, req Request, manager *Manager) {
	var lowTemp, highTemp int

	if temp, ok := req.Params["temp"].(float64); ok {
		lowTemp = int(temp)
		highTemp = int(temp)
	} else {
		low, okLow := req.Params["low"].(float64)
		high, okHigh := req.Params["high"].(float64)

		if !okLow || !okHigh {
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

	models.Respond(conn, req.ID, SuccessResult{Success: true, Message: "temperature set"})
}

func handleSetLocation(conn net.Conn, req Request, manager *Manager) {
	lat, ok := req.Params["latitude"].(float64)
	if !ok {
		models.RespondError(conn, req.ID, "missing or invalid 'latitude' parameter")
		return
	}

	lon, ok := req.Params["longitude"].(float64)
	if !ok {
		models.RespondError(conn, req.ID, "missing or invalid 'longitude' parameter")
		return
	}

	if err := manager.SetLocation(lat, lon); err != nil {
		models.RespondError(conn, req.ID, err.Error())
		return
	}

	models.Respond(conn, req.ID, SuccessResult{Success: true, Message: "location set"})
}

func handleSetManualTimes(conn net.Conn, req Request, manager *Manager) {
	sunriseParam := req.Params["sunrise"]
	sunsetParam := req.Params["sunset"]

	if sunriseParam == nil || sunsetParam == nil {
		manager.ClearManualTimes()
		models.Respond(conn, req.ID, SuccessResult{Success: true, Message: "manual times cleared"})
		return
	}

	sunriseStr, ok := sunriseParam.(string)
	if !ok || sunriseStr == "" {
		manager.ClearManualTimes()
		models.Respond(conn, req.ID, SuccessResult{Success: true, Message: "manual times cleared"})
		return
	}

	sunsetStr, ok := sunsetParam.(string)
	if !ok || sunsetStr == "" {
		manager.ClearManualTimes()
		models.Respond(conn, req.ID, SuccessResult{Success: true, Message: "manual times cleared"})
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

	if err := manager.SetManualTimes(sunrise, sunset); err != nil {
		models.RespondError(conn, req.ID, err.Error())
		return
	}

	models.Respond(conn, req.ID, SuccessResult{Success: true, Message: "manual times set"})
}

func handleSetUseIPLocation(conn net.Conn, req Request, manager *Manager) {
	use, ok := req.Params["use"].(bool)
	if !ok {
		models.RespondError(conn, req.ID, "missing or invalid 'use' parameter")
		return
	}

	manager.SetUseIPLocation(use)
	models.Respond(conn, req.ID, SuccessResult{Success: true, Message: "IP location preference set"})
}

func handleSetGamma(conn net.Conn, req Request, manager *Manager) {
	gamma, ok := req.Params["gamma"].(float64)
	if !ok {
		models.RespondError(conn, req.ID, "missing or invalid 'gamma' parameter")
		return
	}

	if err := manager.SetGamma(gamma); err != nil {
		models.RespondError(conn, req.ID, err.Error())
		return
	}

	models.Respond(conn, req.ID, SuccessResult{Success: true, Message: "gamma set"})
}

func handleSetEnabled(conn net.Conn, req Request, manager *Manager) {
	enabled, ok := req.Params["enabled"].(bool)
	if !ok {
		models.RespondError(conn, req.ID, "missing or invalid 'enabled' parameter")
		return
	}

	manager.SetEnabled(enabled)
	models.Respond(conn, req.ID, SuccessResult{Success: true, Message: "enabled state set"})
}

func handleSubscribe(conn net.Conn, req Request, manager *Manager) {
	clientID := fmt.Sprintf("client-%p", conn)
	stateChan := manager.Subscribe(clientID)
	defer manager.Unsubscribe(clientID)

	initialState := manager.GetState()
	if err := json.NewEncoder(conn).Encode(models.Response[State]{
		ID:     req.ID,
		Result: &initialState,
	}); err != nil {
		return
	}

	for state := range stateChan {
		if err := json.NewEncoder(conn).Encode(models.Response[State]{
			Result: &state,
		}); err != nil {
			return
		}
	}
}
