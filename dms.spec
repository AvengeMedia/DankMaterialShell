# Spec for DMS - uses rpkg macros for both stable and git builds

%global debug_package %{nil}
%global version {{{ git_dir_version }}}
%global pkg_summary DankMaterialShell - Material 3 inspired shell for Wayland compositors

Name:           dms
Version:        %{version}
Release:        1%{?dist}
Summary:        %{pkg_summary}

License:        GPL-3.0-only
URL:            https://github.com/AvengeMedia/DankMaterialShell
VCS:            {{{ git_dir_vcs }}}
Source0:        {{{ git_dir_pack }}}

# DMS CLI from danklinux latest release
Source1:        https://github.com/AvengeMedia/danklinux/releases/latest/download/dms-distropkg-amd64.gz

# DGOP binary from dgop latest release
Source2:        https://github.com/AvengeMedia/dgop/releases/latest/download/dgop-linux-amd64.gz

BuildRequires:  git-core
BuildRequires:  rpkg
BuildRequires:  gzip

# Core requirements
Requires:       (quickshell or quickshell-git)
Requires:       dms-cli
Requires:       dgop
Requires:       fira-code-fonts
Requires:       material-symbols-fonts
Requires:       rsms-inter-fonts

# Core utilities (Highly recommended for DMS functionality)
Recommends:     brightnessctl
Recommends:     cava
Recommends:     cliphist
Recommends:     hyprpicker
Recommends:     matugen
Recommends:     wl-clipboard

# Recommended system packages
Recommends:     gammastep
Recommends:     NetworkManager
Suggests:       qt6ct

%description
DankMaterialShell (DMS) is a modern Wayland desktop shell built with Quickshell
and optimized for the niri and hyprland compositors. Features notifications,
app launcher, wallpaper customization, and fully customizable with plugins.

Includes auto-theming for GTK/Qt apps with matugen, 20+ customizable widgets,
process monitoring, notification center, clipboard history, dock, control center,
lock screen, and comprehensive plugin system.

%package -n dms-cli
Summary:        DankMaterialShell CLI tool
License:        GPL-3.0-only
URL:            https://github.com/AvengeMedia/danklinux

%description -n dms-cli
Command-line interface for DankMaterialShell configuration and management.
Provides native DBus bindings, NetworkManager integration, and system utilities.

%package -n dgop
Summary:        Stateless CPU/GPU monitor for DankMaterialShell
License:        MIT
URL:            https://github.com/AvengeMedia/dgop
Provides:       dgop

%description -n dgop
DGOP is a stateless system monitoring tool that provides CPU, GPU, memory, and 
network statistics. Designed for integration with DankMaterialShell but can be 
used standalone. This package always includes the latest stable dgop release.

%prep
{{{ git_dir_setup_macro }}}

# Extract CLI binary
gunzip -c %{SOURCE1} > %{_builddir}/dms-cli
chmod +x %{_builddir}/dms-cli

# Extract DGOP binary
gunzip -c %{SOURCE2} > %{_builddir}/dgop
chmod +x %{_builddir}/dgop

%build
# DMS QML is source-only, binaries are prebuilt from releases

%install
# Install dms-cli binary
install -Dm755 %{_builddir}/dms-cli %{buildroot}%{_bindir}/dms

# Install dgop binary
install -Dm755 %{_builddir}/dgop %{buildroot}%{_bindir}/dgop

# Install shell files to XDG config location
install -dm755 %{buildroot}%{_sysconfdir}/xdg/quickshell/dms
cp -r * %{buildroot}%{_sysconfdir}/xdg/quickshell/dms/

# Remove build files
rm -rf %{buildroot}%{_sysconfdir}/xdg/quickshell/dms/.git*
rm -f %{buildroot}%{_sysconfdir}/xdg/quickshell/dms/.gitignore
rm -rf %{buildroot}%{_sysconfdir}/xdg/quickshell/dms/.github
rm -f %{buildroot}%{_sysconfdir}/xdg/quickshell/dms/*.spec

%files
%license LICENSE
%doc README.md CONTRIBUTING.md
%{_sysconfdir}/xdg/quickshell/dms/

%files -n dms-cli
%{_bindir}/dms

%files -n dgop
%{_bindir}/dgop

%changelog
{{{ git_dir_changelog }}}