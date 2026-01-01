package network

import (
	"context"
	"errors"
	"fmt"
	"strconv"
	"strings"
	"time"

	"github.com/AvengeMedia/DankMaterialShell/core/internal/errdefs"
	"github.com/AvengeMedia/DankMaterialShell/core/internal/log"
	"github.com/godbus/dbus/v5"
	"golang.org/x/text/cases"
	"golang.org/x/text/language"
)

const (
	nmAgentManagerPath  = "/org/freedesktop/NetworkManager/AgentManager"
	nmAgentManagerIface = "org.freedesktop.NetworkManager.AgentManager"
	nmSecretAgentIface  = "org.freedesktop.NetworkManager.SecretAgent"
	agentObjectPath     = "/org/freedesktop/NetworkManager/SecretAgent"
	agentIdentifier     = "com.danklinux.NMAgent"
)

type SecretAgent struct {
	conn    *dbus.Conn
	objPath dbus.ObjectPath
	id      string
	prompts PromptBroker
	manager *Manager
	backend *NetworkManagerBackend
}

type nmVariantMap map[string]dbus.Variant
type nmSettingMap map[string]nmVariantMap

const introspectXML = `
<node>
	<interface name="org.freedesktop.NetworkManager.SecretAgent">
		<method name="GetSecrets">
			<arg type="a{sa{sv}}" name="connection" direction="in"/>
			<arg type="o" name="connection_path" direction="in"/>
			<arg type="s" name="setting_name" direction="in"/>
			<arg type="as" name="hints" direction="in"/>
			<arg type="u" name="flags" direction="in"/>
			<arg type="a{sa{sv}}" name="secrets" direction="out"/>
		</method>
		<method name="DeleteSecrets">
			<arg type="a{sa{sv}}" name="connection" direction="in"/>
			<arg type="o" name="connection_path" direction="in"/>
		</method>
		<method name="DeleteSecrets2">
			<arg type="o" name="connection_path" direction="in"/>
			<arg type="s" name="setting" direction="in"/>
		</method>
		<method name="CancelGetSecrets">
			<arg type="o" name="connection_path" direction="in"/>
			<arg type="s" name="setting_name" direction="in"/>
		</method>
	</interface>
	<interface name="org.freedesktop.DBus.Introspectable">
		<method name="Introspect">
			<arg name="data" type="s" direction="out"/>
		</method>
	</interface>
</node>`

func NewSecretAgent(prompts PromptBroker, manager *Manager, backend *NetworkManagerBackend) (*SecretAgent, error) {
	c, err := dbus.ConnectSystemBus()
	if err != nil {
		return nil, fmt.Errorf("failed to connect to system bus: %w", err)
	}

	sa := &SecretAgent{
		conn:    c,
		objPath: dbus.ObjectPath(agentObjectPath),
		id:      agentIdentifier,
		prompts: prompts,
		manager: manager,
		backend: backend,
	}

	if err := c.Export(sa, sa.objPath, nmSecretAgentIface); err != nil {
		c.Close()
		return nil, fmt.Errorf("failed to export secret agent: %w", err)
	}

	if err := c.Export(sa, sa.objPath, "org.freedesktop.DBus.Introspectable"); err != nil {
		c.Close()
		return nil, fmt.Errorf("failed to export introspection: %w", err)
	}

	mgr := c.Object("org.freedesktop.NetworkManager", dbus.ObjectPath(nmAgentManagerPath))
	call := mgr.Call(nmAgentManagerIface+".Register", 0, sa.id)
	if call.Err != nil {
		c.Close()
		return nil, fmt.Errorf("failed to register agent with NetworkManager: %w", call.Err)
	}

	log.Infof("[SecretAgent] Registered with NetworkManager (id=%s, unique name=%s, fixed path=%s)", sa.id, c.Names()[0], sa.objPath)
	return sa, nil
}

func (a *SecretAgent) Close() {
	if a.conn != nil {
		mgr := a.conn.Object("org.freedesktop.NetworkManager", dbus.ObjectPath(nmAgentManagerPath))
		mgr.Call(nmAgentManagerIface+".Unregister", 0, a.id)
		a.conn.Close()
	}
}

