#!/usr/bin/env bash
set -euo pipefail

img=$1
# Convert to absolute path to fix symlink issues
img=$(realpath "$img")

QS_DIR="$HOME/quickshell"
mkdir -p "$QS_DIR"
LINK="$QS_DIR/current_wallpaper"

ln -sf -- "$img" "$LINK"

# Kill existing swaybg processes before starting new one
pkill -f "swaybg.*$LINK" 2>/dev/null || true
swaybg -m fill -i "$LINK" & disown

json="$(matugen image "$img" --json hex)"
get() { jq -r "$1" <<<"$json"; }

bg=$(get '.colors.dark.background')
fg=$(get '.colors.dark.on_background')
primary=$(get '.colors.dark.primary')
secondary=$(get '.colors.dark.secondary')
tertiary=$(get '.colors.dark.tertiary')
tertiary_ctr=$(get '.colors.dark.tertiary_container')
error=$(get '.colors.dark.error')
inverse=$(get '.colors.dark.inverse_primary')

bg_b=$(get '.colors.light.background')
fg_b=$(get '.colors.light.on_background')
primary_b=$(get '.colors.light.primary')
secondary_b=$(get '.colors.light.secondary')
tertiary_b=$(get '.colors.light.tertiary')
tertiary_ctr_b=$(get '.colors.light.tertiary_container')
error_b=$(get '.colors.light.error')
inverse_b=$(get '.colors.light.inverse_primary')

cat >"$QS_DIR/generated_niri_colors.kdl" <<EOF
// AUTO-GENERATED on $(date)
layout {
    border {
        active-color   "$primary"
        inactive-color "$secondary"
    }
    focus-ring {
        active-color   "$inverse"
    }
    background-color "$bg"
}
EOF

echo "→ Niri colours:   $QS_DIR/generated_niri_colors.kdl"

cat >"$QS_DIR/generated_ghostty_colors.conf" <<EOF
# AUTO-GENERATED on $(date)
background = $bg
foreground = $fg
cursor-color = $inverse
selection-background = $secondary
selection-foreground = #ffffff
palette = 0=$bg
palette = 1=$error
palette = 2=$tertiary
palette = 3=$secondary
palette = 4=$primary
palette = 5=$tertiary_ctr
palette = 6=$inverse
palette = 7=$fg
palette = 8=$bg_b
palette = 9=$error_b
palette = 10=$tertiary_b
palette = 11=$secondary_b
palette = 12=$primary_b
palette = 13=$tertiary_ctr_b
palette = 14=$inverse_b
palette = 15=$fg_b
EOF

echo "→ Ghostty theme:  $QS_DIR/generated_ghostty_colors.conf"
echo "   (use in ghostty:  theme = $QS_DIR/generated_ghostty_colors.conf )"

niri msg action do-screen-transition --delay-ms 100

# Notify running shell about wallpaper change via IPC
qs -c "DankMaterialShell" ipc call wallpaper refresh 2>/dev/null && echo "→ Shell notified via IPC" || echo "→ Shell not running or IPC failed"