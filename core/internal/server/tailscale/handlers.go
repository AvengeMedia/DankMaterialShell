package tailscale

import (
	"fmt"
	"net"

	"github.com/AvengeMedia/DankMaterialShell/core/internal/server/models"
)

// HandleRequest routes an IPC request to the appropriate handler.
func HandleRequest(conn net.Conn, req models.Request, manager *Manager) {
	switch req.Method {
	case "tailscale.getStatus":
		handleGetStatus(conn, req, manager)
	case "tailscale.refresh":
		handleRefresh(conn, req, manager)
	default:
		models.RespondError(conn, req.ID, fmt.Sprintf("unknown method: %s", req.Method))
	}
}

func handleGetStatus(conn net.Conn, req models.Request, manager *Manager) {
	state := manager.GetState()
	models.Respond(conn, req.ID, state)
}

func handleRefresh(conn net.Conn, req models.Request, manager *Manager) {
	manager.RefreshState()
	models.Respond(conn, req.ID, models.SuccessResult{Success: true, Message: "refreshed"})
}
