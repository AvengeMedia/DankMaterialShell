package chromecast

import (
	"context"
	"crypto/rand"
	"encoding/hex"
	"fmt"
	"net"
	"net/http"
	"os"
	"os/exec"
	"path/filepath"
	"sync"
	"time"

	"github.com/AvengeMedia/DankMaterialShell/core/internal/log"
)

// hlsPlaylist is the HLS playlist filename served to the Cast device.
const hlsPlaylist = "stream.m3u8"

// hlsContentType is the MIME type for an HLS playlist.
const hlsContentType = "application/x-mpegURL"

// helperPath resolves the dms-cast-helper binary (the go-gst capture program).
// Order: DMS_CAST_HELPER env, then next to the dms executable, then PATH.
func helperPath() string {
	if p := os.Getenv("DMS_CAST_HELPER"); p != "" {
		return p
	}
	if exe, err := os.Executable(); err == nil {
		cand := filepath.Join(filepath.Dir(exe), "dms-cast-helper")
		if _, err := os.Stat(cand); err == nil {
			return cand
		}
	}
	return "dms-cast-helper"
}

// buildHelperCmd builds the go-gst capture helper invocation for HLS output.
// A package var so tests can stub it.
var buildHelperCmd = func(outDir string, nodeID uint32) *exec.Cmd {
	return exec.Command(helperPath(),
		"-mode", "hls",
		"-out", outDir,
		"-node", fmt.Sprintf("%d", nodeID),
	)
}

// outboundIPFunc resolves the local interface address that targetHost would
// connect back to. Overridable in tests.
var outboundIPFunc = outboundIP

func outboundIP(targetHost string) (string, error) {
	// A UDP "connection" sends no packets; it just selects the route/interface
	// the kernel would use to reach targetHost, exposing the local address the
	// Cast device can reach us on.
	conn, err := net.Dial("udp", net.JoinHostPort(targetHost, "8009"))
	if err != nil {
		return "", err
	}
	defer conn.Close()
	return conn.LocalAddr().(*net.UDPAddr).IP.String(), nil
}

// screenStreamer captures the screen to HLS and serves it over HTTP for a Cast
// device to pull. This is the buffered-player "laggy mirror" path: the Cast
// media receiver pre-buffers segments, so expect multi-second latency. It is
// not real-time mirroring (that needs Google's closed protocol).
// portalTimeout bounds how long we wait for the user to approve the screen-share
// dialog before giving up.
const portalTimeout = 90 * time.Second

type screenStreamer struct {
	mu      sync.Mutex
	dir     string
	cmd     *exec.Cmd
	server  *http.Server
	portal  *PortalSession
	running bool
}

// noListFS wraps an http.FileSystem to disable directory listings, so the HLS
// segment filenames can't be enumerated by an unauthenticated client.
type noListFS struct{ fs http.FileSystem }

func (n noListFS) Open(name string) (http.File, error) {
	f, err := n.fs.Open(name)
	if err != nil {
		return nil, err
	}
	return noListFile{f}, nil
}

type noListFile struct{ http.File }

func (noListFile) Readdir(int) ([]os.FileInfo, error) { return nil, nil }

// randToken returns an unguessable URL path segment for the HLS server, so a
// LAN host can't reach the screen capture just by scanning the port.
func randToken() (string, error) {
	b := make([]byte, 16)
	if _, err := rand.Read(b); err != nil {
		return "", err
	}
	return hex.EncodeToString(b), nil
}

