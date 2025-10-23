# Dank (dms) Greeter

A greeter for [greetd](https://github.com/kennylevinsen/greetd) that follows the aesthetics of the dms lock screen.

## Features

- **Multi user**: Login with any system user
- **dms sync**: Sync settings with dms for consistent styling between shell and greeter
- **niri or Hyprland**: Use either niri or Hyprland for the greeter's compositor.
- **Custom PAM**: Supports custom PAM configuration in `/etc/pam.d/dankshell`
- **Session Memory**: Remembers last selected session and user

## Installation

### Arch Linux

Arch linux users can install [greetd-dms-greeter-git](https://aur.archlinux.org/packages/greetd-dms-greeter-git) from the AUR.

```bash
paru -S greetd-dms-greeter-git
# Or with yay
yay -S greetd-dms-greeter-git
```

Once installed, disable any existing display manager and enable greetd:

```bash
sudo systemctl disable gdm sddm lightdm
sudo systemctl enable greetd
```

#### Syncing themes (Optional)

To sync your wallpaper and theme with the greeter login screen, follow the manual setup below:

<details>
<summary>Manual theme syncing</summary>

```bash
# Add yourself to greeter group
sudo usermod -aG greeter <username>

# Set ACLs to allow greeter to traverse your directories
setfacl -m u:greeter:x ~ ~/.config ~/.local ~/.cache ~/.local/state

# Set group ownership on config directories
sudo chgrp -R greeter ~/.config/DankMaterialShell
sudo chgrp -R greeter ~/.local/state/DankMaterialShell  
sudo chgrp -R greeter ~/.cache/quickshell
sudo chmod -R g+rX ~/.config/DankMaterialShell ~/.local/state/DankMaterialShell ~/.cache/quickshell

# Create symlinks
sudo ln -sf ~/.config/DankMaterialShell/settings.json /var/cache/dms-greeter/settings.json
sudo ln -sf ~/.local/state/DankMaterialShell/session.json /var/cache/dms-greeter/session.json
sudo ln -sf ~/.cache/DankMaterialShell/dms-colors.json /var/cache/dms-greeter/colors.json

# Logout and login for group membership to take effect
```

</details>

### Fedora / RHEL / Rocky / Alma

Install from COPR or build the RPM:

```bash
# From COPR (when available)
sudo dnf copr enable avenge/dms
sudo dnf install dms-greeter

# Or build locally
cd /path/to/DankMaterialShell
rpkg local
sudo rpm -ivh x86_64/dms-greeter-*.rpm
```

The package automatically:
- Creates the greeter user
- Sets up directories and permissions
- Configures greetd with auto-detected compositor
- Applies SELinux contexts
- Installs the `dms-greeter-sync` helper script

Then disable existing display manager and enable greetd:

```bash
sudo systemctl disable gdm sddm lightdm
sudo systemctl enable greetd
```

#### Syncing themes (Optional)

The RPM package includes the `dms-greeter-sync` helper for easy theme syncing:

```bash
dms-greeter-sync
```

Then logout/login to see your wallpaper on the greeter!

<details>
<summary>What does dms-greeter-sync do?</summary>

The `dms-greeter-sync` helper automatically:
- Adds you to the greeter group
- Sets minimal ACL permissions on parent directories (traverse only)
- Sets group ownership on your DMS config directories
- Creates symlinks to share your theme files with the greeter

This uses standard Linux ACLs (Access Control Lists) - the same security model used by GNOME, KDE, and systemd. The greeter user only gets traverse permission through your directories and can only read the specific theme files you share.

</details>

### Automatic

The easiest thing is to run `dms greeter install` or `dms` for interactive installation.

### Manual

1. Install `greetd` (in most distro's standard repositories) and `quickshell`

2. Create the greeter user (if not already created by greetd):
```bash
sudo groupadd -r greeter
sudo useradd -r -g greeter -d /var/lib/greeter -s /bin/bash -c "System Greeter" greeter
sudo mkdir -p /var/lib/greeter
sudo chown greeter:greeter /var/lib/greeter
```

3. Clone the dms project to `/etc/xdg/quickshell/dms-greeter`:
```bash
sudo git clone https://github.com/AvengeMedia/DankMaterialShell.git /etc/xdg/quickshell/dms-greeter
```

4. Copy `Modules/Greetd/assets/dms-greeter` to `/usr/local/bin/dms-greeter`:
```bash
sudo cp /etc/xdg/quickshell/dms-greeter/Modules/Greetd/assets/dms-greeter /usr/local/bin/dms-greeter
sudo chmod +x /usr/local/bin/dms-greeter
```

5. Create greeter cache directory with proper permissions:
```bash
sudo mkdir -p /var/cache/dms-greeter
sudo chown greeter:greeter /var/cache/dms-greeter
sudo chmod 750 /var/cache/dms-greeter
```

6. Edit or create `/etc/greetd/config.toml`:
```toml
[terminal]
vt = 1

[default_session]
user = "greeter"
# Change compositor to sway or hyprland if preferred
command = "/usr/local/bin/dms-greeter --command niri"
```

7. Disable existing display manager and enable greetd:
```bash
sudo systemctl disable gdm sddm lightdm
sudo systemctl enable greetd
```

8. (Optional) Set up theme syncing using the manual ACL method described in the Configuration → Personalization section below

#### Legacy installation (deprecated)

If you prefer the old method with separate shell scripts and config files:
1. Copy `assets/dms-niri.kdl` or `assets/dms-hypr.conf` to `/etc/greetd`
2. Copy `assets/greet-niri.sh` or `assets/greet-hyprland.sh` to `/usr/local/bin/start-dms-greetd.sh`
3. Edit the config file and replace `_DMS_PATH_` with your DMS installation path
4. Configure greetd to use `/usr/local/bin/start-dms-greetd.sh`

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

### Using dms-greeter wrapper (recommended)

The `dms-greeter` wrapper simplifies running the greeter with any compositor:

```bash
dms-greeter --command niri
dms-greeter --command hyprland
dms-greeter --command sway
dms-greeter --command niri -C /path/to/custom-niri.kdl
```

Configure greetd to use it in `/etc/greetd/config.toml`:
```toml
[terminal]
vt = 1

[default_session]
user = "greeter"
command = "/usr/local/bin/dms-greeter --command niri"
```

### Manual usage

To run dms in greeter mode you can also manually set environment variables:

```bash
DMS_RUN_GREETER=1 qs -p /path/to/dms
```

### Configuration

#### Compositor

You can configure compositor specific settings such as outputs/displays the same as you would in niri or Hyprland.

Simply edit `/etc/greetd/dms-niri.kdl` or `/etc/greetd/dms-hypr.conf` to change compositor settings for the greeter

#### Personalization

The greeter can be personalized with wallpapers, themes, weather, clock formats, and more - configured exactly the same as dms.

**Easiest method:** Run `dms-greeter-sync` to automatically sync your DMS theme with the greeter.

**Manual method:** You can manually synchronize configurations if you want greeter settings to always mirror your shell:

```bash
# Add yourself to the greeter group
sudo usermod -aG greeter $USER

# Set ACLs to allow greeter user to traverse your home directory
setfacl -m u:greeter:x ~ ~/.config ~/.local ~/.cache ~/.local/state

# Set group permissions on DMS directories
sudo chgrp -R greeter ~/.config/DankMaterialShell ~/.local/state/DankMaterialShell ~/.cache/quickshell
sudo chmod -R g+rX ~/.config/DankMaterialShell ~/.local/state/DankMaterialShell ~/.cache/quickshell

# Create symlinks for theme files
sudo ln -sf ~/.config/DankMaterialShell/settings.json /var/cache/dms-greeter/settings.json
sudo ln -sf ~/.local/state/DankMaterialShell/session.json /var/cache/dms-greeter/session.json
sudo ln -sf ~/.cache/DankMaterialShell/dms-colors.json /var/cache/dms-greeter/colors.json

# Logout and login for group membership to take effect
```

**Advanced:** You can override the configuration path with the `DMS_GREET_CFG_DIR` environment variable or the `--cache-dir` flag when using `dms-greeter`. The default is `/var/cache/dms-greeter`.

The cache directory should be owned by `greeter:greeter` with `770` permissions.
