package network

import (
	"errors"
	"maps"
	"strings"
	"testing"

	mock_dbus "github.com/AvengeMedia/DankMaterialShell/core/internal/mocks/github.com/godbus/dbus/v5"
	"github.com/godbus/dbus/v5"
	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
)

func TestPreferenceUpdate(t *testing.T) {
	const wifi, eth = "802-11-wireless", "802-3-ethernet"
	tests := []struct {
		name       string
		connType   string
		pref       ConnectionPreference
		metric     int64
		priority   int32
		wantMetric int64
		wantMChg   bool
		wantPrio   int32
		wantPChg   bool
	}{
		{"wifi preferred from default", wifi, PreferenceWiFi, -1, 0, 100, true, 0, false},
		{"ethernet demoted from default", eth, PreferenceWiFi, -1, 0, 300, true, 0, false},
		{"custom metric untouched", eth, PreferenceWiFi, 50, 0, 0, false, 0, false},
		{"priority never changed when preferring", eth, PreferenceWiFi, -1, 100, 300, true, 0, false},
		{"already preferred", wifi, PreferenceWiFi, 100, 0, 0, false, 0, false},
		{"demoted to preferred", eth, PreferenceEthernet, 300, 0, 100, true, 0, false},
		{"gsm preferred for cellular", "gsm", PreferenceCellular, -1, 0, 100, true, 0, false},
		{"cdma demoted for wifi", "cdma", PreferenceWiFi, -1, 0, 300, true, 0, false},
		{"auto resets 300", eth, PreferenceAuto, 300, 0, -1, true, 0, false},
		{"auto resets 100", wifi, PreferenceAuto, 100, 0, -1, true, 0, false},
		{"auto leaves custom metric", wifi, PreferenceAuto, 50, 0, 0, false, 0, false},
		{"auto resets priority 10", wifi, PreferenceAuto, -1, 10, 0, false, 0, true},
		{"auto resets priority 100", wifi, PreferenceAuto, -1, 100, 0, false, 0, true},
		{"auto leaves generated -999", eth, PreferenceAuto, -1, -999, 0, false, 0, false},
		{"auto on defaults is a no-op", eth, PreferenceAuto, -1, 0, 0, false, 0, false},
	}
	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			m, mc, p, pc := preferenceUpdate(tt.connType, tt.pref, tt.metric, tt.priority)
			assert.Equal(t, tt.wantMChg, mc)
			if mc {
				assert.Equal(t, tt.wantMetric, m)
			}
			assert.Equal(t, tt.wantPChg, pc)
			if pc {
				assert.Equal(t, tt.wantPrio, p)
			}
		})
	}
}

func TestManager_SetConnectionPreference(t *testing.T) {
	t.Run("invalid preference", func(t *testing.T) {
		manager := &Manager{
			state: &NetworkState{
				Preference: PreferenceAuto,
			},
		}

		err := manager.SetConnectionPreference(ConnectionPreference("invalid"))
		assert.Error(t, err)
		assert.Contains(t, err.Error(), "invalid preference")
	})

	t.Run("no reapply when nothing changed", func(t *testing.T) {
		settings := mock_dbus.NewMockBusObject(t)
		settings.EXPECT().Call("org.freedesktop.NetworkManager.Settings.ListConnections", dbus.Flags(0)).
			Return(&dbus.Call{Body: []any{[]dbus.ObjectPath{}}}).Once()
		backend := &NetworkManagerBackend{nmObjectFn: func(dbus.ObjectPath) dbus.BusObject { return settings }}

		var reapplied []string
		orig := reapplyDevice
		reapplyDevice = func(dev string) error { reapplied = append(reapplied, dev); return nil }
		defer func() { reapplyDevice = orig }()

		manager := &Manager{
			backend: backend,
			dirty:   make(chan struct{}, 1),
			state: &NetworkState{
				Preference:      PreferenceAuto,
				EthernetDevices: []EthernetDevice{{Name: "eth0", Connected: true}},
			},
		}

		require.NoError(t, manager.SetConnectionPreference(PreferenceWiFi))
		assert.Empty(t, reapplied)
		assert.Equal(t, PreferenceWiFi, manager.GetConnectionPreference())
	})
}

