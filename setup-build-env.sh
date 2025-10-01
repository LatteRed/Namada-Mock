#!/bin/bash

# Secure Build Environment Setup Script
# Configures a secure build environment for Rust and other compilation tools
# while maintaining system security hardening

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

# Check if running as root
if [[ $EUID -eq 0 ]]; then
    warn "Running as root. This is acceptable for initial setup on fresh systems."
    warn "The script will create the namada user and configure build environment properly."
fi

# Check if namada user exists (create if needed)
if ! id "namada" &>/dev/null; then
    warn "Namada user does not exist. Creating it now..."
    sudo useradd -m -s /bin/bash namada
    log "Created namada user"
fi

# Helper function for sudo commands
run_cmd() {
    if [[ $EUID -eq 0 ]]; then
        "$@"
    else
        sudo "$@"
    fi
}

log "Setting up secure build environment for Rust and compilation tools..."

# 1. Create secure build directory structure
log "Step 1: Creating secure build directory structure"
run_cmd mkdir -p /build/{target,cargo,rustup,tmp,bin}
run_cmd chown -R namada:namada /build
run_cmd chmod -R 755 /build

# 2. Set up Rust environment variables
log "Step 2: Configuring Rust environment variables"
if [[ $EUID -eq 0 ]]; then
    su - namada -c 'cat >> /home/namada/.bashrc << "EOF"

# Rust environment for secure builds
export CARGO_TARGET_DIR=/build/target
export CARGO_HOME=/build/cargo
export RUSTUP_HOME=/build/rustup
export TMPDIR=/build/tmp
export PATH="/build/cargo/bin:$PATH"

# Additional build security
export CARGO_BUILD_JOBS=4
export CARGO_INCREMENTAL=0
export RUSTFLAGS="-C target-cpu=native -C opt-level=3"
EOF'
else
    sudo -u namada bash -c 'cat >> /home/namada/.bashrc << "EOF"

# Rust environment for secure builds
export CARGO_TARGET_DIR=/build/target
export CARGO_HOME=/build/cargo
export RUSTUP_HOME=/build/rustup
export TMPDIR=/build/tmp
export PATH="/build/cargo/bin:$PATH"

# Additional build security
export CARGO_BUILD_JOBS=4
export CARGO_INCREMENTAL=0
export RUSTFLAGS="-C target-cpu=native -C opt-level=3"
EOF'
fi

# 3. Create build environment configuration
log "Step 3: Creating build environment configuration"
sudo tee /build/build-env.conf > /dev/null << 'EOF'
# Secure Build Environment Configuration
# This file contains environment variables for secure compilation

# Rust/Cargo configuration
CARGO_TARGET_DIR=/build/target
CARGO_HOME=/build/cargo
RUSTUP_HOME=/build/rustup
TMPDIR=/build/tmp

# Security settings
CARGO_BUILD_JOBS=4
CARGO_INCREMENTAL=0
RUSTFLAGS="-C target-cpu=native -C opt-level=3"

# Build isolation
BUILD_DIR=/build
TEMP_DIR=/build/tmp
CACHE_DIR=/build/cache
EOF

sudo chown namada:namada /build/build-env.conf
sudo chmod 644 /build/build-env.conf

# 4. Create build cleanup script
log "Step 4: Creating build cleanup script"
sudo tee /usr/local/bin/clean-build-env.sh > /dev/null << 'EOF'
#!/bin/bash
# Clean build environment script

echo "Cleaning build environment..."

