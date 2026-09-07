//go:build linux

package internal

import (
	"bufio"
	"bytes"
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"net"
	"os"
	"path/filepath"
	"regexp"
	"syscall"
	"time"
	"unicode/utf8"

	"golang.org/x/sys/unix"
)

const aqueousMaxFrameBytes = 4*1024*1024 + 65536
const aqueousMaxBatchBytes = 4 * 1024 * 1024

var aqueousSessionPattern = regexp.MustCompile(`^[0-9a-f]{32}$`)
var aqueousSequencePattern = regexp.MustCompile(`^[0-9]{1,20}$`)

type aqueousHello struct {
	Session      string           `json:"session"`
	Schema       int              `json:"schema"`
	MaxRequest   int              `json:"max_request_bytes"`
	MaxFrame     int              `json:"max_frame_bytes"`
	MaxBatch     int              `json:"max_batch_bytes"`
	MaxPending   int              `json:"max_pending_requests"`
	Capabilities map[string]*bool `json:"capabilities"`
}

func validateAqueousSocketPath(path string) error {
	runtime := os.Getenv("XDG_RUNTIME_DIR")
	if !filepath.IsAbs(runtime) || !filepath.IsAbs(path) || filepath.Clean(path) != path || filepath.Dir(filepath.Dir(filepath.Dir(path))) != runtime || filepath.Base(filepath.Dir(filepath.Dir(path))) != "aqueous" || filepath.Base(path) != "ipc.sock" {
		return errors.New("unavailable: invalid AQUEOUS_SOCKET or XDG_RUNTIME_DIR")
	}
	for _, dir := range []string{runtime, filepath.Dir(filepath.Dir(path)), filepath.Dir(path)} {
		if err := validateAqueousDirectory(dir); err != nil {
			return err
		}
	}
	info, err := os.Lstat(path)
	if err != nil {
		return err
	}
	if info.Mode()&os.ModeSocket == 0 || info.Mode().Perm() != 0600 {
		return errors.New("unavailable: socket must have mode 0600")
	}
	return nil
}

func readAqueousFrame(reader *bufio.Reader, limit int) ([]byte, error) {
	var frame []byte
	for {
		part, err := reader.ReadSlice('\n')
		count := len(part)
		if count > 0 && part[count-1] == '\n' {
			count--
		}
		if len(frame)+count > limit {
			return nil, errors.New("IPC frame exceeds size bound")
		}
		frame = append(frame, part[:count]...)
		if err == bufio.ErrBufferFull {
			continue
		}
		if err != nil {
			return nil, fmt.Errorf("truncated IPC frame: %w", err)
		}
		if !utf8.Valid(frame) || !json.Valid(frame) {
			return nil, errors.New("invalid IPC JSON/UTF-8")
		}
		depth, quoted, escaped := 0, false, false
		for _, c := range frame {
			if quoted {
				if escaped {
					escaped = false
				} else if c == '\\' {
					escaped = true
				} else if c == '"' {
					quoted = false
				}
				continue
			}
			if c == '"' {
				quoted = true
			}
			if c == '{' || c == '[' {
				depth++
				if depth > 32 {
					return nil, errors.New("IPC nesting exceeds limit")
				}
			}
			if c == '}' || c == ']' {
				depth--
			}
		}
		return frame, nil
	}
}

func exchangeAqueousRequest(conn net.Conn, reader *bufio.Reader, id, op, session string, maxRequest, limit int) (json.RawMessage, error) {
	request := map[string]any{"ipc": 1, "id": id, "op": op, "params": map[string]any{}}
	if session != "" {
		request["session"] = session
	}
	data, err := json.Marshal(request)
	if err != nil {
		return nil, err
	}
	if len(data) > maxRequest {
		return nil, errors.New("IPC request exceeds advertised size bound")
	}
	if _, err = io.Copy(conn, bytes.NewReader(append(data, '\n'))); err != nil {
		return nil, err
	}
	frame, err := readAqueousFrame(reader, limit)
	if err != nil {
		return nil, err
	}
	var response struct {
		IPC    int             `json:"ipc"`
		ID     string          `json:"id"`
		OK     *bool           `json:"ok"`
		Event  json.RawMessage `json:"event"`
		Result json.RawMessage `json:"result"`
		Error  *struct {
			Code    string  `json:"code"`
			Message *string `json:"message"`
		} `json:"error"`
	}
	if err := json.Unmarshal(frame, &response); err != nil {
		return nil, err
	}
	if response.IPC != 1 || response.ID != id || response.OK == nil || response.Event != nil {
		return nil, errors.New("invalid IPC response envelope")
	}
	if !*response.OK {
		if response.Error == nil || response.Error.Code == "" || len(response.Error.Code) > 128 || (response.Error.Message == nil || len(*response.Error.Message) > 4096) || response.Result != nil {
			return nil, errors.New("malformed IPC error")
		}
		return nil, fmt.Errorf("%s: %s", response.Error.Code, *response.Error.Message)
	}
	if response.Error != nil || len(response.Result) == 0 || response.Result[0] != '{' {
		return nil, errors.New("missing IPC result")
	}
	return response.Result, nil
}

