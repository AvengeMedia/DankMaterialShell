package cups

import (
	"bytes"
	"encoding/json"
	"fmt"
	"testing"

	"github.com/AvengeMedia/DankMaterialShell/core/internal/server/models"
	"github.com/AvengeMedia/DankMaterialShell/core/pkg/ipp"
	"github.com/stretchr/testify/assert"
)

func TestValidateTestConnectionParams(t *testing.T) {
	tests := []struct {
		name     string
		host     string
		port     int
		protocol string
		wantErr  string
	}{
		{
			name:     "valid ipp",
			host:     "192.168.0.5",
			port:     631,
			protocol: "ipp",
			wantErr:  "",
		},
		{
			name:     "valid ipps",
			host:     "printer.local",
			port:     443,
			protocol: "ipps",
			wantErr:  "",
		},
		{
			name:     "valid lpd",
			host:     "10.0.0.1",
			port:     515,
			protocol: "lpd",
			wantErr:  "",
		},
		{
			name:     "valid socket",
			host:     "10.0.0.1",
			port:     9100,
			protocol: "socket",
			wantErr:  "",
		},
		{
			name:     "empty host",
			host:     "",
			port:     631,
			protocol: "ipp",
			wantErr:  "host is required",
		},
		{
			name:     "port too low",
			host:     "192.168.0.5",
			port:     0,
			protocol: "ipp",
			wantErr:  "port must be between 1 and 65535",
		},
		{
			name:     "port too high",
			host:     "192.168.0.5",
			port:     70000,
			protocol: "ipp",
			wantErr:  "port must be between 1 and 65535",
		},
		{
			name:     "invalid protocol",
			host:     "192.168.0.5",
			port:     631,
			protocol: "ftp",
			wantErr:  "protocol must be one of: ipp, ipps, lpd, socket",
		},
		{
			name:     "empty protocol treated as ipp",
			host:     "192.168.0.5",
			port:     631,
			protocol: "",
			wantErr:  "",
		},
		{
			name:     "host with slash",
			host:     "192.168.0.5/admin",
			port:     631,
			protocol: "ipp",
			wantErr:  "host contains invalid characters",
		},
		{
			name:     "host with space",
			host:     "192.168.0.5 ",
			port:     631,
			protocol: "ipp",
			wantErr:  "host contains invalid characters",
		},
		{
			name:     "host with newline",
			host:     "192.168.0.5\n",
			port:     631,
			protocol: "ipp",
			wantErr:  "host contains invalid characters",
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			err := validateTestConnectionParams(tt.host, tt.port, tt.protocol)
			if tt.wantErr == "" {
				assert.NoError(t, err)
			} else {
				assert.EqualError(t, err, tt.wantErr)
			}
		})
	}
}

func TestManager_TestRemotePrinter_Validation(t *testing.T) {
	m := NewTestManager(nil, nil)

	tests := []struct {
		name     string
		host     string
		port     int
		protocol string
		wantErr  string
	}{
		{
			name:     "empty host returns error",
			host:     "",
			port:     631,
			protocol: "ipp",
			wantErr:  "host is required",
		},
		{
			name:     "invalid port returns error",
			host:     "192.168.0.5",
			port:     0,
			protocol: "ipp",
			wantErr:  "port must be between 1 and 65535",
		},
		{
			name:     "invalid protocol returns error",
			host:     "192.168.0.5",
			port:     631,
			protocol: "ftp",
			wantErr:  "protocol must be one of: ipp, ipps, lpd, socket",
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			_, err := m.TestRemotePrinter(tt.host, tt.port, tt.protocol)
			assert.EqualError(t, err, tt.wantErr)
		})
	}
}

