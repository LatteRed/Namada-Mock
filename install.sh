#!/bin/bash

# Simple launcher script for hardened Namada setup
# This is the main entry point for the complete setup process

set -euo pipefail

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${BLUE}"
echo "╔══════════════════════════════════════════════════════════════════════════════╗"
echo "║                    HARDENED NAMADA NODE SETUP                               ║"
echo "║                                                                              ║"
echo "║  This sets up a hardened Ubuntu system for running a Namada node       ║"
echo "║  with HardenedBSD-style security features.                                  ║"
echo "╚══════════════════════════════════════════════════════════════════════════════╝"
echo -e "${NC}"

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Check if main script exists
if [[ ! -f "$SCRIPT_DIR/setup-hardened-namada.sh" ]]; then
    echo -e "${YELLOW}Error: setup-hardened-namada.sh not found in $SCRIPT_DIR${NC}"
    exit 1
fi

# Make sure main script is executable
chmod +x "$SCRIPT_DIR/setup-hardened-namada.sh"

# Run the main setup script
echo -e "${GREEN}Starting hardened Namada setup...${NC}"
echo ""

exec "$SCRIPT_DIR/setup-hardened-namada.sh" "$@"
