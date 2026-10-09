package notifyactions

import (
	"os"

	"github.com/AvengeMedia/DankMaterialShell/core/internal/notify"
	"github.com/AvengeMedia/DankMaterialShell/core/internal/server/models"
	"github.com/AvengeMedia/dankgo/ipc"
	"github.com/AvengeMedia/dankgo/ipc/params"
)

func HandleRequest(conn *ipc.ConnWriter, req ipc.Request, manager *Manager) {
	switch req.Method {
	case "notify.watchAction":
		handleWatchAction(conn, req, manager)
	case "notify.send":
		handleSend(conn, req, manager)
	default:
		models.RespondError(conn, req.ID, "unknown method")
	}
}

func handleWatchAction(conn *ipc.ConnWriter, req ipc.Request, manager *Manager) {
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

// The shell can't post its own: notify-send blocks until the notification closes, and the shell is the server.
// Only the arguments come from the client; the executable is always this dms binary.
func handleSend(conn *ipc.ConnWriter, req ipc.Request, manager *Manager) {
	summary, ok := models.Get[string](req, "summary")
	if !ok || summary == "" {
		models.RespondError(conn, req.ID, "invalid summary parameter")
		return
	}
	n := notify.Notification{
		Summary: summary,
		Body:    params.StringOpt(req.Params, "body", ""),
		Icon:    params.StringOpt(req.Params, "icon", ""),
		Timeout: 5000,
	}
	label := params.StringOpt(req.Params, "actionLabel", "")
	var argv []string
	if args := stringSlice(req.Params["actionArgs"]); label != "" && len(args) > 0 {
		exe, err := os.Executable()
		if err != nil {
			exe = "dms"
		}
		argv = append([]string{exe}, args...)
		n.Actions = []string{"default", label}
	}
	id, err := notify.Send(n)
	if err != nil {
		models.RespondError(conn, req.ID, err.Error())
		return
	}
	if len(n.Actions) > 0 && id != 0 {
		manager.WatchCommand(id, argv)
	}
	models.Respond(conn, req.ID, map[string]any{"id": id})
}

func stringSlice(v any) []string {
	arr, ok := v.([]any)
	if !ok {
		return nil
	}
	out := make([]string, 0, len(arr))
	for _, item := range arr {
		if s, ok := item.(string); ok && s != "" {
			out = append(out, s)
		}
	}
	return out
}
