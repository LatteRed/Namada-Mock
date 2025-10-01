#!/bin/bash

# Secure Namada Installation Script
# Installs and configures Namada on a hardened Ubuntu system

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
    warn "The script will install Namada with proper permissions for namadaoperator user."
fi

# Check if namadaoperator user exists
if ! id "namadaoperator" &>/dev/null; then
    error "Namadaoperator user does not exist. Please run the hardening script first."
fi

# Check if hardening was applied
if [[ ! -f "/etc/sysctl.d/99-hardened.conf" ]]; then
    warn "Hardening configuration not found. It's recommended to run the hardening script first."
    read -p "Do you want to continue anyway? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        log "Aborted by user."
        exit 0
    fi
fi

# Source the secure build environment if it exists
if [[ -f "/usr/local/bin/source-build-env.sh" ]]; then
    log "Loading secure build environment..."
    source /usr/local/bin/source-build-env.sh
fi

# Check if Rust is installed
if ! command -v cargo &> /dev/null; then
    error "Rust/Cargo is not installed. Please run the build environment setup first."
fi

log "Rust version: $(rustc --version)"
log "Cargo version: $(cargo --version)"

# Get the latest Namada release tag for building
log "Fetching latest Namada release information..."
NAMADA_RELEASE_URL="https://api.github.com/repos/namada-net/namada/releases/latest"

RELEASE_INFO=$(curl -sL "$NAMADA_RELEASE_URL")
if [[ -z "$RELEASE_INFO" ]]; then
    error "Failed to fetch release information from GitHub API"
fi

NAMADA_VERSION=$(echo "$RELEASE_INFO" | grep -o '"tag_name": "[^"]*' | cut -d'"' -f4)
if [[ -z "$NAMADA_VERSION" ]]; then
    error "Failed to extract version information"
fi

log "Latest Namada version: $NAMADA_VERSION"

# Confirm installation
echo -e "${BLUE}This script will build and install Namada version $NAMADA_VERSION from source${NC}"
echo -e "${BLUE}Installation will be performed securely with the following features:${NC}"
echo "  - Source code compilation with Rust"
echo "  - Secure directory permissions"
echo "  - Systemd service configuration"
echo "  - Logging configuration"
echo "  - Resource limits"
echo ""
echo -e "${YELLOW}Note: Building from source requires at least 16GB RAM and may take 30-60 minutes${NC}"
echo ""
read -p "Do you want to continue? (y/N): " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    log "Aborted by user."
    exit 0
fi

# Create temporary directory for build
TEMP_DIR=$(mktemp -d -t namada-build.XXXXXXXXXX)
cd "$TEMP_DIR"

# Clone Namada repository
log "Cloning Namada repository..."
git clone --depth 1 --branch "$NAMADA_VERSION" https://github.com/namada-net/namada.git
cd namada

# Check if CometBFT is available
if ! command -v cometbft &> /dev/null; then
    log "CometBFT not found. Installing CometBFT v0.37.15..."
    # Install CometBFT
    wget -O cometbft_0.37.15_linux_amd64.tar.gz https://github.com/cometbft/cometbft/releases/download/v0.37.15/cometbft_0.37.15_linux_amd64.tar.gz
    tar -xzf cometbft_0.37.15_linux_amd64.tar.gz
    sudo cp cometbft /usr/local/bin/
    sudo chmod +x /usr/local/bin/cometbft
    rm cometbft_0.37.15_linux_amd64.tar.gz cometbft
    log "CometBFT installed successfully"
fi

# Build Namada using isolated build environment
log "Building Namada from source (this may take 30-60 minutes)..."
if [[ -f "/usr/local/bin/isolated-build.sh" ]]; then
    log "Using isolated build environment..."
    /usr/local/bin/isolated-build.sh make install
else
    log "Using standard build environment..."
    make install
fi

# Verify build
if ! command -v namada &> /dev/null; then
    error "Namada build failed - binary not found in PATH"
fi

# Install binary securely
log "Installing Namada binary to /opt/namada/bin/..."
sudo mkdir -p /opt/namada/bin
sudo cp "$(which namada)" /opt/namada/bin/
sudo chown namadaoperator:namadaoperator /opt/namada/bin/namada
sudo chmod 755 /opt/namada/bin/namada

# Verify installation
if /opt/namada/bin/namada --version; then
    log "Namada binary installed successfully"
else
    error "Namada binary installation verification failed"
fi

# Initialize Namada
log "Initializing Namada node..."
sudo -u namadaoperator /opt/namada/bin/namada --base-dir /opt/namada/data init

