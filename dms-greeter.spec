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

Requires:       greetd
Requires:       quickshell >= 0.1.0
Requires:       material-symbols-fonts

Suggests:       niri
Suggests:       hyprland
Suggests:       sway

Provides:       greetd-dms-greeter = %{version}-%{release}
Conflicts:      greetd-dms-greeter

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
# Install greeter files to XDG config location
install -dm755 %{buildroot}%{_sysconfdir}/xdg/quickshell/dms-greeter
cp -r * %{buildroot}%{_sysconfdir}/xdg/quickshell/dms-greeter/

# Install launcher script
install -Dm755 Modules/Greetd/assets/dms-greeter %{buildroot}%{_bindir}/dms-greeter

# Install documentation
install -Dm644 Modules/Greetd/README.md %{buildroot}%{_docdir}/dms-greeter/README.md

# Create cache directory for greeter data
install -dm750 %{buildroot}%{_sharedstatedir}/cache/dms-greeter

# Remove build and development files
rm -rf %{buildroot}%{_sysconfdir}/xdg/quickshell/dms-greeter/.git*
rm -f %{buildroot}%{_sysconfdir}/xdg/quickshell/dms-greeter/.gitignore
rm -rf %{buildroot}%{_sysconfdir}/xdg/quickshell/dms-greeter/.github
rm -f %{buildroot}%{_sysconfdir}/xdg/quickshell/dms-greeter/*.spec
rm -f %{buildroot}%{_sysconfdir}/xdg/quickshell/dms-greeter/dms.spec
rm -f %{buildroot}%{_sysconfdir}/xdg/quickshell/dms-greeter/dms-greeter.spec

%files
%license LICENSE
%doc %{_docdir}/dms-greeter/README.md
%{_bindir}/dms-greeter
%{_sysconfdir}/xdg/quickshell/dms-greeter/
%dir %attr(0750,greeter,greeter) %{_sharedstatedir}/cache/dms-greeter

%pre
# Create greeter user/group if they don't exist (greetd expects this)
getent group greeter >/dev/null || groupadd -r greeter
getent passwd greeter >/dev/null || \
    useradd -r -g greeter -d /var/lib/greeter -s /sbin/nologin \
    -c "System Greeter" greeter
exit 0

%changelog
{{{ git_dir_changelog }}}
