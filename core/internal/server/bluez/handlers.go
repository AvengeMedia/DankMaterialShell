package bluez

import (
	"fmt"

	"github.com/AvengeMedia/DankMaterialShell/core/internal/server/models"
	"github.com/AvengeMedia/dankgo/ipc/params"
)

type PoweredResult struct {
	Success bool `json:"success"`
	Powered bool `json:"powered"`
}

type BluetoothEvent struct {
	Type string         `json:"type"`
	Data BluetoothState `json:"data"`
}

func HandleRequest(conn *models.Conn, req models.Request, manager *Manager) {
	switch req.Method {
	case "bluetooth.getState":
		handleGetState(conn, req, manager)
	case "bluetooth.startDiscovery":
		handleStartDiscovery(conn, req, manager)
	case "bluetooth.stopDiscovery":
		handleStopDiscovery(conn, req, manager)
	case "bluetooth.setPowered":
		handleSetPowered(conn, req, manager)
	case "bluetooth.togglePowered":
		handleTogglePowered(conn, req, manager)
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

func handleGetState(conn *models.Conn, req models.Request, manager *Manager) {
	models.Respond(conn, req.ID, manager.GetState())
}

func handleStartDiscovery(conn *models.Conn, req models.Request, manager *Manager) {
	if err := manager.StartDiscovery(params.StringOpt(req.Params, "adapter", "")); err != nil {
		models.RespondError(conn, req.ID, err.Error())
		return
	}
	models.Respond(conn, req.ID, models.SuccessResult{Success: true, Message: "discovery started"})
}

func handleStopDiscovery(conn *models.Conn, req models.Request, manager *Manager) {
	if err := manager.StopDiscovery(params.StringOpt(req.Params, "adapter", "")); err != nil {
		models.RespondError(conn, req.ID, err.Error())
		return
	}
	models.Respond(conn, req.ID, models.SuccessResult{Success: true, Message: "discovery stopped"})
}

func handleSetPowered(conn *models.Conn, req models.Request, manager *Manager) {
	powered, err := params.Bool(req.Params, "powered")
	if err != nil {
		models.RespondError(conn, req.ID, err.Error())
		return
	}

	if err := manager.SetPowered(params.StringOpt(req.Params, "adapter", ""), powered); err != nil {
		models.RespondError(conn, req.ID, err.Error())
		return
	}

	models.Respond(conn, req.ID, models.SuccessResult{Success: true, Message: "powered state updated"})
}

func handleTogglePowered(conn *models.Conn, req models.Request, manager *Manager) {
	powered, err := manager.TogglePowered(params.StringOpt(req.Params, "adapter", ""))
	if err != nil {
		models.RespondError(conn, req.ID, err.Error())
		return
	}

	models.Respond(conn, req.ID, PoweredResult{Success: true, Powered: powered})
}

func handlePairDevice(conn *models.Conn, req models.Request, manager *Manager) {
	devicePath, err := params.String(req.Params, "device")
	if err != nil {
		models.RespondError(conn, req.ID, err.Error())
		return
	}

	if err := manager.PairDevice(devicePath); err != nil {
		models.RespondError(conn, req.ID, err.Error())
		return
	}

	models.Respond(conn, req.ID, models.SuccessResult{Success: true, Message: "pairing initiated"})
}

func handleConnectDevice(conn *models.Conn, req models.Request, manager *Manager) {
	devicePath, err := params.String(req.Params, "device")
	if err != nil {
		models.RespondError(conn, req.ID, err.Error())
		return
	}

	if err := manager.ConnectDevice(devicePath); err != nil {
		models.RespondError(conn, req.ID, err.Error())
		return
	}

	models.Respond(conn, req.ID, models.SuccessResult{Success: true, Message: "connecting"})
}

func handleDisconnectDevice(conn *models.Conn, req models.Request, manager *Manager) {
	devicePath, err := params.String(req.Params, "device")
	if err != nil {
		models.RespondError(conn, req.ID, err.Error())
		return
	}

	if err := manager.DisconnectDevice(devicePath); err != nil {
		models.RespondError(conn, req.ID, err.Error())
		return
	}

	models.Respond(conn, req.ID, models.SuccessResult{Success: true, Message: "disconnected"})
}

func handleRemoveDevice(conn *models.Conn, req models.Request, manager *Manager) {
	devicePath, err := params.String(req.Params, "device")
	if err != nil {
		models.RespondError(conn, req.ID, err.Error())
		return
	}

	if err := manager.RemoveDevice(devicePath); err != nil {
		models.RespondError(conn, req.ID, err.Error())
		return
	}

	models.Respond(conn, req.ID, models.SuccessResult{Success: true, Message: "device removed"})
}

func handleTrustDevice(conn *models.Conn, req models.Request, manager *Manager) {
	devicePath, err := params.String(req.Params, "device")
	if err != nil {
		models.RespondError(conn, req.ID, err.Error())
		return
	}

	if err := manager.TrustDevice(devicePath, true); err != nil {
		models.RespondError(conn, req.ID, err.Error())
		return
	}

	models.Respond(conn, req.ID, models.SuccessResult{Success: true, Message: "device trusted"})
}

func handleUntrustDevice(conn *models.Conn, req models.Request, manager *Manager) {
	devicePath, err := params.String(req.Params, "device")
	if err != nil {
		models.RespondError(conn, req.ID, err.Error())
		return
	}

	if err := manager.TrustDevice(devicePath, false); err != nil {
		models.RespondError(conn, req.ID, err.Error())
		return
	}

	models.Respond(conn, req.ID, models.SuccessResult{Success: true, Message: "device untrusted"})
}

func handlePairingSubmit(conn *models.Conn, req models.Request, manager *Manager) {
	token, err := params.String(req.Params, "token")
	if err != nil {
		models.RespondError(conn, req.ID, err.Error())
		return
	}

	secrets := params.StringMapOpt(req.Params, "secrets")
	accept := params.BoolOpt(req.Params, "accept", false)

	if err := manager.SubmitPairing(token, secrets, accept); err != nil {
		models.RespondError(conn, req.ID, err.Error())
		return
	}

	models.Respond(conn, req.ID, models.SuccessResult{Success: true, Message: "pairing response submitted"})
}

func handlePairingCancel(conn *models.Conn, req models.Request, manager *Manager) {
	token, err := params.String(req.Params, "token")
	if err != nil {
		models.RespondError(conn, req.ID, err.Error())
		return
	}

	if err := manager.CancelPairing(token); err != nil {
		models.RespondError(conn, req.ID, err.Error())
		return
	}

	models.Respond(conn, req.ID, models.SuccessResult{Success: true, Message: "pairing cancelled"})
}

func handleSubscribe(conn *models.Conn, req models.Request, manager *Manager) {
	clientID := fmt.Sprintf("client-%p", conn)
	stateChan := manager.Subscribe(clientID)
	defer manager.Unsubscribe(clientID)

	initialState := manager.GetState()
	event := BluetoothEvent{
		Type: "state_changed",
		Data: initialState,
	}

	if err := conn.WriteResponse(models.Response[BluetoothEvent]{
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
		if err := conn.WriteResponse(models.Response[BluetoothEvent]{
			Result: &event,
		}); err != nil {
			return
		}
	}
}
