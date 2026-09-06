#!/usr/bin/env python3
"""Exercise AqueousService's real Quickshell processes using private fake CLI fixtures."""

import json
import os
from pathlib import Path
import shutil
import signal
import subprocess
import tempfile
import time


def wait_for(fn, timeout=12):
    deadline = time.monotonic() + timeout
    while time.monotonic() < deadline:
        result = fn()
        if result:
            return result
        time.sleep(0.05)
    raise AssertionError("timed out waiting for QML service")


def main():
    root = Path(__file__).resolve().parents[1]
    base = Path(tempfile.mkdtemp(prefix="dms-aqueous-service-"))
    print(f"Evidence: {base}", flush=True)
    for directory in ("Common", "Services", "bin", "runtime", "home", "config", "cache"):
        (base / directory).mkdir(mode=0o700)
    for name in ("AqueousService.qml", "AqueousConfigService.qml"):
        shutil.copy(root / "quickshell/Services" / name, base / "Services" / name)
    common = {
        "Log": 'function scoped(name) { return {warn: function() {}}; }',
        "I18n": 'function tr(value) { return value; }',
        "SettingsData": 'enum Position { Top, Left, Right }',
    }
    services = {
        "CompositorService": 'property bool isAqueous: false',
        "ToastService": 'function showError(title, message) {}',
    }
    for directory, stubs in (("Common", common), ("Services", services)):
        for name, body in stubs.items():
            (base / directory / (name + ".qml")).write_text("pragma Singleton\nimport QtQuick\nQtObject { " + body + " }\n")
    for directory in ("Common", "Services"):
        (base / directory / "qmldir").write_text("\n".join("singleton " + path.stem + " 1.0 " + path.name for path in (base / directory).glob("*.qml")))
    (base / "shell.qml").write_text('''import QtQuick
import Quickshell
import Quickshell.Io
import qs.Services
ShellRoot {
    id: shell
    property var reply: ({pending: true})
    IpcHandler {
        target: "test"
        function enabled(value: bool): string { CompositorService.isAqueous = value; return "OK"; }
        function status(): string {
            return JSON.stringify({available: AqueousService.available, state: AqueousService.state,
                pending: AqueousService.pendingProcesses.length, commandPending: AqueousService.commandPending,
                retry: AqueousService.retryDelay, watching: !!AqueousService.watchProcess});
        }
        function command(): string {
            shell.reply = {pending: true};
            AqueousService.command("workspace.activate", {id: AqueousService.workspaces[0].id},
                (ok, message) => { shell.reply = {ok: ok, message: message}; });
            return "REQUESTED";
        }
        function json(mode: string): string {
            shell.reply = {pending: true};
            AqueousService.runJson(["aqueousctl", "test-json", mode], null,
                (result, error) => { shell.reply = {error: error, length: result?.payload?.length,
                    tail: result?.payload?.slice(-7)}; });
            return "REQUESTED";
        }
        function result(): string { return JSON.stringify(shell.reply); }
    }
}''')
    shutil.copy(root / "quickshell/tests/fixtures/aqueous/capabilities.json", base / "capabilities.json")
    batch = json.loads((root / "quickshell/tests/fixtures/aqueous/watch.ndjson").read_text().splitlines()[0])
    (base / "snapshot.json").write_text(json.dumps(batch))
    binary = base / "bin/aqueousctl"
    binary.write_text('''#!/usr/bin/python3
import json, os, sys, time
from pathlib import Path
base = Path(os.environ["AQ_TEST_DIR"])
args = sys.argv[1:]
mode = (base / "mode").read_text()
with (base / "calls").open("a") as f:
    f.write(json.dumps({"args": args, "pid": os.getpid()}) + "\\n")
if args[0] == "test-json":
    if args[1] == "oversize":
        sys.stdout.write("x" * (5 * 1024 * 1024))
        sys.stdout.flush()
        time.sleep(30)
        sys.exit(0)
    data = json.dumps({"payload": "x" * (2 * 1024 * 1024) + "🫧 日本語"}, ensure_ascii=False).encode()
    for offset in range(0, len(data), 65537):
        sys.stdout.buffer.write(data[offset:offset + 65537])
        sys.stdout.buffer.flush()
        time.sleep(.002)
    sys.exit(0)
if args[:2] == ["shell", "capabilities"]:
    caps = json.loads((base / "capabilities.json").read_text())
    if mode == "unsupported": caps["schema"] = 2
    print(json.dumps(caps))
    sys.exit(0)
if args[:2] != ["shell", "watch"]:
    if mode == "timeout": time.sleep(30)
    if mode == "no-ack": sys.exit(0)
    print(json.dumps({"ok": False, "status": "locked", "sequence": "9007199254740999"}))
    sys.exit(1)
batch = json.loads((base / "snapshot.json").read_text())
batch["sequence"] = "9007199254740993"
workspace = next(e for e in batch["upsert"] if e["kind"] == "workspace")
workspace["name"] = "🫧 日本語"
data = (json.dumps(batch, ensure_ascii=False) + "\\n").encode()
split = data.index("🫧".encode()) + 1
sys.stdout.buffer.write(data[:split]); sys.stdout.buffer.flush()
time.sleep(.02)
sys.stdout.buffer.write(data[split:]); sys.stdout.buffer.flush()
delta = dict(schema=1, session=batch["session"], sequence="9007199254740999", base_sequence=batch["sequence"], type="delta", upsert=[], removed=[])
time.sleep(.15)
if mode == "malformed": print("{bad}", flush=True)
elif mode == "oversize": print("x" * (4 * 1024 * 1024 + 1), flush=True)
elif mode == "eof": sys.exit(0)
else:
    if mode == "mismatch": delta["base_sequence"] = "wrong"
    # Multiple records in one write exercise coalesced reads.
    second = dict(delta, sequence="9007199254741999", base_sequence=delta["sequence"])
    print(json.dumps(delta) + "\\n" + json.dumps(second), flush=True)
time.sleep(60)
''')
    binary.chmod(0o755)
    env = dict(os.environ)
    for name in ("WAYLAND_DISPLAY", "WAYLAND_SOCKET", "DISPLAY", "DMS_SOCKET"):
        env.pop(name, None)
    env.update(AQ_TEST_DIR=str(base), PATH=str(base / "bin") + ":/usr/bin", HOME=str(base / "home"),
               XDG_RUNTIME_DIR=str(base / "runtime"), XDG_CONFIG_HOME=str(base / "config"), XDG_CACHE_HOME=str(base / "cache"),
               QT_QPA_PLATFORM="offscreen", QT_QUICK_BACKEND="software", QT_QPA_PLATFORMTHEME="generic", QT_STYLE_OVERRIDE="Fusion")
    (base / "mode").write_text("normal")
    (base / "calls").touch()
    qs = shutil.which("qs") or shutil.which("quickshell")

    def ipc(*args):
        result = subprocess.run([qs, "ipc", "-p", str(base / "shell.qml"), "call", "test", *args], env=env, capture_output=True, text=True, timeout=5)
        assert result.returncode == 0, (result.stdout, result.stderr)
        return result.stdout.strip()

    def state():
        return json.loads(ipc("status"))

    def calls():
        return [json.loads(line) for line in (base / "calls").read_text().splitlines()]

    def reply():
        response = json.loads(ipc("result"))
        return response if not response.get("pending") else None

    def stop():
        ipc("enabled", "false")
        wait_for(lambda: not state()["watching"] and not state()["pending"])
        time.sleep(.1)
        assert not any(Path("/proc", str(call["pid"])).exists() for call in calls()), "child process survived backend change"

    with (base / "quickshell.log").open("w") as log:
        process = subprocess.Popen([qs, "-p", str(base / "shell.qml")], env=env, stdout=log, stderr=log, start_new_session=True)
        try:
            wait_for(lambda: subprocess.run([qs, "ipc", "-p", str(base / "shell.qml"), "call", "test", "status"], env=env, capture_output=True).returncode == 0)
            assert not calls(), "Aqueous helper initialized in unrelated backend"
            ipc("enabled", "true")
            current = wait_for(lambda: (s if (s := state())["available"] and s["state"]["batch"]["sequence"] == "9007199254741999" else None))
            assert any(e.get("name") == "🫧 日本語" for e in current["state"]["batch"]["upsert"])
            count = len(calls())
            time.sleep(1)
            assert state()["available"] and len(calls()) == count, "quiet stream spawned subprocesses"
            ipc("command")
            assert "locked" in wait_for(reply)["message"]
            ipc("json", "large")
            response = wait_for(reply)
            assert response == {"error": "", "length": 2 * 1024 * 1024 + 6, "tail": "x🫧 日本語"}, response
            ipc("json", "oversize")
            response = wait_for(reply)
            assert response["error"] == "process output exceeds 4 MiB", response
            wait_for(lambda: not state()["pending"] and not any(
                Path("/proc", str(call["pid"])).exists() for call in calls() if call["args"][0] == "test-json"))
            assert state()["available"], "JSON helper failure disconnected the watch stream"
            for mode in ("malformed", "mismatch", "oversize", "eof", "unsupported"):
                stop()
                (base / "mode").write_text(mode)
                ipc("enabled", "true")
                wait_for(lambda: state()["state"].get("error"))
                assert not state()["available"], mode
                assert state()["retry"] >= 1000
            stop()
            binary.rename(base / "bin/aqueousctl-disabled")
            ipc("enabled", "true")
            wait_for(lambda: state()["state"].get("error"))
            assert not state()["pending"]
            time.sleep(.7)
            assert state()["retry"] <= 4000, "missing CLI caused a tight retry loop"
            stop()
            (base / "bin/aqueousctl-disabled").rename(binary)
            (base / "mode").write_text("no-ack")
            ipc("enabled", "true")
            wait_for(lambda: state()["available"])
            ipc("command")
            assert not wait_for(reply)["ok"], "EOF without acknowledgement accepted"
            stop()
            (base / "mode").write_text("timeout")
            ipc("enabled", "true")
            wait_for(lambda: state()["available"])
            count = len([c for c in calls() if c["args"][0] == "workspace"])
            ipc("command")
            assert "uncertain" in wait_for(reply)["message"]
            assert len([c for c in calls() if c["args"][0] == "workspace"]) == count + 1, "timed-out mutation retried"
            stop()
            (base / "mode").write_text("normal")
            ipc("enabled", "true")
            wait_for(lambda: state()["available"])
        finally:
            os.killpg(process.pid, signal.SIGTERM)
            process.wait(timeout=5)
    wait_for(lambda: not any(Path("/proc", str(call["pid"])).exists() for call in calls()))
    print("PASS: QML process framing, large JSON, streaming size guard, Unicode, continuity, errors, retry, timeout, idle and cleanup", flush=True)


if __name__ == "__main__":
    main()
