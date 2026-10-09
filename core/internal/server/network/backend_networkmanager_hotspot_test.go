package network

import (
	"strings"
	"testing"

	mock_gonetworkmanager "github.com/AvengeMedia/DankMaterialShell/core/internal/mocks/github.com/Wifx/gonetworkmanager/v2"
	mock_dbus "github.com/AvengeMedia/DankMaterialShell/core/internal/mocks/github.com/godbus/dbus/v5"
	"github.com/Wifx/gonetworkmanager/v2"
	"github.com/godbus/dbus/v5"
	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
)

func TestBuildHotspotSettings(t *testing.T) {
	settings := buildHotspotSettings(HotspotRequest{
		SSID:     "DMS Hotspot",
		Password: "hunter2-password",
		Device:   "wlan0",
		Band:     "bg",
	})

	assert.Equal(t, dmsHotspotConnectionID, settings["connection"]["id"])
	assert.Equal(t, "802-11-wireless", settings["connection"]["type"])
	assert.Equal(t, false, settings["connection"]["autoconnect"])
	assert.Equal(t, dmsHotspotStableID, settings["connection"]["stable-id"])
	assert.Equal(t, "wlan0", settings["connection"]["interface-name"])

	assert.Equal(t, "ap", settings["802-11-wireless"]["mode"])
	assert.Equal(t, []byte("DMS Hotspot"), settings["802-11-wireless"]["ssid"])
	assert.Equal(t, "bg", settings["802-11-wireless"]["band"])
	assert.Equal(t, "802-11-wireless-security", settings["802-11-wireless"]["security"])

	assert.Equal(t, "wpa-psk", settings["802-11-wireless-security"]["key-mgmt"])
	assert.Equal(t, "hunter2-password", settings["802-11-wireless-security"]["psk"])
	assert.Equal(t, uint32(0), settings["802-11-wireless-security"]["psk-flags"])

	assert.Equal(t, "shared", settings["ipv4"]["method"])
	assert.Equal(t, "ignore", settings["ipv6"]["method"])
}

func TestBuildHotspotSettingsOpenNetwork(t *testing.T) {
	settings := buildHotspotSettings(HotspotRequest{SSID: "Open Hotspot"})

	_, hasSecurity := settings["802-11-wireless-security"]
	assert.False(t, hasSecurity)
	_, hasWirelessSecurityRef := settings["802-11-wireless"]["security"]
	assert.False(t, hasWirelessSecurityRef)
}

func TestIsDMSHotspotConnection(t *testing.T) {
	tests := []struct {
		name     string
		settings gonetworkmanager.ConnectionSettings
		want     bool
	}{
		{
			name: "stable-id marker",
			settings: gonetworkmanager.ConnectionSettings{
				"connection": {
					"type":      "802-11-wireless",
					"stable-id": dmsHotspotStableID,
				},
				"802-11-wireless": {
					"mode": "ap",
				},
			},
			want: true,
		},
		{
			name: "stable DMS id without marker is not enough",
			settings: gonetworkmanager.ConnectionSettings{
				"connection": {
					"type": "802-11-wireless",
					"id":   dmsHotspotConnectionID,
				},
				"802-11-wireless": {
					"mode": "ap",
				},
			},
			want: false,
		},
		{
			name: "same SSID but client profile",
			settings: gonetworkmanager.ConnectionSettings{
				"connection": {
					"type": "802-11-wireless",
					"id":   dmsHotspotConnectionID,
				},
				"802-11-wireless": {
					"mode": "infrastructure",
					"ssid": []byte("DMS Hotspot"),
				},
			},
			want: false,
		},
		{
			name: "matching SSID only is not enough",
			settings: gonetworkmanager.ConnectionSettings{
				"connection": {
					"type": "802-11-wireless",
					"id":   "User Hotspot",
				},
				"802-11-wireless": {
					"mode": "ap",
					"ssid": []byte("DMS Hotspot"),
				},
			},
			want: false,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			assert.Equal(t, tt.want, isDMSHotspotConnection(tt.settings))
		})
	}
}

func TestIsAPCapableWiFiDevice(t *testing.T) {
	mockWiFi := mock_gonetworkmanager.NewMockDeviceWireless(t)
	mockWiFi.EXPECT().GetPropertyManaged().Return(true, nil)
	mockWiFi.EXPECT().GetPropertyWirelessCapabilities().Return(nmWiFiDeviceCapAP, nil)

	ok, err := isAPCapableWiFiDevice(&wifiDeviceInfo{device: mockWiFi, wireless: mockWiFi})
	require.NoError(t, err)
	assert.True(t, ok)
}

func TestIsAPCapableWiFiDeviceUnmanaged(t *testing.T) {
	mockWiFi := mock_gonetworkmanager.NewMockDeviceWireless(t)
	mockWiFi.EXPECT().GetPropertyManaged().Return(false, nil)

	ok, err := isAPCapableWiFiDevice(&wifiDeviceInfo{device: mockWiFi, wireless: mockWiFi})
	require.NoError(t, err)
	assert.False(t, ok)
}

func TestValidateHotspotBand(t *testing.T) {
	tests := []struct {
		name    string
		band    string
		caps    uint32
		wantErr bool
	}{
		{
			name: "2.4GHz supported",
			band: "bg",
			caps: nmWiFiDeviceCapFreqValid | nmWiFiDeviceCapFreq2GHz,
		},
		{
			name: "5GHz supported",
			band: "a",
			caps: nmWiFiDeviceCapFreqValid | nmWiFiDeviceCapFreq5GHz,
		},
		{
			name:    "2.4GHz unsupported",
			band:    "bg",
			caps:    nmWiFiDeviceCapFreqValid | nmWiFiDeviceCapFreq5GHz,
			wantErr: true,
		},
		{
			name:    "5GHz unsupported",
			band:    "a",
			caps:    nmWiFiDeviceCapFreqValid | nmWiFiDeviceCapFreq2GHz,
			wantErr: true,
		},
		{
			name: "unknown frequencies defer to NetworkManager",
			band: "a",
			caps: 0,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			mockWiFi := mock_gonetworkmanager.NewMockDeviceWireless(t)
			mockWiFi.EXPECT().GetPropertyWirelessCapabilities().Return(tt.caps, nil)

			err := validateHotspotBand(&wifiDeviceInfo{wireless: mockWiFi}, tt.band)
			if tt.wantErr {
				assert.Error(t, err)
			} else {
				assert.NoError(t, err)
			}
		})
	}
}