// start negotiates the screen-share portal, runs the go-gst capture helper to
// produce HLS, serves it over HTTP, and returns the playlist URL reachable from
// reachableIP. The HTTP server is bound to reachableIP only, serves under an
// unguessable path token with directory listing off, and onExit fires if the
// capture helper exits on its own. The portal step pops the screen-share dialog.
func (s *screenStreamer) start(reachableIP string, onExit func()) (string, error) {
	s.mu.Lock()
	defer s.mu.Unlock()
	if s.running {
		return "", fmt.Errorf("screencast already running")
	}

	token, err := randToken()
	if err != nil {
		return "", err
	}

	ctx, cancel := context.WithTimeout(context.Background(), portalTimeout)
	defer cancel()
	portal, err := requestScreencast(ctx)
	if err != nil {
		return "", fmt.Errorf("screencast portal: %w", err)
	}

	dir, err := os.MkdirTemp("", "dms-cast-screen-")
	if err != nil {
		portal.Close()
		return "", err
	}

	// Bind to the single LAN-facing interface the cast device reaches us on,
	// not 0.0.0.0, so the capture isn't offered on every interface.
	listener, err := net.Listen("tcp", net.JoinHostPort(reachableIP, "0"))
	if err != nil {
		os.RemoveAll(dir)
		portal.Close()
		return "", err
	}
	port := listener.Addr().(*net.TCPAddr).Port

	// Serve under a random path token (so a port scan can't guess the URL) with
	// directory listing disabled. Still unauthenticated, but unguessable.
	prefix := "/" + token + "/"
	mux := http.NewServeMux()
	mux.Handle(prefix, http.StripPrefix(prefix, http.FileServer(noListFS{http.Dir(dir)})))
	srv := &http.Server{Handler: mux}
	go func() {
		if err := srv.Serve(listener); err != nil && err != http.ErrServerClosed {
			log.Warnf("[Cast] HLS server error: %v", err)
		}
	}()

	cmd := buildHelperCmd(dir, portal.NodeID)
	cmd.ExtraFiles = []*os.File{portal.Fd} // PipeWire remote fd -> child fd 3
	cmd.Stderr = os.Stderr
	if err := cmd.Start(); err != nil {
		srv.Close()
		os.RemoveAll(dir)
		portal.Close()
		return "", fmt.Errorf("start capture helper: %w", err)
	}

	s.dir = dir
	s.cmd = cmd
	s.server = srv
	s.portal = portal
	s.running = true

	// Supervise the helper: if it exits on its own (crash, portal revoked),
	// tear down and notify so the manager clears screencasting instead of being
	// stuck on a dead/zombie helper. Mirrors airplayMirror's exit watcher.
	go func() {
		_ = cmd.Wait()
		s.mu.Lock()
		unexpected := s.running && s.cmd == cmd
		if unexpected {
			s.teardownLocked() // process already reaped by Wait above
		}
		s.mu.Unlock()
		if unexpected && onExit != nil {
			onExit()
		}
	}()

	url := fmt.Sprintf("http://%s:%d%s%s", reachableIP, port, prefix, hlsPlaylist)
	log.Infof("[Cast] Screencast HLS at %s (dir %s)", url, dir)
	return url, nil
}

// stop kills the capture helper and tears down the HTTP server, temp directory,
// and portal.
func (s *screenStreamer) stop() {
	s.mu.Lock()
	defer s.mu.Unlock()
	if !s.running {
		return
	}
	// Only Kill here; the supervisor goroutine started in start() is the sole
	// caller of cmd.Wait() and will reap the process (calling Wait from two
	// goroutines races). It sees running=false below and skips its own teardown.
	if s.cmd != nil && s.cmd.Process != nil {
		_ = s.cmd.Process.Kill()
	}
	s.teardownLocked()
}

// teardownLocked releases the HTTP server, temp directory, and portal and
// resets state. The caller holds s.mu and must already have reaped the helper.
func (s *screenStreamer) teardownLocked() {
	if s.server != nil {
		_ = s.server.Close()
	}
	if s.portal != nil {
		s.portal.Close()
	}
	if s.dir != "" {
		_ = os.RemoveAll(s.dir)
	}
	s.cmd = nil
	s.server = nil
	s.portal = nil
	s.dir = ""
	s.running = false
	log.Info("[Cast] Screencast stopped")
}

func (s *screenStreamer) isRunning() bool {
	s.mu.Lock()
	defer s.mu.Unlock()
	return s.running
}
