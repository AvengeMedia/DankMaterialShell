package dwl

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
		models.RespondError(conn, req.ID, "dwl manager not initialized")
		return
	}

	switch req.Method {
	case "dwl.getState":
		handleGetState(conn, req, manager)
	case "dwl.setTags":
		handleSetTags(conn, req, manager)
	case "dwl.setClientTags":
		handleSetClientTags(conn, req, manager)
	case "dwl.setLayout":
		handleSetLayout(conn, req, manager)
	case "dwl.subscribe":
		handleSubscribe(conn, req, manager)
	default:
		models.RespondError(conn, req.ID, fmt.Sprintf("unknown method: %s", req.Method))
	}
}

func handleGetState(conn net.Conn, req Request, manager *Manager) {
	state := manager.GetState()
	models.Respond(conn, req.ID, state)
}

func handleSetTags(conn net.Conn, req Request, manager *Manager) {
	output, ok := req.Params["output"].(string)
	if !ok {
		models.RespondError(conn, req.ID, "missing or invalid 'output' parameter")
		return
	}

	tagmask, ok := req.Params["tagmask"].(float64)
	if !ok {
		models.RespondError(conn, req.ID, "missing or invalid 'tagmask' parameter")
		return
	}

	toggleTagset, ok := req.Params["toggleTagset"].(float64)
	if !ok {
		models.RespondError(conn, req.ID, "missing or invalid 'toggleTagset' parameter")
		return
	}

	if err := manager.SetTags(output, uint32(tagmask), uint32(toggleTagset)); err != nil {
		models.RespondError(conn, req.ID, err.Error())
		return
	}

	models.Respond(conn, req.ID, SuccessResult{Success: true, Message: "tags set"})
}

func handleSetClientTags(conn net.Conn, req Request, manager *Manager) {
	output, ok := req.Params["output"].(string)
	if !ok {
		models.RespondError(conn, req.ID, "missing or invalid 'output' parameter")
		return
	}

	andTags, ok := req.Params["andTags"].(float64)
	if !ok {
		models.RespondError(conn, req.ID, "missing or invalid 'andTags' parameter")
		return
	}

	xorTags, ok := req.Params["xorTags"].(float64)
	if !ok {
		models.RespondError(conn, req.ID, "missing or invalid 'xorTags' parameter")
		return
	}

	if err := manager.SetClientTags(output, uint32(andTags), uint32(xorTags)); err != nil {
		models.RespondError(conn, req.ID, err.Error())
		return
	}

	models.Respond(conn, req.ID, SuccessResult{Success: true, Message: "client tags set"})
}

func handleSetLayout(conn net.Conn, req Request, manager *Manager) {
	output, ok := req.Params["output"].(string)
	if !ok {
		models.RespondError(conn, req.ID, "missing or invalid 'output' parameter")
		return
	}

	index, ok := req.Params["index"].(float64)
	if !ok {
		models.RespondError(conn, req.ID, "missing or invalid 'index' parameter")
		return
	}

	if err := manager.SetLayout(output, uint32(index)); err != nil {
		models.RespondError(conn, req.ID, err.Error())
		return
	}

	models.Respond(conn, req.ID, SuccessResult{Success: true, Message: "layout set"})
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
