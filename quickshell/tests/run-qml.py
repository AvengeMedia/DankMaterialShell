import argparse
from concurrent.futures import ThreadPoolExecutor, as_completed
import os
from pathlib import Path
import shutil
import signal
import subprocess
import sys
import time

repo = Path(__file__).resolve().parents[2]


def qml_test_runner():
    override = os.environ.get("QMLTESTRUNNER")
    candidates = [override] if override else ["qmltestrunner6", "/usr/lib/qt6/bin/qmltestrunner", "/usr/lib64/qt6/bin/qmltestrunner", "qmltestrunner"]
    for candidate in candidates:
        executable = shutil.which(candidate)
        if executable:
            return executable
    raise SystemExit("Qt 6 qmltestrunner is required; set QMLTESTRUNNER to its path")


def run(name, command):
    started = time.monotonic()
    env = {key: value for key, value in os.environ.items() if not key.startswith("DMS_FIXTURE_")}
    env["QT_QPA_PLATFORM"] = "offscreen"
    try:
        process = subprocess.Popen(command, cwd=repo, env=env, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True, start_new_session=True)
    except OSError as error:
        return name, False, time.monotonic() - started, str(error)
    try:
        output, _ = process.communicate(timeout=120)
        return name, process.returncode == 0, time.monotonic() - started, output
    except subprocess.TimeoutExpired:
        os.killpg(process.pid, signal.SIGTERM)
        try:
            output, _ = process.communicate(timeout=5)
        except subprocess.TimeoutExpired:
            os.killpg(process.pid, signal.SIGKILL)
            output, _ = process.communicate()
        return name, False, time.monotonic() - started, output + "\nSuite timed out"


def main():
    parser = argparse.ArgumentParser(description="Run shell logic, Qt unit tests and QML widget regressions")
    parser.add_argument("--jobs", type=int, default=max(1, min(4, len(os.sched_getaffinity(0)) // 4)))
    parser.add_argument("suites", nargs="*", choices=["widgets", "media", "qt", "logic"])
    args = parser.parse_args()
    if args.jobs < 1:
        parser.error("--jobs must be positive")
    selected = args.suites or ["widgets", "media", "qt", "logic"]
    commands = {
        "widgets": [sys.executable, "quickshell/tests/run-surface-fixture.py", "--suite", "quickshell/tests/qml/bar-content.qml", "quickshell/tests/qml/instance-routing.qml", "quickshell/tests/qml/font-weights.qml", "quickshell/tests/qml/theme-selected-container.qml", "quickshell/tests/qml/theme-accents.qml", "quickshell/tests/qml/clipboard-preview.qml", "quickshell/tests/qml/launcher-plugin-instances.qml", "quickshell/tests/qml/island-launcher-focus.qml", "quickshell/tests/qml/workspace-switcher.qml", "quickshell/tests/qml/focused-app.qml", "quickshell/tests/qml/slider-wheel.qml", "quickshell/tests/qml/control-center-sizes.qml", "quickshell/tests/qml/grid-edit-layout.qml"],
        "media": [sys.executable, "quickshell/tests/run-surface-fixture.py", "--suite", "quickshell/tests/qml/media-presentation.qml", "quickshell/tests/qml/media-playback.qml", "quickshell/tests/qml/media-artwork.qml", "quickshell/tests/qml/media-lyrics.qml", "--mpris", "--artwork"],
        "logic": ["node", "--test", *sorted(str(path.relative_to(repo)) for path in (repo / "quickshell/tests").glob("*.test.mjs"))],
    }
    if "qt" in selected:
        commands["qt"] = [qml_test_runner(), "-input", "quickshell/tests", "-o", "-,txt"]
    started = time.monotonic()
    failed = False
    with ThreadPoolExecutor(max_workers=min(args.jobs, len(selected))) as pool:
        futures = [pool.submit(run, name, commands[name]) for name in selected]
        for future in as_completed(futures):
            name, passed, elapsed, output = future.result()
            print(f"{'PASS' if passed else 'FAIL'} {name}: {elapsed:.2f}s", flush=True)
            if not passed:
                failed = True
                print(output, flush=True)
                continue
            for line in output.splitlines():
                if any(token in line for token in ["FIXTURE_", "Totals:", "# tests "]):
                    print(line.strip(), flush=True)
    print(f"QML checks: {time.monotonic() - started:.2f}s", flush=True)
    return int(failed)


if __name__ == "__main__":
    sys.exit(main())
