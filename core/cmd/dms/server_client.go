package main

import (
	"bufio"
	"encoding/json"
	"fmt"
	"net"
	"os"
	"path/filepath"
	"time"

	"github.com/AvengeMedia/DankMaterialShell/core/internal/server"
	"github.com/AvengeMedia/DankMaterialShell/core/internal/utils"
	"github.com/AvengeMedia/dankgo/ipc"
)

// maxIPCMessageSize allows room for a 50 MB clipboard entry plus JSON/base64
// overhead in the line-delimited IPC response.
const maxIPCMessageSize = 96 * 1024 * 1024

// serverHandshakeTimeout bounds connecting, the greeting and sending the
// request, so a stuck server can't hang the CLI. Replies get no limit because
// some requests (matugen queue --wait) legitimately take long.
var serverHandshakeTimeout = 2 * time.Second

func dialServer() (net.Conn, *bufio.Scanner, error) {
	conn, err := net.DialTimeout("unix", getServerSocketPath(), serverHandshakeTimeout)
	if err != nil {
		return nil, nil, fmt.Errorf("failed to connect to server (is it running?): %w", err)
	}
	_ = conn.SetDeadline(time.Now().Add(serverHandshakeTimeout))

	scanner := bufio.NewScanner(conn)
	scanner.Buffer(make([]byte, bufio.MaxScanTokenSize), maxIPCMessageSize)
	if !scanner.Scan() { // initial capabilities message
		conn.Close()
		return nil, nil, fmt.Errorf("server did not respond: %w", scanner.Err())
	}
	return conn, scanner, nil
}

func sendServerRequest(req ipc.Request) (*ipc.Response[any], error) {
	conn, scanner, err := dialServer()
	if err != nil {
		return nil, err
	}
	defer conn.Close()

	reqData, err := json.Marshal(req)
	if err != nil {
		return nil, fmt.Errorf("failed to marshal request: %w", err)
	}

	if _, err := conn.Write(reqData); err != nil {
		return nil, fmt.Errorf("failed to write request: %w", err)
	}

	if _, err := conn.Write([]byte("\n")); err != nil {
		return nil, fmt.Errorf("failed to write newline: %w", err)
	}

	_ = conn.SetDeadline(time.Time{})
	if !scanner.Scan() {
		return nil, fmt.Errorf("failed to read response")
	}

	var resp ipc.Response[any]
	if err := json.Unmarshal(scanner.Bytes(), &resp); err != nil {
		return nil, fmt.Errorf("failed to unmarshal response: %w", err)
	}

	return &resp, nil
}

// sendServerRequestFireAndForget sends a request without waiting for a response.
// Useful for commands that trigger UI or async operations.
func sendServerRequestFireAndForget(req ipc.Request) error {
	conn, _, err := dialServer()
	if err != nil {
		return err
	}
	defer conn.Close()

	reqData, err := json.Marshal(req)
	if err != nil {
		return fmt.Errorf("failed to marshal request: %w", err)
	}

	if _, err := conn.Write(reqData); err != nil {
		return fmt.Errorf("failed to write request: %w", err)
	}

	if _, err := conn.Write([]byte("\n")); err != nil {
		return fmt.Errorf("failed to write newline: %w", err)
	}

	return nil
}

// tryServerRequest attempts to send a request but returns false if server unavailable.
// Does not log errors - caller can decide what to do on failure.
func tryServerRequest(req ipc.Request) (*ipc.Response[any], bool) {
	resp, err := sendServerRequest(req)
	if err != nil {
		return nil, false
	}
	return resp, true
}

func getServerSocketPath() string {
	runtimeDir := utils.RuntimeDir()

	if sessionSock, ok := shellApp.SessionSocketPath(); ok {
		return sessionSock
	}

	entries, err := os.ReadDir(runtimeDir)
	if err != nil {
		return filepath.Join(runtimeDir, "danklinux.sock")
	}

	for _, entry := range entries {
		name := entry.Name()
		if name == "danklinux.sock" {
			return filepath.Join(runtimeDir, name)
		}
		if len(name) > 10 && name[:10] == "danklinux-" && filepath.Ext(name) == ".sock" {
			return filepath.Join(runtimeDir, name)
		}
	}

	return server.GetSocketPath()
}
