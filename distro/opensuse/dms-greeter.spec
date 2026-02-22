# Spec for DMS Greeter - OpenSUSE/OBS

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

# Remove build and development files
rm -rf %{buildroot}%{_datadir}/quickshell/dms-greeter/.git*
rm -f %{buildroot}%{_datadir}/quickshell/dms-greeter/.gitignore
rm -rf %{buildroot}%{_datadir}/quickshell/dms-greeter/.github
rm -rf %{buildroot}%{_datadir}/quickshell/dms-greeter/distro

%posttrans
if [ -d "%{_sysconfdir}/xdg/quickshell/dms-greeter" ]; then
    rmdir "%{_sysconfdir}/xdg/quickshell/dms-greeter" 2>/dev/null || true
    rmdir "%{_sysconfdir}/xdg/quickshell" 2>/dev/null || true
    rmdir "%{_sysconfdir}/xdg" 2>/dev/null || true
fi

%files
%dir %{_docdir}/dms-greeter
%license %{_docdir}/dms-greeter/LICENSE
%doc %{_docdir}/dms-greeter/README.md
%{_bindir}/dms-greeter
%dir %{_datadir}/quickshell
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
# SELinux contexts (no-op on OpenSUSE - semanage/restorecon not present)
if [ -x /usr/sbin/semanage ] && [ -x /usr/sbin/restorecon ]; then
    semanage fcontext -a -t bin_t '%{_bindir}/dms-greeter' >/dev/null 2>&1 || true
    restorecon %{_bindir}/dms-greeter >/dev/null 2>&1 || true
    semanage fcontext -a -t user_home_dir_t '%{_sharedstatedir}/greeter(/.*)?' >/dev/null 2>&1 || true
    restorecon -R %{_sharedstatedir}/greeter >/dev/null 2>&1 || true
    semanage fcontext -a -t cache_home_t '%{_localstatedir}/cache/dms-greeter(/.*)?' >/dev/null 2>&1 || true
    restorecon -R %{_localstatedir}/cache/dms-greeter >/dev/null 2>&1 || true
    semanage fcontext -a -t usr_t '%{_datadir}/quickshell/dms-greeter(/.*)?' >/dev/null 2>&1 || true
    restorecon -R %{_datadir}/quickshell/dms-greeter >/dev/null 2>&1 || true
    restorecon %{_sysconfdir}/pam.d/greetd >/dev/null 2>&1 || true
fi

# Resolve greeter runtime account/group for distro differences
GREETER_USER="greeter"
for candidate in greeter greetd _greeter; do
    if getent passwd "$candidate" >/dev/null 2>&1; then
        GREETER_USER="$candidate"
        break
    fi
done

GREETER_GROUP="$GREETER_USER"
if ! getent group "$GREETER_GROUP" >/dev/null 2>&1; then
    for candidate in greeter greetd _greeter; do
        if getent group "$candidate" >/dev/null 2>&1; then
            GREETER_GROUP="$candidate"
            break
        fi
    done
fi

# Ensure proper ownership of greeter directories
chown -R "$GREETER_USER:$GREETER_GROUP" %{_localstatedir}/cache/dms-greeter 2>/dev/null || true
chown -R "$GREETER_USER:$GREETER_GROUP" %{_sharedstatedir}/greeter 2>/dev/null || true

# Verify PAM configuration
PAM_CONFIG="/etc/pam.d/greetd"
write_greetd_pam_config() {
    # openSUSE and Debian families usually expose PAM stacks as common-*
    if [ -f /etc/pam.d/common-auth ] && [ -f /etc/pam.d/common-account ] && [ -f /etc/pam.d/common-password ] && [ -f /etc/pam.d/common-session ]; then
        cat > "$PAM_CONFIG" << 'PAM_EOF'
#%PAM-1.0
auth       include     common-auth
account    required    pam_nologin.so
account    include     common-account
password   include     common-password
session    required    pam_loginuid.so
session    optional    pam_keyinit.so force revoke
session    include     common-session
PAM_EOF
        return
    fi

    # Fedora/RHEL style system-auth/postlogin stack
    if [ -f /etc/pam.d/system-auth ]; then
        if [ -f /etc/pam.d/postlogin ]; then
            cat > "$PAM_CONFIG" << 'PAM_EOF'
#%PAM-1.0
auth       substack    system-auth
auth       include     postlogin
account    required    pam_nologin.so
account    include     system-auth
password   include     system-auth
session    required    pam_loginuid.so
session    optional    pam_keyinit.so force revoke
session    include     system-auth
session    include     postlogin
PAM_EOF
        else
            cat > "$PAM_CONFIG" << 'PAM_EOF'
#%PAM-1.0
auth       include     system-auth
account    required    pam_nologin.so
account    include     system-auth
password   include     system-auth
session    required    pam_loginuid.so
session    optional    pam_keyinit.so force revoke
session    include     system-auth
PAM_EOF
        fi
        return
    fi

    # Last-resort conservative fallback
    cat > "$PAM_CONFIG" << 'PAM_EOF'
#%PAM-1.0
auth       required    pam_unix.so nullok
account    required    pam_unix.so
password   required    pam_unix.so nullok sha512
session    required    pam_unix.so
PAM_EOF
}

if [ ! -f "$PAM_CONFIG" ]; then
    write_greetd_pam_config
    chmod 644 "$PAM_CONFIG"
    [ "$1" -eq 1 ] && echo "Created PAM configuration for greetd"
