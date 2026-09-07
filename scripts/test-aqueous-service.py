#!/usr/bin/env python3
"""Exercise production Aqueous QML sockets on a private offscreen Quickshell."""
import json
import os
from pathlib import Path
import shutil
import signal
import socket
import subprocess
import tempfile
import threading
import time


def wait_for(fn, timeout=15):
    deadline = time.monotonic() + timeout
    while time.monotonic() < deadline:
        value = fn()
        if value:
            return value
        time.sleep(.05)
    raise AssertionError("timed out waiting for QML service")


def main():
    root = Path(__file__).resolve().parents[1]
    base = Path(tempfile.mkdtemp(prefix="dms-aqueous-socket-"))
    print(f"Evidence: {base}", flush=True)
    for name in ("Common", "Services", "bin", "runtime", "home", "config", "cache"):
        (base / name).mkdir(mode=0o700)
    (base / "DankCommon").symlink_to(root / "dank-qml-common/DankCommon", target_is_directory=True)
    shutil.copy(root / "quickshell/Services/AqueousService.qml", base / "Services")
    for name in ("AqueousConnection.qml", "AqueousIpc.js", "DankSocket.qml"):
        shutil.copy(root / "quickshell/Common" / name, base / "Common")
    stubs = {
        "Common": {"Log": 'function scoped(name) { return {warn: function() {}}; }',
                   "I18n": 'function tr(value) { return value; }',
                   "SettingsData": 'enum Position { Top, Left, Right }'},
        "Services": {"CompositorService": 'property bool isAqueous: false',
                     "ToastService": 'function showError(title, message) {}'},
    }
    for directory, items in stubs.items():
        for name, body in items.items():
            (base / directory / (name + ".qml")).write_text("pragma Singleton\nimport QtQuick\nQtObject { " + body + " }\n")
        (base / directory / "qmldir").write_text("\n".join(
            ("singleton " if p.stem in items or p.stem == "AqueousService" else "") + p.stem + " 1.0 " + p.name
            for p in (base / directory).glob("*.qml")))
    (base / "shell.qml").write_text('''import QtQuick
import Quickshell
import Quickshell.Io
import qs.Services
ShellRoot {
    id: shell
    property var replies: []
    IpcHandler {
        target: "test"
        function enabled(value: bool): string { CompositorService.isAqueous = value; return "OK"; }
        function status(): string {
            return JSON.stringify({available: AqueousService.available, state: AqueousService.state,
                pending: AqueousService.commandPending, queued: AqueousService.commandQueue.length});
        }
        function commands(count: int): string {
            shell.replies = [];
            for (let i = 0; i < count; i++) {
                const number = i;
                AqueousService.command("workspace.rename", {id: AqueousService.workspaces[0].id, name: String(i)},
                    (ok, message) => { shell.replies = shell.replies.concat([{number: number, ok: ok, message: message}]); });
            }
            return "REQUESTED";
        }
        function exitSession(): string {
            shell.replies = [];
            AqueousService.command("session.exit", {}, (ok, message) => { shell.replies = [{ok: ok, message: message}]; });
            return "REQUESTED";
        }
        function results(): string { return JSON.stringify(shell.replies); }
    }
}''')
    # Any legacy runtime helper launch is a test failure, including short-lived children.
    (base / "calls").touch()
    (base / "bin/aqueousctl").write_text('#!/bin/sh\nprintf "aqueousctl\\n" >> "$AQ_TEST_DIR/calls"\nexit 99\n')
    (base / "bin/aqueousctl").chmod(0o755)
    env = dict(os.environ)
    for key in ("WAYLAND_DISPLAY", "WAYLAND_SOCKET", "DISPLAY", "DMS_SOCKET", "AQUEOUS_SOCKET"):
        env.pop(key, None)
    socket_dir = base / "runtime/aqueous/test"
    socket_dir.mkdir(parents=True, mode=0o700)
    (socket_dir.parent).chmod(0o700)
    endpoint = socket_dir / "ipc.sock"
    env.update(AQ_TEST_DIR=str(base), PATH=str(base / "bin") + ":/usr/bin", HOME=str(base / "home"),
               XDG_RUNTIME_DIR=str(base / "runtime"), XDG_CONFIG_HOME=str(base / "config"), XDG_CACHE_HOME=str(base / "cache"),
               AQUEOUS_SOCKET=str(endpoint), QT_QPA_PLATFORM="offscreen", QT_QUICK_BACKEND="software",
               QT_QPA_PLATFORMTHEME="generic", QT_STYLE_OVERRIDE="Fusion")
    qs = shutil.which("qs") or shutil.which("quickshell")
    hello = json.loads((root / "quickshell/tests/fixtures/aqueous/hello.json").read_text())["result"]
    snapshot = json.loads((root / "quickshell/tests/fixtures/aqueous/watch.ndjson").read_text().splitlines()[0])
    snapshot["sequence"] = "9007199254740993"
    next(e for e in snapshot["upsert"] if e["kind"] == "workspace")["name"] = "🫧 日本語"
    mode = "normal"
    connections, requests, errors = [], [], []
    traffic = {"received": 0, "sent": 0}
    stopping = threading.Event()

    def serve(conn):
        try:
            reader = conn.makefile("rb")
            last = 0
            delivery = 0
            session = hello["session"]
            while line := reader.readline(65538):
                traffic["received"] += len(line)
                request = json.loads(line)
                requests.append(request)
                assert int(request["id"]) > last
                last = int(request["id"])
                op = request["op"]
                reply = dict(ipc=1, id=request["id"], ok=True)
                event = None
                if op == "hello":
                    assert last == 1 and "session" not in request
                    result = dict(hello)
                    if mode == "unsupported":
                        result["schema"] = 2
                    if mode == "session-mismatch" and len([r for r in requests if r["op"] == "hello"]) % 2:
                        result["session"] = "f" * 32
                    reply["result"] = result
                else:
                    assert request["session"] == session
                    if op == "subscribe":
                        reply["result"] = {"subscribed": True}
                        delivery = 1
                        event = dict(ipc=1, event="state", delivery="1", batch=snapshot)
                    elif op == "ack":
                        assert request["params"]["delivery"] == str(delivery)
                        reply["result"] = {"acked": str(delivery)}
                        if delivery == 1:
                            delivery = 2
                            batch = dict(schema=1, session=session, type="delta", sequence="9007199254741999",
                                         base_sequence=snapshot["sequence"], upsert=[], removed=[])
                            if mode == "baseline":
                                batch["base_sequence"] = "wrong"
                            event = dict(ipc=1, event="state", delivery="2", batch=batch)
                    elif op == "command":
                        if mode == "timeout":
                            conn.recv(1)
                            return
                        if mode == "disconnect":
                            conn.shutdown(socket.SHUT_RDWR)
                            return
                        if mode == "slow":
                            time.sleep(.2)
                        if mode == "locked":
                            reply.update(ok=False, error={"code": "locked", "message": "Session is locked"})
                        elif mode == "malformed-error":
                            reply.update(ok=False, error={"code": 42})
                        else:
                            action = request["params"]["action"]
                            reply["result"] = {"status": "accepted"} if action == "session.exit" else {"status": "applied", "sequence": "9007199254742999"}
                    else:
                        raise AssertionError(op)
                data = (json.dumps(reply) + "\n").encode()
                if event:
                    if mode == "partial":
                        conn.sendall(data + b'{"ipc":1,"event":"state","batch":')
                        conn.shutdown(socket.SHUT_RDWR)
                        return
                    if mode == "malformed":
                        data += b"{bad}\n"
                    elif mode == "oversize":
                        data += b"x" * 4259841 + b"\n"
                    elif mode == "no-snapshot":
                        pass
                    else:
                        data += (json.dumps(event, ensure_ascii=False) + "\n").encode()
                # Split inside a UTF-8 codepoint, with reply/event coalesced in the tail.
                split = data.find("🫧".encode()) + 1
                if split:
                    conn.sendall(data[:split])
                    time.sleep(.01)
                    data = data[split:]
                    traffic["sent"] += split
                conn.sendall(data)
                traffic["sent"] += len(data)
        except (BrokenPipeError, ConnectionResetError, OSError):
            pass
        except Exception as error:
            errors.append(repr(error))
        finally:
            conn.close()

    listener = socket.socket(socket.AF_UNIX)

    def accept():
        while not stopping.is_set():
            try:
                conn, _ = listener.accept()
            except OSError:
                return
            connections.append(conn)
            threading.Thread(target=serve, args=(conn,), daemon=True).start()

    def disconnect():
        for conn in connections[:]:
            try:
                conn.shutdown(socket.SHUT_RDWR)
                conn.close()
            except OSError:
                pass
        connections.clear()

    def ipc(*args):
        result = subprocess.run([qs, "ipc", "-p", str(base / "shell.qml"), "call", "test", *args], env=env,
                                capture_output=True, text=True, timeout=5)
        assert result.returncode == 0, (result.stdout, result.stderr, (base / "qml.log").read_text())
        return result.stdout.strip()

    def state():
        return json.loads(ipc("status"))

    def results(count):
        value = json.loads(ipc("results"))
        return value if len(value) == count else None

    def restart(new_mode):
        nonlocal mode
        ipc("enabled", "false")
        disconnect()
        mode = new_mode
        requests.clear()
        ipc("enabled", "true")

    with (base / "qml.log").open("w") as log:
        child = subprocess.Popen([qs, "-p", str(base / "shell.qml")], env=env, stdout=log, stderr=log, start_new_session=True)
    try:
        wait_for(lambda: (base / "qml.log").read_text().find("Configuration Loaded") >= 0)
        ipc("enabled", "true")
        assert not state()["available"]
        # The compositor can be absent at startup; only DankSocket owns retries.
        listener.bind(str(endpoint))
        endpoint.chmod(0o600)
        listener.listen()
        threading.Thread(target=accept, daemon=True).start()
        wait_for(lambda: state()["available"] and state()["state"]["batch"]["sequence"] == "9007199254741999")
        assert len([r for r in requests if r["op"] == "hello"]) == 2
        assert "🫧 日本語" in json.dumps(state(), ensure_ascii=False)
        mode = "slow"
        ipc("commands", "35")
        replies = wait_for(lambda: results(35))
        assert len([r for r in replies if "queue full" in r["message"]]) == 2
        sent = [r["params"]["fields"]["name"] for r in requests if r["op"] == "command"]
        assert sent == [str(i) for i in range(len(sent))], sent
        assert any("before sending" in r["message"] for r in replies), replies
        for failure in ("locked", "malformed-error", "disconnect", "timeout"):
            mode = failure
            ipc("commands", "2")
            replies = wait_for(lambda: results(2))
            assert all(not r["ok"] for r in replies), replies
            assert ("locked" if failure == "locked" else "uncertain") in replies[0]["message"], replies
            mode = "normal"
            wait_for(lambda: state()["available"])
        ipc("exitSession")
        assert wait_for(lambda: results(1)) == [{"ok": True, "message": "accepted"}]
        for failure in ("unsupported", "session-mismatch", "baseline", "malformed", "oversize", "partial", "no-snapshot"):
            restart(failure)
            wait_for(lambda: state()["state"].get("error", "").find("connecting") < 0 and bool(state()["state"].get("error")), timeout=20)
            assert not state()["available"], failure
            restart("normal")
            wait_for(lambda: state()["available"])
        disconnect()
        wait_for(lambda: len([r for r in requests if r["op"] == "hello"]) >= 4 and state()["available"])
        time.sleep(.2)
        before = dict(traffic)
        stat_before = Path(f"/proc/{child.pid}/stat").read_text().split()
        status_before = Path(f"/proc/{child.pid}/status").read_text()
        time.sleep(2)
        stat_after = Path(f"/proc/{child.pid}/stat").read_text().split()
        children = Path(f"/proc/{child.pid}/task/{child.pid}/children").read_text().strip()
        assert not children, children
        assert before == traffic, (before, traffic)
        assert not (base / "calls").read_text(), "aqueousctl was launched"
        assert not errors, errors
        def fields(status):
            return {line.split(":", 1)[0]: line.split(":", 1)[1].strip() for line in status.splitlines() if ":" in line}
        status_after = Path(f"/proc/{child.pid}/status").read_text()
        first, last = fields(status_before), fields(status_after)
        (base / "resources.json").write_text(json.dumps(dict(idle_seconds=2, child_processes=0, traffic=traffic, idle_bytes=0,
            rss_before=first["VmRSS"], rss_after=last["VmRSS"],
            voluntary_context_switches=int(last["voluntary_ctxt_switches"])-int(first["voluntary_ctxt_switches"]),
            idle_cpu_ticks=int(stat_after[13])+int(stat_after[14])-int(stat_before[13])-int(stat_before[14]),
            status_before=status_before, status_after=Path(f"/proc/{child.pid}/status").read_text()), indent=2))
        print("PASS: QML hello, UTF-8, ack order, queue, deadlines, errors, reconnect, accepted exit, zero helper launches and idle traffic", flush=True)
    finally:
        stopping.set()
        disconnect()
        listener.close()
        os.killpg(child.pid, signal.SIGTERM)
        child.wait(timeout=10)


if __name__ == "__main__":
    main()
