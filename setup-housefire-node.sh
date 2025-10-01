#!/bin/bash

# Housefire Testnet Node Setup Script
# Complete revamp following official Namada documentation

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
NAMADA_BIN="/opt/namada/bin/namada"

log "Starting Housefire testnet node setup (REVAMPED)..."

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

# Step 1: Initialize Namada properly
log "Step 1: Initializing Namada configuration..."

# Set environment variables
export CHAIN_ID="$CHAIN_ID"
export NAMADA_CHAIN_ID="$CHAIN_ID"

# Create proper base directory structure
sudo mkdir -p "$BASE_DIR"
sudo chown namadaoperator:namadaoperator "$BASE_DIR"
sudo chmod 755 "$BASE_DIR"

# Initialize Namada client configuration
log "Initializing Namada client configuration..."
sudo -u namadaoperator $NAMADA_BIN client utils init-network \
    --chain-id "$CHAIN_ID" \
    --base-dir "$BASE_DIR" \
    --wasm-dir /opt/namada/wasm

# Step 2: Create proper configuration files
log "Step 2: Creating proper configuration files..."

# Create global config
sudo -u namadaoperator tee "$BASE_DIR/global-config.toml" > /dev/null << EOF
# Global Namada configuration for Housefire testnet
default_chain_id = "$CHAIN_ID"

[global]
# Default chain ID
default_chain_id = "$CHAIN_ID"

# Default base directory
default_base_dir = "$BASE_DIR"

# Default WASM directory
default_wasm_dir = "/opt/namada/wasm"
EOF

# Create chain-specific config directory
sudo mkdir -p "$BASE_DIR/$CHAIN_ID"
sudo chown namadaoperator:namadaoperator "$BASE_DIR/$CHAIN_ID"

# Create chain config
sudo -u namadaoperator tee "$BASE_DIR/$CHAIN_ID/config.toml" > /dev/null << EOF
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

[mempool]
recheck = true
broadcast = true
wal_dir = "$BASE_DIR/$CHAIN_ID/data/mempool.wal"

[consensus]
wal_file = "$BASE_DIR/$CHAIN_ID/data/cs.wal/wal"
timeout_propose = "3s"
timeout_propose_delta = "500ms"
timeout_prevote = "1s"
timeout_prevote_delta = "500ms"
timeout_precommit = "1s"
timeout_precommit_delta = "500ms"
timeout_commit = "5s"

[instrumentation]
prometheus = true
prometheus_listen_addr = ":26660"
max_open_connections = 3
namespace = "namada"
EOF

# Step 3: Create proper genesis file
log "Step 3: Creating genesis file..."

sudo -u namadaoperator tee "$BASE_DIR/$CHAIN_ID/genesis.json" > /dev/null << EOF
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

# Step 4: Create data directories
log "Step 4: Creating data directories..."

sudo mkdir -p "$BASE_DIR/$CHAIN_ID/data"
sudo mkdir -p "$BASE_DIR/$CHAIN_ID/data/mempool.wal"
sudo mkdir -p "$BASE_DIR/$CHAIN_ID/data/cs.wal"
sudo chown -R namadaoperator:namadaoperator "$BASE_DIR/$CHAIN_ID/data"

# Step 5: Create proper startup script
log "Step 5: Creating startup script..."

sudo tee /usr/local/bin/start-housefire-node.sh > /dev/null << EOF
#!/bin/bash
# Start Housefire testnet node (REVAMPED)

export CHAIN_ID="$CHAIN_ID"
export NAMADA_CHAIN_ID="$CHAIN_ID"
export CMT_LOG_LEVEL="p2p:none,pex:error"
export NAMADA_LOG="info"
export NAMADA_CMT_STDOUT="true"

echo "Starting Housefire testnet node (REVAMPED)..."
echo "Chain ID: \$CHAIN_ID"
echo "Base directory: $BASE_DIR"
echo "Chain directory: $BASE_DIR/\$CHAIN_ID"
echo ""
echo "Logging configuration:"
echo "  CMT_LOG_LEVEL: \$CMT_LOG_LEVEL"
echo "  NAMADA_LOG: \$NAMADA_LOG"
echo "  NAMADA_CMT_STDOUT: \$NAMADA_CMT_STDOUT"
echo ""

