# Void Linux packaging

XBPS templates for DankMaterialShell on [Void Linux](https://voidlinux.org).

| Package | Source repo | Template |
| --- | --- | --- |
| `dms` | DankMaterialShell | [`srcpkgs/dms/template`](srcpkgs/dms/template) |
| `dms-greeter` (optional) | DankMaterialShell | [`srcpkgs/dms-greeter/template`](srcpkgs/dms-greeter/template) |
| `dgop` | AvengeMedia/dgop | maintained in the **danklinux** repo (`distro/void/srcpkgs/dgop`) |
| `danksearch` | AvengeMedia/danksearch | maintained in the **danklinux** repo (`distro/void/srcpkgs/danksearch`) |

All build from source.

## Distribution

These packages target the official
[`void-linux/void-packages`](https://github.com/void-linux/void-packages)
repository, so they install with a plain `xbps-install dms` and no extra setup.
Most dependencies (`quickshell`, `matugen`, `cava`, `niri`, `greetd`, …) are
already in Void; `dgop` and `danksearch` are packaged alongside in the
[danklinux repo](https://github.com/AvengeMedia/danklinux/tree/master/distro/void).

The templates here are the source of truth: copy each into a void-packages
checkout at `srcpkgs/<pkg>/template` to build or submit it. Only tagged releases
are packaged (no `-git`/nightly variant).

## Dependencies

Installing `dms` automatically pulls in `quickshell`, `accountsservice`, `dgop`,
and `matugen` (which drives the Material You theming). The rest are optional —
install whichever features you want:

| Package | Enables |
| --- | --- |
| `danksearch` | launcher / filesystem search |
| `cava` | audio visualiser widget |
| `qt6-multimedia` | system sound feedback |
| `qt6ct` | Qt app theming |
| `wtype` | virtual keyboard input |
| `power-profiles-daemon` | power profile control |
| `cups-pk-helper` | printer management |
| `NetworkManager` | network control |
| `i2c-tools` | external-monitor brightness (DDC) |
| `niri` / `hyprland` / `sway` | a Wayland compositor (niri is the team's choice) |

## Building & testing

Inside a `void-packages` checkout (symlink or copy these `srcpkgs/<pkg>` dirs in):

```sh
# build the dependency packages first (dms requires dgop)
./xbps-src pkg dgop
./xbps-src pkg danksearch
./xbps-src pkg dms
./xbps-src pkg dms-greeter      # optional

# lint (xlint ships in the xtools package)
xlint srcpkgs/dms/template

# install the built packages
sudo xbps-install --repository=hostdir/binpkgs dms dgop
```

`dms` requires Go ≥ 1.26 in the build environment (per `core/go.mod`).

## Running the shell

DMS is a user-level Wayland shell with **no system service** — start it from your
compositor's autostart, e.g. niri:

```kdl
spawn-at-startup "dms" "run"
```

or Hyprland: `exec-once = dms run`.

## Greeter (optional)

Install `dms-greeter`, then let the CLI do the setup:

```sh
dms greeter enable      # configures greetd + the Void seat/PAM bits below
dms greeter sync        # optional: share theming with the shell
```

`dms greeter enable` handles what logind does automatically on systemd: it points
greetd at the greeter, enables `seatd`, adds `_greeter` to the `_seatd`/`video`/
`input` groups, and adds `pam_rundir` to `/etc/pam.d/greetd` (so the post-login
session gets an `XDG_RUNTIME_DIR`). A Wayland compositor and a working DRM device
(`/dev/dri/card*`) are required and not pulled in automatically.