func (a *SecretAgent) GetSecrets(
	conn map[string]nmVariantMap,
	path dbus.ObjectPath,
	settingName string,
	hints []string,
	flags uint32,
) (nmSettingMap, *dbus.Error) {
	log.Infof("[SecretAgent] GetSecrets called: path=%s, setting=%s, hints=%v, flags=%d",
		path, settingName, hints, flags)

	connType, displayName, vpnSvc := readConnTypeAndName(conn)
	ssid := readSSID(conn)
	fields := fieldsNeeded(settingName, hints)
	vpnPasswordFlags := readVPNPasswordFlags(conn, settingName)

	log.Infof("[SecretAgent] connType=%s, name=%s, vpnSvc=%s, fields=%v, flags=%d, vpnPasswordFlags=%d", connType, displayName, vpnSvc, fields, flags, vpnPasswordFlags)

	if a.backend != nil {
		a.backend.stateMutex.RLock()
		isConnecting := a.backend.state.IsConnecting
		connectingSSID := a.backend.state.ConnectingSSID
		isConnectingVPN := a.backend.state.IsConnectingVPN
		connectingVPNUUID := a.backend.state.ConnectingVPNUUID
		a.backend.stateMutex.RUnlock()

		switch connType {
		case "802-11-wireless":
			// If we're connecting to a WiFi network, only respond if it's the one we're connecting to
			if isConnecting && connectingSSID != ssid {
				log.Infof("[SecretAgent] Ignoring WiFi request for SSID '%s' - we're connecting to '%s'", ssid, connectingSSID)
				return nil, dbus.NewError("org.freedesktop.NetworkManager.SecretAgent.Error.NoSecrets", nil)
			}
		case "vpn", "wireguard":
			var connUuid string
			if c, ok := conn["connection"]; ok {
				if v, ok := c["uuid"]; ok {
					if s, ok2 := v.Value().(string); ok2 {
						connUuid = s
					}
				}
			}

			// If we're connecting to a VPN, only respond if it's the one we're connecting to
			// This prevents interfering with nmcli/other tools when our app isn't connecting
			if isConnectingVPN && connUuid != connectingVPNUUID {
				log.Infof("[SecretAgent] Ignoring VPN request for UUID '%s' - we're connecting to '%s'", connUuid, connectingVPNUUID)
				return nil, dbus.NewError("org.freedesktop.NetworkManager.SecretAgent.Error.NoSecrets", nil)
			}
		}
	}

	if len(fields) == 0 {
		if settingName == "vpn" {
			if a.backend != nil {
				a.backend.stateMutex.RLock()
				isConnectingVPN := a.backend.state.IsConnectingVPN
				a.backend.stateMutex.RUnlock()

				if !isConnectingVPN {
					log.Infof("[SecretAgent] VPN with empty hints - deferring to other agents for %s", vpnSvc)
					return nil, dbus.NewError("org.freedesktop.NetworkManager.SecretAgent.Error.NoSecrets", nil)
				}

				fields = inferVPNFields(conn, vpnSvc)
				log.Infof("[SecretAgent] VPN with empty hints but we're connecting - inferred fields: %v", fields)
			} else {
				log.Infof("[SecretAgent] VPN with empty hints - deferring to other agents for %s", vpnSvc)
				return nil, dbus.NewError("org.freedesktop.NetworkManager.SecretAgent.Error.NoSecrets", nil)
			}
		}

		if len(fields) == 0 {
			const (
				NM_SETTING_SECRET_FLAG_NONE         = 0
				NM_SETTING_SECRET_FLAG_AGENT_OWNED  = 1
				NM_SETTING_SECRET_FLAG_NOT_SAVED    = 2
				NM_SETTING_SECRET_FLAG_NOT_REQUIRED = 4
			)

			var passwordFlags uint32 = 0xFFFF
			switch settingName {
			case "802-11-wireless-security":
				if wifiSecSettings, ok := conn["802-11-wireless-security"]; ok {
					if flagsVariant, ok := wifiSecSettings["psk-flags"]; ok {
						if pwdFlags, ok := flagsVariant.Value().(uint32); ok {
							passwordFlags = pwdFlags
						}
					}
				}
			case "802-1x":
				if dot1xSettings, ok := conn["802-1x"]; ok {
					if flagsVariant, ok := dot1xSettings["password-flags"]; ok {
						if pwdFlags, ok := flagsVariant.Value().(uint32); ok {
							passwordFlags = pwdFlags
						}
					}
				}
			}

			if passwordFlags == 0xFFFF {
				log.Warnf("[SecretAgent] Could not determine password-flags for empty hints - returning NoSecrets error")
				return nil, dbus.NewError("org.freedesktop.NetworkManager.SecretAgent.Error.NoSecrets", nil)
			} else if passwordFlags&NM_SETTING_SECRET_FLAG_NOT_REQUIRED != 0 {
				log.Infof("[SecretAgent] Secrets not required (flags=%d)", passwordFlags)
				out := nmSettingMap{}
				out[settingName] = nmVariantMap{}
				return out, nil
			} else if passwordFlags&NM_SETTING_SECRET_FLAG_AGENT_OWNED != 0 {
				log.Warnf("[SecretAgent] Secrets are agent-owned but we don't store secrets (flags=%d) - returning NoSecrets error", passwordFlags)
				return nil, dbus.NewError("org.freedesktop.NetworkManager.SecretAgent.Error.NoSecrets", nil)
			} else {
				log.Infof("[SecretAgent] No secrets needed, using system stored secrets (flags=%d)", passwordFlags)
				out := nmSettingMap{}
				out[settingName] = nmVariantMap{}
				return out, nil
			}
		}
	}

	reason := reasonFromFlags(flags)
	if a.manager != nil && connType == "802-11-wireless" && a.manager.WasRecentlyFailed(ssid) {
		reason = "wrong-password"
	}
	if settingName == "vpn" && isPKCS11Auth(conn, vpnSvc) {
		reason = "pkcs11"
	}

	var connId, connUuid string
	if c, ok := conn["connection"]; ok {
		if v, ok := c["id"]; ok {
			if s, ok2 := v.Value().(string); ok2 {
				connId = s
			}
		}
		if v, ok := c["uuid"]; ok {
			if s, ok2 := v.Value().(string); ok2 {
				connUuid = s
			}
		}
	}

	if settingName == "vpn" && a.backend != nil {
		// Check for cached PKCS11 PIN first
		isPKCS11Request := len(fields) == 1 && fields[0] == "key_pass"
		if isPKCS11Request {
			a.backend.cachedPKCS11Mu.Lock()
			cached := a.backend.cachedPKCS11PIN
			if cached != nil && cached.ConnectionUUID == connUuid {
				a.backend.cachedPKCS11PIN = nil
				a.backend.cachedPKCS11Mu.Unlock()

				log.Infof("[SecretAgent] Using cached PKCS11 PIN")

				out := nmSettingMap{}
				vpnSec := nmVariantMap{}
				vpnSec["secrets"] = dbus.MakeVariant(map[string]string{"key_pass": cached.PIN})
				out[settingName] = vpnSec

				return out, nil
			}
			a.backend.cachedPKCS11Mu.Unlock()
		}

		// Check for cached VPN password
		a.backend.cachedVPNCredsMu.Lock()
		cached := a.backend.cachedVPNCreds
		if cached != nil && cached.ConnectionUUID == connUuid {
			a.backend.cachedVPNCreds = nil
			a.backend.cachedVPNCredsMu.Unlock()

			log.Infof("[SecretAgent] Using cached password from pre-activation prompt")

			out := nmSettingMap{}
			vpnSec := nmVariantMap{}
			vpnSec["secrets"] = dbus.MakeVariant(map[string]string{"password": cached.Password})
			out[settingName] = vpnSec

			if cached.SavePassword {
				a.backend.pendingVPNSaveMu.Lock()
				a.backend.pendingVPNSave = &pendingVPNCredentials{
					ConnectionPath: string(path),
					Password:       cached.Password,
					SavePassword:   true,
				}
				a.backend.pendingVPNSaveMu.Unlock()
			}

			return out, nil
		}
		a.backend.cachedVPNCredsMu.Unlock()
	}

	ctx, cancel := context.WithTimeout(context.Background(), 2*time.Minute)
	defer cancel()

	token, err := a.prompts.Ask(ctx, PromptRequest{
		Name:           displayName,
		SSID:           ssid,
		ConnType:       connType,
		VpnService:     vpnSvc,
		SettingName:    settingName,
		Fields:         fields,
		FieldsInfo:     buildFieldsInfo(settingName, fields, vpnSvc),
		Hints:          hints,
		Reason:         reason,
		ConnectionId:   connId,
		ConnectionUuid: connUuid,
		ConnectionPath: string(path),
	})
	if err != nil {
		log.Warnf("[SecretAgent] Failed to create prompt: %v", err)
		return nil, dbus.MakeFailedError(err)
	}

	log.Infof("[SecretAgent] Waiting for user input (token=%s)", token)
	reply, err := a.prompts.Wait(ctx, token)
	if err != nil {
		log.Warnf("[SecretAgent] Prompt failed or cancelled: %v", err)

		// Clear connecting state immediately on cancellation
		if a.backend != nil {
			a.backend.stateMutex.Lock()
			wasConnecting := a.backend.state.IsConnecting
			wasConnectingVPN := a.backend.state.IsConnectingVPN
			cancelledSSID := a.backend.state.ConnectingSSID
			cancelledVPNUUID := a.backend.state.ConnectingVPNUUID
			if wasConnecting || wasConnectingVPN {
				log.Infof("[SecretAgent] Clearing connecting state due to cancelled prompt")
				a.backend.state.IsConnecting = false
				a.backend.state.ConnectingSSID = ""
				a.backend.state.IsConnectingVPN = false
				a.backend.state.ConnectingVPNUUID = ""
			}
			a.backend.stateMutex.Unlock()

			// If this was a WiFi connection that was just cancelled, remove the connection profile
			// (it was created with AddConnection but activation was cancelled)
			if wasConnecting && cancelledSSID != "" && connType == "802-11-wireless" {
				log.Infof("[SecretAgent] Removing connection profile for cancelled WiFi connection: %s", cancelledSSID)
				if err := a.backend.ForgetWiFiNetwork(cancelledSSID); err != nil {
					log.Warnf("[SecretAgent] Failed to remove cancelled connection profile: %v", err)
				}
			}

			// If this was a VPN connection that was cancelled, deactivate it
			if wasConnectingVPN && cancelledVPNUUID != "" {
				log.Infof("[SecretAgent] Deactivating cancelled VPN connection: %s", cancelledVPNUUID)
				if err := a.backend.DisconnectVPN(cancelledVPNUUID); err != nil {
					log.Warnf("[SecretAgent] Failed to deactivate cancelled VPN: %v", err)
				}
			}

			if (wasConnecting || wasConnectingVPN) && a.backend.onStateChange != nil {
				a.backend.onStateChange()
			}
		}

		if reply.Cancel || errors.Is(err, errdefs.ErrSecretPromptCancelled) {
			return nil, dbus.NewError("org.freedesktop.NetworkManager.SecretAgent.Error.UserCanceled", nil)
		}

		if errors.Is(err, errdefs.ErrSecretPromptTimeout) {
			return nil, dbus.NewError("org.freedesktop.NetworkManager.SecretAgent.Error.Failed", nil)
		}
		return nil, dbus.NewError("org.freedesktop.NetworkManager.SecretAgent.Error.Failed", nil)
	}

	log.Infof("[SecretAgent] User provided secrets, save=%v", reply.Save)

	out := nmSettingMap{}
	sec := nmVariantMap{}

	var vpnUsername string
	for k, v := range reply.Secrets {
		if settingName == "vpn" && k == "username" {
			vpnUsername = v
		}
		sec[k] = dbus.MakeVariant(v)
	}

	// Check if this is PKCS11 auth (key_pass)
	pin, isPKCS11 := reply.Secrets["key_pass"]

	switch settingName {
	case "vpn":
		// VPN secrets must be wrapped in a "secrets" key per NM spec
		secretsDict := make(map[string]string)
		for k, v := range reply.Secrets {
			if k != "username" {
				secretsDict[k] = v
			}
		}
		vpnSec := nmVariantMap{}
		vpnSec["secrets"] = dbus.MakeVariant(secretsDict)
		out[settingName] = vpnSec
		log.Infof("[SecretAgent] Returning VPN secrets with %d fields for %s", len(secretsDict), vpnSvc)

		// Cache PKCS11 PIN in case GetSecrets is called again during activation
		if isPKCS11 && a.backend != nil {
			a.backend.cachedPKCS11Mu.Lock()
			a.backend.cachedPKCS11PIN = &cachedPKCS11PIN{
				ConnectionUUID: connUuid,
				PIN:            pin,
			}
			a.backend.cachedPKCS11Mu.Unlock()
			log.Infof("[SecretAgent] Cached PKCS11 PIN for potential re-request")
		}
	case "802-1x":
		out[settingName] = sec
		log.Infof("[SecretAgent] Returning 802-1x enterprise secrets with %d fields", len(sec))
	default:
		out[settingName] = sec
	}
	if settingName == "vpn" && a.backend != nil && !isPKCS11 && (vpnUsername != "" || reply.Save) {
		pw := reply.Secrets["password"]
		a.backend.pendingVPNSaveMu.Lock()
		a.backend.pendingVPNSave = &pendingVPNCredentials{
			ConnectionPath: string(path),
			Username:       vpnUsername,
			Password:       pw,
			SavePassword:   reply.Save,
		}
		a.backend.pendingVPNSaveMu.Unlock()
		log.Infof("[SecretAgent] Queued credentials persist for after connection succeeds")
	} else if reply.Save && settingName != "vpn" {
		// Non-VPN save logic
		go func() {
			log.Infof("[SecretAgent] Persisting secrets with Update2: path=%s, setting=%s", path, settingName)

			connObj := a.conn.Object("org.freedesktop.NetworkManager", path)
			var existingSettings map[string]map[string]dbus.Variant
			if err := connObj.Call("org.freedesktop.NetworkManager.Settings.Connection.GetSettings", 0).Store(&existingSettings); err != nil {
				log.Warnf("[SecretAgent] GetSettings failed: %v", err)
				return
			}

			settings := make(map[string]map[string]dbus.Variant)
			if connSection, ok := existingSettings["connection"]; ok {
				settings["connection"] = connSection
			}

			switch settingName {
			case "802-11-wireless-security":
				wifiSec, ok := existingSettings["802-11-wireless-security"]
				if !ok {
					wifiSec = make(map[string]dbus.Variant)
				}
				wifiSec["psk-flags"] = dbus.MakeVariant(uint32(0))

				if psk, ok := reply.Secrets["psk"]; ok {
					wifiSec["psk"] = dbus.MakeVariant(psk)
					log.Infof("[SecretAgent] Updated WiFi settings: psk-flags=0")
				}
				settings["802-11-wireless-security"] = wifiSec

			case "802-1x":
				dot1x, ok := existingSettings["802-1x"]
				if !ok {
					dot1x = make(map[string]dbus.Variant)
				}
				dot1x["password-flags"] = dbus.MakeVariant(uint32(0))

				if password, ok := reply.Secrets["password"]; ok {
					dot1x["password"] = dbus.MakeVariant(password)
					log.Infof("[SecretAgent] Updated 802.1x settings: password-flags=0")
				}
				settings["802-1x"] = dot1x
			}

			// Call Update2 with correct signature:
			// Update2(IN settings, IN flags, IN args) -> OUT result
			// flags: 0x1 = to-disk
			var result map[string]dbus.Variant
			err := connObj.Call("org.freedesktop.NetworkManager.Settings.Connection.Update2", 0,
				settings, uint32(0x1), map[string]dbus.Variant{}).Store(&result)
			if err != nil {
				log.Warnf("[SecretAgent] Update2(to-disk) failed: %v", err)
			} else {
				log.Infof("[SecretAgent] Successfully persisted secrets to disk for %s", settingName)
			}
		}()
	}

	return out, nil
}

