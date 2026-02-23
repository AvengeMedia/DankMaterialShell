package network

import (
	"encoding/json"
	"fmt"
	"net"
	"os"

	"github.com/AvengeMedia/DankMaterialShell/core/internal/log"
	"github.com/AvengeMedia/DankMaterialShell/core/internal/server/models"
	"github.com/AvengeMedia/DankMaterialShell/core/internal/server/params"
)

func HandleRequest(conn net.Conn, req models.Request, manager *Manager) {
	switch req.Method {
	case "network.getState":
		handleGetState(conn, req, manager)
	case "network.wifi.scan":
		handleScanWiFi(conn, req, manager)
	case "network.wifi.networks":
		handleGetWiFiNetworks(conn, req, manager)
	case "network.wifi.connect":
		handleConnectWiFi(conn, req, manager)
	case "network.wifi.disconnect":
		handleDisconnectWiFi(conn, req, manager)
	case "network.wifi.forget":
		handleForgetWiFi(conn, req, manager)
	case "network.wifi.toggle":
		handleToggleWiFi(conn, req, manager)
	case "network.wifi.enable":
		handleEnableWiFi(conn, req, manager)
	case "network.wifi.disable":
		handleDisableWiFi(conn, req, manager)
	case "network.ethernet.connect.config":
		handleConnectEthernetSpecificConfig(conn, req, manager)
	case "network.ethernet.connect":
		handleConnectEthernet(conn, req, manager)
	case "network.ethernet.disconnect":
		handleDisconnectEthernet(conn, req, manager)
	case "network.preference.set":
		handleSetPreference(conn, req, manager)
	case "network.info":
		handleGetNetworkInfo(conn, req, manager)
	case "network.qrcode":
		handleGetNetworkQRCode(conn, req, manager)
	case "network.delete-qrcode":
		handleDeleteQRCode(conn, req, manager)
	case "network.ethernet.info":
		handleGetWiredNetworkInfo(conn, req, manager)
	case "network.subscribe":
		handleSubscribe(conn, req, manager)
	case "network.credentials.submit":
		handleCredentialsSubmit(conn, req, manager)
	case "network.credentials.cancel":
		handleCredentialsCancel(conn, req, manager)
	case "network.vpn.profiles":
		handleListVPNProfiles(conn, req, manager)
	case "network.vpn.active":
		handleListActiveVPN(conn, req, manager)
	case "network.vpn.connect":
		handleConnectVPN(conn, req, manager)
	case "network.vpn.disconnect":
		handleDisconnectVPN(conn, req, manager)
	case "network.vpn.disconnectAll":
		handleDisconnectAllVPN(conn, req, manager)
	case "network.vpn.clearCredentials":
		handleClearVPNCredentials(conn, req, manager)
	case "network.vpn.plugins":
		handleListVPNPlugins(conn, req, manager)
	case "network.vpn.import":
		handleImportVPN(conn, req, manager)
	case "network.vpn.getConfig":
		handleGetVPNConfig(conn, req, manager)
	case "network.vpn.updateConfig":
		handleUpdateVPNConfig(conn, req, manager)
	case "network.vpn.delete":
		handleDeleteVPN(conn, req, manager)
	case "network.vpn.setCredentials":
		handleSetVPNCredentials(conn, req, manager)
	case "network.wifi.setAutoconnect":
		handleSetWiFiAutoconnect(conn, req, manager)
	default:
		models.RespondError(conn, req.ID, fmt.Sprintf("unknown method: %s", req.Method))
	}
}

