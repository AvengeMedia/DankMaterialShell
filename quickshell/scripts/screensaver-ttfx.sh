#!/usr/bin/env bash
# Omarchy-compatible terminal screensaver integration for DMS.
# Adapted from omacom/omarchy's MIT-licensed omarchy-screensaver.
# Copyright (c) David Heinemeier Hansson.

set -u

action="${1:-}"
requested_terminal="${2:-${TERMINAL:-}}"
script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
runtime_base="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}/dms-screensaver"
pid_file="$runtime_base/terminal.pids"
legacy_pid_file="$runtime_base/ghostty.pids"
runner_pid_file="$runtime_base/runner.pids"
stopping_file="$runtime_base/stopping"
content_file="$runtime_base/content.txt"
screensaver_class="com.danklinux.dms.screensaver"
font_size=18
terminal_bin=""
terminal_name=""

resolve_terminal() {
  local candidate="${requested_terminal%%[[:space:]]*}"
  local fallback

  if [[ -n $candidate ]] && command -v "$candidate" >/dev/null 2>&1; then
    terminal_bin="$(command -v "$candidate")"
    terminal_name="$(basename "$candidate")"
    return
  fi

  for fallback in xdg-terminal-exec x-terminal-emulator ghostty kitty foot footclient alacritty wezterm konsole gnome-terminal kgx xterm; do
    if command -v "$fallback" >/dev/null 2>&1; then
      terminal_bin="$(command -v "$fallback")"
      terminal_name="$fallback"
      return
    fi
  done
}

finish_shell() {
  local dms_bin
  if [[ ! -e $stopping_file ]] && dms_bin="$(command -v dms 2>/dev/null)"; then
    "$dms_bin" ipc call screensaver stop >/dev/null 2>&1 || true
  fi
}

request_shell_stop() {
  local dms_bin
  if dms_bin="$(command -v dms 2>/dev/null)"; then
    "$dms_bin" ipc call screensaver stop >/dev/null 2>&1 || true
  fi
}

run_effects() {
  local input_file="$1" child_pid=""
  printf '%s\n' "$$" >>"$runner_pid_file"
  trap '[[ -n $child_pid ]] && kill "$child_pid" 2>/dev/null || true; printf "\033[?1003l\033[?1006l"; finish_shell; exit 0' INT TERM HUP QUIT EXIT
  printf '\033]11;rgb:00/00/00\007'
  printf '\033[?1003h\033[?1006h'

  while true; do
    ttfx -i "$input_file" \
      --frame-rate 60 --canvas-width 0 --canvas-height 0 --reuse-canvas \
      --anchor-canvas c --anchor-text c --random-effect --no-eol --no-restore-cursor &
    child_pid=$!

    while kill -0 "$child_pid" 2>/dev/null; do
      if read -r -n 1 -t 0.2; then
        exit 0
      fi
    done
    wait "$child_pid" 2>/dev/null || true
    child_pid=""
  done
}

is_screensaver_pid() {
  local pid="$1" command_line=""
  [[ -r /proc/$pid/cmdline ]] || return 1
  command_line="$(tr '\0' ' ' <"/proc/$pid/cmdline")"
  [[ $command_line == *"$screensaver_class"* || $command_line == *"$script_dir/screensaver-ttfx.sh"* ]]
}

stop_screensaver() {
  local pid attempt alive
  local -a pids=()
  mkdir -p "$runtime_base"
  : >"$stopping_file"
  for tracked_file in "$runner_pid_file" "$pid_file" "$legacy_pid_file"; do
    if [[ -f $tracked_file ]]; then
      while IFS= read -r pid; do
        if [[ $pid =~ ^[0-9]+$ ]] && is_screensaver_pid "$pid"; then
          pids+=("$pid")
          kill "$pid" 2>/dev/null || true
        fi
      done <"$tracked_file"
    fi
  done
  for attempt in {1..20}; do
    alive=false
    for pid in "${pids[@]}"; do
      if kill -0 "$pid" 2>/dev/null; then
        alive=true
        break
      fi
    done
    [[ $alive == false ]] && break
    sleep 0.05
  done
  rm -f "$pid_file" "$legacy_pid_file" "$runner_pid_file" "$content_file" "$runtime_base/generation" "$runtime_base/fullscreen-debug.log"
}

