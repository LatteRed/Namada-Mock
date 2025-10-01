#!/bin/bash

# Housefire Testnet Node Setup Script V2
# Based on Namada Node Mastery guide and official documentation

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

# Housefire testnet configuration
CHAIN_ID="housefire-alpaca.cc0d3e0c033be"
NAMADA_BIN="/opt/namada/bin/namada"
NAMADA_DATA_DIR="/opt/namada/data"

log "Starting Housefire testnet node setup V2 (Based on Namada Node Mastery guide)..."

# Check if running as root
if [[ $EUID -ne 0 ]]; then
    error "This script must be run as root or with sudo."
fi

# Check if Namada is installed
if [[ ! -f "$NAMADA_BIN" ]]; then
    error "Namada is not installed at $NAMADA_BIN. Please install Namada first."
fi

log "Namada version: $($NAMADA_BIN --version)"

# Check if namadaoperator user exists
if ! id "namadaoperator" &>/dev/null; then
    error "Namadaoperator user does not exist. Please run the setup scripts first."
fi

# Step 1: Clean up any existing configuration
log "Step 1: Cleaning up existing configuration..."
sudo rm -rf "$NAMADA_DATA_DIR"
sudo mkdir -p "$NAMADA_DATA_DIR"
sudo chown namadaoperator:namadaoperator "$NAMADA_DATA_DIR"

# Step 2: Set up proper data directory structure (following the guide)
log "Step 2: Setting up data directory structure..."

# Create the standard Namada data directory structure
sudo -u namadaoperator mkdir -p "$NAMADA_DATA_DIR"
sudo -u namadaoperator mkdir -p "$NAMADA_DATA_DIR/$CHAIN_ID"

# Step 3: Try to join the network using the official method
log "Step 3: Attempting to join Housefire testnet network..."

# Set environment variables
export CHAIN_ID="$CHAIN_ID"
export NAMADA_CHAIN_ID="$CHAIN_ID"

# Try the official join-network command
if sudo -u namadaoperator $NAMADA_BIN client utils join-network \
    --chain-id "$CHAIN_ID" \
    --add-persistent-peers \
    --base-dir "$NAMADA_DATA_DIR" 2>/dev/null; then
    log "✓ Successfully joined Housefire testnet using official method!"
else
    warn "Official join-network failed (expected for Housefire testnet)"
    warn "Setting up manual configuration for Housefire testnet..."
    
    # Create minimal configuration for Housefire testnet
    sudo -u namadaoperator tee "$NAMADA_DATA_DIR/$CHAIN_ID/config.toml" > /dev/null << EOF
# Housefire testnet configuration
chain_id = "$CHAIN_ID"
log_level = "info"

[cometbft]
log_level = "info"

[rpc]
laddr = "tcp://127.0.0.1:26657"
cors_allowed_origins = []
cors_allowed_methods = ["GET", "POST"]
cors_allowed_headers = ["*"]

[p2p]
laddr = "tcp://0.0.0.0:26656"
external_address = ""
persistent_peers = ""
unconditional_peer_ids = ""
private_peer_ids = ""
EOF

    # Create minimal genesis file
    sudo -u namadaoperator tee "$NAMADA_DATA_DIR/$CHAIN_ID/genesis.json" > /dev/null << EOF
{
  "genesis_time": "2025-01-01T00:00:00Z",
  "chain_id": "$CHAIN_ID",
  "consensus_params": {
    "block": {
      "max_bytes": "22020096",
      "max_gas": "-1"
    },
    "evidence": {
      "max_age_num_blocks": "100000",
      "max_age_duration": "172800000000000"
    },
    "validator": {
      "pub_key_types": ["ed25519"]
    }
  },
  "validators": [],
  "app_hash": ""
}
EOF

    log "Manual configuration created for Housefire testnet"
fi

# Step 4: Create systemd service (following the guide)
log "Step 4: Creating systemd service..."

sudo tee /etc/systemd/system/namadad.service > /dev/null << EOF
[Unit]
Description=namada
After=network-online.target

[Service]
User=namadaoperator
WorkingDirectory=$NAMADA_DATA_DIR
Environment=CHAIN_ID=$CHAIN_ID
Environment=NAMADA_CHAIN_ID=$CHAIN_ID
Environment=CMT_LOG_LEVEL=p2p:none,pex:error
Environment=NAMADA_CMT_STDOUT=true
ExecStart=$NAMADA_BIN node ledger run --base-dir $NAMADA_DATA_DIR
StandardOutput=syslog
StandardError=syslog
Restart=always
RestartSec=10
LimitNOFILE=65535

[Install]
WantedBy=multi-user.target
EOF

# Step 5: Create manual start script
log "Step 5: Creating manual start script..."

sudo tee /usr/local/bin/start-housefire-node-v2.sh > /dev/null << EOF
#!/bin/bash
# Start Housefire testnet node V2 (Based on Namada Node Mastery guide)

export CHAIN_ID="$CHAIN_ID"
export NAMADA_CHAIN_ID="$CHAIN_ID"
export CMT_LOG_LEVEL="p2p:none,pex:error"
export NAMADA_CMT_STDOUT="true"

echo "Starting Housefire testnet node V2..."
echo "Chain ID: \$CHAIN_ID"
echo "Data directory: $NAMADA_DATA_DIR"
echo ""

# Start node following the guide's approach
$NAMADA_BIN node ledger run --base-dir "$NAMADA_DATA_DIR"
EOF

sudo chmod +x /usr/local/bin/start-housefire-node-v2.sh

# Step 6: Create status and management scripts
log "Step 6: Creating management scripts..."

# Status script
sudo tee /usr/local/bin/check-housefire-node-v2.sh > /dev/null << EOF
#!/bin/bash
# Check Housefire testnet node status V2