func handleCredentialsSubmit(conn net.Conn, req models.Request, manager *Manager) {
	token, err := params.String(req.Params, "token")
	if err != nil {
		log.Warnf("handleCredentialsSubmit: missing or invalid token parameter")
		models.RespondError(conn, req.ID, err.Error())
		return
	}

	secrets, err := params.StringMap(req.Params, "secrets")
	if err != nil {
		log.Warnf("handleCredentialsSubmit: missing or invalid secrets parameter")
		models.RespondError(conn, req.ID, err.Error())
		return
	}

	save := params.BoolOpt(req.Params, "save", true)

	if err := manager.SubmitCredentials(token, secrets, save); err != nil {
		log.Warnf("handleCredentialsSubmit: failed to submit credentials: %v", err)
		models.RespondError(conn, req.ID, err.Error())
		return
	}

	log.Infof("handleCredentialsSubmit: credentials submitted successfully")
	models.Respond(conn, req.ID, models.SuccessResult{Success: true, Message: "credentials submitted"})
}

func handleCredentialsCancel(conn net.Conn, req models.Request, manager *Manager) {
	token, err := params.String(req.Params, "token")
	if err != nil {
		models.RespondError(conn, req.ID, err.Error())
		return
	}

	if err := manager.CancelCredentials(token); err != nil {
		models.RespondError(conn, req.ID, err.Error())
		return
	}

	models.Respond(conn, req.ID, models.SuccessResult{Success: true, Message: "credentials cancelled"})
}

func handleGetState(conn net.Conn, req models.Request, manager *Manager) {
	models.Respond(conn, req.ID, manager.GetState())
}

func handleScanWiFi(conn net.Conn, req models.Request, manager *Manager) {
	device := params.StringOpt(req.Params, "device", "")
	var err error
	if device != "" {
		err = manager.ScanWiFiDevice(device)
	} else {
		err = manager.ScanWiFi()
	}
	if err != nil {
		models.RespondError(conn, req.ID, err.Error())
		return
	}
	models.Respond(conn, req.ID, models.SuccessResult{Success: true, Message: "scanning"})
}

func handleGetWiFiNetworks(conn net.Conn, req models.Request, manager *Manager) {
	models.Respond(conn, req.ID, manager.GetWiFiNetworks())
}

func handleConnectWiFi(conn net.Conn, req models.Request, manager *Manager) {
	ssid, err := params.String(req.Params, "ssid")
	if err != nil {
		models.RespondError(conn, req.ID, err.Error())
		return
	}

	var connReq ConnectionRequest
	connReq.SSID = ssid
	connReq.Password = params.StringOpt(req.Params, "password", "")
	connReq.Username = params.StringOpt(req.Params, "username", "")
	connReq.Device = params.StringOpt(req.Params, "device", "")

	if interactive, ok := models.Get[bool](req, "interactive"); ok {
		connReq.Interactive = interactive
	} else {
		state := manager.GetState()
		alreadyConnected := state.WiFiConnected && state.WiFiSSID == ssid

		if alreadyConnected && connReq.Device == "" {
			connReq.Interactive = false
		} else {
			networkInfo, err := manager.GetNetworkInfo(ssid)
			isSaved := err == nil && networkInfo.Saved

			if isSaved {
				connReq.Interactive = false
			} else if err == nil && networkInfo.Secured && connReq.Password == "" && connReq.Username == "" {
				connReq.Interactive = true
			}
		}
	}

	connReq.AnonymousIdentity = params.StringOpt(req.Params, "anonymousIdentity", "")
	connReq.DomainSuffixMatch = params.StringOpt(req.Params, "domainSuffixMatch", "")
	connReq.EAPMethod = params.StringOpt(req.Params, "eapMethod", "")
	connReq.Phase2Auth = params.StringOpt(req.Params, "phase2Auth", "")
	connReq.CACertPath = params.StringOpt(req.Params, "caCertPath", "")
	connReq.ClientCertPath = params.StringOpt(req.Params, "clientCertPath", "")
	connReq.PrivateKeyPath = params.StringOpt(req.Params, "privateKeyPath", "")

	if useSystemCACerts, ok := models.Get[bool](req, "useSystemCACerts"); ok {
		connReq.UseSystemCACerts = &useSystemCACerts
	}

	if err := manager.ConnectWiFi(connReq); err != nil {
		models.RespondError(conn, req.ID, err.Error())
		return
	}

	models.Respond(conn, req.ID, models.SuccessResult{Success: true, Message: "connecting"})
}

