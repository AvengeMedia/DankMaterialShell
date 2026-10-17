package network

import (
	"encoding/binary"
	"errors"
	"net/netip"
	"os"
	"path/filepath"
	"regexp"
	"testing"

	mock_gonetworkmanager "github.com/AvengeMedia/DankMaterialShell/core/internal/mocks/github.com/Wifx/gonetworkmanager/v2"
	mock_dbus "github.com/AvengeMedia/DankMaterialShell/core/internal/mocks/github.com/godbus/dbus/v5"
	"github.com/Wifx/gonetworkmanager/v2"
	"github.com/godbus/dbus/v5"
	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/mock"
	"github.com/stretchr/testify/require"
)

const nmConnFlagsProp = dbusNMSettingsConnectionInterface + ".Flags"

type editorFixture struct {
	backend  *NetworkManagerBackend
	nm       *mock_gonetworkmanager.MockNetworkManager
	settings *mock_gonetworkmanager.MockSettings
	objects  map[dbus.ObjectPath]*mock_dbus.MockBusObject
}

func newEditorFixture(t *testing.T) *editorFixture {
	f := &editorFixture{
		nm:       mock_gonetworkmanager.NewMockNetworkManager(t),
		settings: mock_gonetworkmanager.NewMockSettings(t),
		objects:  map[dbus.ObjectPath]*mock_dbus.MockBusObject{},
	}
	b, err := NewNetworkManagerBackend(f.nm)
	require.NoError(t, err)
	b.settings = f.settings
	b.nmObjectFn = func(p dbus.ObjectPath) dbus.BusObject {
		obj, ok := f.objects[p]
		require.True(t, ok, "unexpected object %s", p)
		return obj
	}
	f.backend = b
	return f
}

func (f *editorFixture) object(t *testing.T, path dbus.ObjectPath) *mock_dbus.MockBusObject {
	obj := mock_dbus.NewMockBusObject(t)
	f.objects[path] = obj
	return obj
}

// profile registers a saved connection reachable by UUID.
func (f *editorFixture) profile(t *testing.T, uuid string, path dbus.ObjectPath) *mock_dbus.MockBusObject {
	conn := mock_gonetworkmanager.NewMockConnection(t)
	conn.EXPECT().GetPath().Return(path).Maybe()
	f.settings.EXPECT().GetConnectionByUUID(uuid).Return(conn, nil).Maybe()
	return f.object(t, path)
}

func listedConnection(t *testing.T, f *editorFixture, path dbus.ObjectPath, flags uint32, s nmSettings) gonetworkmanager.Connection {
	conn := mock_gonetworkmanager.NewMockConnection(t)
	conn.EXPECT().GetPath().Return(path).Maybe()
	obj := f.object(t, path)
	obj.EXPECT().GetProperty(nmConnFlagsProp).Return(dbus.MakeVariant(flags), nil).Maybe()
	obj.EXPECT().Call(nmConnGetSettings, dbus.Flags(0)).Return(&dbus.Call{Body: []any{s}}).Maybe()
	return conn
}

func connSection(uuid, id, typ string, extra map[string]dbus.Variant) nmSettings {
	c := map[string]dbus.Variant{
		"uuid": dbus.MakeVariant(uuid),
		"id":   dbus.MakeVariant(id),
		"type": dbus.MakeVariant(typ),
	}
	for k, v := range extra {
		c[k] = v
	}
	return nmSettings{"connection": c}
}

