package tailscale

import (
	"encoding/json"
	"fmt"
	"net"

	"github.com/AvengeMedia/DankMaterialShell/core/internal/server/models"
)

// TailscaleEvent wraps a state update for streaming to IPC subscribers.
type TailscaleEvent struct {
	Type string         `json:"type"`
	Data TailscaleState `json:"data"`
}

// HandleRequest routes an IPC request to the appropriate handler.
func HandleRequest(conn net.Conn, req models.Request, manager *Manager) {
	switch req.Method {
	case "tailscale.subscribe":
		handleSubscribe(conn, req, manager)
	case "tailscale.getStatus":
		handleGetStatus(conn, req, manager)
	case "tailscale.refresh":
		handleRefresh(conn, req, manager)
	default:
		models.RespondError(conn, req.ID, fmt.Sprintf("unknown method: %s", req.Method))
	}
}

func handleGetStatus(conn net.Conn, req models.Request, manager *Manager) {
	state := manager.GetState()
	models.Respond(conn, req.ID, state)
}

func handleRefresh(conn net.Conn, req models.Request, manager *Manager) {
	manager.RefreshState()
	models.Respond(conn, req.ID, models.SuccessResult{Success: true, Message: "refreshed"})
}

func handleSubscribe(conn net.Conn, req models.Request, manager *Manager) {
	clientID := fmt.Sprintf("client-%p", conn)
	stateChan := manager.Subscribe(clientID)
	defer manager.Unsubscribe(clientID)

	initialState := manager.GetState()
	event := TailscaleEvent{
		Type: "state_changed",
		Data: initialState,
	}

	if err := json.NewEncoder(conn).Encode(models.Response[TailscaleEvent]{
		ID:     req.ID,
		Result: &event,
	}); err != nil {
		return
	}

	for state := range stateChan {
		event := TailscaleEvent{
			Type: "state_changed",
			Data: state,
		}
		if err := json.NewEncoder(conn).Encode(models.Response[TailscaleEvent]{
			Result: &event,
		}); err != nil {
			return
		}
	}
}