func (a *SecretAgent) DeleteSecrets(conn map[string]nmVariantMap, path dbus.ObjectPath) *dbus.Error {
	ssid := readSSID(conn)
	log.Infof("[SecretAgent] DeleteSecrets called: path=%s, SSID=%s", path, ssid)
	return nil
}

func (a *SecretAgent) DeleteSecrets2(path dbus.ObjectPath, setting string) *dbus.Error {
	log.Infof("[SecretAgent] DeleteSecrets2 (alternate) called: path=%s, setting=%s", path, setting)
	return nil
}

func (a *SecretAgent) CancelGetSecrets(path dbus.ObjectPath, settingName string) *dbus.Error {
	log.Infof("[SecretAgent] CancelGetSecrets called: path=%s, setting=%s", path, settingName)

	if a.prompts != nil {
		if err := a.prompts.Cancel(string(path), settingName); err != nil {
			log.Warnf("[SecretAgent] Failed to cancel prompt: %v", err)
		}
	}

	return nil
}

func (a *SecretAgent) Introspect() (string, *dbus.Error) {
	return introspectXML, nil
}

func readSSID(conn map[string]nmVariantMap) string {
	if w, ok := conn["802-11-wireless"]; ok {
		if v, ok := w["ssid"]; ok {
			if b, ok := v.Value().([]byte); ok {
				return string(b)
			}
			if s, ok := v.Value().(string); ok {
				return s
			}
		}
	}
	return ""
}

