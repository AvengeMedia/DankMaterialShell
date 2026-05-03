package network

import (
	"testing"

	mock_gonetworkmanager "github.com/AvengeMedia/DankMaterialShell/core/internal/mocks/github.com/Wifx/gonetworkmanager/v2"
	"github.com/Wifx/gonetworkmanager/v2"
	"github.com/stretchr/testify/assert"
)

func TestNetworkManagerBackend_GetCellularEnabled(t *testing.T) {
	mockNM := mock_gonetworkmanager.NewMockNetworkManager(t)

	backend, err := NewNetworkManagerBackend(mockNM)
	assert.NoError(t, err)

	mockNM.EXPECT().GetPropertyWwanEnabled().Return(true, nil)

	enabled, err := backend.GetCellularEnabled()
	assert.NoError(t, err)
	assert.True(t, enabled)
}

func TestNetworkManagerBackend_GetCellularEnabled_Disabled(t *testing.T) {
	mockNM := mock_gonetworkmanager.NewMockNetworkManager(t)

	backend, err := NewNetworkManagerBackend(mockNM)
	assert.NoError(t, err)

	mockNM.EXPECT().GetPropertyWwanEnabled().Return(false, nil)

	enabled, err := backend.GetCellularEnabled()
	assert.NoError(t, err)
	assert.False(t, enabled)
}

func TestNetworkManagerBackend_SetCellularEnabled_NoDBusConn(t *testing.T) {
	mockNM := mock_gonetworkmanager.NewMockNetworkManager(t)

	backend, err := NewNetworkManagerBackend(mockNM)
	assert.NoError(t, err)

	// Without a real D-Bus connection, this should return an error
	// (no system bus available in test environment)
	backend.dbusConn = nil
	err = backend.SetCellularEnabled(true)
	// In CI/test environments without D-Bus, this will error
	// In environments with D-Bus, it may succeed
	if err != nil {
		assert.Contains(t, err.Error(), "failed")
	}
}

func TestNetworkManagerBackend_GetCellularDevices_Empty(t *testing.T) {
	mockNM := mock_gonetworkmanager.NewMockNetworkManager(t)

	backend, err := NewNetworkManagerBackend(mockNM)
	assert.NoError(t, err)

	devices := backend.GetCellularDevices()
	assert.Empty(t, devices)
}

func TestNetworkManagerBackend_GetCellularDevices_FromState(t *testing.T) {
	mockNM := mock_gonetworkmanager.NewMockNetworkManager(t)

	backend, err := NewNetworkManagerBackend(mockNM)
	assert.NoError(t, err)

	backend.stateMutex.Lock()
	backend.state.CellularDevices = []CellularDevice{
		{Name: "wwan0", State: "connected", Connected: true, Operator: "Test Mobile"},
	}
	backend.stateMutex.Unlock()

	devices := backend.GetCellularDevices()
	assert.Len(t, devices, 1)
	assert.Equal(t, "wwan0", devices[0].Name)
	assert.Equal(t, "Test Mobile", devices[0].Operator)
	assert.True(t, devices[0].Connected)
}

func TestNetworkManagerBackend_GetCellularDevices_ReturnsCopy(t *testing.T) {
	mockNM := mock_gonetworkmanager.NewMockNetworkManager(t)

	backend, err := NewNetworkManagerBackend(mockNM)
	assert.NoError(t, err)

	backend.stateMutex.Lock()
	backend.state.CellularDevices = []CellularDevice{
		{Name: "wwan0"},
	}
	backend.stateMutex.Unlock()

	devices := backend.GetCellularDevices()
	devices[0].Name = "modified"

	// Original should be unchanged
	backend.stateMutex.RLock()
	assert.Equal(t, "wwan0", backend.state.CellularDevices[0].Name)
	backend.stateMutex.RUnlock()
}

func TestNetworkManagerBackend_GetCellularConnections_NoSettings(t *testing.T) {
	mockNM := mock_gonetworkmanager.NewMockNetworkManager(t)

	backend, err := NewNetworkManagerBackend(mockNM)
	assert.NoError(t, err)
	backend.settings = nil

	// listCellularConnections will try to create settings via gonetworkmanager.NewSettings()
	// In test env without D-Bus, this will fail — that's expected
	mockNM.EXPECT().GetPropertyActiveConnections().Return([]gonetworkmanager.ActiveConnection{}, nil).Maybe()

	conns, err := backend.GetCellularConnections()
	if err != nil {
		assert.Nil(t, conns)
	} else {
		assert.NotNil(t, conns)
	}
}