func TestListConnectionProfiles_FiltersExternalAndReportsActive(t *testing.T) {
	f := newEditorFixture(t)
	docker := listedConnection(t, f, "/s/1", 15, connSection("u-docker", "docker0", "bridge", nil))
	wired := listedConnection(t, f, "/s/2", 1, connSection("u-wired", "Wired connection 1", "802-3-ethernet", map[string]dbus.Variant{
		"interface-name": dbus.MakeVariant("enp5s0"),
		"timestamp":      dbus.MakeVariant(uint64(1700000000)),
	}))
	home := listedConnection(t, f, "/s/3", 0, connSection("u-home", "aHome", "802-11-wireless", map[string]dbus.Variant{
		"autoconnect": dbus.MakeVariant(false),
	}))
	f.settings.EXPECT().ListConnections().Return([]gonetworkmanager.Connection{docker, wired, home}, nil)

	dev := mock_gonetworkmanager.NewMockDevice(t)
	dev.EXPECT().GetPropertyInterface().Return("enp5s0", nil)
	ac := mock_gonetworkmanager.NewMockActiveConnection(t)
	ac.EXPECT().GetPropertyUUID().Return("u-wired", nil)
	ac.EXPECT().GetPropertyState().Return(gonetworkmanager.NmActiveConnectionStateActivated, nil)
	ac.EXPECT().GetPropertyDevices().Return([]gonetworkmanager.Device{dev}, nil)
	f.nm.EXPECT().GetPropertyActiveConnections().Return([]gonetworkmanager.ActiveConnection{ac}, nil)
	expectPermissions(t, f, map[string]string{"org.freedesktop.NetworkManager.settings.modify.system": "yes"}, nil)

	profiles, err := f.backend.ListConnectionProfiles()
	require.NoError(t, err)

	assert.Equal(t, []ConnectionProfile{
		{UUID: "u-home", ID: "aHome", Type: "802-11-wireless", CanModify: true},
		{
			UUID: "u-wired", ID: "Wired connection 1", Type: "802-3-ethernet",
			Device: "enp5s0", InterfaceName: "enp5s0", Active: true, ActiveState: "activated",
			Autoconnect: true, Timestamp: 1700000000, Unsaved: true, CanModify: true,
		},
	}, profiles)
}

func TestUpdateConnectionSettings_EncodesPatchAndKeepsModernIPKeys(t *testing.T) {
	stored := func() nmSettings {
		s := connSection("u1", "Wired", "802-3-ethernet", nil)
		s["ipv4"] = map[string]dbus.Variant{
			"method":   dbus.MakeVariant("auto"),
			"dns":      dbus.MakeVariant([]uint32{0x01010101}),
			"dns-data": dbus.MakeVariant([]string{"1.1.1.1"}),
		}
		return s
	}
	patch := SettingsPatch{"connection": {"autoconnect-priority": float64(5)}}

	for _, tc := range []struct {
		persist bool
		flags   uint32
	}{{false, 0}, {true, 0x1}} {
		f := newEditorFixture(t)
		obj := f.profile(t, "u1", "/s/1")
		expectGetSettings(obj, stored())
		got := captureUpdate2(obj, tc.flags, nil)

		require.NoError(t, f.backend.UpdateConnectionSettings("u1", patch, tc.persist))

		s := *got
		assert.Equal(t, int32(5), s["connection"]["autoconnect-priority"].Value())
		assert.Equal(t, []string{"1.1.1.1"}, s["ipv4"]["dns-data"].Value())
		assert.NotContains(t, s["ipv4"], "dns")
	}
}

func TestUpdateConnectionSettings_Rejections(t *testing.T) {
	f := newEditorFixture(t)
	require.EqualError(t, f.backend.UpdateConnectionSettings("u1", SettingsPatch{}, false), "no changes")

	for _, patch := range []SettingsPatch{
		{"connection": {"uuid": "other"}},
		{"connection": {"type": "802-11-wireless"}},
		{"connection": nil},
	} {
		obj := f.profile(t, "u1", "/s/1")
		expectGetSettings(obj, connSection("u1", "Wired", "802-3-ethernet", nil))
		err := f.backend.UpdateConnectionSettings("u1", patch, false)
		require.ErrorContains(t, err, "cannot be changed")
		obj.AssertNotCalled(t, "Call", nmConnUpdate2, mock.Anything, mock.Anything, mock.Anything, mock.Anything)
	}

	f.settings.EXPECT().GetConnectionByUUID("nope").
		Return(nil, dbus.Error{Name: "org.freedesktop.NetworkManager.Settings.InvalidConnection", Body: []any{"No connection with the UUID was found."}})
	require.EqualError(t, f.backend.UpdateConnectionSettings("nope", SettingsPatch{"connection": {"id": "x"}}, false), "connection nope not found")
}

func pskProfile(obj *mock_dbus.MockBusObject) {
	s := connSection("u1", "Home", "802-11-wireless", map[string]dbus.Variant{
		"timestamp": dbus.MakeVariant(uint64(1700000000)),
	})
	s["802-11-wireless-security"] = map[string]dbus.Variant{"key-mgmt": dbus.MakeVariant("wpa-psk")}
	s["ipv4"] = map[string]dbus.Variant{
		"method":   dbus.MakeVariant("auto"),
		"dns":      dbus.MakeVariant([]uint32{0x01010101}),
		"dns-data": dbus.MakeVariant([]string{"1.1.1.1"}),
	}
	expectGetSettings(obj, s)
}

