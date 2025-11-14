package evdev

import (
	"net"

	"github.com/AvengeMedia/DankMaterialShell/core/internal/server/models"
)

type Request struct {
	ID     interface{}            `json:"id"`
	Method string                 `json:"method"`
	Params map[string]interface{} `json:"params"`
}

func HandleRequest(conn net.Conn, req Request, m *Manager) {
	switch req.Method {
	case "evdev.getState":
		handleGetState(conn, req, m)
	default:
		models.RespondError(conn, req.ID.(int), "unknown method: "+req.Method)
	}
}

func handleGetState(conn net.Conn, req Request, m *Manager) {
	state := m.GetState()
	models.Respond(conn, req.ID.(int), state)
}
