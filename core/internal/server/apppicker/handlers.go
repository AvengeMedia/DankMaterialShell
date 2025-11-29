package apppicker

import (
	"net"

	"github.com/AvengeMedia/DankMaterialShell/core/internal/log"
	"github.com/AvengeMedia/DankMaterialShell/core/internal/server/models"
)

type Request struct {
	ID     int                    `json:"id"`
	Method string                 `json:"method"`
	Params map[string]interface{} `json:"params"`
}

func HandleRequest(conn net.Conn, req Request, manager *Manager) {
	switch req.Method {
	case "apppicker.open", "browser.open":
		handleOpen(conn, req, manager)
	default:
		models.RespondError(conn, req.ID, "unknown method")
	}
}

func handleOpen(conn net.Conn, req Request, manager *Manager) {
	log.Infof("AppPicker: Received %s request with params: %+v", req.Method, req.Params)

	target, ok := req.Params["target"].(string)
	if !ok {
		target, ok = req.Params["url"].(string)
		if !ok {
			log.Warnf("AppPicker: Invalid target parameter in request")
			models.RespondError(conn, req.ID, "invalid target parameter")
			return
		}
	}

	event := OpenEvent{
		Target:      target,
		RequestType: "url",
	}

	if mimeType, ok := req.Params["mimeType"].(string); ok {
		event.MimeType = mimeType
	}

	if categories, ok := req.Params["categories"].([]interface{}); ok {
		event.Categories = make([]string, 0, len(categories))
		for _, cat := range categories {
			if catStr, ok := cat.(string); ok {
				event.Categories = append(event.Categories, catStr)
			}
		}
	}

	if requestType, ok := req.Params["requestType"].(string); ok {
		event.RequestType = requestType
	}

	log.Infof("AppPicker: Broadcasting event: %+v", event)
	manager.RequestOpen(event)
	models.Respond(conn, req.ID, "ok")
	log.Infof("AppPicker: Request handled successfully")
}