func expectPSKSecret(obj *mock_dbus.MockBusObject) {
	expectGetSecrets(obj, "802-11-wireless-security", nmSettings{
		"802-11-wireless-security": {"psk": dbus.MakeVariant("hunter22")},
	})
}

var uuidV4 = regexp.MustCompile(`^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$`)

func captureAddConnection(obj *mock_dbus.MockBusObject, method string) *nmSettings {
	var got nmSettings
	obj.EXPECT().Call(method, dbus.Flags(0), mock.Anything).
		Run(func(_ string, _ dbus.Flags, args ...any) { got = args[0].(nmSettings) }).
		Return(&dbus.Call{Body: []any{dbus.ObjectPath("/s/new")}}).Once()
	return &got
}

func expectFlags(obj *mock_dbus.MockBusObject, flags uint32) {
	obj.EXPECT().GetProperty(nmConnFlagsProp).Return(dbus.MakeVariant(flags), nil).Once()
}

func TestDuplicateConnectionProfile_FollowsSourceStorage(t *testing.T) {
	f := newEditorFixture(t)
	obj := f.profile(t, "u1", "/s/1")
	expectFlags(obj, nmConnFlagUnsaved)
	pskProfile(obj)
	expectPSKSecret(obj)
	got := captureAddConnection(f.object(t, nmSettingsPath), nmSettingsAddConnectionUnsaved)

	_, err := f.backend.DuplicateConnectionProfile("u1", "Home copy")
	require.NoError(t, err)
	assert.Equal(t, "Home copy", (*got)["connection"]["id"].Value())
}

func TestListConnectionProfiles_SkipsProfileWithUnreadableFlags(t *testing.T) {
	f := newEditorFixture(t)
	conn := mock_gonetworkmanager.NewMockConnection(t)
	conn.EXPECT().GetPath().Return(dbus.ObjectPath("/s/1")).Maybe()
	f.object(t, "/s/1").EXPECT().GetProperty(nmConnFlagsProp).Return(dbus.Variant{}, errors.New("gone")).Once()
	f.settings.EXPECT().ListConnections().Return([]gonetworkmanager.Connection{conn}, nil)
	f.nm.EXPECT().GetPropertyActiveConnections().Return(nil, nil)
	expectPermissions(t, f, nil, nil)

	profiles, err := f.backend.ListConnectionProfiles()
	require.NoError(t, err)
	assert.Empty(t, profiles)
}

func TestDuplicateConnectionProfile(t *testing.T) {
	f := newEditorFixture(t)
	obj := f.profile(t, "u1", "/s/1")
	expectFlags(obj, 0)
	pskProfile(obj)
	expectPSKSecret(obj)
	got := captureAddConnection(f.object(t, nmSettingsPath), nmSettingsAddConnection)

	newUUID, err := f.backend.DuplicateConnectionProfile("u1", "Home copy")
	require.NoError(t, err)

	s := *got
	assert.Regexp(t, uuidV4, newUUID)
	assert.Equal(t, newUUID, s["connection"]["uuid"].Value())
	assert.Equal(t, "Home copy", s["connection"]["id"].Value())
	assert.NotContains(t, s["connection"], "timestamp")
	assert.Equal(t, "hunter22", s["802-11-wireless-security"]["psk"].Value())
	assert.NotContains(t, s["ipv4"], "dns")
	assert.Equal(t, []string{"1.1.1.1"}, s["ipv4"]["dns-data"].Value())

	_, err = f.backend.DuplicateConnectionProfile("u1", "")
	require.Error(t, err)
}

func TestGetConnectionSettings_Secrets(t *testing.T) {
	f := newEditorFixture(t)
	obj := f.profile(t, "u1", "/s/1")

	pskProfile(obj)
	s, err := f.backend.GetConnectionSettings("u1", false)
	require.NoError(t, err)
	assert.NotContains(t, s["802-11-wireless-security"], "psk")
	assert.Equal(t, []string{"1.1.1.1"}, s["ipv4"]["dns-data"])
	assert.NotContains(t, s["ipv4"], "dns")

	pskProfile(obj)
	expectPSKSecret(obj)
	s, err = f.backend.GetConnectionSettings("u1", true)
	require.NoError(t, err)
	assert.Equal(t, "hunter22", s["802-11-wireless-security"]["psk"])
}

