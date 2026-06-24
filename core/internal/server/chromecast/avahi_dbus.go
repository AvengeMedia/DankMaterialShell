package chromecast

import (
	"context"
	"fmt"
	"strings"
	"sync"

	"github.com/godbus/dbus/v5"
)

// Avahi D-Bus constants (see avahi-common/defs.h).
const (
	avahiIfaceUnspec   = int32(-1) // AVAHI_IF_UNSPEC
	avahiProtoInet     = int32(0)  // AVAHI_PROTO_INET (IPv4)
	avahiServerRunning = int32(2)  // AVAHI_SERVER_RUNNING
)

const (
	avahiDest          = "org.freedesktop.Avahi"
	avahiServerIface   = "org.freedesktop.Avahi.Server"
	avahiBrowserIface  = "org.freedesktop.Avahi.ServiceBrowser"
	avahiItemNewSignal = "org.freedesktop.Avahi.ServiceBrowser.ItemNew"
)

// avahiAvailableFunc reports whether the Avahi daemon is usable. Overridable in
// tests so they never touch the system bus.
var avahiAvailableFunc = avahiAvailable

// avahiBrowseFunc browses one service type via Avahi. Overridable in tests.
var avahiBrowseFunc = browseAvahi

// avahiAvailable reports whether avahi-daemon is running and reachable on the
// system bus. When it is, we browse through it instead of running our own mDNS
// stack, which avoids contending for UDP port 5353 (avahi already owns it).
func avahiAvailable() bool {
	conn, err := dbus.SystemBus()
	if err != nil {
		return false
	}
	var state int32
	err = conn.Object(avahiDest, "/").Call(avahiServerIface+".GetState", 0).Store(&state)
	return err == nil && state == avahiServerRunning
}

// browseAvahi asks Avahi to browse serviceType and returns a channel of
// normalized Devices (tagged with proto). It uses a private system-bus
// connection so its signal stream is isolated; the connection, the browser, and
// the channel are all torn down when ctx is cancelled.
func browseAvahi(ctx context.Context, serviceType string, proto string) (<-chan Device, error) {
	conn, err := dbus.ConnectSystemBus()
	if err != nil {
		return nil, fmt.Errorf("avahi system bus: %w", err)
	}

	server := conn.Object(avahiDest, "/")
	var browserPath dbus.ObjectPath
	if err := server.Call(avahiServerIface+".ServiceBrowserNew", 0,
		avahiIfaceUnspec, avahiProtoInet, serviceType, "", uint32(0)).Store(&browserPath); err != nil {
		conn.Close()
		return nil, fmt.Errorf("avahi ServiceBrowserNew(%s): %w", serviceType, err)
	}

	if err := conn.AddMatchSignal(
		dbus.WithMatchObjectPath(browserPath),
		dbus.WithMatchInterface(avahiBrowserIface),
	); err != nil {
		conn.Close()
		return nil, fmt.Errorf("avahi match: %w", err)
	}

	sig := make(chan *dbus.Signal, 32)
	conn.Signal(sig)

	out := make(chan Device, 8)
	var resolves sync.WaitGroup
	go func() {
		// Defers run LIFO: wait for in-flight resolves, then free the browser and
		// close the bus while they no longer use it, then close the channel.
		defer close(out)
		defer conn.Close()
		defer conn.Object(avahiDest, browserPath).Call(avahiBrowserIface+".Free", 0)
		defer resolves.Wait()

		for {
			select {
			case <-ctx.Done():
				return
			case s, ok := <-sig:
				if !ok {
					return
				}
				if s.Path != browserPath || s.Name != avahiItemNewSignal {
					continue
				}
				// ItemNew(i iface, i proto, s name, s type, s domain, u flags)
				if len(s.Body) < 5 {
					continue
				}
				iface, _ := s.Body[0].(int32)
				protocol, _ := s.Body[1].(int32)
				name, _ := s.Body[2].(string)
				stype, _ := s.Body[3].(string)
				domain, _ := s.Body[4].(string)

				// Resolve off the browse loop so one slow/failed resolve doesn't
				// stall the others, and retry: under mDNS port contention (e.g.
				// Chrome's 5353 socket) a single resolve often loses its response.
				resolves.Add(1)
				go func() {
					defer resolves.Done()
					dev, ok := resolveAvahiRetry(ctx, server, iface, protocol, name, stype, domain, proto)
					if !ok {
						return
					}
					select {
					case out <- dev:
					case <-ctx.Done():
					}
				}()
			}
		}
	}()
	return out, nil
}

// avahiResolveAttempts bounds how many times a browsed item is re-resolved
// before giving up for this announcement (it is retried on the next re-announce).
const avahiResolveAttempts = 3

// resolveAvahiRetry resolves an item, retrying a few times because a single
// mDNS resolve response is easily lost when other listeners share port 5353.
func resolveAvahiRetry(ctx context.Context, server dbus.BusObject, iface, protocol int32, name, stype, domain, proto string) (Device, bool) {
	for attempt := 0; attempt < avahiResolveAttempts; attempt++ {
		if dev, ok := resolveAvahi(server, iface, protocol, name, stype, domain, proto); ok {
			return dev, true
		}
		if ctx.Err() != nil {
			return Device{}, false
		}
	}
	return Device{}, false
}

// resolveAvahi resolves a browsed item to an address + TXT and maps it to a
// Device. Avahi returns names already unescaped, so no DNS-escape decoding is
// needed here (unlike the raw zeroconf path).
func resolveAvahi(server dbus.BusObject, iface, protocol int32, name, stype, domain string, proto string) (Device, bool) {
	var (
		rIface, rProto        int32
		rName, rType, rDomain string
		rHost                 string
		rAproto               int32
		rAddress              string
		rPort                 uint16
		rTxt                  [][]byte
		rFlags                uint32
	)
	err := server.Call(avahiServerIface+".ResolveService", 0,
		iface, protocol, name, stype, domain, avahiProtoInet, uint32(0)).Store(
		&rIface, &rProto, &rName, &rType, &rDomain, &rHost, &rAproto, &rAddress, &rPort, &rTxt, &rFlags)
	if err != nil {
		return Device{}, false // device vanished between browse and resolve
	}

	txt := make(map[string]string, len(rTxt))
	for _, b := range rTxt {
		k, v, ok := strings.Cut(string(b), "=")
		if ok {
			txt[strings.ToLower(k)] = v
		}
	}

	dev := Device{Host: rAddress, Port: int(rPort), Protocol: proto}
	switch proto {
	case ProtocolChromecast:
		// Cast TXT carries the device UUID (id), friendly name (fn), model (md).
		dev.ID = txt["id"]
		dev.Name = txt["fn"]
		dev.Model = txt["md"]
	case ProtocolAirplay:
		// Key on the instance name, consistent with the zeroconf path.
		dev.ID = "airplay:" + rName
		dev.Name = rName
		dev.Model = txt["model"]
	}
	if dev.Name == "" {
		dev.Name = rName
	}
	return dev, true
}
