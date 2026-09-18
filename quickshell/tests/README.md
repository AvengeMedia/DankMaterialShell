# Shell tests

`make test-qml` runs the shell JavaScript tests, Qt output-cycle tests, QML tests for widget ordering and multi-bar/plugin routing, and the media fixtures. It needs Python 3, Node.js, make, Qt 6 qmltestrunner, Quickshell, niri, Xvfb, dbus-daemon or dbus-broker, and the `dbus_next` Python module. The Nix development shell includes these dependencies on Linux.

The `qml-tests` pre-commit hook runs the same checks when shell code, tests or their configuration changes. CI runs that hook in the QML tests job. The other pre-commit job skips it to avoid running it twice.

```sh
prek run qml-tests --all-files
python3 quickshell/tests/run-qml.py logic
python3 quickshell/tests/run-qml.py qt
python3 quickshell/tests/run-qml.py widgets
python3 quickshell/tests/run-qml.py media
```

Set `QMLTESTRUNNER` to override the Qt 6 executable. Use `--jobs 1` to run the suites sequentially.

The QML fixtures share one X server and the QML disk cache. Each fixture gets its own niri, Quickshell process, QML tree and config, cache, state and data directories, so nothing one fixture does is visible to another. The host is hidden too: `HOME`, `XDG_DATA_DIRS` and `XDG_CONFIG_DIRS` point into the temporary root, the locale is `C.UTF-8`, the timezone is UTC, and host `DMS_*`, `QS_*` and Qt theme and scale variables are dropped. The only desktop entries and icons a fixture sees are the ones in `fixtures/share`; add to it when a fixture needs an app or icon. Idle, lock and suspend timeouts are disabled. The runner does not connect to the live shell or session bus.

Other compositor, D-Bus, screenshot and resource fixtures remain available through `run-surface-fixture.py`:

```sh
python3 quickshell/tests/run-surface-fixture.py quickshell/tests/qml/system-tray.qml /tmp/system-tray.log --dbus
python3 quickshell/tests/run-surface-fixture.py quickshell/tests/qml/media-presentation.qml /tmp/media-presentation.log --mpris
python3 quickshell/tests/run-surface-fixture.py quickshell/tests/qml/media-playback.qml /tmp/media-playback.log --mpris
python3 quickshell/tests/run-surface-fixture.py quickshell/tests/qml/media-artwork.qml /tmp/media-artwork.log --mpris --artwork
python3 quickshell/tests/run-surface-fixture.py quickshell/tests/qml/media-lyrics.qml /tmp/media-lyrics.log --mpris --artwork
python3 quickshell/tests/run-surface-fixture.py --suite quickshell/tests/qml/bar-content.qml quickshell/tests/qml/instance-routing.qml
```

`--suite` accepts QML paths followed by the fixture flags they share. It reports each fixture's runtime and runs half the available cores at a time, up to four; set `DMS_FIXTURE_JOBS` to change that. `--mpris` fixtures get their own session bus and player, so they run in parallel like the rest. A failure, missing pass marker, QML binding error or timeout fails the command and prints the failed fixture's full log.
