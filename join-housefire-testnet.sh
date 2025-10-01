#!/bin/bash

# Join Housefire Testnet Script
# Standalone script to join the Housefire testnet

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
BASE_DIR="/opt/namada/data"

log "Starting Housefire testnet join process..."

# Check if running as root
if [[ $EUID -eq 0 ]]; then
    warn "Running as root. This is acceptable for initial setup."
fi

# Check if Namada is installed
if [[ -f "/opt/namada/bin/namada" ]]; then
    NAMADA_BIN="/opt/namada/bin/namada"
elif command -v namada &> /dev/null; then
    NAMADA_BIN="namada"
else
    error "Namada is not installed. Please install Namada first."
fi

log "Namada version: $($NAMADA_BIN --version)"

# Check if CometBFT is installed
if ! command -v cometbft &> /dev/null; then
    error "CometBFT is not installed. Please install CometBFT v0.37.15 first."
fi

log "CometBFT version: $(cometbft version)"

# Check if namadaoperator user exists
if ! id "namadaoperator" &>/dev/null; then
    error "Namadaoperator user does not exist. Please run the setup scripts first."
fi

# Create base directory if it doesn't exist
log "Setting up base directory..."
sudo mkdir -p "$BASE_DIR"
sudo chown namadaoperator:namadaoperator "$BASE_DIR"
sudo chmod 755 "$BASE_DIR"

# Export chain ID
export CHAIN_ID="$CHAIN_ID"

# Join the Housefire testnet
log "Joining Housefire testnet (Chain ID: $CHAIN_ID)..."
log "This will download genesis files and initialize the node..."

sudo -u namadaoperator $NAMADA_BIN client utils join-network \
    --chain-id "$CHAIN_ID" \
    --add-persistent-peers \
    --base-dir "$BASE_DIR"

if [[ $? -eq 0 ]]; then
    log "Successfully joined Housefire testnet!"
else
    error "Failed to join Housefire testnet"
fi

# Verify the join was successful
log "Verifying network configuration..."
if [[ -f "$BASE_DIR/config.toml" ]]; then
    log "✓ Config file created: $BASE_DIR/config.toml"
else
    warn "Config file not found at $BASE_DIR/config.toml"
fi

if [[ -f "$BASE_DIR/genesis.json" ]]; then
    log "✓ Genesis file created: $BASE_DIR/genesis.json"
else
    warn "Genesis file not found at $BASE_DIR/genesis.json"
fi

# Check persistent peers
if grep -q "persistent_peers" "$BASE_DIR/config.toml" 2>/dev/null; then
    log "✓ Persistent peers configured"
    log "Persistent peers:"
    grep "persistent_peers" "$BASE_DIR/config.toml" | head -3
else
    warn "Persistent peers not found in config"
fi

# Create a test script to start the node
log "Creating node start script..."
sudo tee /usr/local/bin/start-housefire-node.sh > /dev/null << 'EOF'
#!/bin/bash
# Start Housefire testnet node

export CHAIN_ID="housefire-alpaca.cc0d3e0c033be"
export CMT_LOG_LEVEL="p2p:none,pex:error"
export NAMADA_LOG="info"
export NAMADA_CMT_STDOUT="true"

echo "Starting Housefire testnet node..."
echo "Chain ID: $CHAIN_ID"
echo "Base directory: /opt/namada/data"
echo ""
echo "To stop the node, press Ctrl+C"
echo "To run in background, add '&' at the end"
echo ""

/opt/namada/bin/namada node ledger run --base-dir /opt/namada/data
EOF

sudo chmod +x /usr/local/bin/start-housefire-node.sh

# Create a status check script
log "Creating node status script..."
sudo tee /usr/local/bin/check-housefire-node.sh > /dev/null << 'EOF'
#!/bin/bash
# Check Housefire testnet node status

export CHAIN_ID="housefire-alpaca.cc0d3e0c033be"

echo "=== Housefire Testnet Node Status ==="
echo "Chain ID: $CHAIN_ID"
echo "Base directory: /opt/namada/data"
echo ""

# Check if node is running
if pgrep -f "namada node ledger run" > /dev/null; then
    echo "✓ Node is running"
    
    # Get last block
    echo ""
    echo "Last committed block:"
    /opt/namada/bin/namada client block --base-dir /opt/namada/data 2>/dev/null || echo "Unable to get block info"
else
    echo "✗ Node is not running"
fi

echo ""
echo "=== Network Information ==="
echo "Chain ID: $CHAIN_ID"
echo "Genesis file: /opt/namada/data/genesis.json"
echo "Config file: /opt/namada/data/config.toml"
EOF

sudo chmod +x /usr/local/bin/check-housefire-node.sh

# Display summary
log "Housefire testnet join completed!"
echo ""
echo -e "${GREEN}=== JOIN SUMMARY ===${NC}"
echo "✓ Joined Housefire testnet"
echo "✓ Chain ID: $CHAIN_ID"
echo "✓ Base directory: $BASE_DIR"
echo "✓ Genesis files downloaded"
echo "✓ Persistent peers configured"
echo ""
echo -e "${BLUE}Available commands:${NC}"
echo "  start-housefire-node.sh    # Start the node manually"
echo "  check-housefire-node.sh    # Check node status"
echo "  namada client block        # Check last block"
echo ""
echo -e "${BLUE}To start the node:${NC}"
echo "  sudo -u namadaoperator /usr/local/bin/start-housefire-node.sh"
echo ""
echo -e "${BLUE}Or start with systemd (if configured):${NC}"
echo "  sudo systemctl start namada"
echo "  sudo systemctl status namada"
echo ""
echo -e "${YELLOW}Next steps:${NC}"
echo "1. Start the node to begin syncing"
echo "2. Monitor logs for sync progress"
echo "3. Check Discord for updated peer lists if needed"
echo ""
echo -e "${GREEN}Housefire testnet node is ready!${NC}"
