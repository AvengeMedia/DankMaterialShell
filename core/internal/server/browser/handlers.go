package browser

import (
	"net"

	"github.com/AvengeMedia/DankMaterialShell/core/internal/server/models"
)

type Request struct {
	ID     int            `json:"id"`
	Method string         `json:"method"`
	Params map[string]any `json:"params"`
}

func HandleRequest(conn net.Conn, req Request, manager *Manager) {
	switch req.Method {
	case "browser.open":
		url, ok := req.Params["url"].(string)
		if !ok {
			models.RespondError(conn, req.ID, "invalid url parameter")
			return
		}
		manager.RequestOpen(url)
		models.Respond(conn, req.ID, "ok")
	default:
		models.RespondError(conn, req.ID, "unknown method")
	}
}
