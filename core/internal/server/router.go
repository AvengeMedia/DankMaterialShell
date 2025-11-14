package server

import (
	"fmt"
	"net"
	"strings"

	"github.com/AvengeMedia/DankMaterialShell/core/internal/server/bluez"
	"github.com/AvengeMedia/DankMaterialShell/core/internal/server/brightness"
	"github.com/AvengeMedia/DankMaterialShell/core/internal/server/cups"
	"github.com/AvengeMedia/DankMaterialShell/core/internal/server/dwl"
	"github.com/AvengeMedia/DankMaterialShell/core/internal/server/evdev"
	"github.com/AvengeMedia/DankMaterialShell/core/internal/server/extworkspace"
	"github.com/AvengeMedia/DankMaterialShell/core/internal/server/freedesktop"
	"github.com/AvengeMedia/DankMaterialShell/core/internal/server/loginctl"
	"github.com/AvengeMedia/DankMaterialShell/core/internal/server/models"
	"github.com/AvengeMedia/DankMaterialShell/core/internal/server/network"
	serverPlugins "github.com/AvengeMedia/DankMaterialShell/core/internal/server/plugins"
	"github.com/AvengeMedia/DankMaterialShell/core/internal/server/wayland"
	"github.com/AvengeMedia/DankMaterialShell/core/internal/server/wlroutput"
)

func RouteRequest(conn net.Conn, req models.Request) {
	if strings.HasPrefix(req.Method, "network.") {
		if networkManager == nil {
			models.RespondError(conn, req.ID, "network manager not initialized")
			return
		}
		netReq := network.Request{
			ID:     req.ID,
			Method: req.Method,
			Params: req.Params,
		}
		network.HandleRequest(conn, netReq, networkManager)
		return
	}

	if strings.HasPrefix(req.Method, "plugins.") {
		serverPlugins.HandleRequest(conn, req)
		return
	}

	if strings.HasPrefix(req.Method, "loginctl.") {
		if loginctlManager == nil {
			models.RespondError(conn, req.ID, "loginctl manager not initialized")
			return
		}
		loginReq := loginctl.Request{
			ID:     req.ID,
			Method: req.Method,
			Params: req.Params,
		}
		loginctl.HandleRequest(conn, loginReq, loginctlManager)
		return
	}

	if strings.HasPrefix(req.Method, "freedesktop.") {
		if freedesktopManager == nil {
			models.RespondError(conn, req.ID, "freedesktop manager not initialized")
			return
		}
		freedeskReq := freedesktop.Request{
			ID:     req.ID,
			Method: req.Method,
			Params: req.Params,
		}
		freedesktop.HandleRequest(conn, freedeskReq, freedesktopManager)
		return
	}

	if strings.HasPrefix(req.Method, "wayland.") {
		if waylandManager == nil {
			models.RespondError(conn, req.ID, "wayland manager not initialized")
			return
		}
		waylandReq := wayland.Request{
			ID:     req.ID,
			Method: req.Method,
			Params: req.Params,
		}
		wayland.HandleRequest(conn, waylandReq, waylandManager)
		return
	}

	if strings.HasPrefix(req.Method, "bluetooth.") {
		if bluezManager == nil {
			models.RespondError(conn, req.ID, "bluetooth manager not initialized")
			return
		}
		bluezReq := bluez.Request{
			ID:     req.ID,
			Method: req.Method,
			Params: req.Params,
		}
		bluez.HandleRequest(conn, bluezReq, bluezManager)
		return
	}

	if strings.HasPrefix(req.Method, "cups.") {
		if cupsManager == nil {
			models.RespondError(conn, req.ID, "CUPS manager not initialized")
			return
		}
		cupsReq := cups.Request{
			ID:     req.ID,
			Method: req.Method,
			Params: req.Params,
		}
		cups.HandleRequest(conn, cupsReq, cupsManager)
		return
	}

	if strings.HasPrefix(req.Method, "dwl.") {
		if dwlManager == nil {
			models.RespondError(conn, req.ID, "dwl manager not initialized")
			return
		}
		dwlReq := dwl.Request{
			ID:     req.ID,
			Method: req.Method,
			Params: req.Params,
		}
		dwl.HandleRequest(conn, dwlReq, dwlManager)
		return
	}

	if strings.HasPrefix(req.Method, "brightness.") {
		if brightnessManager == nil {
			models.RespondError(conn, req.ID, "brightness manager not initialized")
			return
		}
		brightnessReq := brightness.Request{
			ID:     req.ID,
			Method: req.Method,
			Params: req.Params,
		}
		brightness.HandleRequest(conn, brightnessReq, brightnessManager)
		return
	}

	if strings.HasPrefix(req.Method, "extworkspace.") {
		if extWorkspaceManager == nil {
			models.RespondError(conn, req.ID, "extworkspace manager not initialized")
			return
		}
		extWorkspaceReq := extworkspace.Request{
			ID:     req.ID,
			Method: req.Method,
			Params: req.Params,
		}
		extworkspace.HandleRequest(conn, extWorkspaceReq, extWorkspaceManager)
		return
	}

	if strings.HasPrefix(req.Method, "wlroutput.") {
		if wlrOutputManager == nil {
			models.RespondError(conn, req.ID, "wlroutput manager not initialized")
			return
		}
		wlrOutputReq := wlroutput.Request{
			ID:     req.ID,
			Method: req.Method,
			Params: req.Params,
		}
		wlroutput.HandleRequest(conn, wlrOutputReq, wlrOutputManager)
		return
	}

	if strings.HasPrefix(req.Method, "evdev.") {
		if evdevManager == nil {
			models.RespondError(conn, req.ID, "evdev manager not initialized")
			return
		}
		evdevReq := evdev.Request{
			ID:     req.ID,
			Method: req.Method,
			Params: req.Params,
		}
		evdev.HandleRequest(conn, evdevReq, evdevManager)
		return
	}

	switch req.Method {
	case "ping":
		models.Respond(conn, req.ID, "pong")
	case "getServerInfo":
		info := getServerInfo()
		models.Respond(conn, req.ID, info)
	case "subscribe":
		handleSubscribe(conn, req)
	default:
		models.RespondError(conn, req.ID, fmt.Sprintf("unknown method: %s", req.Method))
	}
}