func handleDisconnectWiFi(conn net.Conn, req models.Request, manager *Manager) {
	device := params.StringOpt(req.Params, "device", "")
	var err error
	if device != "" {
		err = manager.DisconnectWiFiDevice(device)
	} else {
		err = manager.DisconnectWiFi()
	}
	if err != nil {
		models.RespondError(conn, req.ID, err.Error())
		return
	}
	models.Respond(conn, req.ID, models.SuccessResult{Success: true, Message: "disconnected"})
}

func handleForgetWiFi(conn net.Conn, req models.Request, manager *Manager) {
	ssid, err := params.String(req.Params, "ssid")
	if err != nil {
		models.RespondError(conn, req.ID, err.Error())
		return
	}

	if err := manager.ForgetWiFiNetwork(ssid); err != nil {
		models.RespondError(conn, req.ID, err.Error())
		return
	}

	models.Respond(conn, req.ID, models.SuccessResult{Success: true, Message: "forgotten"})
}

func handleToggleWiFi(conn net.Conn, req models.Request, manager *Manager) {
	if err := manager.ToggleWiFi(); err != nil {
		models.RespondError(conn, req.ID, err.Error())
		return
	}

	state := manager.GetState()
	models.Respond(conn, req.ID, map[string]bool{"enabled": state.WiFiEnabled})
}

func handleEnableWiFi(conn net.Conn, req models.Request, manager *Manager) {
	if err := manager.EnableWiFi(); err != nil {
		models.RespondError(conn, req.ID, err.Error())
		return
	}
	models.Respond(conn, req.ID, map[string]bool{"enabled": true})
}

func handleDisableWiFi(conn net.Conn, req models.Request, manager *Manager) {
	if err := manager.DisableWiFi(); err != nil {
		models.RespondError(conn, req.ID, err.Error())
		return
	}
	models.Respond(conn, req.ID, map[string]bool{"enabled": false})
}

func handleConnectEthernetSpecificConfig(conn net.Conn, req models.Request, manager *Manager) {
	uuid, err := params.String(req.Params, "uuid")
	if err != nil {
		models.RespondError(conn, req.ID, err.Error())
		return
	}
	if err := manager.activateConnection(uuid); err != nil {
		models.RespondError(conn, req.ID, err.Error())
		return
	}
	models.Respond(conn, req.ID, models.SuccessResult{Success: true, Message: "connecting"})
}

func handleConnectEthernet(conn net.Conn, req models.Request, manager *Manager) {
	if err := manager.ConnectEthernet(); err != nil {
		models.RespondError(conn, req.ID, err.Error())
		return
	}
	models.Respond(conn, req.ID, models.SuccessResult{Success: true, Message: "connecting"})
}

func handleDisconnectEthernet(conn net.Conn, req models.Request, manager *Manager) {
	device := params.StringOpt(req.Params, "device", "")
	var err error
	if device != "" {
		err = manager.DisconnectEthernetDevice(device)
	} else {
		err = manager.DisconnectEthernet()
	}
	if err != nil {
		models.RespondError(conn, req.ID, err.Error())
		return
	}
	models.Respond(conn, req.ID, models.SuccessResult{Success: true, Message: "disconnected"})
}

func handleSetPreference(conn net.Conn, req models.Request, manager *Manager) {
	preference, err := params.String(req.Params, "preference")
	if err != nil {
		models.RespondError(conn, req.ID, err.Error())
		return
	}

	if err := manager.SetConnectionPreference(ConnectionPreference(preference)); err != nil {
		models.RespondError(conn, req.ID, err.Error())
		return
	}

	models.Respond(conn, req.ID, map[string]string{"preference": preference})
}

