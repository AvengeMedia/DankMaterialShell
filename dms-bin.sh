#!/usr/bin/env bash
# Build script wrapper for dms-cli core binaries
# Forwards make commands to core/Makefile

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CORE_DIR="$SCRIPT_DIR/core"

# Colors for output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Check if core directory exists
if [ ! -d "$CORE_DIR" ]; then
    echo "Error: core directory not found at $CORE_DIR"
    exit 1
fi

# If no arguments provided, build and install
if [ $# -eq 0 ]; then
    echo -e "${BLUE}Building and installing DMS CLI binary...${NC}"
    cd "$CORE_DIR"
    make && sudo make install
    exit 0
fi

# Forward all arguments to make in core directory
echo -e "${GREEN}Building in core directory...${NC}"
cd "$CORE_DIR"
make "$@"
