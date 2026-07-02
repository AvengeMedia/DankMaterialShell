# Casting (Chromecast + AirPlay)

The cast feature discovers both **Chromecast** (`_googlecast._tcp`) and **AirPlay 2**
(`_airplay._tcp`) devices and shows them in one Control Center widget.

- **Chromecast**: media casting + screen mirroring (HLS) handled in-process by the
  `dms` core (Go Cast protocol).
- **AirPlay 2**: screen mirroring via **doubletake** (a separate process).

Screen capture/encode is done by **`dms-cast-helper`**, a small program that uses
the GStreamer **library** (go-gst) — not the `gst-launch`/`ffmpeg`/`wf-recorder`
CLIs. The capture pipeline imports the portal's DMA-BUF via VA-API, forces 4:2:0
(`I420`) chroma (4:4:4 is rejected by most TV decoders → black screen), and
re-stamps timestamps (the portal delivers `pts=0`).

## Build

The main `dms` binary stays CGO-free. The cast helper is opt-in and needs CGO +
GStreamer development packages:

```sh
make build                 # dms (no extra deps)
make cast-helper           # dms-cast-helper (needs gstreamer-1.0 + gst-plugins-base dev, pkg-config, glib dev)
sudo make install install-cast-helper
```

Runtime needs GStreamer plugins (base/good/bad/ugly + pipewire) and, for hardware
DMA-BUF import on Wayland, a VA-API driver.

## AirPlay: external doubletake dependency

AirPlay mirroring shells out to **doubletake** (GPLv3) — a separate binary, never
linked into the MIT `dms`. We use the fork
[`domenkozar/doubletake` (`go-gst-capture`)](https://github.com/domenkozar/doubletake/tree/go-gst-capture),
which drives `gst-launch-1.0` for capture and fixes the black-screen + pts-timing
issues there (DMA-BUF import + 4:2:0 chroma; pending upstream in omarroth/doubletake).

doubletake builds **CGO-free** — no GStreamer dev packages needed; it only needs the
`gst-launch-1.0` CLI and plugins at runtime. Build it and put `bin/doubletake` on
`PATH`, or point `DMS_DOUBLETAKE` at it:

```sh
git clone -b go-gst-capture https://github.com/domenkozar/doubletake
cd doubletake && make            # builds bin/doubletake (CGO-free)
```

Without doubletake, AirPlay devices still appear in discovery but connecting reports
that doubletake is required.

## Discovery

Both protocols are found over mDNS. When **avahi-daemon** is running, `dms`
browses through it (Avahi D-Bus API) and does **not** open its own port-5353
socket — this avoids contending with avahi for the port. Where avahi is absent,
`dms` falls back to a built-in browser (go-chromecast + zeroconf) that
**re-browses periodically** so a resolver that missed responses recovers on the
next cycle.

AirPlay devices are keyed by their mDNS **instance name** (stable and always
present), not the `deviceid` TXT record — the TXT is frequently dropped under
port contention, which would otherwise make the same device flip identity
between scans and break the favorite/auto-reconnect match.

> **Note:** multiple processes sharing UDP port 5353 degrades mDNS for everyone.
> Google Chrome in particular keeps a `224.0.0.251:5353` socket open for its own
> Cast discovery and can intermittently swallow resolve responses (so does any
> second mDNS stack). If discovery shows a device but never resolves its
> address, that contention is the usual cause. Preferring avahi and retrying
> resolves mitigates it, but a misbehaving co-resident mDNS listener can still
> cause flakiness.

## Firewall

AirPlay receivers connect *back* to the sender on negotiated ports. `dms` confines
them to a fixed range (default `60000-60010`, override `DMS_CAST_PORT_RANGE`); open
that range inbound (UDP+TCP). On NixOS:

```nix
networking.firewall.allowedUDPPortRanges = [ { from = 60000; to = 60010; } ];
networking.firewall.allowedTCPPortRanges = [ { from = 60000; to = 60010; } ];
```

## Environment overrides

- `DMS_CAST_HELPER` — path to `dms-cast-helper` (default: next to `dms`, then PATH).
- `DMS_DOUBLETAKE` — path to `doubletake` (default: PATH).
- `DMS_CAST_PORT_RANGE` — AirPlay back-channel port range (default `60000-60010`).
