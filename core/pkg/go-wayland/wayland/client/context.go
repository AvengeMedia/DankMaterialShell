package client

import (
	"errors"
	"fmt"
	"net"
	"os"
	"sync"
	"time"

	"github.com/AvengeMedia/DankMaterialShell/core/pkg/syncmap"
)

type Context struct {
	conn      *net.UnixConn
	objects   syncmap.Map[uint32, Proxy] // map[uint32]Proxy - thread-safe concurrent map
	currentID uint32
	idMu      sync.Mutex // protects currentID increment
}

func (ctx *Context) Register(p Proxy) {
	ctx.idMu.Lock()
	ctx.currentID++
	id := ctx.currentID
	ctx.idMu.Unlock()

	p.SetID(id)
	p.SetContext(ctx)
	ctx.objects.Store(id, p)
}

func (ctx *Context) RegisterWithID(p Proxy, id uint32) {
	p.SetID(id)
	p.SetContext(ctx)
	ctx.objects.Store(id, p)
}

func (ctx *Context) Unregister(p Proxy) {
	ctx.objects.Delete(p.ID())
}

func (ctx *Context) DeleteID(id uint32) {
	ctx.objects.Delete(id)
}

func (ctx *Context) GetProxy(id uint32) Proxy {
	if val, ok := ctx.objects.Load(id); ok {
		return val
	}
	return nil
}

func (ctx *Context) Close() error {
	return ctx.conn.Close()
}

func (ctx *Context) SetReadDeadline(t time.Time) error {
	return ctx.conn.SetReadDeadline(t)
}

func (ctx *Context) Fd() int {
	rawConn, err := ctx.conn.SyscallConn()
	if err != nil {
		return -1
	}
	var fd int
	rawConn.Control(func(f uintptr) {
		fd = int(f)
	})
	return fd
}

// Dispatch reads and processes incoming messages and calls [client.Dispatcher.Dispatch] on the
// respective wayland protocol.
// Dispatch must be called on the same goroutine as other interactions with the Context.
// If a multi goroutine approach is desired, use [Context.GetDispatch] instead.
// Dispatch blocks if there are no incoming messages.
// A Dispatch loop is usually used to handle incoming messages.
func (ctx *Context) Dispatch() error {
	return ctx.GetDispatch()()
}

var ErrDispatchSenderNotFound = errors.New("dispatch: unable to find sender")
var ErrDispatchSenderUnsupported = errors.New("dispatch: sender does not implement Dispatch method")
var ErrDispatchUnableToReadMsg = errors.New("dispatch: unable to read msg")

// GetDispatch reads incoming messages and returns the dispatch function which calls
// [client.Dispatcher.Dispatch] on the respective wayland protocol.
// This function is now thread-safe and can be called from multiple goroutines.
// GetDispatch blocks if there are no incoming messages.
func (ctx *Context) GetDispatch() func() error {
	senderID, opcode, fd, data, err := ctx.ReadMsg() // Blocks if there are no incoming messages
	if err != nil {
		return func() error {
			return fmt.Errorf("%w: %w", ErrDispatchUnableToReadMsg, err)
		}
	}

	return func() (dispatchErr error) {
		proxy, ok := ctx.objects.Load(senderID)
		if !ok {
			return nil // Proxy already deleted via delete_id, silently ignore
		}

		if proxy.IsZombie() {
			return nil // Zombie proxy, discard late events
		}

		sender, ok := proxy.(Dispatcher)
		if !ok {
			return fmt.Errorf("%w (senderID=%d)", ErrDispatchSenderUnsupported, senderID)
		}

		// generated Dispatch methods don't bounds-check wire data; surface a
		// decoder panic as an error instead of crashing the process
		defer func() {
			if r := recover(); r != nil {
				dispatchErr = fmt.Errorf("dispatch: panic handling opcode=%d senderID=%d: %v", opcode, senderID, r)
			}
		}()

		sender.Dispatch(opcode, fd, data)
		return nil
	}
}

func Connect(addr string) (*Display, error) {
	if addr == "" {
		runtimeDir := os.Getenv("XDG_RUNTIME_DIR")
		if runtimeDir == "" {
			return nil, errors.New("env XDG_RUNTIME_DIR not set")
		}
		if addr == "" {
			addr = os.Getenv("WAYLAND_DISPLAY")
		}
		if addr == "" {
			addr = "wayland-0"
		}
		addr = runtimeDir + "/" + addr
	}

	ctx := &Context{}

	conn, err := net.DialUnix("unix", nil, &net.UnixAddr{Name: addr, Net: "unix"})
	if err != nil {
		return nil, err
	}
	ctx.conn = conn

	return NewDisplay(ctx), nil
}
