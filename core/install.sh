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

# Get the repository root directory
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Verify Go is installed
if ! command -v go &> /dev/null; then
    printf "%bError: Go is required to build from source but was not found.%b\n" "$RED" "$NC"
    printf "Please install Go (1.22 or higher) and try again.\n"
    exit 1
fi

printf "%bBuilding dankinstall from source...%b\n" "$GREEN" "$NC"
cd "$REPO_ROOT" || exit 1
go build -ldflags="-s -w" -o bin/dankinstall ./cmd/dankinstall

printf "%bRunning installer...%b\n" "$GREEN" "$NC"
./bin/dankinstall "$@"