func TestGetAPCapableWiFiDeviceSelectsDeviceCompatibleWithRequestedBand(t *testing.T) {
	mockNM := mock_gonetworkmanager.NewMockNetworkManager(t)
	wlan0 := mock_gonetworkmanager.NewMockDeviceWireless(t)
	wlan1 := mock_gonetworkmanager.NewMockDeviceWireless(t)

	backend, err := NewNetworkManagerBackend(mockNM)
	require.NoError(t, err)
	backend.wifiDevices = map[string]*wifiDeviceInfo{
		"wlan0": {device: wlan0, wireless: wlan0, name: "wlan0"},
		"wlan1": {device: wlan1, wireless: wlan1, name: "wlan1"},
	}

	wlan0.EXPECT().GetPropertyManaged().Return(true, nil)
	wlan0.EXPECT().GetPropertyWirelessCapabilities().Return(nmWiFiDeviceCapAP|nmWiFiDeviceCapFreqValid|nmWiFiDeviceCapFreq2GHz, nil).Twice()
	wlan1.EXPECT().GetPropertyManaged().Return(true, nil)
	wlan1.EXPECT().GetPropertyWirelessCapabilities().Return(nmWiFiDeviceCapAP|nmWiFiDeviceCapFreqValid|nmWiFiDeviceCapFreq5GHz, nil).Twice()
	mockNM.EXPECT().GetPropertyActiveConnections().Return(nil, nil).Once()
	wlan1.EXPECT().GetPropertyState().Return(gonetworkmanager.NmDeviceStateDisconnected, nil).Once()

	devInfo, err := backend.getAPCapableWiFiDevice("", "a")
	require.NoError(t, err)
	assert.Equal(t, "wlan1", devInfo.name)
}

func TestGetAPCapableWiFiDeviceAutoPrefersIdleDevice(t *testing.T) {
	mockNM := mock_gonetworkmanager.NewMockNetworkManager(t)
	wlan0 := mock_gonetworkmanager.NewMockDeviceWireless(t)
	wlan1 := mock_gonetworkmanager.NewMockDeviceWireless(t)

	backend, err := NewNetworkManagerBackend(mockNM)
	require.NoError(t, err)
	backend.wifiDevices = map[string]*wifiDeviceInfo{
		"wlan0": {device: wlan0, wireless: wlan0, name: "wlan0"},
		"wlan1": {device: wlan1, wireless: wlan1, name: "wlan1"},
	}

	wlan0.EXPECT().GetPropertyManaged().Return(true, nil)
	wlan0.EXPECT().GetPropertyWirelessCapabilities().Return(nmWiFiDeviceCapAP, nil)
	wlan1.EXPECT().GetPropertyManaged().Return(true, nil)
	wlan1.EXPECT().GetPropertyWirelessCapabilities().Return(nmWiFiDeviceCapAP, nil)
	mockNM.EXPECT().GetPropertyActiveConnections().Return(nil, nil).Once()
	wlan0.EXPECT().GetPropertyState().Return(gonetworkmanager.NmDeviceStateActivated, nil).Once()
	wlan1.EXPECT().GetPropertyState().Return(gonetworkmanager.NmDeviceStateDisconnected, nil).Once()

	devInfo, err := backend.getAPCapableWiFiDevice("", "")
	require.NoError(t, err)
	assert.Equal(t, "wlan1", devInfo.name, "auto selection should prefer the radio without an active connection")
}

func TestGetAPCapableWiFiDeviceAutoRanksTransitionalAndUnusableStates(t *testing.T) {
	tests := []struct {
		name       string
		wlan0State gonetworkmanager.NmDeviceState
		wlan1State gonetworkmanager.NmDeviceState
		want       string
	}{
		{
			name:       "disconnected beats client activation in progress",
			wlan0State: gonetworkmanager.NmDeviceStateConfig,
			wlan1State: gonetworkmanager.NmDeviceStateDisconnected,
			want:       "wlan1",
		},
		{
			name:       "active connection beats failed radio",
			wlan0State: gonetworkmanager.NmDeviceStateFailed,
			wlan1State: gonetworkmanager.NmDeviceStateActivated,
			want:       "wlan1",
		},
		{
			name:       "active connection beats unavailable radio",
			wlan0State: gonetworkmanager.NmDeviceStateUnavailable,
			wlan1State: gonetworkmanager.NmDeviceStateActivated,
			want:       "wlan1",
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			mockNM := mock_gonetworkmanager.NewMockNetworkManager(t)
			wlan0 := mock_gonetworkmanager.NewMockDeviceWireless(t)
			wlan1 := mock_gonetworkmanager.NewMockDeviceWireless(t)

			backend, err := NewNetworkManagerBackend(mockNM)
			require.NoError(t, err)
			backend.wifiDevices = map[string]*wifiDeviceInfo{
				"wlan0": {device: wlan0, wireless: wlan0, name: "wlan0"},
				"wlan1": {device: wlan1, wireless: wlan1, name: "wlan1"},
			}

			wlan0.EXPECT().GetPropertyManaged().Return(true, nil)
			wlan0.EXPECT().GetPropertyWirelessCapabilities().Return(nmWiFiDeviceCapAP, nil)
			wlan1.EXPECT().GetPropertyManaged().Return(true, nil)
			wlan1.EXPECT().GetPropertyWirelessCapabilities().Return(nmWiFiDeviceCapAP, nil)
			mockNM.EXPECT().GetPropertyActiveConnections().Return(nil, nil).Once()
			wlan0.EXPECT().GetPropertyState().Return(tt.wlan0State, nil).Once()
			wlan1.EXPECT().GetPropertyState().Return(tt.wlan1State, nil).Once()

			devInfo, err := backend.getAPCapableWiFiDevice("", "")
			require.NoError(t, err)
			assert.Equal(t, tt.want, devInfo.name)
		})
	}
}

func TestGetAPCapableWiFiDeviceAutoDoesNotEvictForeignHotspot(t *testing.T) {
	mockNM := mock_gonetworkmanager.NewMockNetworkManager(t)
	wlan0 := mock_gonetworkmanager.NewMockDeviceWireless(t)
	wlan1 := mock_gonetworkmanager.NewMockDeviceWireless(t)
	mockActive := mock_gonetworkmanager.NewMockActiveConnection(t)
	mockConn := mock_gonetworkmanager.NewMockConnection(t)

	backend, err := NewNetworkManagerBackend(mockNM)
	require.NoError(t, err)
	backend.wifiDevices = map[string]*wifiDeviceInfo{
		"wlan0": {device: wlan0, wireless: wlan0, name: "wlan0"},
		"wlan1": {device: wlan1, wireless: wlan1, name: "wlan1"},
	}

	userHotspot := gonetworkmanager.ConnectionSettings{
		"connection": {
			"type": "802-11-wireless",
			"id":   "User Hotspot",
		},
		"802-11-wireless": {
			"mode": "ap",
		},
	}

	wlan0.EXPECT().GetPropertyManaged().Return(true, nil)
	wlan0.EXPECT().GetPropertyWirelessCapabilities().Return(nmWiFiDeviceCapAP, nil)
	wlan1.EXPECT().GetPropertyManaged().Return(true, nil)
	wlan1.EXPECT().GetPropertyWirelessCapabilities().Return(nmWiFiDeviceCapAP, nil)
	mockNM.EXPECT().GetPropertyActiveConnections().Return([]gonetworkmanager.ActiveConnection{mockActive}, nil).Once()
	mockActive.EXPECT().GetPropertyType().Return("802-11-wireless", nil).Once()
	mockActive.EXPECT().GetPropertyConnection().Return(mockConn, nil).Once()
	mockConn.EXPECT().GetSettings().Return(userHotspot, nil).Once()
	wlan0.EXPECT().GetPropertyState().Return(gonetworkmanager.NmDeviceStateActivated, nil).Once()
	wlan1.EXPECT().GetPropertyState().Return(gonetworkmanager.NmDeviceStateDisconnected, nil).Once()

	devInfo, err := backend.getAPCapableWiFiDevice("", "")
	require.NoError(t, err)
	assert.Equal(t, "wlan1", devInfo.name, "a radio hosting a foreign hotspot must rank as busy, not preferred")
}

