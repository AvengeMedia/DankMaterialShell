#!/usr/bin/env bash

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m' # No Color

# Check for root privileges
if [ "$(id -u)" == "0" ]; then
    printf "%bError: This script must not be run as root%b\n" "$RED" "$NC"
    exit 1
fi

# Check if running on Linux
if [ "$(uname)" != "Linux" ]; then
    printf "%bError: This installer only supports Linux systems%b\n" "$RED" "$NC"
    exit 1
fi

# Detect architecture
ARCH=$(uname -m)
case "$ARCH" in
x86_64)
    ARCH="amd64"
    ;;
aarch64)
    ARCH="arm64"
    ;;
*)
    printf "%bError: Unsupported architecture: %s%b\n" "$RED" "$ARCH" "$NC"
    printf "This installer only supports x86_64 (amd64) and aarch64 (arm64) architectures\n"
    exit 1
    ;;
esac

# Get the latest release version
LATEST_VERSION=$(curl -s https://api.github.com/repos/AvengeMedia/DankMaterialShell/releases/latest | grep '"tag_name":' | sed -E 's/.*"([^"]+)".*/\1/')

if [ -z "$LATEST_VERSION" ]; then
    printf "%bError: Could not fetch latest version%b\n" "$RED" "$NC"
    exit 1
fi

printf "%bInstalling Dankinstall %s for %s...%b\n" "$GREEN" "$LATEST_VERSION" "$ARCH" "$NC"

# Download and install
TEMP_DIR=$(mktemp -d)
cd "$TEMP_DIR" || exit 1

# Download the gzipped binary and its checksum
printf "%bDownloading installer...%b\n" "$GREEN" "$NC"
curl -L "https://github.com/AvengeMedia/DankMaterialShell/releases/download/$LATEST_VERSION/dankinstall-$ARCH.gz" -o "installer.gz"
curl -L "https://github.com/AvengeMedia/DankMaterialShell/releases/download/$LATEST_VERSION/dankinstall-$ARCH.gz.sha256" -o "expected.sha256"

# Get the expected checksum
EXPECTED_CHECKSUM=$(awk '{print $1}' expected.sha256)

# Calculate actual checksum
printf "%bVerifying checksum...%b\n" "$GREEN" "$NC"
ACTUAL_CHECKSUM=$(sha256sum installer.gz | awk '{print $1}')

# Compare checksums
if [ "$EXPECTED_CHECKSUM" != "$ACTUAL_CHECKSUM" ]; then
    printf "%bError: Checksum verification failed%b\n" "$RED" "$NC"
    printf "Expected: %s\n" "$EXPECTED_CHECKSUM"
    printf "Got:      %s\n" "$ACTUAL_CHECKSUM"
    printf "The downloaded file may be corrupted or tampered with\n"
    cd - >/dev/null
    rm -rf "$TEMP_DIR"
    exit 1
fi

# Decompress the binary
printf "%bDecompressing installer...%b\n" "$GREEN" "$NC"
gunzip installer.gz
chmod +x installer

# Execute the installer
printf "%bRunning installer...%b\n" "$GREEN" "$NC"
./installer

# Cleanup
cd - >/dev/null
rm -rf "$TEMP_DIR"
