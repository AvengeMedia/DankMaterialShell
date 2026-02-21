# Spec for DMS - uses rpkg macros for git builds

%global debug_package %{nil}
%global version {{{ git_repo_version }}}
%global pkg_summary DankMaterialShell - Material 3 inspired shell for Wayland compositors
%global go_toolchain_version 1.25.7

Name:           dms
Epoch:          2
Version:        %{version}
Release:        1%{?dist}
Summary:        %{pkg_summary}

License:        MIT
URL:            https://github.com/AvengeMedia/DankMaterialShell
VCS:            {{{ git_repo_vcs }}}
Source0:        {{{ git_repo_pack }}}
Source1:        https://go.dev/dl/go%{go_toolchain_version}.linux-amd64.tar.gz
Source2:        https://go.dev/dl/go%{go_toolchain_version}.linux-arm64.tar.gz

BuildRequires:  git-core
BuildRequires:  gzip
BuildRequires:  make
BuildRequires:  systemd-rpm-macros

# Core requirements
Requires:       (quickshell-git or quickshell)
Requires:       accountsservice
Requires:       dms-cli = %{epoch}:%{version}-%{release}
Requires:       dgop

# Core utilities (Recommended for DMS functionality)
Recommends:     cava
Recommends:     danksearch
Recommends:     matugen
Recommends:     quickshell-git

# Recommended system packages
Recommends:     NetworkManager
Recommends:     qt6-qtmultimedia
Suggests:       cups-pk-helper
Suggests:       qt6ct

%description
DankMaterialShell (DMS) is a modern Wayland desktop shell built with Quickshell
and optimized for the niri, hyprland, sway, and dwl (MangoWC) compositors. Features notifications,
app launcher, wallpaper customization, and fully customizable with plugins.

Includes auto-theming for GTK/Qt apps with matugen, 20+ customizable widgets,
process monitoring, notification center, clipboard history, dock, control center,
lock screen, and comprehensive plugin system.

%package -n dms-cli
Summary:        DankMaterialShell CLI tool
License:        MIT
URL:            https://github.com/AvengeMedia/DankMaterialShell

%description -n dms-cli
Command-line interface for DankMaterialShell configuration and management.
Provides native DBus bindings, NetworkManager integration, and system utilities.

%prep
{{{ git_repo_setup_macro }}}

%build
# Build DMS CLI from source (core/subdirectory)
VERSION="%{version}"
COMMIT=$(echo "%{version}" | grep -oP '[a-f0-9]{7,}' | head -n1 || echo "unknown")

# Use pinned bundled Go toolchain (deterministic across chroots)
case "%{_arch}" in
  x86_64)
    GO_TARBALL="%{_sourcedir}/go%{go_toolchain_version}.linux-amd64.tar.gz"
    ;;
  aarch64)
    GO_TARBALL="%{_sourcedir}/go%{go_toolchain_version}.linux-arm64.tar.gz"
    ;;
  *)
    echo "Unsupported architecture for bundled Go: %{_arch}"
    exit 1
    ;;
esac

rm -rf .go
tar -xzf "$GO_TARBALL"
mv go .go
export GOROOT="$PWD/.go"
export PATH="$GOROOT/bin:$PATH"
export GOTOOLCHAIN=local
go version

cd core
make dist VERSION="$VERSION" COMMIT="$COMMIT"

%install
# Install dms-cli binary (built from source)
case "%{_arch}" in
  x86_64)
    DMS_BINARY="dms-linux-amd64"
    ;;
  aarch64)
    DMS_BINARY="dms-linux-arm64"
    ;;
  *)
    echo "Unsupported architecture: %{_arch}"
    exit 1
    ;;
esac

install -Dm755 core/bin/${DMS_BINARY} %{buildroot}%{_bindir}/dms

# Shell completions
install -d %{buildroot}%{_datadir}/bash-completion/completions
install -d %{buildroot}%{_datadir}/zsh/site-functions
install -d %{buildroot}%{_datadir}/fish/vendor_completions.d
core/bin/${DMS_BINARY} completion bash > %{buildroot}%{_datadir}/bash-completion/completions/dms || :
core/bin/${DMS_BINARY} completion zsh > %{buildroot}%{_datadir}/zsh/site-functions/_dms || :
core/bin/${DMS_BINARY} completion fish > %{buildroot}%{_datadir}/fish/vendor_completions.d/dms.fish || :

# Install systemd user service
install -Dm644 assets/systemd/dms.service %{buildroot}%{_userunitdir}/dms.service

install -Dm644 assets/dms-open.desktop %{buildroot}%{_datadir}/applications/dms-open.desktop
install -Dm644 assets/danklogo.svg %{buildroot}%{_datadir}/icons/hicolor/scalable/apps/danklogo.svg

# Install shell files to shared data location
install -dm755 %{buildroot}%{_datadir}/quickshell/dms
cp -r quickshell/* %{buildroot}%{_datadir}/quickshell/dms/

# Remove build files
rm -rf %{buildroot}%{_datadir}/quickshell/dms/.git*
rm -f %{buildroot}%{_datadir}/quickshell/dms/.gitignore
rm -rf %{buildroot}%{_datadir}/quickshell/dms/.github
rm -rf %{buildroot}%{_datadir}/quickshell/dms/distro

%posttrans
# Signal running DMS instances to reload
pkill -USR1 -x dms >/dev/null 2>&1 || :

%files
%license LICENSE
%doc CONTRIBUTING.md
%doc quickshell/README.md
%{_datadir}/quickshell/dms/
%{_userunitdir}/dms.service
%{_datadir}/applications/dms-open.desktop
%{_datadir}/icons/hicolor/scalable/apps/danklogo.svg

%files -n dms-cli
%{_bindir}/dms
%{_datadir}/bash-completion/completions/dms
%{_datadir}/zsh/site-functions/_dms
%{_datadir}/fish/vendor_completions.d/dms.fish

%changelog
{{{ git_repo_changelog }}}