func TestManager_TestRemotePrinter_IPP(t *testing.T) {
	tests := []struct {
		name      string
		protocol  string
		probeRet  *RemotePrinterInfo
		probeErr  error
		wantTLS   bool
		wantReach bool
		wantModel string
	}{
		{
			name:     "successful ipp probe",
			protocol: "ipp",
			probeRet: &RemotePrinterInfo{
				Reachable: true,
				MakeModel: "HP OfficeJet 8010",
				Name:      "OfficeJet",
				State:     "idle",
				URI:       "ipp://192.168.0.5:631/ipp/print",
			},
			wantTLS:   false,
			wantReach: true,
			wantModel: "HP OfficeJet 8010",
		},
		{
			name:     "successful ipps probe",
			protocol: "ipps",
			probeRet: &RemotePrinterInfo{
				Reachable: true,
				MakeModel: "HP OfficeJet 8010",
				URI:       "ipps://192.168.0.5:631/ipp/print",
			},
			wantTLS:   true,
			wantReach: true,
			wantModel: "HP OfficeJet 8010",
		},
		{
			name:     "unreachable host",
			protocol: "ipp",
			probeRet: &RemotePrinterInfo{
				Reachable: false,
				Error:     "cannot reach 192.168.0.5:631: connection refused",
			},
			wantReach: false,
		},
		{
			name:     "empty protocol defaults to ipp",
			protocol: "",
			probeRet: &RemotePrinterInfo{
				Reachable: true,
				MakeModel: "Test Printer",
			},
			wantTLS:   false,
			wantReach: true,
			wantModel: "Test Printer",
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			var capturedTLS bool
			m := NewTestManager(nil, nil)
			m.probeRemoteFn = func(host string, port int, useTLS bool) (*RemotePrinterInfo, error) {
				capturedTLS = useTLS
				return tt.probeRet, tt.probeErr
			}

			result, err := m.TestRemotePrinter("192.168.0.5", 631, tt.protocol)
			if tt.probeErr != nil {
				assert.Error(t, err)
				return
			}
			assert.NoError(t, err)
			assert.Equal(t, tt.wantReach, result.Reachable)
			assert.Equal(t, tt.wantModel, result.MakeModel)
			assert.Equal(t, tt.wantTLS, capturedTLS)
		})
	}
}

func TestManager_TestRemotePrinter_AuthRequired(t *testing.T) {
	m := NewTestManager(nil, nil)
	m.probeRemoteFn = func(host string, port int, useTLS bool) (*RemotePrinterInfo, error) {
		// Simulate what happens when the printer returns HTTP 401
		return probeRemotePrinterWithAuthError(host, port, useTLS)
	}

	result, err := m.TestRemotePrinter("192.168.0.107", 631, "ipp")
	assert.NoError(t, err)
	assert.True(t, result.Reachable)
	assert.Equal(t, "authentication required", result.Info)
	assert.Contains(t, result.URI, "ipp://192.168.0.107:631")
}

// probeRemotePrinterWithAuthError simulates a probe where the printer
// returns HTTP 401 on both endpoints.
func probeRemotePrinterWithAuthError(host string, port int, useTLS bool) (*RemotePrinterInfo, error) {
	// This simulates what probeRemotePrinter does when both endpoints
	// return auth errors. We test the auth detection logic directly.
	err := ipp.HTTPError{Code: 401}
	if isAuthError(err) {
		proto := "ipp"
		if useTLS {
			proto = "ipps"
		}
		return &RemotePrinterInfo{
			Reachable: true,
			URI:       fmt.Sprintf("%s://%s:%d/ipp/print", proto, host, port),
			Info:      "authentication required",
		}, nil
	}
	return nil, err
}

func TestManager_TestRemotePrinter_NonIPPProtocol(t *testing.T) {
	m := NewTestManager(nil, nil)
	probeCalled := false
	m.probeRemoteFn = func(host string, port int, useTLS bool) (*RemotePrinterInfo, error) {
		probeCalled = true
		return nil, nil
	}

	// These will fail at TCP dial (no real server), but the important
	// thing is that probeRemoteFn is NOT called for lpd/socket.
	m.TestRemotePrinter("192.168.0.5", 9100, "socket")
	assert.False(t, probeCalled, "probe function should not be called for socket protocol")

	m.TestRemotePrinter("192.168.0.5", 515, "lpd")
	assert.False(t, probeCalled, "probe function should not be called for lpd protocol")
}

