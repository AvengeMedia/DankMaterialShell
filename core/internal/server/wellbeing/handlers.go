package wellbeing

import (
	"fmt"

	"github.com/AvengeMedia/DankMaterialShell/core/internal/server/models"
	"github.com/AvengeMedia/dankgo/ipc"
	"github.com/AvengeMedia/dankgo/ipc/params"
)

func HandleRequest(conn *ipc.ConnWriter, req ipc.Request, manager *Manager) {
	switch req.Method {
	case "wellbeing.getState":
		models.Respond(conn, req.ID, manager.GetState())
	case "wellbeing.setState":
		handleSetState(conn, req, manager)
	case "wellbeing.setLimits":
		handleSetLimits(conn, req, manager)
	case "wellbeing.summary":
		days := min(max(params.IntOpt(req.Params, "days", 7), 1), retentionDays)
		models.Respond(conn, req.ID, map[string]any{"days": manager.Summary(days)})
	case "wellbeing.clear":
		manager.Clear()
		models.Respond(conn, req.ID, models.SuccessResult{Success: true, Message: "wellbeing history cleared"})
	default:
		models.RespondError(conn, req.ID, fmt.Sprintf("unknown method: %s", req.Method))
	}
}

func handleSetState(conn *ipc.ConnWriter, req ipc.Request, manager *Manager) {
	active, err := params.Bool(req.Params, "active")
	if err != nil {
		models.RespondError(conn, req.ID, err.Error())
		return
	}
	manager.SetState(params.StringOpt(req.Params, "appId", ""), active, int64(params.FloatOpt(req.Params, "seq", 0)))
	models.Respond(conn, req.ID, models.SuccessResult{Success: true, Message: "wellbeing state set"})
}

func handleSetLimits(conn *ipc.ConnWriter, req ipc.Request, manager *Manager) {
	limits := Limits{Daily: int64(params.FloatOpt(req.Params, "daily", 0)), Apps: map[string]int64{}}
	if apps, ok := params.AnyMap(req.Params, "apps"); ok {
		for appID, raw := range apps {
			seconds, ok := raw.(float64)
			if !ok || seconds <= 0 || appID == "" {
				continue
			}
			limits.Apps[appID] = int64(seconds)
		}
	}
	manager.SetLimits(limits)
	models.Respond(conn, req.ID, models.SuccessResult{Success: true, Message: "wellbeing limits set"})
}
