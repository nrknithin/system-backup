# System Configuration Backup & Restore

This directory contains a complete backup of your Ubuntu 22.04 system configuration, including all installed packages, environment variables, and shell configurations.

## 📋 What's Included

### Backup Files
- **packages/apt_packages.list** - All 2103 installed APT packages
- **packages/apt_manual.list** - 202 manually installed packages (recommended for restore)
- **packages/snap_packages.list** - Snap packages (if any)
- **packages/pip3_packages.list** - Python pip3 packages
- **packages/npm_global_packages.list** - Node.js global packages
- **configs/** - Shell configuration files (.bashrc, .profile, .zshrc, etc.)
- **env/environment_variables.list** - All environment variables
- **system_info.txt** - System information and details

### Scripts
- **backup_system.sh** - Creates/updates the backup
- **restore_system.sh** - Restores configuration on a new system

## 🚀 Quick Start

### Creating a Backup (Already Done)
```bash
./backup_system.sh
```

### Restoring on a New System

1. **Copy this entire directory** to your new system:
   ```bash
   # On source system
   tar -czf sysconfig-backup.tar.gz /home/dev/nrknithin/sysconfig
   
   # Transfer to target system (via USB, scp, etc.)
   scp sysconfig-backup.tar.gz user@target-system:~/
   
   # On target system
   tar -xzf sysconfig-backup.tar.gz
   cd sysconfig
   ```

2. **Run the restore script**:
   ```bash
   ./restore_system.sh
   ```

3. **Follow the prompts** - The script will:
   - Update package lists
   - Install all manually installed APT packages
   - Install Snap packages (if any)
   - Install Python packages
   - Install Node.js global packages
   - Restore shell configuration files

4. **Manual steps after restore**:
   - Review `env/environment_variables.list` for custom variables
   - Add any custom environment variables to `~/.bashrc` or `~/.profile`
   - Restart your shell: `source ~/.bashrc`

## 📦 Package Breakdown

- **APT Packages**: 2103 total (202 manually installed)
- **Snap Packages**: Check `packages/snap_packages.list`
- **Python Packages**: Check `packages/pip3_packages.list`
- **NVM & Node.js**: v22.22.0, v24.12.0, v24.13.0 (default: 24) + npm global packages
- **SDKMAN Tools**: Java, Maven, Quarkus (see `packages/sdkman_candidates.list`)

## ⚙️ What Gets Restored

### ✅ Automatically Restored
- All manually installed APT packages
- Snap packages
- Python pip packages
- Node.js global packages
- Shell configuration files (.bashrc, .profile, .zshrc)

### 📝 Requires Manual Review
- **Environment Variables**: Review `env/environment_variables.list` and add custom ones to your shell config
- **APT Sources**: Check `configs/sources.list.d/` for custom repositories
- **System-specific settings**: Some configurations may need adjustment for the new system

## 🔧 Advanced Usage

### Update the Backup
Run the backup script again to update all files:
```bash
./backup_system.sh
```

### Selective Restore
You can manually install specific package types:

**APT packages only:**
```bash
sudo apt update
while read package; do sudo apt install -y "$package"; done < packages/apt_manual.list
```

**Python packages only:**
```bash
pip3 install -r packages/pip3_packages.list
```

**Node.js packages only:**
```bash
grep -oP '(?<=├── |└── )[^@]+' packages/npm_global_packages.list | while read pkg; do npm install -g "$pkg"; done
```

### Restore Shell Configs Only
```bash
cp configs/.bashrc ~/
cp configs/.profile ~/
cp configs/.zshrc ~/
source ~/.bashrc
```

## 🛡️ Important Notes

1. **Target System Requirements**:
   - Ubuntu/Debian-based distribution
   - Same or newer Ubuntu version recommended
   - Sufficient disk space for all packages

2. **Package Compatibility**:
   - Some packages may not be available on different Ubuntu versions
   - The restore script will skip unavailable packages and continue

3. **Credentials & Secrets**:
   - This backup does NOT include passwords, SSH keys, or credentials
   - Manually transfer sensitive files separately and securely

4. **Custom Software**:
   - Manually installed software (not via package managers) is not included
   - Document and reinstall these separately

## 📊 System Information

Check `system_info.txt` for:
- Original hostname
- OS version
- Kernel version
- Architecture
- Installed package managers
- Backup timestamp

## 🔄 Keeping Backups Updated

Run the backup script periodically to keep your configuration up to date:
```bash
# Add to crontab for weekly backups
0 0 * * 0 /home/dev/nrknithin/sysconfig/backup_system.sh
```

## 🆘 Troubleshooting

**Package installation fails:**
- Check if the package exists: `apt search <package-name>`
- Some packages may have different names on different Ubuntu versions
- Check the error message and install manually if needed

**Permission denied:**
- Ensure scripts are executable: `chmod +x *.sh`
- Run restore script with appropriate permissions

**Missing dependencies:**
- Run `sudo apt update` before restore
- Install build-essential if compiling packages: `sudo apt install build-essential`

## 📝 License

This is your personal system configuration backup. Use it to restore your own systems.

---

**Created**: February 2, 2026  
**System**: Ubuntu 22.04.5 LTS  
**Packages**: 2103 total, 202 manually installed
