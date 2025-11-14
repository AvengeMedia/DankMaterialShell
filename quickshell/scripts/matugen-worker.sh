#!/usr/bin/env bash
set -euo pipefail

if [ $# -lt 5 ]; then
    echo "Usage: $0 STATE_DIR SHELL_DIR CONFIG_DIR SYNC_MODE_WITH_PORTAL TERMINALS_ALWAYS_DARK --run" >&2
    exit 1
fi

STATE_DIR="$1"
SHELL_DIR="$2"
CONFIG_DIR="$3"
SYNC_MODE_WITH_PORTAL="$4"
TERMINALS_ALWAYS_DARK="$5"

if [ ! -d "$STATE_DIR" ]; then
    echo "Error: STATE_DIR '$STATE_DIR' does not exist" >&2
    exit 1
fi

if [ ! -d "$SHELL_DIR" ]; then
    echo "Error: SHELL_DIR '$SHELL_DIR' does not exist" >&2
    exit 1
fi

if [ ! -d "$CONFIG_DIR" ]; then
    echo "Error: CONFIG_DIR '$CONFIG_DIR' does not exist" >&2
    exit 1
fi

shift 5

if [[ "${1:-}" != "--run" ]]; then
  echo "usage: $0 STATE_DIR SHELL_DIR CONFIG_DIR SYNC_MODE_WITH_PORTAL TERMINALS_ALWAYS_DARK --run" >&2
  exit 1
fi

DESIRED_JSON="$STATE_DIR/matugen.desired.json"
BUILT_KEY="$STATE_DIR/matugen.key"
LAST_JSON="$STATE_DIR/last.json"
LOCK="$STATE_DIR/matugen-worker.lock"

exec 9>"$LOCK"
flock 9

rm -f "$BUILT_KEY"

get_matugen_major_version() {
  local version_output=$(matugen --version 2>&1)
  local version=$(echo "$version_output" | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -n1)
  local major=$(echo "$version" | cut -d. -f1)
  echo "$major"
}

MATUGEN_VERSION=$(get_matugen_major_version)

read_desired() {
  [[ ! -f "$DESIRED_JSON" ]] && { echo "no desired state" >&2; exit 0; }
  cat "$DESIRED_JSON"
}

key_of() {
  local json="$1"
  local kind=$(echo "$json" | sed 's/.*"kind": *"\([^"]*\)".*/\1/')
  local value=$(echo "$json" | sed 's/.*"value": *"\([^"]*\)".*/\1/')
  local mode=$(echo "$json" | sed 's/.*"mode": *"\([^"]*\)".*/\1/')
  local icon=$(echo "$json" | sed 's/.*"iconTheme": *"\([^"]*\)".*/\1/')
  local matugen_type=$(echo "$json" | sed 's/.*"matugenType": *"\([^"]*\)".*/\1/')
  local run_user_templates=$(echo "$json" | sed 's/.*"runUserTemplates": *\([^,}]*\).*/\1/')
  [[ -z "$icon" ]] && icon="System Default"
  [[ -z "$matugen_type" ]] && matugen_type="scheme-tonal-spot"
  [[ -z "$run_user_templates" ]] && run_user_templates="true"
  echo "${kind}|${value}|${mode}|${icon}|${matugen_type}|${run_user_templates}" | sha256sum | cut -d' ' -f1
}

set_system_color_scheme() {
  local mode="$1"

  if [[ "$SYNC_MODE_WITH_PORTAL" != "true" ]]; then
    return 0
  fi

  local target_scheme
  if [[ "$mode" == "light" ]]; then
    target_scheme="default"
  else
    target_scheme="prefer-dark"
  fi

  if command -v gsettings >/dev/null 2>&1; then
    gsettings set org.gnome.desktop.interface color-scheme "$target_scheme" >/dev/null 2>&1 || true
  elif command -v dconf >/dev/null 2>&1; then
    dconf write /org/gnome/desktop/interface/color-scheme "'$target_scheme'" >/dev/null 2>&1 || true
  fi
}

build_once() {
  local json="$1"
  local kind value mode icon matugen_type run_user_templates
  kind=$(echo "$json" | sed 's/.*"kind": *"\([^"]*\)".*/\1/')
  value=$(echo "$json" | sed 's/.*"value": *"\([^"]*\)".*/\1/')
  mode=$(echo "$json" | sed 's/.*"mode": *"\([^"]*\)".*/\1/')
  icon=$(echo "$json" | sed 's/.*"iconTheme": *"\([^"]*\)".*/\1/')
  matugen_type=$(echo "$json" | sed 's/.*"matugenType": *"\([^"]*\)".*/\1/')
  run_user_templates=$(echo "$json" | sed 's/.*"runUserTemplates": *\([^,}]*\).*/\1/')
  [[ -z "$icon" ]] && icon="System Default"
  [[ -z "$matugen_type" ]] && matugen_type="scheme-tonal-spot"
  [[ -z "$run_user_templates" ]] && run_user_templates="true"

  USER_MATUGEN_DIR="$CONFIG_DIR/matugen/dms"
  
  TMP_CFG="$(mktemp)"
  trap 'rm -f "$TMP_CFG"' RETURN

  if [[ "$run_user_templates" == "true" ]] && [[ -f "$CONFIG_DIR/matugen/config.toml" ]]; then
    awk '/^\[config/{p=1} /^\[templates/{p=0} p' "$CONFIG_DIR/matugen/config.toml" >> "$TMP_CFG"
    echo "" >> "$TMP_CFG"
  else
    echo "[config]" >> "$TMP_CFG"
    echo "" >> "$TMP_CFG"
  fi

  grep -v '^\[config\]' "$SHELL_DIR/matugen/configs/base.toml" | \
    sed "s|'SHELL_DIR/|'$SHELL_DIR/|g" >> "$TMP_CFG"
  echo "" >> "$TMP_CFG"

  cat >> "$TMP_CFG" << EOF
[templates.dank]
input_path = '$SHELL_DIR/matugen/templates/dank.json'
output_path = '$STATE_DIR/dms-colors.json'

EOF

  # If light mode, use gtk3 light config
  if [[ "$mode" == "light" ]]; then
    sed "s|'SHELL_DIR/|'$SHELL_DIR/|g" "$SHELL_DIR/matugen/configs/gtk3-light.toml" >> "$TMP_CFG"
    echo "" >> "$TMP_CFG"
  else
    sed "s|'SHELL_DIR/|'$SHELL_DIR/|g" "$SHELL_DIR/matugen/configs/gtk3-dark.toml" >> "$TMP_CFG"
    echo "" >> "$TMP_CFG"
  fi

  if command -v niri >/dev/null 2>&1; then
    sed "s|'SHELL_DIR/|'$SHELL_DIR/|g" "$SHELL_DIR/matugen/configs/niri.toml" >> "$TMP_CFG"
    echo "" >> "$TMP_CFG"
  fi

  if command -v qt5ct >/dev/null 2>&1; then
    sed "s|'SHELL_DIR/|'$SHELL_DIR/|g" "$SHELL_DIR/matugen/configs/qt5ct.toml" >> "$TMP_CFG"
    echo "" >> "$TMP_CFG"
  fi

  if command -v qt6ct >/dev/null 2>&1; then
    sed "s|'SHELL_DIR/|'$SHELL_DIR/|g" "$SHELL_DIR/matugen/configs/qt6ct.toml" >> "$TMP_CFG"
    echo "" >> "$TMP_CFG"
  fi

  if command -v firefox >/dev/null 2>&1; then
    sed "s|'SHELL_DIR/|'$SHELL_DIR/|g" "$SHELL_DIR/matugen/configs/firefox.toml" >> "$TMP_CFG"
    echo "" >> "$TMP_CFG"
  fi

  if command -v pywalfox >/dev/null 2>&1; then
    sed "s|'SHELL_DIR/|'$SHELL_DIR/|g" "$SHELL_DIR/matugen/configs/pywalfox.toml" >> "$TMP_CFG"
    echo "" >> "$TMP_CFG"
  fi

  if command -v vesktop >/dev/null 2>&1 && [[ -d "$CONFIG_DIR/vesktop" ]]; then
    sed "s|'SHELL_DIR/|'$SHELL_DIR/|g" "$SHELL_DIR/matugen/configs/vesktop.toml" >> "$TMP_CFG"
    echo "" >> "$TMP_CFG"
  fi

  if [[ "$run_user_templates" == "true" ]] && [[ -f "$CONFIG_DIR/matugen/config.toml" ]]; then
    awk '/^\[templates/{p=1} p' "$CONFIG_DIR/matugen/config.toml" >> "$TMP_CFG"
    echo "" >> "$TMP_CFG"
  fi

  for config in "$USER_MATUGEN_DIR/configs"/*.toml; do
    [[ -f "$config" ]] || continue
    cat "$config" >> "$TMP_CFG"
    echo "" >> "$TMP_CFG"
  done

  pushd "$SHELL_DIR" >/dev/null
  MAT_MODE=(-m "$mode")
  MAT_TYPE=(-t "$matugen_type")

  case "$kind" in
    image)
      [[ -f "$value" ]] || { echo "wallpaper not found: $value" >&2; popd >/dev/null; return 2; }
      JSON=$(matugen -c "$TMP_CFG" --json hex image "$value" "${MAT_MODE[@]}" "${MAT_TYPE[@]}")
      matugen -c "$TMP_CFG" image "$value" "${MAT_MODE[@]}" "${MAT_TYPE[@]}" >/dev/null
      ;;
    hex)
      [[ "$value" =~ ^#[0-9A-Fa-f]{6}$ ]] || { echo "invalid hex: $value" >&2; popd >/dev/null; return 2; }
      JSON=$(matugen -c "$TMP_CFG" --json hex color hex "$value" "${MAT_MODE[@]}" "${MAT_TYPE[@]}")
      matugen -c "$TMP_CFG" color hex "$value" "${MAT_MODE[@]}" "${MAT_TYPE[@]}" >/dev/null
      ;;
    *)
      echo "unknown kind: $kind" >&2; popd >/dev/null; return 2;;
  esac
  
  TMP_CONTENT_CFG="$(mktemp)"
  echo "[config]" > "$TMP_CONTENT_CFG"
  echo "" >> "$TMP_CONTENT_CFG"

  TERMINAL_MODE="$mode"
  if [[ "$TERMINALS_ALWAYS_DARK" == "true" ]]; then
    TERMINAL_MODE="dark"
  fi

  if command -v ghostty >/dev/null 2>&1; then
    sed "s|'SHELL_DIR/|'$SHELL_DIR/|g" "$SHELL_DIR/matugen/configs/ghostty.toml" >> "$TMP_CONTENT_CFG"
    echo "" >> "$TMP_CONTENT_CFG"
  fi

  if command -v kitty >/dev/null 2>&1; then
    sed "s|'SHELL_DIR/|'$SHELL_DIR/|g" "$SHELL_DIR/matugen/configs/kitty.toml" >> "$TMP_CONTENT_CFG"
    echo "" >> "$TMP_CONTENT_CFG"
  fi

  if command -v foot >/dev/null 2>&1; then
    sed "s|'SHELL_DIR/|'$SHELL_DIR/|g" "$SHELL_DIR/matugen/configs/foot.toml" >> "$TMP_CONTENT_CFG"
    echo "" >> "$TMP_CONTENT_CFG"
  fi

  if command -v alacritty >/dev/null 2>&1; then
    sed "s|'SHELL_DIR/|'$SHELL_DIR/|g" "$SHELL_DIR/matugen/configs/alacritty.toml" >> "$TMP_CONTENT_CFG"
    echo "" >> "$TMP_CONTENT_CFG"
  fi

  if command -v wezterm >/dev/null 2>&1; then
    sed "s|'SHELL_DIR/|'$SHELL_DIR/|g" "$SHELL_DIR/matugen/configs/wezterm.toml" >>"$TMP_CONTENT_CFG"
    echo "" >>"$TMP_CONTENT_CFG"
  fi

  if command -v dgop >/dev/null 2>&1; then
    sed "s|'SHELL_DIR/|'$SHELL_DIR/|g" "$SHELL_DIR/matugen/configs/dgop.toml" >> "$TMP_CONTENT_CFG"
    echo "" >> "$TMP_CONTENT_CFG"
  fi

  if command -v code >/dev/null 2>&1; then
    sed "s|'SHELL_DIR/|'$SHELL_DIR/|g" "$SHELL_DIR/matugen/configs/vscode.toml" >> "$TMP_CONTENT_CFG"
    echo "" >> "$TMP_CONTENT_CFG"
  fi

  if command -v codium >/dev/null 2>&1; then
    sed "s|'SHELL_DIR/|'$SHELL_DIR/|g" "$SHELL_DIR/matugen/configs/codium.toml" >> "$TMP_CONTENT_CFG"
    echo "" >> "$TMP_CONTENT_CFG"
  fi

  if [[ -s "$TMP_CONTENT_CFG" ]] && grep -q '\[templates\.' "$TMP_CONTENT_CFG"; then
    MAT_TERMINAL_MODE=(-m "$TERMINAL_MODE")
    case "$kind" in
      image)
        matugen -c "$TMP_CONTENT_CFG" image "$value" "${MAT_TERMINAL_MODE[@]}" "${MAT_TYPE[@]}" >/dev/null
        ;;
      hex)
        matugen -c "$TMP_CONTENT_CFG" color hex "$value" "${MAT_TERMINAL_MODE[@]}" "${MAT_TYPE[@]}" >/dev/null
        ;;
    esac
  fi

  rm -f "$TMP_CONTENT_CFG"
  popd >/dev/null

  echo "$JSON" | grep -q '"primary"' || { echo "matugen JSON missing primary" >&2; set_system_color_scheme "$mode"; return 2; }
  printf "%s" "$JSON" > "$LAST_JSON"

  GTK_CSS="$CONFIG_DIR/gtk-3.0/gtk.css"
  SHOULD_RUN_HOOK=false

  if [[ -L "$GTK_CSS" ]]; then
    LINK_TARGET=$(readlink "$GTK_CSS")
    if [[ "$LINK_TARGET" == *"dank-colors.css"* ]]; then
      SHOULD_RUN_HOOK=true
    fi
  elif [[ -f "$GTK_CSS" ]] && grep -q "dank-colors.css" "$GTK_CSS"; then
    SHOULD_RUN_HOOK=true
  fi

  if [[ "$SHOULD_RUN_HOOK" == "true" ]]; then
    gsettings set org.gnome.desktop.interface gtk-theme "" >/dev/null 2>&1 || true
    gsettings set org.gnome.desktop.interface gtk-theme "adw-gtk3-${mode}" >/dev/null 2>&1 || true
  fi

  if [[ "$MATUGEN_VERSION" == "2" ]]; then
    PRIMARY=$(echo "$JSON" | sed -n "s/.*\"$mode\":{[^}]*\"primary\":\"\\(#[0-9a-fA-F]\\{6\\}\\)\".*/\\1/p")
    SURFACE=$(echo "$JSON" | sed -n "s/.*\"$mode\":{[^}]*\"surface\":\"\\(#[0-9a-fA-F]\\{6\\}\\)\".*/\\1/p")
  else
    JSON_FLAT=$(echo "$JSON" | tr -d '\n')
    PRIMARY=$(echo "$JSON_FLAT" | sed -n "s/.*\"primary\" *: *{ *[^}]*\"$mode\" *: *\"\\(#[0-9a-fA-F]\\{6\\}\\)\".*/\\1/p")
    SURFACE=$(echo "$JSON_FLAT" | sed -n "s/.*\"surface\" *: *{ *[^}]*\"$mode\" *: *\"\\(#[0-9a-fA-F]\\{6\\}\\)\".*/\\1/p")
  fi

  if [[ -z "$PRIMARY" ]]; then
    echo "Error: Failed to extract PRIMARY color from matugen JSON (mode: $mode)" >&2
    echo "This may indicate an incompatible matugen JSON format" >&2
    set_system_color_scheme "$mode"
    return 2
  fi

  TERMINAL_LIGHT_FLAG=""
  if [[ "$TERMINALS_ALWAYS_DARK" != "true" ]] && [[ "$mode" == "light" ]]; then
    TERMINAL_LIGHT_FLAG="--light"
  fi

  if command -v ghostty >/dev/null 2>&1 && [[ -f "$CONFIG_DIR/ghostty/config-dankcolors" ]]; then
    OUT=$(dms dank16 "$PRIMARY" $TERMINAL_LIGHT_FLAG ${SURFACE:+--background "$SURFACE"} --ghostty 2>/dev/null || true)
    if [[ -n "${OUT:-}" ]]; then
      printf "\n%s\n" "$OUT" >> "$CONFIG_DIR/ghostty/config-dankcolors"
      if [[ -f "$CONFIG_DIR/ghostty/config" ]] && grep -q "^[^#]*config-dankcolors" "$CONFIG_DIR/ghostty/config" 2>/dev/null; then
        pkill -USR2 -x 'ghostty|.ghostty-wrappe' >/dev/null 2>&1 || true
      fi
    fi
  fi

  if command -v kitty >/dev/null 2>&1 && [[ -f "$CONFIG_DIR/kitty/dank-theme.conf" ]]; then
    OUT=$(dms dank16 "$PRIMARY" $TERMINAL_LIGHT_FLAG ${SURFACE:+--background "$SURFACE"} --kitty 2>/dev/null || true)
    if [[ -n "${OUT:-}" ]]; then
      printf "\n%s\n" "$OUT" >> "$CONFIG_DIR/kitty/dank-theme.conf"
      if [[ -f "$CONFIG_DIR/kitty/kitty.conf" ]] && grep -q "^[^#]*dank-theme.conf" "$CONFIG_DIR/kitty/kitty.conf" 2>/dev/null; then
        pkill -USR1 -x kitty >/dev/null 2>&1 || true
      fi
    fi
  fi

  if command -v foot >/dev/null 2>&1; then
    FOOT_CONFIG="$CONFIG_DIR/foot/dank-colors.ini"

    if [[ ! -f "$FOOT_CONFIG" ]]; then
      mkdir -p "$(dirname "$FOOT_CONFIG")"
      echo "[colors]" > "$FOOT_CONFIG"
    fi

    OUT=$(dms dank16 "$PRIMARY" $TERMINAL_LIGHT_FLAG ${SURFACE:+--background "$SURFACE"} --foot 2>/dev/null || true)
    if [[ -n "${OUT:-}" ]]; then
      printf "\n%s\n" "$OUT" >> "$FOOT_CONFIG"
    fi
  fi

  if command -v wezterm >/dev/null 2>&1; then
    WEZTERM_CONFIG="$CONFIG_DIR/wezterm/colors/dank-theme.toml"

    if [[ ! -f "$WEZTERM_CONFIG" ]]; then
      mkdir -p "$(dirname "$WEZTERM_CONFIG")"
      touch "$WEZTERM_CONFIG"
    fi

    OUT=$(dms dank16 "$PRIMARY" $TERMINAL_LIGHT_FLAG ${SURFACE:+--background "$SURFACE"} --wezterm 2>/dev/null || true)
    if [[ -n "${OUT:-}" ]]; then
      printf "\n%s\n" "$OUT" >>"$WEZTERM_CONFIG"
    fi
  fi

  if command -v alacritty >/dev/null 2>&1; then
    ALACRITTY_CONFIG="$CONFIG_DIR/alacritty/dank-theme.toml"

    if [[ ! -f "$ALACRITTY_CONFIG" ]]; then
      mkdir -p "$(dirname "$ALACRITTY_CONFIG")"
      touch "$ALACRITTY_CONFIG"
    fi

    OUT=$(dms dank16 "$PRIMARY" $TERMINAL_LIGHT_FLAG ${SURFACE:+--background "$SURFACE"} --alacritty 2>/dev/null || true)
    if [[ -n "${OUT:-}" ]]; then
      printf "\n%s\n" "$OUT" >> "$ALACRITTY_CONFIG"
    fi
  fi

  if command -v code >/dev/null 2>&1; then
    VSCODE_EXT_DIR="$HOME/.vscode/extensions/local.dynamic-base16-dankshell-0.0.1"
    VSCODE_THEME_DIR="$VSCODE_EXT_DIR/themes"
    VSCODE_BASE_THEME="$VSCODE_THEME_DIR/dankshell-color-theme-base.json"
    VSCODE_FINAL_THEME="$VSCODE_THEME_DIR/dankshell-color-theme.json"

    mkdir -p "$VSCODE_THEME_DIR"

    cp "$SHELL_DIR/matugen/templates/vscode-package.json" "$VSCODE_EXT_DIR/package.json"
    cp "$SHELL_DIR/matugen/templates/vscode-vsixmanifest.xml" "$VSCODE_EXT_DIR/.vsixmanifest"

    for variant in default dark light; do
      VSCODE_BASE="$VSCODE_THEME_DIR/dankshell-${variant}-base.json"
      VSCODE_FINAL="$VSCODE_THEME_DIR/dankshell-${variant}.json"

      if [[ -f "$VSCODE_BASE" ]]; then
        VARIANT_FLAG=""
        if [[ "$variant" == "light" ]]; then
          VARIANT_FLAG="--light"
        elif [[ "$variant" == "default" && "$mode" == "light" ]]; then
          VARIANT_FLAG="--light"
        fi

        dms dank16 "$PRIMARY" $VARIANT_FLAG ${SURFACE:+--background "$SURFACE"} --vscode-enrich "$VSCODE_BASE" > "$VSCODE_FINAL" 2>/dev/null || cp "$VSCODE_BASE" "$VSCODE_FINAL"
      fi
    done
  fi

  if command -v codium >/dev/null 2>&1; then
    CODIUM_EXT_DIR="$HOME/.vscode-oss/extensions/local.dynamic-base16-dankshell-0.0.1"
    CODIUM_THEME_DIR="$CODIUM_EXT_DIR/themes"
    CODIUM_BASE_THEME="$CODIUM_THEME_DIR/dankshell-color-theme-base.json"
    CODIUM_FINAL_THEME="$CODIUM_THEME_DIR/dankshell-color-theme.json"
    CODIUM_EXTENSIONS_JSON="$HOME/.vscode-oss/extensions/extensions.json"

    mkdir -p "$CODIUM_THEME_DIR"

    cp "$SHELL_DIR/matugen/templates/vscode-package.json" "$CODIUM_EXT_DIR/package.json"
    cp "$SHELL_DIR/matugen/templates/vscode-vsixmanifest.xml" "$CODIUM_EXT_DIR/.vsixmanifest"

    if [[ -f "$CODIUM_EXTENSIONS_JSON" ]]; then
      if ! grep -q "local.dynamic-base16-dankshell" "$CODIUM_EXTENSIONS_JSON" 2>/dev/null; then
        cp "$CODIUM_EXTENSIONS_JSON" "$CODIUM_EXTENSIONS_JSON.backup-$(date +%s)" 2>/dev/null || true

        CODIUM_ENTRY='{"identifier":{"id":"local.dynamic-base16-dankshell"},"version":"0.0.1","location":{"$mid":1,"path":"'"$CODIUM_EXT_DIR"'","scheme":"file"},"relativeLocation":"local.dynamic-base16-dankshell-0.0.1","metadata":{"id":"local.dynamic-base16-dankshell","publisherId":"local","publisherDisplayName":"local","targetPlatform":"undefined","isApplicationScoped":false,"updated":false,"isPreReleaseVersion":false,"installedTimestamp":'"$(date +%s)000"',"preRelease":false}}'

        if [[ "$(cat "$CODIUM_EXTENSIONS_JSON")" == "[]" ]]; then
          echo "[$CODIUM_ENTRY]" > "$CODIUM_EXTENSIONS_JSON"
        else
          TMP_JSON="$(mktemp)"
          sed 's/]$/,'"$CODIUM_ENTRY"']/' "$CODIUM_EXTENSIONS_JSON" > "$TMP_JSON"
          mv "$TMP_JSON" "$CODIUM_EXTENSIONS_JSON"
        fi
      fi
    fi

    for variant in default dark light; do
      CODIUM_BASE="$CODIUM_THEME_DIR/dankshell-${variant}-base.json"
      CODIUM_FINAL="$CODIUM_THEME_DIR/dankshell-${variant}.json"

      if [[ -f "$CODIUM_BASE" ]]; then
        VARIANT_FLAG=""
        if [[ "$variant" == "light" ]]; then
          VARIANT_FLAG="--light"
        elif [[ "$variant" == "default" && "$mode" == "light" ]]; then
          VARIANT_FLAG="--light"
        fi

        dms dank16 "$PRIMARY" $VARIANT_FLAG ${SURFACE:+--background "$SURFACE"} --vscode-enrich "$CODIUM_BASE" > "$CODIUM_FINAL" 2>/dev/null || cp "$CODIUM_BASE" "$CODIUM_FINAL"
      fi
    done
  fi

  set_system_color_scheme "$mode"
}

while :; do
  DESIRED="$(read_desired)"
  WANT_KEY="$(key_of "$DESIRED")"
  HAVE_KEY=""
  [[ -f "$BUILT_KEY" ]] && HAVE_KEY="$(cat "$BUILT_KEY" 2>/dev/null || true)"

  if [[ "$WANT_KEY" == "$HAVE_KEY" ]]; then
    exit 0
  fi

  if build_once "$DESIRED"; then
    echo "$WANT_KEY" > "$BUILT_KEY"
  else
    exit 2
  fi
done

exit 0
