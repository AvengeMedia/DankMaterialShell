from concurrent.futures import ThreadPoolExecutor
from pathlib import Path
import json
import os
import re
import shutil
import socket
import subprocess
import tempfile
import time
import sys

repo = Path(__file__).resolve().parents[2]


def settings_config_version():
    source = (repo / "quickshell/Common/SettingsData.qml").read_text()
    match = re.search(r"readonly property int settingsConfigVersion: (\d+)", source)
    return int(match.group(1))


def read_line(fd):
    data = b""
    while not data.endswith(b"\n"):
        chunk = os.read(fd, 300)
        if not chunk:
            break
        data += chunk
    os.close(fd)
    return data.decode().strip()


def mesa_egl_vendor():
    for directory in ["/etc/glvnd/egl_vendor.d", "/usr/share/glvnd/egl_vendor.d"]:
        for path in sorted(Path(directory).glob("*.json")):
            try:
                library = json.loads(path.read_text())["ICD"]["library_path"]
            except (OSError, ValueError, KeyError):
                continue
            if "libEGL_mesa" in library:
                return str(path)
    return None


suite = len(sys.argv) > 1 and sys.argv[1] == "--suite"
fixtures = [name for name in sys.argv[2:] if not name.startswith("--")] if suite else [sys.argv[1] if len(sys.argv) > 1 else "quickshell/tests/qml/instance-routing.qml"]
if not fixtures:
    raise SystemExit("usage: run-surface-fixture.py --suite fixture.qml [fixture.qml ...] [--mpris] [--artwork]")
