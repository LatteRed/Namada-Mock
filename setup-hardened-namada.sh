#!/bin/bash

# Master Script: Hardened Ubuntu Setup for Namada Node
# Chains all hardening, build environment, and Namada installation scripts

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
NC='\033[0m' # No Color

# Logging functions
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

success() {
    echo -e "${GREEN}[$(date +'%Y-%m-%d %H:%M:%S')]  $1${NC}"
}

# Script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Check if running as root
if [[ $EUID -eq 0 ]]; then
    warn "Running as root. This is acceptable for initial setup on fresh systems."
    warn "The script will create the namadaoperator user and switch to it for security."
fi

# Check if sudo is available (install if missing)
if ! command -v sudo &> /dev/null; then
    if [[ $EUID -eq 0 ]]; then
        log "Installing sudo..."
        apt update && apt install -y sudo
    else
        error "sudo is required but not installed."
    fi
fi

# Check Ubuntu version
if ! grep -q "Ubuntu" /etc/os-release; then
    error "Designed for Ubuntu systems only."
fi

UBUNTU_VERSION=$(lsb_release -rs)
log "Detected Ubuntu version: $UBUNTU_VERSION"

# Display banner
echo -e "${PURPLE}"
echo "╔══════════════════════════════════════════════════════════════════════════════╗"
echo "║                    HARDENED UBUNTU SETUP FOR NAMADA NODE                    ║"
echo "║                                                                              ║"
echo "║  This script performs the following operations:                        ║"
echo "║  1. Harden Ubuntu system (HardenedBSD-style security)                       ║"
echo "║  2. Set up secure build environment for Rust compilation                    ║"
echo "║  3. Create namadaoperator user with admin privileges                        ║"
echo "║  4. Install and configure Namada node securely                             ║"
echo "║                                                                              ║"
echo "║  WARNING: This will make significant security changes to your system        ║"
echo "║  Make sure you have a backup and test this in a safe environment first      ║"
echo "╚══════════════════════════════════════════════════════════════════════════════╝"
echo -e "${NC}"

# Confirm before proceeding
echo -e "${YELLOW}This script:${NC}"
echo "  - Apply comprehensive system hardening (kernel, network, filesystem)"
echo "  - Set up secure build environment for Rust compilation"
echo "  - Create namadaoperator user with admin privileges"
echo "  - Install and configure Namada blockchain node"
echo "  - Configure monitoring and maintenance automation"
echo ""
echo -e "${YELLOW}Estimated time: 15-30 minutes depending on system speed${NC}"
echo ""
read -p "Do you want to continue? (y/N): " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    log "Aborted by user."
    exit 0
fi

# Check if required scripts exist
REQUIRED_SCRIPTS=(
    "harden-ubuntu.sh"
    "setup-build-env.sh"
    "setup-namadaoperator.sh"
    "install-namada.sh"
)

for script in "${REQUIRED_SCRIPTS[@]}"; do
    if [[ ! -f "$SCRIPT_DIR/$script" ]]; then
        error "Required script not found: $script"
    fi
    if [[ ! -x "$SCRIPT_DIR/$script" ]]; then
        log "Making $script executable..."
        chmod +x "$SCRIPT_DIR/$script"
    fi
done

# Create log directory
LOG_DIR="/var/log/hardened-namada-setup"
mkdir -p "$LOG_DIR"
chmod 755 "$LOG_DIR"

# Function to run script with logging
run_script() {
    local script_name="$1"
    local script_path="$SCRIPT_DIR/$script_name"
    local log_file="$LOG_DIR/${script_name%.sh}.log"
    
    log "Starting $script_name..."
    info "Log file: $log_file"
    
    if bash "$script_path" 2>&1 | tee "$log_file"; then
        success "$script_name completed successfully"
        return 0
    else
        error "$script_name failed. Check log: $log_file"
        return 1
    fi
}

# Function to check system status
check_system_status() {
    log "Checking system status..."
    
    # Check if namada user exists
    if id "namada" &>/dev/null; then
        success "Namada user exists"
    else
        warn "Namada user does not exist yet"
    fi
    
    # Check if hardening was applied
    if [[ -f "/etc/sysctl.d/99-hardened.conf" ]]; then
        success "Kernel hardening configuration found"
    else
        warn "Kernel hardening not yet applied"
    fi
    
    # Check if build environment exists
    if [[ -d "/build" ]]; then
        success "Build environment directory exists"
    else
        warn "Build environment not yet set up"
    fi
    
    # Check if Namada is installed
    if [[ -f "/opt/namada/bin/namada" ]]; then
        success "Namada binary found"
    else
        warn "Namada not yet installed"
    fi
}

# Function to display progress
show_progress() {
    local step="$1"
    local total="$2"
    local description="$3"
    
    echo -e "${BLUE}[$step/$total] $description${NC}"
    echo "────────────────────────────────────────────────────────────────────────────"
}