func TestGetAPCapableWiFiDeviceAutoSticksWithActiveDMSHotspot(t *testing.T) {
	mockNM := mock_gonetworkmanager.NewMockNetworkManager(t)
	wlan0 := mock_gonetworkmanager.NewMockDeviceWireless(t)
	wlan1 := mock_gonetworkmanager.NewMockDeviceWireless(t)
	mockActive := mock_gonetworkmanager.NewMockActiveConnection(t)
	mockConn := mock_gonetworkmanager.NewMockConnection(t)

	backend, err := NewNetworkManagerBackend(mockNM)
	require.NoError(t, err)
	backend.wifiDevices = map[string]*wifiDeviceInfo{
		"wlan0": {device: wlan0, wireless: wlan0, name: "wlan0"},
		"wlan1": {device: wlan1, wireless: wlan1, name: "wlan1"},
	}

	dmsSettings := buildHotspotSettings(HotspotRequest{SSID: "DMS Hotspot"})

	wlan0.EXPECT().GetPropertyManaged().Return(true, nil)
	wlan0.EXPECT().GetPropertyWirelessCapabilities().Return(nmWiFiDeviceCapAP, nil)
	wlan1.EXPECT().GetPropertyManaged().Return(true, nil)
	wlan1.EXPECT().GetPropertyWirelessCapabilities().Return(nmWiFiDeviceCapAP, nil)
	mockNM.EXPECT().GetPropertyActiveConnections().Return([]gonetworkmanager.ActiveConnection{mockActive}, nil).Once()
	mockActive.EXPECT().GetPropertyType().Return("802-11-wireless", nil).Once()
	mockActive.EXPECT().GetPropertyConnection().Return(mockConn, nil).Once()
	mockConn.EXPECT().GetSettings().Return(dmsSettings, nil).Once()
	mockActive.EXPECT().GetPropertyDevices().Return([]gonetworkmanager.Device{wlan0}, nil).Once()
	wlan0.EXPECT().GetPath().Return(dbus.ObjectPath("/org/freedesktop/NetworkManager/Devices/1"))
	wlan1.EXPECT().GetPath().Return(dbus.ObjectPath("/org/freedesktop/NetworkManager/Devices/2"))
	wlan1.EXPECT().GetPropertyState().Return(gonetworkmanager.NmDeviceStateDisconnected, nil).Once()

	devInfo, err := backend.getAPCapableWiFiDevice("", "")
	require.NoError(t, err)
	assert.Equal(t, "wlan0", devInfo.name, "the radio already hosting the DMS hotspot keeps the preference")
}

func TestConfigureHotspotRejectsNonAPCapableDevice(t *testing.T) {
	mockNM := mock_gonetworkmanager.NewMockNetworkManager(t)
	mockWiFi := mock_gonetworkmanager.NewMockDeviceWireless(t)

	backend, err := NewNetworkManagerBackend(mockNM)
	require.NoError(t, err)
	backend.wifiDevices = map[string]*wifiDeviceInfo{
		"wlan0": {device: mockWiFi, wireless: mockWiFi, name: "wlan0"},
	}

	mockWiFi.EXPECT().GetPropertyManaged().Return(true, nil)
	mockWiFi.EXPECT().GetPropertyWirelessCapabilities().Return(uint32(0), nil)

	err = backend.ConfigureHotspot(HotspotRequest{SSID: "DMS Hotspot", Device: "wlan0"})
	assert.Error(t, err)
	assert.Contains(t, err.Error(), "not hotspot-capable")
}

func TestConfigureHotspotRejectsChangesWhileActive(t *testing.T) {
	tests := []struct {
		name       string
		enabled    bool
		activating bool
	}{
		{name: "enabled", enabled: true},
		{name: "activating", activating: true},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			mockNM := mock_gonetworkmanager.NewMockNetworkManager(t)
			backend, err := NewNetworkManagerBackend(mockNM)
			require.NoError(t, err)
			backend.state.HotspotEnabled = tt.enabled
			backend.state.HotspotActivating = tt.activating

			err = backend.ConfigureHotspot(HotspotRequest{SSID: "DMS Hotspot"})
			assert.ErrorContains(t, err, "stop the hotspot")
		})
	}
}

func TestConfigureHotspotRejectsKnownIncompatibleAutoBand(t *testing.T) {
	mockNM := mock_gonetworkmanager.NewMockNetworkManager(t)
	mockWiFi := mock_gonetworkmanager.NewMockDeviceWireless(t)

	backend, err := NewNetworkManagerBackend(mockNM)
	require.NoError(t, err)
	backend.wifiDevices = map[string]*wifiDeviceInfo{
		"wlan0": {device: mockWiFi, wireless: mockWiFi, name: "wlan0"},
	}

	mockWiFi.EXPECT().GetPropertyManaged().Return(true, nil).Once()
	mockWiFi.EXPECT().GetPropertyWirelessCapabilities().Return(nmWiFiDeviceCapAP|nmWiFiDeviceCapFreqValid|nmWiFiDeviceCapFreq2GHz, nil).Twice()

	err = backend.ConfigureHotspot(HotspotRequest{SSID: "DMS Hotspot", Band: "a"})
	assert.ErrorContains(t, err, "does not support 5GHz")
}

func TestConfigureHotspotAllowsAutoDeviceWithoutCurrentAPCapableDevice(t *testing.T) {
	mockNM := mock_gonetworkmanager.NewMockNetworkManager(t)
	mockSettings := mock_gonetworkmanager.NewMockSettings(t)
	mockConn := mock_gonetworkmanager.NewMockConnection(t)

	backend, err := NewNetworkManagerBackend(mockNM)
	require.NoError(t, err)
	backend.settings = mockSettings
	backend.wifiDevices = map[string]*wifiDeviceInfo{}

	var stateChangeCalls int
	backend.onStateChange = func() {
		stateChangeCalls++
	}

	req := HotspotRequest{SSID: "DMS Hotspot", Password: "hunter2-password", Band: "a"}
	expectedSettings := buildHotspotSettings(req)

	mockSettings.EXPECT().ListConnections().Return([]gonetworkmanager.Connection{}, nil).Once()
	mockSettings.EXPECT().AddConnection(expectedSettings).Return(mockConn, nil).Once()
	mockSettings.EXPECT().ListConnections().Return([]gonetworkmanager.Connection{mockConn}, nil).Once()
	mockConn.EXPECT().GetSettings().Return(expectedSettings, nil).Once()
	mockNM.EXPECT().GetPropertyActiveConnections().Return([]gonetworkmanager.ActiveConnection{}, nil).Once()

	err = backend.ConfigureHotspot(req)
	require.NoError(t, err)
	assert.Equal(t, 0, stateChangeCalls)

	backend.stateMutex.RLock()
	defer backend.stateMutex.RUnlock()
	assert.False(t, backend.state.HotspotAvailable)
	assert.True(t, backend.state.HotspotConfigured)
	assert.False(t, backend.state.HotspotEnabled)
	assert.Equal(t, "DMS Hotspot", backend.state.HotspotSSID)
	assert.Empty(t, backend.state.HotspotDevice)
}

