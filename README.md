# DankMaterialShell (Quickshell)

A [Quickshell](https://quickshell.org/) built shell designed to be highly functional, in Material 3 style.

Specifically created for [Niri](https://github.com/YaLTeR/niri).

<image>

## Installation

1. Install dependencies, this will vary based on your distribution.

```bash
# Arch
paru -S quickshell-git nerd-fonts ttf-material-symbols-variable-git matugen cliphist cava

# Some dependencies are optional
# - cava for audio visualizer, without it music will just randomly visualize
# - cliphist for clipboard history
# - matugen for dynamic themes based on wallpaper
```

2. Configure SwayBG (Optional)

```
# Install wallpaper script
sudo cp ./scripts/set-wallpaper.sh /usr/local/bin/set-wallpaper.sh
sudo chmod +x /usr/local/bin/set-wallpaper.sh

# Arch
pacman -S swaybg

# Create service
echo '[Unit]
PartOf=graphical-session.target
After=graphical-session.target
Requisite=graphical-session.target

[Service]
ExecStart=/usr/bin/swaybg -m fill -i "%h/quickshell/current_wallpaper"
Restart=on-failure

[Install]
WantedBy=graphical-session.target' > ~/.config/systemd/user/swaybg.service

# Set a wallpaper
set-wallpaper.sh /path/to/image.jpg

# Enable service
systemctl --user enable --now swaybg.service
```

3. Install DankMaterialShell

```
mkdir -p ~/.config/quickshell
git clone https://github.com/bbedward/DankMaterialShell.git ~/.config/quickshell/DankMaterialShell
```

4. Enable

```
qs -c DankMaterialDark

# In niri config
spawn-at-startup "qs" "-c" "DankMaterialDark"

# Optionally at bindings for spotlight launcher and clipboard history
Mod+Space hotkey-overlay-title="Run an Application: Spotlight" { spawn "qs" "-c" "DankMaterialShell" "ipc" "call" "spotlight" "toggle"; }
Mod+V hotkey-overlay-title="Open Clipboard History" { spawn "qs" "-c" "DankMaterialShell" "ipc" "call" "clipboard" "toggle"; }
```

## Setup Calendar events (Google, Microsoft, other Caldev, etc.)

1. Install [khal](https://github.com/pimutils/khal), [vdirsyncer](https://github.com/pimutils/vdirsyncer), and `aiohttp-oauthlib`

```
# Arch
pacman -S vdirsyncer khal python-aiohttp-oauthlib
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
# Choose option 1 for use calendar alreayd on this computer
```

