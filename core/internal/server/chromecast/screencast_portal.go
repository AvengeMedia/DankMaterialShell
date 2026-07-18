package chromecast

import (
	"context"
	"fmt"
	"os"
	"strings"
	"sync/atomic"

	"github.com/AvengeMedia/DankMaterialShell/core/pkg/dbusutil"
	"github.com/godbus/dbus/v5"
)

const (
	portalBus     = "org.freedesktop.portal.Desktop"
	portalObjPath = "/org/freedesktop/portal/desktop"
	scIface       = "org.freedesktop.portal.ScreenCast"
	reqIface      = "org.freedesktop.portal.Request"
)

var portalTokenSeq atomic.Uint64

// PortalSession is an open xdg-desktop-portal ScreenCast session plus the
// PipeWire remote it produced.
type PortalSession struct {
	conn    *dbus.Conn
	session dbus.ObjectPath
	NodeID  uint32
	Fd      *os.File
}

// Close releases the PipeWire fd, closes the portal session, and the bus conn.
func (p *PortalSession) Close() {
	if p == nil {
		return
	}
	if p.Fd != nil {
		p.Fd.Close()
	}
	if p.conn != nil {
		if p.session != "" {
			p.conn.Object(portalBus, p.session).Call("org.freedesktop.portal.Session.Close", 0)
		}
		p.conn.Close()
	}
}

// requestScreencast negotiates a ScreenCast session via xdg-desktop-portal and
// returns the granted PipeWire node id + remote fd. It pops the system
// screen-share dialog. Pure Go (godbus) — no cgo, no CLI.
//
// Overridable in tests.
var requestScreencast = func(ctx context.Context) (*PortalSession, error) {
	conn, err := dbus.ConnectSessionBus()
	if err != nil {
		return nil, fmt.Errorf("session bus: %w", err)
	}
	ps := &PortalSession{conn: conn}

	// SENDER token for request/session object paths: unique name minus the
	// leading ':' with '.' -> '_'.
	sender := strings.ReplaceAll(strings.TrimPrefix(conn.Names()[0], ":"), ".", "_")
	portal := conn.Object(portalBus, portalObjPath)

	// 1) CreateSession
	sessTok := nextToken("ses")
	res, err := portalRequest(ctx, conn, sender, portal, scIface+".CreateSession",
		map[string]dbus.Variant{
			"handle_token":         dbus.MakeVariant(nextToken("req")),
			"session_handle_token": dbus.MakeVariant(sessTok),
		})
	if err != nil {
		conn.Close()
		return nil, fmt.Errorf("CreateSession: %w", err)
	}
	sh, ok := dbusutil.Get[string](res, "session_handle")
	if !ok {
		conn.Close()
		return nil, fmt.Errorf("CreateSession: no session_handle")
	}
	ps.session = dbus.ObjectPath(sh)

	// 2) SelectSources: monitor, single, embedded cursor.
	if _, err := portalRequest(ctx, conn, sender, portal, scIface+".SelectSources",
		ps.session,
		map[string]dbus.Variant{
			"handle_token": dbus.MakeVariant(nextToken("req")),
			"types":        dbus.MakeVariant(uint32(1)), // 1 = MONITOR
			"multiple":     dbus.MakeVariant(false),
			"cursor_mode":  dbus.MakeVariant(uint32(2)), // 2 = EMBEDDED
		}); err != nil {
		ps.Close()
		return nil, fmt.Errorf("SelectSources: %w", err)
	}

	// 3) Start (pops the dialog).
	startRes, err := portalRequest(ctx, conn, sender, portal, scIface+".Start",
		ps.session, "",
		map[string]dbus.Variant{"handle_token": dbus.MakeVariant(nextToken("req"))})
	if err != nil {
		ps.Close()
		return nil, fmt.Errorf("Start: %w", err)
	}
	nodeID, err := firstStreamNode(startRes)
	if err != nil {
		ps.Close()
		return nil, err
	}
	ps.NodeID = nodeID

	// 4) OpenPipeWireRemote — synchronous, returns the fd directly (not a Request).
	var fd dbus.UnixFD
	if err := portal.CallWithContext(ctx, scIface+".OpenPipeWireRemote", 0,
		ps.session, map[string]dbus.Variant{}).Store(&fd); err != nil {
		ps.Close()
		return nil, fmt.Errorf("OpenPipeWireRemote: %w", err)
	}
	ps.Fd = os.NewFile(uintptr(fd), "pipewire-remote")
	return ps, nil
}

func nextToken(prefix string) string {
	return fmt.Sprintf("dms_%s_%d", prefix, portalTokenSeq.Add(1))
}

// portalRequest invokes a portal method whose last argument is the options map
// (carrying handle_token) and which returns a Request object path, then waits
// for that Request's Response signal and returns its results.
func portalRequest(ctx context.Context, conn *dbus.Conn, sender string, portal dbus.BusObject, method string, args ...any) (map[string]dbus.Variant, error) {
	// The handle_token is in the options map (last arg); derive the request path.
	opts, _ := args[len(args)-1].(map[string]dbus.Variant)
	token := opts["handle_token"].Value().(string)
	reqPath := dbus.ObjectPath(fmt.Sprintf("%s/request/%s/%s", portalObjPath, sender, token))

	// Subscribe BEFORE calling to avoid missing a fast response.
	if err := conn.AddMatchSignal(
		dbus.WithMatchObjectPath(reqPath),
		dbus.WithMatchInterface(reqIface),
		dbus.WithMatchMember("Response"),
	); err != nil {
		return nil, err
	}
	defer conn.RemoveMatchSignal(
		dbus.WithMatchObjectPath(reqPath),
		dbus.WithMatchInterface(reqIface),
		dbus.WithMatchMember("Response"),
	)
	sigCh := make(chan *dbus.Signal, 4)
	conn.Signal(sigCh)
	defer conn.RemoveSignal(sigCh)

	var returned dbus.ObjectPath
	if err := portal.CallWithContext(ctx, method, 0, args...).Store(&returned); err != nil {
		return nil, err
	}

	for {
		select {
		case <-ctx.Done():
			return nil, ctx.Err()
		case sig := <-sigCh:
			if sig.Path != reqPath || len(sig.Body) < 2 {
				continue
			}
			code, _ := sig.Body[0].(uint32)
			results, _ := sig.Body[1].(map[string]dbus.Variant)
			if code != 0 {
				return nil, fmt.Errorf("portal request rejected (response=%d)", code)
			}
			return results, nil
		}
	}
}

// firstStreamNode extracts the PipeWire node id from a Start response. The
// "streams" result is a()(ua{sv}): array of (node_id uint32, props).
func firstStreamNode(res map[string]dbus.Variant) (uint32, error) {
	streams, ok := dbusutil.Get[[][]any](res, "streams")
	if !ok || len(streams) == 0 {
		return 0, fmt.Errorf("Start: empty/invalid streams")
	}
	nodeID, ok := streams[0][0].(uint32)
	if !ok {
		return 0, fmt.Errorf("Start: stream node id not a uint32")
	}
	return nodeID, nil
}