func TestConfigureHotspotCreatesDMSProfile(t *testing.T) {
	mockNM := mock_gonetworkmanager.NewMockNetworkManager(t)
	mockSettings := mock_gonetworkmanager.NewMockSettings(t)
	mockWiFi := mock_gonetworkmanager.NewMockDeviceWireless(t)
	mockConn := mock_gonetworkmanager.NewMockConnection(t)

	backend, err := NewNetworkManagerBackend(mockNM)
	require.NoError(t, err)
	backend.settings = mockSettings
	backend.wifiDevices = map[string]*wifiDeviceInfo{
		"wlan0": {device: mockWiFi, wireless: mockWiFi, name: "wlan0"},
	}

	req := HotspotRequest{SSID: "DMS Hotspot", Password: "hunter2-password", Device: "wlan0"}
	expectedSettings := buildHotspotSettings(req)

	mockWiFi.EXPECT().GetPropertyManaged().Return(true, nil).Twice()
	mockWiFi.EXPECT().GetPropertyWirelessCapabilities().Return(nmWiFiDeviceCapAP, nil).Twice()
	mockSettings.EXPECT().ListConnections().Return([]gonetworkmanager.Connection{}, nil).Once()
	mockSettings.EXPECT().AddConnection(expectedSettings).Return(mockConn, nil).Once()
	mockSettings.EXPECT().ListConnections().Return([]gonetworkmanager.Connection{mockConn}, nil).Once()
	mockConn.EXPECT().GetSettings().Return(expectedSettings, nil).Once()
	mockNM.EXPECT().GetPropertyActiveConnections().Return([]gonetworkmanager.ActiveConnection{}, nil).Once()

	err = backend.ConfigureHotspot(req)
	require.NoError(t, err)

	backend.stateMutex.RLock()
	defer backend.stateMutex.RUnlock()
	assert.True(t, backend.state.HotspotAvailable)
	assert.True(t, backend.state.HotspotConfigured)
	assert.False(t, backend.state.HotspotEnabled)
	assert.Equal(t, "DMS Hotspot", backend.state.HotspotSSID)
	assert.Equal(t, "wlan0", backend.state.HotspotDevice)
}

func TestGetSavedWiFiProfilesFiltersAPModeProfiles(t *testing.T) {
	clientConn := mock_gonetworkmanager.NewMockConnection(t)
	dmsHotspotConn := mock_gonetworkmanager.NewMockConnection(t)
	userHotspotConn := mock_gonetworkmanager.NewMockConnection(t)

	clientSettings := gonetworkmanager.ConnectionSettings{
		"connection": {
			"type":        "802-11-wireless",
			"autoconnect": true,
		},
		"802-11-wireless": {
			"mode": "infrastructure",
			"ssid": []byte("Home WiFi"),
		},
	}
	dmsSettings := buildHotspotSettings(HotspotRequest{SSID: "DMS Hotspot"})
	userAPSettings := gonetworkmanager.ConnectionSettings{
		"connection": {
			"type": "802-11-wireless",
			"id":   "User AP",
		},
		"802-11-wireless": {
			"mode": "ap",
			"ssid": []byte("User AP"),
		},
	}

	clientConn.EXPECT().GetSettings().Return(clientSettings, nil).Once()
	dmsHotspotConn.EXPECT().GetSettings().Return(dmsSettings, nil).Once()
	userHotspotConn.EXPECT().GetSettings().Return(userAPSettings, nil).Once()

	profiles := getSavedWiFiProfiles([]gonetworkmanager.Connection{clientConn, dmsHotspotConn, userHotspotConn})

	assert.Contains(t, profiles, "Home WiFi")
	assert.NotContains(t, profiles, "DMS Hotspot")
	assert.NotContains(t, profiles, "User AP")
}

func TestUpdateWiFiNetworksFiltersAPModeAccessPoints(t *testing.T) {
	mockNM := mock_gonetworkmanager.NewMockNetworkManager(t)
	mockSettings := mock_gonetworkmanager.NewMockSettings(t)
	mockWiFi := mock_gonetworkmanager.NewMockDeviceWireless(t)
	mockAP := mock_gonetworkmanager.NewMockAccessPoint(t)

	backend, err := NewNetworkManagerBackend(mockNM)
	require.NoError(t, err)
	backend.settings = mockSettings
	backend.wifiDevice = mockWiFi
	backend.wifiDev = mockWiFi

	mockWiFi.EXPECT().GetAccessPoints().Return([]gonetworkmanager.AccessPoint{mockAP}, nil).Once()
	mockSettings.EXPECT().ListConnections().Return([]gonetworkmanager.Connection{}, nil).Once()
	mockAP.EXPECT().GetPropertySSID().Return("DMS Hotspot", nil).Once()
	mockAP.EXPECT().GetPropertyMode().Return(gonetworkmanager.Nm80211ModeAp, nil).Once()

	networks, err := backend.updateWiFiNetworks()
	require.NoError(t, err)
	assert.Empty(t, networks)

	backend.stateMutex.RLock()
	defer backend.stateMutex.RUnlock()
	assert.Empty(t, backend.state.WiFiNetworks)
	assert.Empty(t, backend.state.SavedWiFiNetworks)
}

func TestFindConnectionIgnoresAPModeProfiles(t *testing.T) {
	mockNM := mock_gonetworkmanager.NewMockNetworkManager(t)
	mockSettings := mock_gonetworkmanager.NewMockSettings(t)
	dmsHotspotConn := mock_gonetworkmanager.NewMockConnection(t)
	clientConn := mock_gonetworkmanager.NewMockConnection(t)

	backend, err := NewNetworkManagerBackend(mockNM)
	require.NoError(t, err)
	backend.settings = mockSettings

	dmsSettings := buildHotspotSettings(HotspotRequest{SSID: "Shared SSID"})
	clientSettings := gonetworkmanager.ConnectionSettings{
		"connection": {
			"type": "802-11-wireless",
			"id":   "Shared SSID",
		},
		"802-11-wireless": {
			"mode": "infrastructure",
			"ssid": []byte("Shared SSID"),
		},
	}

	mockSettings.EXPECT().ListConnections().Return([]gonetworkmanager.Connection{dmsHotspotConn, clientConn}, nil).Once()
	dmsHotspotConn.EXPECT().GetSettings().Return(dmsSettings, nil).Once()
	clientConn.EXPECT().GetSettings().Return(clientSettings, nil).Once()

	conn, err := backend.findConnection("Shared SSID")
	require.NoError(t, err)
	assert.Same(t, clientConn, conn)
}

func TestFindConnectionReturnsNotFoundForDMSHotspotOnly(t *testing.T) {
	mockNM := mock_gonetworkmanager.NewMockNetworkManager(t)
	mockSettings := mock_gonetworkmanager.NewMockSettings(t)
	dmsHotspotConn := mock_gonetworkmanager.NewMockConnection(t)

	backend, err := NewNetworkManagerBackend(mockNM)
	require.NoError(t, err)
	backend.settings = mockSettings

	dmsSettings := buildHotspotSettings(HotspotRequest{SSID: "DMS Hotspot"})

	mockSettings.EXPECT().ListConnections().Return([]gonetworkmanager.Connection{dmsHotspotConn}, nil).Once()
	dmsHotspotConn.EXPECT().GetSettings().Return(dmsSettings, nil).Once()

	_, err = backend.findConnection("DMS Hotspot")
	assert.Error(t, err)
}