// AqueousSnapshot uses only the inherited endpoint; no discovery or helper subprocesses.
func AqueousSnapshot(ctx context.Context) (json.RawMessage, error) {
	path := os.Getenv("AQUEOUS_SOCKET")
	if err := validateAqueousSocketPath(path); err != nil {
		return nil, err
	}
	ctx, cancel := context.WithTimeout(ctx, 5*time.Second)
	defer cancel()
	conn, err := (&net.Dialer{}).DialContext(ctx, "unix", path)
	if err != nil {
		return nil, err
	}
	defer conn.Close()
	stop := context.AfterFunc(ctx, func() { conn.Close() })
	defer stop()
	deadline, _ := ctx.Deadline()
	if err := conn.SetDeadline(deadline); err != nil {
		return nil, err
	}
	if err := verifyAqueousPeer(conn.(*net.UnixConn)); err != nil {
		return nil, err
	}
	reader := bufio.NewReaderSize(conn, 16384)
	raw, err := exchangeAqueousRequest(conn, reader, "1", "hello", "", 65536, aqueousMaxFrameBytes)
	if err != nil {
		return nil, err
	}
	var h aqueousHello
	if err := json.Unmarshal(raw, &h); err != nil {
		return nil, err
	}
	if !aqueousSessionPattern.MatchString(h.Session) || h.Schema != 1 || h.MaxRequest <= 0 || h.MaxRequest > 65536 || h.MaxFrame <= 0 || h.MaxFrame > aqueousMaxFrameBytes || h.MaxBatch <= 0 || h.MaxBatch > aqueousMaxBatchBytes || h.MaxPending != 1 {
		return nil, errors.New("unsupported: IPC hello")
	}
	for _, name := range []string{"state", "commands", "keyboard", "overview", "shortcut_inhibition"} {
		if h.Capabilities[name] == nil {
			return nil, errors.New("unsupported: missing IPC capability")
		}
	}
	if !*h.Capabilities["state"] {
		return nil, errors.New("unsupported: state query")
	}
	raw, err = exchangeAqueousRequest(conn, reader, "2", "snapshot", h.Session, h.MaxRequest, h.MaxFrame)
	if err != nil {
		return nil, err
	}
	var result struct {
		Batch json.RawMessage `json:"batch"`
	}
	if err := json.Unmarshal(raw, &result); err != nil {
		return nil, err
	}
	var batch struct {
		Session  string `json:"session"`
		Schema   int    `json:"schema"`
		Sequence string `json:"sequence"`
		Type     string `json:"type"`
	}
	if len(result.Batch) > h.MaxBatch {
		return nil, errors.New("snapshot exceeds size bound")
	}
	if err := json.Unmarshal(result.Batch, &batch); err != nil {
		return nil, err
	}
	if batch.Session != h.Session || batch.Schema != 1 || batch.Type != "snapshot" || !aqueousSequencePattern.MatchString(batch.Sequence) {
		return nil, errors.New("invalid snapshot identity/schema")
	}
	return result.Batch, nil
}

func validateAqueousDirectory(path string) error {
	info, err := os.Lstat(path)
	if err != nil {
		return err
	}
	stat, ok := info.Sys().(*syscall.Stat_t)
	if !ok || !info.IsDir() || info.Mode().Perm() != 0700 || stat.Uid != uint32(os.Getuid()) {
		return errors.New("unavailable: runtime directory must be private and owned by this user")
	}
	return nil
}

func verifyAqueousPeer(conn *net.UnixConn) error {
	raw, err := conn.SyscallConn()
	if err != nil {
		return err
	}
	var peerErr error
	err = raw.Control(func(fd uintptr) {
		cred, err := unix.GetsockoptUcred(int(fd), unix.SOL_SOCKET, unix.SO_PEERCRED)
		if err != nil {
			peerErr = err
			return
		}
		if cred.Uid != uint32(os.Getuid()) {
			peerErr = errors.New("IPC peer UID mismatch")
		}
	})
	if err != nil {
		return err
	}
	return peerErr
}
