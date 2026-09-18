package tailscale

import (
	"fmt"

	"github.com/AvengeMedia/DankMaterialShell/core/internal/server/models"
	"github.com/AvengeMedia/dankgo/ipc"
)

// HandleRequest routes an IPC request to the appropriate handler.
func HandleRequest(conn *ipc.ConnWriter, req ipc.Request, manager *Manager) {
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

func handleGetStatus(conn *ipc.ConnWriter, req ipc.Request, manager *Manager) {
	state := manager.GetState()
	models.Respond(conn, req.ID, state)
}

func handleRefresh(conn *ipc.ConnWriter, req ipc.Request, manager *Manager) {
	manager.RefreshState()
	models.Respond(conn, req.ID, models.SuccessResult{Success: true, Message: "refreshed"})
}

func handleConnect(conn *ipc.ConnWriter, req ipc.Request, manager *Manager) {
	if err := manager.Connect(); err != nil {
		models.RespondError(conn, req.ID, err.Error())
		return
	}
	models.Respond(conn, req.ID, models.SuccessResult{Success: true, Message: "connected"})
}

func handleDisconnect(conn *ipc.ConnWriter, req ipc.Request, manager *Manager) {
	if err := manager.Disconnect(); err != nil {
		models.RespondError(conn, req.ID, err.Error())
		return
	}
	models.Respond(conn, req.ID, models.SuccessResult{Success: true, Message: "disconnected"})
}

func handleSetExitNode(conn *ipc.ConnWriter, req ipc.Request, manager *Manager) {
	id := models.GetOr(req, "id", "")
	if err := manager.SetExitNode(id); err != nil {
		models.RespondError(conn, req.ID, err.Error())
		return
	}
	models.Respond(conn, req.ID, models.SuccessResult{Success: true, Message: "exit node updated"})
}

func handleSetAllowLanAccess(conn *ipc.ConnWriter, req ipc.Request, manager *Manager) {
	enabled := models.GetOr(req, "enabled", false)
	if err := manager.SetAllowLANAccess(enabled); err != nil {
		models.RespondError(conn, req.ID, err.Error())
		return
	}
	models.Respond(conn, req.ID, models.SuccessResult{Success: true, Message: "lan access updated"})
}