func readConnTypeAndName(conn map[string]nmVariantMap) (string, string, string) {
	var connType, name, svc string
	if c, ok := conn["connection"]; ok {
		if v, ok := c["type"]; ok {
			if s, ok2 := v.Value().(string); ok2 {
				connType = s
			}
		}
		if v, ok := c["id"]; ok {
			if s, ok2 := v.Value().(string); ok2 {
				name = s
			}
		}
	}
	if vpn, ok := conn["vpn"]; ok {
		if v, ok := vpn["service-type"]; ok {
			if s, ok2 := v.Value().(string); ok2 {
				svc = s
			}
		}
	}
	if name == "" && connType == "802-11-wireless" {
		name = readSSID(conn)
	}
	return connType, name, svc
}

func fieldsNeeded(setting string, hints []string) []string {
	switch setting {
	case "802-11-wireless-security":
		return []string{"psk"}
	case "802-1x":
		return []string{"identity", "password"}
	case "vpn":
		return hints
	default:
		return []string{}
	}
}

func buildFieldsInfo(setting string, fields []string, vpnService string) []FieldInfo {
	result := make([]FieldInfo, 0, len(fields))
	for _, f := range fields {
		info := FieldInfo{Name: f}
		switch setting {
		case "802-11-wireless-security":
			info.Label = "Password"
			info.IsSecret = true
		case "802-1x":
			switch f {
			case "identity":
				info.Label = "Username"
				info.IsSecret = false
			case "password":
				info.Label = "Password"
				info.IsSecret = true
			default:
				info.Label = f
				info.IsSecret = true
			}
		case "vpn":
			info.Label, info.IsSecret = vpnFieldMeta(f, vpnService)
		default:
			info.Label = f
			info.IsSecret = true
		}
		result = append(result, info)
	}
	return result
}

