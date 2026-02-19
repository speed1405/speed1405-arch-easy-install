#!/bin/bash
#
# Configuration management for Arch Easy Installer
# Supports JSON and YAML configuration files
#

CONFIG_FILE="/tmp/arch-install-config.json"
STATE_FILE="/tmp/arch-install-state.json"
RESUME_FILE="/tmp/arch-install-resume"

# Initialize configuration
init_config() {
    cat > "$CONFIG_FILE" <<'EOF'
{
    "version": "1.0.0",
    "disk": {
        "device": "",
        "partitioning": "automatic",
        "filesystem": "ext4",
        "swap_size": "2048",
        "separate_home": true,
        "encrypt": false,
        "use_lvm": false,
        "use_zfs": false
    },
    "system": {
        "hostname": "archpc",
        "timezone": "UTC",
        "locale": "en_US.UTF-8",
        "keymap": "us",
        "root_password": "",
        "create_user": true,
        "username": "",
        "user_password": ""
    },
    "bootloader": {
        "type": "systemd-boot",
        "target": "UEFI"
    },
    "desktop": {
        "install": false,
        "environment": "gnome",
        "install_drivers": true
    },
    "packages": {
        "base": ["base", "base-devel", "linux", "linux-firmware"],
        "additional": [],
        "aur_helper": false
    },
    "network": {
        "hostname": "archpc",
        "enable_wifi": true,
        "enable_bluetooth": true
    },
    "security": {
        "enable_firewall": true,
        "encrypt_disk": false,
        "luks_password": ""
    },
    "options": {
        "dry_run": false,
        "verbose": false,
        "auto_reboot": false,
        "skip_checks": false
    }
}
EOF
    log_info "Configuration initialized"
}

# Load configuration from file
load_config() {
    if [[ -f "$CONFIG_FILE" ]]; then
        CONFIG=$(cat "$CONFIG_FILE")
        log_info "Configuration loaded from $CONFIG_FILE"
    else
        init_config
        CONFIG=$(cat "$CONFIG_FILE")
    fi
}

# Save configuration to file
save_config() {
    echo "$CONFIG" > "$CONFIG_FILE"
    log_info "Configuration saved to $CONFIG_FILE"
}

# Get configuration value
get_config() {
    local key=$1
    local default=${2:-""}
    
    if command -v jq &>/dev/null; then
        echo "$CONFIG" | jq -r "$key // \"$default\""
    else
        # Fallback to grep/sed if jq not available
        echo "$default"
    fi
}

# Set configuration value
set_config() {
    local key=$1
    local value=$2
    
    if command -v jq &>/dev/null; then
        CONFIG=$(echo "$CONFIG" | jq "$key = \"$value\"")
        save_config
    fi
}

# Save installation state for resume
save_state() {
    local phase=$1
    local status=$2
    
    cat > "$STATE_FILE" <<EOF
{
    "phase": "$phase",
    "status": "$status",
    "timestamp": "$(date -Iseconds)",
    "disk": "$INSTALL_DISK",
    "config_file": "$CONFIG_FILE"
}
EOF
    log_info "State saved: phase=$phase, status=$status"
}

# Load installation state
load_state() {
    if [[ -f "$STATE_FILE" ]]; then
        local phase=$(cat "$STATE_FILE" | jq -r '.phase // "none"')
        local status=$(cat "$STATE_FILE" | jq -r '.status // "none"')
        local disk=$(cat "$STATE_FILE" | jq -r '.disk // ""')
        
        if [[ "$status" == "in_progress" ]]; then
            log_warn "Previous installation found at phase: $phase"
            return 0
        fi
    fi
    return 1
}

# Check if we can resume installation
check_resume() {
    if load_state; then
        if dialog --yesno "A previous installation was interrupted.\n\nWould you like to resume from where it left off?\n\nNote: If you choose 'No', the previous state will be cleared." 12 60; then
            return 0
        else
            # Clear state
            rm -f "$STATE_FILE"
            rm -f "$CONFIG_FILE"
            init_config
            return 1
        fi
    fi
    return 1
}

# Get resume phase
get_resume_phase() {
    if [[ -f "$STATE_FILE" ]]; then
        cat "$STATE_FILE" | jq -r '.phase // "start"'
    else
        echo "start"
    fi
}

# Export configuration for chroot environment
export_config_to_chroot() {
    cp "$CONFIG_FILE" /mnt/install-config.json
    log_info "Configuration exported to /mnt"
}

# Validate configuration
validate_config() {
    local errors=()
    
    # Check disk
    local disk=$(get_config '.disk.device')
    if [[ -z "$disk" ]] || [[ ! -b "$disk" ]]; then
        errors+=("Invalid disk: $disk")
    fi
    
    # Check swap size is numeric
    local swap_size=$(get_config '.disk.swap_size')
    if ! [[ "$swap_size" =~ ^[0-9]+$ ]]; then
        errors+=("Invalid swap size: $swap_size (must be a number)")
    fi
    
    # Check hostname
    local hostname=$(get_config '.system.hostname')
    if [[ -z "$hostname" ]] || [[ ! "$hostname" =~ ^[a-zA-Z0-9-]+$ ]]; then
        errors+=("Invalid hostname: $hostname")
    fi
    
    # Check username
    local username=$(get_config '.system.username')
    if [[ -n "$username" ]] && [[ ! "$username" =~ ^[a-z][a-z0-9-]*$ ]]; then
        errors+=("Invalid username: $username")
    fi
    
    if [[ ${#errors[@]} -gt 0 ]]; then
        log_error "Configuration validation failed:"
        for error in "${errors[@]}"; do
            log_error "  - $error"
        done
        return 1
    fi
    
    log_info "Configuration validation passed"
    return 0
}

# Print configuration summary
print_config_summary() {
    local summary="Installation Configuration Summary:\n\n"
    
    summary+="Disk:\n"
    summary+="  Device: $(get_config '.disk.device')\n"
    summary+="  Partitioning: $(get_config '.disk.partitioning')\n"
    summary+="  Filesystem: $(get_config '.disk.filesystem')\n"
    summary+="  Swap: $(get_config '.disk.swap_size') MB\n"
    summary+="  Separate /home: $(get_config '.disk.separate_home')\n"
    summary+="  Encryption: $(get_config '.disk.encrypt')\n"
    summary+="  LVM: $(get_config '.disk.use_lvm')\n\n"
    
    summary+="System:\n"
    summary+="  Hostname: $(get_config '.system.hostname')\n"
    summary+="  Timezone: $(get_config '.system.timezone')\n"
    summary+="  Locale: $(get_config '.system.locale')\n"
    summary+="  Keymap: $(get_config '.system.keymap')\n"
    summary+="  Username: $(get_config '.system.username')\n\n"
    
    summary+="Desktop:\n"
    summary+="  Install: $(get_config '.desktop.install')\n"
    summary+="  Environment: $(get_config '.desktop.environment')\n\n"
    
    summary+="Options:\n"
    summary+="  Dry run: $(get_config '.options.dry_run')\n"
    summary+="  Verbose: $(get_config '.options.verbose')\n"
    
    echo -e "$summary"
}
