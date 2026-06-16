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
	case "tailscale.connect":
		handleConnect(conn, req, manager)
	case "tailscale.disconnect":
		handleDisconnect(conn, req, manager)
	case "tailscale.setExitNode":
		handleSetExitNode(conn, req, manager)
	case "tailscale.setAllowLanAccess":
		handleSetAllowLanAccess(conn, req, manager)
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

func handleConnect(conn net.Conn, req models.Request, manager *Manager) {
	if err := manager.Connect(); err != nil {
		models.RespondError(conn, req.ID, err.Error())
		return
	}
	models.Respond(conn, req.ID, models.SuccessResult{Success: true, Message: "connected"})
}

func handleDisconnect(conn net.Conn, req models.Request, manager *Manager) {
	if err := manager.Disconnect(); err != nil {
		models.RespondError(conn, req.ID, err.Error())
		return
	}
	models.Respond(conn, req.ID, models.SuccessResult{Success: true, Message: "disconnected"})
}

func handleSetExitNode(conn net.Conn, req models.Request, manager *Manager) {
	id := models.GetOr(req, "id", "")
	if err := manager.SetExitNode(id); err != nil {
		models.RespondError(conn, req.ID, err.Error())
		return
	}
	models.Respond(conn, req.ID, models.SuccessResult{Success: true, Message: "exit node updated"})
}

func handleSetAllowLanAccess(conn net.Conn, req models.Request, manager *Manager) {
	enabled := models.GetOr(req, "enabled", false)
	if err := manager.SetAllowLANAccess(enabled); err != nil {
		models.RespondError(conn, req.ID, err.Error())
		return
	}
	models.Respond(conn, req.ID, models.SuccessResult{Success: true, Message: "lan access updated"})
}
