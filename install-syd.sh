#!/bin/bash

# Syd Installation Script
# Installs and configures Syd application sandbox for Namada

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
if [[ $EUID -ne 0 ]]; then
    error "This script must be run as root (use sudo)"
fi

log "Starting Syd installation and configuration..."

# 1. Install dependencies
log "Installing build dependencies..."
apt update
apt install -y git curl build-essential libseccomp-dev pkg-config

# 2. Install Rust if not available
if ! command -v cargo &> /dev/null; then
    log "Installing Rust for Syd compilation..."
    curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y --default-toolchain stable
    export PATH="$HOME/.cargo/bin:$PATH"
    source ~/.cargo/env
else
    log "Rust is already installed"
fi

# 3. Build and install Syd
if ! command -v syd &> /dev/null; then
    log "Building Syd from source..."
    
    # Create temporary build directory
    TEMP_DIR=$(mktemp -d)
    cd "$TEMP_DIR"
    
    # Clone Syd repository
    git clone https://git.sr.ht/~alip/syd
    cd syd
    
    # Build Syd
    cargo build --release
    
    # Install Syd
    cp target/release/syd /usr/local/bin/
    chmod +x /usr/local/bin/syd
    
    # Clean up
    cd /
    rm -rf "$TEMP_DIR"
    
    log "Syd installed successfully"
else
    log "Syd is already installed"
fi

# 4. Create Syd configuration directory
log "Creating Syd configuration directory..."
mkdir -p /etc/syd/profiles

# 5. Create Namada Syd profile
log "Creating Syd profile for Namada node..."
cat > /etc/syd/profiles/namada.syd << 'EOF'
# Syd profile for Namada blockchain node
# Provides strong isolation while allowing necessary network and file operations

# Basic sandboxing categories
stat:deny
exec:allow
ioctl:allow
force:deny
network:allow
lock:allow
crypt:deny
proxy:deny
memory:allow
pid:allow

# Allow necessary paths for Namada
stat/allow: /opt/namada
stat/allow: /opt/namada/data
stat/allow: /opt/namada/config
stat/allow: /opt/namada/logs
stat/allow: /tmp
stat/allow: /dev/null
stat/allow: /dev/urandom
stat/allow: /dev/random
stat/allow: /proc/self
stat/allow: /proc/self/maps
stat/allow: /proc/self/status

# Network restrictions - allow blockchain networking
network/allow: unix
network/allow: inet
network/allow: inet6

# Exec restrictions - only allow Namada binary
exec/allow: /opt/namada/bin/namada
exec/allow: /bin/sh
exec/allow: /bin/bash

# Ioctl restrictions for necessary operations
ioctl/allow: TIOCGWINSZ
ioctl/allow: TIOCSWINSZ
ioctl/allow: TCGETS
ioctl/allow: TCSETS
ioctl/allow: FIONREAD

# Memory restrictions
memory/allow: mmap
memory/allow: mprotect
memory/allow: munmap
memory/allow: brk
memory/allow: madvise

# PID restrictions
pid/allow: getpid
pid/allow: getppid
pid/allow: getpgrp
pid/allow: setsid
pid/allow: getuid
pid/allow: getgid

# Lock restrictions using Landlock
lock/allow: /opt/namada
EOF

chmod 644 /etc/syd/profiles/namada.syd

# 6. Create Syd management script
log "Creating Syd management script..."
cat > /usr/local/bin/syd-manage.sh << 'EOF'
#!/bin/bash
# Syd management script for Namada

