#!/bin/bash
set -euo pipefail

# Build SRPM locally with correct tarball and upload to Copr
# Usage: ./copr-upload.sh [PACKAGE] [VERSION] [RELEASE]
# Examples:
#   ./copr-upload.sh dms 1.0.3 1
#   ./copr-upload.sh dms-greeter 1.0.3 1

PACKAGE="${1:-dms}"
VERSION="${2:-}"
RELEASE="${3:-1}"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

# Determine Copr project based on package
if [ "$PACKAGE" = "dms" ]; then
    COPR_PROJECT="avengemedia/dms"
elif [ "$PACKAGE" = "dms-greeter" ]; then
    COPR_PROJECT="avengemedia/danklinux"
else
    echo "❌ Unknown package: $PACKAGE"
    echo "Supported packages: dms, dms-greeter"
    exit 1
fi

# Get version from latest release if not provided
if [ -z "$VERSION" ]; then
    echo "📦 Determining latest version..."
    VERSION=$(curl -s https://api.github.com/repos/AvengeMedia/DankMaterialShell/releases/latest | jq -r '.tag_name' | sed 's/^v//')
    if [ -z "$VERSION" ] || [ "$VERSION" = "null" ]; then
        echo "❌ Failed to determine version. Please specify manually."
        exit 1
    fi
    echo "✅ Using latest version: $VERSION"
fi

echo "Building ${PACKAGE} v${VERSION}-${RELEASE} SRPM for Copr..."

# Setup build directories
mkdir -p ~/rpmbuild/{BUILD,BUILDROOT,RPMS,SOURCES,SPECS,SRPMS}
cd ~/rpmbuild/SOURCES

# Download source tarball from GitHub releases
echo "📦 Downloading source tarball for v${VERSION}..."
if [ ! -f ~/rpmbuild/SOURCES/dms-qml.tar.gz ]; then
    wget -O ~/rpmbuild/SOURCES/dms-qml.tar.gz "https://github.com/AvengeMedia/DankMaterialShell/releases/download/v${VERSION}/dms-qml.tar.gz" || {
        echo "❌ Failed to download dms-qml.tar.gz for v${VERSION}"
        exit 1
    }
    echo "✅ Source tarball downloaded"
else
    echo "✅ Source tarball already exists"
fi

# Copy and prepare spec file
echo "📝 Preparing spec file..."
SPEC_FILE="$REPO_ROOT/distro/fedora/${PACKAGE}.spec"
if [ ! -f "$SPEC_FILE" ]; then
    echo "❌ Spec file not found: $SPEC_FILE"
    exit 1
fi

cp "$SPEC_FILE" ~/rpmbuild/SPECS/"${PACKAGE}".spec

# Replace placeholders in spec file
CHANGELOG_DATE="$(date '+%a %b %d %Y')"
sed -i "s/VERSION_PLACEHOLDER/${VERSION}/g" ~/rpmbuild/SPECS/"${PACKAGE}".spec
sed -i "s/RELEASE_PLACEHOLDER/${RELEASE}/g" ~/rpmbuild/SPECS/"${PACKAGE}".spec
sed -i "s/CHANGELOG_DATE_PLACEHOLDER/${CHANGELOG_DATE}/g" ~/rpmbuild/SPECS/"${PACKAGE}".spec

echo "✅ Spec file prepared for ${PACKAGE} v${VERSION}-${RELEASE}"

# Build SRPM
echo "🔨 Building SRPM..."
cd ~/rpmbuild/SPECS
rpmbuild -bs "${PACKAGE}".spec

SRPM=$(ls ~/rpmbuild/SRPMS/"${PACKAGE}"-"${VERSION}"-*.src.rpm | tail -n 1)
if [ ! -f "$SRPM" ]; then
    echo "❌ Error: SRPM not found!"
    echo "Expected pattern: ${PACKAGE}-${VERSION}-*.src.rpm"
    ls -la ~/rpmbuild/SRPMS/ || true
    exit 1
fi

echo "✅ SRPM built successfully: $SRPM"

# Check if copr-cli is installed
if ! command -v copr-cli &>/dev/null; then
    echo ""
    echo "⚠️  copr-cli is not installed. Install it with:"
    echo "  pip install copr-cli"
    echo ""
    echo "Then configure it with your Copr API token in ~/.config/copr"
    echo ""
    echo "SRPM is ready at: $SRPM"
    echo "Upload manually with: copr-cli build $COPR_PROJECT $SRPM"
    exit 0
fi

# Upload to Copr
echo ""
echo "🚀 Uploading to Copr..."
if copr-cli build "$COPR_PROJECT" "$SRPM" --nowait; then
    echo ""
    echo "✅ Build submitted successfully!"
    echo "📊 Check status at:"
    echo "   https://copr.fedorainfracloud.org/coprs/${COPR_PROJECT}/builds/"
    echo ""
    echo "📦 SRPM location: $SRPM"
else
    echo ""
    echo "❌ Copr upload failed. You can manually upload the SRPM:"
    echo "   copr-cli build $COPR_PROJECT $SRPM"
    echo ""
    echo "Or upload via web interface:"
    echo "   https://copr.fedorainfracloud.org/coprs/${COPR_PROJECT}/builds/"
    echo ""
    echo "SRPM location: $SRPM"
    exit 1
fi