func TestAddConnectionProfile(t *testing.T) {
	f := newEditorFixture(t)
	settingsObj := f.object(t, nmSettingsPath)

	_, err := f.backend.AddConnectionProfile(SettingsPatch{"connection": {"id": "x"}}, true)
	require.ErrorContains(t, err, "connection.type")

	got := captureAddConnection(settingsObj, nmSettingsAddConnectionUnsaved)
	uuid, err := f.backend.AddConnectionProfile(SettingsPatch{
		"connection": {"id": "Lab", "type": "802-3-ethernet"},
		"ipv4":       {"method": "auto"},
	}, false)
	require.NoError(t, err)
	assert.Regexp(t, uuidV4, uuid)
	assert.Equal(t, uuid, (*got)["connection"]["uuid"].Value())

	got = captureAddConnection(settingsObj, nmSettingsAddConnection)
	uuid, err = f.backend.AddConnectionProfile(SettingsPatch{
		"connection": {"id": "Lab", "type": "802-3-ethernet", "uuid": "fixed"},
	}, true)
	require.NoError(t, err)
	assert.Equal(t, "fixed", uuid)
	assert.Equal(t, "fixed", (*got)["connection"]["uuid"].Value())
}

func TestDeleteConnectionProfile(t *testing.T) {
	f := newEditorFixture(t)
	conn := mock_gonetworkmanager.NewMockConnection(t)
	conn.EXPECT().Delete().Return(nil).Once()
	f.settings.EXPECT().GetConnectionByUUID("u1").Return(conn, nil)

	require.NoError(t, f.backend.DeleteConnectionProfile("u1"))
}

func expectPermissions(t *testing.T, f *editorFixture, perms map[string]string, err error) {
	call := &dbus.Call{Body: []any{perms}, Err: err}
	f.object(t, dbusNMPath).EXPECT().Call(gonetworkmanager.NetworkManagerGetPermissions, dbus.Flags(0)).Return(call).Once()
}

func TestListConnectionProfiles_CanModifyAndSSID(t *testing.T) {
	f := newEditorFixture(t)
	system := listedConnection(t, f, "/s/1", 0, connSection("u-sys", "a", "802-3-ethernet", nil))
	own := listedConnection(t, f, "/s/2", 0, connSection("u-own", "b", "802-3-ethernet", map[string]dbus.Variant{
		"permissions": dbus.MakeVariant([]string{"user:marlon:"}),
	}))
	wifi := connSection("u-wifi", "c", "802-11-wireless", nil)
	wifi["802-11-wireless"] = map[string]dbus.Variant{"ssid": dbus.MakeVariant([]byte("eduroam"))}
	wifiConn := listedConnection(t, f, "/s/3", 0, wifi)
	f.settings.EXPECT().ListConnections().Return([]gonetworkmanager.Connection{system, own, wifiConn}, nil)
	f.nm.EXPECT().GetPropertyActiveConnections().Return(nil, nil)
	expectPermissions(t, f, map[string]string{
		"org.freedesktop.NetworkManager.settings.modify.system": "no",
		"org.freedesktop.NetworkManager.settings.modify.own":    "yes",
	}, nil)

	profiles, err := f.backend.ListConnectionProfiles()
	require.NoError(t, err)
	require.Len(t, profiles, 3)
	assert.False(t, profiles[0].CanModify)
	assert.True(t, profiles[1].CanModify)
	assert.False(t, profiles[2].CanModify)
	assert.Equal(t, "eduroam", profiles[2].SSID)
	assert.Empty(t, profiles[0].SSID)
}

