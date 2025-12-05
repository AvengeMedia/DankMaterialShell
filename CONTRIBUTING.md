# Contributing

Contributions are welcome and encouraged.

To contribute fork this repository, make your changes, and open a pull request.

## Setup

Enable pre-commit hooks to catch CI failures before pushing:

```bash
git config core.hooksPath .githooks
```

## VSCode Setup

This is a monorepo, the easiest thing to do is to open an editor in either `quickshell`, `core`, or both depending on which part of the project you are working on.

### QML (`quickshell` directory)

1. Install the [QML Extension](https://doc.qt.io/vscodeext/)
2. Configure `ctrl+shift+p` -> user preferences (json) with qmlls path

```json
{
  "qt-qml.doNotAskForQmllsDownload": true,
  "qt-qml.qmlls.customExePath": "/usr/lib/qt6/bin/qmlls"
}
```

3. Create empty `.qmlls.ini` file in `quickshell/` directory

```bash
cd quickshell
touch .qmlls.ini
```

4. Restart dms to generate the `.qmlls.ini` file

5. Make your changes, test, and open a pull request.

### GO (`core` directory)

1. Install the [Go Extension](https://code.visualstudio.com/docs/languages/go)
2. Ensure code is formatted with `make fmt`
3. Add appropriate test coverage and ensure tests pass with `make test`
4. Run `go mod tidy`
5. Open pull request

## Pull request

Include screenshots/video if applicable in your pull request if applicable, to visualize what your change is affecting.