func TestFindActiveDMSHotspotConnectionIgnoresUserAPProfiles(t *testing.T) {
	mockNM := mock_gonetworkmanager.NewMockNetworkManager(t)
	userConn := mock_gonetworkmanager.NewMockConnection(t)
	dmsConn := mock_gonetworkmanager.NewMockConnection(t)
	userActive := mock_gonetworkmanager.NewMockActiveConnection(t)
	dmsActive := mock_gonetworkmanager.NewMockActiveConnection(t)

	backend, err := NewNetworkManagerBackend(mockNM)
	require.NoError(t, err)

	userSettings := gonetworkmanager.ConnectionSettings{
		"connection": {
			"type": "802-11-wireless",
			"id":   dmsHotspotConnectionID,
		},
		"802-11-wireless": {
			"mode": "ap",
			"ssid": []byte("DMS Hotspot"),
		},
	}
	dmsSettings := buildHotspotSettings(HotspotRequest{SSID: "DMS Hotspot"})

	mockNM.EXPECT().GetPropertyActiveConnections().Return([]gonetworkmanager.ActiveConnection{userActive, dmsActive}, nil).Once()
	userActive.EXPECT().GetPropertyType().Return("802-11-wireless", nil).Once()
	userActive.EXPECT().GetPropertyConnection().Return(userConn, nil).Once()
	userConn.EXPECT().GetSettings().Return(userSettings, nil).Once()
	dmsActive.EXPECT().GetPropertyType().Return("802-11-wireless", nil).Once()
	dmsActive.EXPECT().GetPropertyConnection().Return(dmsConn, nil).Once()
	dmsConn.EXPECT().GetSettings().Return(dmsSettings, nil).Once()

	active, err := backend.findActiveDMSHotspotConnection()
	require.NoError(t, err)
	assert.Same(t, dmsActive, active)
}

func TestUpdateWiFiStateSuppressesActiveAPModeConnection(t *testing.T) {
	mockNM := mock_gonetworkmanager.NewMockNetworkManager(t)
	mockWiFi := mock_gonetworkmanager.NewMockDeviceWireless(t)
	mockConn := mock_gonetworkmanager.NewMockConnection(t)
	mockActive := mock_gonetworkmanager.NewMockActiveConnection(t)

	backend, err := NewNetworkManagerBackend(mockNM)
	require.NoError(t, err)
	backend.wifiDevice = mockWiFi
	backend.wifiDev = mockWiFi

	dmsSettings := buildHotspotSettings(HotspotRequest{SSID: "DMS Hotspot"})

	mockWiFi.EXPECT().GetPropertyInterface().Return("wlan0", nil).Once()
	mockWiFi.EXPECT().GetPropertyState().Return(gonetworkmanager.NmDeviceStateActivated, nil).Once()
	mockWiFi.EXPECT().GetPath().Return("/org/freedesktop/NetworkManager/Devices/1").Twice()
	mockNM.EXPECT().GetPropertyActiveConnections().Return([]gonetworkmanager.ActiveConnection{mockActive}, nil).Once()
	mockActive.EXPECT().GetPropertyType().Return("802-11-wireless", nil).Once()
	mockActive.EXPECT().GetPropertyConnection().Return(mockConn, nil).Once()
	mockConn.EXPECT().GetSettings().Return(dmsSettings, nil).Once()
	mockActive.EXPECT().GetPropertyDevices().Return([]gonetworkmanager.Device{mockWiFi}, nil).Once()

	err = backend.updateWiFiState()
	require.NoError(t, err)

	backend.stateMutex.RLock()
	defer backend.stateMutex.RUnlock()
	assert.Equal(t, "wlan0", backend.state.WiFiDevice)
	assert.False(t, backend.state.WiFiConnected)
	assert.Empty(t, backend.state.WiFiSSID)
	assert.Empty(t, backend.state.WiFiIP)
}

func TestUpdateAllWiFiDevicesSuppressesActiveAPModeConnection(t *testing.T) {
	mockNM := mock_gonetworkmanager.NewMockNetworkManager(t)
	mockSettings := mock_gonetworkmanager.NewMockSettings(t)
	mockWiFi := mock_gonetworkmanager.NewMockDeviceWireless(t)
	mockConn := mock_gonetworkmanager.NewMockConnection(t)
	mockActive := mock_gonetworkmanager.NewMockActiveConnection(t)

	backend, err := NewNetworkManagerBackend(mockNM)
	require.NoError(t, err)
	backend.settings = mockSettings
	backend.wifiDevices = map[string]*wifiDeviceInfo{
		"wlan0": {device: mockWiFi, wireless: mockWiFi, name: "wlan0", hwAddress: "00:11:22:33:44:55"},
	}

	dmsSettings := buildHotspotSettings(HotspotRequest{SSID: "DMS Hotspot"})

	mockSettings.EXPECT().ListConnections().Return([]gonetworkmanager.Connection{}, nil).Once()
	mockWiFi.EXPECT().GetPropertyState().Return(gonetworkmanager.NmDeviceStateActivated, nil).Once()
	mockWiFi.EXPECT().GetPath().Return("/org/freedesktop/NetworkManager/Devices/1").Twice()
	mockNM.EXPECT().GetPropertyActiveConnections().Return([]gonetworkmanager.ActiveConnection{mockActive}, nil).Once()
	mockActive.EXPECT().GetPropertyType().Return("802-11-wireless", nil).Once()
	mockActive.EXPECT().GetPropertyConnection().Return(mockConn, nil).Once()
	mockConn.EXPECT().GetSettings().Return(dmsSettings, nil).Once()
	mockActive.EXPECT().GetPropertyDevices().Return([]gonetworkmanager.Device{mockWiFi}, nil).Once()
	mockWiFi.EXPECT().GetAccessPoints().Return([]gonetworkmanager.AccessPoint{}, nil).Once()
	mockWiFi.EXPECT().GetPropertyManaged().Return(true, nil).Once()
	mockWiFi.EXPECT().GetPropertyWirelessCapabilities().Return(nmWiFiDeviceCapAP, nil).Once()

	backend.updateAllWiFiDevices()

	backend.stateMutex.RLock()
	defer backend.stateMutex.RUnlock()
	require.Len(t, backend.state.WiFiDevices, 1)
	device := backend.state.WiFiDevices[0]
	assert.Equal(t, "wlan0", device.Name)
	assert.Equal(t, "disconnected", device.State)
	assert.False(t, device.Connected)
	assert.Empty(t, device.SSID)
}

