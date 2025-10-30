# Spec for DMS Greeter - Git builds using rpkg macros

%global debug_package %{nil}
%global version {{{ git_dir_version }}}
%global pkg_summary DankMaterialShell greeter for greetd

Name:           dms-greeter
Version:        %{version}
Release:        0.git%{?dist}
Summary:        %{pkg_summary}

License:        GPL-3.0-only
URL:            https://github.com/AvengeMedia/DankMaterialShell
VCS:            {{{ git_dir_vcs }}}
Source0:        {{{ git_dir_pack }}}

BuildRequires:  git-core
BuildRequires:  rpkg
# For the _tmpfilesdir macro.
BuildRequires: systemd-rpm-macros

Requires:       greetd
Requires:       (quickshell-git or quickshell)
Requires(post): /usr/sbin/useradd
Requires(post): /usr/sbin/groupadd

Recommends:     policycoreutils-python-utils
Suggests:       niri
Suggests:       hyprland
Suggests:       sway

# Provides:       greetd-dms-greeter = %{version}-%{release}
# Conflicts:      greetd-dms-greeter

%description
DankMaterialShell greeter for greetd login manager. A modern, Material Design 3
inspired greeter interface built with Quickshell for Wayland compositors.

Supports multiple compositors including Niri, Hyprland, and Sway with automatic
compositor detection and configuration. Features session selection, user
authentication, and dynamic theming.

%prep
{{{ git_dir_setup_macro }}}

%build
# QML-based application

%install
# Install greeter files to shared data location
install -dm755 %{buildroot}%{_datadir}/quickshell/dms-greeter
cp -r * %{buildroot}%{_datadir}/quickshell/dms-greeter/

# Install launcher script
install -Dm755 Modules/Greetd/assets/dms-greeter %{buildroot}%{_bindir}/dms-greeter

# Install theme sync helper script
cat > %{buildroot}%{_bindir}/dms-greeter-sync << 'SYNC_EOF'
#!/bin/bash
set -e

if [ "$EUID" -eq 0 ]; then
    echo "Error: Do not run this script as root. Run as your regular user:"
    echo "  dms-greeter-sync"
    exit 1
fi

CURRENT_USER=$(whoami)
CACHE_DIR="/var/cache/dms-greeter"

echo "=== DMS Greeter Theme Sync Setup ==="
echo
echo "This will sync your DMS theme with the greeter login screen."
echo "User: $CURRENT_USER"
echo

# Add user to greeter group
if ! groups "$CURRENT_USER" | grep -q greeter; then
    echo "Adding $CURRENT_USER to greeter group..."
    sudo usermod -aG greeter "$CURRENT_USER"
    echo "✓ Added to greeter group (logout/login required for group membership)"
else
    echo "✓ Already in greeter group"
fi

# Set group permissions on config directories
echo
echo "Setting group permissions on config directories..."

# First, ensure parent directories are traversable by greeter user (using ACLs)
echo "Making parent directories traversable by greeter..."
if command -v setfacl >/dev/null 2>&1; then
    # Set ACL on home directory
    setfacl -m u:greeter:x ~ 2>/dev/null && echo "✓ Home directory" || echo "⚠ Home directory (may need sudo)"
    
    # Set ACLs on parent config directories
    setfacl -m u:greeter:x ~/.config 2>/dev/null && echo "✓ .config directory" || true
    setfacl -m u:greeter:x ~/.local 2>/dev/null && echo "✓ .local directory" || true
    setfacl -m u:greeter:x ~/.cache 2>/dev/null && echo "✓ .cache directory" || true
    setfacl -m u:greeter:x ~/.local/state 2>/dev/null && echo "✓ .local/state directory" || true
else
    echo "⚠ setfacl not found, you need to run:"
    echo "    setfacl -m u:greeter:x ~ ~/.config ~/.local ~/.cache ~/.local/state"
fi

# Then set permissions on target directories
for dir in ~/.config/DankMaterialShell ~/.local/state/DankMaterialShell ~/.cache/quickshell; do
    if [ -d "$dir" ]; then
        sudo chgrp -R greeter "$dir"
        sudo chmod -R g+rX "$dir"
        echo "✓ $(basename $dir)"
    else
        echo "⚠ $dir not found (will be created when you run DMS)"
    fi
done

# Set group read on parent state directory
sudo chmod g+x ~/.local/state 2>/dev/null || true

# Create symlinks
echo
echo "Creating symlinks to sync theme..."

declare -A links=(
    ["$HOME/.config/DankMaterialShell/settings.json"]="$CACHE_DIR/settings.json"
    ["$HOME/.local/state/DankMaterialShell/session.json"]="$CACHE_DIR/session.json"
    ["$HOME/.cache/DankMaterialShell/dms-colors.json"]="$CACHE_DIR/colors.json"
)

