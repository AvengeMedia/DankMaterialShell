#!/usr/bin/env python3
"""Exercise keybind draft recovery on a private headless Aqueous display.

Requires a Pixman-compatible Aqueous build, matching helper/CLI, Quickshell,
and the DMS binary under test in --bin-dir. Never connects to the user display.
"""

import argparse
import json
import os
from pathlib import Path
import signal
import subprocess
import tempfile
import time


def wait_for(operation, timeout=20):
    deadline = time.monotonic() + timeout
    while time.monotonic() < deadline:
        value = operation()
        if value:
            return value
        time.sleep(0.1)
    raise AssertionError("timed out waiting for keybind state")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--bin-dir", type=Path, required=True)
    args = parser.parse_args()
    binaries = args.bin_dir.resolve()
    root = Path(__file__).resolve().parents[1]
    base = Path(tempfile.mkdtemp(prefix="dms-aqueous-keybinds-"))
    print(f"Evidence: {base}", flush=True)
    for name in ("runtime", "config/aqueous", "config/DankMaterialShell", "cache", "state", "home", "shell", "bin"):
        (base / name).mkdir(parents=True, mode=0o700)
    env = {key: value for key, value in os.environ.items() if not key.startswith("AQUEOUS_") and key not in ("DISPLAY", "WAYLAND_DISPLAY", "LD_PRELOAD", "DMS_SOCKET")}
    env.update(HOME=str(base / "home"), XDG_CONFIG_HOME=str(base / "config"), XDG_RUNTIME_DIR=str(base / "runtime"),
               XDG_CACHE_HOME=str(base / "cache"), XDG_STATE_HOME=str(base / "state"), PATH=str(base / "bin") + ":" + str(binaries) + ":" + env["PATH"],
               WLR_BACKENDS="headless", WLR_HEADLESS_OUTPUTS="1", WLR_RENDERER="pixman", QT_QPA_PLATFORM="wayland",
               QT_QUICK_BACKEND="software", GSETTINGS_BACKEND="memory", DMS_NO_DDC="1", DMS_DISABLE_MATUGEN="1", DMS_DISABLE_HOT_RELOAD="1",
               DBUS_SESSION_BUS_ADDRESS="unix:path=" + str(base / "missing-bus"), DBUS_SYSTEM_BUS_ADDRESS="unix:path=" + str(base / "missing-system-bus"))
    env["KEYBIND_TEST_HELPER"] = str(binaries / "aqueous-config")
    wrapper = base / "bin/aqueous-config"
    wrapper.write_text('''#!/usr/bin/python3
import os, sys
from pathlib import Path
with (Path(__file__).resolve().parents[1] / "helper-calls").open("a") as log:
    log.write(sys.argv[1] + "\\n")
os.execv(os.environ["KEYBIND_TEST_HELPER"], ["aqueous-config"] + sys.argv[1:])
''')
    wrapper.chmod(0o755)
    config = base / "config/aqueous"
    for name in ("wm", "rules", "layout", "input", "outputs", "appearance"):
        (config / f"{name}.toml").write_text("")
        env["AQUEOUS_" + ("CONFIG" if name == "wm" else name.upper())] = str(config / f"{name}.toml")
    (config / "wm.toml").write_text('[blur]\nenabled = true\n[keybinds.custom]\n"Super+Shift+S" = "old-screenshot"\n')
    (base / "config/DankMaterialShell/.firstlaunch").touch()
    (base / "config/DankMaterialShell/settings.json").write_text(json.dumps({"barConfigs": [], "blurEnabled": False}))
    shell = base / "shell"
    for path in (root / "quickshell").iterdir():
        if path.name not in ("shell.qml", ".qmlls.ini"):
            (shell / path.name).symlink_to(path)
    harness = '''
    property int savedCount: 0
    property int removedCount: 0
    Connections {
        target: KeybindsService
        function onBindSaved(key) { entrypoint.savedCount++; }
        function onBindRemoved(key) { entrypoint.removedCount++; }
    }
    PanelWindow {
        id: testWindow
        implicitWidth: 900
        implicitHeight: 1000
        KeybindTests.KeybindsTab {
            id: testTab
            anchors.fill: parent
            parentModal: testWindow
        }
    }
    function findObject(item, method) {
        if (typeof item?.[method] === "function") return item;
        for (const child of item?.children || []) {
            const found = findObject(child, method);
            if (found) return found;
        }
        return null;
    }
    function editItem(item) {
        if (typeof item?.updateEdit === "function" && (item.retainEdits || (!item.isNew && item.isExpanded))) return item;
        for (const child of item?.children || []) {
            const found = editItem(child);
            if (found) return found;
        }
        return null;
    }
    IpcHandler {
        target: "keybindTest"
        function status(): string {
            const editor = testTab;
            const item = entrypoint.editItem(testTab);
            return JSON.stringify({input: item ? {key: item.editKey, action: item.editAction, expanded: item.isExpanded} : null,
                generation: KeybindsService._rawData?.generation, loading: KeybindsService.loading,
                busy: KeybindsService.aqueousBusy, saved: entrypoint.savedCount, removed: entrypoint.removedCount,
                editor: editor ? {active: editor.hasEditDraft, busy: editor.editBusy, reviewing: editor.reviewingEdit,
                    error: editor.editError, draft: editor.editDraft} : null});
        }
        function open(key: string): string {
            const binding = KeybindsService.getFlatBinds().find(b => b.keys.some(k => k.key === key));
            if (!binding) return "MISSING";
            if (testTab.expandedKey !== binding.action)
                testTab.toggleExpanded(binding.action);
            return "OK";
        }
        function edit(key: string, action: string): string {
            const editor = testTab;
            const item = entrypoint.editItem(testTab);
            item.updateEdit({key: key, action: action});
            return "OK";
        }
        function filter(query: string): string {
            testTab.searchQuery = query;
            testTab._updateFiltered();
            return "OK";
        }
        function invoke(method: string): string {
            const editor = testTab;
            if (method === "save") entrypoint.editItem(testTab).doSave();
            else if (method === "refreshList") KeybindsService.loadBinds(false);
            else if (method === "remove") entrypoint.editItem(testTab).removeBind(entrypoint.editItem(testTab)._originalKey);
            else if (method === "cancelRemove") entrypoint.findObject(testTab, "showWithOptions")._activate(0);
            else if (method === "toggle") testTab.toggleExpanded(editor.editDraft.action);
            else if (method === "new") testTab.startNewBind();
            else if (method === "confirm") entrypoint.findObject(testTab, "showWithOptions")._activate(1);
            else if (method === "reopen") { testTab.visible = false; testTab.visible = true; }
            else if (method === "reload") testTab.reloadEdit();
            else if (method === "discard") testTab.discardEdit();
            else editor[method]();
            return "OK";
        }
    }
    '''
    source = (root / "quickshell/shell.qml").read_text().replace("import Quickshell\n", "import Quickshell\nimport Quickshell.Io\nimport qs.Modules.Settings as KeybindTests\n")
    (shell / "shell.qml").write_text(source.replace("    id: entrypoint", "    id: entrypoint\n" + harness))
    children = []

    def spawn(command, name):
        with (base / name).open("w") as log:
            process = subprocess.Popen(command, env=env, stdout=log, stderr=log, start_new_session=True)
        children.append(process)

    def run(command, success=True, input=None):
        result = subprocess.run(command, env=env, input=input, text=True, capture_output=True, timeout=20)
        assert (result.returncode == 0) == success, (command, result.stdout, result.stderr)
        return result.stdout

    def ipc(*args):
        return run([str(binaries / "dms"), "ipc", "call", "keybindTest", *args]).strip()

    def state():
        result = json.loads(ipc("status"))
        (base / "state.json").write_text(json.dumps(result, indent=2))
        return result

    def helper(operation, request=None):
        command = [str(binaries / "aqueous-config"), operation, "--shell", "dms"]
        if request:
            command += ["--request", "-"]
        return json.loads(run(command, input=json.dumps(request) if request else None))

    def apply(**changes):
        snapshot = helper("snapshot")
        return helper("apply", dict(protocol=1, expected_generation=snapshot["generation"], **changes))

    try:
        spawn([str(binaries / "aqueous"), "-no-xwayland", "-c", "true"], "compositor.log")
        display = wait_for(lambda: next((p for p in (base / "runtime").glob("wayland-*") if p.is_socket()), None))
        env["WAYLAND_DISPLAY"] = display.name
        env["DMS_SHELL_DIR"] = str(shell)
        spawn([str(binaries / "dms"), "-c", str(shell), "run"], "dms.log")
        wait_for(lambda: subprocess.run([str(binaries / "dms"), "ipc", "call", "keybindTest", "status"], env=env, capture_output=True).returncode == 0)
        wait_for(lambda: state().get("generation") and not state()["loading"])
        assert ipc("open", "Super+Shift+S") == "OK"
        ipc("edit", "Super+Shift+S", "spawn dms screenshot")
        before = state()["editor"]["draft"]
        assert before["data"]["action"] == "spawn dms screenshot"
        rules = '[[layer]]\nnamespace = "dms:*"\nblur = true\n'
        ipc("invoke", "toggle")
        assert not state()["input"]["expanded"]
        ipc("invoke", "toggle")
        assert state()["input"]["action"] == "spawn dms screenshot"
        apply(raw_files={"rules": rules})
        ipc("invoke", "save")
        wait_for(lambda: state()["saved"] == 1 and not state()["loading"])
        assert not state()["editor"]["active"]
        assert (config / "rules.toml").read_text() == rules
        assert helper("snapshot")["custom_keybinds"][0]["command"] == "dms screenshot"

        assert ipc("open", "Super+Shift+S") == "OK"
        ipc("edit", "Super+Shift+S", "spawn dms screenshot full")
        apply(custom_keybind_changes=[{"op": "add", "chord": "Super+F12", "command": "external-command"}])
        ipc("invoke", "save")
        wait_for(lambda: state()["editor"]["reviewing"] and not state()["busy"])
        assert state()["saved"] == 1
        ipc("invoke", "refreshList")
        wait_for(lambda: not state()["loading"])
        ipc("invoke", "reopen")
        ipc("filter", "no-matching-shortcut")
        assert state()["input"] is None
        ipc("filter", "")
        assert state()["input"]["action"] == "spawn dms screenshot full"
        assert state()["editor"]["draft"]["data"]["action"] == "spawn dms screenshot full"
        ipc("invoke", "reload")
        wait_for(lambda: not state()["editor"]["busy"])
        ipc("invoke", "acceptReview")
        assert not state()["editor"]["reviewing"]
        ipc("invoke", "save")
        wait_for(lambda: state()["saved"] == 2 and not state()["loading"])
        snapshot = helper("snapshot")
        assert any(b["command"] == "external-command" for b in snapshot["custom_keybinds"])

        assert ipc("open", "Super+Shift+S") == "OK"
        ipc("edit", "Super+Shift+S", "spawn dms screenshot full")
        ipc("invoke", "remove")
        ipc("invoke", "cancelRemove")
        assert state()["editor"]["draft"]["operation"] == "set"
        ipc("invoke", "remove")
        apply(custom_keybind_changes=[{"op": "add", "chord": "Super+F11", "command": "another-external-command"}])
        ipc("invoke", "confirm")
        wait_for(lambda: state()["editor"]["reviewing"])
        assert state()["removed"] == 0
        ipc("invoke", "reload")
        wait_for(lambda: not state()["editor"]["busy"])
        ipc("invoke", "acceptReview")
        assert state()["removed"] == 0
        ipc("invoke", "confirm")
        wait_for(lambda: state()["removed"] == 1 and not state()["loading"])
        snapshot = helper("snapshot")
        assert all(b["chord"] != "Super+Shift+S" for b in snapshot["custom_keybinds"])

        assert ipc("open", "Super+F12") == "OK"
        ipc("edit", "Super+F12", "spawn discarded-draft")
        removed = next(b for b in snapshot["custom_keybinds"] if b["chord"] == "Super+F12")
        apply(custom_keybind_changes=[{"op": "delete", "id": removed["id"]}])
        ipc("invoke", "save")
        wait_for(lambda: state()["editor"]["reviewing"])
        ipc("invoke", "reload")
        wait_for(lambda: not state()["editor"]["busy"])
        ipc("invoke", "acceptReview")
        assert state()["editor"]["reviewing"], "removed target was silently accepted as a new binding"
        assert state()["editor"]["draft"]["data"]["action"] == "spawn discarded-draft"
        ipc("invoke", "discard")
        wait_for(lambda: not state()["loading"])
        assert not state()["editor"]["active"]
        assert all(b["command"] != "discarded-draft" for b in helper("snapshot")["custom_keybinds"])

        ipc("invoke", "new")
        ipc("edit", "Super+F10", "spawn inline-new-binding")
        ipc("invoke", "save")
        wait_for(lambda: state()["saved"] == 3 and not state()["loading"])
        assert state()["input"]["expanded"]
        ipc("edit", "Super+F10", "spawn inline-second-save")
        ipc("invoke", "save")
        wait_for(lambda: state()["saved"] == 4 and not state()["loading"])
        assert any(b["command"] == "inline-second-save" for b in helper("snapshot")["custom_keybinds"])

        stale = json.loads(run([str(binaries / "dms"), "keybinds", "remove", "aqueous", "Super+F12", "--expected-generation", before["baseline"]["generation"], "--json"], success=False))
        assert stale["success"] is False and stale["code"] == "external_change"
        settled = state()
        calls = (base / "helper-calls").read_text()
        time.sleep(1)
        assert state() == settled
        assert (base / "helper-calls").read_text() == calls, "idle UI launched helper processes"
        assert (config / "rules.toml").read_text() == rules
        print("PASS: shared inline editor, repeated saves, filtering/collapse draft retention, blur conflict, review/discard, removal cancellation/reconfirmation, idle and structured CLI conflict", flush=True)
    finally:
        for child in reversed(children):
            if child.poll() is None:
                os.killpg(child.pid, signal.SIGTERM)
                child.wait(timeout=8)


if __name__ == "__main__":
    main()
