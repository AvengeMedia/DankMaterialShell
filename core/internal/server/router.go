package server

import (
	"fmt"
	"net"
	"strings"

	"github.com/AvengeMedia/DankMaterialShell/core/internal/server/apppicker"
	"github.com/AvengeMedia/DankMaterialShell/core/internal/server/bluez"
	"github.com/AvengeMedia/DankMaterialShell/core/internal/server/brightness"
	"github.com/AvengeMedia/DankMaterialShell/core/internal/server/clipboard"
	"github.com/AvengeMedia/DankMaterialShell/core/internal/server/cups"
	"github.com/AvengeMedia/DankMaterialShell/core/internal/server/dwl"
	"github.com/AvengeMedia/DankMaterialShell/core/internal/server/evdev"
	"github.com/AvengeMedia/DankMaterialShell/core/internal/server/extworkspace"
	"github.com/AvengeMedia/DankMaterialShell/core/internal/server/freedesktop"
	"github.com/AvengeMedia/DankMaterialShell/core/internal/server/loginctl"
	"github.com/AvengeMedia/DankMaterialShell/core/internal/server/models"
	"github.com/AvengeMedia/DankMaterialShell/core/internal/server/network"
	serverPlugins "github.com/AvengeMedia/DankMaterialShell/core/internal/server/plugins"
	serverThemes "github.com/AvengeMedia/DankMaterialShell/core/internal/server/themes"
	"github.com/AvengeMedia/DankMaterialShell/core/internal/server/wayland"
	"github.com/AvengeMedia/DankMaterialShell/core/internal/server/wlroutput"
)

func RouteRequest(conn net.Conn, req models.Request) {
	if strings.HasPrefix(req.Method, "network.") {
		if networkManager == nil {
			models.RespondError(conn, req.ID, "network manager not initialized")
			return
		}
		network.HandleRequest(conn, req, networkManager)
		return
	}

	if strings.HasPrefix(req.Method, "plugins.") {
		serverPlugins.HandleRequest(conn, req)
		return
	}

	if strings.HasPrefix(req.Method, "themes.") {
		serverThemes.HandleRequest(conn, req)
		return
	}

	if strings.HasPrefix(req.Method, "loginctl.") {
		if loginctlManager == nil {
			models.RespondError(conn, req.ID, "loginctl manager not initialized")
			return
		}
		loginctl.HandleRequest(conn, req, loginctlManager)
		return
	}

	if strings.HasPrefix(req.Method, "freedesktop.") {
		if freedesktopManager == nil {
			models.RespondError(conn, req.ID, "freedesktop manager not initialized")
			return
		}
		freedesktop.HandleRequest(conn, req, freedesktopManager)
		return
	}

	if strings.HasPrefix(req.Method, "wayland.") {
		if waylandManager == nil {
			models.RespondError(conn, req.ID, "wayland manager not initialized")
			return
		}
		wayland.HandleRequest(conn, req, waylandManager)
		return
	}

	if strings.HasPrefix(req.Method, "bluetooth.") {
		if bluezManager == nil {
			models.RespondError(conn, req.ID, "bluetooth manager not initialized")
			return
		}
		bluez.HandleRequest(conn, req, bluezManager)
		return
	}

	if strings.HasPrefix(req.Method, "browser.") || strings.HasPrefix(req.Method, "apppicker.") {
		if appPickerManager == nil {
			models.RespondError(conn, req.ID, "apppicker manager not initialized")
			return
		}
		apppicker.HandleRequest(conn, req, appPickerManager)
		return
	}

	if strings.HasPrefix(req.Method, "cups.") {
		if cupsManager == nil {
			models.RespondError(conn, req.ID, "CUPS manager not initialized")
			return
		}
		cups.HandleRequest(conn, req, cupsManager)
		return
	}

	if strings.HasPrefix(req.Method, "dwl.") {
		if dwlManager == nil {
			models.RespondError(conn, req.ID, "dwl manager not initialized")
			return
		}
		dwl.HandleRequest(conn, req, dwlManager)
		return
	}

	if strings.HasPrefix(req.Method, "brightness.") {
		if brightnessManager == nil {
			models.RespondError(conn, req.ID, "brightness manager not initialized")
			return
		}
		brightness.HandleRequest(conn, req, brightnessManager)
		return
	}

	if strings.HasPrefix(req.Method, "extworkspace.") {
		if extWorkspaceManager == nil {
			if extWorkspaceAvailable.Load() {
				extWorkspaceInitMutex.Lock()
				if extWorkspaceManager == nil {
					if err := InitializeExtWorkspaceManager(); err != nil {
						extWorkspaceInitMutex.Unlock()
						models.RespondError(conn, req.ID, "extworkspace manager not available")
						return
					}
				}
				extWorkspaceInitMutex.Unlock()
			} else {
				models.RespondError(conn, req.ID, "extworkspace manager not initialized")
				return
			}
		}
		extworkspace.HandleRequest(conn, req, extWorkspaceManager)
		return
	}

	if strings.HasPrefix(req.Method, "wlroutput.") {
		if wlrOutputManager == nil {
			models.RespondError(conn, req.ID, "wlroutput manager not initialized")
			return
		}
		wlroutput.HandleRequest(conn, req, wlrOutputManager)
		return
	}

	if strings.HasPrefix(req.Method, "evdev.") {
		if evdevManager == nil {
			models.RespondError(conn, req.ID, "evdev manager not initialized")
			return
		}
		evdev.HandleRequest(conn, req, evdevManager)
		return
	}

	if strings.HasPrefix(req.Method, "clipboard.") {
		switch req.Method {
		case "clipboard.getConfig":
			cfg := clipboard.LoadConfig()
			models.Respond(conn, req.ID, cfg)
			return
		case "clipboard.setConfig":
			handleClipboardSetConfig(conn, req)
			return
		}
		if clipboardManager == nil {
			models.RespondError(conn, req.ID, "clipboard manager not initialized")
			return
		}
		clipboard.HandleRequest(conn, req, clipboardManager)
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
	case "matugen.queue":
		handleMatugenQueue(conn, req)
	case "matugen.status":
		handleMatugenStatus(conn, req)
	default:
		models.RespondError(conn, req.ID, fmt.Sprintf("unknown method: %s", req.Method))
	}
}

func handleClipboardSetConfig(conn net.Conn, req models.Request) {
	cfg := clipboard.LoadConfig()

	if v, ok := req.Params["maxHistory"].(float64); ok {
		cfg.MaxHistory = int(v)
	}
	if v, ok := req.Params["maxEntrySize"].(float64); ok {
		cfg.MaxEntrySize = int64(v)
	}
	if v, ok := req.Params["autoClearDays"].(float64); ok {
		cfg.AutoClearDays = int(v)
	}
	if v, ok := req.Params["clearAtStartup"].(bool); ok {
		cfg.ClearAtStartup = v
	}
	if v, ok := req.Params["disabled"].(bool); ok {
		cfg.Disabled = v
	}

	if err := clipboard.SaveConfig(cfg); err != nil {
		models.RespondError(conn, req.ID, err.Error())
		return
	}

	models.Respond(conn, req.ID, models.SuccessResult{Success: true, Message: "config updated"})
}
