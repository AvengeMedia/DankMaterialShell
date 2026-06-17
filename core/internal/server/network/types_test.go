package network

import (
	"encoding/json"
	"testing"

	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
)

func TestNetworkStatus_Constants(t *testing.T) {
	assert.Equal(t, NetworkStatus("disconnected"), StatusDisconnected)
	assert.Equal(t, NetworkStatus("ethernet"), StatusEthernet)
	assert.Equal(t, NetworkStatus("wifi"), StatusWiFi)
	assert.Equal(t, NetworkStatus("cellular"), StatusCellular)
}

func TestConnectionPreference_Constants(t *testing.T) {
	assert.Equal(t, ConnectionPreference("auto"), PreferenceAuto)
	assert.Equal(t, ConnectionPreference("wifi"), PreferenceWiFi)
	assert.Equal(t, ConnectionPreference("ethernet"), PreferenceEthernet)
	assert.Equal(t, ConnectionPreference("cellular"), PreferenceCellular)
}

func TestEventType_Constants(t *testing.T) {
	assert.Equal(t, EventType("state_changed"), EventStateChanged)
	assert.Equal(t, EventType("networks_updated"), EventNetworksUpdated)
	assert.Equal(t, EventType("connecting"), EventConnecting)
	assert.Equal(t, EventType("connected"), EventConnected)
	assert.Equal(t, EventType("disconnected"), EventDisconnected)
	assert.Equal(t, EventType("error"), EventError)
}

func TestWiFiNetwork_JSON(t *testing.T) {
	network := WiFiNetwork{
		SSID:       "TestNetwork",
		BSSID:      "00:11:22:33:44:55",
		Signal:     85,
		Secured:    true,
		Enterprise: false,
		Connected:  true,
		Saved:      true,
		Frequency:  2437,
		Mode:       "infrastructure",
		Rate:       300,
		Channel:    6,
	}

	data, err := json.Marshal(network)
	require.NoError(t, err)

	var decoded WiFiNetwork
	err = json.Unmarshal(data, &decoded)
	require.NoError(t, err)

	assert.Equal(t, network.SSID, decoded.SSID)
	assert.Equal(t, network.BSSID, decoded.BSSID)
	assert.Equal(t, network.Signal, decoded.Signal)
	assert.Equal(t, network.Secured, decoded.Secured)
	assert.Equal(t, network.Enterprise, decoded.Enterprise)
	assert.Equal(t, network.Connected, decoded.Connected)
	assert.Equal(t, network.Saved, decoded.Saved)
	assert.Equal(t, network.Frequency, decoded.Frequency)
	assert.Equal(t, network.Mode, decoded.Mode)
	assert.Equal(t, network.Rate, decoded.Rate)
	assert.Equal(t, network.Channel, decoded.Channel)
}

func TestNetworkState_JSON(t *testing.T) {
	state := NetworkState{
		NetworkStatus:     StatusWiFi,
		Preference:        PreferenceAuto,
		EthernetIP:        "192.168.1.100",
		EthernetDevice:    "eth0",
		EthernetConnected: false,
		WiFiIP:            "192.168.1.101",
		WiFiDevice:        "wlan0",
		WiFiConnected:     true,
		WiFiEnabled:       true,
		WiFiSSID:          "TestNetwork",
		WiFiBSSID:         "00:11:22:33:44:55",
		WiFiSignal:        85,
		WiFiNetworks: []WiFiNetwork{
			{SSID: "Network1", Signal: 90},
			{SSID: "Network2", Signal: 60},
		},
		IsConnecting:   false,
		ConnectingSSID: "",
		LastError:      "",
	}

	data, err := json.Marshal(state)
	require.NoError(t, err)

	var decoded NetworkState
	err = json.Unmarshal(data, &decoded)
	require.NoError(t, err)

	assert.Equal(t, state.NetworkStatus, decoded.NetworkStatus)
	assert.Equal(t, state.Preference, decoded.Preference)
	assert.Equal(t, state.WiFiIP, decoded.WiFiIP)
	assert.Equal(t, state.WiFiSSID, decoded.WiFiSSID)
	assert.Equal(t, len(state.WiFiNetworks), len(decoded.WiFiNetworks))
}

func TestConnectionRequest_JSON(t *testing.T) {
	t.Run("with password", func(t *testing.T) {
		req := ConnectionRequest{
			SSID:     "TestNetwork",
			Password: "testpass123",
		}

		data, err := json.Marshal(req)
		require.NoError(t, err)

		var decoded ConnectionRequest
		err = json.Unmarshal(data, &decoded)
		require.NoError(t, err)

		assert.Equal(t, req.SSID, decoded.SSID)
		assert.Equal(t, req.Password, decoded.Password)
		assert.Empty(t, decoded.Username)
	})

	t.Run("with username and password (enterprise)", func(t *testing.T) {
		req := ConnectionRequest{
			SSID:     "EnterpriseNetwork",
			Password: "testpass123",
			Username: "testuser",
		}

		data, err := json.Marshal(req)
		require.NoError(t, err)

		var decoded ConnectionRequest
		err = json.Unmarshal(data, &decoded)
		require.NoError(t, err)

		assert.Equal(t, req.SSID, decoded.SSID)
		assert.Equal(t, req.Password, decoded.Password)
		assert.Equal(t, req.Username, decoded.Username)
	})
}

func TestPriorityUpdate_JSON(t *testing.T) {
	update := PriorityUpdate{
		Preference: PreferenceWiFi,
	}

	data, err := json.Marshal(update)
	require.NoError(t, err)

	var decoded PriorityUpdate
	err = json.Unmarshal(data, &decoded)
	require.NoError(t, err)

	assert.Equal(t, update.Preference, decoded.Preference)
}

func TestNetworkEvent_JSON(t *testing.T) {
	event := NetworkEvent{
		Type: EventStateChanged,
		Data: NetworkState{
			NetworkStatus: StatusWiFi,
			WiFiSSID:      "TestNetwork",
			WiFiConnected: true,
		},
	}

	data, err := json.Marshal(event)
	require.NoError(t, err)

	var decoded NetworkEvent
	err = json.Unmarshal(data, &decoded)
	require.NoError(t, err)

	assert.Equal(t, event.Type, decoded.Type)
	assert.Equal(t, event.Data.NetworkStatus, decoded.Data.NetworkStatus)
	assert.Equal(t, event.Data.WiFiSSID, decoded.Data.WiFiSSID)
}
