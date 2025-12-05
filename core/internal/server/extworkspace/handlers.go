package extworkspace

import (
	"encoding/json"
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
}

func HandleRequest(conn net.Conn, req Request, manager *Manager) {
	if manager == nil {
		models.RespondError(conn, req.ID, "extworkspace manager not initialized")
		return
	}

	switch req.Method {
	case "extworkspace.getState":
		handleGetState(conn, req, manager)
	case "extworkspace.activateWorkspace":
		handleActivateWorkspace(conn, req, manager)
	case "extworkspace.deactivateWorkspace":
		handleDeactivateWorkspace(conn, req, manager)
	case "extworkspace.removeWorkspace":
		handleRemoveWorkspace(conn, req, manager)
	case "extworkspace.createWorkspace":
		handleCreateWorkspace(conn, req, manager)
	case "extworkspace.subscribe":
		handleSubscribe(conn, req, manager)
	default:
		models.RespondError(conn, req.ID, fmt.Sprintf("unknown method: %s", req.Method))
	}
}

func handleGetState(conn net.Conn, req Request, manager *Manager) {
	state := manager.GetState()
	models.Respond(conn, req.ID, state)
}

func handleActivateWorkspace(conn net.Conn, req Request, manager *Manager) {
	groupID, ok := req.Params["groupID"].(string)
	if !ok {
		groupID = ""
	}

	workspaceID, ok := req.Params["workspaceID"].(string)
	if !ok {
		models.RespondError(conn, req.ID, "missing or invalid 'workspaceID' parameter")
		return
	}

	if err := manager.ActivateWorkspace(groupID, workspaceID); err != nil {
		models.RespondError(conn, req.ID, err.Error())
		return
	}

	models.Respond(conn, req.ID, SuccessResult{Success: true, Message: "workspace activated"})
}

func handleDeactivateWorkspace(conn net.Conn, req Request, manager *Manager) {
	groupID, ok := req.Params["groupID"].(string)
	if !ok {
		groupID = ""
	}

	workspaceID, ok := req.Params["workspaceID"].(string)
	if !ok {
		models.RespondError(conn, req.ID, "missing or invalid 'workspaceID' parameter")
		return
	}

	if err := manager.DeactivateWorkspace(groupID, workspaceID); err != nil {
		models.RespondError(conn, req.ID, err.Error())
		return
	}

	models.Respond(conn, req.ID, SuccessResult{Success: true, Message: "workspace deactivated"})
}

func handleRemoveWorkspace(conn net.Conn, req Request, manager *Manager) {
	groupID, ok := req.Params["groupID"].(string)
	if !ok {
		groupID = ""
	}

	workspaceID, ok := req.Params["workspaceID"].(string)
	if !ok {
		models.RespondError(conn, req.ID, "missing or invalid 'workspaceID' parameter")
		return
	}

	if err := manager.RemoveWorkspace(groupID, workspaceID); err != nil {
		models.RespondError(conn, req.ID, err.Error())
		return
	}

	models.Respond(conn, req.ID, SuccessResult{Success: true, Message: "workspace removed"})
}

func handleCreateWorkspace(conn net.Conn, req Request, manager *Manager) {
	groupID, ok := req.Params["groupID"].(string)
	if !ok {
		models.RespondError(conn, req.ID, "missing or invalid 'groupID' parameter")
		return
	}

	workspaceName, ok := req.Params["name"].(string)
	if !ok {
		models.RespondError(conn, req.ID, "missing or invalid 'name' parameter")
		return
	}

	if err := manager.CreateWorkspace(groupID, workspaceName); err != nil {
		models.RespondError(conn, req.ID, err.Error())
		return
	}

	models.Respond(conn, req.ID, SuccessResult{Success: true, Message: "workspace create requested"})
}

func handleSubscribe(conn net.Conn, req Request, manager *Manager) {
	clientID := fmt.Sprintf("client-%p", conn)
	stateChan := manager.Subscribe(clientID)
	defer manager.Unsubscribe(clientID)

	initialState := manager.GetState()
	if err := json.NewEncoder(conn).Encode(models.Response[State]{
		ID:     req.ID,
		Result: &initialState,
	}); err != nil {
		return
	}

	for state := range stateChan {
		if err := json.NewEncoder(conn).Encode(models.Response[State]{
			Result: &state,
		}); err != nil {
			return
		}
	}
}
