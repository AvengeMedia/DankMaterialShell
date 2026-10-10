package sysupdate

import (
	"context"

	"github.com/AvengeMedia/DankMaterialShell/core/internal/server/models"
	"github.com/AvengeMedia/dankgo/ipc"
	"github.com/AvengeMedia/dankgo/ipc/params"
)

func HandleRequest(ctx context.Context, conn *ipc.ConnWriter, req ipc.Request, m *Manager) {
	switch req.Method {
	case "sysupdate.getState":
		conn.Respond(req.ID, m.GetState())
	case "sysupdate.refresh":
		force := params.BoolOpt(req.Params, "force", false)
		background := params.BoolOpt(req.Params, "background", false)
		m.Refresh(RefreshOptions{Force: force, Background: background})
		conn.Respond(req.ID, m.GetState())
	case "sysupdate.upgrade":
		handleUpgrade(conn, req, m)
	case "sysupdate.cancel":
		m.Cancel()
		conn.Respond(req.ID, m.GetState())
	case "sysupdate.acquire":
		m.Acquire(ctx, conn)
		conn.Respond(req.ID, models.SuccessResult{Success: true})
	case "sysupdate.release":
		m.Release(conn)
		conn.Respond(req.ID, models.SuccessResult{Success: true})
	case "sysupdate.releases":
		force := params.BoolOpt(req.Params, "force", false)
		conn.Respond(req.ID, m.Releases(force))
	case "sysupdate.setInterval":
		seconds, err := params.Int(req.Params, "seconds")
		if err != nil {
			conn.RespondError(req.ID, err.Error())
			return
		}
		m.SetInterval(seconds)
		conn.Respond(req.ID, m.GetState())
	default:
		conn.RespondError(req.ID, "unknown method: "+req.Method)
	}
}

func handleUpgrade(conn *ipc.ConnWriter, req ipc.Request, m *Manager) {
	opts := UpgradeOptions{
		IncludeFlatpak: params.BoolOpt(req.Params, "includeFlatpak", true),
		IncludeAUR:     params.BoolOpt(req.Params, "includeAUR", true),
		DryRun:         params.BoolOpt(req.Params, "dry", false),
		Interactive:    params.BoolOpt(req.Params, "interactive", false),
		CustomCommand:  params.StringOpt(req.Params, "customCommand", ""),
		Terminal:       params.StringOpt(req.Params, "terminal", ""),
		TerminalArgs:   stringSliceOpt(req.Params, "terminalArgs"),
		Ignored:        stringSliceOpt(req.Params, "ignored"),
	}
	if err := m.Upgrade(opts); err != nil {
		conn.RespondError(req.ID, err.Error())
		return
	}
	conn.Respond(req.ID, m.GetState())
}

func stringSliceOpt(p map[string]any, key string) []string {
	val, ok := params.Any(p, key)
	if !ok {
		return nil
	}
	arr, ok := val.([]any)
	if !ok {
		return nil
	}
	out := make([]string, 0, len(arr))
	for _, v := range arr {
		if s, ok := v.(string); ok && s != "" {
			out = append(out, s)
		}
	}
	return out
}