func handleGetNetworkInfo(conn net.Conn, req models.Request, manager *Manager) {
	ssid, err := params.String(req.Params, "ssid")
	if err != nil {
		models.RespondError(conn, req.ID, err.Error())
		return
	}

	network, err := manager.GetNetworkInfoDetailed(ssid)
	if err != nil {
		models.RespondError(conn, req.ID, err.Error())
		return
	}

	models.Respond(conn, req.ID, network)
}

func handleGetNetworkQRCode(conn net.Conn, req models.Request, manager *Manager) {
	ssid, err := params.String(req.Params, "ssid")
	if err != nil {
		models.RespondError(conn, req.ID, err.Error())
		return
	}

	content, err := manager.GetNetworkQRCode(ssid)
	if err != nil {
		models.RespondError(conn, req.ID, err.Error())
		return
	}

	models.Respond(conn, req.ID, content)
}

func handleDeleteQRCode(conn net.Conn, req models.Request, _ *Manager) {
	path, err := params.String(req.Params, "path")
	if err != nil {
		models.RespondError(conn, req.ID, err.Error())
		return
	}

	if !isValidQRCodePath(path) {
		models.RespondError(conn, req.ID, "invalid QR code path")
		return
	}

	if err := os.Remove(path); err != nil {
		models.RespondError(conn, req.ID, err.Error())
		return
	}

	models.Respond(conn, req.ID, models.SuccessResult{Success: true, Message: "QR code file deleted"})
}

func handleGetWiredNetworkInfo(conn net.Conn, req models.Request, manager *Manager) {
	uuid, err := params.String(req.Params, "uuid")
	if err != nil {
		models.RespondError(conn, req.ID, err.Error())
		return
	}

	network, err := manager.GetWiredNetworkInfoDetailed(uuid)
	if err != nil {
		models.RespondError(conn, req.ID, err.Error())
		return
	}

	models.Respond(conn, req.ID, network)
}

func handleSubscribe(conn net.Conn, req models.Request, manager *Manager) {
	clientID := fmt.Sprintf("client-%p", conn)
	stateChan := manager.Subscribe(clientID)
	defer manager.Unsubscribe(clientID)

	initialState := manager.GetState()
	event := NetworkEvent{
		Type: EventStateChanged,
		Data: initialState,
	}
	if err := json.NewEncoder(conn).Encode(models.Response[NetworkEvent]{
		ID:     req.ID,
		Result: &event,
	}); err != nil {
		return
	}

	for state := range stateChan {
		event := NetworkEvent{
			Type: EventStateChanged,
			Data: state,
		}
		if err := json.NewEncoder(conn).Encode(models.Response[NetworkEvent]{
			Result: &event,
		}); err != nil {
			return
		}
	}
}

func handleListVPNProfiles(conn net.Conn, req models.Request, manager *Manager) {
	profiles, err := manager.ListVPNProfiles()
	if err != nil {
		log.Warnf("handleListVPNProfiles: failed to list profiles: %v", err)
		models.RespondError(conn, req.ID, fmt.Sprintf("failed to list VPN profiles: %v", err))
		return
	}

	models.Respond(conn, req.ID, profiles)
}

func handleListActiveVPN(conn net.Conn, req models.Request, manager *Manager) {
	active, err := manager.ListActiveVPN()
	if err != nil {
		log.Warnf("handleListActiveVPN: failed to list active VPNs: %v", err)
		models.RespondError(conn, req.ID, fmt.Sprintf("failed to list active VPNs: %v", err))
		return
	}

	models.Respond(conn, req.ID, active)
}

