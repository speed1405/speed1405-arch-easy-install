#!/bin/bash
#
# Setup script for Arch Linux Easy Installer
# Makes all scripts executable and validates installation
#

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "Setting up Arch Linux Easy Installer..."

# Make main script executable
chmod +x "$SCRIPT_DIR/arch-easy-install.sh"
echo "✓ Main script made executable"

# Make all library files executable
for file in "$SCRIPT_DIR"/lib/*.sh; do
    if [[ -f "$file" ]]; then
        chmod +x "$file"
        echo "✓ Made executable: $(basename "$file")"
    fi
done

# Create config directory if it doesn't exist
mkdir -p "$SCRIPT_DIR/config"
mkdir -p "$SCRIPT_DIR/config/mirrorlist"
echo "✓ Config directories created"

# Create example configuration files
cat > "$SCRIPT_DIR/config/example-minimal.json" <<'EOF'
{
    "version": "1.0.0",
    "disk": {
        "device": "/dev/sda",
        "partitioning": "automatic",
        "filesystem": "ext4",
        "swap_size": "2048",
        "separate_home": false,
        "encrypt": false
    },
    "system": {
        "hostname": "arch-minimal",
        "timezone": "UTC",
        "locale": "en_US.UTF-8",
        "keymap": "us",
        "create_user": true,
        "username": "user"
    },
    "desktop": {
        "install": false
    },
    "packages": {
        "aur_helper": false
    }
}
EOF
cat > "$SCRIPT_DIR/config/example-desktop.json" <<'EOF'
{
    "version": "1.0.0",
    "disk": {
        "device": "/dev/sda",
        "partitioning": "automatic",
        "filesystem": "ext4",
        "swap_size": "4096",
        "separate_home": true,
        "encrypt": false
    },
    "system": {
        "hostname": "arch-desktop",
        "timezone": "America/New_York",
        "locale": "en_US.UTF-8",
        "keymap": "us",
        "create_user": true,
        "username": "user"
    },
    "desktop": {
        "install": true,
        "environment": "gnome",
        "install_drivers": true
    },
    "packages": {
        "aur_helper": true
    }
}
EOF
cat > "$SCRIPT_DIR/config/example-encrypted.json" <<'EOF'
{
    "version": "1.0.0",
    "disk": {
        "device": "/dev/sda",
        "partitioning": "automatic",
        "filesystem": "ext4",
        "swap_size": "4096",
        "separate_home": true,
        "encrypt": true
    },
    "system": {
        "hostname": "arch-secure",
        "timezone": "America/New_York",
        "locale": "en_US.UTF-8",
        "keymap": "us",
        "create_user": true,
        "username": "user"
    },
    "desktop": {
        "install": true,
        "environment": "kde",
        "install_drivers": true
    },
    "packages": {
        "aur_helper": true
    },
    "security": {
        "enable_firewall": true,
        "encrypt_disk": true
    }
}
EOF
echo "✓ Example configuration files created"

# Verify all required files exist
echo ""
echo "Verifying installation..."

required_files=(
    "arch-easy-install.sh"
    "lib/common.sh"
    "lib/config.sh"
    "lib/validation.sh"
    "lib/preflight.sh"
    "lib/progress.sh"
    "lib/encryption.sh"
    "lib/disk.sh"
    "lib/install.sh"
    "lib/desktop.sh"
    "lib/aur.sh"
    "lib/bundles.sh"
    "lib/wm_configs.sh"
)

missing_files=0
for file in "${required_files[@]}"; do
    if [[ -f "$SCRIPT_DIR/$file" ]]; then
        echo "✓ Found: $file"
    else
        echo "✗ Missing: $file"
        ((missing_files++))
    fi
done

echo ""
if [[ $missing_files -eq 0 ]]; then
    echo "✅ Setup complete! All files present."
    echo ""
    echo "To run the installer:"
    echo "  sudo bash $SCRIPT_DIR/arch-easy-install.sh"
    echo ""
    echo "To test with dry-run:"
    echo "  sudo bash $SCRIPT_DIR/arch-easy-install.sh --dry-run"
    echo ""
    echo "Example configurations are in: $SCRIPT_DIR/config/"
    exit 0
else
    echo "⚠️  Setup incomplete: $missing_files files missing"
    exit 1
fi