func TestUpdateHotspotStateDetectsRunningDMSHotspot(t *testing.T) {
	mockNM := mock_gonetworkmanager.NewMockNetworkManager(t)
	mockSettings := mock_gonetworkmanager.NewMockSettings(t)
	mockWiFi := mock_gonetworkmanager.NewMockDeviceWireless(t)
	mockConn := mock_gonetworkmanager.NewMockConnection(t)
	mockActive := mock_gonetworkmanager.NewMockActiveConnection(t)

	backend, err := NewNetworkManagerBackend(mockNM)
	require.NoError(t, err)
	backend.settings = mockSettings
	backend.wifiDevices = map[string]*wifiDeviceInfo{
		"wlan0": {device: mockWiFi, wireless: mockWiFi, name: "wlan0"},
	}

	settings := buildHotspotSettings(HotspotRequest{SSID: "DMS Hotspot", Device: "wlan0", Band: "bg"})

	mockWiFi.EXPECT().GetPropertyManaged().Return(true, nil).Once()
	mockWiFi.EXPECT().GetPropertyWirelessCapabilities().Return(nmWiFiDeviceCapAP, nil).Once()
	mockSettings.EXPECT().ListConnections().Return([]gonetworkmanager.Connection{mockConn}, nil).Once()
	mockConn.EXPECT().GetSettings().Return(settings, nil).Twice()
	mockNM.EXPECT().GetPropertyActiveConnections().Return([]gonetworkmanager.ActiveConnection{mockActive}, nil).Once()
	mockActive.EXPECT().GetPropertyType().Return("802-11-wireless", nil).Once()
	mockActive.EXPECT().GetPropertyConnection().Return(mockConn, nil).Once()
	mockActive.EXPECT().GetPropertyState().Return(gonetworkmanager.NmActiveConnectionStateActivated, nil).Once()

	err = backend.updateHotspotState()
	require.NoError(t, err)

	backend.stateMutex.RLock()
	defer backend.stateMutex.RUnlock()
	assert.True(t, backend.state.HotspotAvailable)
	assert.True(t, backend.state.HotspotConfigured)
	assert.True(t, backend.state.HotspotEnabled)
	assert.Equal(t, "DMS Hotspot", backend.state.HotspotSSID)
	assert.Equal(t, "wlan0", backend.state.HotspotDevice)
	assert.Equal(t, "bg", backend.state.HotspotBand)
}

func TestUpdateHotspotStateReportsActivating(t *testing.T) {
	mockNM := mock_gonetworkmanager.NewMockNetworkManager(t)
	mockSettings := mock_gonetworkmanager.NewMockSettings(t)
	mockWiFi := mock_gonetworkmanager.NewMockDeviceWireless(t)
	mockConn := mock_gonetworkmanager.NewMockConnection(t)
	mockActive := mock_gonetworkmanager.NewMockActiveConnection(t)

	backend, err := NewNetworkManagerBackend(mockNM)
	require.NoError(t, err)
	backend.settings = mockSettings
	backend.wifiDevices = map[string]*wifiDeviceInfo{
		"wlan0": {device: mockWiFi, wireless: mockWiFi, name: "wlan0"},
	}

	settings := buildHotspotSettings(HotspotRequest{SSID: "DMS Hotspot", Device: "wlan0", Band: "bg"})

	mockWiFi.EXPECT().GetPropertyManaged().Return(true, nil).Once()
	mockWiFi.EXPECT().GetPropertyWirelessCapabilities().Return(nmWiFiDeviceCapAP, nil).Once()
	mockSettings.EXPECT().ListConnections().Return([]gonetworkmanager.Connection{mockConn}, nil).Once()
	mockConn.EXPECT().GetSettings().Return(settings, nil).Twice()
	mockNM.EXPECT().GetPropertyActiveConnections().Return([]gonetworkmanager.ActiveConnection{mockActive}, nil).Once()
	mockActive.EXPECT().GetPropertyType().Return("802-11-wireless", nil).Once()
	mockActive.EXPECT().GetPropertyConnection().Return(mockConn, nil).Once()
	mockActive.EXPECT().GetPropertyState().Return(gonetworkmanager.NmActiveConnectionStateActivating, nil).Once()

	err = backend.updateHotspotState()
	require.NoError(t, err)

	backend.stateMutex.RLock()
	defer backend.stateMutex.RUnlock()
	assert.False(t, backend.state.HotspotEnabled)
	assert.True(t, backend.state.HotspotActivating)
	assert.Empty(t, backend.state.HotspotLastError)
}

func TestUpdateHotspotStateReportsActivationFailure(t *testing.T) {
	mockNM := mock_gonetworkmanager.NewMockNetworkManager(t)
	mockSettings := mock_gonetworkmanager.NewMockSettings(t)
	mockWiFi := mock_gonetworkmanager.NewMockDeviceWireless(t)
	mockConn := mock_gonetworkmanager.NewMockConnection(t)

	backend, err := NewNetworkManagerBackend(mockNM)
	require.NoError(t, err)
	backend.settings = mockSettings
	backend.wifiDevices = map[string]*wifiDeviceInfo{
		"wlan0": {device: mockWiFi, wireless: mockWiFi, name: "wlan0"},
	}

	backend.stateMutex.Lock()
	backend.state.HotspotActivating = true
	backend.hotspotPendingDevice = "wlan1"
	backend.stateMutex.Unlock()

	settings := buildHotspotSettings(HotspotRequest{SSID: "DMS Hotspot", Device: "wlan0", Band: "bg"})

	mockWiFi.EXPECT().GetPropertyManaged().Return(true, nil).Once()
	mockWiFi.EXPECT().GetPropertyWirelessCapabilities().Return(nmWiFiDeviceCapAP, nil).Once()
	mockSettings.EXPECT().ListConnections().Return([]gonetworkmanager.Connection{mockConn}, nil).Once()
	mockConn.EXPECT().GetSettings().Return(settings, nil).Once()
	mockNM.EXPECT().GetPropertyActiveConnections().Return(nil, nil).Once()

	err = backend.updateHotspotState()
	require.NoError(t, err)

	backend.stateMutex.RLock()
	defer backend.stateMutex.RUnlock()
	assert.False(t, backend.state.HotspotEnabled)
	assert.False(t, backend.state.HotspotActivating)
	assert.Equal(t, "hotspot-failed", backend.state.HotspotLastError)
	assert.Empty(t, backend.hotspotPendingDevice)
}

func TestClassifyHotspotStateReason(t *testing.T) {
	// Raw value pinned on purpose: 5 is what NetworkManager reports for the
	// missing-dnsmasq failure ('ip-config-unavailable'), and package-local
	// aliases with the same names carry different, incorrect values.
	assert.Equal(t, "hotspot-ip-config-failed", classifyHotspotStateReason(5))
	assert.Equal(t, "hotspot-ip-config-failed", classifyHotspotStateReason(gonetworkmanager.NmDeviceStateReasonSharedStartFailed))
	assert.Equal(t, "hotspot-ip-config-failed", classifyHotspotStateReason(gonetworkmanager.NmDeviceStateReasonDhcpFailed))
	assert.Equal(t, "hotspot-supplicant-failed", classifyHotspotStateReason(gonetworkmanager.NmDeviceStateReasonSupplicantFailed))
	assert.Equal(t, "hotspot-supplicant-failed", classifyHotspotStateReason(gonetworkmanager.NmDeviceStateReasonSupplicantDisconnect))
	assert.Equal(t, "hotspot-failed", classifyHotspotStateReason(gonetworkmanager.NmDeviceStateReasonModemNoCarrier))
}

func TestHotspotSecuredFromSettings(t *testing.T) {
	secured := buildHotspotSettings(HotspotRequest{SSID: "DMS Hotspot", Password: "hunter2-password"})
	assert.True(t, hotspotSecuredFromSettings(secured))

	open := buildHotspotSettings(HotspotRequest{SSID: "DMS Hotspot"})
	assert.False(t, hotspotSecuredFromSettings(open))

	assert.False(t, hotspotSecuredFromSettings(nil))
}

