#!/usr/bin/env bash
# Health and integration check for the DMS chat system.
#
# Runs against the backend you are actually using, or against an isolated
# sandbox with the reference echo provider. Every check names what it asserts,
# so a failure says which part of the chain is wrong rather than only that
# something is.
#
#   ./scripts/chat-healthcheck.sh            check the running backend
#   ./scripts/chat-healthcheck.sh --sandbox  build and check an isolated one
#   ./scripts/chat-healthcheck.sh --unit     Go tests and QML lint only
#
# Read-only against your real data: it never sends a message, deletes anything,
# or changes a provider's enabled state.
set -uo pipefail

REPO="$(cd "$(dirname "$0")/.." && pwd)"
SANDBOX=0
UNIT_ONLY=0

for arg in "$@"; do
    case "$arg" in
    --sandbox) SANDBOX=1 ;;
    --unit) UNIT_ONLY=1 ;;
    -h | --help)
        sed -n '2,14p' "$0"
        exit 0
        ;;
    *)
        echo "unknown option: $arg" >&2
        exit 2
        ;;
    esac
done

PASS=0
FAIL=0
SKIP=0

green() { printf '\033[32m%s\033[0m' "$1"; }
red() { printf '\033[31m%s\033[0m' "$1"; }
yellow() { printf '\033[33m%s\033[0m' "$1"; }

