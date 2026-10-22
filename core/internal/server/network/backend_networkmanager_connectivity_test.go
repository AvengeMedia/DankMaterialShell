package network

import (
	"errors"
	"testing"

	"github.com/godbus/dbus/v5"
	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
)

func TestConnectivityName(t *testing.T) {
	cases := map[uint32]string{0: "unknown", 1: "none", 2: "portal", 3: "limited", 4: "full", 7: "unknown"}
	for v, want := range cases {
		assert.Equal(t, want, connectivityName(v))
	}
}

func TestHandleNetworkManagerChange_Connectivity(t *testing.T) {
	f := newEditorFixture(t)
	notified := 0
	f.backend.onStateChange = func() { notified++ }

	f.backend.handleNetworkManagerChange(map[string]dbus.Variant{
		"Connectivity":               dbus.MakeVariant(uint32(2)),
		"ConnectivityCheckEnabled":   dbus.MakeVariant(true),
		"ConnectivityCheckAvailable": dbus.MakeVariant(true),
		"ConnectivityCheckUri":       dbus.MakeVariant("http://example.test/check"),
	})

	st := f.backend.state
	assert.Equal(t, "portal", st.Connectivity)
	assert.True(t, st.ConnectivityCheckEnabled)
	assert.True(t, st.ConnectivityCheckAvailable)
	assert.Equal(t, "http://example.test/check", st.ConnectivityCheckURI)
	assert.Equal(t, 1, notified)
}

func TestCheckConnectivity(t *testing.T) {
	f := newEditorFixture(t)
	obj := f.object(t, dbusNMPath)
	obj.EXPECT().Call(dbusNMInterface+".CheckConnectivity", dbus.Flags(0)).
		Return(&dbus.Call{Body: []any{uint32(3)}})

	got, err := f.backend.CheckConnectivity()
	require.NoError(t, err)
	assert.Equal(t, "limited", got)
	assert.Equal(t, "limited", f.backend.state.Connectivity)
}

func TestCheckConnectivity_Error(t *testing.T) {
	f := newEditorFixture(t)
	f.object(t, dbusNMPath).EXPECT().Call(dbusNMInterface+".CheckConnectivity", dbus.Flags(0)).
		Return(&dbus.Call{Err: errors.New("checking disabled")})

	_, err := f.backend.CheckConnectivity()
	require.Error(t, err)
	assert.Contains(t, err.Error(), "checking disabled")
}

func TestSetConnectivityCheckEnabled(t *testing.T) {
	f := newEditorFixture(t)
	obj := f.object(t, dbusNMPath)
	obj.EXPECT().Call(dbusPropsInterface+".Set", dbus.FlagAllowInteractiveAuthorization,
		dbusNMInterface, "ConnectivityCheckEnabled", dbus.MakeVariant(true)).
		Return(&dbus.Call{}).Once()
	require.NoError(t, f.backend.SetConnectivityCheckEnabled(true))

	obj.EXPECT().Call(dbusPropsInterface+".Set", dbus.FlagAllowInteractiveAuthorization,
		dbusNMInterface, "ConnectivityCheckEnabled", dbus.MakeVariant(false)).
		Return(&dbus.Call{Err: dbus.Error{Name: "org.freedesktop.NetworkManager.PermissionDenied", Body: []any{"not allowed"}}}).Once()
	err := f.backend.SetConnectivityCheckEnabled(false)
	require.Error(t, err)
	assert.Contains(t, err.Error(), "not allowed")
}

func TestUpdateConnectivityState(t *testing.T) {
	f := newEditorFixture(t)
	obj := f.object(t, dbusNMPath)
	prop := func(name string, v any) {
		obj.EXPECT().GetProperty(dbusNMInterface+"."+name).Return(dbus.MakeVariant(v), nil).Once()
	}
	prop("Connectivity", uint32(4))
	prop("ConnectivityCheckEnabled", true)
	prop("ConnectivityCheckAvailable", true)
	prop("ConnectivityCheckUri", "http://x.test")

	f.backend.updateConnectivityState()
	assert.Equal(t, "full", f.backend.state.Connectivity)
	assert.Equal(t, "http://x.test", f.backend.state.ConnectivityCheckURI)
}
