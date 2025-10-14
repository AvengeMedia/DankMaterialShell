#!/usr/bin/env bash
# matugen-worker - Process matugen color scheme requests
#
# Reads desired color scheme from STATE_DIR/matugen.desired.json and executes
# walset with appropriate arguments. Supports both image and hex color inputs
# with optional mode (dark/light) and scheme selection.
#
# Arguments:
#   $1 - STATE_DIR: Directory containing matugen.desired.json
#   $2 - SHELL_DIR: Shell configuration directory (unused)
#   $3 - CONFIG_DIR: Configuration directory (unused)
#   $4 - Must be "--run" (safety flag)
# Exit codes:
#   0 (success), 1 (failure), 2 (invalid config), 127 (command not found)

set -euo pipefail

shopt -s nullglob globstar

die() {
  local exit_code=1
  local msg

  if [[ "${1:-}" =~ ^[0-9]+$ ]]; then
    exit_code="$1"
    shift
  fi

  msg="$*"

  if command -v notify-send >/dev/null 2>&1; then
    notify-send "matugen-worker" "$msg" -i error -u critical
  fi

  printf 'matugen-worker: %s\n' "$msg" >&2
  exit "$exit_code"
}

validate_arguments() {
  if [[ $# -lt 4 ]]; then
    die 1 "Usage: $0 STATE_DIR SHELL_DIR CONFIG_DIR --run"
  fi

  readonly STATE_DIR="$1"
  readonly SHELL_DIR="$2"
  readonly CONFIG_DIR="$3"

  if [[ ! -d "$STATE_DIR" ]]; then
    die 1 "STATE_DIR '$STATE_DIR' does not exist"
  fi

  if [[ ! -d "$SHELL_DIR" ]]; then
    die 1 "SHELL_DIR '$SHELL_DIR' does not exist"
  fi

  if [[ ! -d "$CONFIG_DIR" ]]; then
    die 1 "CONFIG_DIR '$CONFIG_DIR' does not exist"
  fi

  shift 3

  if [[ "${1:-}" != "--run" ]]; then
    die 1 "Fourth argument must be '--run'"
  fi
}

read_config() {
  local desired_json="$STATE_DIR/matugen.desired.json"

  if [[ ! -f "$desired_json" ]]; then
    exit 2
  fi

  local mode kind value scheme
  read -r mode kind value scheme < <(
    jq -r '[.mode // empty, .kind // empty, .value // empty, .matugenType // empty] | @tsv' "$desired_json"
  )

  if [[ -z "$kind" || -z "$value" ]]; then
    exit 2
  fi

  if [[ "$kind" != "image" && "$kind" != "hex" ]]; then
    exit 2
  fi

  if [[ -n "$mode" && "$mode" != "dark" && "$mode" != "light" ]]; then
    exit 2
  fi

  printf '%s\n%s\n%s\n%s\n' "$mode" "$kind" "$value" "$scheme"
}

build_walset_args() {
  local mode="$1"
  local kind="$2"
  local value="$3"
  local scheme="$4"
  local -a args=()

  case "$kind" in
  image)
    if [[ ! -r "$value" ]]; then
      exit 2
    fi
    args=("image" "$value")
    ;;
  hex)
    args=("color" "$value")
    ;;
  *)
    exit 2
    ;;
  esac

  if [[ -n "$scheme" ]]; then
    args+=("--scheme" "$scheme")
  fi

  if [[ "$mode" == "dark" || "$mode" == "light" ]]; then
    args+=("--mode" "$mode")
  fi

  printf '%s\0' "${args[@]}"
}

main() {
  validate_arguments "$@"

  if ! command -v walset >/dev/null 2>&1; then
    die 127 "walset not found. Ensure ~/.local/bin is in PATH"
  fi

  local mode kind value scheme
  {
    read -r mode
    read -r kind
    read -r value
    read -r scheme
  } < <(read_config)

  local -a args=()
  while read -rd '' arg; do
    args+=("$arg")
  done < <(build_walset_args "$mode" "$kind" "$value" "$scheme")

  exec walset "${args[@]}"
}

main "$@"
