package mime

import (
	"fmt"
	"net"

	"github.com/AvengeMedia/DankMaterialShell/core/internal/desktop"
	"github.com/AvengeMedia/DankMaterialShell/core/internal/server/models"
	"github.com/AvengeMedia/DankMaterialShell/core/internal/server/params"
)

type defaultResult struct {
	MimeType  string `json:"mimeType"`
	DesktopID string `json:"desktopId"`
}

type appsResult struct {
	MimeType   string   `json:"mimeType"`
	DesktopIDs []string `json:"desktopIds"`
}

type queryResult struct {
	Defaults map[string]string `json:"defaults"`
}

func HandleRequest(conn net.Conn, req models.Request) {
	switch req.Method {
	case "mime.getDefault":
		handleGetDefault(conn, req)
	case "mime.setDefault":
		handleSetDefault(conn, req)
	case "mime.setDefaults":
		handleSetDefaults(conn, req)
	case "mime.appsForMime":
		handleAppsForMime(conn, req)
	case "mime.queryDefaults":
		handleQueryDefaults(conn, req)
	case "mime.invalidate":
		desktop.InvalidateCache()
		models.Respond(conn, req.ID, models.SuccessResult{Success: true})
	default:
		models.RespondError(conn, req.ID, fmt.Sprintf("unknown method: %s", req.Method))
	}
}

func handleGetDefault(conn net.Conn, req models.Request) {
	mimeType, err := mimeParam(req.Params, "mimeType")
	if err != nil {
		models.RespondError(conn, req.ID, err.Error())
		return
	}
	models.Respond(conn, req.ID, defaultResult{
		MimeType:  mimeType,
		DesktopID: desktop.GetDefault(mimeType),
	})
}

func handleSetDefault(conn net.Conn, req models.Request) {
	mimeType, err := mimeParam(req.Params, "mimeType")
	if err != nil {
		models.RespondError(conn, req.ID, err.Error())
		return
	}
	desktopID, err := params.StringNonEmpty(req.Params, "desktopId")
	if err != nil {
		models.RespondError(conn, req.ID, err.Error())
		return
	}
	if err := desktop.SetDefault(mimeType, desktopID); err != nil {
		models.RespondError(conn, req.ID, err.Error())
		return
	}
	models.Respond(conn, req.ID, models.SuccessResult{Success: true})
}

func handleSetDefaults(conn net.Conn, req models.Request) {
	desktopID, err := params.StringNonEmpty(req.Params, "desktopId")
	if err != nil {
		models.RespondError(conn, req.ID, err.Error())
		return
	}
	mimeTypes, err := mimeListParam(req, "mimeTypes")
	if err != nil {
		models.RespondError(conn, req.ID, err.Error())
		return
	}
	if err := desktop.SetDefaults(mimeTypes, desktopID); err != nil {
		models.RespondError(conn, req.ID, err.Error())
		return
	}
	models.Respond(conn, req.ID, models.SuccessResult{Success: true})
}

func handleAppsForMime(conn net.Conn, req models.Request) {
	mimeType, err := mimeParam(req.Params, "mimeType")
	if err != nil {
		models.RespondError(conn, req.ID, err.Error())
		return
	}
	ids := desktop.AppsForMime(mimeType)
	if ids == nil {
		ids = []string{}
	}
	models.Respond(conn, req.ID, appsResult{
		MimeType:   mimeType,
		DesktopIDs: ids,
	})
}

func handleQueryDefaults(conn net.Conn, req models.Request) {
	mimeTypes, err := mimeListParam(req, "mimeTypes")
	if err != nil {
		models.RespondError(conn, req.ID, err.Error())
		return
	}
	models.Respond(conn, req.ID, queryResult{
		Defaults: desktop.QueryDefaults(mimeTypes),
	})
}

func mimeParam(p map[string]any, key string) (string, error) {
	raw, err := params.StringNonEmpty(p, key)
	if err != nil {
		return "", err
	}
	canonical := desktop.StripMimeParams(raw)
	if canonical == "" {
		return "", fmt.Errorf("invalid '%s' parameter", key)
	}
	return canonical, nil
}

func mimeListParam(req models.Request, key string) ([]string, error) {
	raw, ok := models.Get[[]any](req, key)
	if !ok {
		return nil, fmt.Errorf("missing or invalid '%s' parameter", key)
	}
	out := make([]string, 0, len(raw))
	for _, v := range raw {
		s, ok := v.(string)
		if !ok {
			continue
		}
		canonical := desktop.StripMimeParams(s)
		if canonical == "" {
			continue
		}
		out = append(out, canonical)
	}
	if len(out) == 0 {
		return nil, fmt.Errorf("no valid mime types provided")
	}
	return out, nil
}
