package main

import (
	"bufio"
	"encoding/json"
	"fmt"
	"net"
	"os"
	"path/filepath"

	"github.com/AvengeMedia/DankMaterialShell/core/internal/server"
	"github.com/AvengeMedia/DankMaterialShell/core/internal/utils"
	"github.com/AvengeMedia/dankgo/ipc"
)

// maxIPCMessageSize allows room for a 50 MB clipboard entry plus JSON/base64
// overhead in the line-delimited IPC response.
const maxIPCMessageSize = 96 * 1024 * 1024

func sendServerRequest(req ipc.Request) (*ipc.Response[any], error) {
	socketPath := getServerSocketPath()

	conn, err := net.Dial("unix", socketPath)
	if err != nil {
		return nil, fmt.Errorf("failed to connect to server (is it running?): %w", err)
	}
	defer conn.Close()

	scanner := bufio.NewScanner(conn)
	scanner.Buffer(make([]byte, bufio.MaxScanTokenSize), maxIPCMessageSize)
	scanner.Scan() // discard initial capabilities message

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
	socketPath := getServerSocketPath()

	conn, err := net.Dial("unix", socketPath)
	if err != nil {
		return fmt.Errorf("failed to connect to server (is it running?): %w", err)
	}
	defer conn.Close()

	scanner := bufio.NewScanner(conn)
	scanner.Buffer(make([]byte, bufio.MaxScanTokenSize), maxIPCMessageSize)
	scanner.Scan() // discard initial capabilities message

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