func TestHandleTestConnection_Success(t *testing.T) {
	m := NewTestManager(nil, nil)
	m.probeRemoteFn = func(host string, port int, useTLS bool) (*RemotePrinterInfo, error) {
		return &RemotePrinterInfo{
			Reachable: true,
			MakeModel: "HP OfficeJet 8010",
			Name:      "OfficeJet",
			State:     "idle",
			URI:       "ipp://192.168.0.5:631/ipp/print",
		}, nil
	}

	buf := &bytes.Buffer{}
	conn := &mockConn{Buffer: buf}

	req := models.Request{
		ID:     1,
		Method: "cups.testConnection",
		Params: map[string]any{
			"host": "192.168.0.5",
		},
	}

	handleTestConnection(conn, req, m)

	var resp models.Response[RemotePrinterInfo]
	err := json.NewDecoder(buf).Decode(&resp)
	assert.NoError(t, err)
	assert.NotNil(t, resp.Result)
	assert.True(t, resp.Result.Reachable)
	assert.Equal(t, "HP OfficeJet 8010", resp.Result.MakeModel)
}

func TestHandleTestConnection_MissingHost(t *testing.T) {
	m := NewTestManager(nil, nil)
	buf := &bytes.Buffer{}
	conn := &mockConn{Buffer: buf}

	req := models.Request{
		ID:     1,
		Method: "cups.testConnection",
		Params: map[string]any{},
	}

	handleTestConnection(conn, req, m)

	var resp models.Response[any]
	err := json.NewDecoder(buf).Decode(&resp)
	assert.NoError(t, err)
	assert.Nil(t, resp.Result)
	assert.NotNil(t, resp.Error)
}

func TestHandleTestConnection_CustomPortAndProtocol(t *testing.T) {
	m := NewTestManager(nil, nil)
	m.probeRemoteFn = func(host string, port int, useTLS bool) (*RemotePrinterInfo, error) {
		assert.Equal(t, 9631, port)
		assert.True(t, useTLS)
		return &RemotePrinterInfo{Reachable: true, URI: "ipps://192.168.0.5:9631/ipp/print"}, nil
	}

	buf := &bytes.Buffer{}
	conn := &mockConn{Buffer: buf}

	req := models.Request{
		ID:     1,
		Method: "cups.testConnection",
		Params: map[string]any{
			"host":     "192.168.0.5",
			"port":     float64(9631),
			"protocol": "ipps",
		},
	}

	handleTestConnection(conn, req, m)

	var resp models.Response[RemotePrinterInfo]
	err := json.NewDecoder(buf).Decode(&resp)
	assert.NoError(t, err)
	assert.NotNil(t, resp.Result)
	assert.True(t, resp.Result.Reachable)
}

func TestHandleRequest_TestConnection(t *testing.T) {
	m := NewTestManager(nil, nil)
	m.probeRemoteFn = func(host string, port int, useTLS bool) (*RemotePrinterInfo, error) {
		return &RemotePrinterInfo{Reachable: true}, nil
	}

	buf := &bytes.Buffer{}
	conn := &mockConn{Buffer: buf}

	req := models.Request{
		ID:     1,
		Method: "cups.testConnection",
		Params: map[string]any{"host": "192.168.0.5"},
	}

	HandleRequest(conn, req, m)

	var resp models.Response[RemotePrinterInfo]
	err := json.NewDecoder(buf).Decode(&resp)
	assert.NoError(t, err)
	assert.NotNil(t, resp.Result)
	assert.True(t, resp.Result.Reachable)
}
