package location

import (
	"encoding/json"
	"fmt"
	"net"

	"github.com/AvengeMedia/DankMaterialShell/core/internal/server/models"
)

type LocationEvent struct {
	Type string `json:"type"`
	Data State  `json:"data"`
}

func HandleRequest(conn net.Conn, req models.Request, manager *Manager) {
	switch req.Method {
	case "location.getState":
		handleGetState(conn, req, manager)
	case "location.subscribe":
		handleSubscribe(conn, req, manager)

	default:
		models.RespondError(conn, req.ID, fmt.Sprintf("unknown method: %s", req.Method))
	}
}

func handleGetState(conn net.Conn, req models.Request, manager *Manager) {
	models.Respond(conn, req.ID, manager.GetState())
}

func handleSubscribe(conn net.Conn, req models.Request, manager *Manager) {
	clientID := fmt.Sprintf("client-%p", conn)
	stateChan := manager.Subscribe(clientID)
	defer manager.Unsubscribe(clientID)

	initialState := manager.GetState()
	event := LocationEvent{
		Type: "state_changed",
		Data: initialState,
	}

	if err := json.NewEncoder(conn).Encode(models.Response[LocationEvent]{
		ID:     req.ID,
		Result: &event,
	}); err != nil {
		return
	}

	for state := range stateChan {
		event := LocationEvent{
			Type: "state_changed",
			Data: state,
		}
		if err := json.NewEncoder(conn).Encode(models.Response[LocationEvent]{
			Result: &event,
		}); err != nil {
			return
		}
	}
}
