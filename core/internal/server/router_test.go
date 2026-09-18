package server

import (
	"context"
	"encoding/json"
	"testing"

	"github.com/AvengeMedia/DankMaterialShell/core/internal/server/apppicker"
	"github.com/AvengeMedia/DankMaterialShell/core/internal/server/clipboard"
	"github.com/AvengeMedia/dankgo/ipc"
	"github.com/stretchr/testify/require"
)

func TestRouteRequestUnavailableManagers(t *testing.T) {
	tests := []struct {
		method string
		err    string
	}{
		{"network.getState", "network manager not initialized"},
		{"theme.auto.getState", "theme mode manager not initialized"},
		{"wallpaper.getState", "wallpaper manager not initialized"},
		{"loginctl.getState", "loginctl manager not initialized"},
		{"freedesktop.getState", "freedesktop manager not initialized"},
		{"wayland.gamma.getState", "wayland manager not initialized"},
		{"bluetooth.getState", "bluetooth manager not initialized"},
		{"browser.open", "apppicker manager not initialized"},
		{"apppicker.open", "apppicker manager not initialized"},
		{"tailscale.getState", "Tailscale not available"},
		{"brightness.getState", "brightness manager not initialized"},
		{"wlroutput.getState", "wlroutput manager not initialized"},
		{"evdev.getState", "evdev manager not initialized"},
		{"dbus.subscribe", "dbus manager not initialized"},
		{"clipboard.getState", "clipboard manager not initialized"},
		{"location.getState", "location manager not initialized"},
		{"notify.invoke", "notification action manager not initialized"},
		{"sysupdate.getState", "sysupdate manager not initialized"},
	}
	for _, tt := range tests {
		t.Run(tt.method, func(t *testing.T) {
			conn := &mockConn{}
			RouteRequest(context.Background(), ipc.NewConnWriter(conn), ipc.Request{ID: 17, Method: tt.method})
			require.JSONEq(t, `{"id":17,"error":"`+tt.err+`"}`, string(conn.written))
		})
	}
}

func TestRouteRequestUnknownMethods(t *testing.T) {
	for _, method := range []string{"", "missing", "network", "networking.getState", "theme.auto", "matugen.missing", "plugins.missing", "themes.missing", "registries.missing", "mime.missing", "dgop.missing", "lyrics.missing"} {
		t.Run(method, func(t *testing.T) {
			conn := &mockConn{}
			RouteRequest(context.Background(), ipc.NewConnWriter(conn), ipc.Request{ID: 18, Method: method})
			require.JSONEq(t, `{"id":18,"error":"unknown method: `+method+`"}`, string(conn.written))
		})
	}
}

func TestRouteRequestExactMethods(t *testing.T) {
	t.Setenv("XDG_CONFIG_HOME", t.TempDir())
	conn := &mockConn{}
	writer := ipc.NewConnWriter(conn)
	RouteRequest(context.Background(), writer, ipc.Request{Method: "ping"})
	require.JSONEq(t, `{"result":"pong"}`, string(conn.written))

	conn.written = nil
	RouteRequest(context.Background(), writer, ipc.Request{ID: 19, Method: "getServerInfo"})
	var info ipc.Response[ServerInfo]
	require.NoError(t, json.Unmarshal(conn.written, &info))
	require.Equal(t, 19, info.ID)
	require.NotNil(t, info.Result)
	require.Equal(t, getServerInfo(), *info.Result)

	conn.written = nil
	RouteRequest(context.Background(), writer, ipc.Request{ID: 20, Method: "clipboard.setConfig", Params: map[string]any{"maxHistory": float64(42)}})
	require.JSONEq(t, `{"id":20,"result":{"success":true,"message":"config updated"}}`, string(conn.written))

	conn.written = nil
	RouteRequest(context.Background(), writer, ipc.Request{ID: 21, Method: "clipboard.getConfig"})
	var config ipc.Response[clipboard.Config]
	require.NoError(t, json.Unmarshal(conn.written, &config))
	require.Equal(t, 21, config.ID)
	require.NotNil(t, config.Result)
	expected := clipboard.DefaultConfig()
	expected.MaxHistory = 42
	require.Equal(t, expected, *config.Result)
}

func TestRouteRequestBrowserAlias(t *testing.T) {
	original := appPickerManager
	appPickerManager = apppicker.NewManager()
	t.Cleanup(func() {
		appPickerManager.Close()
		appPickerManager = original
	})
	events := appPickerManager.Subscribe("route-test")
	for _, method := range []string{"browser.open", "apppicker.open"} {
		t.Run(method, func(t *testing.T) {
			conn := &mockConn{}
			RouteRequest(context.Background(), ipc.NewConnWriter(conn), ipc.Request{ID: 22, Method: method, Params: map[string]any{"url": "https://example.com"}})
			require.JSONEq(t, `{"id":22,"result":"ok"}`, string(conn.written))
			select {
			case event := <-events:
				require.Equal(t, apppicker.OpenEvent{Target: "https://example.com", RequestType: "url"}, event)
			default:
				t.Fatal("missing apppicker event")
			}
		})
	}
	conn := &mockConn{}
	RouteRequest(context.Background(), ipc.NewConnWriter(conn), ipc.Request{ID: 23, Method: "browser.missing"})
	require.JSONEq(t, `{"id":23,"error":"unknown method"}`, string(conn.written))
}

func BenchmarkRouteRequest(b *testing.B) {
	conn := &mockConn{}
	writer := ipc.NewConnWriter(conn)
	req := ipc.Request{ID: 1, Method: "ping"}
	b.ReportAllocs()
	for b.Loop() {
		conn.written = conn.written[:0]
		RouteRequest(context.Background(), writer, req)
	}
}

// Routing only: the no-network invariant itself is TestLookupWithoutConsentNeverFetches.
func TestRouteLyricsGetWithoutConsentStaysLocal(t *testing.T) {
	t.Setenv("XDG_CACHE_HOME", t.TempDir())
	conn := &mockConn{}
	RouteRequest(context.Background(), ipc.NewConnWriter(conn), ipc.Request{ID: 19, Method: "lyrics.get", Params: map[string]any{
		"title":  "Snake Eater",
		"artist": "Cynthia Harrell",
	}})
	require.Contains(t, string(conn.written), `"found":false`)
}
