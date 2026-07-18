package chromecast

import (
	"fmt"
	"net"

	"github.com/AvengeMedia/DankMaterialShell/core/internal/server/models"
)

// HandleRequest routes an IPC request to the appropriate handler.
func HandleRequest(conn net.Conn, req models.Request, manager *Manager) {
	switch req.Method {
	case "chromecast.getState":
		handleGetState(conn, req, manager)
	case "chromecast.startDiscovery":
		handleStartDiscovery(conn, req, manager)
	case "chromecast.stopDiscovery":
		handleStopDiscovery(conn, req, manager)
	case "chromecast.connect":
		handleConnect(conn, req, manager)
	case "chromecast.disconnect":
		handleDisconnect(conn, req, manager)
	case "chromecast.cast":
		handleCast(conn, req, manager)
	case "chromecast.play":
		handleControl(conn, req, manager.Play, "playing")
	case "chromecast.pause":
		handleControl(conn, req, manager.Pause, "paused")
	case "chromecast.stop":
		handleControl(conn, req, manager.StopPlayback, "stopped")
	case "chromecast.seek":
		handleSeek(conn, req, manager)
	case "chromecast.setVolume":
		handleSetVolume(conn, req, manager)
	case "chromecast.setMuted":
		handleSetMuted(conn, req, manager)
	case "chromecast.castScreen":
		handleCastScreen(conn, req, manager)
	case "chromecast.stopScreen":
		handleStopScreen(conn, req, manager)
	case "chromecast.setPreferred":
		handleSetPreferred(conn, req, manager)
	case "chromecast.clearPreferred":
		manager.ClearPreferred()
		models.Respond(conn, req.ID, models.SuccessResult{Success: true, Message: "preference cleared"})
	default:
		models.RespondError(conn, req.ID, fmt.Sprintf("unknown method: %s", req.Method))
	}
}

func handleGetState(conn net.Conn, req models.Request, manager *Manager) {
	models.Respond(conn, req.ID, manager.GetState())
}

func handleStartDiscovery(conn net.Conn, req models.Request, manager *Manager) {
	if err := manager.StartDiscovery(); err != nil {
		models.RespondError(conn, req.ID, err.Error())
		return
	}
	models.Respond(conn, req.ID, models.SuccessResult{Success: true, Message: "discovery started"})
}

func handleStopDiscovery(conn net.Conn, req models.Request, manager *Manager) {
	manager.StopDiscovery()
	models.Respond(conn, req.ID, models.SuccessResult{Success: true, Message: "discovery stopped"})
}

func handleConnect(conn net.Conn, req models.Request, manager *Manager) {
	id := models.GetOr(req, "id", "")
	if id == "" {
		models.RespondError(conn, req.ID, "missing device id")
		return
	}
	if err := manager.Connect(id); err != nil {
		models.RespondError(conn, req.ID, err.Error())
		return
	}
	models.Respond(conn, req.ID, models.SuccessResult{Success: true, Message: "connected"})
}

func handleDisconnect(conn net.Conn, req models.Request, manager *Manager) {
	manager.Disconnect()
	models.Respond(conn, req.ID, models.SuccessResult{Success: true, Message: "disconnected"})
}

func handleCast(conn net.Conn, req models.Request, manager *Manager) {
	url := models.GetOr(req, "url", "")
	if url == "" {
		models.RespondError(conn, req.ID, "missing url")
		return
	}
	contentType := models.GetOr(req, "contentType", "")
	if err := manager.Cast(url, contentType); err != nil {
		models.RespondError(conn, req.ID, err.Error())
		return
	}
	models.Respond(conn, req.ID, models.SuccessResult{Success: true, Message: "casting"})
}

// handleControl wraps a no-argument transport action.
func handleControl(conn net.Conn, req models.Request, action func() error, okMsg string) {
	if err := action(); err != nil {
		models.RespondError(conn, req.ID, err.Error())
		return
	}
	models.Respond(conn, req.ID, models.SuccessResult{Success: true, Message: okMsg})
}

func handleSeek(conn net.Conn, req models.Request, manager *Manager) {
	pos := models.GetOr(req, "position", float64(0))
	if err := manager.Seek(pos); err != nil {
		models.RespondError(conn, req.ID, err.Error())
		return
	}
	models.Respond(conn, req.ID, models.SuccessResult{Success: true, Message: "seeked"})
}

func handleSetVolume(conn net.Conn, req models.Request, manager *Manager) {
	level := models.GetOr(req, "level", float64(0))
	if err := manager.SetVolume(level); err != nil {
		models.RespondError(conn, req.ID, err.Error())
		return
	}
	models.Respond(conn, req.ID, models.SuccessResult{Success: true, Message: "volume set"})
}

func handleSetMuted(conn net.Conn, req models.Request, manager *Manager) {
	muted := models.GetOr(req, "muted", false)
	if err := manager.SetMuted(muted); err != nil {
		models.RespondError(conn, req.ID, err.Error())
		return
	}
	models.Respond(conn, req.ID, models.SuccessResult{Success: true, Message: "mute set"})
}

func handleCastScreen(conn net.Conn, req models.Request, manager *Manager) {
	if err := manager.CastScreen(); err != nil {
		models.RespondError(conn, req.ID, err.Error())
		return
	}
	models.Respond(conn, req.ID, models.SuccessResult{Success: true, Message: "screen casting"})
}

func handleStopScreen(conn net.Conn, req models.Request, manager *Manager) {
	manager.StopScreen()
	models.Respond(conn, req.ID, models.SuccessResult{Success: true, Message: "screen stopped"})
}

func handleSetPreferred(conn net.Conn, req models.Request, manager *Manager) {
	id := models.GetOr(req, "id", "")
	if id == "" {
		models.RespondError(conn, req.ID, "missing device id")
		return
	}
	manager.SetPreferred(id)
	models.Respond(conn, req.ID, models.SuccessResult{Success: true, Message: "preference saved"})
}