func TestListConnectionProfiles_ReportsPortRelation(t *testing.T) {
	f := newEditorFixture(t)
	legacy := connSection("u-a", "a", "802-3-ethernet", map[string]dbus.Variant{
		"master": dbus.MakeVariant("ctrl-1"), "slave-type": dbus.MakeVariant("bond"),
	})
	modern := connSection("u-b", "b", "802-3-ethernet", map[string]dbus.Variant{
		"controller": dbus.MakeVariant("ctrl-2"), "port-type": dbus.MakeVariant("bridge"),
	})
	plain := connSection("u-c", "c", "802-3-ethernet", nil)
	f.settings.EXPECT().ListConnections().Return([]gonetworkmanager.Connection{
		listedConnection(t, f, "/s/1", 0, legacy),
		listedConnection(t, f, "/s/2", 0, modern),
		listedConnection(t, f, "/s/3", 0, plain),
	}, nil)
	f.nm.EXPECT().GetPropertyActiveConnections().Return(nil, nil)
	expectPermissions(t, f, nil, nil)

	profiles, err := f.backend.ListConnectionProfiles()
	require.NoError(t, err)
	require.Len(t, profiles, 3)
	assert.Equal(t, "ctrl-1", profiles[0].Controller)
	assert.Equal(t, "bond", profiles[0].PortType)
	assert.Equal(t, "ctrl-2", profiles[1].Controller)
	assert.Equal(t, "bridge", profiles[1].PortType)
	assert.Empty(t, profiles[2].Controller)
	assert.Empty(t, profiles[2].PortType)
}

func TestListConnectionProfiles_PermissionsErrorAllowsModify(t *testing.T) {
	f := newEditorFixture(t)
	wifi := connSection("u-wifi", "c", "802-11-wireless", nil)
	wifi["802-11-wireless"] = map[string]dbus.Variant{"ssid": dbus.MakeVariant([]byte{0xff, 0xfe})}
	conn := listedConnection(t, f, "/s/1", 0, wifi)
	f.settings.EXPECT().ListConnections().Return([]gonetworkmanager.Connection{conn}, nil)
	f.nm.EXPECT().GetPropertyActiveConnections().Return(nil, nil)
	expectPermissions(t, f, nil, errors.New("denied"))

	profiles, err := f.backend.ListConnectionProfiles()
	require.NoError(t, err)
	require.Len(t, profiles, 1)
	assert.True(t, profiles[0].CanModify)
	assert.Empty(t, profiles[0].SSID)
}

func activeConn(t *testing.T, uuid string) *mock_gonetworkmanager.MockActiveConnection {
	ac := mock_gonetworkmanager.NewMockActiveConnection(t)
	ac.EXPECT().GetPropertyUUID().Return(uuid, nil).Maybe()
	return ac
}

func TestDeactivateConnectionProfile(t *testing.T) {
	f := newEditorFixture(t)
	other, target := activeConn(t, "u-other"), activeConn(t, "u1")
	f.nm.EXPECT().GetPropertyActiveConnections().Return([]gonetworkmanager.ActiveConnection{other, target}, nil).Twice()
	f.nm.EXPECT().DeactivateConnection(target).Return(nil).Once()

	require.NoError(t, f.backend.DeactivateConnectionProfile("u1"))
	require.NoError(t, f.backend.DeactivateConnectionProfile("u-inactive"))
}

func TestActivateConnectionProfile(t *testing.T) {
	f := newEditorFixture(t)
	conn := mock_gonetworkmanager.NewMockConnection(t)
	f.settings.EXPECT().GetConnectionByUUID("u1").Return(conn, nil)
	f.settings.EXPECT().GetConnectionByUUID("nope").Return(nil, nil)
	dev := mock_gonetworkmanager.NewMockDevice(t)
	f.nm.EXPECT().GetDeviceByIpIface("wlan0").Return(dev, nil)
	f.nm.EXPECT().GetDeviceByIpIface("bogus").Return(nil, errors.New("No device found"))
	f.nm.EXPECT().ActivateConnection(conn, gonetworkmanager.Device(nil), (*dbus.Object)(nil)).Return(nil, nil).Once()
	f.nm.EXPECT().ActivateConnection(conn, dev, (*dbus.Object)(nil)).Return(nil, nil).Once()

	require.NoError(t, f.backend.ActivateConnectionProfile("u1", ""))
	require.NoError(t, f.backend.ActivateConnectionProfile("u1", "wlan0"))
	require.ErrorContains(t, f.backend.ActivateConnectionProfile("u1", "bogus"), "bogus")
	require.EqualError(t, f.backend.ActivateConnectionProfile("nope", ""), "connection nope not found")
}

