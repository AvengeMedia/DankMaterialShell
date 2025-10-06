# Dank (dms) Greeter

A greeter for [greetd](https://github.com/kennylevinsen/greetd) that follows the aesthetics of the dms lock screen.

## Features

- **Multi user**: Login with any system user
- **dms sync**: Sync settings with dms for consistent styling between shell and greeter
- **niri or Hyprland**: Use either niri or Hyprland for the greeter's compositor.
- **Custom PAM**: Supports custom PAM configuration in `/etc/pam.d/dankshell`
- **Session Memory**: Remembers last selected session and user

## Installation

### Automatic

The easiest thing is to run `dms greeter install` or `dms` for interactive installation.

### Manual

1. Install `greetd` (in most distro's standard repositories)
2. Copy `assets/dms-niri.kdl` or `assets/dms-hypr.conf` to `/etc/greetd`
  - niri if you want to run the greeter under niri, hypr if you want to run the greeter under Hyprland
3. Copy `assets/greet-niri.sh` or `assets/greet-hyprland.sh` to `/usr/local/bin/start-dms-greetd.sh`
4. Edit `/etc/greetd/dms-niri.kdl` or `/etc/greetd/dms-hypr.conf` and replace `_DMS_PATH_` with the absolute path to dms, e.g. `/home/joecool/.config/quickshell/dms`
5. Edit or create `/etc/greetd/config.toml` 
```toml
[terminal]
# The VT to run the greeter on. Can be "next", "current" or a number
# designating the VT.
vt = 1

# The default session, also known as the greeter.
[default_session]

# `agreety` is the bundled agetty/login-lookalike. You can replace `/bin/sh`
# with whatever you want started, such as `sway`.

# The user to run the command as. The privileges this user must have depends
# on the greeter. A graphical greeter may for example require the user to be
# in the `video` group.
user = "greeter"

command = "/usr/local/bin/start-dms-greetd.sh"
```

Enable the greeter with `sudo systemctl enable greetd`

### NixOS

To install the greeter on NixOS add the repo to your flake inputs as described in the readme. Then somewhere in your NixOS config add this to imports:
```nix
imports = [
  inputs.dankMaterialShell.nixosModules.greeter
]
```

Enable the greeter with this in your NixOS config:
```nix
programs.dankMaterialShell.greeter = {
  enable = true;
  compositor.name = "niri"; # or set to hyprland
  configHome = "/home/user"; # optionally copyies that users DMS settings (and wallpaper if set) to the greeters data directory as root before greeter starts
};
```

## Usage

To run dms in greeter mode you just need to set `DMS_RUN_GREETER=1` in the environment.

```bash
DMS_RUN_GREETER=1 qs -p /path/to/dms
```

### Configuration

#### Compositor

You can configure compositor specific settings such as outputs/displays the same as you would in niri or Hyprland.

Simply edit `/etc/greetd/dms-niri.kdl` or `/etc/greetd/dms-hypr.conf` to change compositor settings for the greeter

#### Personalization

Wallpapers and themes and weather and clock formats and things are a TODO on the documentation, but it's configured exactly the same as dms.

You can synchronize those configurations with a specific user if you want greeter settings to always mirror the shell.

```bash
# For core settings (theme, clock formats, etc)
sudo ln -sf ~/.config/DankMaterialShell/settings.json /etc/greetd/.dms/settings.json
# For state (mainly you would configure wallpaper in this file)
sudo ln -sf ~/.local/state/DankMaterialShell/session.json /etc/greetd/.dms/session.json
# For wallpaper based theming
sudo ln -sf ~/.cache/quickshell/dankshell/dms-colors.json /etc/greetd/.dms/dms-colors.json
```

You can override the configuration path with the `DMS_GREET_CFG_DIR` environment variable, the default is `/etc/greetd/.dms`

It should be writable by the greeter user.