ok() {
    PASS=$((PASS + 1))
    printf '  %s %s\n' "$(green PASS)" "$1"
}
bad() {
    FAIL=$((FAIL + 1))
    printf '  %s %s\n' "$(red FAIL)" "$1"
    [ $# -gt 1 ] && printf '       %s\n' "$2"
}
skip() {
    SKIP=$((SKIP + 1))
    printf '  %s %s\n' "$(yellow SKIP)" "$1"
}
section() { printf '\n== %s ==\n' "$1"; }

# ---------------------------------------------------------------- unit checks

section "Build and tests"

if (cd "$REPO/core" && go build ./... 2>/tmp/dms-chat-build.log); then
    ok "core builds"
else
    bad "core builds" "$(tail -3 /tmp/dms-chat-build.log)"
fi

if (cd "$REPO/core" && go test ./internal/chat/... ./internal/server/chat/... >/tmp/dms-chat-test.log 2>&1); then
    ok "chat tests pass"
else
    bad "chat tests pass" "$(command grep -E '^\s+--- FAIL|FAIL' /tmp/dms-chat-test.log | head -3)"
fi

QMLLINT="${QMLLINT:-$(command -v qmllint || true)}"
if [ -n "$QMLLINT" ]; then
    # Import resolution needs the Quickshell VFS; these categories do not.
    STRUCTURAL="duplicated-name|syntax|incompatible-type|read-only-property|non-list-property|required|unresolved-alias"
    lint_failures=""
    for f in "$REPO"/quickshell/Modals/Chats/*.qml "$REPO"/quickshell/Modules/Settings/Chat*.qml "$REPO"/quickshell/Services/Chat*.qml; do
        [ -e "$f" ] || continue
        if "$QMLLINT" "$f" 2>&1 | command grep -qE "\[($STRUCTURAL)\]"; then
            lint_failures="$lint_failures $(basename "$f")"
        fi
    done
    if [ -z "$lint_failures" ]; then
        ok "chat QML has no structural errors"
    else
        bad "chat QML has no structural errors" "$lint_failures"
    fi
else
    skip "qmllint not found (set QMLLINT=/path/to/qmllint)"
fi

# A NUL in a source file makes it read as binary to git and grep, and has crept
# in before.
if command grep -rlP '\x00' "$REPO/quickshell" --include='*.qml' --include='*.js' 2>/dev/null | command grep -q .; then
    bad "no NUL bytes in QML sources" "$(command grep -rlP '\x00' "$REPO/quickshell" --include='*.qml' 2>/dev/null | head -3)"
else
    ok "no NUL bytes in QML sources"
fi

if [ "$UNIT_ONLY" -eq 1 ]; then
    printf '\n%s passed, %s failed, %s skipped\n' "$PASS" "$FAIL" "$SKIP"
    exit $((FAIL > 0))
fi

# ---------------------------------------------------------------- environment

section "Environment"

for tool in wl-copy wl-paste; do
    if command -v "$tool" >/dev/null; then
        ok "$tool available (clipboard attachments)"
    else
        bad "$tool available (clipboard attachments)" "install wl-clipboard"
    fi
done

# ---------------------------------------------------------------- the backend

SOCKET=""
SANDBOX_DIR=""

start_sandbox() {
    SANDBOX_DIR="$(mktemp -d /tmp/dms-chat-check-XXXXXX)"
    local rt="/tmp/dms-chk-$$"
    mkdir -p "$rt" && chmod 700 "$rt"

    (cd "$REPO/core" && go build -o "$SANDBOX_DIR/dms" ./cmd/dms) || return 1

    local plugin="$REPO/quickshell/PLUGINS/EchoChatExample"
    local dest="$SANDBOX_DIR/config/DankMaterialShell/plugins/echoChat"
    mkdir -p "$dest/bin"
    cp "$plugin/plugin.json" "$dest/" 2>/dev/null
    (cd "$plugin/src" && go build -o "$dest/bin/echo-chat-bridge" .) || return 1

    XDG_RUNTIME_DIR="$rt" XDG_CONFIG_HOME="$SANDBOX_DIR/config" \
        XDG_DATA_HOME="$SANDBOX_DIR/data" XDG_CACHE_HOME="$SANDBOX_DIR/cache" \
        setsid "$SANDBOX_DIR/dms" debug-srv >"$SANDBOX_DIR/server.log" 2>&1 </dev/null &

    sleep 4
    SOCKET="$(ls -t "$rt"/*.sock 2>/dev/null | head -1)"
    [ -n "$SOCKET" ] || return 1

    # Enable the reference provider and wait for it to seed its conversations.
    # Without this the checks below run against an empty store and pass while
    # asserting nothing, which is worse than failing.
    python3 - "$SOCKET" <<'ENABLE'
import json, socket, sys, time
s = socket.socket(socket.AF_UNIX); s.connect(sys.argv[1])
f = s.makefile("rwb"); f.readline()
def call(i, m, p):
    f.write((json.dumps({"id": i, "method": m, "params": p}) + "\n").encode()); f.flush()
    return json.loads(f.readline())
call(1, "chat.setEnabled", {"provider": "echoChat", "enabled": True,
                            "settings": {"peerName": "Ada Lovelace"}})
for _ in range(20):
    time.sleep(0.5)
    chats = call(2, "chat.chats", {"all": True}).get("result", {}).get("chats", [])
    if chats:
        break
ENABLE
    return 0
}

stop_sandbox() {
    [ -n "$SANDBOX_DIR" ] || return 0
    for p in $(ps -eo pid,cmd | command grep "[d]ms debug-srv" | awk '{print $1}'); do
        kill "$p" 2>/dev/null
    done
}
trap stop_sandbox EXIT

section "Backend"

if [ "$SANDBOX" -eq 1 ]; then
    if start_sandbox; then
        ok "sandbox backend started with the echo provider"
    else
        bad "sandbox backend started" "see $SANDBOX_DIR/server.log"
        printf '\n%s passed, %s failed, %s skipped\n' "$PASS" "$FAIL" "$SKIP"
        exit 1
    fi
else
    SOCKET="$(ls -t "${XDG_RUNTIME_DIR:-/run/user/$(id -u)}"/danklinux-*.sock 2>/dev/null | head -1)"
    if [ -n "$SOCKET" ]; then
        ok "found a running backend"
    else
        bad "found a running backend" "start DMS, or pass --sandbox"
        printf '\n%s passed, %s failed, %s skipped\n' "$PASS" "$FAIL" "$SKIP"
        exit 1
    fi
fi

# All backend assertions run in one Python process: one connection, and the
# checks can build on each other.
python3 - "$SOCKET" <<'PY'
import json, socket, sys

sock = sys.argv[1]
s = socket.socket(socket.AF_UNIX); s.connect(sock)
f = s.makefile("rwb")
caps = json.loads(f.readline())

n = [0]
def call(method, params=None):
    n[0] += 1
    f.write((json.dumps({"id": n[0], "method": method, "params": params or {}}) + "\n").encode())
    f.flush()
    return json.loads(f.readline())

passed = failed = 0
def check(label, condition, detail=""):
    global passed, failed
    if condition:
        passed += 1
        print(f"  \033[32mPASS\033[0m {label}")
    else:
        failed += 1
        print(f"  \033[31mFAIL\033[0m {label}")
        if detail:
            print(f"       {detail}")

check("backend advertises the chat capability",
      "chat" in caps.get("capabilities", []),
      f"capabilities: {caps.get('capabilities')}")

r = call("chat.providers")
providers = r.get("result", {}).get("providers", []) if not r.get("error") else []
check("chat.providers answers", not r.get("error"), r.get("error", ""))
print(f"       {len(providers)} provider(s): " +
      ", ".join(f"{p['id']}({p['state']})" for p in providers))

enabled = [p for p in providers if p.get("enabled")]
running = [p for p in enabled if p.get("running")]
check("every enabled provider is running", len(enabled) == len(running),
      "not running: " + ", ".join(p["id"] for p in enabled if not p.get("running")))

for p in enabled:
    if p.get("lastError"):
        check(f"{p['id']} has no error", False, p["lastError"])
    if p.get("restarts", 0) > 3:
        check(f"{p['id']} is stable", False, f"{p['restarts']} restarts")

# --- reads --------------------------------------------------------------
active = call("chat.chats")
every  = call("chat.chats", {"all": True})
check("chat.chats answers", not active.get("error"), active.get("error", ""))
check("chat.chats all answers", not every.get("error"), every.get("error", ""))

n_active = len(active.get("result", {}).get("chats", []))
n_all    = len(every.get("result", {}).get("chats", []))
print(f"       {n_active} with activity, {n_all} known in total")
check("the full list is a superset of the active one", n_all >= n_active)

check("empty results are arrays, not null",
      isinstance(active.get("result", {}).get("chats"), list))

# --- tags ---------------------------------------------------------------
tags = call("chat.tags")
tag_list = tags.get("result", {}).get("tags", [])
check("chat.tags answers", not tags.get("error"), tags.get("error", ""))
check("host-derived tags are offered",
      all(t in tag_list for t in ("archived", "muted", "group", "direct")),
      f"tags: {tag_list}")

chats = every.get("result", {}).get("chats", [])
if chats:
    check("conversations carry tags", any(c.get("tags") for c in chats))

# --- resolution ---------------------------------------------------------
res = call("chat.resolve", {"query": "zzz-nothing-matches-this"})
check("resolve returns an empty list for no match",
      res.get("result", {}).get("candidates") == [],
      str(res.get("result")))

named = [c for c in chats if c.get("name")]
if named:
    target = named[0]
    by_name = call("chat.resolve", {"query": target["name"]})
    found = by_name.get("result", {}).get("candidates", [])
    check("resolve finds a conversation by name",
          any(c["chatId"] == target["id"] for c in found),
          f"looked for {target['name']!r}")

    qualified = call("chat.resolve", {"query": f"{target['provider']}:{target['id']}"})
    check("resolve accepts provider:chatId",
          len(qualified.get("result", {}).get("candidates", [])) == 1)

handled = [c for c in chats if c.get("handles")]
if handled:
    target = handled[0]
    by_handle = call("chat.resolve", {"query": target["handles"][0]})
    check("resolve finds a conversation by handle",
          any(c["chatId"] == target["id"] for c in by_handle.get("result", {}).get("candidates", [])),
          f"handle {target['handles'][0]}")
else:
    print("  \033[33mSKIP\033[0m no conversation has a handle yet")

# --- history and search -------------------------------------------------
withHistory = [c for c in chats if c.get("lastTs")]
if withHistory:
    target = withHistory[0]
    hist = call("chat.history", {"provider": target["provider"], "chatId": target["id"], "limit": 5})
    msgs = hist.get("result", {}).get("messages", [])
    check("chat.history answers", not hist.get("error"), hist.get("error", ""))
    check("history is chronological",
          all(msgs[i]["ts"] <= msgs[i + 1]["ts"] for i in range(len(msgs) - 1)),
          "messages are out of order, which is what reverses the conversation")

srch = call("chat.search", {"query": "zzz-nothing-matches-this"})
check("search returns arrays for no match",
      isinstance(srch.get("result", {}).get("messages"), list) and
      isinstance(srch.get("result", {}).get("chats"), list))

# --- config -------------------------------------------------------------
cfg = call("chat.getConfig")
check("chat.getConfig answers", not cfg.get("error"), cfg.get("error", ""))

if providers:
    pid = providers[0]["id"]
    prefs = providers[0].get("notifications", {})
    check("notification policy uses lowercase keys the UI can read",
          "enabled" in prefs and "doNotDisturb" in prefs,
          f"got: {list(prefs)}")

# --- methods exist ------------------------------------------------------
for method in ("chat.rescan", "chat.setProviderConfig", "chat.deleteLocal",
               "chat.revoke", "chat.authQrCode", "chat.setFocus"):
    r = call(method, {})
    # A missing method says so; a present one complains about its arguments.
    check(f"{method} is implemented",
          "unknown method" not in (r.get("error") or ""),
          r.get("error", ""))

print()
print(f"backend: {passed} passed, {failed} failed")
sys.exit(1 if failed else 0)
PY

BACKEND=$?
if [ $BACKEND -eq 0 ]; then
    ok "backend checks passed"
else
    bad "backend checks failed" "see above"
fi

# ---------------------------------------------------------------- store

section "Store"

DB="${XDG_DATA_HOME:-$HOME/.local/share}/DankMaterialShell/chat/history.db"
if [ -f "$DB" ]; then
    perms="$(stat -c '%a' "$DB")"
    if [ "$perms" = "600" ]; then
        ok "message store is not world-readable"
    else
        bad "message store is not world-readable" "mode is $perms, expected 600"
    fi
else
    skip "no message store yet at $DB"
fi

SESSION="${XDG_DATA_HOME:-$HOME/.local/share}/dms-whatsapp/session.db"
if [ -f "$SESSION" ]; then
    perms="$(stat -c '%a' "$SESSION")"
    if [ "$perms" = "600" ]; then
        ok "WhatsApp session is not world-readable"
    else
        bad "WhatsApp session is not world-readable" "mode is $perms; this file is your account"
    fi
fi

printf '\n%s passed, %s failed, %s skipped\n' "$PASS" "$FAIL" "$SKIP"
exit $((FAIL > 0))