func TestFirewallZones(t *testing.T) {
	f := newEditorFixture(t)
	fw := mock_dbus.NewMockBusObject(t)
	f.backend.firewalldObjectFn = func() dbus.BusObject { return fw }

	fw.EXPECT().Call(firewalldGetZones, dbus.Flags(0)).
		Return(&dbus.Call{Err: dbus.Error{Name: "org.freedesktop.DBus.Error.ServiceUnknown"}}).Once()
	zones, err := f.backend.FirewallZones()
	require.NoError(t, err)
	assert.Equal(t, []string{}, zones)

	fw.EXPECT().Call(firewalldGetZones, dbus.Flags(0)).
		Return(&dbus.Call{Body: []any{[]string{"public", "home"}}}).Once()
	zones, err = f.backend.FirewallZones()
	require.NoError(t, err)
	assert.Equal(t, []string{"home", "public"}, zones)

	fw.EXPECT().Call(firewalldGetZones, dbus.Flags(0)).
		Return(&dbus.Call{Err: dbus.Error{Name: "org.freedesktop.DBus.Error.AccessDenied"}}).Once()
	_, err = f.backend.FirewallZones()
	require.Error(t, err)
}

func TestUpdateConnectionSettings_LegacyDNSShim(t *testing.T) {
	patch := SettingsPatch{"ipv4": {"dns-data": []any{"192.0.2.53"}}}
	stored := func() nmSettings {
		s := connSection("u1", "Wired", "802-3-ethernet", nil)
		s["ipv4"] = map[string]dbus.Variant{"method": dbus.MakeVariant("auto")}
		return s
	}

	f := newEditorFixture(t)
	f.nm.EXPECT().GetPropertyVersion().Return("1.46.0", nil).Once()
	obj := f.profile(t, "u1", "/s/1")
	expectGetSettings(obj, stored())
	got := captureUpdate2(obj, 0, nil)
	require.NoError(t, f.backend.UpdateConnectionSettings("u1", patch, false))
	assert.Equal(t, []uint32{binary.NativeEndian.Uint32([]byte{192, 0, 2, 53})}, (*got)["ipv4"]["dns"].Value())
	assert.NotContains(t, (*got)["ipv4"], "dns-data")

	// The version is cached, and a DoT entry aborts before any write.
	expectGetSettings(obj, stored())
	err := f.backend.UpdateConnectionSettings("u1", SettingsPatch{"ipv4": {"dns-data": []any{"1.1.1.1#one.one.one.one"}}}, false)
	require.ErrorContains(t, err, "ipv4.dns-data")

	f = newEditorFixture(t)
	f.nm.EXPECT().GetPropertyVersion().Return("1.58.1", nil).Once()
	obj = f.profile(t, "u1", "/s/1")
	expectGetSettings(obj, stored())
	got = captureUpdate2(obj, 0, nil)
	require.NoError(t, f.backend.UpdateConnectionSettings("u1", patch, false))
	assert.Equal(t, []string{"192.0.2.53"}, (*got)["ipv4"]["dns-data"].Value())
}

func TestUpdateConnectionSettings_DNSDataReplacesStoredLegacyDNS(t *testing.T) {
	oldDNS := []uint32{binary.NativeEndian.Uint32([]byte{198, 51, 100, 1})}
	legacyOnly := func() nmSettings {
		s := connSection("u1", "Wired", "802-3-ethernet", nil)
		s["ipv4"] = map[string]dbus.Variant{"method": dbus.MakeVariant("auto"), "dns": dbus.MakeVariant(oldDNS)}
		return s
	}
	both := func() nmSettings {
		s := legacyOnly()
		s["ipv4"]["dns-data"] = dbus.MakeVariant([]string{"198.51.100.1"})
		return s
	}

	// NM < 1.52 stores only legacy dns; an edit sends dns-data back.
	f := newEditorFixture(t)
	f.nm.EXPECT().GetPropertyVersion().Return("1.46.0", nil).Once()
	obj := f.profile(t, "u1", "/s/1")
	expectGetSettings(obj, legacyOnly())
	got := captureUpdate2(obj, 0, nil)
	require.NoError(t, f.backend.UpdateConnectionSettings("u1", SettingsPatch{"ipv4": {"dns-data": []any{"192.0.2.53"}}}, false))
	assert.Equal(t, []uint32{binary.NativeEndian.Uint32([]byte{192, 0, 2, 53})}, (*got)["ipv4"]["dns"].Value())
	assert.NotContains(t, (*got)["ipv4"], "dns-data")

	// Clearing removes the stored legacy dns on either version, without a version read.
	for _, stored := range []func() nmSettings{legacyOnly, both} {
		f = newEditorFixture(t)
		obj = f.profile(t, "u1", "/s/1")
		expectGetSettings(obj, stored())
		got = captureUpdate2(obj, 0, nil)
		require.NoError(t, f.backend.UpdateConnectionSettings("u1", SettingsPatch{"ipv4": {"dns-data": nil}}, false))
		assert.NotContains(t, (*got)["ipv4"], "dns")
		assert.NotContains(t, (*got)["ipv4"], "dns-data")
	}
}

