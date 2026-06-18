package tailscale

import (
	"net/netip"
	"testing"
	"time"

	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
	"go4.org/mem"
	"tailscale.com/ipn/ipnstate"
	"tailscale.com/tailcfg"
	"tailscale.com/types/key"
	"tailscale.com/types/views"
)

func makeTestStatus() *ipnstate.Status {
	return &ipnstate.Status{
		Version:        "1.94.2",
		BackendState:   "Running",
		MagicDNSSuffix: "example.ts.net",
		CurrentTailnet: &ipnstate.TailnetStatus{
			Name:           "user@example.com",
			MagicDNSSuffix: "example.ts.net",
		},
		Self: &ipnstate.PeerStatus{
			ID:       "node1",
			HostName: "cachyos",
			DNSName:  "cachyos.example.ts.net.",
			OS:       "linux",
			TailscaleIPs: []netip.Addr{
				netip.MustParseAddr("100.85.254.40"),
				netip.MustParseAddr("fd7a:115c:a1e0::1"),
			},
			Online: true,
			UserID: 12345,
		},
		Peer: map[key.NodePublic]*ipnstate.PeerStatus{
			key.NodePublicFromRaw32(mem.B(make([]byte, 32))): {
				ID:       "node2",
				HostName: "thinkpad-x390",
				DNSName:  "thinkpad-x390.example.ts.net.",
				OS:       "linux",
				TailscaleIPs: []netip.Addr{
					netip.MustParseAddr("100.97.21.17"),
					netip.MustParseAddr("fd7a:115c:a1e0::2"),
				},
				Online:   true,
				Active:   true,
				Relay:    "fra",
				RxBytes:  1024,
				TxBytes:  2048,
				UserID:   12345,
				ExitNode: false,
				LastSeen: time.Date(2026, 3, 1, 12, 0, 0, 0, time.UTC),
			},
		},
		User: map[tailcfg.UserID]tailcfg.UserProfile{
			12345: {
				ID:          12345,
				LoginName:   "user@example.com",
				DisplayName: "User",
			},
		},
	}
}

func TestConvertStatus_Running(t *testing.T) {
	status := makeTestStatus()
	state := convertStatus(status)

	require.NotNil(t, state)
	assert.True(t, state.Connected)
	assert.Equal(t, "1.94.2", state.Version)
	assert.Equal(t, "Running", state.BackendState)
	assert.Equal(t, "example.ts.net", state.MagicDNSSuffix)
	assert.Equal(t, "user@example.com", state.TailnetName)

	// Self
	assert.Equal(t, "cachyos", state.Self.Hostname)
	assert.Equal(t, "cachyos.example.ts.net", state.Self.DNSName)
	assert.Equal(t, "100.85.254.40", state.Self.TailscaleIP)
	assert.Equal(t, "fd7a:115c:a1e0::1", state.Self.TailscaleIPv6)
	assert.Equal(t, "linux", state.Self.OS)
	assert.True(t, state.Self.Online)

	// Peers
	require.Len(t, state.Peers, 1)
	peer := state.Peers[0]
	assert.Equal(t, "thinkpad-x390", peer.Hostname)
	assert.Equal(t, "100.97.21.17", peer.TailscaleIP)
	assert.Equal(t, "fra", peer.Relay)
	assert.Equal(t, "user@example.com", peer.Owner)
	assert.Equal(t, int64(1024), peer.RxBytes)
	assert.True(t, peer.Online)
}

func TestConvertStatus_NotRunning(t *testing.T) {
	status := &ipnstate.Status{
		BackendState: "Stopped",
	}

	state := convertStatus(status)
	assert.False(t, state.Connected)
	assert.Equal(t, "Stopped", state.BackendState)
	assert.Empty(t, state.Peers)
}

func TestConvertStatus_NilSelf(t *testing.T) {
	status := &ipnstate.Status{
		BackendState: "Running",
	}

	state := convertStatus(status)
	assert.True(t, state.Connected)
	assert.Equal(t, Peer{}, state.Self)
}

