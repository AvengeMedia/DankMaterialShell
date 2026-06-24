package chromecast

import (
	"context"
	"fmt"
	"strings"

	"github.com/grandcat/zeroconf"
)

// airplayDiscoverFunc browses for AirPlay devices. Overridable in tests.
var airplayDiscoverFunc = discoverAirplay

// discoverAirplay browses _airplay._tcp and returns a channel of normalized
// AirPlay devices. The channel is closed when ctx is cancelled.
func discoverAirplay(ctx context.Context) (<-chan Device, error) {
	resolver, err := zeroconf.NewResolver(nil)
	if err != nil {
		return nil, fmt.Errorf("airplay resolver: %w", err)
	}

	entries := make(chan *zeroconf.ServiceEntry, 8)
	if err := resolver.Browse(ctx, "_airplay._tcp", "local.", entries); err != nil {
		return nil, fmt.Errorf("airplay browse: %w", err)
	}

	out := make(chan Device, 8)
	go func() {
		defer close(out)
		for {
			select {
			case <-ctx.Done():
				return
			case entry, ok := <-entries:
				if !ok {
					return
				}
				dev := airplayEntryToDevice(entry)
				if dev.Host == "" {
					continue
				}
				select {
				case out <- dev:
				case <-ctx.Done():
					return
				}
			}
		}
	}()
	return out, nil
}

// unescapeDNS decodes DNS presentation-format escapes (\DDD decimal byte
// escapes and \X literal escapes) that zeroconf leaves in instance names, e.g.
// "Geoffrey\226\128\153s\ MacBook" -> "Geoffrey’s MacBook".
func unescapeDNS(s string) string {
	if !strings.Contains(s, "\\") {
		return s
	}
	var b strings.Builder
	for i := 0; i < len(s); i++ {
		if s[i] != '\\' || i+1 >= len(s) {
			b.WriteByte(s[i])
			continue
		}
		if i+3 < len(s) && isDigit(s[i+1]) && isDigit(s[i+2]) && isDigit(s[i+3]) {
			b.WriteByte(byte((int(s[i+1]-'0')*100 + int(s[i+2]-'0')*10 + int(s[i+3]-'0'))))
			i += 3
			continue
		}
		b.WriteByte(s[i+1])
		i++
	}
	return b.String()
}

func isDigit(c byte) bool { return c >= '0' && c <= '9' }

// airplayEntryToDevice normalizes a zeroconf _airplay._tcp entry into a Device.
func airplayEntryToDevice(entry *zeroconf.ServiceEntry) Device {
	dev := Device{
		Name:     unescapeDNS(entry.Instance),
		Port:     entry.Port,
		Protocol: ProtocolAirplay,
	}
	if len(entry.AddrIPv4) > 0 {
		dev.Host = entry.AddrIPv4[0].String()
	}
	// AirPlay TXT records carry model (and a deviceid we deliberately do NOT key
	// on — see below).
	for _, txt := range entry.Text {
		k, v, ok := strings.Cut(txt, "=")
		if !ok {
			continue
		}
		if strings.EqualFold(k, "model") {
			dev.Model = v
		}
	}

	// Key on the mDNS instance name, not the deviceid TXT or host:port. The
	// instance comes from the PTR/SRV records and is present in every resolved
	// browse response; the deviceid TXT is frequently dropped under mDNS port
	// contention (avahi + other listeners share 5353), which previously made the
	// same device flip between its MAC id and a host:port fallback across
	// browses — breaking favorite/auto-reconnect matching and de-duplication.
	switch {
	case entry.Instance != "":
		dev.ID = "airplay:" + unescapeDNS(entry.Instance)
	case entry.HostName != "":
		dev.ID = "airplay:" + strings.TrimSuffix(entry.HostName, ".")
	default:
		dev.ID = fmt.Sprintf("airplay:%s:%d", dev.Host, dev.Port)
	}
	if dev.Name == "" {
		dev.Name = strings.TrimPrefix(dev.ID, "airplay:")
	}
	return dev
}