func TestGetHotspotSecrets(t *testing.T) {
	t.Run("secured profile returns psk", func(t *testing.T) {
		mockNM := mock_gonetworkmanager.NewMockNetworkManager(t)
		mockSettings := mock_gonetworkmanager.NewMockSettings(t)
		mockConn := mock_gonetworkmanager.NewMockConnection(t)

		backend, err := NewNetworkManagerBackend(mockNM)
		require.NoError(t, err)
		backend.settings = mockSettings

		settings := buildHotspotSettings(HotspotRequest{SSID: "DMS Hotspot", Password: "hunter2-password"})

		mockSettings.EXPECT().ListConnections().Return([]gonetworkmanager.Connection{mockConn}, nil).Once()
		mockConn.EXPECT().GetSettings().Return(settings, nil).Once()
		mockConn.EXPECT().GetSecrets("802-11-wireless-security").Return(gonetworkmanager.ConnectionSettings{
			"802-11-wireless-security": {"psk": "hunter2-password"},
		}, nil).Once()

		password, err := backend.GetHotspotSecrets()
		require.NoError(t, err)
		assert.Equal(t, "hunter2-password", password)
	})

	t.Run("open profile skips secrets lookup", func(t *testing.T) {
		mockNM := mock_gonetworkmanager.NewMockNetworkManager(t)
		mockSettings := mock_gonetworkmanager.NewMockSettings(t)
		mockConn := mock_gonetworkmanager.NewMockConnection(t)

		backend, err := NewNetworkManagerBackend(mockNM)
		require.NoError(t, err)
		backend.settings = mockSettings

		settings := buildHotspotSettings(HotspotRequest{SSID: "DMS Hotspot"})

		mockSettings.EXPECT().ListConnections().Return([]gonetworkmanager.Connection{mockConn}, nil).Once()
		mockConn.EXPECT().GetSettings().Return(settings, nil).Once()

		password, err := backend.GetHotspotSecrets()
		require.NoError(t, err)
		assert.Empty(t, password)
	})

	t.Run("unconfigured returns error", func(t *testing.T) {
		mockNM := mock_gonetworkmanager.NewMockNetworkManager(t)
		mockSettings := mock_gonetworkmanager.NewMockSettings(t)

		backend, err := NewNetworkManagerBackend(mockNM)
		require.NoError(t, err)
		backend.settings = mockSettings

		mockSettings.EXPECT().ListConnections().Return(nil, nil).Once()

		_, err = backend.GetHotspotSecrets()
		assert.Error(t, err)
	})
}

func TestValidateHotspotPassword(t *testing.T) {
	hex64 := strings.Repeat("0123456789abcdef", 4)
	cases := []struct {
		name     string
		password string
		valid    bool
	}{
		{"open network", "", true},
		{"three digits", "123", false},
		{"seven chars", "testing", false},
		{"eight chars", "testing1", true},
		{"sixty three chars", strings.Repeat("a", 63), true},
		{"sixty four hex", hex64, true},
		{"sixty four hex uppercase", strings.ToUpper(hex64), true},
		{"sixty four non-hex", strings.Repeat("g", 64), false},
		{"sixty five chars", strings.Repeat("a", 65), false},
		{"multibyte counts bytes", "ääää", true},
	}

	for _, tc := range cases {
		t.Run(tc.name, func(t *testing.T) {
			err := validateHotspotPassword(tc.password)
			if tc.valid {
				assert.NoError(t, err)
				return
			}
			require.Error(t, err)
			assert.Contains(t, err.Error(), "8 to 63 characters")
		})
	}
}

func TestConfigureHotspotRejectsShortPasswordBeforeTouchingNetworkManager(t *testing.T) {
	mockNM := mock_gonetworkmanager.NewMockNetworkManager(t)
	mockSettings := mock_gonetworkmanager.NewMockSettings(t)

	backend, err := NewNetworkManagerBackend(mockNM)
	require.NoError(t, err)
	backend.settings = mockSettings

	err = backend.ConfigureHotspot(HotspotRequest{SSID: "DMS Hotspot", Password: "123", Device: "wlan0"})
	require.Error(t, err)
	assert.Contains(t, err.Error(), "8 to 63 characters")
}

const testHotspotPath = dbus.ObjectPath("/org/freedesktop/NetworkManager/Settings/7")

const testHotspotPSK = "dms-ap-psk-1"

func storedHotspotSettings() nmSettings {
	return nmSettings{
		"connection": {
			"id":             dbus.MakeVariant(dmsHotspotConnectionID),
			"uuid":           dbus.MakeVariant("hotspot-uuid"),
			"type":           dbus.MakeVariant("802-11-wireless"),
			"stable-id":      dbus.MakeVariant(dmsHotspotStableID),
			"autoconnect":    dbus.MakeVariant(false),
			"interface-name": dbus.MakeVariant("wlan0"),
			"metered":        dbus.MakeVariant(int32(1)),
		},
		"802-11-wireless": {
			"ssid":      dbus.MakeVariant([]byte("old")),
			"mode":      dbus.MakeVariant("ap"),
			"band":      dbus.MakeVariant("bg"),
			"channel":   dbus.MakeVariant(uint32(6)),
			"powersave": dbus.MakeVariant(uint32(2)),
			"hidden":    dbus.MakeVariant(true),
			"security":  dbus.MakeVariant("802-11-wireless-security"),
		},
		"802-11-wireless-security": {
			"key-mgmt":  dbus.MakeVariant("wpa-psk"),
			"psk-flags": dbus.MakeVariant(uint32(0)),
		},
		"ipv4": {
			"method":       dbus.MakeVariant("shared"),
			"addresses":    dbus.MakeVariant([][]uint32{{0x01002b0a, 24, 0}}),
			"address-data": dbus.MakeVariant([]map[string]dbus.Variant{{"address": dbus.MakeVariant("10.43.0.1"), "prefix": dbus.MakeVariant(uint32(24))}}),
		},
		"ipv6": {"method": dbus.MakeVariant("ignore")},
	}
}

// configureExistingHotspot runs ConfigureHotspot against a stored DMS hotspot
// and returns the settings sent with Update2.
func configureExistingHotspot(t *testing.T, req HotspotRequest) nmSettings {
	t.Helper()
	mockNM := mock_gonetworkmanager.NewMockNetworkManager(t)
	mockSettings := mock_gonetworkmanager.NewMockSettings(t)
	mockConn := mock_gonetworkmanager.NewMockConnection(t)
	obj := mock_dbus.NewMockBusObject(t)

	backend, err := NewNetworkManagerBackend(mockNM)
	require.NoError(t, err)
	backend.settings = mockSettings
	backend.wifiDevices = map[string]*wifiDeviceInfo{}
	backend.nmObjectFn = func(p dbus.ObjectPath) dbus.BusObject {
		assert.Equal(t, testHotspotPath, p)
		return obj
	}

	listed := buildHotspotSettings(HotspotRequest{SSID: "old", Band: "bg"})
	mockSettings.EXPECT().ListConnections().Return([]gonetworkmanager.Connection{mockConn}, nil)
	mockConn.EXPECT().GetSettings().Return(listed, nil)
	mockConn.EXPECT().GetPath().Return(testHotspotPath)
	mockNM.EXPECT().GetPropertyActiveConnections().Return([]gonetworkmanager.ActiveConnection{}, nil).Maybe()

	expectGetSettings(obj, storedHotspotSettings())
	expectGetSecrets(obj, "802-11-wireless-security", nmSettings{
		"802-11-wireless-security": {"psk": dbus.MakeVariant("stored-psk")},
	})
	got := captureUpdate2(obj, nmUpdate2FlagToDisk, nil)

	require.NoError(t, backend.ConfigureHotspot(req))
	return *got
}