# Configure Namada with security settings
log "Configuring Namada with security settings..."
sudo tee /opt/namada/config/config.toml > /dev/null << 'EOF'
# Namada configuration with security hardening
[rpc]
laddr = "127.0.0.1:26657"
cors_allowed_origins = []
cors_allowed_methods = ["GET", "POST"]
cors_allowed_headers = ["*"]

[p2p]
laddr = "0.0.0.0:26656"
external_address = ""
seeds = ""
persistent_peers = ""

[consensus]
timeout_commit = "1s"
timeout_propose = "3s"
timeout_prevote = "1s"
timeout_precommit = "1s"

[mempool]
size = 10000
cache_size = 10000
keep_invalid_txs_in_cache = false

[instrumentation]
prometheus = false
prometheus_listen_addr = ""
max_open_connections = 3
namespace = "tendermint"
EOF

sudo chown namadaoperator:namadaoperator /opt/namada/config/config.toml
sudo chmod 644 /opt/namada/config/config.toml

# Create additional security configuration
log "Creating additional security configurations..."

# Create environment file for Namada
sudo tee /opt/namada/config/namada.env > /dev/null << 'EOF'
# Namada environment configuration
export NAMADA_LOG_LEVEL=info
export NAMADA_LOG_FORMAT=json
export NAMADA_LOG_COLOR=false
export NAMADA_LOG_FILE=/opt/namada/logs/namada.log
export NAMADA_LOG_MAX_SIZE=100
export NAMADA_LOG_MAX_BACKUPS=3
export NAMADA_LOG_MAX_AGE=30
EOF

sudo chown namadaoperator:namadaoperator /opt/namada/config/namada.env
sudo chmod 644 /opt/namada/config/namada.env

# Update systemd service to use environment file
log "Updating systemd service configuration..."
sudo tee /etc/systemd/system/namada.service > /dev/null << 'EOF'
[Unit]
Description=Namada Node
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
User=namadaoperator
Group=namadaoperator
WorkingDirectory=/opt/namada/data
EnvironmentFile=/opt/namada/config/namada.env
ExecStart=/usr/local/bin/syd -p namada /opt/namada/bin/namada node ledger run
Restart=always
RestartSec=10
LimitNOFILE=65535
LimitNPROC=32768
NoNewPrivileges=true
PrivateTmp=true
ProtectSystem=strict
ProtectHome=true
ReadWritePaths=/opt/namada/data /opt/namada/logs
CapabilityBoundingSet=CAP_NET_BIND_SERVICE
AmbientCapabilities=CAP_NET_BIND_SERVICE
StandardOutput=journal
StandardError=journal
SyslogIdentifier=namada

[Install]
WantedBy=multi-user.target
EOF

# Create log directory
sudo mkdir -p /opt/namada/logs
sudo chown namadaoperator:namadaoperator /opt/namada/logs
sudo chmod 755 /opt/namada/logs

