#!/bin/bash

# Namada Operator User Setup Script
# Creates and configures the namadaoperator user with proper permissions

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

success() {
    echo -e "${GREEN}[$(date +'%Y-%m-%d %H:%M:%S')] SUCCESS: $1${NC}"
}

# Check if running as root
if [[ $EUID -eq 0 ]]; then
    warn "Running as root. This is acceptable for initial setup on fresh systems."
    warn "The script will create the namadaoperator user with proper permissions."
fi

log "Setting up namadaoperator user with admin privileges..."

# 1. Create namadaoperator user
log "Step 1: Creating namadaoperator user"
if ! id "namadaoperator" &>/dev/null; then
    sudo useradd -m -s /bin/bash namadaoperator
    sudo usermod -aG sudo namadaoperator
    log "Created namadaoperator user with sudo privileges"
else
    log "Namadaoperator user already exists"
fi

# 2. Set up SSH access
log "Step 2: Configuring SSH access for namadaoperator"

# Create SSH directory
sudo mkdir -p /home/namadaoperator/.ssh
sudo chmod 700 /home/namadaoperator/.ssh
sudo chown namadaoperator:namadaoperator /home/namadaoperator/.ssh

# Copy SSH keys from current user if they exist
if [[ -f "/home/$USER/.ssh/authorized_keys" ]]; then
    sudo cp /home/$USER/.ssh/authorized_keys /home/namadaoperator/.ssh/
    sudo chown namadaoperator:namadaoperator /home/namadaoperator/.ssh/authorized_keys
    sudo chmod 600 /home/namadaoperator/.ssh/authorized_keys
    log "Copied SSH keys to namadaoperator user"
else
    warn "No SSH keys found for current user. You'll need to set up SSH keys for namadaoperator manually."
fi

# 3. Set up secure password
log "Step 3: Setting up secure password"
TEMP_PASSWORD=$(openssl rand -base64 32 | tr -d "=+/" | cut -c1-32)
echo "namadaoperator:$TEMP_PASSWORD" | chpasswd
log "Set secure password for namadaoperator"

# 4. Configure sudo access
log "Step 4: Configuring sudo access"
sudo tee /etc/sudoers.d/99-namadaoperator > /dev/null << 'EOF'
# Namada operator user sudo configuration
# General sudo access for setup and management
namadaoperator ALL=(ALL) NOPASSWD: ALL
# Specific commands for security
namadaoperator ALL=(ALL) NOPASSWD: /usr/local/bin/namada-manage.sh
namadaoperator ALL=(ALL) NOPASSWD: /usr/local/bin/security-check.sh
namadaoperator ALL=(ALL) NOPASSWD: /usr/local/bin/namada-monitor.sh
namadaoperator ALL=(ALL) NOPASSWD: /usr/local/bin/monitor-build-env.sh
namadaoperator ALL=(ALL) NOPASSWD: /usr/local/bin/clean-build-env.sh
namadaoperator ALL=(ALL) NOPASSWD: /usr/local/bin/isolated-build.sh
namadaoperator ALL=(ALL) NOPASSWD: /usr/local/bin/install-rust-secure.sh
namadaoperator ALL=(ALL) NOPASSWD: /bin/systemctl start namada
namadaoperator ALL=(ALL) NOPASSWD: /bin/systemctl stop namada
namadaoperator ALL=(ALL) NOPASSWD: /bin/systemctl restart namada
namadaoperator ALL=(ALL) NOPASSWD: /bin/systemctl status namada
namadaoperator ALL=(ALL) NOPASSWD: /bin/systemctl enable namada
namadaoperator ALL=(ALL) NOPASSWD: /bin/systemctl disable namada
namadaoperator ALL=(ALL) NOPASSWD: /bin/journalctl -u namada
namadaoperator ALL=(ALL) NOPASSWD: /bin/journalctl -u namada -f
namadaoperator ALL=(ALL) NOPASSWD: /bin/journalctl -u namada -n
EOF

sudo chmod 440 /etc/sudoers.d/99-namadaoperator
log "Configured sudo access for namadaoperator"

# 5. Set up environment for namadaoperator
log "Step 5: Setting up environment for namadaoperator"
sudo -u namadaoperator bash -c 'cat >> /home/namadaoperator/.bashrc << "EOF"

# Namada operator environment
export NAMADA_HOME=/opt/namada
export NAMADA_BIN=/opt/namada/bin
export NAMADA_DATA=/opt/namada/data
export NAMADA_CONFIG=/opt/namada/config

# Build environment
export CARGO_TARGET_DIR=/build/target
export CARGO_HOME=/build/cargo
export RUSTUP_HOME=/build/rustup
export TMPDIR=/build/tmp
export PATH="/build/cargo/bin:$PATH"

# Aliases for common operations
alias namada-status="sudo systemctl status namada"
alias namada-logs="sudo journalctl -u namada -f"
alias namada-start="sudo systemctl start namada"
alias namada-stop="sudo systemctl stop namada"
alias namada-restart="sudo systemctl restart namada"
alias security-check="/usr/local/bin/security-check.sh"
alias namada-monitor="/usr/local/bin/namada-monitor.sh"
alias build-monitor="/usr/local/bin/monitor-build-env.sh"

# Color prompt
export PS1="\[\033[01;32m\]\u@\h\[\033[00m\]:\[\033[01;34m\]\w\[\033[00m\]\$ "
EOF'

# 6. Create management scripts for namadaoperator
log "Step 6: Creating management scripts for namadaoperator"

# Create namada operator management script
sudo tee /usr/local/bin/namada-operator.sh > /dev/null << 'EOF'
#!/bin/bash
# Namada operator management script