func TestConfigureHotspotUpdatesExistingProfileInPlace(t *testing.T) {
	got := configureExistingHotspot(t, HotspotRequest{
		SSID: "dms-ap", Password: testHotspotPSK, Band: "a", Channel: 36, Address: "10.43.0.1/24",
	})

	assert.Equal(t, "hotspot-uuid", got["connection"]["uuid"].Value())
	assert.Equal(t, int32(1), got["connection"]["metered"].Value())
	assert.Equal(t, dmsHotspotConnectionID, got["connection"]["id"].Value())
	assert.NotContains(t, got["connection"], "interface-name")

	wifi := got["802-11-wireless"]
	assert.Equal(t, uint32(2), wifi["powersave"].Value())
	assert.Equal(t, true, wifi["hidden"].Value())
	assert.Equal(t, []byte("dms-ap"), wifi["ssid"].Value())
	assert.Equal(t, "ap", wifi["mode"].Value())
	assert.Equal(t, "a", wifi["band"].Value())
	assert.Equal(t, uint32(36), wifi["channel"].Value())
	assert.Equal(t, "802-11-wireless-security", wifi["security"].Value())

	sec := got["802-11-wireless-security"]
	assert.Equal(t, "wpa-psk", sec["key-mgmt"].Value())
	assert.Equal(t, testHotspotPSK, sec["psk"].Value())
	assert.Equal(t, uint32(0), sec["psk-flags"].Value())

	assert.Equal(t, "shared", got["ipv4"]["method"].Value())
	assert.Equal(t, []map[string]dbus.Variant{{
		"address": dbus.MakeVariant("10.43.0.1"),
		"prefix":  dbus.MakeVariant(uint32(24)),
	}}, got["ipv4"]["address-data"].Value())
	assert.NotContains(t, got["ipv4"], "addresses")
	assert.Equal(t, "ignore", got["ipv6"]["method"].Value())
}

func TestConfigureHotspotOpenWithDefaultRangeDropsSecurityAndAddress(t *testing.T) {
	got := configureExistingHotspot(t, HotspotRequest{SSID: "dms-ap"})

	assert.NotContains(t, got, "802-11-wireless-security")
	assert.NotContains(t, got["802-11-wireless"], "security")
	assert.NotContains(t, got["802-11-wireless"], "band")
	assert.NotContains(t, got["802-11-wireless"], "channel")
	assert.NotContains(t, got["ipv4"], "address-data")
	assert.NotContains(t, got["ipv4"], "addresses")
	assert.Equal(t, "shared", got["ipv4"]["method"].Value())
	assert.Equal(t, uint32(2), got["802-11-wireless"]["powersave"].Value())
}

func TestConfigureHotspotRejectsBadChannelAndAddressBeforeDBus(t *testing.T) {
	tests := []struct {
		name string
		req  HotspotRequest
		want string
	}{
		{"channel without band", HotspotRequest{SSID: "x", Channel: 36}, "channel requires a band"},
		{"bg channel too high", HotspotRequest{SSID: "x", Band: "bg", Channel: 36}, "channel 36"},
		{"a channel too high", HotspotRequest{SSID: "x", Band: "a", Channel: 200}, "channel 200"},
		{"network address", HotspotRequest{SSID: "x", Address: "10.43.0.0/24"}, "10.43.0.0/24"},
		{"broadcast address", HotspotRequest{SSID: "x", Address: "10.43.0.255/24"}, "10.43.0.255/24"},
		{"ipv6", HotspotRequest{SSID: "x", Address: "fd00::1/64"}, "fd00::1/64"},
		{"prefix too long", HotspotRequest{SSID: "x", Address: "10.43.0.1/31"}, "10.43.0.1/31"},
		{"prefix too short", HotspotRequest{SSID: "x", Address: "10.43.0.1/7"}, "10.43.0.1/7"},
		{"garbage", HotspotRequest{SSID: "x", Address: "nope"}, "nope"},
	}
	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			backend, err := NewNetworkManagerBackend(mock_gonetworkmanager.NewMockNetworkManager(t))
			require.NoError(t, err)
			backend.settings = mock_gonetworkmanager.NewMockSettings(t)
			backend.nmObjectFn = func(dbus.ObjectPath) dbus.BusObject { return mock_dbus.NewMockBusObject(t) }

			assert.ErrorContains(t, backend.ConfigureHotspot(tt.req), tt.want)
		})
	}
}

func TestBuildHotspotSettingsChannelAndAddress(t *testing.T) {
	s := buildHotspotSettings(HotspotRequest{SSID: "x", Band: "bg", Channel: 11, Address: "192.168.50.1/24"})

	assert.Equal(t, uint32(11), s["802-11-wireless"]["channel"])
	assert.Equal(t, []map[string]any{{"address": "192.168.50.1", "prefix": uint32(24)}}, s["ipv4"]["address-data"])
	assert.Equal(t, "aa{sv}", dbus.SignatureOf(s["ipv4"]["address-data"]).String())

	open := buildHotspotSettings(HotspotRequest{SSID: "x"})
	assert.NotContains(t, open["802-11-wireless"], "channel")
	assert.NotContains(t, open["ipv4"], "address-data")
}

func TestUpdateHotspotStateReportsChannelAddressAndUUID(t *testing.T) {
	mockNM := mock_gonetworkmanager.NewMockNetworkManager(t)
	mockSettings := mock_gonetworkmanager.NewMockSettings(t)
	mockConn := mock_gonetworkmanager.NewMockConnection(t)

	backend, err := NewNetworkManagerBackend(mockNM)
	require.NoError(t, err)
	backend.settings = mockSettings
	backend.wifiDevices = map[string]*wifiDeviceInfo{}

	// GetSettings decodes aa{sv} into []map[string]any, as built here.
	stored := buildHotspotSettings(HotspotRequest{SSID: "x", Band: "a", Channel: 44, Address: "10.43.0.1/24"})
	stored["connection"]["uuid"] = "hotspot-uuid"
	mockSettings.EXPECT().ListConnections().Return([]gonetworkmanager.Connection{mockConn}, nil)
	mockConn.EXPECT().GetSettings().Return(stored, nil)
	mockNM.EXPECT().GetPropertyActiveConnections().Return([]gonetworkmanager.ActiveConnection{}, nil)

	require.NoError(t, backend.updateHotspotState())
	assert.Equal(t, uint32(44), backend.state.HotspotChannel)
	assert.Equal(t, "10.43.0.1/24", backend.state.HotspotAddress)
	assert.Equal(t, "hotspot-uuid", backend.state.HotspotUUID)

	delete(stored["802-11-wireless"], "channel")
	delete(stored["ipv4"], "address-data")
	require.NoError(t, backend.updateHotspotState())
	assert.Equal(t, uint32(0), backend.state.HotspotChannel)
	assert.Empty(t, backend.state.HotspotAddress)
}
