# Shell tests

`make test-qml` runs the shell JavaScript tests, Qt output-cycle tests and every QML fixture in `qml/`. It needs Python 3, Node.js, make, Qt 6 qmltestrunner, Quickshell, niri, Xvfb, dbus-daemon or dbus-broker, and the `dbus_next` Python module. The Nix development shell includes these dependencies on Linux.

The `qml-tests` pre-commit hook runs the same checks when shell code, tests or their configuration changes. CI runs that hook in the QML tests job. The other pre-commit job skips it to avoid running it twice.

```sh
prek run qml-tests --all-files
python3 quickshell/tests/run-qml.py logic
python3 quickshell/tests/run-qml.py qt
python3 quickshell/tests/run-qml.py lock
python3 quickshell/tests/run-qml.py widgets
python3 quickshell/tests/run-qml.py media
```

Set `QMLTESTRUNNER` to override the Qt 6 executable. Use `--jobs 1` to run the suites sequentially.

Every file in `qml/` runs. `media-*.qml` fixtures get a session bus and a fake MPRIS player with artwork, the rest run in the widgets suite. To run some fixtures on their own:

```sh
python3 quickshell/tests/run-surface-fixture.py quickshell/tests/qml/bar-content.qml quickshell/tests/qml/instance-routing.qml
python3 quickshell/tests/run-surface-fixture.py --mpris --artwork quickshell/tests/qml/media-lyrics.qml
```

The runner prints one line per fixture as it finishes and the full log of a failed one. A fixture fails on a nonzero exit, a missing `FIXTURE_PASS`, a `FIXTURE_FAIL` line or its 60 second cap. Half the available cores run at a time, up to eight; set `DMS_FIXTURE_JOBS` to change that.

The fixtures share one X server. Each fixture gets its own niri, Quickshell process, QML tree and config, cache, state and data directories, so nothing one fixture does is visible to another. The host is hidden too: `HOME`, `XDG_DATA_DIRS` and `XDG_CONFIG_DIRS` point into the temporary root, the locale is `C.UTF-8`, the timezone is UTC, and host `DMS_*`, `QS_*` and Qt theme and scale variables are dropped. The only desktop entries and icons a fixture sees are the ones in `fixtures/share`; add to it when a fixture needs an app or icon. Idle, lock and suspend timeouts are disabled. The runner does not connect to the live shell or session bus.

## Writing a fixture

- Wait on the condition, never on the clock. Poll with a 20 second deadline and a label, then assert. A pass returns as soon as the condition holds, so the budget costs nothing.
- Start from the real precondition (player on the bus, window active, settings loaded), not a startup timer.
- Settle layout with `isPolishScheduled`/`waitForPolish` on `item.Window.window` before reading geometry or clicking.
- Keys only reach a window niri has activated. Wait for `Window.active` before `keyClick`.
- A step `Timer` retries its checks until they pass or its deadline runs out, then moves on. Put every check before the step's mutations so a retry is safe. Give it an interval above 0: a repeating 0ms `Timer` never finishes under qs.
- Assert behavior that would break on a regression. No pixel sampling, no size or locale matrices, no screenshots, no private state unless it is the only deterministic way to order a race.
