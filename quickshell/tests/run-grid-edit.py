from pathlib import Path
import json
import os
import shutil
import subprocess
import tempfile

repo = Path(__file__).resolve().parents[2]
with tempfile.TemporaryDirectory(prefix="dms-grid-edit-test-") as temporary:
    root = Path(temporary)
    for name in ["qml", "runtime", "config/DankMaterialShell", "cache", "state", "data"]:
        (root / name).mkdir(parents=True, exist_ok=True)
    (root / "runtime").chmod(0o700)
    for source in (repo / "quickshell").iterdir():
        if source.name in ["shell.qml", ".qmlls.ini", "dms-plugins"]:
            continue
        (root / "qml" / source.name).symlink_to(source)
    (root / "qml/shell.qml").write_text((repo / "quickshell/tests/qml/grid-edit.qml").read_text())
    settings = {"configVersion": 27, "barConfigs": [], "showDock": False, "frameEnabled": False, "disableLockScreen": True, "loginctlLockIntegration": False, "enableDynamicTheming": False}
    for name in ["acMonitorTimeout", "acLockTimeout", "acSuspendTimeout", "batteryMonitorTimeout", "batteryLockTimeout", "batterySuspendTimeout"]:
        settings[name] = 0
    (root / "config/DankMaterialShell/settings.json").write_text(json.dumps(settings))
    env = dict(os.environ)
    for name in ["DMS_SOCKET", "WAYLAND_DISPLAY", "WAYLAND_SOCKET", "NIRI_SOCKET", "HYPRLAND_INSTANCE_SIGNATURE", "DISPLAY"]:
        env.pop(name, None)
    for name in ["runtime", "config", "cache", "state", "data"]:
        env["XDG_" + name.upper() + ("_DIR" if name == "runtime" else "_HOME")] = str(root / name)
    for name in ["home", "xdg"]:
        (root / name).mkdir()
    shutil.copytree(repo / "quickshell/tests/fixtures/share", root / "share")
    env.update(HOME=str(root / "home"), XDG_DATA_DIRS=str(root / "share"), XDG_CONFIG_DIRS=str(root / "xdg"), LANG="C.UTF-8", LC_ALL="C.UTF-8", TZ="UTC")
    env.update(QT_QPA_PLATFORM="wayland", QT_QUICK_BACKEND="software", WLR_BACKENDS="headless", WLR_RENDERER="pixman", DMS_DISABLE_HOT_RELOAD="1", DMS_DISABLE_MATUGEN="1", DBUS_SESSION_BUS_ADDRESS="unix:path=" + str(root / "no-session-bus"), DBUS_SYSTEM_BUS_ADDRESS="unix:path=" + str(root / "no-system-bus"))
    result = subprocess.run(["cage", "--", "qs", "-p", str(root / "qml")], env=env, capture_output=True, text=True, timeout=30)
    output = result.stdout + result.stderr
    print(output)
    if result.returncode or "GRID_EDIT_PASS" not in output or "GRID_EDIT_FAIL" in output or "Binding loop detected" in output:
        raise SystemExit(1)