func wifiProfile(extra nmSettings) nmSettings {
	s := nmSettings{
		"connection":      {"id": dbus.MakeVariant("home"), "type": dbus.MakeVariant("802-11-wireless")},
		"802-11-wireless": {"mode": dbus.MakeVariant("infrastructure")},
		"ipv4":            {"method": dbus.MakeVariant("auto")},
		"ipv6":            {"method": dbus.MakeVariant("auto")},
	}
	for section, keys := range extra {
		if s[section] == nil {
			s[section] = map[string]dbus.Variant{}
		}
		maps.Copy(s[section], keys)
	}
	return s
}

func TestApplyPreferenceToProfile_WritesDefaultsUnderPreference(t *testing.T) {
	obj := mock_dbus.NewMockBusObject(t)
	expectGetSettings(obj, wifiProfile(nil))
	expectGetSettings(obj, wifiProfile(nil))
	got := captureUpdate2(obj, 0, nil)

	changed, err := applyPreferenceToProfile(obj, PreferenceWiFi)
	require.NoError(t, err)
	assert.True(t, changed)
	assert.Equal(t, dbus.MakeVariant(int64(100)), (*got)["ipv4"]["route-metric"])
	assert.Equal(t, dbus.MakeVariant(int64(100)), (*got)["ipv6"]["route-metric"])
	assert.NotContains(t, (*got)["connection"], "autoconnect-priority")
}

func TestApplyPreferenceToProfile_LeavesProfileAlone(t *testing.T) {
	tests := []struct {
		name  string
		extra nmSettings
		pref  ConnectionPreference
	}{
		{name: "hotspot", extra: nmSettings{"802-11-wireless": {"mode": dbus.MakeVariant("ap")}}, pref: PreferenceWiFi},
		{name: "user metric", extra: nmSettings{
			"ipv4": {"route-metric": dbus.MakeVariant(int64(50))},
			"ipv6": {"route-metric": dbus.MakeVariant(int64(50))},
		}, pref: PreferenceEthernet},
		{name: "auto with defaults", pref: PreferenceAuto},
	}
	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			obj := mock_dbus.NewMockBusObject(t)
			expectGetSettings(obj, wifiProfile(tt.extra))

			changed, err := applyPreferenceToProfile(obj, tt.pref)
			require.NoError(t, err)
			assert.False(t, changed)
		})
	}
}

func TestApplyPreferenceToProfile_AutoResetsPriority(t *testing.T) {
	prio := nmSettings{"connection": {"autoconnect-priority": dbus.MakeVariant(int32(10))}}
	obj := mock_dbus.NewMockBusObject(t)
	expectGetSettings(obj, wifiProfile(prio))
	expectGetSettings(obj, wifiProfile(prio))
	got := captureUpdate2(obj, 0, nil)

	changed, err := applyPreferenceToProfile(obj, PreferenceAuto)
	require.NoError(t, err)
	assert.True(t, changed)
	assert.Equal(t, dbus.MakeVariant(int32(0)), (*got)["connection"]["autoconnect-priority"])
	assert.NotContains(t, (*got)["ipv4"], "route-metric")
}

func TestApplyPreferenceToProfile_UpdateErrorNamesProfile(t *testing.T) {
	obj := mock_dbus.NewMockBusObject(t)
	expectGetSettings(obj, wifiProfile(nil))
	expectGetSettings(obj, wifiProfile(nil))
	captureUpdate2(obj, 0, errors.New("denied"))

	changed, err := applyPreferenceToProfile(obj, PreferenceWiFi)
	require.Error(t, err)
	assert.False(t, changed)
	assert.True(t, strings.HasPrefix(err.Error(), "home: "), err.Error())
}

// Note: Full testing of priority operations would require mocking NetworkManager
// D-Bus interfaces. The tests above cover the basic logic and error handling.
// Integration tests would be needed for complete coverage of network connection
// priority updates and reactivation.
