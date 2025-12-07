#!/bin/bash
set -euo pipefail

# Build SRPM locally with correct tarball and upload to Copr
# Usage: ./create-upload-copr.sh VERSION [RELEASE]
# Example: ./create-upload-copr.sh 1.0.0 4

VERSION="${1:-1.0.0}"
RELEASE="${2:-1}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

echo "Building DMS v${VERSION}-${RELEASE} SRPM for Copr..."

# Setup build directories
mkdir -p ~/rpmbuild/{BUILD,BUILDROOT,RPMS,SOURCES,SPECS,SRPMS}
cd ~/rpmbuild/SOURCES

# Create the corrected QML tarball locally
echo "Creating QML tarball with assets..."
TEMP_DIR=$(mktemp -d)
cd "$REPO_ROOT"

# Copy quickshell contents to temp
cp -r quickshell/* "$TEMP_DIR/"

# Copy root LICENSE and CONTRIBUTING.md
cp LICENSE CONTRIBUTING.md "$TEMP_DIR/"

# Copy root assets directory (this is what was missing!)
cp -r assets "$TEMP_DIR/"

# Create tarball
cd "$TEMP_DIR"
tar --exclude='.git' \
    --exclude='.github' \
    --exclude='*.tar.gz' \
    -czf ~/rpmbuild/SOURCES/dms-qml.tar.gz .

cd ~/rpmbuild/SOURCES
echo "Created dms-qml.tar.gz with md5sum: $(md5sum dms-qml.tar.gz | awk '{print $1}')"
rm -rf "$TEMP_DIR"

# Generate spec file
echo "Generating spec file..."
CHANGELOG_DATE="$(date '+%a %b %d %Y')"

cat >~/rpmbuild/SPECS/dms.spec <<'SPECEOF'
# Spec for DMS stable releases - Built locally

%global debug_package %{nil}
%global version VERSION_PLACEHOLDER
%global pkg_summary DankMaterialShell - Material 3 inspired shell for Wayland compositors

Name:           dms
Version:        %{version}
Release:        RELEASE_PLACEHOLDER%{?dist}
Summary:        %{pkg_summary}

License:        MIT
URL:            https://github.com/AvengeMedia/DankMaterialShell

Source0:        dms-qml.tar.gz

BuildRequires:  gzip
BuildRequires:  wget
BuildRequires:  systemd-rpm-macros

Requires:       (quickshell or quickshell-git)
Requires:       accountsservice
Requires:       dms-cli = %{version}-%{release}
Requires:       dgop

Recommends:     cava
Recommends:     cliphist
Recommends:     danksearch
Recommends:     matugen
Recommends:     wl-clipboard
Recommends:     NetworkManager
Recommends:     qt6-qtmultimedia
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
License:        MIT
URL:            https://github.com/AvengeMedia/DankMaterialShell

%description -n dms-cli
Command-line interface for DankMaterialShell configuration and management.
Provides native DBus bindings, NetworkManager integration, and system utilities.

%prep
%setup -q -c -n dms-qml

# Download architecture-specific binaries during build
case "%{_arch}" in
  x86_64)
    ARCH_SUFFIX="amd64"
    ;;
  aarch64)
    ARCH_SUFFIX="arm64"
    ;;
  *)
    echo "Unsupported architecture: %{_arch}"
    exit 1
    ;;
esac

wget -O %{_builddir}/dms-cli.gz "https://github.com/AvengeMedia/DankMaterialShell/releases/download/v%{version}/dms-distropkg-${ARCH_SUFFIX}.gz" || {
  echo "Failed to download dms-cli for architecture %{_arch}"
  exit 1
}
gunzip -c %{_builddir}/dms-cli.gz > %{_builddir}/dms-cli
chmod +x %{_builddir}/dms-cli

%build

%install
install -Dm755 %{_builddir}/dms-cli %{buildroot}%{_bindir}/dms

install -d %{buildroot}%{_datadir}/bash-completion/completions
install -d %{buildroot}%{_datadir}/zsh/site-functions
install -d %{buildroot}%{_datadir}/fish/vendor_completions.d
%{_builddir}/dms-cli completion bash > %{buildroot}%{_datadir}/bash-completion/completions/dms || :
%{_builddir}/dms-cli completion zsh > %{buildroot}%{_datadir}/zsh/site-functions/_dms || :
%{_builddir}/dms-cli completion fish > %{buildroot}%{_datadir}/fish/vendor_completions.d/dms.fish || :

install -Dm644 assets/systemd/dms.service %{buildroot}%{_userunitdir}/dms.service

install -Dm644 assets/dms-open.desktop %{buildroot}%{_datadir}/applications/dms-open.desktop
install -Dm644 assets/danklogo.svg %{buildroot}%{_datadir}/icons/hicolor/scalable/apps/danklogo.svg

install -dm755 %{buildroot}%{_datadir}/quickshell/dms
cp -r %{_builddir}/dms-qml/* %{buildroot}%{_datadir}/quickshell/dms/

rm -rf %{buildroot}%{_datadir}/quickshell/dms/.git*
rm -f %{buildroot}%{_datadir}/quickshell/dms/.gitignore
rm -rf %{buildroot}%{_datadir}/quickshell/dms/.github
rm -rf %{buildroot}%{_datadir}/quickshell/dms/distro

echo "%{version}" > %{buildroot}%{_datadir}/quickshell/dms/VERSION

%posttrans
if [ -d "%{_sysconfdir}/xdg/quickshell/dms" ]; then
    rmdir "%{_sysconfdir}/xdg/quickshell/dms" 2>/dev/null || true
    rmdir "%{_sysconfdir}/xdg/quickshell" 2>/dev/null || true
    rmdir "%{_sysconfdir}/xdg" 2>/dev/null || true
fi
# Signal running DMS instances to reload
pkill -USR1 -x dms >/dev/null 2>&1 || :

%files
%license LICENSE
%doc README.md CONTRIBUTING.md
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
* CHANGELOG_DATE_PLACEHOLDER AvengeMedia <contact@avengemedia.com> - VERSION_PLACEHOLDER-1
- Stable release VERSION_PLACEHOLDER
- Built locally with corrected tarball
SPECEOF

sed -i "s/VERSION_PLACEHOLDER/${VERSION}/g" ~/rpmbuild/SPECS/dms.spec
sed -i "s/RELEASE_PLACEHOLDER/${RELEASE}/g" ~/rpmbuild/SPECS/dms.spec
sed -i "s/CHANGELOG_DATE_PLACEHOLDER/${CHANGELOG_DATE}/g" ~/rpmbuild/SPECS/dms.spec

# Build SRPM
echo "Building SRPM..."
cd ~/rpmbuild/SPECS
rpmbuild -bs dms.spec

SRPM=$(ls ~/rpmbuild/SRPMS/dms-"${VERSION}"-*.src.rpm | tail -n 1)
if [ ! -f "$SRPM" ]; then
    echo "Error: SRPM not found!"
    exit 1
fi

echo "SRPM built successfully: $SRPM"

# Check if copr-cli is installed
if ! command -v copr-cli &>/dev/null; then
    echo ""
    echo "copr-cli is not installed. Install it with:"
    echo "  pip install copr-cli"
    echo ""
    echo "Then configure it with your Copr API token in ~/.config/copr"
    echo ""
    echo "SRPM is ready at: $SRPM"
    echo "Upload manually with: copr-cli build avengemedia/dms $SRPM"
    exit 0
fi

# Upload to Copr
echo ""
echo "Uploading to Copr..."
if copr-cli build avengemedia/dms "$SRPM" --nowait; then
    echo ""
    echo "Build submitted successfully! Check status at:"
    echo "https://copr.fedorainfracloud.org/coprs/avengemedia/dms/builds/"
else
    echo ""
    echo "Copr upload failed. You can manually upload the SRPM:"
    echo "  copr-cli build avengemedia/dms $SRPM"
    echo ""
    echo "Or upload via web interface:"
    echo "  https://copr.fedorainfracloud.org/coprs/avengemedia/dms/builds/"
    echo ""
    echo "SRPM location: $SRPM"
    exit 1
fi