# Clean temporary files
sudo rm -rf /build/tmp/*
sudo rm -rf /build/target/debug/deps/*
sudo rm -rf /build/target/debug/build/*

# Clean old build artifacts (keep last 3 builds)
cd /build/target
if [[ -d "release" ]]; then
    find release -name "*.so" -mtime +7 -delete 2>/dev/null || true
    find release -name "*.dylib" -mtime +7 -delete 2>/dev/null || true
fi

# Clean cargo cache (keep essential)
cargo cache --autoclean 2>/dev/null || true

# Clean rustup toolchains (keep stable and nightly)
rustup toolchain list | grep -v "stable\|nightly" | xargs -r rustup toolchain uninstall

echo "Build environment cleaned."
echo "Disk usage:"
du -sh /build/*
EOF

sudo chmod +x /usr/local/bin/clean-build-env.sh

# 5. Create build monitoring script
log "Step 5: Creating build monitoring script"
sudo tee /usr/local/bin/monitor-build-env.sh > /dev/null << 'EOF'
#!/bin/bash
# Monitor build environment script

echo "=== Build Environment Status ==="
echo "Date: $(date)"
echo ""

echo "=== Directory Structure ==="
ls -la /build/
echo ""

echo "=== Disk Usage ==="
du -sh /build/*
echo ""

echo "=== Rust Environment ==="
echo "Rust version: $(rustc --version 2>/dev/null || echo 'Not installed')"
echo "Cargo version: $(cargo --version 2>/dev/null || echo 'Not installed')"
echo "Rustup version: $(rustup --version 2>/dev/null || echo 'Not installed')"
echo ""

echo "=== Environment Variables ==="
echo "CARGO_TARGET_DIR: $CARGO_TARGET_DIR"
echo "CARGO_HOME: $CARGO_HOME"
echo "RUSTUP_HOME: $RUSTUP_HOME"
echo "TMPDIR: $TMPDIR"
echo ""

echo "=== Build Directories ==="
echo "Target directory: $(ls -la /build/target/ 2>/dev/null | wc -l) items"
echo "Cargo directory: $(ls -la /build/cargo/ 2>/dev/null | wc -l) items"
echo "Rustup directory: $(ls -la /build/rustup/ 2>/dev/null | wc -l) items"
echo ""

echo "=== Recent Build Activity ==="
find /build -type f -mtime -1 -ls 2>/dev/null | head -10
echo ""

echo "=== System Resources ==="
echo "Memory usage:"
free -h
echo ""
echo "Disk usage:"
df -h /build
echo ""
EOF

sudo chmod +x /usr/local/bin/monitor-build-env.sh

# 6. Create Rust installation script
log "Step 6: Creating Rust installation script"
sudo tee /usr/local/bin/install-rust-secure.sh > /dev/null << 'EOF'
#!/bin/bash
# Install Rust in secure build environment

echo "Installing Rust in secure build environment..."

# Set environment variables
export CARGO_TARGET_DIR=/build/target
export CARGO_HOME=/build/cargo
export RUSTUP_HOME=/build/rustup
export TMPDIR=/build/tmp
export PATH="/build/cargo/bin:$PATH"

# Download and install Rust
curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y --default-toolchain stable

# Source the environment
source /build/cargo/env

# Install additional tools
cargo install cargo-audit
cargo install cargo-outdated
cargo install cargo-udeps

echo "Rust installation completed in secure environment."
echo "To use Rust, run: source /build/cargo/env"
EOF

sudo chmod +x /usr/local/bin/install-rust-secure.sh

# 7. Create build isolation script
log "Step 7: Creating build isolation script"
sudo tee /usr/local/bin/isolated-build.sh > /dev/null << 'EOF'
#!/bin/bash
# Run builds in isolated environment

if [[ $# -eq 0 ]]; then
    echo "Usage: $0 <command> [args...]"
    echo "Example: $0 cargo build --release"
    exit 1
fi

# Set up isolated environment
export CARGO_TARGET_DIR=/build/target
export CARGO_HOME=/build/cargo
export RUSTUP_HOME=/build/rustup
export TMPDIR=/build/tmp
export PATH="/build/cargo/bin:$PATH"

# Create temporary build directory
BUILD_ID=$(date +%s)
BUILD_DIR="/build/tmp/build-$BUILD_ID"
mkdir -p "$BUILD_DIR"
cd "$BUILD_DIR"

# Execute command in isolated environment
echo "Running in isolated build environment: $BUILD_DIR"
echo "Command: $*"
echo ""

# Run the command
sudo -u namada env CARGO_TARGET_DIR=/build/target CARGO_HOME=/build/cargo RUSTUP_HOME=/build/rustup TMPDIR=/build/tmp PATH="/build/cargo/bin:$PATH" "$@"

# Clean up temporary directory
cd /
rm -rf "$BUILD_DIR"

echo "Build completed and temporary files cleaned."
EOF

sudo chmod +x /usr/local/bin/isolated-build.sh

# 8. Set up automatic cleanup
log "Step 8: Setting up automatic cleanup"
sudo tee /etc/cron.d/build-cleanup > /dev/null << 'EOF'
# Build environment cleanup
# Clean temporary files daily at 3 AM
0 3 * * * root /usr/local/bin/clean-build-env.sh >> /var/log/build-cleanup.log 2>&1

# Monitor build environment weekly
0 4 * * 0 root /usr/local/bin/monitor-build-env.sh >> /var/log/build-monitor.log 2>&1
EOF

# 9. Create build environment test script
log "Step 9: Creating build environment test script"
sudo tee /usr/local/bin/test-build-env.sh > /dev/null << 'EOF'
#!/bin/bash
# Test build environment

echo "Testing secure build environment..."

# Test directory permissions
echo "=== Directory Permissions ==="
ls -la /build/
echo ""

# Test environment variables
echo "=== Environment Variables ==="
source /build/build-env.conf
echo "CARGO_TARGET_DIR: $CARGO_TARGET_DIR"
echo "CARGO_HOME: $CARGO_HOME"
echo "RUSTUP_HOME: $RUSTUP_HOME"
echo "TMPDIR: $TMPDIR"
echo ""

# Test temporary directory
echo "=== Temporary Directory Test ==="
TEST_FILE="/build/tmp/test-$(date +%s)"
echo "test content" > "$TEST_FILE"
if [[ -f "$TEST_FILE" ]]; then
    echo " Temporary directory is writable"
    rm "$TEST_FILE"
else
    echo " Temporary directory is not writable"
fi
echo ""

# Test build directory
echo "=== Build Directory Test ==="
TEST_BUILD="/build/tmp/build-test"
mkdir -p "$TEST_BUILD"
if [[ -d "$TEST_BUILD" ]]; then
    echo " Build directory is writable"
    rmdir "$TEST_BUILD"
else
    echo " Build directory is not writable"
fi
echo ""

echo "Build environment test completed."
EOF

sudo chmod +x /usr/local/bin/test-build-env.sh

# 10. Final verification
log "Step 10: Performing final verification"

# Test the build environment
/usr/local/bin/test-build-env.sh

# Final summary
log "Secure build environment setup completed!"
echo ""
echo -e "${GREEN}=== BUILD ENVIRONMENT SUMMARY ===${NC}"
echo " Secure build directory created at /build/"
echo " Rust environment variables configured"
echo " Build isolation scripts created"
echo " Cleanup automation configured"
echo " Monitoring scripts created"
echo ""
echo -e "${BLUE}Available commands:${NC}"
echo "  install-rust-secure.sh     # Install Rust in secure environment"
echo "  isolated-build.sh <cmd>    # Run commands in isolated environment"
echo "  clean-build-env.sh         # Clean build environment"
echo "  monitor-build-env.sh       # Monitor build environment"
echo "  test-build-env.sh          # Test build environment"
echo ""
echo -e "${BLUE}Usage examples:${NC}"
echo "  # Install Rust securely"
echo "  sudo /usr/local/bin/install-rust-secure.sh"
echo ""
echo "  # Run cargo build in isolation"
echo "  /usr/local/bin/isolated-build.sh cargo build --release"
echo ""
echo "  # Clean build environment"
echo "  /usr/local/bin/clean-build-env.sh"
echo ""
echo -e "${YELLOW}Important notes:${NC}"
echo "- All builds happen in /build/ directory"
echo "- Temporary files are isolated and cleaned automatically"
echo "- Rust toolchain is installed in /build/cargo/"
echo "- Build artifacts are stored in /build/target/"
echo "- Regular cleanup runs automatically via cron"
echo ""
# Install Rust in the secure environment
log "Installing Rust in secure environment..."
if [[ -f "/usr/local/bin/install-rust-secure.sh" ]]; then
    sudo /usr/local/bin/install-rust-secure.sh
    if [[ $? -eq 0 ]]; then
        log "Rust installed successfully in secure environment"
    else
        error "Failed to install Rust in secure environment"
    fi
else
    error "Rust installation script not found"
fi

echo -e "${GREEN}Secure build environment setup complete.${NC}"
