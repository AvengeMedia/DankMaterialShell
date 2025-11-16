package client

import (
	"errors"
	"fmt"
	"net"
	"os"
	"sync"

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

func (ctx *Context) Unregister(p Proxy) {
	ctx.objects.Delete(p.ID())
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

	return func() error {
		proxy, ok := ctx.objects.Load(senderID)
		if !ok {
			return fmt.Errorf("%w (senderID=%d)", ErrDispatchSenderNotFound, senderID)
		}

		sender, ok := proxy.(Dispatcher)
		if !ok {
			return fmt.Errorf("%w (senderID=%d)", ErrDispatchSenderUnsupported, senderID)
		}

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