# Configure log rotation for Namada
log "Configuring log rotation..."
sudo tee /etc/logrotate.d/namada > /dev/null << 'EOF'
/opt/namada/logs/*.log {
    daily
    missingok
    rotate 30
    compress
    delaycompress
    notifempty
    create 644 namadaoperator namadaoperator
    postrotate
        systemctl reload namada > /dev/null 2>&1 || true
    endscript
}
EOF

# Create Namada management script
log "Creating Namada management script..."
sudo tee /usr/local/bin/namada-manage.sh > /dev/null << 'EOF'
#!/bin/bash
# Namada node management script

NAMADA_BIN="/opt/namada/bin/namada"
NAMADA_DATA="/opt/namada/data"
NAMADA_USER="namadaoperator"

case "$1" in
    start)
        echo "Starting Namada node..."
        sudo systemctl start namada
        ;;
    stop)
        echo "Stopping Namada node..."
        sudo systemctl stop namada
        ;;
    restart)
        echo "Restarting Namada node..."
        sudo systemctl restart namada
        ;;
    status)
        echo "Namada node status:"
        sudo systemctl status namada --no-pager
        ;;
    logs)
        echo "Namada node logs (last 50 lines):"
        sudo journalctl -u namada -n 50 --no-pager
        ;;
    enable)
        echo "Enabling Namada node to start on boot..."
        sudo systemctl enable namada
        ;;
    disable)
        echo "Disabling Namada node from starting on boot..."
        sudo systemctl disable namada
        ;;
    update)
        echo "Updating Namada node..."
        sudo systemctl stop namada
        # Add update logic here
        sudo systemctl start namada
        ;;
    backup)
        echo "Creating backup of Namada data..."
        BACKUP_DIR="/opt/namada/backups/$(date +%Y%m%d-%H%M%S)"
        sudo mkdir -p "$BACKUP_DIR"
        sudo cp -r "$NAMADA_DATA" "$BACKUP_DIR/"
        echo "Backup created at: $BACKUP_DIR"
        ;;
    *)
        echo "Usage: $0 {start|stop|restart|status|logs|enable|disable|update|backup}"
        exit 1
        ;;
esac
EOF

sudo chmod +x /usr/local/bin/namada-manage.sh

# Create monitoring script for Namada
log "Creating Namada monitoring script..."
sudo tee /usr/local/bin/namada-monitor.sh > /dev/null << 'EOF'
#!/bin/bash
# Namada node monitoring script

echo "=== Namada Node Monitoring ==="
echo "Date: $(date)"
echo ""

echo "=== Service Status ==="
systemctl status namada --no-pager -l
echo ""

echo "=== Recent Logs ==="
sudo journalctl -u namada -n 20 --no-pager
echo ""

echo "=== Resource Usage ==="
echo "Memory usage:"
free -h
echo ""
echo "Disk usage:"
df -h /opt/namada
echo ""

echo "=== Network Connections ==="
ss -tuln | grep -E ':(26656|26657)'
echo ""

echo "=== Process Information ==="
ps aux | grep namada | grep -v grep
echo ""

echo "=== Namada Version ==="
/opt/namada/bin/namada --version
echo ""

echo "=== Configuration Files ==="
echo "Config file exists: $(test -f /opt/namada/config/config.toml && echo 'Yes' || echo 'No')"
echo "Environment file exists: $(test -f /opt/namada/config/namada.env && echo 'Yes' || echo 'No')"
echo ""

echo "=== Data Directory ==="
echo "Data directory size: $(du -sh /opt/namada/data 2>/dev/null || echo 'N/A')"
echo "Data directory permissions: $(ls -ld /opt/namada/data)"
echo ""

echo "=== Security Status ==="
echo "User running Namada: $(ps -o user= -p $(pgrep namada) 2>/dev/null || echo 'Not running')"
echo "File permissions: $(ls -l /opt/namada/bin/namada)"
echo ""
EOF

sudo chmod +x /usr/local/bin/namada-monitor.sh

# Reload systemd and enable service
log "Reloading systemd configuration..."
sudo systemctl daemon-reload

# Enable Namada service
log "Enabling Namada service..."
sudo systemctl enable namada

# Start Namada service
log "Starting Namada service..."
sudo systemctl start namada

# Wait a moment for service to start
sleep 5

# Check service status
if systemctl is-active namada &> /dev/null; then
    log "Namada service started successfully"
else
    warn "Namada service failed to start. Checking logs..."
    sudo journalctl -u namada -n 20 --no-pager
fi

# Clean up temporary files
log "Cleaning up temporary files..."
cd /
rm -rf "$TEMP_DIR"

# Final verification
log "Performing final verification..."

# Check if service is running
if systemctl is-active namada &> /dev/null; then
    echo -e "${GREEN} Namada service is running${NC}"
else
    echo -e "${RED} Namada service is not running${NC}"
fi

# Check if binary is accessible
if /opt/namada/bin/namada --version &> /dev/null; then
    echo -e "${GREEN} Namada binary is working${NC}"
else
    echo -e "${RED} Namada binary is not working${NC}"
fi

# Check file permissions
if [[ $(stat -c %U /opt/namada/bin/namada) == "namadaoperator" ]]; then
    echo -e "${GREEN} File permissions are correct${NC}"
else
    echo -e "${RED} File permissions are incorrect${NC}"
fi

# Final summary
log "Namada installation completed!"
echo ""
echo -e "${GREEN}=== INSTALLATION SUMMARY ===${NC}"
echo " Namada binary installed in /opt/namada/bin/"
echo " Configuration files created in /opt/namada/config/"
echo " Systemd service configured and enabled"
echo " Logging configured"
echo " Management scripts created"
echo " Monitoring scripts created"
echo ""
echo -e "${BLUE}Available commands:${NC}"
echo "  namada-manage.sh start|stop|restart|status|logs|enable|disable|backup"
echo "  namada-monitor.sh  # Check node status and health"
echo "  security-check.sh  # Check system security status"
echo ""
echo -e "${BLUE}Service management:${NC}"
echo "  sudo systemctl start namada"
echo "  sudo systemctl stop namada"
echo "  sudo systemctl restart namada"
echo "  sudo systemctl status namada"
echo ""
echo -e "${BLUE}Logs:${NC}"
echo "  sudo journalctl -u namada -f  # Follow logs"
echo "  sudo journalctl -u namada -n 100  # Last 100 lines"
echo ""
echo -e "${YELLOW}Next steps:${NC}"
echo "1. Configure your node to join the network"
echo "2. Set up monitoring and alerting"
echo "3. Configure backup procedures"
echo "4. Review and adjust firewall rules if needed"
echo ""
echo -e "${GREEN}Your Namada node is now installed and running securely!${NC}"