prepare_content() {
  local config_home="${XDG_CONFIG_HOME:-$HOME/.config}"
  local settings="$config_home/DankMaterialShell/settings.json"
  local content_type="text" text="DankMaterialShell" longest_line=0

  if [[ -f $settings ]]; then
    content_type="$(jq -r '.screensaverType // "text"' "$settings")"
    text="$(jq -r '.screensaverText // "DankMaterialShell"' "$settings")"
  fi
  [[ -n $text ]] || text="DankMaterialShell"

  case "$content_type" in
  ascii)
    printf '%s\n' "$text" >"$content_file"
    ;;
  text | *)
    python3 "$script_dir/screensaver-text-banner.py" "$text" >"$content_file"
    while IFS= read -r line; do
      ((${#line} > longest_line)) && longest_line=${#line}
    done <<<"$text"
    if ((longest_line <= 10)); then
      font_size=24
    elif ((longest_line <= 18)); then
      font_size=20
    elif ((longest_line <= 26)); then
      font_size=16
    else
      font_size=14
    fi
    ;;
  esac
}

window_count() {
  hyprctl clients -j 2>/dev/null | jq --arg class "$screensaver_class" '[.[] | select(.class == $class)] | length' 2>/dev/null || printf '0\n'
}

launch_window() {
  local before after attempt terminal_pid
  local -a runner=(bash "$script_dir/screensaver-ttfx.sh" run "$content_file")
  before="$(window_count)"

  case "$terminal_name" in
  ghostty)
    "$terminal_bin" --class="$screensaver_class" --fullscreen=true \
      --font-size="$font_size" --background=000000 --window-decoration=false \
      --window-padding-x=0 --window-padding-y=0 \
      --window-padding-color=extend-always --confirm-close-surface=false \
      -e "${runner[@]}" &
    ;;
  kitty)
    "$terminal_bin" --class "$screensaver_class" --start-as fullscreen \
      --override "font_size=$font_size" --override "background=#000000" \
      "${runner[@]}" &
    ;;
  foot | footclient)
    "$terminal_bin" --app-id="$screensaver_class" --fullscreen \
      --font="monospace:size=$font_size" "${runner[@]}" &
    ;;
  alacritty)
    "$terminal_bin" --class "$screensaver_class,$screensaver_class" \
      --option window.startup_mode=Fullscreen --option "font.size=$font_size" \
      -e "${runner[@]}" &
    ;;
  wezterm)
    "$terminal_bin" --config "font_size=$font_size" start --always-new-process \
      --class "$screensaver_class" -- "${runner[@]}" &
    ;;
  konsole)
    "$terminal_bin" --fullscreen --name "$screensaver_class" -e "${runner[@]}" &
    ;;
  gnome-terminal)
    "$terminal_bin" --full-screen --class="$screensaver_class" -- "${runner[@]}" &
    ;;
  xterm)
    "$terminal_bin" -fullscreen -class "$screensaver_class" -fa monospace \
      -fs "$font_size" -bg black -e "${runner[@]}" &
    ;;
  xdg-terminal-exec | kgx)
    "$terminal_bin" -- "${runner[@]}" &
    ;;
  *)
    "$terminal_bin" -e "${runner[@]}" &
    ;;
  esac

  terminal_pid=$!
  printf '%s\n' "$terminal_pid" >>"$pid_file"

  for attempt in {1..50}; do
    after="$(window_count)"
    ((after > before)) && break
    sleep 0.05
  done
}

start_screensaver() {
  local focused_monitor="" monitor="" monitors_json=""
  for dependency in ttfx jq python3; do
    command -v "$dependency" >/dev/null 2>&1 || {
      printf 'DMS screensaver: missing dependency: %s\n' "$dependency" >&2
      request_shell_stop
      return 1
    }
  done

  resolve_terminal
  if [[ -z $terminal_bin ]]; then
    printf 'DMS screensaver: no terminal emulator found\n' >&2
    request_shell_stop
    return 1
  fi

  stop_screensaver
  rm -f "$stopping_file"
  prepare_content || {
    printf 'DMS screensaver: could not prepare content\n' >&2
    finish_shell
    return 1
  }
  : >"$pid_file"
  : >"$runner_pid_file"

  if monitors_json="$(hyprctl monitors -j 2>/dev/null)" && jq -e 'type == "array"' >/dev/null 2>&1 <<<"$monitors_json"; then
    focused_monitor="$(jq -r '.[] | select(.focused).name' <<<"$monitors_json" | head -n 1)"
    while IFS= read -r monitor; do
      [[ -n $monitor ]] || continue
      hyprctl dispatch focusmonitor "$monitor" >/dev/null 2>&1 || true
      launch_window
    done < <(jq -r '.[].name' <<<"$monitors_json")
    [[ -n $focused_monitor ]] && hyprctl dispatch focusmonitor "$focused_monitor" >/dev/null 2>&1 || true
  else
    launch_window
  fi
}

case "$action" in
start)
  start_screensaver
  ;;
stop)
  stop_screensaver
  ;;
run)
  run_effects "${2:?missing content file}"
  ;;
*)
  printf 'usage: %s {start|stop|run <content-file>}\n' "$0" >&2
  exit 2
  ;;
esac
