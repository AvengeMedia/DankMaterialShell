package server

import (
	"context"
	"net"
	"time"

	"github.com/AvengeMedia/DankMaterialShell/core/internal/matugen"
	"github.com/AvengeMedia/DankMaterialShell/core/internal/server/models"
)

type MatugenQueueResult struct {
	Success bool   `json:"success"`
	Message string `json:"message,omitempty"`
}

func handleMatugenQueue(conn net.Conn, req models.Request) {
	opts := matugen.Options{
		StateDir:            models.GetOr(req, "stateDir", ""),
		ShellDir:            models.GetOr(req, "shellDir", ""),
		ConfigDir:           models.GetOr(req, "configDir", ""),
		Kind:                models.GetOr(req, "kind", ""),
		Value:               models.GetOr(req, "value", ""),
		Mode:                matugen.ColorMode(models.GetOr(req, "mode", "")),
		IconTheme:           models.GetOr(req, "iconTheme", ""),
		MatugenType:         models.GetOr(req, "matugenType", ""),
		RunUserTemplates:    models.GetOr(req, "runUserTemplates", true),
		StockColors:         models.GetOr(req, "stockColors", ""),
		SyncModeWithPortal:  models.GetOr(req, "syncModeWithPortal", false),
		TerminalsAlwaysDark: models.GetOr(req, "terminalsAlwaysDark", false),
		SkipTemplates:       models.GetOr(req, "skipTemplates", ""),
		Contrast:            models.GetOr(req, "contrast", 0.0),
	}

	wait := models.GetOr(req, "wait", true)

	queue := matugen.GetQueue()
	resultCh := queue.Submit(opts)

	if !wait {
		models.Respond(conn, req.ID, MatugenQueueResult{
			Success: true,
			Message: "queued",
		})
		return
	}

	ctx, cancel := context.WithTimeout(context.Background(), 60*time.Second)
	defer cancel()

	select {
	case result := <-resultCh:
		if result.Error != nil {
			if result.Error == context.Canceled {
				models.Respond(conn, req.ID, MatugenQueueResult{
					Success: false,
					Message: "cancelled",
				})
				return
			}
			models.RespondError(conn, req.ID, result.Error.Error())
			return
		}
		models.Respond(conn, req.ID, MatugenQueueResult{
			Success: true,
			Message: "completed",
		})
	case <-ctx.Done():
		models.RespondError(conn, req.ID, "timeout waiting for theme generation")
	}
}

func handleMatugenStatus(conn net.Conn, req models.Request) {
	queue := matugen.GetQueue()
	models.Respond(conn, req.ID, map[string]bool{
		"running": queue.IsRunning(),
		"pending": queue.HasPending(),
	})
}
