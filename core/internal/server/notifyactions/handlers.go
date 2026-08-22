package notifyactions

import (
	"github.com/AvengeMedia/DankMaterialShell/core/internal/server/models"
)

func HandleRequest(conn *models.Conn, req models.Request, manager *Manager) {
	switch req.Method {
	case "notify.watchAction":
		handleWatchAction(conn, req, manager)
	default:
		models.RespondError(conn, req.ID, "unknown method")
	}
}

func handleWatchAction(conn *models.Conn, req models.Request, manager *Manager) {
	id, ok := models.Get[float64](req, "id")
	if !ok || id <= 0 {
		models.RespondError(conn, req.ID, "invalid id parameter")
		return
	}
	path, ok := models.Get[string](req, "path")
	if !ok || path == "" {
		models.RespondError(conn, req.ID, "invalid path parameter")
		return
	}
	manager.Watch(uint32(id), path)
	models.Respond(conn, req.ID, "ok")
}