func inferVPNFields(conn map[string]nmVariantMap, vpnService string) []string {
	fields := []string{"password"}

	vpnSettings, ok := conn["vpn"]
	if !ok {
		return fields
	}

	dataVariant, ok := vpnSettings["data"]
	if !ok {
		return fields
	}

	dataMap, ok := dataVariant.Value().(map[string]string)
	if !ok {
		return fields
	}

	connType := dataMap["connection-type"]

	switch {
	case strings.Contains(vpnService, "openconnect"):
		authType := dataMap["authtype"]
		userCert := dataMap["usercert"]
		if authType == "cert" && strings.HasPrefix(userCert, "pkcs11:") {
			return []string{"key_pass"}
		}
		if dataMap["username"] == "" {
			fields = []string{"username", "password"}
		}
	case strings.Contains(vpnService, "openvpn"):
		if connType == "password" || connType == "password-tls" {
			if dataMap["username"] == "" {
				fields = []string{"username", "password"}
			}
		}
	case strings.Contains(vpnService, "vpnc"), strings.Contains(vpnService, "l2tp"),
		strings.Contains(vpnService, "pptp"):
		if dataMap["username"] == "" {
			fields = []string{"username", "password"}
		}
	}

	return fields
}

func vpnFieldMeta(field, vpnService string) (label string, isSecret bool) {
	switch field {
	case "key_pass":
		return "PIN", true
	case "password":
		return "Password", true
	case "Xauth password":
		return "IPSec Password", true
	case "IPSec secret":
		return "IPSec Pre-Shared Key", true
	case "cert-pass":
		return "Certificate Password", true
	case "http-proxy-password":
		return "HTTP Proxy Password", true
	case "username":
		return "Username", false
	case "Xauth username":
		return "IPSec Username", false
	case "proxy-password":
		return "Proxy Password", true
	case "private-key-password":
		return "Private Key Password", true
	}
	titleCaser := cases.Title(language.English)
	if strings.HasSuffix(field, "password") || strings.HasSuffix(field, "secret") ||
		strings.HasSuffix(field, "pass") || strings.HasSuffix(field, "psk") {
		return titleCaser.String(strings.ReplaceAll(field, "-", " ")), true
	}
	return titleCaser.String(strings.ReplaceAll(field, "-", " ")), false
}