func handleConnectVPN(conn net.Conn, req models.Request, manager *Manager) {
	uuidOrName, ok := params.StringAlt(req.Params, "uuidOrName", "name", "uuid")
	if !ok {
		log.Warnf("handleConnectVPN: missing uuidOrName/name/uuid parameter")
		models.RespondError(conn, req.ID, "missing 'uuidOrName', 'name', or 'uuid' parameter")
		return
	}

	singleActive := params.BoolOpt(req.Params, "singleActive", true)

	if err := manager.ConnectVPN(uuidOrName, singleActive); err != nil {
		log.Warnf("handleConnectVPN: failed to connect: %v", err)
		models.RespondError(conn, req.ID, fmt.Sprintf("failed to connect VPN: %v", err))
		return
	}

	models.Respond(conn, req.ID, models.SuccessResult{Success: true, Message: "VPN connection initiated"})
}

func handleDisconnectVPN(conn net.Conn, req models.Request, manager *Manager) {
	uuidOrName, ok := params.StringAlt(req.Params, "uuidOrName", "name", "uuid")
	if !ok {
		log.Warnf("handleDisconnectVPN: missing uuidOrName/name/uuid parameter")
		models.RespondError(conn, req.ID, "missing 'uuidOrName', 'name', or 'uuid' parameter")
		return
	}

	if err := manager.DisconnectVPN(uuidOrName); err != nil {
		log.Warnf("handleDisconnectVPN: failed to disconnect: %v", err)
		models.RespondError(conn, req.ID, fmt.Sprintf("failed to disconnect VPN: %v", err))
		return
	}

	models.Respond(conn, req.ID, models.SuccessResult{Success: true, Message: "VPN disconnected"})
}

func handleDisconnectAllVPN(conn net.Conn, req models.Request, manager *Manager) {
	if err := manager.DisconnectAllVPN(); err != nil {
		log.Warnf("handleDisconnectAllVPN: failed: %v", err)
		models.RespondError(conn, req.ID, fmt.Sprintf("failed to disconnect all VPNs: %v", err))
		return
	}

	models.Respond(conn, req.ID, models.SuccessResult{Success: true, Message: "All VPNs disconnected"})
}

func handleClearVPNCredentials(conn net.Conn, req models.Request, manager *Manager) {
	uuidOrName, ok := params.StringAlt(req.Params, "uuid", "name", "uuidOrName")
	if !ok {
		log.Warnf("handleClearVPNCredentials: missing uuidOrName/name/uuid parameter")
		models.RespondError(conn, req.ID, "missing uuidOrName/name/uuid parameter")
		return
	}

	if err := manager.ClearVPNCredentials(uuidOrName); err != nil {
		log.Warnf("handleClearVPNCredentials: failed: %v", err)
		models.RespondError(conn, req.ID, fmt.Sprintf("failed to clear VPN credentials: %v", err))
		return
	}

	models.Respond(conn, req.ID, models.SuccessResult{Success: true, Message: "VPN credentials cleared"})
}

func handleSetWiFiAutoconnect(conn net.Conn, req models.Request, manager *Manager) {
	ssid, err := params.String(req.Params, "ssid")
	if err != nil {
		models.RespondError(conn, req.ID, err.Error())
		return
	}

	autoconnect, err := params.Bool(req.Params, "autoconnect")
	if err != nil {
		models.RespondError(conn, req.ID, err.Error())
		return
	}

	if err := manager.SetWiFiAutoconnect(ssid, autoconnect); err != nil {
		models.RespondError(conn, req.ID, fmt.Sprintf("failed to set autoconnect: %v", err))
		return
	}

	models.Respond(conn, req.ID, models.SuccessResult{Success: true, Message: "autoconnect updated"})
}

func handleListVPNPlugins(conn net.Conn, req models.Request, manager *Manager) {
	plugins, err := manager.ListVPNPlugins()
	if err != nil {
		log.Warnf("handleListVPNPlugins: failed to list plugins: %v", err)
		models.RespondError(conn, req.ID, fmt.Sprintf("failed to list VPN plugins: %v", err))
		return
	}

	models.Respond(conn, req.ID, plugins)
}

