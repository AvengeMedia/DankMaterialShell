# Dynamic Theme Setup

This setup adds wallpaper-aware "Auto" theme support to your Quickshell + Niri environment.

## Prerequisites

Install the required tools:

```bash
# Required for Material-You palette generation
cargo install matugen

# Required for JSON processing (usually pre-installed)
sudo pacman -S jq  # Arch Linux
# or: sudo apt install jq  # Ubuntu/Debian

# Background setters (choose one)
sudo pacman -S swaybg  # Simple and reliable
# or: cargo install swww  # Smoother transitions
```

## Setup

1. **Initial wallpaper setup:**
   ```bash
   # Set your initial wallpaper
   ./scripts/set-wallpaper.sh /path/to/your/wallpaper.jpg
   ```

2. **Enable Niri color integration (optional):**
   Add this line to your `~/.config/niri/config.kdl`:
   ```kdl
   !include "generated_colors.kdl"
   ```

3. **Enable Auto theme:**
   Open Control Center → Theme Picker → Click the gradient "Auto" button

## Usage

### Change wallpaper and auto-update theme:
```bash
./scripts/set-wallpaper.sh /new/wallpaper.jpg
```

### Manual theme switching:
- Use the Control Center theme picker
- Preferences persist across restarts
- Auto theme requires wallpaper symlink to exist

## How it works

1. **Color extraction:** `Colors.qml` uses Quickshell's ColorQuantizer to extract dominant colors from the wallpaper symlink
2. **Persistence:** `Prefs.qml` stores your theme choice using PersistentProperties
3. **Dynamic switching:** `Theme.qml` switches between static themes and wallpaper colors
4. **Auto-reload:** Quickshell's file watching automatically reloads when the wallpaper symlink changes

## Troubleshooting

### "Dynamic theme requires wallpaper setup!" error
Run the setup command:
```bash
./scripts/set-wallpaper.sh /path/to/your/wallpaper.jpg
```

### Colors don't update when changing wallpaper
- Make sure you're using the script, not manually changing files
- The symlink at `~/quickshell/current_wallpaper` must exist

### Niri colors don't change
- Ensure `!include "generated_colors.kdl"` is in your config.kdl
- Check that matugen and jq are installed
- Look for `~/.config/niri/generated_colors.kdl`