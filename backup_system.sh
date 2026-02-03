#!/bin/bash

# System Configuration Backup Script
# This script captures the current system configuration for migration to another system

set -e

BACKUP_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)

echo "=========================================="
echo "System Configuration Backup Script"
echo "=========================================="
echo "Backup directory: $BACKUP_DIR"
echo "Timestamp: $TIMESTAMP"
echo ""

# 1. Create/checkout user-specific git branch FIRST
echo "[1/12] Setting up git branch..."
BRANCH_NAME="ubuntu-$USER"
if git rev-parse --git-dir > /dev/null 2>&1; then
    # Check if branch already exists
    if git show-ref --verify --quiet "refs/heads/$BRANCH_NAME"; then
        echo "  - Checking out existing branch: $BRANCH_NAME"
        git checkout "$BRANCH_NAME" 2>/dev/null || echo "  - Failed to checkout branch"
    else
        echo "  - Creating and checking out new branch: $BRANCH_NAME"
        git checkout -b "$BRANCH_NAME" 2>/dev/null || echo "  - Failed to create branch"
    fi
else
    echo "  - Not a git repository, skipping branch creation"
fi

# Create backup directories
mkdir -p "$BACKUP_DIR/packages"
mkdir -p "$BACKUP_DIR/configs"
mkdir -p "$BACKUP_DIR/env"

# 2. Backup APT packages
echo "[2/12] Backing up APT packages..."
dpkg --get-selections > "$BACKUP_DIR/packages/apt_packages.list"
apt-mark showmanual > "$BACKUP_DIR/packages/apt_manual.list"
echo "  - Saved $(wc -l < "$BACKUP_DIR/packages/apt_packages.list") packages"

# 2. Backup APT sources
echo "[3/12] Backing up APT sources..."
if [ -d /etc/apt/sources.list.d ]; then
    cp -r /etc/apt/sources.list.d "$BACKUP_DIR/configs/" 2>/dev/null || true
fi
cp /etc/apt/sources.list "$BACKUP_DIR/configs/sources.list" 2>/dev/null || true

# 3. Backup Snap packages
echo "[4/12] Backing up Snap packages..."
if command -v snap &> /dev/null; then
    snap list > "$BACKUP_DIR/packages/snap_packages.list" 2>/dev/null || echo "No snap packages installed"
else
    echo "  - Snap not installed"
fi

# 4. Backup Flatpak packages
echo "[5/12] Backing up Flatpak packages..."
if command -v flatpak &> /dev/null; then
    flatpak list --app --columns=application > "$BACKUP_DIR/packages/flatpak_packages.list" 2>/dev/null || echo "No flatpak packages installed"
else
    echo "  - Flatpak not installed"
fi

# 5. Backup Python packages
echo "[6/12] Backing up Python packages..."
if command -v pip3 &> /dev/null; then
    pip3 list --format=freeze > "$BACKUP_DIR/packages/pip3_packages.list" 2>/dev/null || true
fi
if command -v pip &> /dev/null; then
    pip list --format=freeze > "$BACKUP_DIR/packages/pip_packages.list" 2>/dev/null || true
fi

