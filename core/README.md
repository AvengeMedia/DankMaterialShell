# DMS Backend & CLI

Go-based backend for DankMaterialShell providing system integration, IPC, and installation tools.

**See [root README](../README.md) for project overview and installation.**

## Components

**dms CLI**
Command-line interface and daemon for shell management and system control.

**dankinstall**
Distribution-aware installer with TUI for deploying DMS and compositor configurations on Arch, Fedora, Debian, Ubuntu, openSUSE, and Gentoo.

## System Integration

**Wayland Protocols**
- `wlr-gamma-control-unstable-v1` - Night mode and gamma control
- `dwl-ipc-unstable-v2` - dwl/MangoWC workspace integration
- `ext-workspace-v1` - Workspace protocol support
- `wlr-output-management-unstable-v1` - Display configuration

**DBus Interfaces**
- NetworkManager/iwd - Network management
- logind - Session control and inhibit locks
- accountsservice - User account information
- CUPS - Printer management
- Custom IPC via unix socket (JSON API)

**Hardware Control**
- DDC/CI protocol - External monitor brightness control (like `ddcutil`)
- Backlight control - Internal display brightness via `login1` or sysfs
- LED control - Keyboard/device LED management
- evdev input monitoring - Keyboard state tracking (caps lock, etc.)

**Plugin System**
- Plugin registry integration
- Plugin lifecycle management
- Settings persistence

## CLI Commands
- `dms run [-d]` - Start shell (optionally as daemon)
- `dms restart` / `dms kill` - Manage running processes
- `dms ipc <command>` - Send IPC commands (toggle launcher, notifications, etc.)
- `dms plugins [install|browse|search]` - Plugin management
- `dms brightness [list|set]` - Control display/monitor brightness
- `dms update` - Update DMS and dependencies (disabled in distro packages)
- `dms greeter install` - Install greetd greeter (disabled in distro packages)

## Building

Requires Go 1.24+

**Development build:**
```bash
make              # Build dms CLI
make dankinstall  # Build installer
make test         # Run tests
```

**Distribution build:**
```bash
make dist         # Build without update/greeter features
```

Produces `bin/dms-linux-amd64` and `bin/dms-linux-arm64`

**Installation:**
```bash
sudo make install  # Install to /usr/local/bin/dms
```

## Development

**Regenerating Wayland Protocol Bindings:**
```bash
go install github.com/rajveermalviya/go-wayland/cmd/go-wayland-scanner@latest
go-wayland-scanner -i internal/proto/xml/wlr-gamma-control-unstable-v1.xml \
  -pkg wlr_gamma_control -o internal/proto/wlr_gamma_control/gamma_control.go
```

**Module Structure:**
- `cmd/` - Binary entrypoints (dms, dankinstall)
- `internal/distros/` - Distribution-specific installation logic
- `internal/proto/` - Wayland protocol bindings
- `pkg/` - Shared packages

## Installation via dankinstall

```bash
curl -fsSL https://install.danklinux.com | sh
```

## Supported Distributions

Arch, Fedora, Debian, Ubuntu, openSUSE, Gentoo (and derivatives)

**Arch Linux**
Uses `pacman` for system packages, builds AUR packages via `makepkg`, no AUR helper dependency.

**Fedora**

Uses COPR repositories (`avengemedia/danklinux`, `avengemedia/dms`).

**Ubuntu**
Requires PPA support. Most packages built from source (slow first install).

**Debian**
Debian 13+ (Trixie). niri only, no Hyprland support. Builds from source.

**openSUSE**
Most packages available in standard repos. Minimal building required.

**Gentoo**
Uses Portage with GURU overlay. Automatically configures USE flags. Variable success depending on system configuration.

See installer output for distribution-specific details during installation.