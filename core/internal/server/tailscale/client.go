package tailscale

import (
	"fmt"
	"sort"
	"strings"
	"time"

	"tailscale.com/ipn/ipnstate"
	"tailscale.com/tailcfg"
)

// convertStatus converts an ipnstate.Status into our TailscaleState IPC type.
func convertStatus(status *ipnstate.Status) *TailscaleState {
	connected := status.BackendState == "Running"

	state := &TailscaleState{
		Connected:    connected,
		BackendState: status.BackendState,
		Version:      status.Version,
	}

	if status.CurrentTailnet != nil {
		state.TailnetName = status.CurrentTailnet.Name
		state.MagicDNSSuffix = status.CurrentTailnet.MagicDNSSuffix
	}

	if !connected {
		return state
	}

	users := status.User

	if status.Self != nil {
		state.Self = convertPeerStatus(status.Self, users)
	}

	if len(status.Peer) > 0 {
		peers := make([]Peer, 0, len(status.Peer))
		for _, ps := range status.Peer {
			peers = append(peers, convertPeerStatus(ps, users))
		}
		sort.Slice(peers, func(i, j int) bool {
			if peers[i].Online != peers[j].Online {
				return peers[i].Online
			}
			return strings.ToLower(peers[i].Hostname) < strings.ToLower(peers[j].Hostname)
		})
		state.Peers = peers
	}

	return state
}

// convertPeerStatus converts an ipnstate.PeerStatus into our Peer IPC type.
func convertPeerStatus(ps *ipnstate.PeerStatus, users map[tailcfg.UserID]tailcfg.UserProfile) Peer {
	dnsName := strings.TrimSuffix(ps.DNSName, ".")

	// DNSName first label is unique per node; OS HostName is not.
	hostname := ps.HostName
	if dnsName != "" {
		parts := strings.SplitN(dnsName, ".", 2)
		if len(parts) > 0 && parts[0] != "" {
			hostname = parts[0]
		}
	}

	peer := Peer{
		ID:       string(ps.ID),
		Hostname: hostname,
		DNSName:  dnsName,
		OS:       ps.OS,
		Online:   ps.Online,
		Active:   ps.Active,
		ExitNode: ps.ExitNode,
		Relay:    ps.Relay,
		RxBytes:  ps.RxBytes,
		TxBytes:  ps.TxBytes,
	}

	for _, ip := range ps.TailscaleIPs {
		if ip.Is4() {
			if peer.TailscaleIP == "" {
				peer.TailscaleIP = ip.String()
			}
		} else {
			if peer.TailscaleIPv6 == "" {
				peer.TailscaleIPv6 = ip.String()
			}
		}
	}

	if ps.Tags != nil {
		peer.Tags = ps.Tags.AsSlice()
	}

	if ps.UserID > 0 {
		if user, ok := users[ps.UserID]; ok {
			peer.Owner = user.LoginName
		}
	}

	if !ps.LastSeen.IsZero() {
		peer.LastSeen = formatRelativeTime(ps.LastSeen)
	}

	return peer
}

// formatRelativeTime formats a time as a human-readable relative duration (e.g., "5 minutes ago").
func formatRelativeTime(t time.Time) string {
	d := time.Since(t)
	switch {
	case d < time.Minute:
		return "just now"
	case d < time.Hour:
		m := int(d.Minutes())
		if m == 1 {
			return "1 minute ago"
		}
		return fmt.Sprintf("%d minutes ago", m)
	case d < 24*time.Hour:
		h := int(d.Hours())
		if h == 1 {
			return "1 hour ago"
		}
		return fmt.Sprintf("%d hours ago", h)
	default:
		days := int(d.Hours() / 24)
		if days == 1 {
			return "1 day ago"
		}
		return fmt.Sprintf("%d days ago", days)
	}
}
