# Hardened Ubuntu Setup for Namada Node

This repository contains security hardening scripts for Ubuntu systems running Namada blockchain nodes.

## 🚨 Important: /tmp Directory Considerations

**CRITICAL**: When hardening `/tmp` with `noexec` option, it breaks Rust compilation and many build tools that need to execute temporary binaries. This solution addresses this by:

- **Keeping `/tmp` executable** but with `nosuid,nodev` for security
- **Creating a separate `/build` directory** for compilation with proper permissions  
- **Configuring Rust environment variables** to use the secure build directory
- **Using `/var/tmp` with `noexec`** for general temporary files that don't need execution

##  Repository Contents

### Documentation
- **`UBUNTU_HARDENING_GUIDE.md`** - Comprehensive hardening guide with HardenedBSD-style security
- **`README.md`** - This file with overview and usage instructions

### Automation Scripts
- **`install.sh`** - Simple launcher script (recommended entry point)
- **`setup-hardened-namada.sh`** - Master script that chains all operations
- **`harden-ubuntu.sh`** - Main hardening script that applies all security measures
- **`setup-build-env.sh`** - Sets up secure build environment for Rust/compilation
- **`setup-namadaoperator.sh`** - Creates namadaoperator user with admin privileges
- **`install-namada.sh`** - Secure Namada installation and configuration

##  Security Features Implemented

### Kernel Hardening
- **ASLR (Address Space Layout Randomization)** - Prevents memory-based attacks
- **Memory protection** - Restricts kernel pointer access and dmesg
- **Network security** - Disables dangerous network features
- **Process restrictions** - Limits ptrace and file operations

### Network Security
- **UFW Firewall** - Configures restrictive firewall rules
- **Fail2ban** - Prevents brute force attacks
- **SSH Hardening** - Disables root login, password auth, X11 forwarding
- **Network isolation** - Disables IP forwarding and unnecessary protocols

### Filesystem Security
- **Secure mount options** - Applies `nosuid,nodev` where appropriate
- **Build environment isolation** - Separate `/build` directory for compilation
- **File integrity monitoring** - AIDE for detecting unauthorized changes
- **Directory permissions** - Restricts access to sensitive directories

### Service Hardening
- **Disable unnecessary services** - Removes attack surface
- **Systemd service security** - Applies security restrictions to Namada service
- **Resource limits** - Prevents resource exhaustion attacks
- **Logging configuration** - Comprehensive audit trail

### User Management
- **Namadaoperator user** - Dedicated admin user with sudo privileges
- **Service user separation** - Namada runs as dedicated service user
- **SSH access control** - Restricted to namadaoperator user only
- **Privilege separation** - No root access needed for daily operations

##  Quick Start

### 1. Prerequisites
- Fresh Ubuntu 22.04 LTS or 24.04 LTS installation
- User with sudo privileges
- Internet connection
- Minimum 8GB RAM, 100GB storage

### 2. Run Complete Setup (Recommended)
```bash
# Clone or download the scripts
cd /path/to/namada-code

# Run the complete setup (hardening + build env + Namada)
./install.sh
```

### Alternative: Manual Step-by-Step
```bash
# Option 1: Run individual scripts in order
./harden-ubuntu.sh
./setup-build-env.sh
./install-namada.sh

# Option 2: Run the master script
./setup-hardened-namada.sh
```

##  Detailed Usage

### Hardening Script (`harden-ubuntu.sh`)
The main hardening script performs the following operations:

1. **System Updates** - Updates packages and configures automatic updates
2. **Kernel Hardening** - Applies security kernel parameters
3. **Network Security** - Configures firewall and fail2ban
4. **SSH Hardening** - Secures SSH configuration
5. **Service Hardening** - Disables unnecessary services
6. **Filesystem Security** - Sets up secure mount options and permissions
7. **User Management** - Creates namada user with proper permissions
8. **Monitoring Setup** - Configures logging and monitoring
9. **Automation** - Sets up cron jobs for maintenance

### Build Environment Script (`setup-build-env.sh`)
Sets up a secure build environment that addresses the `/tmp` execution issue:

1. **Creates `/build` directory** - Secure location for compilation
2. **Configures Rust environment** - Sets up CARGO_HOME, RUSTUP_HOME, etc.
3. **Build isolation** - Scripts for running builds in isolated environment
4. **Cleanup automation** - Automatic cleanup of build artifacts
5. **Monitoring** - Scripts to monitor build environment health

### Namada Installation Script (`install-namada.sh`)
Securely installs and configures Namada:

1. **Downloads latest Namada** - Fetches from official GitHub releases
2. **Secure installation** - Installs with proper permissions
3. **Service configuration** - Creates systemd service with security restrictions
4. **Logging setup** - Configures comprehensive logging
5. **Management scripts** - Creates scripts for node management

##  Management Commands