export CHAIN_ID="$CHAIN_ID"
export NAMADA_CHAIN_ID="$CHAIN_ID"

echo "=== Housefire Testnet Node Status V2 ==="
echo "Chain ID: \$CHAIN_ID"
echo "Data directory: $NAMADA_DATA_DIR"
echo ""

# Check configuration files
echo "=== Configuration Files ==="
if [[ -f "$NAMADA_DATA_DIR/$CHAIN_ID/config.toml" ]]; then
    echo "✓ Config file: $NAMADA_DATA_DIR/$CHAIN_ID/config.toml"
else
    echo "✗ Config file missing"
fi

if [[ -f "$NAMADA_DATA_DIR/$CHAIN_ID/genesis.json" ]]; then
    echo "✓ Genesis file: $NAMADA_DATA_DIR/$CHAIN_ID/genesis.json"
else
    echo "✗ Genesis file missing"
fi

# Check systemd service
echo ""
echo "=== Systemd Service ==="
if systemctl is-active --quiet namadad; then
    echo "✓ Namada service is running"
elif systemctl is-enabled --quiet namadad; then
    echo "⚠ Namada service is enabled but not running"
else
    echo "✗ Namada service is not enabled"
fi

# Check if node process is running
echo ""
echo "=== Node Process ==="
if pgrep -f "namada node ledger run" > /dev/null; then
    echo "✓ Node process is running"
    
    # Try to get block info
    echo ""
    echo "Last committed block:"
    $NAMADA_BIN client block --base-dir "$NAMADA_DATA_DIR" 2>/dev/null || echo "Unable to get block info"
else
    echo "✗ Node process is not running"
fi

echo ""
echo "=== Management Commands ==="
echo "Start service:    sudo systemctl start namadad"
echo "Stop service:     sudo systemctl stop namadad"
echo "Restart service:  sudo systemctl restart namadad"
echo "View logs:        sudo journalctl -u namadad -f -o cat"
echo "Manual start:     sudo -u namadaoperator /usr/local/bin/start-housefire-node-v2.sh"
EOF

sudo chmod +x /usr/local/bin/check-housefire-node-v2.sh

# Management script
sudo tee /usr/local/bin/manage-housefire-node.sh > /dev/null << EOF
#!/bin/bash
# Manage Housefire testnet node V2

case "\$1" in
    start)
        echo "Starting Namada service..."
        sudo systemctl start namadad
        sudo systemctl status namadad --no-pager
        ;;
    stop)
        echo "Stopping Namada service..."
        sudo systemctl stop namadad
        ;;
    restart)
        echo "Restarting Namada service..."
        sudo systemctl restart namadad
        sudo systemctl status namadad --no-pager
        ;;
    status)
        /usr/local/bin/check-housefire-node-v2.sh
        ;;
    logs)
        echo "Showing Namada logs (Ctrl+C to exit)..."
        sudo journalctl -u namadad -f -o cat
        ;;
    enable)
        echo "Enabling Namada service..."
        sudo systemctl enable namadad
        ;;
    disable)
        echo "Disabling Namada service..."
        sudo systemctl disable namadad
        ;;
    *)
        echo "Usage: \$0 {start|stop|restart|status|logs|enable|disable}"
        echo ""
        echo "Commands:"
        echo "  start    - Start the Namada service"
        echo "  stop     - Stop the Namada service"
        echo "  restart  - Restart the Namada service"
        echo "  status   - Check node status"
        echo "  logs     - View service logs"
        echo "  enable   - Enable service to start on boot"
        echo "  disable  - Disable service from starting on boot"
        exit 1
        ;;
esac
EOF

sudo chmod +x /usr/local/bin/manage-housefire-node.sh

# Step 7: Enable the service
log "Step 7: Enabling systemd service..."
sudo systemctl daemon-reload
sudo systemctl enable namadad

# Step 8: Display summary
log "Housefire testnet node setup V2 completed!"
echo ""
echo -e "${GREEN}=== SETUP SUMMARY V2 ===${NC}"
echo "✓ Data directory structure created"
echo "✓ Configuration files created"
echo "✓ Genesis file created (placeholder)"
echo "✓ Systemd service created and enabled"
echo "✓ Management scripts created"
echo ""
echo -e "${BLUE}Configuration files:${NC}"
echo "  Config:  $NAMADA_DATA_DIR/$CHAIN_ID/config.toml"
echo "  Genesis: $NAMADA_DATA_DIR/$CHAIN_ID/genesis.json"
echo ""
echo -e "${BLUE}Management commands:${NC}"
echo "  manage-housefire-node.sh start    # Start the service"
echo "  manage-housefire-node.sh stop     # Stop the service"
echo "  manage-housefire-node.sh status   # Check status"
echo "  manage-housefire-node.sh logs     # View logs"
echo "  manage-housefire-node.sh restart  # Restart service"
echo ""
echo -e "${BLUE}Manual start:${NC}"
echo "  sudo -u namadaoperator /usr/local/bin/start-housefire-node-v2.sh"
echo ""
echo -e "${YELLOW}Next steps (following Namada Node Mastery guide):${NC}"
echo "1. Check Namada Discord for persistent peers"
echo "2. Update $NAMADA_DATA_DIR/$CHAIN_ID/config.toml with correct peers"
echo "3. Update $NAMADA_DATA_DIR/$CHAIN_ID/genesis.json with proper genesis data"
echo "4. Start the service: sudo systemctl start namadad"
echo "5. Monitor logs: sudo journalctl -u namadad -f -o cat"
echo ""
echo -e "${GREEN}Housefire testnet node setup V2 is ready!${NC}"
echo -e "${BLUE}Based on Namada Node Mastery guide: https://medium.com/@breizh-node/namada-node-mastery${NC}"
