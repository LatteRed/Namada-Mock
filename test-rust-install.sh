#!/bin/bash

# Test script for Rust/Cargo installation workflow
# This script tests the same workflow used in the hardening script

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging function
log() {
    echo -e "${GREEN}[$(date +'%Y-%m-%d %H:%M:%S')] $1${NC}"
}

warn() {
    echo -e "${YELLOW}[$(date +'%Y-%m-%d %H:%M:%S')] WARNING: $1${NC}"
}

error() {
    echo -e "${RED}[$(date +'%Y-%m-%d %H:%M:%S')] ERROR: $1${NC}"
    exit 1
}

info() {
    echo -e "${BLUE}[$(date +'%Y-%m-%d %H:%M:%S')] $1${NC}"
}

# Check if running as root
if [[ $EUID -eq 0 ]]; then
    warn "Running as root. This is acceptable for testing the hardening workflow."
fi

# Check if sudo is available
if ! command -v sudo &> /dev/null; then
    error "sudo is required but not installed."
fi

log "Starting Rust/Cargo installation test..."

# 1. Install dependencies
log "Step 1: Installing dependencies..."
sudo apt update
sudo apt install -y curl libseccomp-dev pkg-config

# 2. Create secure directories
log "Step 2: Creating secure directories..."
sudo mkdir -p /opt/rust/{cargo,rustup}
sudo mkdir -p /build/tmp
# Use current user or root if running as root
CURRENT_USER=${SUDO_USER:-root}
sudo chown -R $CURRENT_USER:$CURRENT_USER /opt/rust /build/tmp

# 3. Set up environment variables
log "Step 3: Setting up environment variables..."
export CARGO_HOME=/opt/rust/cargo
export RUSTUP_HOME=/opt/rust/rustup
export TMPDIR=/build/tmp
export PATH="/opt/rust/cargo/bin:$PATH"

# 4. Install rustup
log "Step 4: Installing rustup..."
curl --proto "=https" --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y --default-toolchain stable
source /opt/rust/cargo/env
rustup update

# 4.5. Make environment persistent
log "Step 4.5: Making Rust environment persistent..."
echo 'export CARGO_HOME=/opt/rust/cargo' >> ~/.bashrc
echo 'export RUSTUP_HOME=/opt/rust/rustup' >> ~/.bashrc
echo 'export PATH="/opt/rust/cargo/bin:$PATH"' >> ~/.bashrc
echo 'export TMPDIR=/build/tmp' >> ~/.bashrc

# 5. Test Rust installation
log "Step 5: Testing Rust installation..."
echo "Testing Rust installation:"
rustc --version
echo "Testing Cargo installation:"
cargo --version
echo "Testing Rustup installation:"
rustup --version
echo "Rust toolchain status:"
rustup show

# 6. Verify binaries are accessible
log "Step 6: Verifying binary accessibility..."
if bash -c 'source ~/.bashrc && rustc --version > /dev/null 2>&1'; then
    log "✅ Rust installation verified"
else
    error "❌ Rust installation failed"
fi

if bash -c 'source ~/.bashrc && cargo --version > /dev/null 2>&1'; then
    log "✅ Cargo installation verified"
else
    error "❌ Cargo installation failed"
fi

# 7. Test building a simple project
log "Step 7: Testing build workflow..."
cd /build/tmp
bash -c 'source ~/.bashrc && cargo new test-project --bin'
cd test-project
bash -c 'source ~/.bashrc && cargo build --release'

if [[ -f "target/release/test-project" ]]; then
    log "✅ Cargo build test successful"
else
    error "❌ Cargo build test failed"
fi

# 8. Test syd clone and build
log "Step 8: Testing syd clone and build..."
cd /build/tmp
git clone https://git.sr.ht/~alip/syd
cd syd
bash -c 'source ~/.bashrc && cargo build --release'

if [[ -f "target/release/syd" ]]; then
    log "✅ Syd build test successful"
    log "Syd binary size: $(du -h target/release/syd | cut -f1)"
else
    error "❌ Syd build test failed"
fi

# 9. Cleanup test
log "Step 9: Testing cleanup..."
cd /build/tmp
rm -rf test-project syd
log "✅ Cleanup test successful"

# 10. Final verification
log "Step 10: Final verification..."
echo "Rust environment summary:"
echo "  CARGO_HOME: $CARGO_HOME"
echo "  RUSTUP_HOME: $RUSTUP_HOME"
echo "  TMPDIR: $TMPDIR"
echo "  PATH includes: $(echo $PATH | grep -o '/opt/rust/cargo/bin')"
echo ""
echo "Directory contents:"
ls -la /opt/rust/
ls -la /build/tmp/
echo ""
echo "Rust toolchain info:"
rustup show
echo ""
echo "Cargo cache info:"
du -sh /opt/rust/cargo/

log "🎉 All tests passed! Rust/Cargo workflow is working correctly."
echo ""
echo -e "${GREEN}=== TEST SUMMARY ===${NC}"
echo "✅ Dependencies installed"
echo "✅ Secure directories created"
echo "✅ Rustup installed"
echo "✅ Rust/Cargo verified"
echo "✅ Build workflow tested"
echo "✅ Syd build successful"
echo "✅ Cleanup working"
echo "✅ Environment variables added to ~/.bashrc"
echo ""
echo -e "${BLUE}To use Rust tools in your current shell, run:${NC}"
echo "source ~/.bashrc"
echo ""
echo -e "${BLUE}Or start a new shell session.${NC}"
echo ""
echo -e "${BLUE}You can now use this workflow in the hardening script!${NC}"