### System Management
```bash
# Check system security status
/usr/local/bin/security-check.sh

# Run system maintenance
/usr/local/bin/namada-maintenance.sh

# Monitor build environment
/usr/local/bin/monitor-build-env.sh
```

### Namada Management
```bash
# Start/stop/restart Namada
/usr/local/bin/namada-manage.sh start
/usr/local/bin/namada-manage.sh stop
/usr/local/bin/namada-manage.sh restart

# Check Namada status
/usr/local/bin/namada-manage.sh status
/usr/local/bin/namada-manage.sh logs

# Backup Namada data
/usr/local/bin/namada-manage.sh backup
```

### Namadaoperator User Management
```bash
# Switch to namadaoperator user
su - namadaoperator

# Use namadaoperator management commands
namada-operator.sh status
namada-operator.sh logs
namada-operator.sh security
namada-operator.sh monitor

# Quick aliases (when logged in as namadaoperator)
namada-status
namada-logs
namada-start
namada-stop
namada-restart
security-check
namada-monitor
```

### Build Environment Management
```bash
# Install Rust securely
/usr/local/bin/install-rust-secure.sh

# Run builds in isolation
/usr/local/bin/isolated-build.sh cargo build --release

# Clean build environment
/usr/local/bin/clean-build-env.sh

# Test build environment
/usr/local/bin/test-build-env.sh
```

##  Security Monitoring

### Automated Monitoring
- **Daily security checks** - Runs at 2 AM via cron
- **File integrity monitoring** - Weekly AIDE checks
- **Log rotation** - Automatic log cleanup
- **Build environment cleanup** - Daily cleanup of build artifacts

### Manual Monitoring
```bash
# Check system security
/usr/local/bin/security-check.sh

# Monitor Namada node
/usr/local/bin/namada-monitor.sh

# Check build environment
/usr/local/bin/monitor-build-env.sh

# View system logs
sudo journalctl -u namada -f
```

##  Troubleshooting

### Common Issues

#### Build Environment Issues
```bash
# Test build environment
/usr/local/bin/test-build-env.sh

# Clean and reset build environment
/usr/local/bin/clean-build-env.sh
```

#### Namada Service Issues
```bash
# Check service status
systemctl status namada

# View logs
journalctl -u namada -n 50

# Restart service
systemctl restart namada
```

#### Security Issues
```bash
# Check firewall status
sudo ufw status

# Check fail2ban status
sudo fail2ban-client status

# Verify kernel hardening
cat /proc/sys/kernel/randomize_va_space
```

### Recovery Procedures

#### Build Environment Recovery
```bash
# Reset build environment
sudo rm -rf /build/*
./setup-build-env.sh
```

#### Namada Recovery
```bash
# Stop service
systemctl stop namada

# Restore from backup
/usr/local/bin/namada-manage.sh backup
# (restore from backup directory)

# Restart service
systemctl start namada
```

## 📚 Security Principles Applied

This hardening solution implements security principles similar to HardenedBSD:

### Memory Protection
- **ASLR** - Randomizes memory layout
- **NX bit** - Prevents code execution in data areas
- **Stack protection** - Protects against buffer overflows
- **Heap protection** - Guards against heap-based attacks

### Process Isolation
- **User separation** - Namada runs as dedicated user
- **Capability restrictions** - Limited system capabilities
- **Resource limits** - Prevents resource exhaustion
- **No new privileges** - Prevents privilege escalation

### Network Security
- **Firewall rules** - Restrictive network access
- **Intrusion detection** - Fail2ban for attack prevention
- **Service hardening** - Minimal network services
- **Protocol restrictions** - Disable dangerous protocols

### Filesystem Security
- **Mount restrictions** - Secure mount options
- **File integrity** - AIDE monitoring
- **Permission restrictions** - Minimal file permissions
- **Build isolation** - Separate build environment

##  Maintenance

### Daily Tasks
- Monitor system logs for anomalies
- Check Namada node status
- Verify backup integrity

### Weekly Tasks
- Review security logs
- Update system packages
- Check file integrity
- Clean build environment

### Monthly Tasks
- Full security audit
- Review and rotate keys
- Test disaster recovery procedures
- Update security configurations

## 📞 Support

For issues with this hardening solution:

1. **Check logs** - Review system and application logs
2. **Run diagnostics** - Use provided monitoring scripts
3. **Verify configuration** - Check security settings
4. **Test components** - Use test scripts provided

##  Important Notes

- **Backup before hardening** - Always backup your system before applying hardening
- **Test in staging** - Test the hardening process in a non-production environment first
- **Monitor after deployment** - Closely monitor the system after hardening
- **Keep updated** - Regularly update security patches and configurations
- **Document changes** - Keep track of any custom modifications

##  License

This hardening solution is provided as-is for educational and operational purposes. Use at your own risk and always test in a safe environment first.

---

**Remember**: Security is an ongoing process, not a one-time setup. Regular monitoring, updates, and audits are essential for maintaining a secure system.
# Namada-Mock