func handleImportVPN(conn net.Conn, req models.Request, manager *Manager) {
	filePath, ok := params.StringAlt(req.Params, "file", "path")
	if !ok {
		models.RespondError(conn, req.ID, "missing 'file' or 'path' parameter")
		return
	}

	name := params.StringOpt(req.Params, "name", "")

	result, err := manager.ImportVPN(filePath, name)
	if err != nil {
		log.Warnf("handleImportVPN: failed to import: %v", err)
		models.RespondError(conn, req.ID, fmt.Sprintf("failed to import VPN: %v", err))
		return
	}

	models.Respond(conn, req.ID, result)
}

func handleGetVPNConfig(conn net.Conn, req models.Request, manager *Manager) {
	uuidOrName, ok := params.StringAlt(req.Params, "uuid", "name", "uuidOrName")
	if !ok {
		models.RespondError(conn, req.ID, "missing 'uuid', 'name', or 'uuidOrName' parameter")
		return
	}

	config, err := manager.GetVPNConfig(uuidOrName)
	if err != nil {
		log.Warnf("handleGetVPNConfig: failed to get config: %v", err)
		models.RespondError(conn, req.ID, fmt.Sprintf("failed to get VPN config: %v", err))
		return
	}

	models.Respond(conn, req.ID, config)
}

func handleUpdateVPNConfig(conn net.Conn, req models.Request, manager *Manager) {
	connUUID, err := params.String(req.Params, "uuid")
	if err != nil {
		models.RespondError(conn, req.ID, err.Error())
		return
	}

	updates := make(map[string]any)

	if name, ok := models.Get[string](req, "name"); ok {
		updates["name"] = name
	}
	if autoconnect, ok := models.Get[bool](req, "autoconnect"); ok {
		updates["autoconnect"] = autoconnect
	}
	if data, ok := models.Get[map[string]any](req, "data"); ok {
		updates["data"] = data
	}

	if len(updates) == 0 {
		models.RespondError(conn, req.ID, "no updates provided")
		return
	}

	if err := manager.UpdateVPNConfig(connUUID, updates); err != nil {
		log.Warnf("handleUpdateVPNConfig: failed to update: %v", err)
		models.RespondError(conn, req.ID, fmt.Sprintf("failed to update VPN config: %v", err))
		return
	}

	models.Respond(conn, req.ID, models.SuccessResult{Success: true, Message: "VPN config updated"})
}

func handleDeleteVPN(conn net.Conn, req models.Request, manager *Manager) {
	uuidOrName, ok := params.StringAlt(req.Params, "uuid", "name", "uuidOrName")
	if !ok {
		models.RespondError(conn, req.ID, "missing 'uuid', 'name', or 'uuidOrName' parameter")
		return
	}

	if err := manager.DeleteVPN(uuidOrName); err != nil {
		log.Warnf("handleDeleteVPN: failed to delete: %v", err)
		models.RespondError(conn, req.ID, fmt.Sprintf("failed to delete VPN: %v", err))
		return
	}

	models.Respond(conn, req.ID, models.SuccessResult{Success: true, Message: "VPN deleted"})
}

func handleSetVPNCredentials(conn net.Conn, req models.Request, manager *Manager) {
	connUUID, err := params.String(req.Params, "uuid")
	if err != nil {
		models.RespondError(conn, req.ID, err.Error())
		return
	}

	username := params.StringOpt(req.Params, "username", "")
	password := params.StringOpt(req.Params, "password", "")
	save := params.BoolOpt(req.Params, "save", true)

	if err := manager.SetVPNCredentials(connUUID, username, password, save); err != nil {
		log.Warnf("handleSetVPNCredentials: failed to set credentials: %v", err)
		models.RespondError(conn, req.ID, fmt.Sprintf("failed to set VPN credentials: %v", err))
		return
	}

	models.Respond(conn, req.ID, models.SuccessResult{Success: true, Message: "VPN credentials set"})
}