case "$1" in
    status)
        echo "=== Namada Node Status ==="
        sudo systemctl status namada --no-pager
        ;;
    logs)
        echo "=== Namada Node Logs ==="
        sudo journalctl -u namada -n 50 --no-pager
        ;;
    follow)
        echo "=== Following Namada Logs (Ctrl+C to exit) ==="
        sudo journalctl -u namada -f
        ;;
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
    enable)
        echo "Enabling Namada node..."
        sudo systemctl enable namada
        ;;
    disable)
        echo "Disabling Namada node..."
        sudo systemctl disable namada
        ;;
    security)
        echo "=== Security Status ==="
        /usr/local/bin/security-check.sh
        ;;
    monitor)
        echo "=== Namada Monitoring ==="
        /usr/local/bin/namada-monitor.sh
        ;;
    build)
        echo "=== Build Environment ==="
        /usr/local/bin/monitor-build-env.sh
        ;;
    backup)
        echo "=== Creating Backup ==="
        /usr/local/bin/namada-manage.sh backup
        ;;
    update)
        echo "=== Updating Namada ==="
        /usr/local/bin/namada-manage.sh update
        ;;
    *)
        echo "Namada Operator Management"
        echo "Usage: $0 {status|logs|follow|start|stop|restart|enable|disable|security|monitor|build|backup|update}"
        echo ""
        echo "Commands:"
        echo "  status    - Show Namada service status"
        echo "  logs      - Show recent Namada logs"
        echo "  follow    - Follow Namada logs in real-time"
        echo "  start     - Start Namada service"
        echo "  stop      - Stop Namada service"
        echo "  restart   - Restart Namada service"
        echo "  enable    - Enable Namada service on boot"
        echo "  disable   - Disable Namada service on boot"
        echo "  security  - Check system security status"
        echo "  monitor   - Monitor Namada node health"
        echo "  build     - Monitor build environment"
        echo "  backup    - Create Namada data backup"
        echo "  update    - Update Namada node"
        exit 1
        ;;
esac
EOF

sudo chmod +x /usr/local/bin/namada-operator.sh
sudo chown namadaoperator:namadaoperator /usr/local/bin/namada-operator.sh

# 7. Set up directory permissions
log "Step 7: Setting up directory permissions"
sudo chown -R namadaoperator:namadaoperator /home/namadaoperator
sudo chmod 755 /home/namadaoperator

# 8. Create welcome message
log "Step 8: Creating welcome message"
sudo tee /home/namadaoperator/welcome.txt > /dev/null << 'EOF'
Welcome to the Namada Operator Account!

This account has been set up with the following privileges:
- Sudo access for Namada management operations
- SSH access (if keys were configured)
- Pre-configured environment variables
- Management aliases and scripts

Available commands:
- namada-operator.sh status    # Check Namada status
- namada-operator.sh logs     # View Namada logs
- namada-operator.sh security  # Check security status
- namada-operator.sh monitor   # Monitor node health

Quick aliases:
- namada-status, namada-logs, namada-start, namada-stop, namada-restart
- security-check, namada-monitor, build-monitor

IMPORTANT SECURITY NOTES:
1. Change your password immediately: passwd
2. Set up SSH keys if not already done
3. Review sudo permissions in /etc/sudoers.d/99-namadaoperator
4. Never use root account for daily operations

For more information, see the hardening guide and README.
EOF

sudo chown namadaoperator:namadaoperator /home/namadaoperator/welcome.txt

# 9. Final verification
log "Step 9: Performing final verification"

# Check if user exists and has sudo access
if id "namadaoperator" &>/dev/null; then
    success "Namadaoperator user exists"
else
    error "Namadaoperator user creation failed"
fi

# Check sudo access
if sudo -u namadaoperator sudo -l &>/dev/null; then
    success "Namadaoperator has sudo access"
else
    warn "Namadaoperator sudo access verification failed"
fi

# Check SSH directory
if [[ -d "/home/namadaoperator/.ssh" ]]; then
    success "SSH directory created"
else
    warn "SSH directory not found"
fi

# Final summary
log "Namadaoperator user setup completed!"
echo ""
echo -e "${GREEN}=== NAMADAOPERATOR SETUP SUMMARY ===${NC}"
echo " Namadaoperator user created with sudo privileges"
echo " SSH access configured"
echo " Management scripts created"
echo " Environment variables set up"
echo " Welcome message created"
echo ""
echo -e "${BLUE}User details:${NC}"
echo "  Username: namadaoperator"
echo "  Home directory: /home/namadaoperator"
echo "  Shell: /bin/bash"
echo "  Groups: namadaoperator, sudo"
echo ""
echo -e "${RED}🔐 CRITICAL: SAVE THIS PASSWORD NOW! 🔐${NC}"
echo -e "${RED}Password for namadaoperator: $TEMP_PASSWORD${NC}"
echo -e "${RED}This password is needed for reboots and system access!${NC}"
echo ""
echo -e "${YELLOW}Next steps:${NC}"
echo "1. Log in as namadaoperator: su - namadaoperator"
echo "2. Change password: passwd"
echo "3. Set up SSH keys if needed"
echo "4. Test management commands: namada-operator.sh status"
echo ""
echo -e "${YELLOW}Important:${NC}"
echo "- Change the temporary password immediately"
echo "- Review and test sudo permissions"
echo "- Set up SSH keys for remote access"
echo "- Use namadaoperator instead of root for daily operations"
echo ""
echo -e "${GREEN}Namadaoperator user setup complete.${NC}"
