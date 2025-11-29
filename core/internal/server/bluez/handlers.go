package bluez

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

type BluetoothEvent struct {
	Type string         `json:"type"`
	Data BluetoothState `json:"data"`
}

func HandleRequest(conn net.Conn, req Request, manager *Manager) {
	switch req.Method {
	case "bluetooth.getState":
		handleGetState(conn, req, manager)
	case "bluetooth.startDiscovery":
		handleStartDiscovery(conn, req, manager)
	case "bluetooth.stopDiscovery":
		handleStopDiscovery(conn, req, manager)
	case "bluetooth.setPowered":
		handleSetPowered(conn, req, manager)
	case "bluetooth.pair":
		handlePairDevice(conn, req, manager)
	case "bluetooth.connect":
		handleConnectDevice(conn, req, manager)
	case "bluetooth.disconnect":
		handleDisconnectDevice(conn, req, manager)
	case "bluetooth.remove":
		handleRemoveDevice(conn, req, manager)
	case "bluetooth.trust":
		handleTrustDevice(conn, req, manager)
	case "bluetooth.untrust":
		handleUntrustDevice(conn, req, manager)
	case "bluetooth.subscribe":
		handleSubscribe(conn, req, manager)
	case "bluetooth.pairing.submit":
		handlePairingSubmit(conn, req, manager)
	case "bluetooth.pairing.cancel":
		handlePairingCancel(conn, req, manager)
	default:
		models.RespondError(conn, req.ID, fmt.Sprintf("unknown method: %s", req.Method))
	}
}

func handleGetState(conn net.Conn, req Request, manager *Manager) {
	state := manager.GetState()
	models.Respond(conn, req.ID, state)
}

func handleStartDiscovery(conn net.Conn, req Request, manager *Manager) {
	if err := manager.StartDiscovery(); err != nil {
		models.RespondError(conn, req.ID, err.Error())
		return
	}
	models.Respond(conn, req.ID, SuccessResult{Success: true, Message: "discovery started"})
}

func handleStopDiscovery(conn net.Conn, req Request, manager *Manager) {
	if err := manager.StopDiscovery(); err != nil {
		models.RespondError(conn, req.ID, err.Error())
		return
	}
	models.Respond(conn, req.ID, SuccessResult{Success: true, Message: "discovery stopped"})
}

func handleSetPowered(conn net.Conn, req Request, manager *Manager) {
	powered, ok := req.Params["powered"].(bool)
	if !ok {
		models.RespondError(conn, req.ID, "missing or invalid 'powered' parameter")
		return
	}

	if err := manager.SetPowered(powered); err != nil {
		models.RespondError(conn, req.ID, err.Error())
		return
	}

	models.Respond(conn, req.ID, SuccessResult{Success: true, Message: "powered state updated"})
}

func handlePairDevice(conn net.Conn, req Request, manager *Manager) {
	devicePath, ok := req.Params["device"].(string)
	if !ok {
		models.RespondError(conn, req.ID, "missing or invalid 'device' parameter")
		return
	}

	if err := manager.PairDevice(devicePath); err != nil {
		models.RespondError(conn, req.ID, err.Error())
		return
	}

	models.Respond(conn, req.ID, SuccessResult{Success: true, Message: "pairing initiated"})
}

func handleConnectDevice(conn net.Conn, req Request, manager *Manager) {
	devicePath, ok := req.Params["device"].(string)
	if !ok {
		models.RespondError(conn, req.ID, "missing or invalid 'device' parameter")
		return
	}

	if err := manager.ConnectDevice(devicePath); err != nil {
		models.RespondError(conn, req.ID, err.Error())
		return
	}

	models.Respond(conn, req.ID, SuccessResult{Success: true, Message: "connecting"})
}

