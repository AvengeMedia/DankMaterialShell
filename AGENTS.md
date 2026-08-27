## What is this?

DMS is an open-source, MIT-licensed desktop shell for Wayland compositors on linux. Like KWin, gnome-shell, or cosmic-shell - but designed to work with many different compositors.

## Repo Structure:

There are 2 main apps in the repo, they are designed to operate together. Additionally there is a dank-qml-common submodule which contains common QML widgets, like a shared library, that is leveraged by other quickshell apps in the Dank Desktop suite.

There is a GO module (dankgo) that is used by core for certain common go functionality.

### 1- core:

Contains 2 apps:

1. cmd/dms - The parent process for quickshell (shell runner), and general purpose tools and utilities (such as screenshot, clipboard). It also runs the unix socket server the UI uses for functionality quickshell doesn't provide.
2. cmd/dankinstall - An entirely separate app, a TUI for quickly installing DMS

### 2- quickshell:

A quickshell application, the entirety of the UI for DMS. It uses quickshells own services supplemented by the core unix socket server for additional functionality.

Layout:

- Common/ - app-wide singletons and helpers (Theme, SettingsData, SessionData, I18n, PopoutManager)
- Services/ - headless singletons that talk to the system and to core
- Modules/ - the visible shell: DankBar, ControlCenter, Dock, Lock, Notifications, OSD, and so on
- Modals/ - large standalone surfaces: Settings, DankLauncherV2, Clipboard, Greeter
- Widgets/ - reusable Dank* components (DankListView, DankIcon, DankToggle, ...)
- PLUGINS/ - the plugin system; third-party plugins load from the user's config dir
- translations/ - POEditor-synced catalogs

### Other directories:

- docs/ - IPC reference, custom theme docs
- distro/ - packaging for debian, fedora, nix, opensuse, ubuntu, void

## General Rules:

- Keep it simple. Do not overcomplicate things.
- Follow each apps' own conventions. For example, QML widgets use Theme tokens instead of hardcoding colors, spacing, or other constants.
- Resource usage is extremely important to DMS. The shell runs 24/7 on every machine it's installed on - audit any change for idle CPU cost, extra processes, timers, and retained memory.
- `core` and `quickshell` are tightly coupled through the unix socket protocol. When you are changing one, be mindful of the consequences for the other.
- Use the Dank* wrappers in Widgets/ (DankListView, DankFlickable, and so on) instead of raw ListView/Flickable/ScrollView.
- All user-facing text goes through I18n.tr(). Prefer reusing existing catalog terms over adding new ones. Never edit the translation catalogs by hand, they are synced with POEditor.
- Do not start editing code in response to a question. We'll tell you when to edit code.
- Do not leave paragraphs of comments on top of the code. You should try to avoid them as much as possible with understandable function names and code. If they are necessary even then, make them concise. Remove such comments when you come by them in the codebase. Comments should always move with code, not be left behind.
- Use guard statement patterns in any code you write.
- Do not write any useless tests, tests should cover input output validation - not useless things like "main.go contains func main()"
- Do not edit generated code directly, mocks are generated with mockery. Not edited by hand
- If we are missing a glaring issue when we ask you to do something, do not hesitate to point it out.
- Reinvent the wheel but do not reinvent the car. If you are solving a simple problem do not introduce a library. If you are solving a complex but a common problem, there is likely a modern library for it, if so, use it.
- Never commit or push code unless explicitly asked to do so.
- Never make a PR unless explicitly asked to do so.

## Commit Messages

Commit messages start with the part of the system they touched, followed by a short lowercase explanation of the work:

network: report wifi state from the associated adapter
doctor: flag config files that fail to parse

The title should be concise. Description should explain the work in more detail (only if required) while still being concise. Use simple language, do not try to sound smart.