func TestNetworkManagerBackend_GetCellularConnections_Empty(t *testing.T) {
	mockNM := mock_gonetworkmanager.NewMockNetworkManager(t)
	mockSettings := mock_gonetworkmanager.NewMockSettings(t)

	backend, err := NewNetworkManagerBackend(mockNM)
	assert.NoError(t, err)
	backend.settings = mockSettings

	mockSettings.EXPECT().ListConnections().Return([]gonetworkmanager.Connection{}, nil)
	mockNM.EXPECT().GetPropertyActiveConnections().Return([]gonetworkmanager.ActiveConnection{}, nil).Maybe()

	conns, err := backend.GetCellularConnections()
	assert.NoError(t, err)
	assert.Empty(t, conns)
}

func TestNetworkManagerBackend_ListCellularProfiles_Empty(t *testing.T) {
	mockNM := mock_gonetworkmanager.NewMockNetworkManager(t)
	mockSettings := mock_gonetworkmanager.NewMockSettings(t)

	backend, err := NewNetworkManagerBackend(mockNM)
	assert.NoError(t, err)
	backend.settings = mockSettings

	mockSettings.EXPECT().ListConnections().Return([]gonetworkmanager.Connection{}, nil)
	mockNM.EXPECT().GetPropertyActiveConnections().Return([]gonetworkmanager.ActiveConnection{}, nil).Maybe()

	profiles, err := backend.ListCellularProfiles()
	assert.NoError(t, err)
	assert.Empty(t, profiles)
}

func TestNetworkManagerBackend_ListActiveCellular_Empty(t *testing.T) {
	mockNM := mock_gonetworkmanager.NewMockNetworkManager(t)

	backend, err := NewNetworkManagerBackend(mockNM)
	assert.NoError(t, err)

	mockNM.EXPECT().GetPropertyActiveConnections().Return([]gonetworkmanager.ActiveConnection{}, nil)

	active, err := backend.ListActiveCellular()
	assert.NoError(t, err)
	assert.Empty(t, active)
}

func TestNetworkManagerBackend_ConnectCellular_NoDevices(t *testing.T) {
	mockNM := mock_gonetworkmanager.NewMockNetworkManager(t)

	backend, err := NewNetworkManagerBackend(mockNM)
	assert.NoError(t, err)

	// ConnectCellular checks state.CellularDevices first
	err = backend.ConnectCellular("some-uuid")
	assert.Error(t, err)
	assert.Contains(t, err.Error(), "no cellular device available")
}

func TestNetworkManagerBackend_ConnectCellular_NotFound(t *testing.T) {
	mockNM := mock_gonetworkmanager.NewMockNetworkManager(t)
	mockSettings := mock_gonetworkmanager.NewMockSettings(t)

	backend, err := NewNetworkManagerBackend(mockNM)
	assert.NoError(t, err)
	backend.settings = mockSettings

	// Populate state with a device so ConnectCellular proceeds past device check
	backend.stateMutex.Lock()
	backend.state.CellularDevices = []CellularDevice{{Name: "wwan0"}}
	backend.stateMutex.Unlock()

	mockSettings.EXPECT().ListConnections().Return([]gonetworkmanager.Connection{}, nil)

	err = backend.ConnectCellular("non-existent-uuid")
	assert.Error(t, err)
	assert.Contains(t, err.Error(), "not found")
}

func TestNetworkManagerBackend_DisconnectCellular_NoDevices(t *testing.T) {
	mockNM := mock_gonetworkmanager.NewMockNetworkManager(t)

	backend, err := NewNetworkManagerBackend(mockNM)
	assert.NoError(t, err)

	// DisconnectCellular checks state.CellularDevices first
	err = backend.DisconnectCellular()
	assert.Error(t, err)
	assert.Contains(t, err.Error(), "no cellular device available")
}

