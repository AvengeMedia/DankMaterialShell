#!/usr/bin/env bash
set -uo pipefail

log() { echo "[matugen-worker] $*" >&2; }
err() { echo "[matugen-worker] ERROR: $*" >&2; }

[[ $# -lt 6 ]] && { echo "Usage: $0 STATE_DIR SHELL_DIR CONFIG_DIR SYNC_MODE_WITH_PORTAL TERMINALS_ALWAYS_DARK --run" >&2; exit 1; }

STATE_DIR="$1"
SHELL_DIR="$2"
CONFIG_DIR="$3"
SYNC_MODE_WITH_PORTAL="$4"
TERMINALS_ALWAYS_DARK="$5"
shift 5
[[ "${1:-}" != "--run" ]] && { echo "Usage: $0 ... --run" >&2; exit 1; }

[[ ! -d "$STATE_DIR" ]] && { err "STATE_DIR '$STATE_DIR' does not exist"; exit 1; }
[[ ! -d "$SHELL_DIR" ]] && { err "SHELL_DIR '$SHELL_DIR' does not exist"; exit 1; }
[[ ! -d "$CONFIG_DIR" ]] && { err "CONFIG_DIR '$CONFIG_DIR' does not exist"; exit 1; }

DESIRED_JSON="$STATE_DIR/matugen.desired.json"
BUILT_KEY="$STATE_DIR/matugen.key"
LOCK="$STATE_DIR/matugen-worker.lock"
COLORS_OUTPUT="$STATE_DIR/dms-colors.json"

exec 9>"$LOCK"
flock 9
rm -f "$BUILT_KEY"

read_json_field() {
  local json="$1" field="$2"
  echo "$json" | sed -n "s/.*\"$field\"[[:space:]]*:[[:space:]]*\"\([^\"]*\)\".*/\1/p" | head -1
}

read_json_escaped_field() {
  local json="$1" field="$2"
  local after="${json#*\"$field\":\"}"
  [[ "$after" == "$json" ]] && return
  local result=""
  while [[ -n "$after" ]]; do
    local char="${after:0:1}"
    after="${after:1}"
    [[ "$char" == '"' ]] && break
    [[ "$char" == '\' ]] && { result+="${after:0:1}"; after="${after:1}"; continue; }
    result+="$char"
  done
  echo "$result"
}

read_json_bool() {
  local json="$1" field="$2"
  echo "$json" | sed -n "s/.*\"$field\"[[:space:]]*:[[:space:]]*\([^,}]*\).*/\1/p" | head -1 | tr -d ' '
}

compute_key() {
  local json="$1"
  local kind=$(read_json_field "$json" "kind")
  local value=$(read_json_field "$json" "value")
  local mode=$(read_json_field "$json" "mode")
  local icon=$(read_json_field "$json" "iconTheme")
  local mtype=$(read_json_field "$json" "matugenType")
  local run_user=$(read_json_bool "$json" "runUserTemplates")
  local stock_colors=$(read_json_escaped_field "$json" "stockColors")
  echo "${kind}|${value}|${mode}|${icon:-default}|${mtype:-scheme-tonal-spot}|${run_user:-true}|${stock_colors:-}" | sha256sum | cut -d' ' -f1
}

append_config() {
  local check_cmd="$1" file_name="$2" cfg_file="$3"
  local target="$SHELL_DIR/matugen/configs/$file_name"
  [[ ! -f "$target" ]] && return
  [[ "$check_cmd" != "skip" ]] && ! command -v "$check_cmd" >/dev/null 2>&1 && return
  sed "s|'SHELL_DIR/|'$SHELL_DIR/|g" "$target" >> "$cfg_file"
  echo "" >> "$cfg_file"
}

append_vscode_config() {
  local name="$1" ext_dir="$2" cfg_file="$3"
  [[ ! -d "$ext_dir" ]] && return
  local template_dir="$SHELL_DIR/matugen/templates"
  cat >> "$cfg_file" << EOF
[templates.dms${name}default]
input_path = '$template_dir/vscode-color-theme-default.json'
output_path = '$ext_dir/themes/dankshell-default.json'

[templates.dms${name}dark]
input_path = '$template_dir/vscode-color-theme-dark.json'
output_path = '$ext_dir/themes/dankshell-dark.json'

[templates.dms${name}light]
input_path = '$template_dir/vscode-color-theme-light.json'
output_path = '$ext_dir/themes/dankshell-light.json'

EOF
  log "Added $name theme config (extension found at $ext_dir)"
}

build_merged_config() {
  local mode="$1" run_user="$2" cfg_file="$3"

  if [[ "$run_user" == "true" && -f "$CONFIG_DIR/matugen/config.toml" ]]; then
    awk '/^\[config\]/{p=1} /^\[templates\]/{p=0} p' "$CONFIG_DIR/matugen/config.toml" >> "$cfg_file"
  else
    echo "[config]" >> "$cfg_file"
  fi
  echo "" >> "$cfg_file"

  grep -v '^\[config\]' "$SHELL_DIR/matugen/configs/base.toml" | sed "s|'SHELL_DIR/|'$SHELL_DIR/|g" >> "$cfg_file"
  echo "" >> "$cfg_file"

  cat >> "$cfg_file" << EOF
[templates.dank]
input_path = '$SHELL_DIR/matugen/templates/dank.json'
output_path = '$COLORS_OUTPUT'

EOF

  [[ "$mode" == "light" ]] && append_config "skip" "gtk3-light.toml" "$cfg_file" || append_config "skip" "gtk3-dark.toml" "$cfg_file"

  append_config "niri" "niri.toml" "$cfg_file"
  append_config "qt5ct" "qt5ct.toml" "$cfg_file"
  append_config "qt6ct" "qt6ct.toml" "$cfg_file"
  append_config "firefox" "firefox.toml" "$cfg_file"
  append_config "pywalfox" "pywalfox.toml" "$cfg_file"
  append_config "vesktop" "vesktop.toml" "$cfg_file"
  append_config "ghostty" "ghostty.toml" "$cfg_file"
  append_config "kitty" "kitty.toml" "$cfg_file"
  append_config "foot" "foot.toml" "$cfg_file"
  append_config "alacritty" "alacritty.toml" "$cfg_file"
  append_config "wezterm" "wezterm.toml" "$cfg_file"
  append_config "dgop" "dgop.toml" "$cfg_file"

  append_vscode_config "vscode" "$HOME/.vscode/extensions/local.dynamic-base16-dankshell-0.0.1" "$cfg_file"
  append_vscode_config "codium" "$HOME/.vscode-oss/extensions/local.dynamic-base16-dankshell-0.0.1" "$cfg_file"
  append_vscode_config "codeoss" "$HOME/.config/Code - OSS/extensions/local.dynamic-base16-dankshell-0.0.1" "$cfg_file"
  append_vscode_config "cursor" "$HOME/.cursor/extensions/local.dynamic-base16-dankshell-0.0.1" "$cfg_file"
  append_vscode_config "windsurf" "$HOME/.windsurf/extensions/local.dynamic-base16-dankshell-0.0.1" "$cfg_file"

  if [[ "$run_user" == "true" && -f "$CONFIG_DIR/matugen/config.toml" ]]; then
    awk '/^\[templates\]/{p=1} p' "$CONFIG_DIR/matugen/config.toml" >> "$cfg_file"
    echo "" >> "$cfg_file"
  fi

  if [[ -d "$CONFIG_DIR/matugen/dms/configs" ]]; then
    for config in "$CONFIG_DIR/matugen/dms/configs"/*.toml; do
      [[ -f "$config" ]] || continue
      cat "$config" >> "$cfg_file"
      echo "" >> "$cfg_file"
    done
  fi
}

generate_dank16() {
  local primary="$1" surface="$2" light_flag="$3"
  local args=("$primary" --json)
  [[ -n "$light_flag" ]] && args+=("$light_flag")
  [[ -n "$surface" ]] && args+=(--background "$surface")
  dms dank16 "${args[@]}" 2>/dev/null || echo '{}'
}

set_system_color_scheme() {
  [[ "$SYNC_MODE_WITH_PORTAL" != "true" ]] && return
  local mode="$1"
  local scheme="prefer-dark"
  [[ "$mode" == "light" ]] && scheme="default"
  gsettings set org.gnome.desktop.interface color-scheme "$scheme" 2>/dev/null || \
    dconf write /org/gnome/desktop/interface/color-scheme "'$scheme'" 2>/dev/null || true
}

sync_color_scheme_on_exit() {
  [[ "$SYNC_MODE_WITH_PORTAL" != "true" ]] && return
  [[ ! -f "$DESIRED_JSON" ]] && return
  local json mode
  json=$(cat "$DESIRED_JSON" 2>/dev/null) || return
  mode=$(read_json_field "$json" "mode")
  [[ -n "$mode" ]] && set_system_color_scheme "$mode"
}

trap sync_color_scheme_on_exit EXIT

refresh_gtk() {
  local mode="$1"
  local gtk_css="$CONFIG_DIR/gtk-3.0/gtk.css"
  [[ ! -e "$gtk_css" ]] && return
  local should_run=false
  if [[ -L "$gtk_css" ]]; then
    [[ "$(readlink "$gtk_css")" == *"dank-colors.css"* ]] && should_run=true
  elif grep -q "dank-colors.css" "$gtk_css" 2>/dev/null; then
    should_run=true
  fi
  [[ "$should_run" != "true" ]] && return
  gsettings set org.gnome.desktop.interface gtk-theme "" 2>/dev/null || true
  gsettings set org.gnome.desktop.interface gtk-theme "adw-gtk3-${mode}" 2>/dev/null || true
}

signal_terminals() {
  pgrep -x kitty >/dev/null 2>&1 && pkill -USR1 kitty
  pgrep -x ghostty >/dev/null 2>&1 && pkill -USR2 ghostty
  pgrep -x .kitty-wrapped >/dev/null 2>&1 && pkill -USR2 .kitty-wrapped
  pgrep -x .ghostty-wrappe >/dev/null 2>&1 && pkill -USR2 .ghostty-wrappe
}

build_once() {
  local json="$1"
  local kind=$(read_json_field "$json" "kind")
  local value=$(read_json_field "$json" "value")
  local mode=$(read_json_field "$json" "mode")
  local mtype=$(read_json_field "$json" "matugenType")
  local run_user=$(read_json_bool "$json" "runUserTemplates")
  local stock_colors=$(read_json_escaped_field "$json" "stockColors")

  [[ -z "$mtype" ]] && mtype="scheme-tonal-spot"
  [[ -z "$run_user" ]] && run_user="true"

  local TMP_CFG=$(mktemp)
  trap "rm -f '$TMP_CFG'" RETURN

  build_merged_config "$mode" "$run_user" "$TMP_CFG"

  local light_flag=""
  [[ "$mode" == "light" ]] && light_flag="--light"

  local primary surface dank16_dark dank16_light import_args=()

  if [[ -n "$stock_colors" ]]; then
    log "Using stock/custom theme colors with matugen base"
    primary=$(echo "$stock_colors" | sed -n 's/.*"primary"[^{]*{[^}]*"dark"[^{]*{[^}]*"color"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' | head -1)
    surface=$(echo "$stock_colors" | sed -n 's/.*"surface"[^{]*{[^}]*"dark"[^{]*{[^}]*"color"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' | head -1)

    [[ -z "$primary" ]] && { err "Failed to extract primary from stock colors"; return 1; }

    dank16_dark=$(generate_dank16 "$primary" "$surface" "")
    dank16_light=$(generate_dank16 "$primary" "$surface" "--light")

    local dank16_current
    [[ "$mode" == "light" ]] && dank16_current="$dank16_light" || dank16_current="$dank16_dark"
    [[ "$TERMINALS_ALWAYS_DARK" == "true" && "$mode" == "light" ]] && dank16_current="$dank16_dark"

    import_args+=(--import-json-string "{\"colors\": $stock_colors, \"dank16\": $dank16_current}")

    log "Running matugen color hex with stock color overrides"
    if ! matugen color hex "$primary" -m "$mode" -t "${mtype:-scheme-tonal-spot}" -c "$TMP_CFG" "${import_args[@]}"; then
      err "matugen failed"
      return 1
    fi
  else
    log "Using dynamic theme from $kind: $value"

    local matugen_cmd=("matugen")
    [[ "$kind" == "hex" ]] && matugen_cmd+=("color" "hex") || matugen_cmd+=("$kind")
    matugen_cmd+=("$value")

    local mat_json
    mat_json=$("${matugen_cmd[@]}" -m dark -t "$mtype" --json hex --dry-run 2>/dev/null | tr -d '\n')
    [[ -z "$mat_json" ]] && { err "matugen dry-run failed"; return 1; }

    primary=$(echo "$mat_json" | sed -n 's/.*"primary"[[:space:]]*:[[:space:]]*{[^}]*"dark"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p')
    surface=$(echo "$mat_json" | sed -n 's/.*"surface"[[:space:]]*:[[:space:]]*{[^}]*"dark"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p')

    [[ -z "$primary" ]] && { err "Failed to extract primary color"; return 1; }

    dank16_dark=$(generate_dank16 "$primary" "$surface" "")
    dank16_light=$(generate_dank16 "$primary" "$surface" "--light")

    local dank16_current
    [[ "$mode" == "light" ]] && dank16_current="$dank16_light" || dank16_current="$dank16_dark"
    [[ "$TERMINALS_ALWAYS_DARK" == "true" && "$mode" == "light" ]] && dank16_current="$dank16_dark"

    import_args+=(--import-json-string "{\"dank16\": $dank16_current}")

    log "Running matugen $kind with dank16 injection"
    if ! "${matugen_cmd[@]}" -m "$mode" -t "$mtype" -c "$TMP_CFG" "${import_args[@]}"; then
      err "matugen failed"
      return 1
    fi
  fi

  refresh_gtk "$mode"
  signal_terminals

  return 0
}

[[ ! -f "$DESIRED_JSON" ]] && { log "No desired state file"; exit 0; }

DESIRED=$(cat "$DESIRED_JSON")
WANT_KEY=$(compute_key "$DESIRED")
HAVE_KEY=""
[[ -f "$BUILT_KEY" ]] && HAVE_KEY=$(cat "$BUILT_KEY" 2>/dev/null || true)

[[ "$WANT_KEY" == "$HAVE_KEY" ]] && { log "Already up to date"; exit 0; }

log "Building theme (key: ${WANT_KEY:0:12}...)"
if build_once "$DESIRED"; then
  echo "$WANT_KEY" > "$BUILT_KEY"
  log "Done"
  exit 0
else
  err "Build failed"
  exit 2
fi
