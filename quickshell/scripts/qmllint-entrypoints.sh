#!/usr/bin/env bash
set -euo pipefail

script_dir="$(
    CDPATH=''
    cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd
)"
repo_root="$(
    CDPATH=''
    cd -- "${script_dir}/../.." && pwd
)"
quickshell_dir="${repo_root}/quickshell"
qmllint_bin="${QMLLINT:-qmllint}"
qmlls_config="${quickshell_dir}/.qmlls.ini"

if ! command -v -- "${qmllint_bin}" >/dev/null 2>&1; then
    printf 'error: qmllint not found in PATH (override with QMLLINT=/path/to/qmllint)\n' >&2
    exit 127
fi

trim_ini_value() {
    local value="$1"
    value="${value#\"}"
    value="${value%\"}"
    printf '%s\n' "${value}"
}

read_ini_value() {
    local key="$1"
    local file="$2"
    local raw

    raw="$(sed -n "s/^${key}=//p" "${file}" | head -n 1)"
    if [[ -z "${raw}" ]]; then
        return 1
    fi

    trim_ini_value "${raw}"
}

print_vfs_recovery() {
    printf 'Generate it by starting the local shell config once, for example:\n' >&2
    printf '  dms -c %q run\n' "${quickshell_dir}" >&2
    printf '  qs -p %q\n' "${quickshell_dir}" >&2
}

if [[ ! -e "${qmlls_config}" ]]; then
    printf 'error: %s is missing. lint-qml requires the Quickshell tooling VFS.\n' "${qmlls_config}" >&2
    print_vfs_recovery
    exit 1
fi

if ! build_dir="$(read_ini_value "buildDir" "${qmlls_config}")"; then
    printf 'error: %s does not contain a buildDir entry.\n' "${qmlls_config}" >&2
    print_vfs_recovery
    exit 1
fi

if ! import_paths_raw="$(read_ini_value "importPaths" "${qmlls_config}")"; then
    printf 'error: %s does not contain an importPaths entry.\n' "${qmlls_config}" >&2
    print_vfs_recovery
    exit 1
fi

if [[ ! -d "${build_dir}" || ! -f "${build_dir}/qs/qmldir" ]]; then
    printf 'error: Quickshell tooling VFS is missing or stale: %s\n' "${build_dir}" >&2
    print_vfs_recovery
    exit 1
fi

targets=(
    "${quickshell_dir}/shell.qml"
    "${quickshell_dir}/DMSShell.qml"
    "${quickshell_dir}/DMSGreeter.qml"
)

qmllint_args=(
    --ignore-settings
    -W 0
    -I "${build_dir}"
)

IFS=':' read -r -a import_paths <<< "${import_paths_raw}"
for path in "${import_paths[@]}"; do
    if [[ -n "${path}" ]]; then
        qmllint_args+=(-I "${path}")
    fi
done

if ! output="$("${qmllint_bin}" "${qmllint_args[@]}" "${targets[@]}" 2>&1)"; then
    printf '%s\n' "${output}" >&2
    exit 1
fi

if [[ -n "${output}" ]]; then
    printf '%s\n' "${output}"
fi