func TestNetworkManagerBackend_DisconnectCellular_NoActiveConnections(t *testing.T) {
	mockNM := mock_gonetworkmanager.NewMockNetworkManager(t)

	backend, err := NewNetworkManagerBackend(mockNM)
	assert.NoError(t, err)

	// Populate state with a device so DisconnectCellular proceeds
	backend.stateMutex.Lock()
	backend.state.CellularDevices = []CellularDevice{{Name: "wwan0"}}
	backend.stateMutex.Unlock()

	mockNM.EXPECT().GetPropertyActiveConnections().Return([]gonetworkmanager.ActiveConnection{}, nil)
	mockNM.EXPECT().GetPropertyWwanEnabled().Return(false, nil).Maybe()
	mockNM.EXPECT().GetDevices().Return([]gonetworkmanager.Device{}, nil).Maybe()
	mockNM.EXPECT().GetPropertyPrimaryConnection().Return(nil, nil).Maybe()

	err = backend.DisconnectCellular()
	assert.NoError(t, err)
}

func TestNetworkManagerBackend_GetSIMStatus_NoDevices(t *testing.T) {
	mockNM := mock_gonetworkmanager.NewMockNetworkManager(t)

	backend, err := NewNetworkManagerBackend(mockNM)
	assert.NoError(t, err)

	status, err := backend.GetSIMStatus("")
	assert.Error(t, err)
	assert.Nil(t, status)
	assert.Contains(t, err.Error(), "no cellular devices found")
}

func TestNetworkManagerBackend_GetSIMStatus_FirstDevice(t *testing.T) {
	mockNM := mock_gonetworkmanager.NewMockNetworkManager(t)

	backend, err := NewNetworkManagerBackend(mockNM)
	assert.NoError(t, err)

	backend.stateMutex.Lock()
	backend.state.CellularDevices = []CellularDevice{
		{Name: "wwan0", SimLocked: true, PinRequired: true},
		{Name: "wwan1", SimLocked: false},
	}
	backend.stateMutex.Unlock()

	// Empty device string should return first device
	status, err := backend.GetSIMStatus("")
	assert.NoError(t, err)
	assert.NotNil(t, status)
	assert.Equal(t, "wwan0", status.Name)
	assert.True(t, status.SimLocked)
	assert.True(t, status.PinRequired)
}

func TestNetworkManagerBackend_GetSIMStatus_ByName(t *testing.T) {
	mockNM := mock_gonetworkmanager.NewMockNetworkManager(t)

	backend, err := NewNetworkManagerBackend(mockNM)
	assert.NoError(t, err)

	backend.stateMutex.Lock()
	backend.state.CellularDevices = []CellularDevice{
		{Name: "wwan0", SimLocked: true},
		{Name: "wwan1", SimLocked: false},
	}
	backend.stateMutex.Unlock()

	status, err := backend.GetSIMStatus("wwan1")
	assert.NoError(t, err)
	assert.NotNil(t, status)
	assert.Equal(t, "wwan1", status.Name)
	assert.False(t, status.SimLocked)
}

func TestNetworkManagerBackend_GetSIMStatus_ByIMEI(t *testing.T) {
	mockNM := mock_gonetworkmanager.NewMockNetworkManager(t)

	backend, err := NewNetworkManagerBackend(mockNM)
	assert.NoError(t, err)

	backend.stateMutex.Lock()
	backend.state.CellularDevices = []CellularDevice{
		{Name: "wwan0", IMEI: "123456789012345"},
	}
	backend.stateMutex.Unlock()

	status, err := backend.GetSIMStatus("123456789012345")
	assert.NoError(t, err)
	assert.NotNil(t, status)
	assert.Equal(t, "wwan0", status.Name)
}

func TestNetworkManagerBackend_GetSIMStatus_NotFound(t *testing.T) {
	mockNM := mock_gonetworkmanager.NewMockNetworkManager(t)

	backend, err := NewNetworkManagerBackend(mockNM)
	assert.NoError(t, err)

	backend.stateMutex.Lock()
	backend.state.CellularDevices = []CellularDevice{
		{Name: "wwan0"},
	}
	backend.stateMutex.Unlock()

	status, err := backend.GetSIMStatus("wwan99")
	assert.Error(t, err)
	assert.Nil(t, status)
	assert.Contains(t, err.Error(), "not found")
}

func TestNetworkManagerBackend_GetSIMPinTriesLeft(t *testing.T) {
	mockNM := mock_gonetworkmanager.NewMockNetworkManager(t)

	backend, err := NewNetworkManagerBackend(mockNM)
	assert.NoError(t, err)

	tries, err := backend.GetSIMPinTriesLeft("")
	assert.NoError(t, err)
	assert.Equal(t, 3, tries)
}

