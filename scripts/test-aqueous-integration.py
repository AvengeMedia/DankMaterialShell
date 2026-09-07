#!/usr/bin/env python3
"""Run the real DMS daemon/UI on a private Aqueous headless display.

Requires a diagnostic Pixman-compatible Aqueous build and its source checkout.
All configuration, sockets, images and logs stay in the printed temporary directory.
"""

import argparse
import json
import os
from pathlib import Path
import signal
import socket
import struct
import subprocess
import tempfile
import time


def wait_for(operation, timeout=15):
    deadline = time.monotonic() + timeout
    while time.monotonic() < deadline:
        value = operation()
        if value:
            return value
        time.sleep(0.1)
    raise AssertionError("timed out waiting for authoritative state")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--aqueous-source", type=Path, required=True)
    parser.add_argument("--bin-dir", type=Path, required=True, help="aqueous, aqueousctl, aqueous-config and dms binaries")
    parser.add_argument("--frame", action="store_true", help="exercise connected frame reservations on both outputs")
    parser.add_argument("--xwayland", action="store_true", help="also capture a synthetic XWayland window; uses positive output origins")
    parser.add_argument("--force-ext", action="store_true", help="verify the actual workspace widget through ext-workspace")
    args = parser.parse_args()
    source = args.aqueous_source.resolve() / "compositor"
    binaries = args.bin_dir.resolve()
    root = Path(__file__).resolve().parents[1]
    base = Path(tempfile.mkdtemp(prefix="dms-aqueous-integration-"))
    print(f"Evidence: {base}", flush=True)
    for name in ("runtime", "config", "state", "cache", "home", "protocols", "bin"):
        (base / name).mkdir(mode=0o700)
    env = dict(os.environ)
    for key in list(env):
        if key.startswith("AQUEOUS_") or key in ("WAYLAND_DISPLAY", "DISPLAY", "LD_PRELOAD", "DMS_SOCKET"):
            env.pop(key)
    env.update(HOME=str(base / "home"), XDG_RUNTIME_DIR=str(base / "runtime"),
               XDG_CONFIG_HOME=str(base / "config"), XDG_STATE_HOME=str(base / "state"),
               XDG_CACHE_HOME=str(base / "cache"), PATH=str(base / "bin") + ":" + str(binaries) + ":" + env["PATH"],
               WLR_BACKENDS="headless", WLR_HEADLESS_OUTPUTS="2", WLR_RENDERER="pixman",
               QT_QPA_PLATFORM="wayland", QT_QUICK_BACKEND="software", GSETTINGS_BACKEND="memory",
               DMS_FORCE_EXTWS="1" if args.force_ext else "0", DMS_NO_DDC="1", DMS_DISABLE_MATUGEN="1", DMS_DISABLE_HOT_RELOAD="1",
               DBUS_SESSION_BUS_ADDRESS="unix:path=" + str(base / "missing-session-bus"),
               DBUS_SYSTEM_BUS_ADDRESS="unix:path=" + str(base / "missing-system-bus"))
    (base / "runtime-helper-calls").touch()
    env["AQ_TEST_REAL_CTL"] = str(binaries / "aqueousctl")
    (base / "bin/aqueousctl").write_text('''#!/usr/bin/python3
import json, os, sys
from pathlib import Path
parent = Path("/proc", str(os.getppid()), "cmdline").read_bytes().split(b"\\0")
record = {"args": sys.argv[1:], "parent": os.fsdecode(parent[0]), "pid": os.getpid()}
with (Path(os.environ["XDG_RUNTIME_DIR"]).parent / "runtime-helper-calls").open("a") as log:
    log.write(json.dumps(record) + "\\n")
if Path(record["parent"]).name != "aqueous-config":
    sys.exit(99)
real = os.environ["AQ_TEST_REAL_CTL"]
os.execv(real, [real, *sys.argv[1:]])
''')
    (base / "bin/aqueousctl").chmod(0o755)
    config = base / "config/aqueous"
    config.mkdir()
    shell_config = base / "config/DankMaterialShell"
    shell_config.mkdir()
    (shell_config / ".firstlaunch").touch()
    (shell_config / "settings.json").write_text(json.dumps(dict(
        frameEnabled=args.frame, frameMode="connected", showDock=True, dockGroupByApp=False,
        showWorkspaceApps=True, showWorkspacePadding=True, groupWorkspaceApps=False,
        workspaceFollowFocus=False, showOccupiedWorkspacesOnly=False,
        barConfigs=[dict(id="default", name="Test", enabled=True, position=0,
                        screenPreferences=["all"], showOnLastDisplay=True,
                        leftWidgets=["workspaceSwitcher", "focusedWindow", "runningApps", "keyboard_layout_name"],
                        centerWidgets=[], rightWidgets=[], spacing=4, innerPadding=4, visible=True)])))
    for name in ("wm", "layout", "input", "outputs", "rules", "appearance"):
        path = config / f"{name}.toml"
        path.write_text((source / "scripts/fixtures/overview-wm.toml").read_text() if name == "wm" else "")
        env["AQUEOUS_" + ("CONFIG" if name == "wm" else name.upper())] = str(path)

    protocols = {
        "xdg-activation": Path("/usr/share/wayland-protocols/staging/xdg-activation/xdg-activation-v1.xml"),
        "pointer-constraints": Path("/usr/share/wayland-protocols/unstable/pointer-constraints/pointer-constraints-unstable-v1.xml"),
        "xdg-shell": Path("/usr/share/wayland-protocols/stable/xdg-shell/xdg-shell.xml"),
        "shortcuts": Path("/usr/share/wayland-protocols/unstable/keyboard-shortcuts-inhibit/keyboard-shortcuts-inhibit-unstable-v1.xml"),
        "virtual-keyboard": source / "protocol/upstream/virtual-keyboard-unstable-v1.xml",
        "layer-shell": source / "protocol/upstream/wlr-layer-shell-unstable-v1.xml",
        "session-lock": Path("/usr/share/wayland-protocols/staging/ext-session-lock/ext-session-lock-v1.xml"),
        "aqueous-shell": source / "protocol/aqueous-shell-v1.xml",
        "ext-workspace": source / "protocol/upstream/ext-workspace-v1.xml",
    }
    generated = []
    for name, xml in protocols.items():
        subprocess.run(["wayland-scanner", "client-header", str(xml), str(base / "protocols" / f"{name}-client-protocol.h")], check=True)
        code = base / "protocols" / f"{name}.c"
        subprocess.run(["wayland-scanner", "private-code", str(xml), str(code)], check=True)
        generated.append(str(code))
    fixture = base / "shell-client"
    subprocess.run(["cc", "-Wall", "-Wextra", "-Werror", "-I" + str(base / "protocols"),
                    str(source / "scripts/fixtures/shell-client.c"), *generated,
                    "-lwayland-client", "-lxkbcommon", "-o", str(fixture)], check=True)
    if args.xwayland:
        subprocess.run(["cc", "-Wall", "-Wextra", "-Werror", str(source / "scripts/fixtures/shell-x11.c"),
                        "-lX11", "-o", str(base / "shell-x11")], check=True)
    children = []

    def spawn(command, log_name):
        with (base / log_name).open("w") as log:
            child = subprocess.Popen(command, env=env, stdin=subprocess.PIPE, stdout=log, stderr=log, start_new_session=True)
        children.append(child)
        return child

    def run(command, success=True):
        result = subprocess.run(command, env=env, capture_output=True, text=True, timeout=20)
        assert (result.returncode == 0) == success, (command, result.stdout, result.stderr)
        return result.stdout

    def ipc(*args):
        return run([str(binaries / "dms"), "ipc", "call", *args]).strip()

    def rpc(method, params=None, success=True):
        assert ipc("aqueousTest", "request", method, json.dumps(params)) == "REQUESTED"
        def reply():
            output = ""
            while True:
                part = json.loads(ipc("aqueousTest", "result", str(len(output))))
                output += part["data"]
                if part["complete"]:
                    return json.loads(output)
        response = wait_for(reply)
        assert ("error" not in response) == success, response
        return response.get("result") if success else response["error"]

    def state():
        return json.loads(ipc("aqueousTest", "state"))

    def entities(kind):
        return [e for e in state().get("batch", {}).get("upsert", []) if e["kind"] == kind]

    def command(action, success=True, **fields):
        return rpc("aqueous.command", dict(action=action, session=session, **fields), success)

    # Test-only IPC invokes the production singleton inside the actual shell.
    shell = base / "shell"
    shell.mkdir()
    for path in (root / "quickshell").iterdir():
        if path.name != "shell.qml":
            (shell / path.name).symlink_to(path)
    harness = """
    property var aqueousTestReply: null
    property var rememberedWorkspace: null
    PanelWindow {
        screen: workspaceTest.parentScreen
        implicitWidth: Math.max(1, workspaceTest.width)
        implicitHeight: Math.max(1, workspaceTest.height)
        color: "transparent"
        anchors { top: true; left: true }
        WlrLayershell.namespace: "dms:aqueous-workspace-test"
        exclusiveZone: 0
        WorkspaceWidgets.WorkspaceSwitcher {
            id: workspaceTest
            parentScreen: Quickshell.screens.find(s => s.name === screenName) || null
            screenName: Quickshell.screens[0]?.name || ""
            widgetHeight: 30
            barThickness: 48
        }
    }
    function activateWorkspaceIcon(item, windowId) {
        for (const child of item.children || []) {
            if (child.windowId === windowId && child.windowSession) {
                let delegate = child.parent;
                while (delegate && typeof delegate.focusWindowAt !== "function")
                    delegate = delegate.parent;
                if (!delegate)
                    return false;
                const point = child.mapToItem(delegate, child.width / 2, child.height / 2);
                return delegate.focusWindowAt(point.x, point.y);
            }
            if (activateWorkspaceIcon(child, windowId))
                return true;
        }
        return false;
    }
    function workspaceDelegates(item) {
        let result = [];
        for (const child of item.children || []) {
            if (child.stableIconCount !== undefined) {
                result.push({active: child.isActive, placeholder: child.isPlaceholder,
                    occupied: child.isOccupied, known: !workspaceTest.useExtWorkspace, count: child.stableIconCount,
                    icons: child.loadedIcons.length, width: child.width, height: child.height,
                    extraWidth: child.iconsExtraWidth, extraHeight: child.iconsExtraHeight});
            } else {
                result = result.concat(workspaceDelegates(child));
            }
        }
        return result;
    }
    function renameModal() {
        return dmsShellLoader.item?.children.find(c => c.workspaceRenameModalLoader !== undefined)?.workspaceRenameModalLoader?.item;
    }
    function renameInput(item) {
        if (!item)
            return null;
        if (item.placeholderText === I18n.tr("Workspace name"))
            return item;
        for (const child of item.children || []) {
            const found = renameInput(child);
            if (found)
                return found;
        }
        return null;
    }
    IpcHandler {
        target: "aqueousTest"
        function state(): string { return JSON.stringify(AqueousService.state); }
        function workspaceSetting(key: string): string {
            const row = SettingsSearchService.registeredCards[key]?.item;
            return JSON.stringify(row ? {visible: row.visible, enabled: row.enabled, checked: row.checked} : {visible: false, tab: PopoutService.settingsModal?.currentTabIndex, registered: Object.keys(SettingsSearchService.registeredCards)});
        }
        function toggleWorkspaceSetting(key: string): string {
            const row = SettingsSearchService.registeredCards[key]?.item;
            if (!row?.visible || !row.enabled)
                return "UNAVAILABLE";
            row.toggled(!row.checked);
            return "TOGGLED";
        }
        function renameStatus(): string {
            const modal = entrypoint.renameModal();
            const input = entrypoint.renameInput(modal?.contentItem);
            return JSON.stringify(modal ? {visible: modal.visible, pending: modal.renaming,
                target: modal.aqueousWorkspace, text: input?.text, inputEnabled: input?.enabled} : null);
        }
        function renameSubmit(name: string): string {
            const modal = entrypoint.renameModal();
            const input = entrypoint.renameInput(modal?.contentItem);
            if (!modal?.visible || !input)
                return "UNAVAILABLE";
            input.text = name;
            modal.submitAndClose();
            return "REQUESTED";
        }
        function workspaceStatus(): string {
            return JSON.stringify({backend: workspaceTest.useAqueous ? "aqueous" : workspaceTest.useExtWorkspace ? "ext" : "none", output: workspaceTest.effectiveScreenName,
                rows: workspaceTest.workspaceList.map(w => ({name: w.name, active: w.active, number: w.number,
                    placeholder: !!w._placeholder, windows: workspaceTest.useAqueous ? AqueousService.toplevels.filter(t => t.aqueousWorkspaceId === w.id).length : null})),
                delegates: entrypoint.workspaceDelegates(workspaceTest)});
        }
        function workspaceOptions(options: string): string {
            const value = JSON.parse(options);
            if (value.output !== undefined) workspaceTest.screenName = value.output;
            if (value.vertical !== undefined) workspaceTest.isVertical = value.vertical;
            if (value.padding !== undefined) SettingsData.showWorkspacePadding = value.padding;
            if (value.occupiedOnly !== undefined) SettingsData.showOccupiedWorkspacesOnly = value.occupiedOnly;
            if (value.group !== undefined) { SettingsData.groupWorkspaceApps = value.group; SettingsData.groupActiveWorkspaceApps = value.group; }
            if (value.follow !== undefined) SettingsData.workspaceFollowFocus = value.follow;
            if (value.maxIcons !== undefined) SettingsData.maxWorkspaceIcons = value.maxIcons;
            return "OK";
        }
        function workspaceActivate(index: int): string {
            workspaceTest.switchToWorkspaceByModelData(workspaceTest.workspaceList[index]);
            return "REQUESTED";
        }
        function workspaceWheel(direction: string): string { workspaceTest.switchWorkspace(direction === "previous" ? -1 : 1); return "REQUESTED"; }
        function workspaceIcon(windowId: string): string { return String(entrypoint.activateWorkspaceIcon(workspaceTest, windowId)); }
        function workspaceRemember(): string {
            entrypoint.rememberedWorkspace = workspaceTest.workspaceList.find(w => !w.active && !w._placeholder);
            return String(!!entrypoint.rememberedWorkspace);
        }
        function reconnect(): string { AqueousService.disconnected("test stream disconnected"); return "OK"; }
        function workspaceReplay(): string { AqueousService.activateWorkspace(entrypoint.rememberedWorkspace); return "REQUESTED"; }
        function workspaceOverview(): string { AqueousService.toggleOverview(workspaceTest.effectiveScreenName); return "true"; }
        function result(offset: int): string {
            const text = JSON.stringify(entrypoint.aqueousTestReply);
            return JSON.stringify({data: text.slice(offset, offset + 8192), complete: offset + 8192 >= text.length});
        }
        function request(method: string, params: string): string {
            entrypoint.aqueousTestReply = null;
            const fields = JSON.parse(params);
            if (method === "aqueous.command") {
                AqueousService.command(fields.action, fields, (ok, status) => {
                    entrypoint.aqueousTestReply = ok ? {result: {ok: true, status: status}} : {error: status};
                });
            } else {
                AqueousConfigService.request(method.split(".").pop(), fields, (result, error) => {
                    entrypoint.aqueousTestReply = error ? {error: error} : {result: result};
                });
            }
            return "REQUESTED";
        }
    }
    """
    source_shell = (root / "quickshell/shell.qml").read_text().replace("import Quickshell\n", "import Quickshell\nimport Quickshell.Io\nimport Quickshell.Wayland\nimport qs.Modules.DankBar.Widgets as WorkspaceWidgets\n")
    (shell / "shell.qml").write_text(source_shell.replace("    id: entrypoint", "    id: entrypoint\n" + harness))

    try:
        compositor = spawn([str(binaries / "aqueous"), *([] if args.xwayland else ["-no-xwayland"]),
                            "-c", 'printf %s "$DISPLAY" > "$XDG_RUNTIME_DIR/test-display"; printf %s "$AQUEOUS_SOCKET" > "$XDG_RUNTIME_DIR/test-ipc"'], "compositor.log")
        display = wait_for(lambda: next((p for p in (base / "runtime").glob("wayland-*") if p.is_socket()), None))
        env["WAYLAND_DISPLAY"] = display.name
        env["AQUEOUS_SOCKET"] = wait_for(lambda: (base / "runtime/test-ipc").read_text() if (base / "runtime/test-ipc").exists() else None)
        with socket.socket(socket.AF_UNIX) as probe:
            probe.settimeout(5)
            probe.connect(env["AQUEOUS_SOCKET"])
            probe.sendall(b'{"ipc":1,"id":"1","op":"hello","params":{}}\n')
            hello = json.loads(probe.makefile("rb").readline(65536))
            assert hello["ok"] and hello["result"]["schema"] == 1, hello
            (base / "hello.json").write_text(json.dumps(hello, indent=2))
        env["DMS_SHELL_DIR"] = str(shell)
        dms = spawn([str(binaries / "dms"), "-c", str(shell), "run"], "dms.log")
        wait_for(lambda: subprocess.run([str(binaries / "dms"), "ipc", "call", "aqueous", "status"], env=env, capture_output=True, text=True, timeout=5).returncode == 0)
        status = wait_for(lambda: (s if (s := json.loads(ipc("aqueous", "status")))["available"] else None))
        assert status["outputs"] == 2, status
        session = status["session"]
        def workspace_status():
            value = json.loads(ipc("aqueousTest", "workspaceStatus"))
            (base / "workspace-status.json").write_text(json.dumps(value, indent=2))
            return value
        def workspace_options(**options):
            assert ipc("aqueousTest", "workspaceOptions", json.dumps(options)) == "OK"
        view = wait_for(lambda: (v if (v := workspace_status())["delegates"] else None))
        assert view["backend"] == ("ext" if args.force_ext else "aqueous"), view
        assert len(view["delegates"]) == len(view["rows"]), view
        if args.frame:
            wait_for(lambda: len(entities("output")) == 2 and all(o["usable_bounds"]["width"] < o["bounds"]["width"] and o["usable_bounds"]["height"] < o["bounds"]["height"] for o in entities("output")))
        wait_for(lambda: ipc("settings", "openWith", "workspaces").startswith("SETTINGS_OPEN_SUCCESS"))
        time.sleep(2)
        assert "Type SettingsModal unavailable" not in (base / "dms.log").read_text()
        for key in ("showWorkspaceApps", "workspaceFollowFocus", "showOccupiedWorkspacesOnly", "reverseScrolling"):
            def setting_state():
                value = json.loads(ipc("aqueousTest", "workspaceSetting", key))
                (base / "workspace-setting.json").write_text(json.dumps(dict(key=key, state=value), indent=2))
                return value
            control = wait_for(lambda: (value if (value := setting_state()) and value["visible"] else None))
            assert control["enabled"] == (not args.force_ext or key not in ("showWorkspaceApps", "showOccupiedWorkspacesOnly")), (key, control)
            if control["enabled"]:
                assert ipc("aqueousTest", "toggleWorkspaceSetting", key) == "TOGGLED"
                wait_for(lambda: setting_state()["checked"] != control["checked"])
                assert ipc("aqueousTest", "toggleWorkspaceSetting", key) == "TOGGLED"
                wait_for(lambda: setting_state()["checked"] == control["checked"])
            else:
                assert ipc("aqueousTest", "toggleWorkspaceSetting", key) == "UNAVAILABLE"
        assert ipc("settings", "close") == "SETTINGS_CLOSE_SUCCESS"
        windows = [spawn([str(fixture), "window"], f"window-{i}.log") for i in range(2)]
        clients = wait_for(lambda: (w if len(w := [w for w in entities("window") if w["app_id"] == "aq-shell-test"]) == 2 else None))
        assert clients[0]["title"] == clients[1]["title"] and clients[0]["id"] != clients[1]["id"]
        seat = entities("seat")[0]["id"]
        window = clients[0]["id"]
        assert command("window.activate", id=window, seat=seat)["status"] == "applied"
        wait_for(lambda: next(s for s in entities("seat") if s["id"] == seat)["window"] == window)
        def current_window():
            return next(w for w in entities("window") if w["id"] == window)
        original_workspace = current_window()["workspace"]
        other_output = next(o for o in entities("output") if o["id"] != current_window()["output"])["id"]
        for field in ("fullscreen", "maximized", "minimized"):
            if field != "fullscreen" and not current_window()["can_" + field[:-1]]:
                assert "unavailable" in command("window." + field, id=window, value=True, success=False)
                continue
            for value in (True, False):
                assert command("window." + field, id=window, value=value)["status"] == "applied"
                wait_for(lambda: current_window()[field] == value)
        assert command("window.move", id=window, output=other_output)["status"] == "applied"
        wait_for(lambda: current_window()["output"] == other_output)
        assert command("window.move", id=window, workspace=original_workspace)["status"] == "applied"
        wait_for(lambda: current_window()["workspace"] == original_workspace)
        locker = spawn([str(fixture), "lock"], "lock.log")
        wait_for(lambda: entities("session")[0]["locked"])
        assert "locked" in command("window.activate", id=window, seat=seat, success=False)
        locker.stdin.write(b"unlock\n")
        locker.stdin.flush()
        assert locker.wait(timeout=5) == 0
        wait_for(lambda: not entities("session")[0]["locked"])
        command("window.activate", id=window, seat=seat)
        group = next(s for s in entities("seat") if s["id"] == seat)["keyboard"]
        assert command("keyboard.set", seat=seat, group=group, index=1)["status"] == "applied"
        wait_for(lambda: next(k for k in entities("keyboard") if k["id"] == group)["index"] == 1)
        assert "German" in json.loads(ipc("aqueous", "status"))["keyboardLayout"]
        output = next(o for o in entities("output") if o["id"] == next(w for w in entities("window") if w["id"] == window)["output"])
        workspace_options(output=output["name"], group=False, occupiedOnly=not args.force_ext)
        if not args.force_ext:
            view = wait_for(lambda: (v if (v := workspace_status()) and any(d["icons"] == 2 for d in v["delegates"]) else None))
            assert all(d["icons"] == d["count"] for d in view["delegates"]), view
            assert len(view["rows"]) == 3 and sum(r["placeholder"] for r in view["rows"]) == 2, view
            assert any(d["extraWidth"] > 0 for d in view["delegates"]), view
            workspace_options(group=True)
            wait_for(lambda: any(d["icons"] == 1 for d in workspace_status()["delegates"]))
            workspace_options(group=False, vertical=True, maxIcons=1)
            view = wait_for(lambda: (v if (v := workspace_status()) and any(d["icons"] == 2 and d["extraHeight"] > 0 for d in v["delegates"]) else None))
            assert all(d["icons"] == d["count"] for d in view["delegates"]), view
            workspace_options(padding=False)
            wait_for(lambda: len(workspace_status()["rows"]) == 1)
            workspace_options(padding=True)
            wait_for(lambda: len(workspace_status()["rows"]) == 3)
        else:
            view = workspace_status()
            assert all(row["windows"] is None for row in view["rows"]), view
            assert all(d["icons"] == d["count"] == 0 and not d["known"] for d in view["delegates"]), view
        workspace_options(vertical=False, maxIcons=3, occupiedOnly=False)
        view = workspace_status()
        current = next(i for i, r in enumerate(view["rows"]) if r["active"])
        target = next(i for i, r in enumerate(view["rows"]) if not r["active"] and not r["placeholder"])
        assert ipc("aqueousTest", "workspaceActivate", str(target)) == "REQUESTED"
        wait_for(lambda: workspace_status()["rows"][target]["active"])
        assert ipc("aqueousTest", "workspaceWheel", "previous" if target > current else "next") == "REQUESTED"
        wait_for(lambda: workspace_status()["rows"][current]["active"])
        # Names change independently of identity, including collisions in one projection.
        same_output = [w for w in entities("workspace") if w["output"] == output["id"]]
        for workspace in same_output[:2]:
            command("workspace.rename", id=workspace["id"], name="Duplicate")
        wait_for(lambda: sum(r["name"] == "Duplicate" for r in workspace_status()["rows"]) == 2)
        command("workspace.rename", id=same_output[0]["id"], name="Renamed")
        wait_for(lambda: any(r["name"] == "Renamed" for r in workspace_status()["rows"]))
        other_output = next(o for o in entities("output") if o["id"] != output["id"])
        workspace_options(output=other_output["name"], follow=True)
        wait_for(lambda: workspace_status()["output"] == output["name"])
        workspace_options(follow=False)
        assert workspace_status()["output"] == other_output["name"]
        workspace_options(output=output["name"])
        if not args.force_ext:
            command("window.activate", id=window, seat=seat)
            def activate_icon():
                workspace_status()
                return ipc("aqueousTest", "workspaceIcon", clients[1]["id"]) == "true"
            wait_for(activate_icon)
            wait_for(lambda: next(s for s in entities("seat") if s["id"] == seat)["window"] == clients[1]["id"])
            command("window.activate", id=window, seat=seat)
        assert ipc("aqueousTest", "workspaceOverview") == "true"
        wait_for(lambda: entities("session")[0]["overview_output"] == output["id"])
        command("overview.hide")
        assert command("overview.show", output=output["id"])["status"] == "applied"
        wait_for(lambda: entities("session")[0]["overview_output"] == output["id"])
        assert ipc("aqueous", "overview", "hide", output["name"]) == "OVERVIEW_REQUESTED"
        wait_for(lambda: entities("session")[0]["overview_output"] is None)

        # Use the real rename IPC/dialog and keep its captured target across a focus change.
        def rename_status():
            value = json.loads(ipc("aqueousTest", "renameStatus"))
            (base / "rename-status.json").write_text(json.dumps(value, indent=2))
            return value
        target = next(w for w in entities("workspace") if w["output"] == output["id"] and w["active"])
        destination = next(w for w in entities("workspace") if w["output"] == output["id"] and w["id"] != target["id"])
        assert ipc("workspace-rename", "open") == "WORKSPACE_RENAME_MODAL_OPENED"
        draft = wait_for(lambda: (value if (value := rename_status()) and value["visible"] else None))
        assert draft["target"] == dict(id=target["id"], session=session), draft
        assert draft["text"] == target["name"], draft
        command("workspace.activate", id=destination["id"], seat=seat)
        assert ipc("aqueousTest", "renameSubmit", "日本語 🫧") == "REQUESTED"
        wait_for(lambda: not rename_status()["visible"])
        wait_for(lambda: next(w for w in entities("workspace") if w["id"] == target["id"])["name"] == "日本語 🫧")
        assert next(w for w in entities("workspace") if w["id"] == destination["id"])["name"] == destination["name"]
        assert ipc("workspace-rename", "toggle") == "WORKSPACE_RENAME_MODAL_OPENED"
        wait_for(lambda: rename_status()["visible"])
        assert rename_status()["target"]["id"] == destination["id"]
        invalid_name = "x" * 1025
        assert ipc("aqueousTest", "renameSubmit", invalid_name) == "REQUESTED"
        draft = rename_status()
        assert draft["visible"] and not draft["pending"] and draft["text"] == invalid_name, draft
        assert ipc("aqueousTest", "renameSubmit", "Renamed after error") == "REQUESTED"
        wait_for(lambda: not rename_status()["visible"])
        wait_for(lambda: next(w for w in entities("workspace") if w["id"] == destination["id"])["name"] == "Renamed after error")
        command("window.activate", id=window, seat=seat)

        def capture(name):
            command("window.activate", id=window, seat=seat)
            run([str(binaries / "dms"), "screenshot", "window", "--seat", seat, "--no-clipboard", "--no-notify", "--dir", str(base), "--filename", name])
            data = (base / name).read_bytes()
            assert data.startswith(b"\x89PNG\r\n\x1a\n")
            dimensions = struct.unpack(">II", data[16:24])
            assert all(dimensions), dimensions
            print(f"Screenshot {name}: {dimensions}", flush=True)

        capture("window.png")
        run([str(binaries / "dms"), "screenshot", "full", "--seat", seat, "--geometry"])
        origin = "3000,100" if args.xwayland else "-3000,-100"
        run(["wlr-randr", "--output", output["name"], "--scale", "1.25", "--transform", "90", "--pos=" + origin])
        wait_for(lambda: next(o for o in entities("output") if o["id"] == output["id"])["scale"] == 1.25)
        capture("rotated-fractional.png" if args.xwayland else "rotated-fractional-negative-origin.png")
        if args.xwayland:
            env["DISPLAY"] = wait_for(lambda: (base / "runtime/test-display").read_text())
            spawn([str(base / "shell-x11")], "xwayland-window.log")
            xwindow = wait_for(lambda: next((w for w in entities("window") if w["backend"] == "xwayland"), None))
            window = xwindow["id"]
            capture("xwayland-window.png")
            assert command("window.close", id=window)["status"] == "accepted"

        snapshot = rpc("aqueous.config.snapshot")
        (base / "helper-snapshot.json").write_text(json.dumps(snapshot, indent=2) + "\n")
        (base / "helper-version.json").write_text(run([str(binaries / "aqueous-config"), "version"]))
        generation = snapshot["generation"]
        edit = dict(expected_generation=generation, changes=[dict(id="toggle_overview", value=["Super+W", "Super+F12"])])
        rpc("aqueous.config.validate", edit)
        assert rpc("aqueous.config.snapshot")["generation"] == generation
        saved = rpc("aqueous.config.apply", edit)
        assert saved["generation"] != generation
        assert "external_change" in rpc("aqueous.config.apply", edit, success=False)
        sheet = json.loads(run([str(binaries / "dms"), "keybinds", "show", "aqueous"]))
        assert sheet["generation"] == saved["generation"]
        run([str(binaries / "dms"), "keybinds", "set", "aqueous", "Super+F11", "spawn true", "--expected-generation", saved["generation"]])
        assert "not_found" in command("window.activate", id="removed-window", seat=seat, success=False)
        assert "stale session" in rpc("aqueous.command", dict(action="window.close", session="0" * 32, id=window), success=False)

        assert ipc("aqueousTest", "workspaceRemember") == "true"
        active_before = [w["id"] for w in entities("workspace") if w["active"]]
        assert ipc("aqueousTest", "reconnect") == "OK"
        wait_for(lambda: not state().get("available", False))
        if not args.force_ext:
            assert ipc("aqueousTest", "workspaceReplay") == "REQUESTED"
        wait_for(lambda: workspace_status()["backend"] == "ext")
        wait_for(lambda: state().get("available", False))
        assert json.loads(ipc("aqueous", "status"))["session"] == session
        if not args.force_ext:
            wait_for(lambda: workspace_status()["backend"] == "aqueous")
            assert [w["id"] for w in entities("workspace") if w["active"]] == active_before, "unavailable workspace action was replayed after reconnect"
        time.sleep(1)
        assert state()["available"], "quiet subscription became unavailable"
        for client in clients:
            assert command("window.close", id=client["id"])["status"] == "accepted"
        wait_for(lambda: not [w for w in entities("window") if w["app_id"] == "aq-shell-test"])
        # Qt exits when its Wayland connection closes; it cannot answer another IPC call after logout.
        assert ipc("aqueousTest", "request", "aqueous.command", json.dumps(dict(action="session.exit", session=session))) == "REQUESTED"
        assert compositor.wait(timeout=10) == 0
        os.killpg(dms.pid, signal.SIGTERM)
        dms.wait(timeout=10)
        launches = [json.loads(line) for line in (base / "runtime-helper-calls").read_text().splitlines()]
        assert all(Path(call["parent"]).name == "aqueous-config" for call in launches), launches
        print(f"Retained configuration helper aqueousctl launches: {len(launches)}", flush=True)
        print("PASS: daemon/UI, duplicate identities, state/move eligibility, lock/unlock, keyboard, overview, screenshots, helper conflicts, keybinds, persistent IPC and zero runtime aqueousctl launches, workspace settings/widget/rename and orderly exit", flush=True)
    finally:
        for child in reversed(children):
            if child.poll() is None:
                os.killpg(child.pid, signal.SIGTERM)
        for child in reversed(children):
            try:
                child.wait(timeout=8)
            except subprocess.TimeoutExpired:
                os.killpg(child.pid, signal.SIGKILL)
                child.wait()


if __name__ == "__main__":
    main()
