# DankMaterialShell Installer (`dankinstall`) Flag Reference & Combinations

This document provides a comprehensive guide and full list of command-line flags and combinations for headless (unattended) automated installation of **DankMaterialShell** via `dankinstall` or `install.sh`.

---

## 1. Complete Flag Reference

| Flag | Short | Input Values / Type | Description |
| :--- | :--- | :--- | :--- |
| `--compositor` | `-c` | `niri`, `hyprland`, `mango` | Compositor / Window Manager (Required for headless mode). |
| `--term` | `-t` | `ghostty`, `kitty`, `alacritty` | Terminal emulator to install (Required for headless mode). |
| `--privesc` | `-p` | `sudo`, `doas`, `run0` | Explicit privilege escalation tool. |
| `--yes` | `-y` | Boolean | Required for headless mode - auto-confirms installation without prompts. |
| `--all` / `--all-features` | `-a` | Boolean | Enables all optional packages (`dms-greeter`, `danksearch`, `dankcalendar`). |
| `--no-features` | | Boolean | Skips all optional packages and features. |
| `--wm-git` | | Boolean | Installs the git/development release of the selected window manager. |
| `--quickshell-git` | | Boolean | Installs the git/development release of Quickshell. |
| `--dms-git` | | Boolean | Installs the git/development release of DankMaterialShell. |
| `--git` / `--git-all` | | Boolean | Forces git/development versions for all supported components. |
| `--git-deps` | | Comma-separated list | Forces git versions for specific dependencies (e.g. `niri,quickshell`). |
| `--dms-greeter` / `--greeter` | | Boolean | Installs the `dms-greeter` optional component. |
| `--danksearch` | | Boolean | Installs `danksearch` and enables its background file indexing service. |
| `--dankcalendar` | | Boolean | Installs `dankcalendar` optional package. |
| `--include-deps` | | Comma-separated list | Explicit list of optional dependencies to enable. |
| `--exclude-deps` | | Comma-separated list | Dependencies to exclude/skip during installation. |
| `--replace-configs` | | Comma-separated list | Deploy/overwrite specific configs (e.g. `niri,ghostty`). |
| `--replace-configs-all` | | Boolean | Deploy/overwrite all configuration files. |

---

## 2. Core Compositor & Terminal Matrix

Headless mode requires both `--compositor` (`-c`) and `--term` (`-t`), plus `--yes` (`-y`).

| # | Compositor | Terminal | Execution Command Example |
| :--- | :--- | :--- | :--- |
| 1 | `niri` | `ghostty` | `dankinstall -c niri -t ghostty -y` |
| 2 | `niri` | `kitty` | `dankinstall -c niri -t kitty -y` |
| 3 | `niri` | `alacritty` | `dankinstall -c niri -t alacritty -y` |
| 4 | `hyprland` | `ghostty` | `dankinstall -c hyprland -t ghostty -y` |
| 5 | `hyprland` | `kitty` | `dankinstall -c hyprland -t kitty -y` |
| 6 | `hyprland` | `alacritty` | `dankinstall -c hyprland -t alacritty -y` |
| 7 | `mango` | `ghostty` | `dankinstall -c mango -t ghostty -y` |
| 8 | `mango` | `kitty` | `dankinstall -c mango -t kitty -y` |
| 9 | `mango` | `alacritty` | `dankinstall -c mango -t alacritty -y` |

---

## 3. Privilege Escalation Combinations

Choose your preferred escalation backend using `--privesc` (`-p`).

```bash
# 1. Standard sudo escalation
curl -fsSL https://raw.githubusercontent.com/JDKamalakar/DankMaterialShell/master/core/install.sh | sh -s -- -c niri -t ghostty -p sudo -y

# 2. OpenBSD doas escalation
curl -fsSL https://raw.githubusercontent.com/JDKamalakar/DankMaterialShell/master/core/install.sh | sh -s -- -c hyprland -t kitty -p doas -y

# 3. systemd run0 escalation
curl -fsSL https://raw.githubusercontent.com/JDKamalakar/DankMaterialShell/master/core/install.sh | sh -s -- -c mango -t alacritty -p run0 -y
```

---

## 4. Git vs. Stable Variant Combinations

Control whether components install stable or bleeding-edge (git) releases.

| Category | Description | Command Combination |
| :--- | :--- | :--- |
| **All Git Releases** | Force git builds for WM, Quickshell, DMS & companions | `dankinstall -c niri -t ghostty --git -y` |
| **WM Git Only** | Bleeding-edge WM with stable DMS & Quickshell | `dankinstall -c hyprland -t kitty --wm-git -y` |
| **Quickshell Git Only** | Bleeding-edge Quickshell backend | `dankinstall -c niri -t ghostty --quickshell-git -y` |
| **DMS Git Only** | Development version of DMS shell | `dankinstall -c niri -t ghostty --dms-git -y` |
| **WM + Quickshell Git** | Git WM and Quickshell | `dankinstall -c niri -t ghostty --wm-git --quickshell-git -y` |
| **Targeted Git List** | Specific packages via comma list | `dankinstall -c niri -t ghostty --git-deps niri,quickshell,matugen -y` |

---

## 5. Feature Toggles & Package Combinations

| Goal | Description | Command Combination |
| :--- | :--- | :--- |
| **Full Installation** | Install all optional features & services | `dankinstall -c niri -t ghostty -a -y` |
| **Minimal / Core Only** | Skip all optional features | `dankinstall -c niri -t ghostty --no-features -y` |
| **DankSearch Only** | Enable search indexer service | `dankinstall -c niri -t ghostty --danksearch -y` |
| **Calendar Only** | Enable calendar package | `dankinstall -c niri -t ghostty --dankcalendar -y` |
| **Greeter Only** | Enable login greeter | `dankinstall -c niri -t ghostty --greeter -y` |
| **Search + Calendar** | Enable search & calendar | `dankinstall -c niri -t ghostty --danksearch --dankcalendar -y` |
| **Include Specific List** | Enable specific items | `dankinstall -c niri -t ghostty --include-deps dms-greeter,danksearch -y` |
| **Exclude Specific Item** | Exclude unwanted package | `dankinstall -c niri -t ghostty -a --exclude-deps dms-greeter -y` |

---

## 6. Config Deployment Combinations

| Goal | Command Combination |
| :--- | :--- |
| **Deploy All Configs** | `dankinstall -c niri -t ghostty --replace-configs-all -y` |
| **Deploy WM Config Only** | `dankinstall -c niri -t ghostty --replace-configs niri -y` |
| **Deploy Terminal Config Only** | `dankinstall -c niri -t ghostty --replace-configs ghostty -y` |
| **Deploy WM + Terminal Config** | `dankinstall -c niri -t ghostty --replace-configs niri,ghostty -y` |

---

## 7. Real-World Deployment Recipes

### Minimal Production Deployment (Niri + Ghostty)
```bash
curl -fsSL https://raw.githubusercontent.com/JDKamalakar/DankMaterialShell/master/core/install.sh | sh -s -- -c niri -t ghostty -p sudo --no-features -y
```

### Full Workstation Deployment (Hyprland + Kitty + All Features + Configs)
```bash
curl -fsSL https://raw.githubusercontent.com/JDKamalakar/DankMaterialShell/master/core/install.sh | sh -s -- -c hyprland -t kitty -p sudo -a --replace-configs-all -y
```

### Bleeding-Edge Developer Setup (Mango + Alacritty + All Git Versions)
```bash
curl -fsSL https://raw.githubusercontent.com/JDKamalakar/DankMaterialShell/master/core/install.sh | sh -s -- -c mango -t alacritty -p doas --git -a -y
```