case "$1" in
    test)
        echo "Testing Syd with Namada profile..."
        if [[ -f "/etc/syd/profiles/namada.syd" ]]; then
            echo "Namada profile exists"
            syd -p namada --check
        else
            echo "Namada profile not found"
            exit 1
        fi
        ;;
    validate)
        echo "Validating Syd installation..."
        syd --version
        echo "Available profiles:"
        ls -la /etc/syd/profiles/
        ;;
    logs)
        echo "Syd debug mode - run with verbose logging"
        echo "Usage: syd -v -p namada <command>"
        ;;
    *)
        echo "Usage: $0 {test|validate|logs}"
        echo "  test     - Test Namada profile"
        echo "  validate - Validate Syd installation"
        echo "  logs     - Show how to enable verbose logging"
        exit 1
        ;;
esac
EOF

chmod +x /usr/local/bin/syd-manage.sh

# 7. Create test script for Namada sandboxing
log "Creating Namada sandbox test script..."
cat > /usr/local/bin/test-namada-sandbox.sh << 'EOF'
#!/bin/bash
# Test script for Namada sandboxing

echo "=== Testing Namada Sandbox ==="
echo "Date: $(date)"
echo ""

echo "=== Syd Version ==="
syd --version
echo ""

echo "=== Available Profiles ==="
ls -la /etc/syd/profiles/
echo ""

echo "=== Testing Namada Profile ==="
if syd -p namada --check; then
    echo "✓ Namada profile is valid"
else
    echo "✗ Namada profile has issues"
fi
echo ""

echo "=== Testing Sandbox Restrictions ==="
echo "Testing file access restrictions..."
if syd -p namada ls /root 2>/dev/null; then
    echo "✗ Sandbox allows access to /root (security issue)"
else
    echo "✓ Sandbox blocks access to /root"
fi

echo "Testing network restrictions..."
if syd -p namada ping -c 1 8.8.8.8 2>/dev/null; then
    echo "✓ Sandbox allows network access"
else
    echo "✗ Sandbox blocks network access"
fi
echo ""

echo "=== Testing Namada Binary Access ==="
if [[ -f "/opt/namada/bin/namada" ]]; then
    echo "Testing Namada binary in sandbox..."
    if syd -p namada /opt/namada/bin/namada --version 2>/dev/null; then
        echo "✓ Namada binary works in sandbox"
    else
        echo "✗ Namada binary fails in sandbox"
    fi
else
    echo "Namada binary not found at /opt/namada/bin/namada"
fi
echo ""

echo "=== Sandbox Test Complete ==="
EOF

chmod +x /usr/local/bin/test-namada-sandbox.sh

# 8. Final verification
log "Verifying Syd installation..."
if syd --version; then
    log "Syd installation verified successfully"
else
    error "Syd installation verification failed"
fi

# 9. Display summary
log "Syd installation completed!"
echo ""
echo -e "${GREEN}=== SYD INSTALLATION SUMMARY ===${NC}"
echo "✓ Syd binary installed at /usr/local/bin/syd"
echo "✓ Namada profile created at /etc/syd/profiles/namada.syd"
echo "✓ Management script created at /usr/local/bin/syd-manage.sh"
echo "✓ Test script created at /usr/local/bin/test-namada-sandbox.sh"
echo ""
echo -e "${BLUE}Available commands:${NC}"
echo "  syd-manage.sh test       # Test Namada profile"
echo "  syd-manage.sh validate   # Validate installation"
echo "  test-namada-sandbox.sh   # Run comprehensive sandbox tests"
echo ""
echo -e "${BLUE}Usage examples:${NC}"
echo "  # Run Namada in sandbox"
echo "  syd -p namada /opt/namada/bin/namada node ledger run"
echo ""
echo "  # Test sandbox restrictions"
echo "  syd -p namada ls /root  # Should fail"
echo "  syd -p namada ls /opt/namada  # Should work"
echo ""
echo -e "${YELLOW}Next steps:${NC}"
echo "1. Run test-namada-sandbox.sh to verify sandboxing works"
echo "2. Update your Namada systemd service to use: syd -p namada"
echo "3. Monitor sandbox logs for any issues"
echo ""
echo -e "${GREEN}Syd sandboxing is now ready for Namada!${NC}"