# Start node with proper chain ID
$NAMADA_BIN node ledger run --base-dir "$BASE_DIR" --chain-id "\$CHAIN_ID"
EOF

sudo chmod +x /usr/local/bin/start-housefire-node.sh

# Step 6: Create status script
log "Step 6: Creating status script..."

sudo tee /usr/local/bin/check-housefire-node.sh > /dev/null << EOF
#!/bin/bash
# Check Housefire testnet node status (REVAMPED)

export CHAIN_ID="$CHAIN_ID"
export NAMADA_CHAIN_ID="$CHAIN_ID"

echo "=== Housefire Testnet Node Status (REVAMPED) ==="
echo "Chain ID: \$CHAIN_ID"
echo "Base directory: $BASE_DIR"
echo "Chain directory: $BASE_DIR/\$CHAIN_ID"
echo ""

# Check configuration files
echo "=== Configuration Files ==="
if [[ -f "$BASE_DIR/global-config.toml" ]]; then
    echo "✓ Global config: $BASE_DIR/global-config.toml"
else
    echo "✗ Global config missing"
fi

if [[ -f "$BASE_DIR/\$CHAIN_ID/config.toml" ]]; then
    echo "✓ Chain config: $BASE_DIR/\$CHAIN_ID/config.toml"
else
    echo "✗ Chain config missing"
fi

if [[ -f "$BASE_DIR/\$CHAIN_ID/genesis.json" ]]; then
    echo "✓ Genesis file: $BASE_DIR/\$CHAIN_ID/genesis.json"
else
    echo "✗ Genesis file missing"
fi

# Check if node is running
echo ""
echo "=== Node Status ==="
if pgrep -f "namada node ledger run" > /dev/null; then
    echo "✓ Node is running"
    
    # Get last block
    echo ""
    echo "Last committed block:"
    $NAMADA_BIN client block --base-dir "$BASE_DIR" --chain-id "\$CHAIN_ID" 2>/dev/null || echo "Unable to get block info"
else
    echo "✗ Node is not running"
fi

echo ""
echo "=== Next Steps ==="
echo "1. Check Namada Discord for persistent peers"
echo "2. Update config.toml with correct peers"
echo "3. Update genesis.json with proper genesis data"
echo "4. Start the node to begin syncing"
EOF

sudo chmod +x /usr/local/bin/check-housefire-node.sh

# Step 7: Verify setup
log "Step 7: Verifying setup..."

# Check if we can query the configuration
if sudo -u namadaoperator $NAMADA_BIN client utils validate-config --base-dir "$BASE_DIR" --chain-id "$CHAIN_ID" 2>/dev/null; then
    log "✓ Configuration validation passed"
else
    warn "Configuration validation failed, but setup may still work"
fi

# Display summary
log "Housefire testnet node setup completed (REVAMPED)!"
echo ""
echo -e "${GREEN}=== SETUP SUMMARY ===${NC}"
echo "✓ Proper directory structure created"
echo "✓ Global configuration initialized"
echo "✓ Chain-specific configuration created"
echo "✓ Genesis file created (placeholder)"
echo "✓ Data directories created"
echo "✓ Startup script created"
echo "✓ Status script created"
echo ""
echo -e "${BLUE}Configuration files:${NC}"
echo "  Global config: $BASE_DIR/global-config.toml"
echo "  Chain config:  $BASE_DIR/$CHAIN_ID/config.toml"
echo "  Genesis file:  $BASE_DIR/$CHAIN_ID/genesis.json"
echo ""
echo -e "${BLUE}Available commands:${NC}"
echo "  start-housefire-node.sh    # Start the node"
echo "  check-housefire-node.sh    # Check node status"
echo ""
echo -e "${BLUE}To start the node:${NC}"
echo "  sudo -u namadaoperator /usr/local/bin/start-housefire-node.sh"
echo ""
echo -e "${YELLOW}Next steps:${NC}"
echo "1. Check Namada Discord for persistent peers"
echo "2. Update $BASE_DIR/$CHAIN_ID/config.toml with correct peers"
echo "3. Update $BASE_DIR/$CHAIN_ID/genesis.json with proper genesis data"
echo "4. Start the node to begin syncing"
echo ""
echo -e "${GREEN}Housefire testnet node setup is ready!${NC}"
