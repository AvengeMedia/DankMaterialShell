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

This is a DMS maintained repo for VoidLinux until these packages are officially merged upstream in the Void Linux repositories, you can install them from our self-hosted custom XBPS repositories served via GitHub Pages.

### Using the Self-Hosted Repositories

We serve both stable release and development packages from Cloudflare R2 at
`void.danklinux.com`.

> **Repository migration:** the former GitHub Pages repositories will be
> frozen for 14 days at cutover. Their retirement date will be announced when
> the snapshots are frozen. Replace any existing `avengemedia.github.io`
> entries with the URLs below.

#### 1. Add Repository Configurations

Create configuration files in `/etc/xbps.d/` pointing to our repositories (needed for both stable and git/nightly variants):

```sh
echo "repository=https://void.danklinux.com/dms/current" | sudo tee /etc/xbps.d/dms.conf
echo "repository=https://void.danklinux.com/danklinux/current" | sudo tee /etc/xbps.d/danklinux.conf
```

#### 2. Install DMS

Synchronize repositories and install the package:

* For the **stable** variant:

    ```sh
    sudo xbps-install -S dms
    ```

* For the **git/nightly** variant (this will conflict with and replace the stable package):

    ```sh
    sudo xbps-install -S dms-git
    ```

*Note: On the first sync, `xbps-install` will output our signing key fingerprint and ask you to type `y` to trust and import it. Verify that the key matches our official signing fingerprint.*

The templates here are the source of truth: copy each into a void-packages
checkout at `srcpkgs/<pkg>/template` to build or submit it.

## Dependencies

Installing `dms` automatically pulls in `quickshell`, `accountsservice`, `dgop`,
`matugen` (which drives the Material You theming), `dbus`, `elogind`, and
`mesa-dri` (GL drivers, required for compositors to render).
The rest are optional, install whichever features you want:

| Package | Enables |
| --- | --- |
| `danksearch` | launcher / filesystem search |
| `cava` | audio visualiser widget |
| `qt6-multimedia` | system sound feedback |
| `qt6ct` | Qt app theming |
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

From a TTY on Void without a greeter, start your compositor through a D-Bus
session:

```sh
dbus-run-session niri
dbus-run-session Hyprland
dbus-run-session mango
```

The `mangowc` package provides the `mango` command.

For power menu actions to work on runit systems, make sure the system D-Bus and
elogind services are enabled:

```sh
sudo ln -sf /etc/sv/dbus /var/service/dbus
sudo ln -sf /etc/sv/elogind /var/service/elogind
```

The `dankinstall` Void path enables both services after installing packages.

## Greeter (optional)

Install `dms-greeter`, then let the CLI do the setup:

```sh
dms greeter enable      # configures greetd + the Void seat/PAM bits below
dms greeter sync        # optional: share theming with the shell
```

`dms-greeter` requires D-Bus and elogind. `dms greeter enable` enables the
`dbus` and `elogind` runit services, configures greetd for elogind
(`LIBSEAT_BACKEND=logind`), adds `_greeter` to the `video` and `input` groups,
and adds `pam_rundir` to `/etc/pam.d/greetd` (so the post-login session gets an
`XDG_RUNTIME_DIR`). It disables seatd if enabled: on Void, seatd is the
alternative to elogind, and running both fights over the seat. Greeter sessions
are launched through `dbus-run-session`. A Wayland compositor and a working DRM
device (`/dev/dri/card*`) are required and not pulled in automatically.

`dms greeter enable` also rewrites `/etc/sv/greetd/run` to wait for the `dbus`
and `elogind` services, preventing a first-boot race that can leave the greeter
on a black screen. greetd package updates restore the stock run script; re-run
`dms greeter enable` afterwards.