log_path = Path(sys.argv[2]) if not suite and len(sys.argv) > 2 and not sys.argv[2].startswith("--") else None
with tempfile.TemporaryDirectory(prefix="dms-surface-test-") as temporary:
    root = Path(temporary)
    for name in ["qml", "runtime", "config/DankMaterialShell", "cache", "state", "data"]:
        (root / name).mkdir(parents=True, exist_ok=True)
    (root / "runtime").chmod(0o700)
    def link_tree(target, fixture):
        target.mkdir(parents=True, exist_ok=True)
        for source in (repo / "quickshell").iterdir():
            if source.name in ["shell.qml", ".qmlls.ini", "dms-plugins"]:
                continue
            (target / source.name).symlink_to(source)
        (target / "shell.qml").write_text((repo / fixture).read_text())

    if not suite:
        link_tree(root / "qml", fixtures[0])
    settings = {"configVersion": settings_config_version(), "barConfigs": [], "showDock": False, "frameEnabled": False, "disableLockScreen": True, "loginctlLockIntegration": False, "enableDynamicTheming": False}
    for name in ["acMonitorTimeout", "acLockTimeout", "acSuspendTimeout", "batteryMonitorTimeout", "batteryLockTimeout", "batterySuspendTimeout"]:
        settings[name] = 0
    if os.environ.get("DMS_FIXTURE_SETTINGS"):
        settings.update(json.loads(Path(os.environ["DMS_FIXTURE_SETTINGS"]).read_text()))
    (root / "config/DankMaterialShell/settings.json").write_text(json.dumps(settings))
    if os.environ.get("DMS_FIXTURE_PLUGIN_SETTINGS"):
        (root / "config/DankMaterialShell/plugin_settings.json").write_text(Path(os.environ["DMS_FIXTURE_PLUGIN_SETTINGS"]).read_text())
    if os.environ.get("DMS_FIXTURE_PLUGINS"):
        plugins = root / "config/DankMaterialShell/plugins"
        plugins.mkdir()
        for entry in Path(os.environ["DMS_FIXTURE_PLUGINS"]).iterdir():
            if entry.name.startswith("."):
                continue
            (plugins / entry.name).symlink_to(entry.resolve())
    env = dict(os.environ)
    for name in ["WAYLAND_DISPLAY", "WAYLAND_SOCKET", "NIRI_SOCKET", "HYPRLAND_INSTANCE_SIGNATURE", "SWAYSOCK", "I3SOCK", "MANGO_SOCKET", "MIRACLESOCK", "PULSE_SERVER", "PIPEWIRE_REMOTE", "DISPLAY", "QSG_USE_SIMPLE_ANIMATION_DRIVER", "QT_QPA_PLATFORMTHEME", "QT_STYLE_OVERRIDE", "QT_SCALE_FACTOR", "QT_SCREEN_SCALE_FACTORS", "QT_AUTO_SCREEN_SCALE_FACTOR", "QT_ENABLE_HIGHDPI_SCALING", "QT_FONT_DPI", "GTK_THEME", "LANGUAGE", "XDG_CURRENT_DESKTOP", "XDG_SESSION_DESKTOP", "XDG_SESSION_TYPE", "DESKTOP_SESSION"]:
        env.pop(name, None)
    for name in list(env):
        if name.startswith(("DMS_", "QS_", "LC_", "XCURSOR_")) and not name.startswith("DMS_FIXTURE_"):
            del env[name]
    for name in ["home", "xdg", "qmlcache"]:
        (root / name).mkdir()
    shutil.copytree(repo / "quickshell/tests/fixtures/share", root / "share")
    env.update(HOME=str(root / "home"), XDG_DATA_DIRS=str(root / "share"), XDG_CONFIG_DIRS=str(root / "xdg"), QML_DISK_CACHE_PATH=str(root / "qmlcache"), LANG="C.UTF-8", LC_ALL="C.UTF-8", TZ="UTC")
    for name in ["runtime", "config", "cache", "state", "data"]:
        env["XDG_" + name.upper() + ("_DIR" if name == "runtime" else "_HOME")] = str(root / name)
    env.update(QT_QPA_PLATFORM="wayland", QT_LOGGING_RULES="qml.debug=true", LIBGL_ALWAYS_SOFTWARE="1", DMS_DISABLE_HOT_RELOAD="1", DMS_DISABLE_MATUGEN="1", DBUS_SESSION_BUS_ADDRESS="unix:path=" + str(root / "no-session-bus"), DBUS_SYSTEM_BUS_ADDRESS="unix:path=" + str(root / "no-system-bus"), PULSE_SERVER="unix:" + str(root / "no-pulse"), PIPEWIRE_REMOTE="no-pipewire")
    # glvnd loads the nvidia vendor first, which powers up a sleeping dGPU
    mesa_vendor = mesa_egl_vendor()
    if mesa_vendor:
        env["__EGL_VENDOR_LIBRARY_FILENAMES"] = mesa_vendor
    if "--capture" in sys.argv:
        env["DMS_FIXTURE_CAPTURE"] = "1"
    if "--corners" in sys.argv:
        env["DMS_FIXTURE_CORNERS"] = "1"
    if "--baseline" in sys.argv:
        env["DMS_FIXTURE_BASELINE"] = "1"
    (root / "niri.kdl").write_text('prefer-no-csd\nhotkey-overlay { skip-at-startup; }\nlayout { gaps 0; border { off; }; focus-ring { off; }; default-column-width { proportion 1.0; }; }\n' + ('output \"winit\" { scale 1.25; }\n' if '--fractional' in sys.argv else ''))
    processes = []
    failed_logs = []
    try:
        read_fd, write_fd = os.pipe()
        xvfb = subprocess.Popen(["Xvfb", "-displayfd", str(write_fd), "-screen", "0", "1280x800x24", "-nolisten", "tcp"], env=env, pass_fds=(write_fd,), stdout=subprocess.DEVNULL, stderr=(root / "xvfb.log").open("w"))
        processes.append(xvfb)
        os.close(write_fd)
        display = read_line(read_fd)
        if not display:
            raise RuntimeError("Xvfb failed to start: " + (root / "xvfb.log").read_text()[-3000:])
        env["DISPLAY"] = ":" + display
        def start_niri(runtime, log):
            runtime.mkdir(parents=True, exist_ok=True)
            runtime.chmod(0o700)
            local = dict(env)
            local["XDG_RUNTIME_DIR"] = str(runtime)
            niri = subprocess.Popen(["niri", "-c", str(root / "niri.kdl")], env=local, stdout=subprocess.DEVNULL, stderr=log.open("w"))
            processes.append(niri)
            for attempt in range(100):
                sockets = [path for path in runtime.glob("wayland-*") if not path.name.endswith(".lock")]
                ipc = list(runtime.glob("niri.*.sock"))
                if sockets and ipc:
                    local.update(WAYLAND_DISPLAY=sockets[0].name, NIRI_SOCKET=str(ipc[0]))
                    return local, niri
                if niri.poll() is not None:
                    raise RuntimeError("isolated niri failed to start: " + log.read_text()[-3000:] + "\nXvfb: " + (root / "xvfb.log").read_text()[-3000:])
                time.sleep(0.1)
            raise RuntimeError("isolated niri startup timed out: " + log.read_text()[-3000:])

        if not suite:
            env, niri = start_niri(root / "runtime", root / "niri.log")
        if "--hyprland" in sys.argv:
            (root / "hyprland.conf").write_text("monitor = ,1280x800@60,auto," + ("1.25" if "--fractional" in sys.argv else "1") + "\ngeneral {\n gaps_in = 0\n gaps_out = 0\n border_size = 0\n}\nmisc {\n disable_hyprland_logo = true\n disable_splash_rendering = true\n}\n")
            hypr_log = (root / "hyprland.log").open("w")
            hypr = subprocess.Popen(["Hyprland", "--config", str(root / "hyprland.conf")], env=env, stdout=hypr_log, stderr=subprocess.STDOUT)
            processes.append(hypr)
            for attempt in range(100):
                signatures = list((root / "runtime/hypr").glob("*/.socket.sock"))
                child_sockets = [path for path in (root / "runtime").glob("wayland-*") if path.name != env["WAYLAND_DISPLAY"] and not path.name.endswith(".lock")]
                if signatures and child_sockets:
                    break
                if hypr.poll() is not None:
                    raise RuntimeError("isolated Hyprland failed to start: " + (root / "hyprland.log").read_text()[-6000:])
                time.sleep(0.1)
            else:
                raise RuntimeError("isolated Hyprland startup timed out: " + (root / "hyprland.log").read_text()[-6000:])
            env.pop("NIRI_SOCKET", None)
            env.update(WAYLAND_DISPLAY=child_sockets[0].name, HYPRLAND_INSTANCE_SIGNATURE=signatures[0].parent.name)
        # a bus with service dirs activates gvfs and friends, whose fuse mounts break the temporary directory cleanup
        (root / "dbus.conf").write_text('<!DOCTYPE busconfig PUBLIC "-//freedesktop//DTD D-Bus Bus Configuration 1.0//EN" "http://www.freedesktop.org/standards/dbus/1.0/busconfig.dtd">\n<busconfig><type>session</type><listen>unix:tmpdir=' + str(root) + '</listen><policy context="default"><allow send_destination="*" eavesdrop="true"/><allow eavesdrop="true"/><allow own="*"/></policy></busconfig>\n')

        def start_dbus(target):
            if shutil.which("dbus-daemon"):
                read_fd, write_fd = os.pipe()
                dbus = subprocess.Popen(["dbus-daemon", "--config-file=" + str(root / "dbus.conf"), "--nofork", "--print-address=" + str(write_fd)], env=target, pass_fds=(write_fd,), stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
                processes.append(dbus)
                os.close(write_fd)
                target["DBUS_SESSION_BUS_ADDRESS"] = read_line(read_fd)
                return dbus
            if not shutil.which("dbus-broker-launch"):
                raise RuntimeError("bus fixtures need dbus-daemon or dbus-broker-launch")
            # dbus-broker only takes its listener through systemd socket activation, and the launcher joins its own bus through the session address
            path = Path(tempfile.mkdtemp(prefix="bus-", dir=root)) / "socket"
            address = "unix:path=" + str(path)
            listener = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
            listener.bind(str(path))
            listener.listen()
            fd = listener.fileno()
            move = f"exec 3<&{fd} {fd}<&-; " if fd != 3 else ""
            dbus = subprocess.Popen(["sh", "-c", move + 'LISTEN_PID=$$ LISTEN_FDS=1 exec dbus-broker-launch --scope user --config-file "$0"', str(root / "dbus.conf")], env=dict(target, DBUS_SESSION_BUS_ADDRESS=address), pass_fds=(fd,), stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
            processes.append(dbus)
            listener.close()
            target["DBUS_SESSION_BUS_ADDRESS"] = address
            return dbus

        def start_mpris_player(target):
            player = subprocess.Popen([sys.executable, str(repo / "quickshell/tests/fixtures/mpris_player.py")] + (["--artwork"] if "--artwork" in sys.argv else []), env=target, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
            processes.append(player)
            return player

        if "--dbus" in sys.argv or ("--mpris" in sys.argv and not suite):
            start_dbus(env)
        if "--mpris" in sys.argv and not suite:
            start_mpris_player(env)
        if "--dbus" in sys.argv:
            tray_items = ["firefox:Mozilla Firefox:firefox:0", "kitty:Kitty:utilities-terminal:0", "nm-applet:Network:network-wireless:1", "steam:Steam:steam:0"]
            sni_log = (root / "sni.log").open("w")
            sni = subprocess.Popen([sys.executable, str(repo / "quickshell/tests/fixtures/sni_item.py")] + tray_items, env=env, stdout=sni_log, stderr=subprocess.STDOUT)
            processes.append(sni)
        if "--capture" in sys.argv and "--hyprland" in sys.argv:
            raise SystemExit("--capture drives niri msg and cannot run under --hyprland")
        if "--capture" in sys.argv and (len(sys.argv) < 3 or sys.argv[2].startswith("--")):
            raise SystemExit("--capture needs an output log path as the second argument")
        if "--capture" in sys.argv:
            process = subprocess.Popen(["qs", "-p", str(root / "qml")], env=env, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True)
            processes.append(process)
            captured = []
            snapshot = None
            for line in process.stdout:
                captured.append(line)
                if "LAYOUT_SNAPSHOT " in line:
                    snapshot = json.loads(line.split("LAYOUT_SNAPSHOT ", 1)[1])
                if "CAPTURE_READY" not in line:
                    continue
                time.sleep(0.7)
                layers = json.loads(subprocess.run(["niri", "msg", "-j", "layers"], env=env, capture_output=True, text=True, check=True, timeout=10).stdout)
                windows = json.loads(subprocess.run(["niri", "msg", "-j", "windows"], env=env, capture_output=True, text=True, check=True, timeout=10).stdout)
                probe = next(window for window in windows if window["title"] == "reservation probe")
                captured.append("COMPOSITOR_SNAPSHOT " + json.dumps({"caseIndex": snapshot["caseIndex"], "layout": probe["layout"], "layers": layers}) + "\n")
                if snapshot["caseIndex"] in [1, 3, 17, 35, 48, 73, 74, 75]:
                    screenshot = Path(sys.argv[2]).with_suffix("." + str(snapshot["caseIndex"]) + ".png")
                    subprocess.run(["niri", "msg", "action", "screenshot-screen", "--show-pointer", "false", "--path", str(screenshot)], env=env, capture_output=True, check=True, timeout=10)
                if "--baseline" not in sys.argv:
                    reservations = snapshot["reservations"]
                    size = probe["layout"]["window_size"]
                    expected = [snapshot["screen"]["width"] - reservations["left"] - reservations["right"], snapshot["screen"]["height"] - reservations["top"] - reservations["bottom"]]
                    if any(abs(actual - target) > 2 for actual, target in zip(size, expected)):
                        captured.append("FIXTURE_FAIL compositor reservation " + json.dumps({"case": snapshot["caseIndex"], "expected": expected, "actual": size}) + "\n")
                        break
                subprocess.run(["qs", "ipc", "-p", str(root / "qml"), "call", "probe", "next"], env=env, capture_output=True, check=True, timeout=10)
            if process.poll() is None:
                process.terminate()
            process.wait(timeout=10)
            output = "".join(captured)
            returncode = process.returncode
        elif "--measure" in sys.argv:
            process = subprocess.Popen(["qs", "-p", str(root / "qml")], env=env, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True)
            processes.append(process)
            startup = []
            for line in process.stdout:
                startup.append(line)
                if "RESOURCE_READY" in line:
                    break
            else:
                raise RuntimeError("resource fixture failed: " + "".join(startup))
            def sample():
                fields = Path(f"/proc/{process.pid}/stat").read_text().split()
                memory = dict(line.split(":", 1) for line in Path(f"/proc/{process.pid}/smaps_rollup").read_text().splitlines()[1:])
                return {"ticks": int(fields[13]) + int(fields[14]), "pss_kb": int(memory["Pss"].split()[0]), "rss_kb": int(memory["Rss"].split()[0]), "threads": len(list(Path(f"/proc/{process.pid}/task").iterdir())), "children": len(Path(f"/proc/{process.pid}/task/{process.pid}/children").read_text().split())}
            def ipc(method):
                subprocess.run(["qs", "ipc", "-p", str(root / "qml"), "call", "probe", method], env=env, capture_output=True, check=True, timeout=10)
            time.sleep(3)
            start = sample()
            time.sleep(5)
            idle = sample()
            ipc("play")
            time.sleep(5)
            active = sample()
            ipc("stop")
            time.sleep(2)
            settled = sample()
            layers = subprocess.run(["niri", "msg", "-j", "layers"], env=env, capture_output=True, text=True, check=True).stdout
            measurement = {"idle": idle, "active": active, "settled": settled, "idle_ticks": idle["ticks"] - start["ticks"], "active_ticks": active["ticks"] - idle["ticks"], "sample_seconds": 5, "clock_ticks": os.sysconf("SC_CLK_TCK"), "layers": json.loads(layers)}
            ipc("done")
            tail, _ = process.communicate(timeout=10)
            output = "".join(startup) + tail
            output += "\nRESOURCE_MEASUREMENT " + json.dumps(measurement) + "\n"
            if measurement["active_ticks"] <= measurement["idle_ticks"]:
                output += "FIXTURE_FAIL popout animation did not consume more cpu than idle\n"
            if settled["children"] != idle["children"] or settled["threads"] != idle["threads"]:
                output += "FIXTURE_FAIL processes or threads leaked across the animation: " + json.dumps({"idle": idle, "settled": settled}) + "\n"
            returncode = process.returncode
        else:
            def run_fixture(index, fixture):
                home = root / f"fixture{index}"
                started = time.monotonic()
                link_tree(home / "qml", fixture)
                bus = dict(env)
                dbus = start_dbus(bus) if "--mpris" in sys.argv else None
                player = start_mpris_player(bus) if dbus else None
                fixture_env, niri = start_niri(home / "runtime", home / "niri.log")
                if dbus:
                    fixture_env["DBUS_SESSION_BUS_ADDRESS"] = bus["DBUS_SESSION_BUS_ADDRESS"]
                for name in ["config", "state", "data"]:
                    shutil.copytree(root / name, home / name, symlinks=True)
                    fixture_env["XDG_" + name.upper() + "_HOME"] = str(home / name)
                (home / "cache").mkdir()
                fixture_env["XDG_CACHE_HOME"] = str(home / "cache")
                try:
                    result = subprocess.run(["qs", "-p", str(home / "qml")], env=fixture_env, capture_output=True, text=True, timeout=60)
                    output = result.stdout + result.stderr
                    failed = result.returncode or "FIXTURE_PASS" not in output
                except subprocess.TimeoutExpired as expired:
                    output = "".join(part.decode() if isinstance(part, bytes) else part for part in [expired.stdout or "", expired.stderr or ""]) + "\nFIXTURE_FAIL timeout\n"
                    failed = True
                finally:
                    niri.terminate()
                    niri.wait()
                    if player:
                        player.terminate()
                        player.wait()
                    if dbus:
                        dbus.terminate()
                        dbus.wait()
                if failed:
                    output += "\nFIXTURE_FAIL " + fixture + "\nniri: " + (home / "niri.log").read_text()[-3000:] + "\n"
                return output + f"\nFIXTURE_TIME {Path(fixture).stem}: {time.monotonic() - started:.2f}s\n", failed

            if not suite:
                started = time.monotonic()
                try:
                    result = subprocess.run(["qs", "-p", str(root / "qml")], env=env, capture_output=True, text=True, timeout=180)
                    output = result.stdout + result.stderr
                    returncode = int(bool(result.returncode) or "FIXTURE_PASS" not in output)
                except subprocess.TimeoutExpired as expired:
                    output = "".join(part.decode() if isinstance(part, bytes) else part for part in [expired.stdout or "", expired.stderr or ""]) + "\nFIXTURE_FAIL timeout\n"
                    returncode = 1
            else:
                default_jobs = max(1, min(8, len(os.sched_getaffinity(0)) // 2))
                jobs = min(len(fixtures), int(os.environ.get("DMS_FIXTURE_JOBS", default_jobs)))
                with ThreadPoolExecutor(max_workers=jobs) as pool:
                    results = list(pool.map(run_fixture, range(len(fixtures)), fixtures))
                returncode = int(any(failed for _, failed in results))
                output = "\n".join(text for text, _ in results)
                failed_logs = [text for text, failed in results if failed]
        if "--dbus" in sys.argv:
            output += "\nSNI_CLIENT " + (root / "sni.log").read_text().replace("\n", "\nSNI_CLIENT ")
        if log_path:
            log_path.write_text(output)
        print("\n".join(line for line in output.splitlines() if any(token in line for token in ["FIXTURE_", "Error", "ERROR", "read-only", "Binding loop", "unavailable"])))
        print("snapshots:", output.count("LAYOUT_SNAPSHOT"))
        for text in failed_logs:
            print("---- full log of failed fixture ----\n" + text)
        if returncode or "FIXTURE_PASS" not in output or any(token in output for token in ["FIXTURE_FAIL", "ReferenceError:", "TypeError:", "Binding loop", "Cannot assign", "is not a function"]):
            raise SystemExit(1)
    finally:
        for process in reversed(processes):
            process.terminate()
            try:
                process.wait(timeout=5)
            except subprocess.TimeoutExpired:
                process.kill()
                process.wait()