func TestConvertPeerStatus_Tags(t *testing.T) {
	tags := views.SliceOf([]string{"tag:k8s", "tag:server"})
	ps := &ipnstate.PeerStatus{
		ID:       "node3",
		HostName: "k8s-node",
		DNSName:  "k8s-node.example.ts.net.",
		OS:       "linux",
		Online:   false,
		Tags:     &tags,
	}
	users := map[tailcfg.UserID]tailcfg.UserProfile{}

	peer := convertPeerStatus(ps, users)
	assert.Equal(t, "k8s-node", peer.Hostname)
	assert.Contains(t, peer.Tags, "tag:k8s")
	assert.Contains(t, peer.Tags, "tag:server")
	assert.Equal(t, "", peer.Owner)
}

func TestConvertPeerStatus_HostnameFromDNS(t *testing.T) {
	// Hostname should always be derived from DNSName, not OS HostName
	ps := &ipnstate.PeerStatus{
		HostName: "GL-MT6000",
		DNSName:  "gl-mt6000-2.example.ts.net.",
	}
	users := map[tailcfg.UserID]tailcfg.UserProfile{}

	peer := convertPeerStatus(ps, users)
	assert.Equal(t, "gl-mt6000-2", peer.Hostname)
}

func TestConvertPeerStatus_FallbackToHostName(t *testing.T) {
	// When DNSName is empty, fall back to OS HostName
	ps := &ipnstate.PeerStatus{
		HostName: "my-device",
	}
	users := map[tailcfg.UserID]tailcfg.UserProfile{}

	peer := convertPeerStatus(ps, users)
	assert.Equal(t, "my-device", peer.Hostname)
}

func TestConvertPeerStatus_LastSeen(t *testing.T) {
	ps := &ipnstate.PeerStatus{
		HostName: "recent-node",
		LastSeen: time.Now().Add(-5 * time.Minute),
	}
	users := map[tailcfg.UserID]tailcfg.UserProfile{}

	peer := convertPeerStatus(ps, users)
	assert.NotEmpty(t, peer.LastSeen)
	assert.Contains(t, peer.LastSeen, "minutes ago")
}

func TestPeerSorting(t *testing.T) {
	b1 := make([]byte, 32)
	b2 := make([]byte, 32)
	b2[0] = 1
	b3 := make([]byte, 32)
	b3[0] = 2

	k1 := key.NodePublicFromRaw32(mem.B(b1))
	k2 := key.NodePublicFromRaw32(mem.B(b2))
	k3 := key.NodePublicFromRaw32(mem.B(b3))

	status := &ipnstate.Status{
		BackendState: "Running",
		Peer: map[key.NodePublic]*ipnstate.PeerStatus{
			k1: {HostName: "zebra", Online: false},
			k2: {HostName: "alpha", Online: true},
			k3: {HostName: "beta", Online: true},
		},
	}

	state := convertStatus(status)

	// Online peers first (alpha, beta), then offline (zebra)
	require.Len(t, state.Peers, 3)
	assert.True(t, state.Peers[0].Online)
	assert.True(t, state.Peers[1].Online)
	assert.False(t, state.Peers[2].Online)
	assert.Equal(t, "alpha", state.Peers[0].Hostname)
	assert.Equal(t, "beta", state.Peers[1].Hostname)
	assert.Equal(t, "zebra", state.Peers[2].Hostname)
}

func TestFormatRelativeTime(t *testing.T) {
	tests := []struct {
		name     string
		duration string
		contains string
	}{
		{"minutes", "5m", "minutes ago"},
		{"hours", "3h", "hours ago"},
		{"days", "48h", "days ago"},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			d, _ := time.ParseDuration(tt.duration)
			result := formatRelativeTime(time.Now().Add(-d))
			assert.Contains(t, result, tt.contains)
		})
	}
}
