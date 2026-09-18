package server

import (
	"context"
	"fmt"

	"github.com/AvengeMedia/DankMaterialShell/core/internal/server/apppicker"
	"github.com/AvengeMedia/DankMaterialShell/core/internal/server/bluez"
	"github.com/AvengeMedia/DankMaterialShell/core/internal/server/brightness"
	"github.com/AvengeMedia/DankMaterialShell/core/internal/server/clipboard"
	"github.com/AvengeMedia/DankMaterialShell/core/internal/server/cups"
	serverDbus "github.com/AvengeMedia/DankMaterialShell/core/internal/server/dbus"
	serverDgop "github.com/AvengeMedia/DankMaterialShell/core/internal/server/dgop"
	"github.com/AvengeMedia/DankMaterialShell/core/internal/server/evdev"
	"github.com/AvengeMedia/DankMaterialShell/core/internal/server/freedesktop"
	"github.com/AvengeMedia/DankMaterialShell/core/internal/server/location"
	"github.com/AvengeMedia/DankMaterialShell/core/internal/server/loginctl"
	serverLyrics "github.com/AvengeMedia/DankMaterialShell/core/internal/server/lyrics"
	"github.com/AvengeMedia/DankMaterialShell/core/internal/server/mime"
	"github.com/AvengeMedia/DankMaterialShell/core/internal/server/models"
	"github.com/AvengeMedia/DankMaterialShell/core/internal/server/network"
	"github.com/AvengeMedia/DankMaterialShell/core/internal/server/notifyactions"
	serverPlugins "github.com/AvengeMedia/DankMaterialShell/core/internal/server/plugins"
	serverRegistries "github.com/AvengeMedia/DankMaterialShell/core/internal/server/registries"
	"github.com/AvengeMedia/DankMaterialShell/core/internal/server/sysupdate"
	"github.com/AvengeMedia/DankMaterialShell/core/internal/server/tailscale"
	"github.com/AvengeMedia/DankMaterialShell/core/internal/server/thememode"
	serverThemes "github.com/AvengeMedia/DankMaterialShell/core/internal/server/themes"
	"github.com/AvengeMedia/DankMaterialShell/core/internal/server/wallpaper"
	"github.com/AvengeMedia/DankMaterialShell/core/internal/server/wayland"
	"github.com/AvengeMedia/DankMaterialShell/core/internal/server/wlroutput"
	"github.com/AvengeMedia/dankgo/ipc"
)

var requestMux = newRequestMux()

func RouteRequest(ctx context.Context, conn *ipc.ConnWriter, req ipc.Request) {
	requestMux.ServeIPC(ctx, conn, req, nil)
}

func requestHandler(handle func(*ipc.ConnWriter, ipc.Request)) ipc.Handler {
	return func(_ context.Context, conn *ipc.ConnWriter, req ipc.Request, _ *ipc.Subscriber) {
		handle(conn, req)
	}
}

