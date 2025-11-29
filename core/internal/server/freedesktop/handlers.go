package freedesktop

import (
	"fmt"
	"net"

	"github.com/AvengeMedia/DankMaterialShell/core/internal/server/models"
)

type Request struct {
	ID     int            `json:"id,omitempty"`
	Method string         `json:"method"`
	Params map[string]any `json:"params,omitempty"`
}

type SuccessResult struct {
	Success bool   `json:"success"`
	Message string `json:"message"`
	Value   string `json:"value,omitempty"`
}

func HandleRequest(conn net.Conn, req Request, manager *Manager) {
	switch req.Method {
	case "freedesktop.getState":
		handleGetState(conn, req, manager)
	case "freedesktop.accounts.setIconFile":
		handleSetIconFile(conn, req, manager)
	case "freedesktop.accounts.setRealName":
		handleSetRealName(conn, req, manager)
	case "freedesktop.accounts.setEmail":
		handleSetEmail(conn, req, manager)
	case "freedesktop.accounts.setLanguage":
		handleSetLanguage(conn, req, manager)
	case "freedesktop.accounts.setLocation":
		handleSetLocation(conn, req, manager)
	case "freedesktop.accounts.getUserIconFile":
		handleGetUserIconFile(conn, req, manager)
	case "freedesktop.settings.getColorScheme":
		handleGetColorScheme(conn, req, manager)
	case "freedesktop.settings.setIconTheme":
		handleSetIconTheme(conn, req, manager)
	default:
		models.RespondError(conn, req.ID, fmt.Sprintf("unknown method: %s", req.Method))
	}
}

func handleGetState(conn net.Conn, req Request, manager *Manager) {
	state := manager.GetState()
	models.Respond(conn, req.ID, state)
}

func handleSetIconFile(conn net.Conn, req Request, manager *Manager) {
	iconPath, ok := req.Params["path"].(string)
	if !ok {
		models.RespondError(conn, req.ID, "missing or invalid 'path' parameter")
		return
	}

	if err := manager.SetIconFile(iconPath); err != nil {
		models.RespondError(conn, req.ID, err.Error())
		return
	}

	models.Respond(conn, req.ID, SuccessResult{Success: true, Message: "icon file set"})
}

func handleSetRealName(conn net.Conn, req Request, manager *Manager) {
	name, ok := req.Params["name"].(string)
	if !ok {
		models.RespondError(conn, req.ID, "missing or invalid 'name' parameter")
		return
	}

	if err := manager.SetRealName(name); err != nil {
		models.RespondError(conn, req.ID, err.Error())
		return
	}

	models.Respond(conn, req.ID, SuccessResult{Success: true, Message: "real name set"})
}

func handleSetEmail(conn net.Conn, req Request, manager *Manager) {
	email, ok := req.Params["email"].(string)
	if !ok {
		models.RespondError(conn, req.ID, "missing or invalid 'email' parameter")
		return
	}

	if err := manager.SetEmail(email); err != nil {
		models.RespondError(conn, req.ID, err.Error())
		return
	}

	models.Respond(conn, req.ID, SuccessResult{Success: true, Message: "email set"})
}

func handleSetLanguage(conn net.Conn, req Request, manager *Manager) {
	language, ok := req.Params["language"].(string)
	if !ok {
		models.RespondError(conn, req.ID, "missing or invalid 'language' parameter")
		return
	}

	if err := manager.SetLanguage(language); err != nil {
		models.RespondError(conn, req.ID, err.Error())
		return
	}

	models.Respond(conn, req.ID, SuccessResult{Success: true, Message: "language set"})
}

func handleSetLocation(conn net.Conn, req Request, manager *Manager) {
	location, ok := req.Params["location"].(string)
	if !ok {
		models.RespondError(conn, req.ID, "missing or invalid 'location' parameter")
		return
	}

	if err := manager.SetLocation(location); err != nil {
		models.RespondError(conn, req.ID, err.Error())
		return
	}

	models.Respond(conn, req.ID, SuccessResult{Success: true, Message: "location set"})
}

func handleGetUserIconFile(conn net.Conn, req Request, manager *Manager) {
	username, ok := req.Params["username"].(string)
	if !ok {
		models.RespondError(conn, req.ID, "missing or invalid 'username' parameter")
		return
	}

	iconFile, err := manager.GetUserIconFile(username)
	if err != nil {
		models.RespondError(conn, req.ID, err.Error())
		return
	}

	models.Respond(conn, req.ID, SuccessResult{Success: true, Value: iconFile})
}

func handleGetColorScheme(conn net.Conn, req Request, manager *Manager) {
	if err := manager.updateSettingsState(); err != nil {
		models.RespondError(conn, req.ID, err.Error())
		return
	}

	state := manager.GetState()
	models.Respond(conn, req.ID, map[string]uint32{"colorScheme": state.Settings.ColorScheme})
}

func handleSetIconTheme(conn net.Conn, req Request, manager *Manager) {
	iconTheme, ok := req.Params["iconTheme"].(string)
	if !ok {
		models.RespondError(conn, req.ID, "missing or invalid 'iconTheme' parameter")
		return
	}

	if err := manager.SetIconTheme(iconTheme); err != nil {
		models.RespondError(conn, req.ID, err.Error())
		return
	}

	models.Respond(conn, req.ID, SuccessResult{Success: true, Message: "icon theme set"})
}