# 6. Backup NVM and Node.js
echo "[7/12] Backing up NVM and Node.js..."
if [ -d "$HOME/.nvm" ]; then
    # Backup NVM versions
    echo "NVM_DIR=$HOME/.nvm" > "$BACKUP_DIR/packages/nvm_config.txt"
    
    # List all installed Node versions
    > "$BACKUP_DIR/packages/nvm_versions.list"
    for version_dir in "$HOME/.nvm/versions/node"/*; do
        if [ -d "$version_dir" ]; then
            version=$(basename "$version_dir")
            echo "$version" >> "$BACKUP_DIR/packages/nvm_versions.list"
        fi
    done
    
    # Save default/current version
    if [ -f "$HOME/.nvm/alias/default" ]; then
        default_version=$(cat "$HOME/.nvm/alias/default")
        echo "DEFAULT:$default_version" >> "$BACKUP_DIR/packages/nvm_versions.list"
    fi
    
    # Backup global npm packages for current version
    if command -v npm &> /dev/null; then
        npm list -g --depth=0 > "$BACKUP_DIR/packages/npm_global_packages.list" 2>/dev/null || true
    fi
    
    echo "  - Backed up NVM and Node.js versions"
else
    echo "  - NVM not installed"
    # Fallback: backup npm packages if Node is installed without NVM
    if command -v npm &> /dev/null; then
        npm list -g --depth=0 > "$BACKUP_DIR/packages/npm_global_packages.list" 2>/dev/null || true
        echo "  - Backed up npm global packages"
    fi
fi

# 7. Backup SDKMAN candidates
echo "[8/12] Backing up SDKMAN candidates..."
if [ -d "$HOME/.sdkman" ]; then
    echo "SDKMAN_DIR=$HOME/.sdkman" > "$BACKUP_DIR/packages/sdkman_config.txt"
    
    # Clear previous list
    > "$BACKUP_DIR/packages/sdkman_candidates.list"
    
    # List all installed candidates and versions
    for candidate_dir in "$HOME/.sdkman/candidates"/*; do
        if [ -d "$candidate_dir" ]; then
            candidate=$(basename "$candidate_dir")
            echo "=== $candidate ===" >> "$BACKUP_DIR/packages/sdkman_candidates.list"
            
            # Get current version first
            current_version=""
            if [ -L "$candidate_dir/current" ]; then
                current_version=$(basename "$(readlink "$candidate_dir/current")")
            fi
            
            # List all versions for this candidate
            for version_dir in "$candidate_dir"/*; do
                if [ -d "$version_dir" ] && [ "$(basename "$version_dir")" != "current" ]; then
                    version=$(basename "$version_dir")
                    if [ "$version" = "$current_version" ]; then
                        echo "$candidate:$version:CURRENT" >> "$BACKUP_DIR/packages/sdkman_candidates.list"
                    else
                        echo "$candidate:$version" >> "$BACKUP_DIR/packages/sdkman_candidates.list"
                    fi
                fi
            done
        fi
    done
    echo "  - Backed up SDKMAN candidates"
else
    echo "  - SDKMAN not installed"
fi

# 8. Backup environment variables
echo "[9/12] Backing up environment variables..."
printenv | sort > "$BACKUP_DIR/env/environment_variables.list"

# 9. Backup shell configuration files
echo "[10/12] Backing up shell configuration files..."
for file in ~/.bashrc ~/.bash_profile ~/.profile ~/.zshrc ~/.zsh_profile; do
    if [ -f "$file" ]; then
        cp "$file" "$BACKUP_DIR/configs/" 2>/dev/null || true
        echo "  - Backed up $file"
    fi
done

# 10. Backup system information
echo "[11/12] Backing up system information..."
cat > "$BACKUP_DIR/system_info.txt" << EOF
System Information
==================
Hostname: $(hostname)
OS: $(cat /etc/os-release | grep PRETTY_NAME | cut -d'"' -f2)
Kernel: $(uname -r)
Architecture: $(uname -m)
Date: $(date)

Installed Package Managers:
- APT: $(command -v apt &> /dev/null && echo "Yes" || echo "No")
- Snap: $(command -v snap &> /dev/null && echo "Yes" || echo "No")
- Flatpak: $(command -v flatpak &> /dev/null && echo "Yes" || echo "No")
- pip3: $(command -v pip3 &> /dev/null && echo "Yes" || echo "No")
- npm: $(command -v npm &> /dev/null && echo "Yes" || echo "No")
- NVM: $([ -d "$HOME/.nvm" ] && echo "Yes" || echo "No")
- SDKMAN: $([ -d "$HOME/.sdkman" ] && echo "Yes" || echo "No")

Shell: $SHELL
User: $USER
Home: $HOME
EOF

# 12. Create system restore script
echo "[12/12] Creating restore script..."
cat > "$BACKUP_DIR/restore_system.sh" << 'RESTORE_SCRIPT'
#!/bin/bash

# System Configuration Restore Script
# This script restores the system configuration on a new machine

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "=========================================="
echo "System Configuration Restore Script"
echo "=========================================="
echo "Restore directory: $SCRIPT_DIR"
echo ""
echo "WARNING: This script will install packages and modify system configuration."
read -p "Do you want to continue? (yes/no): " confirm

if [ "$confirm" != "yes" ]; then
    echo "Restore cancelled."
    exit 0
fi

# Check if running on Ubuntu/Debian
if [ ! -f /etc/debian_version ]; then
    echo "ERROR: This script is designed for Ubuntu/Debian systems."
    exit 1
fi

# 1. Update package lists
echo ""
echo "[1/9] Updating package lists..."
sudo apt update

# 2. Restore APT packages
echo ""
echo "[2/9] Restoring APT packages..."
if [ -f "$SCRIPT_DIR/packages/apt_manual.list" ]; then
    echo "  - Installing manually installed packages..."
    while IFS= read -r package; do
        if ! dpkg -l | grep -q "^ii  $package "; then
            echo "    Installing: $package"
            sudo apt install -y "$package" 2>/dev/null || echo "    Failed to install: $package"
        fi
    done < "$SCRIPT_DIR/packages/apt_manual.list"
else
    echo "  - No APT package list found"
fi

# 3. Restore Snap packages
echo ""
echo "[3/9] Restoring Snap packages..."
if [ -f "$SCRIPT_DIR/packages/snap_packages.list" ] && command -v snap &> /dev/null; then
    tail -n +2 "$SCRIPT_DIR/packages/snap_packages.list" | while IFS= read -r line; do
        package=$(echo "$line" | awk '{print $1}')
        if [ -n "$package" ] && [ "$package" != "Name" ]; then
            echo "  - Installing snap: $package"
            sudo snap install "$package" 2>/dev/null || echo "    Failed to install: $package"
        fi
    done
else
    echo "  - Skipping Snap packages"
fi

# 4. Restore Flatpak packages
echo ""
echo "[4/9] Restoring Flatpak packages..."
if [ -f "$SCRIPT_DIR/packages/flatpak_packages.list" ] && command -v flatpak &> /dev/null; then
    while IFS= read -r package; do
        if [ -n "$package" ]; then
            echo "  - Installing flatpak: $package"
            flatpak install -y flathub "$package" 2>/dev/null || echo "    Failed to install: $package"
        fi
    done < "$SCRIPT_DIR/packages/flatpak_packages.list"
else
    echo "  - Skipping Flatpak packages"
fi

# 5. Restore Python packages
echo ""
echo "[5/9] Restoring Python packages..."
if [ -f "$SCRIPT_DIR/packages/pip3_packages.list" ] && command -v pip3 &> /dev/null; then
    echo "  - Installing pip3 packages..."
    pip3 install -r "$SCRIPT_DIR/packages/pip3_packages.list" 2>/dev/null || echo "    Some pip3 packages failed to install"
else
    echo "  - Skipping pip3 packages"
fi

# 6. Restore NVM and Node.js
echo ""
echo "[6/9] Restoring NVM and Node.js..."
if [ -f "$SCRIPT_DIR/packages/nvm_versions.list" ]; then
    # Install NVM if not present
    if [ ! -d "$HOME/.nvm" ]; then
        echo "  - Installing NVM..."
        curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.1/install.sh | bash
        export NVM_DIR="$HOME/.nvm"
        [ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
    else
        echo "  - NVM already installed"
        export NVM_DIR="$HOME/.nvm"
        [ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
    fi
    
    # Install Node versions
    default_version=""
    while IFS= read -r line; do
        if [[ "$line" =~ ^DEFAULT: ]]; then
            default_version=$(echo "$line" | cut -d':' -f2)
        elif [ -n "$line" ]; then
            echo "  - Installing Node.js $line..."
            nvm install "$line" 2>/dev/null || echo "    Failed to install Node.js $line"
        fi
    done < "$SCRIPT_DIR/packages/nvm_versions.list"
    
    # Set default version
    if [ -n "$default_version" ]; then
        echo "  - Setting Node.js $default_version as default..."
        nvm alias default "$default_version" 2>/dev/null || true
        nvm use default 2>/dev/null || true
    fi
    
    # Restore global npm packages
    if [ -f "$SCRIPT_DIR/packages/npm_global_packages.list" ]; then
        echo "  - Installing npm global packages..."
        grep -oP '(?<=├── |└── )[^@]+' "$SCRIPT_DIR/packages/npm_global_packages.list" 2>/dev/null | while read -r package; do
            if [ -n "$package" ] && [ "$package" != "npm" ]; then
                echo "    Installing: $package"
                npm install -g "$package" 2>/dev/null || echo "    Failed to install: $package"
            fi
        done
    fi
else
    echo "  - No NVM configuration found"
    # Fallback: restore npm packages if available
    if [ -f "$SCRIPT_DIR/packages/npm_global_packages.list" ] && command -v npm &> /dev/null; then
        echo "  - Installing npm global packages..."
        grep -oP '(?<=├── |└── )[^@]+' "$SCRIPT_DIR/packages/npm_global_packages.list" 2>/dev/null | while read -r package; do
            if [ -n "$package" ] && [ "$package" != "npm" ]; then
                echo "    Installing: $package"
                npm install -g "$package" 2>/dev/null || echo "    Failed to install: $package"
            fi
        done
    fi
fi

# 7. Restore SDKMAN and candidates
echo ""
echo "[7/9] Restoring SDKMAN and candidates..."
if [ -f "$SCRIPT_DIR/packages/sdkman_candidates.list" ]; then
    # Install SDKMAN if not present
    if [ ! -d "$HOME/.sdkman" ]; then
        echo "  - Installing SDKMAN..."
        curl -s "https://get.sdkman.io" | bash
        source "$HOME/.sdkman/bin/sdkman-init.sh"
    else
        echo "  - SDKMAN already installed"
        source "$HOME/.sdkman/bin/sdkman-init.sh"
    fi
    
    # Install candidates
    current_candidate=""
    while IFS= read -r line; do
        if [[ "$line" =~ ^===.*===$ ]]; then
            current_candidate=$(echo "$line" | sed 's/=== \(.*\) ===/\1/')
            echo "  - Processing $current_candidate..."
        elif [ -n "$line" ] && [ -n "$current_candidate" ]; then
            IFS=':' read -r candidate version is_current <<< "$line"
            if [ "$candidate" = "$current_candidate" ]; then
                echo "    Installing $candidate $version..."
                sdk install "$candidate" "$version" 2>/dev/null || echo "    Failed to install $candidate $version"
                
                if [ "$is_current" = "CURRENT" ]; then
                    echo "    Setting $candidate $version as current..."
                    sdk default "$candidate" "$version" 2>/dev/null || true
                fi
            fi
        fi
    done < "$SCRIPT_DIR/packages/sdkman_candidates.list"
else
    echo "  - No SDKMAN candidates to restore"
fi

# 8. Restore shell configuration files
echo ""
echo "[8/9] Restoring shell configuration files..."
for file in "$SCRIPT_DIR/configs/.bashrc" "$SCRIPT_DIR/configs/.bash_profile" "$SCRIPT_DIR/configs/.profile" "$SCRIPT_DIR/configs/.zshrc"; do
    if [ -f "$file" ]; then
        filename=$(basename "$file")
        echo "  - Restoring $filename"
        cp "$file" "$HOME/" 2>/dev/null || echo "    Failed to restore: $filename"
    fi
done

# 9. Display environment variables
echo ""
echo "[9/9] Environment variables backed up in: $SCRIPT_DIR/env/environment_variables.list"
echo "  - Review and manually add any custom environment variables to your shell config"

echo ""
echo "=========================================="
echo "Restore Complete!"
echo "=========================================="
echo ""
echo "Next steps:"
echo "1. Review $SCRIPT_DIR/env/environment_variables.list for custom environment variables"
echo "2. Add any custom environment variables to your ~/.bashrc or ~/.profile"
echo "3. Restart your shell or run: source ~/.bashrc"
echo "4. If NVM was installed, run: source ~/.nvm/nvm.sh"
echo "5. If SDKMAN was installed, run: source ~/.sdkman/bin/sdkman-init.sh"
echo "6. Review $SCRIPT_DIR/system_info.txt for additional system details"
echo ""
RESTORE_SCRIPT

chmod +x "$BACKUP_DIR/restore_system.sh"

# Stage and commit the backup files
if git rev-parse --git-dir > /dev/null 2>&1; then
    echo ""
    echo "Committing backup files to branch ubuntu-$USER..."
    git add . 2>/dev/null || true
    git commit -m "Backup system configuration for $USER on $(date +%Y-%m-%d)" 2>/dev/null || echo "  - No changes to commit"
fi

echo ""
echo "=========================================="
echo "Backup Complete!"
echo "=========================================="
echo ""
echo "Backup location: $BACKUP_DIR"
echo ""
echo "Files created:"
echo "  - packages/apt_packages.list ($(wc -l < "$BACKUP_DIR/packages/apt_packages.list" 2>/dev/null || echo 0) packages)"
echo "  - packages/apt_manual.list ($(wc -l < "$BACKUP_DIR/packages/apt_manual.list" 2>/dev/null || echo 0) packages)"
if [ -f "$BACKUP_DIR/packages/sdkman_candidates.list" ]; then
    echo "  - packages/sdkman_candidates.list (SDKMAN tools)"
fi
echo "  - env/environment_variables.list"
echo "  - system_info.txt"
echo "  - restore_system.sh (executable)"
echo ""
echo "To restore on another system:"
echo "1. Copy this entire directory to the target system"
echo "2. Run: ./restore_system.sh"
echo ""