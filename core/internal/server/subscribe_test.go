package server

import (
	"context"
	"encoding/json"
	"fmt"
	"net"
	"testing"
	"testing/synctest"

	"github.com/AvengeMedia/DankMaterialShell/core/internal/server/apppicker"
	"github.com/AvengeMedia/DankMaterialShell/core/internal/server/wlroutput"
	"github.com/AvengeMedia/dankgo/ipc"
	"github.com/stretchr/testify/require"
)

func TestSubscribeStreams(t *testing.T) {
	for _, snapshot := range []bool{false, true} {
		t.Run(fmt.Sprintf("snapshot=%t", snapshot), func(t *testing.T) {
			synctest.Test(t, func(t *testing.T) {
				originalPicker, originalOutput := appPickerManager, wlrOutputManager
				appPickerManager = apppicker.NewManager()
				wlrOutputManager = &wlroutput.Manager{}
				defer func() {
					appPickerManager.Close()
					appPickerManager, wlrOutputManager = originalPicker, originalOutput
				}()

				services := []any{"browser", 123, "unavailable"}
				if snapshot {
					services = append(services, "wlroutput")
				}
				serverConn, clientConn := net.Pipe()
				defer serverConn.Close()
				defer clientConn.Close()
				writer := ipc.NewConnWriter(serverConn)
				done := make(chan struct{})
				go func() {
					defer close(done)
					handleSubscribe(context.Background(), writer, ipc.Request{ID: 24, Params: map[string]any{"services": services}})
				}()

				decoder := json.NewDecoder(clientConn)
				readEvent := func(service string, expected any) {
					t.Helper()
					var response ipc.Response[struct {
						Service string          `json:"service"`
						Data    json.RawMessage `json:"data"`
					}]
					require.NoError(t, decoder.Decode(&response))
					require.Equal(t, 24, response.ID)
					require.Empty(t, response.Error)
					require.NotNil(t, response.Result)
					require.Equal(t, service, response.Result.Service)
					data, err := json.Marshal(expected)
					require.NoError(t, err)
					require.JSONEq(t, string(data), string(response.Result.Data))
				}

				readEvent("server", getServerInfo())
				if snapshot {
					readEvent("wlroutput", wlrOutputManager.GetState())
				}
				event := apppicker.OpenEvent{Target: "https://example.com", RequestType: "url"}
				appPickerManager.RequestOpen(event)
				readEvent("browser.open_requested", event)

				notifyCapabilityChange()
				readEvent("server", getServerInfo())
				require.NoError(t, clientConn.Close())
				appPickerManager.RequestOpen(event)
				<-done
				synctest.Wait()
				_, subscribed := capabilitySubscribers.Load(fmt.Sprintf("meta-client-%p-capabilities", writer))
				require.False(t, subscribed)
			})
		})
	}
}

func TestSubscribeInitialWriteFailure(t *testing.T) {
	synctest.Test(t, func(t *testing.T) {
		serverConn, clientConn := net.Pipe()
		defer serverConn.Close()
		require.NoError(t, clientConn.Close())
		writer := ipc.NewConnWriter(serverConn)
		handleSubscribe(context.Background(), writer, ipc.Request{Params: map[string]any{"services": []any{"unavailable"}}})
		synctest.Wait()
		_, subscribed := capabilitySubscribers.Load(fmt.Sprintf("meta-client-%p-capabilities", writer))
		require.False(t, subscribed)
	})
}
