# Spec for DMS Greeter - Stable releases

%global debug_package %{nil}
%global version VERSION_PLACEHOLDER
%global pkg_summary DankMaterialShell greeter for greetd

Name:           dms-greeter
Version:        %{version}
Release:        RELEASE_PLACEHOLDER%{?dist}
Summary:        %{pkg_summary}

License:        MIT
URL:            https://github.com/AvengeMedia/DankMaterialShell

Source0:        dms-qml.tar.gz

BuildRequires:  gzip
BuildRequires:  wget
BuildRequires:  systemd-rpm-macros

Requires:       greetd
Requires:       (quickshell-git or quickshell)
Requires(post): /usr/sbin/useradd
Requires(post): /usr/sbin/groupadd

Recommends:     policycoreutils-python-utils
Recommends:     acl
Suggests:       niri
Suggests:       hyprland
Suggests:       sway

%description
DankMaterialShell greeter for greetd login manager. A modern, Material Design 3
inspired greeter interface built with Quickshell for Wayland compositors.

Supports multiple compositors including Niri, Hyprland, and Sway with automatic
compositor detection and configuration. Features session selection, user
authentication, and dynamic theming.

%prep
%setup -q -c -n dms-qml

%build

%install
# Install greeter files to shared data location
install -dm755 %{buildroot}%{_datadir}/quickshell/dms-greeter
cp -r %{_builddir}/dms-qml/* %{buildroot}%{_datadir}/quickshell/dms-greeter/

install -Dm755 %{_builddir}/dms-qml/Modules/Greetd/assets/dms-greeter %{buildroot}%{_bindir}/dms-greeter

install -Dm644 %{_builddir}/dms-qml/Modules/Greetd/README.md %{buildroot}%{_docdir}/dms-greeter/README.md

install -Dpm0644 %{_builddir}/dms-qml/systemd/tmpfiles-dms-greeter.conf %{buildroot}%{_tmpfilesdir}/dms-greeter.conf

install -Dm644 %{_builddir}/dms-qml/LICENSE %{buildroot}%{_docdir}/dms-greeter/LICENSE

install -dm755 %{buildroot}%{_sharedstatedir}/greeter

# Note: We do NOT install a PAM config here to avoid conflicting w/greetd packages
# Remove build and development files
rm -rf %{buildroot}%{_datadir}/quickshell/dms-greeter/.git*
rm -f %{buildroot}%{_datadir}/quickshell/dms-greeter/.gitignore
rm -rf %{buildroot}%{_datadir}/quickshell/dms-greeter/.github
rm -rf %{buildroot}%{_datadir}/quickshell/dms-greeter/distro

%posttrans
if [ -d "%{_sysconfdir}/xdg/quickshell/dms-greeter" ]; then
    # Remove directories & preserves any user-added files
    rmdir "%{_sysconfdir}/xdg/quickshell/dms-greeter" 2>/dev/null || true
    rmdir "%{_sysconfdir}/xdg/quickshell" 2>/dev/null || true
    rmdir "%{_sysconfdir}/xdg" 2>/dev/null || true
fi

%files
%license %{_docdir}/dms-greeter/LICENSE
%doc %{_docdir}/dms-greeter/README.md
%{_bindir}/dms-greeter
%{_datadir}/quickshell/dms-greeter/
%{_tmpfilesdir}/%{name}.conf

%pre
# Create greeter user/group if they don't exist
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

elif ! grep -q "dms-greeter" "$GREETD_CONFIG"; then
        BACKUP_FILE="${GREETD_CONFIG}.backup-$(date +%%Y%%m%%d-%%H%%M%%S)"
        cp "$GREETD_CONFIG" "$BACKUP_FILE" 2>/dev/null || true

        # Update command in default_session section
        sed -i "/^\[default_session\]/,/^\[/ s|^command =.*|command = \"/usr/bin/dms-greeter --command $COMPOSITOR\"|" "$GREETD_CONFIG"
        sed -i '/^\[default_session\]/,/^\[/ s|^user =.*|user = "greeter"|' "$GREETD_CONFIG"
        CONFIG_STATUS="Updated existing config (backed up) with $COMPOSITOR ✓"
fi

# Set graphical.target as default
CURRENT_TARGET=$(systemctl get-default 2>/dev/null || echo "unknown")
if [ "$CURRENT_TARGET" != "graphical.target" ]; then
	systemctl set-default graphical.target >/dev/null 2>&1 || true
	TARGET_STATUS="Set to graphical.target (was: $CURRENT_TARGET) ✓"
else
	TARGET_STATUS="Already graphical.target ✓"
fi

# Only show banner on initial install
if [ "$1" -eq 1 ]; then
cat << 'EOF'

=========================================================================
        DMS Greeter Installation Complete!
=========================================================================

Status:
EOF
echo "    ✓ Greetd config: $CONFIG_STATUS"
echo "    ✓ Default target: $TARGET_STATUS"
cat << 'EOF'
    ✓ Greeter user: Created
    ✓ Greeter directories: /var/cache/dms-greeter, /var/lib/greeter
    ✓ SELinux contexts: Applied

Next steps:

1. Enable the greeter:
     dms greeter enable
     (This will automatically disable gdm, sddm, or lightdm display managers,
      set graphical.target, and enable greetd)

2. Sync your theme with the greeter (optional):
     If you have DankMaterialShell (DMS) installed, you can sync theming with:
     dms greeter sync

3. Check your setup:
     dms greeter status

Ready to test? Run: sudo systemctl start greetd or simply log out/reboot your system
Documentation: https://danklinux.com/docs/dankgreeter/
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
* CHANGELOG_DATE_PLACEHOLDER AvengeMedia <contact@avengemedia.com> - VERSION_PLACEHOLDER-RELEASE_PLACEHOLDER
- Stable release VERSION_PLACEHOLDER
- Built from GitHub release