func TestAddConnectionProfile_LegacyDNSShim(t *testing.T) {
	f := newEditorFixture(t)
	f.nm.EXPECT().GetPropertyVersion().Return("1.42.4", nil).Once()
	got := captureAddConnection(f.object(t, nmSettingsPath), nmSettingsAddConnection)
	_, err := f.backend.AddConnectionProfile(SettingsPatch{
		"connection": {"id": "Lab", "type": "802-3-ethernet"},
		"ipv6":       {"method": "manual", "dns-data": []any{"2001:db8::53"}},
	}, true)
	require.NoError(t, err)
	assert.Equal(t, [][]byte{netip.MustParseAddr("2001:db8::53").AsSlice()}, (*got)["ipv6"]["dns"].Value())
	assert.NotContains(t, (*got)["ipv6"], "dns-data")
}

func TestConvertDNSDataToLegacy(t *testing.T) {
	for _, tc := range []struct {
		family string
		in     []string
		ok     bool
	}{
		{"ipv4", []string{"192.0.2.1", "198.51.100.2"}, true},
		{"ipv4", []string{"2001:db8::1"}, false},
		{"ipv6", []string{"::ffff:192.0.2.1"}, false},
		{"ipv6", []string{"fe80::1%eth0"}, false},
		{"ipv6", []string{"dns+tls://[2001:db8::1]"}, false},
		{"ipv6", []string{}, true},
	} {
		s := nmSettings{tc.family: {"dns-data": dbus.MakeVariant(tc.in)}}
		err := convertDNSDataToLegacy(s, []string{tc.family})
		if !tc.ok {
			require.ErrorContains(t, err, tc.family+".dns-data", "%v", tc.in)
			continue
		}
		require.NoError(t, err, "%v", tc.in)
		assert.NotContains(t, s[tc.family], "dns-data")
		assert.Contains(t, s[tc.family], "dns")
	}
}

func TestConvertDNSDataToLegacyLeavesOtherFamilies(t *testing.T) {
	s := nmSettings{
		"ipv4": {"dns-data": dbus.MakeVariant([]string{"192.0.2.1"})},
		"ipv6": {"dns-data": dbus.MakeVariant([]string{"dns+tls://[2001:db8::1]"})},
	}
	require.NoError(t, convertDNSDataToLegacy(s, []string{"ipv4"}))
	assert.Contains(t, s["ipv4"], "dns")
	assert.Contains(t, s["ipv6"], "dns-data")
}

func TestNMVersionBelow(t *testing.T) {
	for v, want := range map[string]bool{
		"1.46.0": true, "1.51.90": true, "1.52.0": false, "1.58.1": false,
		"2.0": false, "garbage": false, "": false, "0.9.10": true,
	} {
		assert.Equal(t, want, nmVersionBelow(v, 1, 52), v)
	}
}

func TestExportConnectionProfile_WireGuard(t *testing.T) {
	f := newEditorFixture(t)
	obj := f.profile(t, "u1", "/s/1")
	s := connSection("u1", "wg", "wireguard", map[string]dbus.Variant{"interface-name": dbus.MakeVariant("wg0")})
	s["wireguard"] = map[string]dbus.Variant{
		"private-key-flags": dbus.MakeVariant(uint32(0)),
		"peers": dbus.MakeVariant([]map[string]dbus.Variant{{
			"public-key":  dbus.MakeVariant("PUB1"),
			"allowed-ips": dbus.MakeVariant([]string{"10.0.0.0/24"}),
		}}),
	}
	expectGetSettings(obj, s)
	expectGetSecrets(obj, "wireguard", nmSettings{"wireguard": {"private-key": dbus.MakeVariant("PRIV")}})

	path := filepath.Join(t.TempDir(), "wg0.conf")
	require.NoError(t, f.backend.ExportConnectionProfile("u1", path))

	info, err := os.Stat(path)
	require.NoError(t, err)
	assert.Equal(t, os.FileMode(0o600), info.Mode().Perm())
	data, err := os.ReadFile(path)
	require.NoError(t, err)
	assert.Contains(t, string(data), "PrivateKey = PRIV")
	assert.Contains(t, string(data), "AllowedIPs = 10.0.0.0/24")
}

