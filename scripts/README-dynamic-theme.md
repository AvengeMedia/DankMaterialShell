# Dynamic Theme Setup

This setup adds wallpaper-aware "Auto" theme support to your Quickshell + Niri environment.

## Prerequisites

Install the required tools:

```bash
# Required for Material-You palette generation
# Or paru -S matugen-bin on arch
cargo install matugen

# Required for JSON processing (usually pre-installed)
sudo pacman -S jq  # Arch Linux
# or: sudo apt install jq  # Ubuntu/Debian

# Background setters (choose one)
sudo pacman -S swaybg  # Simple and reliable
```

## Setup

1. **Initial wallpaper setup:**
   ```bash
   # Set your initial wallpaper
   sudo cp ./set-wallpaper.sh /usr/local/bin
   sudo chmod +x /usr/local/bin/set-wallpaper.sh
   set-wallpaper.sh /path/to/your/wallpaper.jpg
   ```

2. **Enable Niri color integration (optional):**
   Niri doesn't have a good way to just set colors, you have to edit your main `~/.config/niri/config.kdl`

   The script generates suggestions in `~/quickshell/generated_niri_colors.kdl` you can manually configure in Niri.

3. **Enable Auto theme:**
   Open Control Center → Theme Picker → Click the gradient "Auto" button

4. **Configure swaybg systemd unit**

```
[Unit]
PartOf=graphical-session.target
After=graphical-session.target
Requisite=graphical-session.target

[Service]
ExecStart=/usr/bin/swaybg -m fill -i "%h/quickshell/current_wallpaper"
Restart=on-failure
```

```bash
systemctl enable --user --now swaybg
```