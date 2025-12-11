#!/bin/bash
# Ubuntu PPA uploader for DMS packages
# Usage: ./upload-ppa.sh <changes-file> <ppa-name>
#
# Example:
#   ./upload-ppa.sh ../dms_0.5.2ppa1_source.changes dms
#   ./upload-ppa.sh ../dms_0.5.2+git705.fdbb86appa1_source.changes dms-git

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

info() { echo -e "${BLUE}[INFO]${NC} $1"; }
success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
error() { echo -e "${RED}[ERROR]${NC} $1"; }

if [ $# -lt 2 ]; then
    error "Usage: $0 <changes-file> <ppa-name>"
    echo
    echo "Arguments:"
    echo "  changes-file : Path to .changes file (e.g., ../dms_0.5.2ppa1_source.changes)"
    echo "  ppa-name     : PPA to upload to (dms or dms-git)"
    echo
    echo "Examples:"
    echo "  $0 ../dms_0.5.2ppa1_source.changes dms"
    echo "  $0 ../dms_0.5.2+git705.fdbb86appa1_source.changes dms-git"
    exit 1
fi

CHANGES_FILE="$1"
PPA_NAME="$2"

# Validate changes file
if [ ! -f "$CHANGES_FILE" ]; then
    error "Changes file not found: $CHANGES_FILE"
    exit 1
fi

if [[ ! "$CHANGES_FILE" =~ \.changes$ ]]; then
    error "File must be a .changes file"
    exit 1
fi

# Validate PPA name
if [ "$PPA_NAME" != "dms" ] && [ "$PPA_NAME" != "dms-git" ] && [ "$PPA_NAME" != "danklinux" ]; then
    error "PPA name must be 'dms', 'dms-git', or 'danklinux'"
    exit 1
fi

# Get absolute path
CHANGES_FILE=$(realpath "$CHANGES_FILE")

info "Uploading to PPA: ppa:avengemedia/$PPA_NAME"
info "Changes file: $CHANGES_FILE"

# Check if dput is installed
if command -v dput &>/dev/null; then
    info "dput found"
else
    error "dput not found. Install with:"
    error "  sudo dnf install dput-ng"
    exit 1
fi

# Check if ~/.dput.cf exists
if [ ! -f "$HOME/.dput.cf" ]; then
    error "$HOME/.dput.cf not found!"
    echo
    info "Create it from template:"
    echo "  cp $(dirname "$0")/../dput.cf.template ~/.dput.cf"
    echo
    info "Or create it manually with:"
    cat <<'EOF'
[ppa:avengemedia/dms]
fqdn = ppa.launchpad.net
method = ftp
incoming = ~avengemedia/ubuntu/dms/
login = anonymous
allow_unsigned_uploads = 0

[ppa:avengemedia/dms-git]
fqdn = ppa.launchpad.net
method = ftp
incoming = ~avengemedia/ubuntu/dms-git/
login = anonymous
allow_unsigned_uploads = 0
EOF
    exit 1
fi

# Check if PPA is configured in dput.cf
if ! grep -q "^\[ppa:avengemedia/$PPA_NAME\]" "$HOME/.dput.cf"; then
    error "PPA 'ppa:avengemedia/$PPA_NAME' not found in ~/.dput.cf"
    echo
    info "Add this to ~/.dput.cf:"
    cat <<EOF
[ppa:avengemedia/$PPA_NAME]
fqdn = ppa.launchpad.net
method = ftp
incoming = ~avengemedia/ubuntu/$PPA_NAME/
login = anonymous
allow_unsigned_uploads = 0
EOF
    exit 1
fi

# Extract package info from changes file
PACKAGE_NAME=$(grep "^Source:" "$CHANGES_FILE" | awk '{print $2}')
VERSION=$(grep "^Version:" "$CHANGES_FILE" | awk '{print $2}')

info "Package: $PACKAGE_NAME"
info "Version: $VERSION"

# Show files that will be uploaded
echo
info "Files to be uploaded:"
grep "^ [a-f0-9]" "$CHANGES_FILE" | awk '{print "  - " $5}' || true

# Verify GPG signature
info "Verifying GPG signature..."
if gpg --verify "$CHANGES_FILE" 2>/dev/null; then
    success "GPG signature valid"
else
    error "GPG signature verification failed!"
    error "The .changes file must be signed with your GPG key"
    exit 1
fi

# Ask for confirmation
echo
warn "About to upload to: ppa:avengemedia/$PPA_NAME"
read -p "Continue? (y/N) " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    info "Upload cancelled"
    exit 0
fi

# Upload to PPA
info "Uploading to Launchpad..."
echo

UPLOAD_SUCCESS=false

if [ "$UPLOAD_METHOD" = "dput" ]; then
    if dput "ppa:avengemedia/$PPA_NAME" "$CHANGES_FILE"; then
        UPLOAD_SUCCESS=true
    fi
elif [ "$UPLOAD_METHOD" = "lftp" ]; then
    # Use lftp to upload to Launchpad PPA
    CHANGES_DIR=$(dirname "$CHANGES_FILE")
    CHANGES_BASENAME=$(basename "$CHANGES_FILE")

    # Extract files to upload from .changes file
    FILES_TO_UPLOAD=("$CHANGES_BASENAME")
    while IFS= read -r line; do
        if [[ "$line" =~ ^\ [a-f0-9]+\ [0-9]+\ [^\ ]+\ [^\ ]+\ (.+)$ ]]; then
            FILES_TO_UPLOAD+=("${BASH_REMATCH[1]}")
        fi
    done < "$CHANGES_FILE"

    # Build lftp command to upload all files
    LFTP_COMMANDS="set ftp:ssl-allow no; open ftp://ppa.launchpad.net; user anonymous ''; cd ~avengemedia/ubuntu/$PPA_NAME/;"
    for file in "${FILES_TO_UPLOAD[@]}"; do
        LFTP_COMMANDS="$LFTP_COMMANDS put '$CHANGES_DIR/$file';"
    done
    LFTP_COMMANDS="$LFTP_COMMANDS bye"

    if echo "$LFTP_COMMANDS" | lftp; then
        UPLOAD_SUCCESS=true
    fi
fi

if [ "$UPLOAD_SUCCESS" = true ]; then
    echo
    success "Upload successful!"
    echo
    info "Monitor build progress at:"
    echo "  https://launchpad.net/~avengemedia/+archive/ubuntu/$PPA_NAME/+packages"
    echo
    info "Builds typically take 5-30 minutes depending on:"
    echo "  - Build queue length"
    echo "  - Package complexity"
    echo "  - Number of target Ubuntu series"
    echo
    info "Once built, users can install with:"
    echo "  sudo add-apt-repository ppa:avengemedia/$PPA_NAME"
    echo "  sudo apt update"
    echo "  sudo apt install $PACKAGE_NAME"
else
    error "Upload failed!"
    echo
    info "Common issues:"
    echo "  - GPG key not verified on Launchpad (check https://launchpad.net/~/+editpgpkeys)"
    echo "  - Version already uploaded (must increment version number)"
    echo "  - Network/firewall blocking FTP (try HTTPS method in dput.cf)"
    echo "  - Email in changelog doesn't match GPG key email"
    exit 1
fi