func TestExportConnectionProfile_VPNAndRejections(t *testing.T) {
	f := newEditorFixture(t)
	var argv []string
	var runErr error
	stdout, stderr := "remote vpn.example.com\n", "warning: noisy\n"
	orig := nmcliRun
	t.Cleanup(func() { nmcliRun = orig })
	nmcliRun = func(args ...string) ([]byte, []byte, error) {
		argv = args
		return []byte(stdout), []byte(stderr), runErr
	}
	vpn := func() { expectGetSettings(f.profile(t, "u1", "/s/1"), connSection("u1", "v", "vpn", nil)) }

	vpn()
	path := filepath.Join(t.TempDir(), "v.ovpn")
	require.NoError(t, f.backend.ExportConnectionProfile("u1", path))
	assert.Equal(t, []string{"connection", "export", "uuid", "u1"}, argv)
	data, err := os.ReadFile(path)
	require.NoError(t, err)
	assert.Equal(t, stdout, string(data))
	info, err := os.Stat(path)
	require.NoError(t, err)
	assert.Equal(t, os.FileMode(0o600), info.Mode().Perm())

	f = newEditorFixture(t)
	vpn()
	runErr, stdout, stderr = errors.New("exit status 1"), "", "export not supported\n"
	missing := filepath.Join(t.TempDir(), "x.ovpn")
	err = f.backend.ExportConnectionProfile("u1", missing)
	assert.ErrorContains(t, err, "nmcli: export not supported")
	assert.NoFileExists(t, missing)

	f = newEditorFixture(t)
	expectGetSettings(f.profile(t, "u1", "/s/1"), connSection("u1", "e", "802-3-ethernet", nil))
	assert.ErrorContains(t, f.backend.ExportConnectionProfile("u1", missing), "VPN and WireGuard")

	assert.Error(t, f.backend.ExportConnectionProfile("u1", "rel.conf"))
}

func TestExportConnectionProfile_TightensExistingMode(t *testing.T) {
	f := newEditorFixture(t)
	obj := f.profile(t, "u1", "/s/1")
	s := connSection("u1", "wg", "wireguard", nil)
	s["wireguard"] = map[string]dbus.Variant{"private-key-flags": dbus.MakeVariant(uint32(0))}
	expectGetSettings(obj, s)
	expectGetSecrets(obj, "wireguard", nmSettings{"wireguard": {"private-key": dbus.MakeVariant("PRIV")}})

	path := filepath.Join(t.TempDir(), "wg0.conf")
	require.NoError(t, os.WriteFile(path, []byte("old"), 0o644))
	require.NoError(t, os.Chmod(path, 0o644))
	require.NoError(t, f.backend.ExportConnectionProfile("u1", path))
	info, err := os.Stat(path)
	require.NoError(t, err)
	assert.Equal(t, os.FileMode(0o600), info.Mode().Perm())
}

func TestExportConnectionProfile_RefusesSymlink(t *testing.T) {
	f := newEditorFixture(t)
	obj := f.profile(t, "u1", "/s/1")
	s := connSection("u1", "wg", "wireguard", nil)
	s["wireguard"] = map[string]dbus.Variant{"private-key-flags": dbus.MakeVariant(uint32(0))}
	expectGetSettings(obj, s)
	expectGetSecrets(obj, "wireguard", nmSettings{"wireguard": {"private-key": dbus.MakeVariant("PRIV")}})

	dir := t.TempDir()
	target := filepath.Join(dir, "target")
	link := filepath.Join(dir, "link")
	require.NoError(t, os.Symlink(target, link))
	assert.Error(t, f.backend.ExportConnectionProfile("u1", link))
	assert.NoFileExists(t, target)
}