func handleDisconnectDevice(conn net.Conn, req Request, manager *Manager) {
	devicePath, ok := req.Params["device"].(string)
	if !ok {
		models.RespondError(conn, req.ID, "missing or invalid 'device' parameter")
		return
	}

	if err := manager.DisconnectDevice(devicePath); err != nil {
		models.RespondError(conn, req.ID, err.Error())
		return
	}

	models.Respond(conn, req.ID, SuccessResult{Success: true, Message: "disconnected"})
}

func handleRemoveDevice(conn net.Conn, req Request, manager *Manager) {
	devicePath, ok := req.Params["device"].(string)
	if !ok {
		models.RespondError(conn, req.ID, "missing or invalid 'device' parameter")
		return
	}

	if err := manager.RemoveDevice(devicePath); err != nil {
		models.RespondError(conn, req.ID, err.Error())
		return
	}

	models.Respond(conn, req.ID, SuccessResult{Success: true, Message: "device removed"})
}

func handleTrustDevice(conn net.Conn, req Request, manager *Manager) {
	devicePath, ok := req.Params["device"].(string)
	if !ok {
		models.RespondError(conn, req.ID, "missing or invalid 'device' parameter")
		return
	}

	if err := manager.TrustDevice(devicePath, true); err != nil {
		models.RespondError(conn, req.ID, err.Error())
		return
	}

	models.Respond(conn, req.ID, SuccessResult{Success: true, Message: "device trusted"})
}

func handleUntrustDevice(conn net.Conn, req Request, manager *Manager) {
	devicePath, ok := req.Params["device"].(string)
	if !ok {
		models.RespondError(conn, req.ID, "missing or invalid 'device' parameter")
		return
	}

	if err := manager.TrustDevice(devicePath, false); err != nil {
		models.RespondError(conn, req.ID, err.Error())
		return
	}

	models.Respond(conn, req.ID, SuccessResult{Success: true, Message: "device untrusted"})
}

func handlePairingSubmit(conn net.Conn, req Request, manager *Manager) {
	token, ok := req.Params["token"].(string)
	if !ok {
		models.RespondError(conn, req.ID, "missing or invalid 'token' parameter")
		return
	}

	secretsRaw, ok := req.Params["secrets"].(map[string]any)
	secrets := make(map[string]string)
	if ok {
		for k, v := range secretsRaw {
			if str, ok := v.(string); ok {
				secrets[k] = str
			}
		}
	}

	accept := false
	if acceptParam, ok := req.Params["accept"].(bool); ok {
		accept = acceptParam
	}

	if err := manager.SubmitPairing(token, secrets, accept); err != nil {
		models.RespondError(conn, req.ID, err.Error())
		return
	}

	models.Respond(conn, req.ID, SuccessResult{Success: true, Message: "pairing response submitted"})
}

func handlePairingCancel(conn net.Conn, req Request, manager *Manager) {
	token, ok := req.Params["token"].(string)
	if !ok {
		models.RespondError(conn, req.ID, "missing or invalid 'token' parameter")
		return
	}

	if err := manager.CancelPairing(token); err != nil {
		models.RespondError(conn, req.ID, err.Error())
		return
	}

	models.Respond(conn, req.ID, SuccessResult{Success: true, Message: "pairing cancelled"})
}

func handleSubscribe(conn net.Conn, req Request, manager *Manager) {
	clientID := fmt.Sprintf("client-%p", conn)
	stateChan := manager.Subscribe(clientID)
	defer manager.Unsubscribe(clientID)

	initialState := manager.GetState()
	event := BluetoothEvent{
		Type: "state_changed",
		Data: initialState,
	}

	if err := json.NewEncoder(conn).Encode(models.Response[BluetoothEvent]{
		ID:     req.ID,
		Result: &event,
	}); err != nil {
		return
	}

	for state := range stateChan {
		event := BluetoothEvent{
			Type: "state_changed",
			Data: state,
		}
		if err := json.NewEncoder(conn).Encode(models.Response[BluetoothEvent]{
			Result: &event,
		}); err != nil {
			return
		}
	}
}
