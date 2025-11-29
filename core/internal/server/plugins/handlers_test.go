package plugins

import (
	"encoding/json"
	"testing"

	"github.com/AvengeMedia/DankMaterialShell/core/internal/mocks/net"
	"github.com/AvengeMedia/DankMaterialShell/core/internal/server/models"
	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/mock"
)

func TestHandleList(t *testing.T) {
	conn := net.NewMockConn(t)
	conn.EXPECT().Write(mock.Anything).Return(0, nil).Maybe()

	req := models.Request{
		ID:     123,
		Method: "plugins.list",
		Params: map[string]any{},
	}

	HandleList(conn, req)
}

func TestHandleListInstalled(t *testing.T) {
	conn := net.NewMockConn(t)
	conn.EXPECT().Write(mock.Anything).Return(0, nil).Maybe()

	req := models.Request{
		ID:     123,
		Method: "plugins.listInstalled",
		Params: map[string]any{},
	}

	HandleListInstalled(conn, req)
}

func TestHandleInstallMissingName(t *testing.T) {
	conn := net.NewMockConn(t)
	var written []byte
	conn.EXPECT().Write(mock.Anything).RunAndReturn(func(b []byte) (int, error) {
		written = b
		return len(b), nil
	}).Maybe()

	req := models.Request{
		ID:     123,
		Method: "plugins.install",
		Params: map[string]any{},
	}

	HandleInstall(conn, req)

	var resp models.Response[SuccessResult]
	err := json.Unmarshal(written, &resp)
	assert.NoError(t, err)
	assert.NotEmpty(t, resp.Error)
	assert.Contains(t, resp.Error, "missing or invalid 'name' parameter")
}

func TestHandleInstallInvalidName(t *testing.T) {
	conn := net.NewMockConn(t)
	var written []byte
	conn.EXPECT().Write(mock.Anything).RunAndReturn(func(b []byte) (int, error) {
		written = b
		return len(b), nil
	}).Maybe()

	req := models.Request{
		ID:     123,
		Method: "plugins.install",
		Params: map[string]any{
			"name": 123,
		},
	}

	HandleInstall(conn, req)

	var resp models.Response[SuccessResult]
	err := json.Unmarshal(written, &resp)
	assert.NoError(t, err)
	assert.NotEmpty(t, resp.Error)
}

func TestHandleUninstallMissingName(t *testing.T) {
	conn := net.NewMockConn(t)
	var written []byte
	conn.EXPECT().Write(mock.Anything).RunAndReturn(func(b []byte) (int, error) {
		written = b
		return len(b), nil
	}).Maybe()

	req := models.Request{
		ID:     123,
		Method: "plugins.uninstall",
		Params: map[string]any{},
	}

	HandleUninstall(conn, req)

	var resp models.Response[SuccessResult]
	err := json.Unmarshal(written, &resp)
	assert.NoError(t, err)
	assert.NotEmpty(t, resp.Error)
}

func TestHandleUpdateMissingName(t *testing.T) {
	conn := net.NewMockConn(t)
	var written []byte
	conn.EXPECT().Write(mock.Anything).RunAndReturn(func(b []byte) (int, error) {
		written = b
		return len(b), nil
	}).Maybe()

	req := models.Request{
		ID:     123,
		Method: "plugins.update",
		Params: map[string]any{},
	}

	HandleUpdate(conn, req)

	var resp models.Response[SuccessResult]
	err := json.Unmarshal(written, &resp)
	assert.NoError(t, err)
	assert.NotEmpty(t, resp.Error)
}

func TestHandleSearchMissingQuery(t *testing.T) {
	conn := net.NewMockConn(t)
	var written []byte
	conn.EXPECT().Write(mock.Anything).RunAndReturn(func(b []byte) (int, error) {
		written = b
		return len(b), nil
	}).Maybe()

	req := models.Request{
		ID:     123,
		Method: "plugins.search",
		Params: map[string]any{},
	}

	HandleSearch(conn, req)

	var resp models.Response[[]PluginInfo]
	err := json.Unmarshal(written, &resp)
	assert.NoError(t, err)
	assert.NotEmpty(t, resp.Error)
}

func TestSortPluginInfoByFirstParty(t *testing.T) {
	plugins := []PluginInfo{
		{Name: "third-party", Repo: "https://github.com/other/test"},
		{Name: "first-party", Repo: "https://github.com/AvengeMedia/test"},
	}

	SortPluginInfoByFirstParty(plugins)

	assert.Equal(t, "first-party", plugins[0].Name)
	assert.Equal(t, "third-party", plugins[1].Name)
}

func TestPluginInfoJSON(t *testing.T) {
	info := PluginInfo{
		Name:        "test",
		Description: "test description",
		Installed:   true,
		FirstParty:  true,
	}

	data, err := json.Marshal(info)
	assert.NoError(t, err)

	var unmarshaled PluginInfo
	err = json.Unmarshal(data, &unmarshaled)
	assert.NoError(t, err)
	assert.Equal(t, info.Name, unmarshaled.Name)
	assert.Equal(t, info.Installed, unmarshaled.Installed)
}

func TestSuccessResult(t *testing.T) {
	result := SuccessResult{
		Success: true,
		Message: "test message",
	}

	data, err := json.Marshal(result)
	assert.NoError(t, err)

	var unmarshaled SuccessResult
	err = json.Unmarshal(data, &unmarshaled)
	assert.NoError(t, err)
	assert.True(t, unmarshaled.Success)
	assert.Equal(t, "test message", unmarshaled.Message)
}