func isPKCS11Auth(conn map[string]nmVariantMap, vpnService string) bool {
	if !strings.Contains(vpnService, "openconnect") {
		return false
	}
	vpnSettings, ok := conn["vpn"]
	if !ok {
		return false
	}
	dataVariant, ok := vpnSettings["data"]
	if !ok {
		return false
	}
	dataMap, ok := dataVariant.Value().(map[string]string)
	if !ok {
		return false
	}
	return dataMap["authtype"] == "cert" && strings.HasPrefix(dataMap["usercert"], "pkcs11:")
}

func readVPNPasswordFlags(conn map[string]nmVariantMap, settingName string) uint32 {
	if settingName != "vpn" {
		return 0xFFFF
	}

	vpnSettings, ok := conn["vpn"]
	if !ok {
		return 0xFFFF
	}

	dataVariant, ok := vpnSettings["data"]
	if !ok {
		return 0xFFFF
	}

	dataMap, ok := dataVariant.Value().(map[string]string)
	if !ok {
		return 0xFFFF
	}

	flagsStr, ok := dataMap["password-flags"]
	if !ok {
		return 0xFFFF
	}

	flags64, err := strconv.ParseUint(flagsStr, 10, 32)
	if err != nil {
		return 0xFFFF
	}

	return uint32(flags64)
}

func reasonFromFlags(flags uint32) string {
	const (
		NM_SECRET_AGENT_GET_SECRETS_FLAG_NONE              = 0x0
		NM_SECRET_AGENT_GET_SECRETS_FLAG_ALLOW_INTERACTION = 0x1
		NM_SECRET_AGENT_GET_SECRETS_FLAG_REQUEST_NEW       = 0x2
		NM_SECRET_AGENT_GET_SECRETS_FLAG_USER_REQUESTED    = 0x4
		NM_SECRET_AGENT_GET_SECRETS_FLAG_WPS_PBC_ACTIVE    = 0x8
		NM_SECRET_AGENT_GET_SECRETS_FLAG_ONLY_SYSTEM       = 0x80000000
		NM_SECRET_AGENT_GET_SECRETS_FLAG_NO_ERRORS         = 0x40000000
	)

	if flags&NM_SECRET_AGENT_GET_SECRETS_FLAG_REQUEST_NEW != 0 {
		return "wrong-password"
	}
	if flags&NM_SECRET_AGENT_GET_SECRETS_FLAG_USER_REQUESTED != 0 {
		return "user-requested"
	}
	return "required"
}