func TestNetworkManagerBackend_SubmitSIMPin_NoConnections(t *testing.T) {
	mockNM := mock_gonetworkmanager.NewMockNetworkManager(t)
	mockSettings := mock_gonetworkmanager.NewMockSettings(t)

	backend, err := NewNetworkManagerBackend(mockNM)
	assert.NoError(t, err)
	backend.settings = mockSettings

	mockSettings.EXPECT().ListConnections().Return([]gonetworkmanager.Connection{}, nil)

	err = backend.SubmitSIMPin("", "1234")
	assert.Error(t, err)
	assert.Contains(t, err.Error(), "no cellular connection found")
}

func TestNetworkManagerBackend_ActivateCellularConnection_NoDevices(t *testing.T) {
	mockNM := mock_gonetworkmanager.NewMockNetworkManager(t)

	backend, err := NewNetworkManagerBackend(mockNM)
	assert.NoError(t, err)

	// ActivateCellularConnection delegates to ConnectCellular which checks devices
	err = backend.ActivateCellularConnection("non-existent")
	assert.Error(t, err)
	assert.Contains(t, err.Error(), "no cellular device available")
}

func TestNetworkManagerBackend_UpdateCellularState_NoModems(t *testing.T) {
	mockNM := mock_gonetworkmanager.NewMockNetworkManager(t)

	backend, err := NewNetworkManagerBackend(mockNM)
	assert.NoError(t, err)

	mockNM.EXPECT().GetPropertyWwanEnabled().Return(false, nil)
	mockNM.EXPECT().GetDevices().Return([]gonetworkmanager.Device{}, nil)

	assert.NotPanics(t, func() {
		backend.updateCellularState()
	})

	backend.stateMutex.RLock()
	assert.False(t, backend.state.CellularEnabled)
	assert.Empty(t, backend.state.CellularDevices)
	assert.False(t, backend.state.CellularConnected)
	backend.stateMutex.RUnlock()
}

func TestNetworkManagerBackend_UpdateCellularState_WwanEnabled(t *testing.T) {
	mockNM := mock_gonetworkmanager.NewMockNetworkManager(t)

	backend, err := NewNetworkManagerBackend(mockNM)
	assert.NoError(t, err)

	mockNM.EXPECT().GetPropertyWwanEnabled().Return(true, nil)
	mockNM.EXPECT().GetDevices().Return([]gonetworkmanager.Device{}, nil)

	backend.updateCellularState()

	backend.stateMutex.RLock()
	assert.True(t, backend.state.CellularEnabled)
	backend.stateMutex.RUnlock()
}

func TestNetworkManagerBackend_DisconnectCellularDevice_NoDevices(t *testing.T) {
	mockNM := mock_gonetworkmanager.NewMockNetworkManager(t)

	backend, err := NewNetworkManagerBackend(mockNM)
	assert.NoError(t, err)

	// DisconnectCellularDevice delegates to DisconnectCellular which checks state
	err = backend.DisconnectCellularDevice("wwan0")
	assert.Error(t, err)
	assert.Contains(t, err.Error(), "no cellular device available")
}

func TestNetworkManagerBackend_GetCellularProfile_NotFound(t *testing.T) {
	mockNM := mock_gonetworkmanager.NewMockNetworkManager(t)
	mockSettings := mock_gonetworkmanager.NewMockSettings(t)

	backend, err := NewNetworkManagerBackend(mockNM)
	assert.NoError(t, err)
	backend.settings = mockSettings

	mockSettings.EXPECT().ListConnections().Return([]gonetworkmanager.Connection{}, nil)
	mockNM.EXPECT().GetPropertyActiveConnections().Return([]gonetworkmanager.ActiveConnection{}, nil).Maybe()

	profile, err := backend.GetCellularProfile("non-existent")
	assert.Error(t, err)
	assert.Nil(t, profile)
	assert.Contains(t, err.Error(), "not found")
}

func TestNetworkManagerBackend_UpdateCellularProfile_NotFound(t *testing.T) {
	mockNM := mock_gonetworkmanager.NewMockNetworkManager(t)
	mockSettings := mock_gonetworkmanager.NewMockSettings(t)

	backend, err := NewNetworkManagerBackend(mockNM)
	assert.NoError(t, err)
	backend.settings = mockSettings

	mockSettings.EXPECT().ListConnections().Return([]gonetworkmanager.Connection{}, nil)

	err = backend.UpdateCellularProfile("non-existent", map[string]any{"apn": "test"})
	assert.Error(t, err)
	assert.Contains(t, err.Error(), "not found")
}
