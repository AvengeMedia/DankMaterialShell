# DankMaterialShell (Quickshell)

A [Quickshell](https://quickshell.org/) built shell designed to be highly functional, in Material 3 style.

Specifically created for [niri](https://github.com/YaLTeR/niri).

<image>

## Installation

1. Install required dependencies

This shell was primarily built for [niri](https://github.com/YaLTeR/niri), but only for workspaces and the active window widget in TopBar. So it could be used on any other wayland compositor with minimal changes.

```bash
# 1 --- Material Symbols Font (if not present)
mkdir -p ~/.local/share/fonts && curl -L "https://github.com/google/material-design-icons/raw/master/variablefont/MaterialSymbolsRounded%5BFILL%2CGRAD%2Copsz%2Cwght%5D.ttf" -o ~/.local/share/fonts/MaterialSymbolsRounded.ttf && fc-cache -f
# Arch: paru -S ttf-material-symbols-variable-git
# Fedora: Use manual installation (Fedora packages contain legacy Material Icons, not Material Symbols)

# 2 --- Inter Variable (recommended font)
mkdir -p ~/.local/share/fonts && curl -L "https://github.com/rsms/inter/releases/download/v4.0/Inter-4.0.zip" -o /tmp/Inter.zip && unzip -j /tmp/Inter.zip "InterVariable.ttf" "InterVariable-Italic.ttf" -d ~/.local/share/fonts/ && rm /tmp/Inter.zip && fc-cache -f
# Arch: pacman -S inter-font
# Fedora: sudo dnf install rsms-inter-fonts

# 3 --- Fira Code (recommended monospace font)
mkdir -p ~/.local/share/fonts && curl -L "https://github.com/tonsky/FiraCode/releases/download/6.2/Fira_Code_v6.2.zip" -o /tmp/FiraCode.zip && unzip -j /tmp/FiraCode.zip "ttf/*.ttf" -d ~/.local/share/fonts/ && rm /tmp/FiraCode.zip && fc-cache -f
# Arch: pacman -S ttf-fira-code
# Fedora: sudo dnf install fira-code-fonts

# 4 --- QuickShell (recommended to use a git build)
# Arch
paru -S quickshell-git

# Fedora
sudo dnf copr enable errornointernet/quickshell
sudo dnf install quickshell
# or
sudo dnf install quickshell-git
```

2. Install optional dependencies to unlock certain features

| Dependency | Purpose | If Missing |
|------------|---------|------------|
| matugen | Allows dynamic themes based on wallpaper and system app theming | Just can choose from preconfigured themes instead of dynamic colors |
| ddcutil | Allows controlling brightness of external monitors via DDC/CI | No external monitor brightness control |
| brightnessctl | Allows controlling brightness of laptop displays via backlight | No laptop display brightness control |
| wl-clipboard | Unlocks copy functionality of certain elements, such as process PIDs | No copy |
| qt5ct + qt6ct | Icon theme and Qt app theming | Setting icon theme in settings won't work for QT5 or QT6 applications, no Qt theming |
| adw-gtk3 | GTK app theming | No GTK theming |
| gsettings | GTK theme management | No GTK theming |

```bash
# Arch
# Core dependencies
sudo pacman -S inter-font ttf-fira-code cava wl-clipboard cliphist
paru -S ttf-material-symbols-variable-git    # AUR package

# Optional: Brightness control
sudo pacman -S ddcutil          # For external monitors
sudo pacman -S brightnessctl    # For laptop displays

# Optional: App theming (only if you use GTK/Qt applications)
sudo pacman -S adw-gtk-theme qt5ct qt6ct gsettings-desktop-schemas

# Third-party packages (AUR)
paru -S matugen

# Fedora
# Core dependencies
sudo dnf install cava wl-clipboard

# COPR packages (core dependencies from third-party repositories)
sudo dnf copr enable wef/cliphist && sudo dnf install cliphist

# Optional: Brightness control
sudo dnf install ddcutil          # For external monitors
sudo dnf install brightnessctl    # For laptop displays

# Optional: App theming (only if you use GTK/Qt applications)
sudo dnf install adw-gtk3-theme qt5ct qt6ct gsettings-desktop-schemas

# Optional third-party packages (COPR repositories)
sudo dnf copr enable heus-sueh/packages && sudo dnf install matugen
```

**Note on networking:** This shell requires NetworkManager for WiFi functionality.

**Note on system app theming:** DankMaterialShell can automatically theme GTK and Qt applications to match your dynamic wallpaper colors. This requires:
- For GTK apps: `adw-gtk3` theme and `gsettings`
- For Qt apps: `qt5ct` and/or `qt6ct`

Enable these features in Settings → Appearance → System App Theming after installing the dependencies.

3. Install DankMaterialShell

```
mkdir -p ~/.config/quickshell
git clone https://github.com/bbedward/DankMaterialShell.git ~/.config/quickshell/DankMaterialShell
```

4. Enable

```
qs -c DankMaterialShell

# In niri config
spawn-at-startup "qs" "-c" "DankMaterialShell"

# Optionally at bindings for spotlight launcher and clipboard history
Mod+Space hotkey-overlay-title="Run an Application: Spotlight" { spawn "qs" "-c" "DankMaterialShell" "ipc" "call" "spotlight" "toggle"; }
Mod+V hotkey-overlay-title="Open Clipboard History" { spawn "qs" "-c" "DankMaterialShell" "ipc" "call" "clipboard" "toggle"; }
```

# Available IPC Events

IPC Events are events that can be triggered with `qs` cli.

```bash
qs -c DankMaterialShell ipc call <target> <function>
```

## System Controls

| Target | Function | Parameters | Description |
|--------|----------|------------|-------------|
| audio | setvolume | percentage (string) | Set audio volume to specific percentage (0-100) |
| audio | increment | step (string, default: "5") | Increase volume by step percentage |
| audio | decrement | step (string, default: "5") | Decrease volume by step percentage |
| audio | mute | none | Toggle audio mute |
| audio | setmic | percentage (string) | Set microphone volume to specific percentage |
| audio | micmute | none | Toggle microphone mute |
| audio | status | none | Get current audio status (output/input levels and mute states) |

## Application Controls

| Target | Function | Parameters | Description |
|--------|----------|------------|-------------|
| spotlight | open | none | Open spotlight (app launcher) |
| spotlight | close | none | Close spotlight (app launcher) |
| spotlight | toggle | none | Toggle spotlight (app launcher) |
| clipboard | open | none | Open clipboard history view |
| clipboard | close | none | Close clipboard history view |
| clipboard | toggle | none | Toggle clipboard history view |
| processlist | open | none | Open process list (task manager) |  
| processlist | close | none | Close process list (task manager) |
| processlist | toggle | none | Toggle process list (task manager) |
| lock | lock | none | Activate lockscreen |
| lock | demo | none | Show lockscreen in demo mode |
| lock | isLocked | none | Returns whether screen is currently locked |

## Media Controls

| Target | Function | Parameters | Description |
|--------|----------|------------|-------------|
| mpris | list | none | Get list of available media players |
| mpris | play | none | Start media playback on active player |
| mpris | pause | none | Pause media playback on active player |
| mpris | playPause | none | Toggle play/pause state on active player |
| mpris | previous | none | Skip to previous track on active player |
| mpris | next | none | Skip to next track on active player |
| mpris | stop | none | Stop media playback on active player |

## System Services

| Target | Function | Parameters | Description |
|--------|----------|------------|-------------|
| wallpaper | get | none | Get current wallpaper path |
| wallpaper | set | path (string) | Set wallpaper to image path and refresh theme |
| wallpaper | clear | none | Clear current wallpaper |
| theme | get | none | Get current theme mode (light/dark) |
| theme | toggle | none | Toggle between light and dark mode |
| theme | light | none | Set theme to light mode |
| theme | dark | none | Set theme to dark mode |
| notifs | clear | none | Clear all notifications |


## (Optional) Setup Calendar events (Google, Microsoft, other Caldev, etc.)

1. Install [khal](https://github.com/pimutils/khal), [vdirsyncer](https://github.com/pimutils/vdirsyncer), and `aiohttp-oauthlib`

```
# Arch
pacman -S vdirsyncer khal python-aiohttp-oauthlib

# Fedora
sudo dnf install python3-vdirsyncer khal python3-aiohttp-oauthlib
```

2. Configure vdirsyncer

Follow the [documentation](https://vdirsyncer.pimutils.org/en/stable/config.html), you will have different steps depending on which calendars you want to sync with.

```
mkdir -p ~/.vdirsyncer

# Create ~/.vdirsyncer/config (a single google calendar would look like)
[general]
status_path = "~/.calendars/status"

[pair personal_sync]
a = "personal"
b = "personallocal"
collections = ["from a", "from b"]
conflict_resolution = "a wins"
metadata = ["color"]

[storage personal]
type = "google_calendar"
token_file = "~/.vdirsyncer/google_calendar_token"
client_id = "...."
client_secret = "...."

[storage personallocal]
type = "filesystem"
path = "~/.calendars/Personal"
fileext = ".ics"

# Sync
vdirsyncer sync

# Create crontab
crontab -e 
# e.g., this syncs every 5 minutes
*/5 * * * * /usr/bin/vdirsyncer sync
```

3. Configure khal

```
# Run this
khal configure

# Choose option 2 for month/day/year
# Time format, doesnt matter
# Choose option 1 for use calendar already on this computer
```

