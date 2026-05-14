package apppicker

import (
	"net"

	"github.com/AvengeMedia/DankMaterialShell/core/internal/desktop"
	"github.com/AvengeMedia/DankMaterialShell/core/internal/log"
	"github.com/AvengeMedia/DankMaterialShell/core/internal/server/models"
)

func HandleRequest(conn net.Conn, req models.Request, manager *Manager) {
	switch req.Method {
	case "apppicker.open", "browser.open":
		handleOpen(conn, req, manager)
	default:
		models.RespondError(conn, req.ID, "unknown method")
	}
}

func handleOpen(conn net.Conn, req models.Request, manager *Manager) {
	log.Infof("AppPicker: Received %s request with params: %+v", req.Method, req.Params)

	target, ok := models.Get[string](req, "target")
	if !ok {
		target, ok = models.Get[string](req, "url")
		if !ok {
			log.Warnf("AppPicker: Invalid target parameter in request")
			models.RespondError(conn, req.ID, "invalid target parameter")
			return
		}
	}

	event := OpenEvent{
		Target:      target,
		RequestType: models.GetOr(req, "requestType", "url"),
		MimeType:    desktop.StripMimeParams(models.GetOr(req, "mimeType", "")),
	}

	if categories, ok := models.Get[[]any](req, "categories"); ok {
		event.Categories = make([]string, 0, len(categories))
		for _, cat := range categories {
			if catStr, ok := cat.(string); ok {
				event.Categories = append(event.Categories, catStr)
			}
		}
	}

	log.Infof("AppPicker: Broadcasting event: %+v", event)
	manager.RequestOpen(event)
	models.Respond(conn, req.ID, "ok")
	log.Infof("AppPicker: Request handled successfully")
}
