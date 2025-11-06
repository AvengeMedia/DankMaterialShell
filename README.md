# DankMaterialShell (dms)

<div align="center">
  <a href="https://danklinux.com">
    <img src="assets/danklogo2.svg" alt="DankMaterialShell Logo" width="200">
  </a>

  ### A modern Wayland desktop shell

  Built with [Quickshell](https://quickshell.org/) and [Go](https://go.dev/)

[![Documentation](https://img.shields.io/badge/docs-danklinux.com-9ccbfb?style=for-the-badge&labelColor=101418)](https://danklinux.com/docs)
[![GitHub stars](https://img.shields.io/github/stars/AvengeMedia/DankMaterialShell?style=for-the-badge&labelColor=101418&color=ffd700)](https://github.com/AvengeMedia/DankMaterialShell/stargazers)
[![GitHub License](https://img.shields.io/github/license/AvengeMedia/DankMaterialShell?style=for-the-badge&labelColor=101418&color=b9c8da)](https://github.com/AvengeMedia/DankMaterialShell/blob/master/LICENSE)
[![GitHub release](https://img.shields.io/github/v/release/AvengeMedia/DankMaterialShell?style=for-the-badge&labelColor=101418&color=9ccbfb)](https://github.com/AvengeMedia/DankMaterialShell/releases)
[![AUR version](https://img.shields.io/aur/version/dms-shell-bin?style=for-the-badge&labelColor=101418&color=9ccbfb)](https://aur.archlinux.org/packages/dms-shell-bin)
[![AUR version (git)](https://img.shields.io/aur/version/dms-shell-git?style=for-the-badge&labelColor=101418&color=9ccbfb&label=AUR%20(git))](https://aur.archlinux.org/packages/dms-shell-git)
[![Ko-Fi donate](https://img.shields.io/badge/donate-kofi?style=for-the-badge&logo=ko-fi&logoColor=ffffff&label=ko-fi&labelColor=101418&color=f16061&link=https%3A%2F%2Fko-fi.com%2Favengemediallc)](https://ko-fi.com/avengemediallc)

</div>

DankMaterialShell is a complete desktop shell for [niri](https://github.com/YaLTeR/niri), [Hyprland](https://hypr.land), [MangoWC](https://github.com/DreamMaoMao/mangowc), [Sway](https://swaywm.org), and other Wayland compositors. It replaces waybar, swaylock, swayidle, mako, fuzzel, polkit, and everything else you'd normally stitch together to make a desktop - all in one cohesive package with a gorgeous interface.

## Components

DankMaterialShell combines two main components:

- **[QML/UI Layer](https://github.com/AvengeMedia/DankMaterialShell)** (this repo) - All the visual components, widgets, and shell interface built with Quickshell
- **[Go Backend](https://github.com/AvengeMedia/danklinux)** - System integration, IPC, process management, and core services

---

## See it in Action

<div align="center">

https://github.com/user-attachments/assets/1200a739-7770-4601-8b85-695ca527819a

</div>

<details><summary><strong>More Screenshots</strong></summary>

<div align="center">

<img src="https://github.com/user-attachments/assets/203a9678-c3b7-4720-bb97-853a511ac5c8" width="600" alt="Desktop" />

<img src="https://github.com/user-attachments/assets/a937cf35-a43b-4558-8c39-5694ff5fcac4" width="600" alt="Dashboard" />

<img src="https://github.com/user-attachments/assets/2da00ea1-8921-4473-a2a9-44a44535a822" width="450" alt="Launcher" />

<img src="https://github.com/user-attachments/assets/732c30de-5f4a-4a2b-a995-c8ab656cecd5" width="600" alt="Control Center" />

</div>

</details>

---

## Quick Install

```bash
curl -fsSL https://install.danklinux.com | sh
```

That's it. One command installs dms and all dependencies on Arch, Fedora, Debian, Ubuntu, or openSUSE.

**[Manual Installation Guide →](https://danklinux.com/docs/dankmaterialshell/installation)**

---

## What You Get

**Dynamic Theming**
Wallpaper-based color schemes that automatically theme GTK, Qt, terminals, editors (like vscode, vscodium), and more with [matugen](https://github.com/InioX/matugen) and [dank16](https://github.com/AvengeMedia/danklinux/blob/master/internal/dank16/dank16.go).

**System Monitoring**
Real-time CPU, RAM, GPU metrics and temps with [dgop](https://github.com/AvengeMedia/dgop). Full process list with search and management.

**Powerful Launcher**
Spotlight-style search for apps, files (via [dsearch](https://github.com/AvengeMedia/danksearch)), emojis, running windows, calculator, commands - extensible with plugins.

**Control Center**
Network, Bluetooth, audio devices, display settings, night mode - all in one clean interface.

**Smart Notifications**
Notification center with grouping, rich text support, and keyboard navigation.

**Media Integration**
MPRIS player controls, calendar sync, weather widgets, clipboard history with image previews.

**Complete Session Management**
Lock screen, idle detection, auto-lock/suspend with separate AC/battery settings, greeter support.

**Plugin System**
Endless customization with the [plugin registry](https://plugins.danklinux.com).

**TL;DR** - One shell replaces waybar, swaylock, swayidle, mako, fuzzel, polkit and everything else you normally piece together to create a linux desktop.

---

## Supported Compositors

DankMaterialShell works best with **[niri](https://github.com/YaLTeR/niri)**, **[Hyprland](https://hyprland.org/)**, **[sway](https://swaywm.org/)**, and **[dwl/MangoWC](https://github.com/DreamMaoMao/mangowc)** - with full workspace switching, overview integration, and monitor management.

Other Wayland compositors work too, just with a reduced feature set.

**[Compositor configuration guide →](https://danklinux.com/docs/dankmaterialshell/compositors)**

---

## Keybinds & IPC

Control everything from the command line or keybinds:

```bash
dms ipc call spotlight toggle
dms ipc call audio setvolume 50
dms ipc call wallpaper set /path/to/image.jpg
dms ipc call theme toggle
```

**[Full keybind and IPC documentation →](https://danklinux.com/docs/dankmaterialshell/keybinds-ipc)**

---

## Theming

DankMaterialShell automatically generates color schemes from your wallpaper or theme and applies them to GTK, Qt, terminals, and more.

DMS is not opinionated or forcing these themes - they are created as optional themes you can enable. You can refer to the documentation if you want to use them:

**Application theming:** [GTK, Qt, Firefox, terminals, vscode+vscodium →](https://danklinux.com/docs/dankmaterialshell/application-themes)

**Custom themes:** [Create your own color schemes →](https://danklinux.com/docs/dankmaterialshell/custom-themes)

---

## Plugins

Extend dms with the plugin system. Browse community plugins at [plugins.danklinux.com](https://plugins.danklinux.com).

**[Plugin development guide →](https://danklinux.com/docs/dankmaterialshell/plugins-overview)**

---

## Documentation

**Website:** [danklinux.com](https://danklinux.com)

**Docs:** [danklinux.com/docs](https://danklinux.com/docs)

**Support:** [Ko-fi](https://ko-fi.com/avengemediallc)

---

## Contributing

Contributions welcome! Bug fixes, new widgets, theme improvements, or docs - it all helps.

**Contributing Code:**
1. Fork the repository
2. Make your changes
3. Open a pull request

**Contributing Documentation:**
1. Fork the [DankLinux-Docs](https://github.com/AvengeMedia/DankLinux-Docs) repository
2. Update files in the `docs/` folder
3. Open a pull request

Check the [issues](https://github.com/AvengeMedia/DankMaterialShell/issues) or join the community.

---

## Credits

- [quickshell](https://quickshell.org/) the core of what makes a shell like this possible.
- [niri](https://github.com/YaLTeR/niri) for the awesome scrolling compositor.
- [Ly-sec](http://github.com/ly-sec) for awesome wallpaper effects among other things from [Noctalia](https://github.com/noctalia-dev/noctalia-shell)
- [soramanew](https://github.com/soramanew) who built [caelestia](https://github.com/caelestia-dots/shell) which served as inspiration and guidance for many dank widgets.
- [end-4](https://github.com/end-4) for [dots-hyprland](https://github.com/end-4/dots-hyprland) which also served as inspiration and guidance for many dank widgets.