# Main execution
main() {
    local start_time=$(date +%s)
    
    log "Starting hardened Namada setup process..."
    check_system_status
    
    # If running as root, create namadaoperator user first and switch to it
    if [[ $EUID -eq 0 ]]; then
        echo ""
        show_progress "0" "4" "STEP 0: CREATING NAMADAOPERATOR USER"
        echo ""
        
        # Step 0: Create namadaoperator user first
        if run_script "setup-namadaoperator.sh"; then
            success "Namadaoperator user created"
            echo ""
            echo -e "${RED}🔐 IMPORTANT: SAVE THE NAMADAOPERATOR PASSWORD ABOVE! 🔐${NC}"
            echo -e "${RED}You will need this password for reboots and system access!${NC}"
            echo ""
            log "Switching to namadaoperator user for secure setup..."
            echo ""
            echo -e "${YELLOW}The setup will now continue as the namadaoperator user.${NC}"
            echo -e "${YELLOW}This ensures proper security and permissions.${NC}"
            echo ""
            read -p "Press Enter to continue as namadaoperator user..."
            
            # Copy scripts to accessible location and continue
            log "Copying setup scripts to accessible location..."
            SETUP_DIR="/home/namadaoperator/namada-setup"
            cp -r "$SCRIPT_DIR" "$SETUP_DIR"
            chown -R namadaoperator:namadaoperator "$SETUP_DIR"
            chmod +x "$SETUP_DIR"/*.sh
            
            # Give namadaoperator access to log directory
            log "Setting up log directory access..."
            chown -R namadaoperator:namadaoperator "$LOG_DIR"
            chmod 755 "$LOG_DIR"
            
            # Also ensure namadaoperator can create new log files
            chmod 777 "$LOG_DIR"
            
            # Switch to namadaoperator user and continue
            exec su - namadaoperator -c "cd '$SETUP_DIR' && ./setup-hardened-namada.sh"
        else
            error "Namadaoperator user creation failed. Aborting."
        fi
    fi
    
    echo ""
        show_progress "1" "3" "STEP 1: HARDENING UBUNTU SYSTEM"
    echo ""
    
    # Step 1: Harden Ubuntu system
    if run_script "harden-ubuntu.sh"; then
        success "System hardening completed"
    else
        error "System hardening failed. Aborting."
    fi
    
    echo ""
    show_progress "2" "3" "STEP 2: SETTING UP SECURE BUILD ENVIRONMENT"
    echo ""
    
    # Step 2: Set up build environment
    if run_script "setup-build-env.sh"; then
        success "Build environment setup completed"
    else
        error "Build environment setup failed. Aborting."
    fi
    
    echo ""
    show_progress "3" "3" "STEP 3: INSTALLING NAMADA NODE"
    echo ""
    
    # Step 3: Install Namada
    if run_script "install-namada.sh"; then
        success "Namada installation completed"
    else
        error "Namada installation failed. Aborting."
    fi
    
    # Final system check
    echo ""
    log "Performing final system verification..."
    check_system_status
    
    # Calculate execution time
    local end_time=$(date +%s)
    local execution_time=$((end_time - start_time))
    local minutes=$((execution_time / 60))
    local seconds=$((execution_time % 60))
    
    # Final summary
    echo ""
    echo -e "${GREEN}╔══════════════════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║                            SETUP COMPLETED SUCCESSFULLY!                    ║${NC}"
    echo -e "${GREEN}╚══════════════════════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    echo -e "${GREEN}System hardening complete${NC}"
    echo -e "${GREEN}Build environment configured${NC}"
    echo -e "${GREEN}Namadaoperator user created${NC}"
    echo -e "${GREEN}Namada node installed${NC}"
    echo -e "${GREEN}Monitoring configured${NC}"
    echo ""
    echo -e "${BLUE}Execution time: ${minutes}m ${seconds}s${NC}"
    echo -e "${BLUE}Log files: $LOG_DIR${NC}"
    echo ""
    echo -e "${YELLOW}Available management commands:${NC}"
    echo "  /usr/local/bin/security-check.sh      # Check system security"
    echo "  /usr/local/bin/namada-manage.sh       # Manage Namada node"
    echo "  /usr/local/bin/monitor-build-env.sh   # Monitor build environment"
    echo "  /usr/local/bin/namada-monitor.sh       # Monitor Namada node"
    echo ""
    echo -e "${YELLOW}Next steps:${NC}"
    echo "1. Configure your node to join the network"
    echo "2. Set up monitoring and alerting"
    echo "3. Configure backup procedures"
    echo "4. Review firewall rules and adjust if needed"
    echo ""
    echo -e "${GREEN}Hardened Namada node setup complete.${NC}"
    echo ""
    
    # Display service status
    echo -e "${BLUE}Current service status:${NC}"
    if systemctl is-active namada &> /dev/null; then
        echo -e "${GREEN}  Namada service: Running${NC}"
    else
        echo -e "${YELLOW}  Namada service: Not running${NC}"
    fi
    
    if systemctl is-active fail2ban &> /dev/null; then
        echo -e "${GREEN}  Fail2ban: Running${NC}"
    else
        echo -e "${YELLOW}  Fail2ban: Not running${NC}"
    fi
    
    if systemctl is-active ufw &> /dev/null; then
        echo -e "${GREEN}  Firewall: Active${NC}"
    else
        echo -e "${YELLOW}  Firewall: Not active${NC}"
    fi
    
    echo ""
    echo -e "${PURPLE}To check detailed status, run: /usr/local/bin/security-check.sh${NC}"
}

# Error handling
trap 'error "Script interrupted. Check logs in $LOG_DIR for details."' INT TERM

# Run main function
main "$@"
