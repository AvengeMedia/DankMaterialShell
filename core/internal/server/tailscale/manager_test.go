package tailscale

import (
	"fmt"
	"net/http"
	"net/http/httptest"
	"reflect"
	"testing"

	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
)

// roundTripFunc adapts a function to http.RoundTripper.
// This lets us intercept all requests from local.Client and route them
// to our httptest server, regardless of the target hostname.
type roundTripFunc func(*http.Request) (*http.Response, error)

func (f roundTripFunc) RoundTrip(req *http.Request) (*http.Response, error) {
	return f(req)
}

// sampleLocalAPIResponse is a realistic /localapi/v0/status JSON response
// matching what the official Tailscale local API returns.
const sampleLocalAPIResponse = `{
	"Version": "1.94.2",
	"BackendState": "Running",
	"TUN": true,
	"HaveNodeKey": true,
	"TailscaleIPs": ["100.85.254.40", "fd7a:115c:a1e0::1"],
	"Self": {
		"ID": "node1",
		"HostName": "cachyos",
		"DNSName": "cachyos.example.ts.net.",
		"OS": "linux",
		"TailscaleIPs": ["100.85.254.40", "fd7a:115c:a1e0::1"],
		"Online": true,
		"UserID": 12345
	},
	"MagicDNSSuffix": "example.ts.net",
	"CurrentTailnet": {
		"Name": "user@example.com",
		"MagicDNSSuffix": "example.ts.net"
	},
	"Peer": {
		"nodekey:0000000000000000000000000000000000000000000000000000000000000001": {
			"ID": "node2",
			"HostName": "thinkpad-x390",
			"DNSName": "thinkpad-x390.example.ts.net.",
			"OS": "linux",
			"TailscaleIPs": ["100.97.21.17", "fd7a:115c:a1e0::2"],
			"Online": true,
			"Active": true,
			"Relay": "fra",
			"RxBytes": 1024,
			"TxBytes": 2048,
			"UserID": 12345,
			"ExitNode": false,
			"LastSeen": "2026-03-01T12:00:00Z"
		},
		"nodekey:0000000000000000000000000000000000000000000000000000000000000002": {
			"ID": "node3",
			"HostName": "k8s-node",
			"DNSName": "k8s-node.example.ts.net.",
			"OS": "linux",
			"TailscaleIPs": ["100.100.100.1"],
			"Online": false,
			"Active": false,
			"Tags": ["tag:k8s"],
			"UserID": 0,
			"LastSeen": "2026-02-28T10:00:00Z"
		}
	},
	"User": {
		"12345": {
			"ID": 12345,
			"LoginName": "user@example.com",
			"DisplayName": "User"
		}
	}
}`

// newTestServerTransport creates an httptest server returning the given response
// and a roundTripFunc that redirects local.Client requests to it.
func newTestServerTransport(response string) (*httptest.Server, roundTripFunc) {
	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		w.Header().Set("Content-Type", "application/json")
		w.Write([]byte(response))
	}))
	// local.Client sends to http://local-tailscaled.sock/localapi/v0/status
	// We rewrite the URL to point at our httptest server instead.
	transport := roundTripFunc(func(req *http.Request) (*http.Response, error) {
		req.URL.Scheme = "http"
		req.URL.Host = server.Listener.Addr().String()
		return http.DefaultTransport.RoundTrip(req)
	})
	return server, transport
}

func TestManager_GetState(t *testing.T) {
	server, transport := newTestServerTransport(sampleLocalAPIResponse)
	defer server.Close()

	m := newTestManager(transport)
	defer m.Close()

	err := m.poll()
	require.NoError(t, err)

	state := m.GetState()
	assert.True(t, state.Connected)
	assert.Equal(t, "cachyos", state.Self.Hostname)
	assert.Equal(t, "1.94.2", state.Version)
	assert.Equal(t, "Running", state.BackendState)
}

func TestManager_PollError(t *testing.T) {
	// Transport that always fails — simulates unreachable daemon
	failTransport := roundTripFunc(func(req *http.Request) (*http.Response, error) {
		return nil, fmt.Errorf("connection refused")
	})

	m := newTestManager(failTransport)
	defer m.Close()

	err := m.poll()
	require.Error(t, err)

	// State should remain at initial empty state
	state := m.GetState()
	assert.False(t, state.Connected)
}

func TestManager_Subscribe(t *testing.T) {
	server, transport := newTestServerTransport(sampleLocalAPIResponse)
	defer server.Close()

	m := newTestManager(transport)
	defer m.Close()

	err := m.poll()
	require.NoError(t, err)

	ch := m.Subscribe("test-client-1")
	assert.NotNil(t, ch)

	ch2 := m.Subscribe("test-client-2")
	assert.NotNil(t, ch2)

	m.Unsubscribe("test-client-1")
	m.Unsubscribe("test-client-2")
}

func TestManager_Close(t *testing.T) {
	server, transport := newTestServerTransport(sampleLocalAPIResponse)
	defer server.Close()

	m := newTestManager(transport)

	ch := m.Subscribe("test-client")
	assert.NotNil(t, ch)

	assert.NotPanics(t, func() {
		m.Close()
	})
}

func TestStateChanged(t *testing.T) {
	state1 := &TailscaleState{
		Connected:    true,
		BackendState: "Running",
		Version:      "1.94.2",
		Peers:        []Peer{{Hostname: "a", Online: true}},
	}

	// Same state should not be changed
	state2 := &TailscaleState{
		Connected:    true,
		BackendState: "Running",
		Version:      "1.94.2",
		Peers:        []Peer{{Hostname: "a", Online: true}},
	}

	// reflect.DeepEqual: identical structs
	assert.True(t, reflect.DeepEqual(state1, state2))

	// nil vs state
	assert.False(t, reflect.DeepEqual(nil, state1))

	// Modified state
	state3 := &TailscaleState{
		Connected:    false,
		BackendState: "Stopped",
	}
	assert.False(t, reflect.DeepEqual(state1, state3))

	// Different peer count
	state4 := &TailscaleState{
		Connected:    true,
		BackendState: "Running",
		Version:      "1.94.2",
		Peers:        []Peer{},
	}
	assert.False(t, reflect.DeepEqual(state1, state4))
}
