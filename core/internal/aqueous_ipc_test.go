//go:build linux

package internal

import (
	"bufio"
	"bytes"
	"context"
	"encoding/json"
	"net"
	"os"
	"path/filepath"
	"strings"
	"testing"
	"time"
)

func TestAqueousIPCReadFrame(t *testing.T) {
	for _, tc := range []struct {
		name, input string
		limit       int
		valid       bool
	}{
		{"unicode", "{\"title\":\"🫧 日本語\"}\n", 64, true},
		{"truncated", "{}", 64, false},
		{"invalid utf8", "{\"title\":\"\xff\"}\n", 64, false},
		{"oversize without newline", strings.Repeat("x", 17000), 16000, false},
		{"exact limit", "{}\n", 2, true},
		{"oversize", "{} \n", 2, false},
		{"deep", strings.Repeat("[", 33) + strings.Repeat("]", 33) + "\n", 100, false},
	} {
		t.Run(tc.name, func(t *testing.T) {
			_, err := readAqueousFrame(bufio.NewReaderSize(strings.NewReader(tc.input), 16), tc.limit)
			if (err == nil) != tc.valid {
				t.Fatalf("unexpected error: %v", err)
			}
		})
	}
	reader := bufio.NewReader(strings.NewReader("{}\n{\"next\":true}\n"))
	for _, expected := range []string{"{}", `{"next":true}`} {
		got, err := readAqueousFrame(reader, 64)
		if err != nil || string(got) != expected {
			t.Fatalf("got %q, %v", got, err)
		}
	}
}

func fakeAqueousIPCServer(t *testing.T, serve func(net.Conn)) {
	t.Helper()
	runtime, err := os.MkdirTemp("/tmp", "aq-ipc-")
	if err != nil {
		t.Fatal(err)
	}
	t.Cleanup(func() { os.RemoveAll(runtime) })
	path := filepath.Join(runtime, "aqueous", "test", "ipc.sock")
	if err := os.MkdirAll(filepath.Dir(path), 0700); err != nil {
		t.Fatal(err)
	}
	listener, err := net.Listen("unix", path)
	if err != nil {
		t.Fatal(err)
	}
	if err := os.Chmod(path, 0600); err != nil {
		t.Fatal(err)
	}
	t.Setenv("XDG_RUNTIME_DIR", runtime)
	t.Setenv("AQUEOUS_SOCKET", path)
	done := make(chan struct{})
	go func() {
		defer close(done)
		conn, err := listener.Accept()
		if err != nil {
			return
		}
		defer conn.Close()
		conn.SetDeadline(time.Now().Add(3 * time.Second))
		serve(conn)
	}()
	t.Cleanup(func() { listener.Close(); <-done })
}

func TestAqueousIPCSnapshot(t *testing.T) {
	fixture, err := os.ReadFile("../../quickshell/tests/fixtures/aqueous/hello.json")
	if err != nil {
		t.Fatal(err)
	}
	snapshot, err := os.ReadFile("screenshot/testdata/aqueous-snapshot.json")
	if err != nil {
		t.Fatal(err)
	}
	var batch map[string]any
	if err := json.Unmarshal(snapshot, &batch); err != nil {
		t.Fatal(err)
	}
	// Both clients consume the same wire hello fixture.
	var h map[string]any
	json.Unmarshal(fixture, &h)
	batch["session"] = h["result"].(map[string]any)["session"]
	batch["sequence"] = "9007199254740993123"
	for _, mode := range []string{"valid", "bad hello", "bad id", "malformed error", "stale session", "truncated", "oversize", "cancel"} {
		t.Run(mode, func(t *testing.T) {
			fakeAqueousIPCServer(t, func(conn net.Conn) {
				reader := bufio.NewReader(conn)
				first, err := readAqueousFrame(reader, 65536)
				if err != nil {
					return
				}
				if !bytes.Contains(first, []byte(`"op":"hello"`)) {
					t.Error("missing hello")
					return
				}
				if mode == "cancel" {
					reader.ReadByte()
					return
				}
				var compact bytes.Buffer
				json.Compact(&compact, fixture)
				helloReply := append(compact.Bytes(), '\n')
				if mode == "bad hello" {
					helloReply = bytes.Replace(helloReply, []byte(`"schema":1`), []byte(`"schema":2`), 1)
				}
				conn.Write(helloReply)
				if mode == "bad hello" {
					return
				}
				req, err := readAqueousFrame(reader, 65536)
				if err != nil {
					return
				}
				var request map[string]any
				json.Unmarshal(req, &request)
				if request["session"] != batch["session"] || request["op"] != "snapshot" || request["id"] != "2" {
					t.Error("invalid snapshot request")
					return
				}
				reply := map[string]any{"ipc": 1, "id": "2", "ok": true, "result": map[string]any{"batch": batch}}
				switch mode {
				case "bad id":
					reply["id"] = "3"
				case "malformed error":
					reply = map[string]any{"ipc": 1, "id": "2", "ok": false, "error": map[string]any{"code": 7}}
				case "stale session":
					reply = map[string]any{"ipc": 1, "id": "2", "ok": false, "error": map[string]any{"code": "stale_session", "message": "session changed"}}
				case "truncated":
					conn.Write([]byte(`{"ipc":`))
					return
				case "oversize":
					conn.Write(bytes.Repeat([]byte("x"), aqueousMaxFrameBytes+1))
					return
				}
				data, _ := json.Marshal(reply)
				data = append(data, '\n')
				for len(data) > 0 {
					n := min(7, len(data))
					if _, err := conn.Write(data[:n]); err != nil {
						return
					}
					data = data[n:]
				}
			})
			ctx, cancel := context.WithTimeout(context.Background(), time.Second)
			defer cancel()
			if mode == "cancel" {
				go func() { time.Sleep(20 * time.Millisecond); cancel() }()
			}
			result, err := AqueousSnapshot(ctx)
			if mode != "valid" {
				if err == nil {
					t.Fatal("invalid server accepted")
				}
				return
			}
			if err != nil {
				t.Fatal(err)
			}
			if !bytes.Contains(result, []byte("9007199254740993123")) {
				t.Fatal("sequence lost precision")
			}
		})
	}
}

func TestAqueousIPCMissingSocket(t *testing.T) {
	t.Setenv("AQUEOUS_SOCKET", "")
	if _, err := AqueousSnapshot(context.Background()); err == nil {
		t.Fatal("missing socket accepted")
	}
}
