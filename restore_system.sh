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
