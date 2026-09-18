package brightness

import (
	"fmt"

	"github.com/AvengeMedia/DankMaterialShell/core/internal/server/models"
	"github.com/AvengeMedia/dankgo/ipc"
	"github.com/AvengeMedia/dankgo/ipc/params"
)

func HandleRequest(conn *ipc.ConnWriter, req ipc.Request, m *Manager) {
	switch req.Method {
	case "brightness.getState":
		handleGetState(conn, req, m)
	case "brightness.setBrightness":
		handleSetBrightness(conn, req, m)
	case "brightness.increment":
		handleIncrement(conn, req, m)
	case "brightness.decrement":
		handleDecrement(conn, req, m)
	case "brightness.rescan":
		handleRescan(conn, req, m)
	case "brightness.subscribe":
		handleSubscribe(conn, req, m)
	default:
		models.RespondError(conn, req.ID, "unknown method: "+req.Method)
	}
}

func handleGetState(conn *ipc.ConnWriter, req ipc.Request, m *Manager) {
	models.Respond(conn, req.ID, m.GetState())
}

func handleSetBrightness(conn *ipc.ConnWriter, req ipc.Request, m *Manager) {
	device, err := params.String(req.Params, "device")
	if err != nil {
		models.RespondError(conn, req.ID, err.Error())
		return
	}

	percent, err := params.Int(req.Params, "percent")
	if err != nil {
		models.RespondError(conn, req.ID, err.Error())
		return
	}

	exponential := params.BoolOpt(req.Params, "exponential", false)
	exponent := params.FloatOpt(req.Params, "exponent", 1.2)

	if err := m.SetBrightnessWithExponent(device, percent, exponential, exponent); err != nil {
		models.RespondError(conn, req.ID, err.Error())
		return
	}

	models.Respond(conn, req.ID, m.GetState())
}

func handleIncrement(conn *ipc.ConnWriter, req ipc.Request, m *Manager) {
	device, err := params.String(req.Params, "device")
	if err != nil {
		models.RespondError(conn, req.ID, err.Error())
		return
	}

	step := params.IntOpt(req.Params, "step", 10)
	exponential := params.BoolOpt(req.Params, "exponential", false)
	exponent := params.FloatOpt(req.Params, "exponent", 1.2)

	if err := m.IncrementBrightnessWithExponent(device, step, exponential, exponent); err != nil {
		models.RespondError(conn, req.ID, err.Error())
		return
	}

	models.Respond(conn, req.ID, m.GetState())
}

func handleDecrement(conn *ipc.ConnWriter, req ipc.Request, m *Manager) {
	device, err := params.String(req.Params, "device")
	if err != nil {
		models.RespondError(conn, req.ID, err.Error())
		return
	}

	step := params.IntOpt(req.Params, "step", 10)
	exponential := params.BoolOpt(req.Params, "exponential", false)
	exponent := params.FloatOpt(req.Params, "exponent", 1.2)

	if err := m.IncrementBrightnessWithExponent(device, -step, exponential, exponent); err != nil {
		models.RespondError(conn, req.ID, err.Error())
		return
	}

	models.Respond(conn, req.ID, m.GetState())
}

func handleRescan(conn *ipc.ConnWriter, req ipc.Request, m *Manager) {
	m.Rescan()
	models.Respond(conn, req.ID, m.GetState())
}

func handleSubscribe(conn *ipc.ConnWriter, req ipc.Request, m *Manager) {
	clientID := fmt.Sprintf("brightness-%d", req.ID)

	ch := m.Subscribe(clientID)
	defer m.Unsubscribe(clientID)

	initialState := m.GetState()
	if err := conn.WriteResponse(ipc.Response[State]{
		ID:     req.ID,
		Result: &initialState,
	}); err != nil {
		return
	}

	for state := range ch {
		if err := conn.WriteResponse(ipc.Response[State]{
			ID:     req.ID,
			Result: &state,
		}); err != nil {
			return
		}
	}
}
