// gaze-observe subscribes to the Gaze daemon's scrubbed auth-phase broadcast
// (com.gundulabs.Gaze.AuthPhase) and prints one key=value record per change
// to stdout. It is the read-only status channel for the shell's auth HUD:
// the daemon fan-out is uid-checked on registration, and the payload contains
// phase and camera status codes plus the surface class — never face names or
// match scores.
//
// Protocol (stdout, one record per line, fields space-separated):
//
//	ready=1                                   after successful registration
//	phase=waiting rgb=no-face ir=unused surface=elevation
//	phase=matched rgb=ready ir=unused surface=elevation
//	phase=not-recognized rgb=no-face ir=unused surface=elevation
//
// phase values: waiting | matched | not-recognized | unavailable | idle
// rgb/ir values: unused | no-face | too-dark | clipped | not-centered |
//
//	too-far | too-close | ready | usable
//
// surface values: screen_lock | elevation | login | direct
//
// The helper exits non-zero when the daemon or its observer API is
// unavailable; consumers fall back to their in-process PAM feedback.
package main

import (
	"bufio"
	"fmt"
	"os"
	"os/signal"
	"syscall"

	"github.com/godbus/dbus/v5"
)

const (
	gazeService = "com.gundulabs.Gaze"
	gazePath    = "/com/gundulabs/Gaze"
	gazeIface   = "com.gundulabs.Gaze"
)

func phaseName(code byte) string {
	switch code {
	case 0:
		return "waiting"
	case 1:
		return "matched"
	case 2:
		return "not-recognized"
	case 3:
		return "unavailable"
	default:
		return "idle"
	}
}

func statusName(code byte) string {
	switch code {
	case 0:
		return "unused"
	case 1:
		return "no-face"
	case 2:
		return "too-dark"
	case 3:
		return "clipped"
	case 4:
		return "not-centered"
	case 5:
		return "too-far"
	case 6:
		return "too-close"
	case 7:
		return "ready"
	case 8:
		return "usable"
	default:
		return "unknown"
	}
}

func main() {
	conn, err := dbus.SessionBus()
	if err != nil {
		os.Exit(1)
	}

	obj := conn.Object(gazeService, gazePath)

	// Registration is uid-derived from the caller's bus credentials inside the
	// daemon; the uid is never passed as an argument.
	if err := obj.Call(gazeIface+".RegisterObserver", 0).Err; err != nil {
		os.Exit(2)
	}
	defer obj.Call(gazeIface+".UnregisterObserver", 0)

	rule := fmt.Sprintf("type='signal',sender='%s',path='%s',interface='%s',member='AuthPhase'",
		gazeService, gazePath, gazeIface)
	if err := conn.BusObject().Call("org.freedesktop.DBus.AddMatch", 0, rule).Err; err != nil {
		os.Exit(3)
	}
	defer conn.BusObject().Call("org.freedesktop.DBus.RemoveMatch", 0, rule)

	// The parent closes stdin to shut us down; on EOF, release and exit.
	go func() {
		bufio.NewReader(os.Stdin).ReadByte()
		os.Exit(0)
	}()

	sig := make(chan os.Signal, 1)
	signal.Notify(sig, syscall.SIGTERM, syscall.SIGINT)
	go func() {
		<-sig
		os.Exit(0)
	}()

	// Consumers use this line to distinguish "connected, waiting" from "no
	// daemon" (which exits non-zero before any output).
	fmt.Println("ready=1")

	signals := make(chan *dbus.Signal, 16)
	conn.Signal(signals)
	defer conn.RemoveSignal(signals)

	for s := range signals {
		if s.Name != gazeIface+".AuthPhase" || len(s.Body) < 4 {
			continue
		}
		phase, ok := s.Body[0].(byte)
		if !ok {
			continue
		}
		rgb, _ := s.Body[1].(byte)
		ir, _ := s.Body[2].(byte)
		surface, _ := s.Body[3].(string)
		fmt.Printf("phase=%s rgb=%s ir=%s surface=%s\n",
			phaseName(phase), statusName(rgb), statusName(ir), surface)
	}
}
