# Hardened Ubuntu Setup for Namada Node
## HardenedBSD-Style Security Implementation

This guide provides comprehensive hardening for Ubuntu systems running Namada blockchain nodes, implementing security principles similar to HardenedBSD.

## Table of Contents
1. [System Requirements](#system-requirements)
2. [Initial System Setup](#initial-system-setup)
3. [Kernel Hardening](#kernel-hardening)
4. [Memory Protection](#memory-protection)
5. [Network Security](#network-security)
6. [Filesystem Security](#filesystem-security)
7. [Service Hardening](#service-hardening)
8. [Namada Node Security](#namada-node-security)
9. [Monitoring and Logging](#monitoring-and-logging)
10. [Automation Scripts](#automation-scripts)

## System Requirements

### Minimum Hardware
- **CPU**: 4+ cores (8+ recommended)
- **RAM**: 8GB minimum (16GB+ recommended)
- **Storage**: 100GB+ SSD (500GB+ recommended)
- **Network**: Stable internet connection with static IP

### Ubuntu Version
- **Recommended**: Ubuntu 22.04 LTS or Ubuntu 24.04 LTS
- **Kernel**: Latest LTS kernel with security patches

## Initial System Setup

### 1. Fresh Ubuntu Installation
```bash
# Download Ubuntu Server LTS (minimal installation)
# During installation:
# - Use full disk encryption (LUKS)
# - Enable secure boot
# - Disable unnecessary services
# - Set strong root password
```

### 2. Initial Security Updates
```bash
sudo apt update && sudo apt upgrade -y
sudo apt install -y unattended-upgrades
sudo dpkg-reconfigure -plow unattended-upgrades
```

### 3. Create Dedicated User
```bash
# Create namada user with restricted shell
sudo useradd -m -s /bin/bash namada
sudo usermod -aG sudo namada
sudo passwd namada
```

## Kernel Hardening

### 1. Enable Kernel Security Features
Create `/etc/sysctl.d/99-hardened.conf`:

```bash
# ASLR (Address Space Layout Randomization)
kernel.randomize_va_space = 2

# Memory protection
kernel.kptr_restrict = 2
kernel.dmesg_restrict = 1
kernel.perf_event_paranoid = 3

# Network security
net.ipv4.conf.all.send_redirects = 0
net.ipv4.conf.default.send_redirects = 0
net.ipv4.conf.all.accept_redirects = 0
net.ipv4.conf.default.accept_redirects = 0
net.ipv4.conf.all.accept_source_route = 0
net.ipv4.conf.default.accept_source_route = 0
net.ipv4.conf.all.log_martians = 1
net.ipv4.conf.default.log_martians = 1
net.ipv4.icmp_echo_ignore_broadcasts = 1
net.ipv4.icmp_ignore_bogus_error_responses = 1
net.ipv4.tcp_syncookies = 1
net.ipv6.conf.all.accept_redirects = 0
net.ipv6.conf.default.accept_redirects = 0

# Process restrictions
kernel.yama.ptrace_scope = 1
fs.protected_hardlinks = 1
fs.protected_symlinks = 1
fs.suid_dumpable = 0

# Disable core dumps
kernel.core_pattern = |/bin/false
```

### 2. Apply Kernel Parameters
```bash
sudo sysctl -p /etc/sysctl.d/99-hardened.conf
sudo sysctl --system
```

## Memory Protection

### 1. Enable PIE and Stack Protection
Create `/etc/ld.so.conf.d/99-hardened.conf`:
```
# Force PIE compilation
/usr/lib/x86_64-linux-gnu/libc.so.6
```

### 2. Compiler Hardening
```bash
# Install hardened toolchain
sudo apt install -y gcc-12 g++-12 make cmake

# Set hardening flags
export CFLAGS="-fstack-protector-strong -fPIE -D_FORTIFY_SOURCE=2"
export CXXFLAGS="-fstack-protector-strong -fPIE -D_FORTIFY_SOURCE=2"
export LDFLAGS="-Wl,-z,relro -Wl,-z,now -Wl,-z,noexecstack"
```

### 3. Enable ASLR and NX
```bash
# Verify ASLR is enabled
cat /proc/sys/kernel/randomize_va_space

# Check NX bit support
grep -i nx /proc/cpuinfo
```

## Network Security

### 1. Firewall Configuration (UFW)
```bash
# Install and configure UFW
sudo apt install -y ufw

# Default policies
sudo ufw default deny incoming
sudo ufw default allow outgoing

# Allow SSH (change port if needed)
sudo ufw allow 22/tcp

# Allow Namada ports (adjust as needed)
sudo ufw allow 26656/tcp  # P2P port
sudo ufw allow 26657/tcp  # RPC port (restrict to localhost)

# Enable firewall
sudo ufw enable
```

### 2. Advanced Firewall (iptables)
Create `/etc/iptables/rules.v4`:
```bash
# Clear existing rules
*filter
:INPUT DROP [0:0]
:FORWARD DROP [0:0]
:OUTPUT ACCEPT [0:0]

# Allow loopback
-A INPUT -i lo -j ACCEPT

# Allow established connections
-A INPUT -m state --state ESTABLISHED,RELATED -j ACCEPT

# Allow SSH (change port if needed)
-A INPUT -p tcp --dport 22 -j ACCEPT

# Allow Namada P2P
-A INPUT -p tcp --dport 26656 -j ACCEPT

# Drop everything else
-A INPUT -j DROP

COMMIT
```

### 3. Network Hardening
```bash
# Disable IPv6 if not needed
echo 'net.ipv6.conf.all.disable_ipv6 = 1' | sudo tee -a /etc/sysctl.d/99-hardened.conf
echo 'net.ipv6.conf.default.disable_ipv6 = 1' | sudo tee -a /etc/sysctl.d/99-hardened.conf

# Disable IP forwarding
echo 'net.ipv4.ip_forward = 0' | sudo tee -a /etc/sysctl.d/99-hardened.conf
```

## Filesystem Security

### 1. Mount Options
Update `/etc/fstab`:
```bash
# Add security options to existing mounts
/dev/sda1 / ext4 defaults,noexec,nosuid,nodev 0 1

# IMPORTANT: /tmp needs to allow execution for Rust compilation and build tools
# Use a separate tmpfs for build operations
/tmp /tmp tmpfs defaults,nosuid,nodev,size=2G 0 0
/var/tmp /var/tmp tmpfs defaults,noexec,nosuid,nodev,size=1G 0 0

# Create secure build directory for compilation
/build /build tmpfs defaults,nosuid,nodev,size=4G 0 0
```

### 2. Directory Permissions
```bash
# Secure critical directories
sudo chmod 755 /home
sudo chmod 700 /home/namada
sudo chmod 755 /etc
sudo chmod 644 /etc/passwd
sudo chmod 600 /etc/shadow
sudo chmod 644 /etc/group
```

### 3. File Integrity Monitoring
```bash
# Install AIDE (Advanced Intrusion Detection Environment)
sudo apt install -y aide

# Initialize database
sudo aideinit

# Move database to secure location
sudo mv /var/lib/aide/aide.db.new /var/lib/aide/aide.db
```

### 4. Rust and Build Tool Considerations
```bash
# Create secure build environment
sudo mkdir -p /build
sudo chown namada:namada /build
sudo chmod 755 /build

# Set up Rust environment variables for secure compilation
cat >> /home/namada/.bashrc << 'EOF'
# Rust environment for secure builds
export CARGO_TARGET_DIR=/build/target
export CARGO_HOME=/build/cargo
export RUSTUP_HOME=/build/rustup
export TMPDIR=/build/tmp
EOF

# Create temporary directory for builds
sudo mkdir -p /build/tmp
sudo chown namada:namada /build/tmp
sudo chmod 755 /build/tmp
```

## Service Hardening

### 1. Disable Unnecessary Services
```bash
# List and disable unnecessary services
sudo systemctl disable bluetooth
sudo systemctl disable cups
sudo systemctl disable avahi-daemon
sudo systemctl disable whoopsie
sudo systemctl disable apport
```

### 2. SSH Hardening
Edit `/etc/ssh/sshd_config`:
```bash
# Security settings
PermitRootLogin no
PasswordAuthentication no
PubkeyAuthentication yes
AuthorizedKeysFile .ssh/authorized_keys
Protocol 2
Port 22
MaxAuthTries 3
ClientAliveInterval 300
ClientAliveCountMax 2
X11Forwarding no
AllowUsers namada
```

### 3. System Limits
Create `/etc/security/limits.d/99-namada.conf`:
```bash
# Set resource limits
namada soft nofile 65535
namada hard nofile 65535
namada soft nproc 32768
namada hard nproc 32768
```

## Namada Node Security

### 1. Install Namada Securely
```bash
# Create secure directory structure
sudo mkdir -p /opt/namada/{bin,data,config}
sudo chown -R namada:namada /opt/namada

# Download and verify Namada binary
cd /tmp
wget https://github.com/anoma/namada/releases/latest/download/namada-*.tar.gz
# Verify checksums and signatures
tar -xzf namada-*.tar.gz
sudo cp namada-*/namada /opt/namada/bin/
sudo chmod 755 /opt/namada/bin/namada
```

### 2. Configure Namada with Security
```bash
# Initialize with secure settings
sudo -u namada /opt/namada/bin/namada --base-dir /opt/namada/data init

# Configure with security settings
cat > /opt/namada/config/config.toml << EOF
# Security settings
rpc = { laddr = "127.0.0.1:26657" }
p2p = { laddr = "0.0.0.0:26656" }
consensus = { timeout_commit = "1s" }
mempool = { size = 10000 }
EOF
```

### 3. Systemd Service
Create `/etc/systemd/system/namada.service`:
```ini
[Unit]
Description=Namada Node
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
User=namada
Group=namada
WorkingDirectory=/opt/namada/data
ExecStart=/opt/namada/bin/namada node ledger run
Restart=always
RestartSec=10
LimitNOFILE=65535
LimitNPROC=32768
NoNewPrivileges=true
PrivateTmp=true
ProtectSystem=strict
ProtectHome=true
ReadWritePaths=/opt/namada/data
CapabilityBoundingSet=CAP_NET_BIND_SERVICE
AmbientCapabilities=CAP_NET_BIND_SERVICE

[Install]
WantedBy=multi-user.target
```

## Monitoring and Logging

### 1. System Monitoring
```bash
# Install monitoring tools
sudo apt install -y htop iotop nethogs fail2ban

# Configure fail2ban
sudo systemctl enable fail2ban
sudo systemctl start fail2ban
```

### 2. Log Configuration
Create `/etc/rsyslog.d/99-namada.conf`:
```bash
# Namada specific logging
:programname, isequal, "namada" /var/log/namada.log
& stop
```

### 3. Log Rotation
Create `/etc/logrotate.d/namada`:
```bash
/var/log/namada.log {
    daily
    missingok
    rotate 30
    compress
    delaycompress
    notifempty
    create 644 namada namada
}
```

## Important Security Considerations

### /tmp Directory and Build Tools
**CRITICAL**: When hardening `/tmp` with `noexec` option, it breaks Rust compilation and many build tools that need to execute temporary binaries. The hardening guide addresses this by:

1. **Keeping `/tmp` executable** but with `nosuid,nodev` for security
2. **Creating a separate `/build` directory** for compilation with proper permissions
3. **Configuring Rust environment variables** to use the secure build directory
4. **Using `/var/tmp` with `noexec`** for general temporary files that don't need execution

### Build Environment Security
- All compilation happens in `/build` directory with restricted permissions
- Rust toolchain uses secure temporary directories
- Build artifacts are isolated from system directories
- Temporary files are cleaned up automatically

## Security Checklist

### Pre-Deployment
- [ ] Full disk encryption enabled
- [ ] Secure boot enabled
- [ ] Strong passwords set
- [ ] SSH keys configured
- [ ] Firewall configured
- [ ] Unnecessary services disabled
- [ ] Kernel hardening applied
- [ ] File integrity monitoring set up
- [ ] Build environment configured securely

### Post-Deployment
- [ ] Namada node running securely
- [ ] Monitoring configured
- [ ] Logs being collected
- [ ] Backup strategy implemented
- [ ] Security updates automated
- [ ] Regular security audits scheduled

## Maintenance

### Daily
- Check system logs for anomalies
- Monitor Namada node status
- Verify backup integrity

### Weekly
- Review security logs
- Update system packages
- Check file integrity

### Monthly
- Full security audit
- Review and rotate keys
- Test disaster recovery procedures

## Emergency Procedures

### Incident Response
1. Isolate the system
2. Preserve logs and evidence
3. Assess damage
4. Implement fixes
5. Document lessons learned

### Recovery
1. Boot from secure media
2. Restore from clean backup
3. Apply all security patches
4. Reconfigure hardened settings
5. Verify system integrity

---

This guide hardens Ubuntu for Namada nodes using HardenedBSD-style security principles.
