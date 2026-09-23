from concurrent.futures import ThreadPoolExecutor, as_completed
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


fixtures = [name for name in sys.argv[1:] if not name.startswith("--")]
if not fixtures:
    raise SystemExit("usage: run-surface-fixture.py [--mpris] [--artwork] fixture.qml [fixture.qml ...]")
mpris = "--mpris" in sys.argv
with tempfile.TemporaryDirectory(prefix="dms-surface-test-") as temporary:
    root = Path(temporary)
    for name in ["config/DankMaterialShell", "state", "data", "cache", "home", "xdg"]:
        (root / name).mkdir(parents=True)
    (root / "runtime").mkdir(mode=0o700)
    settings = {"configVersion": settings_config_version(), "barConfigs": [], "showDock": False, "frameEnabled": False, "disableLockScreen": True, "loginctlLockIntegration": False, "enableDynamicTheming": False}
    for name in ["acMonitorTimeout", "acLockTimeout", "acSuspendTimeout", "batteryMonitorTimeout", "batteryLockTimeout", "batterySuspendTimeout"]:
        settings[name] = 0
    (root / "config/DankMaterialShell/settings.json").write_text(json.dumps(settings))
    env = dict(os.environ)
    for name in ["WAYLAND_DISPLAY", "WAYLAND_SOCKET", "NIRI_SOCKET", "HYPRLAND_INSTANCE_SIGNATURE", "SWAYSOCK", "I3SOCK", "MANGO_SOCKET", "MIRACLESOCK", "PULSE_SERVER", "PIPEWIRE_REMOTE", "DISPLAY", "QSG_USE_SIMPLE_ANIMATION_DRIVER", "QT_QPA_PLATFORMTHEME", "QT_STYLE_OVERRIDE", "QT_SCALE_FACTOR", "QT_SCREEN_SCALE_FACTORS", "QT_AUTO_SCREEN_SCALE_FACTOR", "QT_ENABLE_HIGHDPI_SCALING", "QT_FONT_DPI", "GTK_THEME", "LANGUAGE", "XDG_CURRENT_DESKTOP", "XDG_SESSION_DESKTOP", "XDG_SESSION_TYPE", "DESKTOP_SESSION"]:
        env.pop(name, None)
    for name in list(env):
        if name.startswith(("DMS_", "QS_", "LC_", "XCURSOR_")):
            del env[name]
    shutil.copytree(repo / "quickshell/tests/fixtures/share", root / "share")
    env.update(HOME=str(root / "home"), XDG_DATA_DIRS=str(root / "share"), XDG_CONFIG_DIRS=str(root / "xdg"), XDG_RUNTIME_DIR=str(root / "runtime"), LANG="C.UTF-8", LC_ALL="C.UTF-8", TZ="UTC")
    env.update({"XDG_" + name.upper() + "_HOME": str(root / name) for name in ["config", "state", "data", "cache"]})
    env.update(QT_QPA_PLATFORM="wayland", QT_LOGGING_RULES="qml.debug=true", LIBGL_ALWAYS_SOFTWARE="1", DMS_DISABLE_HOT_RELOAD="1", DMS_DISABLE_MATUGEN="1", DBUS_SESSION_BUS_ADDRESS="unix:path=" + str(root / "no-session-bus"), DBUS_SYSTEM_BUS_ADDRESS="unix:path=" + str(root / "no-system-bus"), PULSE_SERVER="unix:" + str(root / "no-pulse"), PIPEWIRE_REMOTE="no-pipewire")
    # glvnd loads the nvidia vendor first, which powers up a sleeping dGPU
    mesa_vendor = mesa_egl_vendor()
    if mesa_vendor:
        env["__EGL_VENDOR_LIBRARY_FILENAMES"] = mesa_vendor
    (root / "niri.kdl").write_text('prefer-no-csd\nhotkey-overlay { skip-at-startup; }\nlayout { gaps 0; border { off; }; focus-ring { off; }; default-column-width { proportion 1.0; }; }\n')
    # a bus with service dirs activates gvfs and friends, whose fuse mounts break the temporary directory cleanup
    (root / "dbus.conf").write_text('<!DOCTYPE busconfig PUBLIC "-//freedesktop//DTD D-Bus Bus Configuration 1.0//EN" "http://www.freedesktop.org/standards/dbus/1.0/busconfig.dtd">\n<busconfig><type>session</type><listen>unix:tmpdir=' + str(root) + '</listen><policy context="default"><allow send_destination="*" eavesdrop="true"/><allow eavesdrop="true"/><allow own="*"/></policy></busconfig>\n')
    xvfb = None
    try:
        read_fd, write_fd = os.pipe()
        xvfb = subprocess.Popen(["Xvfb", "-displayfd", str(write_fd), "-screen", "0", "1280x800x24", "-nolisten", "tcp"], env=env, pass_fds=(write_fd,), stdout=subprocess.DEVNULL, stderr=(root / "xvfb.log").open("w"))
        os.close(write_fd)
        display = read_line(read_fd)
        if not display:
            raise RuntimeError("Xvfb failed to start: " + (root / "xvfb.log").read_text()[-3000:])
        env["DISPLAY"] = ":" + display

        def start_niri(home, processes):
            runtime = home / "runtime"
            runtime.mkdir(mode=0o700)
            log = home / "niri.log"
            local = dict(env, XDG_RUNTIME_DIR=str(runtime))
            niri = subprocess.Popen(["niri", "-c", str(root / "niri.kdl")], env=local, stdout=subprocess.DEVNULL, stderr=log.open("w"))
            processes.append(niri)
            for attempt in range(100):
                sockets = [path for path in runtime.glob("wayland-*") if not path.name.endswith(".lock")]
                ipc = list(runtime.glob("niri.*.sock"))
                if sockets and ipc:
                    local.update(WAYLAND_DISPLAY=sockets[0].name, NIRI_SOCKET=str(ipc[0]))
                    return local
                if niri.poll() is not None:
                    raise RuntimeError("isolated niri failed to start: " + log.read_text()[-3000:])
                time.sleep(0.1)
            raise RuntimeError("isolated niri startup timed out: " + log.read_text()[-3000:])

        def start_dbus(target, processes):
            if shutil.which("dbus-daemon"):
                read_fd, write_fd = os.pipe()
                processes.append(subprocess.Popen(["dbus-daemon", "--config-file=" + str(root / "dbus.conf"), "--nofork", "--print-address=" + str(write_fd)], env=target, pass_fds=(write_fd,), stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL))
                os.close(write_fd)
                target["DBUS_SESSION_BUS_ADDRESS"] = read_line(read_fd)
                return
            if not shutil.which("dbus-broker-launch"):
                raise RuntimeError("--mpris fixtures need dbus-daemon or dbus-broker-launch")
            # dbus-broker only takes its listener through systemd socket activation, and the launcher joins its own bus through the session address
            path = Path(tempfile.mkdtemp(prefix="bus-", dir=root)) / "socket"
            address = "unix:path=" + str(path)
            listener = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
            listener.bind(str(path))
            listener.listen()
            fd = listener.fileno()
            move = f"exec 3<&{fd} {fd}<&-; " if fd != 3 else ""
            processes.append(subprocess.Popen(["sh", "-c", move + 'LISTEN_PID=$$ LISTEN_FDS=1 exec dbus-broker-launch --scope user --config-file "$0"', str(root / "dbus.conf")], env=dict(target, DBUS_SESSION_BUS_ADDRESS=address), pass_fds=(fd,), stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL))
            listener.close()
            target["DBUS_SESSION_BUS_ADDRESS"] = address

        def run_fixture(index, fixture):
            started = time.monotonic()
            home = root / f"fixture{index}"
            (home / "qml").mkdir(parents=True)
            for source in (repo / "quickshell").iterdir():
                if source.name not in ["shell.qml", ".qmlls.ini", "dms-plugins"]:
                    (home / "qml" / source.name).symlink_to(source)
            (home / "qml/shell.qml").write_text((repo / fixture).read_text())
            for name in ["config", "state", "data"]:
                shutil.copytree(root / name, home / name, symlinks=True)
            (home / "cache").mkdir()
            processes = []
            try:
                fixture_env = start_niri(home, processes)
                fixture_env.update({"XDG_" + name.upper() + "_HOME": str(home / name) for name in ["config", "state", "data", "cache"]})
                if mpris:
                    start_dbus(fixture_env, processes)
                    processes.append(subprocess.Popen([sys.executable, str(repo / "quickshell/tests/fixtures/mpris_player.py")] + (["--artwork"] if "--artwork" in sys.argv else []), env=fixture_env, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL))
                result = subprocess.run(["qs", "-p", str(home / "qml")], env=fixture_env, capture_output=True, text=True, timeout=180)
                output = result.stdout + result.stderr
                failed = bool(result.returncode) or "FIXTURE_PASS" not in output or "FIXTURE_FAIL" in output
            except subprocess.TimeoutExpired as expired:
                output = "".join(part.decode() if isinstance(part, bytes) else part for part in [expired.stdout or "", expired.stderr or ""]) + "\nFIXTURE_FAIL timed out after 60s\n"
                failed = True
            except RuntimeError as error:
                output = str(error)
                failed = True
            finally:
                for process in reversed(processes):
                    process.terminate()
                    try:
                        process.wait(timeout=5)
                    except subprocess.TimeoutExpired:
                        process.kill()
                        process.wait()
            if failed and (home / "niri.log").exists():
                output += "\nniri: " + (home / "niri.log").read_text()[-3000:]
            return Path(fixture).stem, failed, time.monotonic() - started, output

        jobs = min(len(fixtures), int(os.environ.get("DMS_FIXTURE_JOBS", max(1, min(8, len(os.sched_getaffinity(0)) // 2)))))
        failures = 0
        with ThreadPoolExecutor(max_workers=jobs) as pool:
            for future in as_completed([pool.submit(run_fixture, index, fixture) for index, fixture in enumerate(fixtures)]):
                name, failed, elapsed, output = future.result()
                print(f"{'FAIL' if failed else 'PASS'} {name} {elapsed:.2f}s", flush=True)
                if failed:
                    failures += 1
                    print(output, flush=True)
    finally:
        if xvfb:
            xvfb.terminate()
            xvfb.wait()
if failures:
    raise SystemExit(1)