else
    NEEDS_PAM_UPDATE=0
    if grep -q "common-auth" "$PAM_CONFIG"; then
        if [ ! -f /etc/pam.d/common-auth ]; then
            NEEDS_PAM_UPDATE=1
        fi
    elif grep -q "system-auth" "$PAM_CONFIG"; then
        if [ ! -f /etc/pam.d/system-auth ]; then
            NEEDS_PAM_UPDATE=1
        fi
    else
        NEEDS_PAM_UPDATE=1
    fi

    if [ "$NEEDS_PAM_UPDATE" -eq 1 ]; then
        cp "$PAM_CONFIG" "$PAM_CONFIG.backup-dms-greeter"
        write_greetd_pam_config
        chmod 644 "$PAM_CONFIG"
        [ "$1" -eq 1 ] && echo "Updated PAM configuration (old config backed up to $PAM_CONFIG.backup-dms-greeter)"
    fi
fi

# Auto-configure greetd config
GREETD_CONFIG="/etc/greetd/config.toml"
CONFIG_STATUS="Not modified (already configured)"

COMPOSITOR=""
for candidate in niri Hyprland sway; do
    if command -v "$candidate" >/dev/null 2>&1; then
        case "$candidate" in
            Hyprland)
                COMPOSITOR="hyprland"
                ;;
            *)
                COMPOSITOR="$candidate"
                ;;
        esac
        break
    fi
done

if [ ! -f "$GREETD_CONFIG" ]; then
    mkdir -p /etc/greetd
    if [ -n "$COMPOSITOR" ]; then
        cat > "$GREETD_CONFIG" << 'GREETD_EOF'
[terminal]
vt = 1

[default_session]
user = "GREETER_USER_PLACEHOLDER"
command = "/usr/bin/dms-greeter --command COMPOSITOR_PLACEHOLDER"
GREETD_EOF
        sed -i "s|GREETER_USER_PLACEHOLDER|$GREETER_USER|" "$GREETD_CONFIG"
        sed -i "s|COMPOSITOR_PLACEHOLDER|$COMPOSITOR|" "$GREETD_CONFIG"
        CONFIG_STATUS="Created new config with $COMPOSITOR ✓"
    else
        cat > "$GREETD_CONFIG" << 'GREETD_EOF'
[terminal]
vt = 1

[default_session]
user = "GREETER_USER_PLACEHOLDER"
command = "agreety --cmd /bin/login"
GREETD_EOF
        sed -i "s|GREETER_USER_PLACEHOLDER|$GREETER_USER|" "$GREETD_CONFIG"
        CONFIG_STATUS="Created safe fallback config (no supported compositor detected)"
    fi
elif ! grep -q "dms-greeter" "$GREETD_CONFIG"; then
    if [ -n "$COMPOSITOR" ]; then
        BACKUP_FILE="${GREETD_CONFIG}.backup-$(date +%%Y%%m%%d-%%H%%M%%S)"
        cp "$GREETD_CONFIG" "$BACKUP_FILE" 2>/dev/null || true
        sed -i "/^\[default_session\]/,/^\[/ s|^command =.*|command = \"/usr/bin/dms-greeter --command $COMPOSITOR\"|" "$GREETD_CONFIG"
        sed -i "/^\[default_session\]/,/^\[/ s|^user =.*|user = \"$GREETER_USER\"|" "$GREETD_CONFIG"
        CONFIG_STATUS="Updated existing config (backed up) with $COMPOSITOR ✓"
    else
        CONFIG_STATUS="Skipped dms-greeter command update (no supported compositor detected)"
    fi
fi

# Set graphical.target as default
CURRENT_TARGET=$(systemctl get-default 2>/dev/null || echo "unknown")
if [ "$CURRENT_TARGET" != "graphical.target" ]; then
    systemctl set-default graphical.target >/dev/null 2>&1 || true
    TARGET_STATUS="Set to graphical.target (was: $CURRENT_TARGET) ✓"
else
    TARGET_STATUS="Already graphical.target ✓"
fi

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
    ✓ SELinux contexts: Applied (if applicable)

Next steps:

1. Enable the greeter:
     dms greeter enable

2. Sync your theme with the greeter (optional):
     dms greeter sync

3. Check your setup:
     dms greeter status

Ready to test? Run: sudo systemctl start greetd
Documentation: https://danklinux.com/docs/dankgreeter/
=========================================================================

EOF
fi

%postun
if [ "$1" -eq 0 ] && [ -x /usr/sbin/semanage ]; then
    semanage fcontext -d '%{_bindir}/dms-greeter' 2>/dev/null || true
    semanage fcontext -d '%{_sharedstatedir}/greeter(/.*)?' 2>/dev/null || true
    semanage fcontext -d '%{_localstatedir}/cache/dms-greeter(/.*)?' 2>/dev/null || true
    semanage fcontext -d '%{_datadir}/quickshell/dms-greeter(/.*)?' 2>/dev/null || true
fi

%changelog
* CHANGELOG_DATE_PLACEHOLDER AvengeMedia <contact@avengemedia.com> - VERSION_PLACEHOLDER-RELEASE_PLACEHOLDER
- Stable release VERSION_PLACEHOLDER
- Initial OpenSUSE/OBS port from Fedora