for source in "${!links[@]}"; do
    target="${links[$source]}"
    target_name=$(basename "$source")
    
    if [ -f "$source" ]; then
        sudo ln -sf "$source" "$target"
        echo "✓ Synced $target_name"
    else
        echo "⚠ $target_name not found yet (run DMS to generate it)"
    fi
done

echo
echo "=== Setup Complete! ==="
echo
echo "IMPORTANT: You must LOGOUT and LOGIN for group membership to take effect."
echo "After logging back in, your theme will be synced with the greeter."
SYNC_EOF

chmod 755 %{buildroot}%{_bindir}/dms-greeter-sync

# Install documentation
install -Dm644 Modules/Greetd/README.md %{buildroot}%{_docdir}/dms-greeter/README.md

# Create cache directory for greeter data
install -Dpm0644 ./systemd/tmpfiles-dms-greeter.conf %{buildroot}%{_tmpfilesdir}/dms-greeter.conf

# Create greeter home directory
install -dm755 %{buildroot}%{_sharedstatedir}/greeter

# Note: We do NOT install a PAM config here to avoid conflicting with greetd package
# Instead, we verify/fix it in %post if needed

# Remove build and development files
rm -rf %{buildroot}%{_datadir}/quickshell/dms-greeter/.git*
rm -f %{buildroot}%{_datadir}/quickshell/dms-greeter/.gitignore
rm -rf %{buildroot}%{_datadir}/quickshell/dms-greeter/.github
rm -f %{buildroot}%{_datadir}/quickshell/dms-greeter/*.spec
rm -f %{buildroot}%{_datadir}/quickshell/dms-greeter/dms.spec
rm -f %{buildroot}%{_datadir}/quickshell/dms-greeter/dms-greeter.spec

%posttrans
# Clean up old installation path from previous versions (only if empty)
if [ -d "%{_sysconfdir}/xdg/quickshell/dms-greeter" ]; then
    # Remove directories only if empty (preserves any user-added files)
    rmdir "%{_sysconfdir}/xdg/quickshell/dms-greeter" 2>/dev/null || true
    rmdir "%{_sysconfdir}/xdg/quickshell" 2>/dev/null || true
    rmdir "%{_sysconfdir}/xdg" 2>/dev/null || true
fi

%files
%license LICENSE
%doc %{_docdir}/dms-greeter/README.md
%{_bindir}/dms-greeter
%{_bindir}/dms-greeter-sync
%{_datadir}/quickshell/dms-greeter/
%{_tmpfilesdir}/%{name}.conf

%pre
# Create greeter user/group if they don't exist (greetd expects this)
getent group greeter >/dev/null || groupadd -r greeter
getent passwd greeter >/dev/null || \
    useradd -r -g greeter -d %{_sharedstatedir}/greeter -s /bin/bash \
    -c "System Greeter" greeter
exit 0

%post

# Set SELinux contexts for greeter files on Fedora systems
if [ -x /usr/sbin/semanage ] && [ -x /usr/sbin/restorecon ]; then
    # Greeter launcher binary
    semanage fcontext -a -t bin_t '%{_bindir}/dms-greeter' >/dev/null 2>&1 || true
    restorecon %{_bindir}/dms-greeter >/dev/null 2>&1 || true
    
    # Greeter home directory
    semanage fcontext -a -t user_home_dir_t '%{_sharedstatedir}/greeter(/.*)?' >/dev/null 2>&1 || true
    restorecon -R %{_sharedstatedir}/greeter >/dev/null 2>&1 || true
    
    # Cache directory for greeter data
    semanage fcontext -a -t cache_home_t '%{_localstatedir}/cache/dms-greeter(/.*)?' >/dev/null 2>&1 || true
    restorecon -R %{_localstatedir}/cache/dms-greeter >/dev/null 2>&1 || true
    
    # Shared data directory
    semanage fcontext -a -t usr_t '%{_datadir}/quickshell/dms-greeter(/.*)?' >/dev/null 2>&1 || true
    restorecon -R %{_datadir}/quickshell/dms-greeter >/dev/null 2>&1 || true
    
    # PAM configuration
    restorecon %{_sysconfdir}/pam.d/greetd >/dev/null 2>&1 || true
fi

# Ensure proper ownership of greeter directories
chown -R greeter:greeter %{_localstatedir}/cache/dms-greeter 2>/dev/null || true
chown -R greeter:greeter %{_sharedstatedir}/greeter 2>/dev/null || true

# Verify PAM configuration - only fix if insufficient
PAM_CONFIG="/etc/pam.d/greetd"
if [ ! -f "$PAM_CONFIG" ]; then
    # PAM config doesn't exist - create it
    cat > "$PAM_CONFIG" << 'PAM_EOF'
#%PAM-1.0
auth       substack    system-auth
auth       include     postlogin

account    required    pam_nologin.so
account    include     system-auth

password   include     system-auth

session    required    pam_selinux.so close
session    required    pam_loginuid.so
session    required    pam_selinux.so open
session    optional    pam_keyinit.so force revoke
session    include     system-auth
session    include     postlogin
PAM_EOF
    chmod 644 "$PAM_CONFIG"
    # Only show message on initial install
    [ "$1" -eq 1 ] && echo "Created PAM configuration for greetd"
elif ! grep -q "pam_systemd\|system-auth" "$PAM_CONFIG"; then
    # PAM config exists but looks insufficient - back it up and replace
    cp "$PAM_CONFIG" "$PAM_CONFIG.backup-dms-greeter"
    cat > "$PAM_CONFIG" << 'PAM_EOF'
#%PAM-1.0
auth       substack    system-auth
auth       include     postlogin

account    required    pam_nologin.so
account    include     system-auth

password   include     system-auth

session    required    pam_selinux.so close
session    required    pam_loginuid.so
session    required    pam_selinux.so open
session    optional    pam_keyinit.so force revoke
session    include     system-auth
session    include     postlogin
PAM_EOF
    chmod 644 "$PAM_CONFIG"
    # Only show message on initial install
    [ "$1" -eq 1 ] && echo "Updated PAM configuration (old config backed up to $PAM_CONFIG.backup-dms-greeter)"
fi

# Auto-configure greetd config
GREETD_CONFIG="/etc/greetd/config.toml"
CONFIG_STATUS="Not modified (already configured)"

# Check if niri or hyprland exists
COMPOSITOR="niri"
if ! command -v niri >/dev/null 2>&1; then
        if command -v Hyprland >/dev/null 2>&1; then
                COMPOSITOR="hyprland"
        fi
fi

# If config doesn't exist, create a default one
if [ ! -f "$GREETD_CONFIG" ]; then
        mkdir -p /etc/greetd
        cat > "$GREETD_CONFIG" << 'GREETD_EOF'
[terminal]
vt = 1

[default_session]
user = "greeter"
command = "/usr/bin/dms-greeter --command COMPOSITOR_PLACEHOLDER"
GREETD_EOF
        sed -i "s|COMPOSITOR_PLACEHOLDER|$COMPOSITOR|" "$GREETD_CONFIG"
        CONFIG_STATUS="Created new config with $COMPOSITOR ✓"
# If config exists and doesn't have dms-greeter, update it
elif ! grep -q "dms-greeter" "$GREETD_CONFIG"; then
        # Backup existing config
        BACKUP_FILE="${GREETD_CONFIG}.backup-$(date +%%Y%%m%%d-%%H%%M%%S)"
        cp "$GREETD_CONFIG" "$BACKUP_FILE" 2>/dev/null || true

        # Update command in default_session section
        sed -i "/^\[default_session\]/,/^\[/ s|^command =.*|command = \"/usr/bin/dms-greeter --command $COMPOSITOR\"|" "$GREETD_CONFIG"
        sed -i '/^\[default_session\]/,/^\[/ s|^user =.*|user = "greeter"|' "$GREETD_CONFIG"
        CONFIG_STATUS="Updated existing config (backed up) with $COMPOSITOR ✓"
fi

# Only show banner on initial install
if [ "$1" -eq 1 ]; then
cat << 'EOF'

=========================================================================
        DMS Greeter Installation Complete!
=========================================================================

Status:
    ✓ Greeter user: Created
    ✓ Greeter directories: /var/cache/dms-greeter, /var/lib/greeter
    ✓ SELinux contexts: Applied
EOF
echo "    ✓ Greetd config: $CONFIG_STATUS"
cat << 'EOF'

Next steps:

1. Disable any existing display managers (IMPORTANT):
     sudo systemctl disable gdm sddm lightdm

2. Enable greetd service:
     sudo systemctl enable greetd

3. (Optional) Sync your theme with the greeter:
     dms-greeter-sync
     
     Then logout/login to see your wallpaper on the greeter!

Ready to test? Reboot or run: sudo systemctl start greetd
Documentation: /usr/share/doc/dms-greeter/README.md
=========================================================================

EOF
fi

%postun
# Clean up SELinux contexts on package removal
if [ "$1" -eq 0 ] && [ -x /usr/sbin/semanage ]; then
    semanage fcontext -d '%{_bindir}/dms-greeter' 2>/dev/null || true
    semanage fcontext -d '%{_sharedstatedir}/greeter(/.*)?' 2>/dev/null || true
    semanage fcontext -d '%{_localstatedir}/cache/dms-greeter(/.*)?' 2>/dev/null || true
    semanage fcontext -d '%{_datadir}/quickshell/dms-greeter(/.*)?' 2>/dev/null || true
fi

%changelog
{{{ git_dir_changelog }}}