func newRequestMux() *ipc.Mux {
	mux := ipc.NewMux()
	mux.Handle("ping", requestHandler(func(conn *ipc.ConnWriter, req ipc.Request) {
		models.Respond(conn, req.ID, "pong")
	}))
	mux.Handle("getServerInfo", requestHandler(func(conn *ipc.ConnWriter, req ipc.Request) {
		models.Respond(conn, req.ID, getServerInfo())
	}))
	mux.Handle("subscribe", func(ctx context.Context, conn *ipc.ConnWriter, req ipc.Request, _ *ipc.Subscriber) {
		handleSubscribe(ctx, conn, req)
	})
	mux.Handle("matugen.queue", requestHandler(handleMatugenQueue))
	mux.Handle("matugen.status", requestHandler(handleMatugenStatus))
	mux.Handle("clipboard.getConfig", requestHandler(func(conn *ipc.ConnWriter, req ipc.Request) {
		models.Respond(conn, req.ID, clipboard.LoadConfig())
	}))
	mux.Handle("clipboard.setConfig", requestHandler(handleClipboardSetConfig))

	mux.HandlePrefix("network.", requestHandler(func(conn *ipc.ConnWriter, req ipc.Request) {
		if networkManager == nil {
			models.RespondError(conn, req.ID, "network manager not initialized")
			return
		}
		network.HandleRequest(conn, req, networkManager)
	}))

	mux.HandlePrefix("plugins.", requestHandler(serverPlugins.HandleRequest))

	mux.HandlePrefix("themes.", requestHandler(serverThemes.HandleRequest))

	mux.HandlePrefix("registries.", requestHandler(serverRegistries.HandleRequest))

	mux.HandlePrefix("theme.auto.", requestHandler(func(conn *ipc.ConnWriter, req ipc.Request) {
		if themeModeManager == nil {
			models.RespondError(conn, req.ID, "theme mode manager not initialized")
			return
		}
		thememode.HandleRequest(conn, req, themeModeManager)
	}))

	mux.HandlePrefix("wallpaper.", requestHandler(func(conn *ipc.ConnWriter, req ipc.Request) {
		if wallpaperManager == nil {
			models.RespondError(conn, req.ID, "wallpaper manager not initialized")
			return
		}
		wallpaper.HandleRequest(conn, req, wallpaperManager)
	}))

	mux.HandlePrefix("loginctl.", requestHandler(func(conn *ipc.ConnWriter, req ipc.Request) {
		if loginctlManager == nil {
			models.RespondError(conn, req.ID, "loginctl manager not initialized")
			return
		}
		loginctl.HandleRequest(conn, req, loginctlManager)
	}))

	mux.HandlePrefix("freedesktop.", requestHandler(func(conn *ipc.ConnWriter, req ipc.Request) {
		if freedesktopManager == nil {
			models.RespondError(conn, req.ID, "freedesktop manager not initialized")
			return
		}
		freedesktop.HandleRequest(conn, req, freedesktopManager)
	}))

	mux.HandlePrefix("wayland.", requestHandler(func(conn *ipc.ConnWriter, req ipc.Request) {
		if waylandManager == nil {
			models.RespondError(conn, req.ID, "wayland manager not initialized")
			return
		}
		wayland.HandleRequest(conn, req, waylandManager)
	}))

	mux.HandlePrefix("bluetooth.", requestHandler(func(conn *ipc.ConnWriter, req ipc.Request) {
		if bluezManager == nil {
			models.RespondError(conn, req.ID, "bluetooth manager not initialized")
			return
		}
		bluez.HandleRequest(conn, req, bluezManager)
	}))

	mux.HandlePrefix("mime.", requestHandler(mime.HandleRequest))

	mux.HandlePrefix("dgop.", requestHandler(serverDgop.HandleRequest))

	mux.HandlePrefix("lyrics.", requestHandler(serverLyrics.HandleRequest))

	appPickerHandler := requestHandler(func(conn *ipc.ConnWriter, req ipc.Request) {
		if appPickerManager == nil {
			models.RespondError(conn, req.ID, "apppicker manager not initialized")
			return
		}
		apppicker.HandleRequest(conn, req, appPickerManager)
	})
	mux.HandlePrefix("browser.", appPickerHandler)
	mux.HandlePrefix("apppicker.", appPickerHandler)

	mux.HandlePrefix("cups.", requestHandler(func(conn *ipc.ConnWriter, req ipc.Request) {
		mgr, err := ensureCupsManager()
		if err != nil {
			models.RespondError(conn, req.ID, "CUPS manager not initialized")
			return
		}
		cups.HandleRequest(conn, req, mgr)
	}))

	mux.HandlePrefix("tailscale.", requestHandler(func(conn *ipc.ConnWriter, req ipc.Request) {
		if tailscaleManager == nil {
			models.RespondError(conn, req.ID, "Tailscale not available")
			return
		}
		tailscale.HandleRequest(conn, req, tailscaleManager)
	}))

	mux.HandlePrefix("brightness.", requestHandler(func(conn *ipc.ConnWriter, req ipc.Request) {
		if brightnessManager == nil {
			models.RespondError(conn, req.ID, "brightness manager not initialized")
			return
		}
		brightness.HandleRequest(conn, req, brightnessManager)
	}))

	mux.HandlePrefix("wlroutput.", requestHandler(func(conn *ipc.ConnWriter, req ipc.Request) {
		if wlrOutputManager == nil {
			models.RespondError(conn, req.ID, "wlroutput manager not initialized")
			return
		}
		wlroutput.HandleRequest(conn, req, wlrOutputManager)
	}))

	mux.HandlePrefix("evdev.", requestHandler(func(conn *ipc.ConnWriter, req ipc.Request) {
		if evdevManager == nil {
			models.RespondError(conn, req.ID, "evdev manager not initialized")
			return
		}
		evdev.HandleRequest(conn, req, evdevManager)
	}))

	mux.HandlePrefix("dbus.", requestHandler(func(conn *ipc.ConnWriter, req ipc.Request) {
		if dbusManager == nil {
			models.RespondError(conn, req.ID, "dbus manager not initialized")
			return
		}
		serverDbus.HandleRequest(conn, req, dbusManager, dbusClientID)
	}))

	mux.HandlePrefix("clipboard.", requestHandler(func(conn *ipc.ConnWriter, req ipc.Request) {
		if clipboardManager == nil {
			models.RespondError(conn, req.ID, "clipboard manager not initialized")
			return
		}
		clipboard.HandleRequest(conn, req, clipboardManager)
	}))

	mux.HandlePrefix("location.", requestHandler(func(conn *ipc.ConnWriter, req ipc.Request) {
		if locationManager == nil {
			models.RespondError(conn, req.ID, "location manager not initialized")
			return
		}
		location.HandleRequest(conn, req, locationManager)
	}))

	mux.HandlePrefix("notify.", requestHandler(func(conn *ipc.ConnWriter, req ipc.Request) {
		if notifyActionsManager == nil {
			models.RespondError(conn, req.ID, "notification action manager not initialized")
			return
		}
		notifyactions.HandleRequest(conn, req, notifyActionsManager)
	}))

	mux.HandlePrefix("sysupdate.", requestHandler(func(conn *ipc.ConnWriter, req ipc.Request) {
		if sysUpdateManager == nil {
			models.RespondError(conn, req.ID, "sysupdate manager not initialized")
			return
		}
		sysupdate.HandleRequest(conn, req, sysUpdateManager)
	}))

	mux.HandlePrefix("", requestHandler(func(conn *ipc.ConnWriter, req ipc.Request) {
		models.RespondError(conn, req.ID, fmt.Sprintf("unknown method: %s", req.Method))
	}))
	return mux
}

func handleClipboardSetConfig(conn *ipc.ConnWriter, req ipc.Request) {
	cfg := clipboard.LoadConfig()

	if v, ok := models.Get[float64](req, "maxHistory"); ok {
		cfg.MaxHistory = int(v)
	}
	if v, ok := models.Get[float64](req, "maxEntrySize"); ok {
		cfg.MaxEntrySize = int64(v)
	}
	if v, ok := models.Get[float64](req, "autoClearDays"); ok {
		cfg.AutoClearDays = int(v)
	}
	if v, ok := models.Get[bool](req, "clearAtStartup"); ok {
		cfg.ClearAtStartup = v
	}
	if v, ok := models.Get[bool](req, "disabled"); ok {
		cfg.Disabled = v
	}
	if v, ok := models.Get[float64](req, "maxPinned"); ok {
		cfg.MaxPinned = int(v)
	}

	if err := clipboard.SaveConfig(cfg); err != nil {
		models.RespondError(conn, req.ID, err.Error())
		return
	}

	models.Respond(conn, req.ID, models.SuccessResult{Success: true, Message: "config updated"})
}
