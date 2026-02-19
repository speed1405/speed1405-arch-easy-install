#!/bin/bash
#
# Input validation and security functions
#

# Validate integer
validate_integer() {
    local value=$1
    local min=${2:-0}
    local max=${3:-999999}
    local name=${4:-"value"}
    
    if ! [[ "$value" =~ ^-?[0-9]+$ ]]; then
        log_error "$name must be a valid integer (got: $value)"
        return 1
    fi
    
    if [[ $value -lt $min ]] || [[ $value -gt $max ]]; then
        log_error "$name must be between $min and $max (got: $value)"
        return 1
    fi
    
    return 0
}

# Validate hostname
validate_hostname() {
    local hostname=$1
    
    # Hostname rules:
    # - 1-63 characters
    # - Only letters, numbers, and hyphens
    # - Cannot start or end with hyphen
    # - Cannot be all numeric
    
    if [[ ${#hostname} -lt 1 ]] || [[ ${#hostname} -gt 63 ]]; then
        log_error "Hostname must be 1-63 characters long"
        return 1
    fi
    
    if [[ ! "$hostname" =~ ^[a-zA-Z0-9]([a-zA-Z0-9-]*[a-zA-Z0-9])?$ ]]; then
        log_error "Hostname can only contain letters, numbers, and hyphens (cannot start/end with hyphen)"
        return 1
    fi
    
    if [[ "$hostname" =~ ^[0-9]+$ ]]; then
        log_error "Hostname cannot be all numeric"
        return 1
    fi
    
    return 0
}

# Validate username
validate_username() {
    local username=$1
    
    # Username rules (POSIX standard):
    # - 1-32 characters
    # - Must start with a letter
    # - Only lowercase letters, numbers, hyphens, underscores
    # - Cannot be reserved system names
    
    local reserved_names=("root" "admin" "daemon" "bin" "sys" "sync" "games" "man" "lp" "mail" "news" "uucp" "proxy" "www-data" "backup" "list" "irc" "gnats" "nobody" "systemd-network" "systemd-resolve" "messagebus" "systemd-timesync" "sshd")
    
    if [[ ${#username} -lt 1 ]] || [[ ${#username} -gt 32 ]]; then
        log_error "Username must be 1-32 characters long"
        return 1
    fi
    
    if [[ ! "$username" =~ ^[a-z][a-z0-9_-]*$ ]]; then
        log_error "Username must start with a letter and contain only lowercase letters, numbers, hyphens, and underscores"
        return 1
    fi
    
    for reserved in "${reserved_names[@]}"; do
        if [[ "$username" == "$reserved" ]]; then
            log_error "Username '$username' is reserved for system use"
            return 1
        fi
    done
    
    return 0
}

# Validate password strength
validate_password() {
    local password=$1
    local min_length=${2:-8}
    
    if [[ ${#password} -lt $min_length ]]; then
        log_warn "Password is shorter than $min_length characters (recommended)"
        # Don't fail, just warn
    fi
    
    # Check for common weak passwords
    local weak_passwords=("password" "123456" "qwerty" "admin" "letmein" "welcome" "monkey" "1234567890")
    
    for weak in "${weak_passwords[@]}"; do
        if [[ "${password,,}" == "$weak" ]]; then
            log_error "Password is too common and insecure"
            return 1
        fi
    done
    
    return 0
}

# Validate disk device
validate_disk() {
    local disk=$1
    
    if [[ -z "$disk" ]]; then
        log_error "No disk specified"
        return 1
    fi
    
    if [[ ! -b "$disk" ]]; then
        log_error "Disk $disk is not a valid block device"
        return 1
    fi
    
    if [[ ! -w "$disk" ]]; then
        log_error "No write permission for disk $disk (are you root?)"
        return 1
    fi
    
    # Check if disk is mounted
    if mount | grep -q "$disk"; then
        log_error "Disk $disk is currently mounted"
        return 1
    fi
    
    return 0
}

# Validate partition size
validate_partition_size() {
    local size=$1
    local available=$2
    local name=${3:-"partition"}
    
    if ! validate_integer "$size" 1 "$available" "$name size"; then
        return 1
    fi
    
    # Minimum sizes (in MB)
    case "$name" in
        "boot") 
            if [[ $size -lt 100 ]]; then
                log_error "Boot partition must be at least 100 MB"
                return 1
            fi
            ;;
        "root")
            if [[ $size -lt 5120 ]]; then
                log_error "Root partition must be at least 5 GB"
                return 1
            fi
            ;;
        "swap")
            # Swap can be 0 (disabled)
            if [[ $size -lt 0 ]]; then
                log_error "Invalid swap size"
                return 1
            fi
            ;;
    esac
    
    return 0
}

# Validate filesystem type
validate_filesystem() {
    local fs=$1
    local supported=("ext4" "btrfs" "xfs" "f2fs")
    
    for supported_fs in "${supported[@]}"; do
        if [[ "$fs" == "$supported_fs" ]]; then
            return 0
        fi
    done
    
    log_error "Unsupported filesystem: $fs (supported: ${supported[*]})"
    return 1
}

# Sanitize input (remove dangerous characters)
sanitize_input() {
    local input=$1
    # Remove control characters and dangerous shell characters
    echo "$input" | tr -d '[:cntrl:]' | sed 's/[;&|`$(){}[\]\\]//g'
}

# Confirm dangerous operation with type-to-confirm
confirm_dangerous_operation() {
    local message=$1
    local confirm_text=${2:-"CONFIRM"}
    
    local user_input
    user_input=$(dialog_safe --clear --title "⚠ DANGEROUS OPERATION" \
        --inputbox "${message}\n\nType '${confirm_text}' to proceed:" 12 60 \
        3>&1 1>&2 2>&3)
    
    if [[ "$user_input" != "$confirm_text" ]]; then
        log_warn "User did not confirm dangerous operation"
        return 1
    fi
    
    return 0
}

# Check for sufficient disk space
check_disk_space_available() {
    local disk=$1
    local required_mb=${2:-20480}  # 20GB default
    
    local available_mb
    available_mb=$(blockdev --getsize64 "$disk" 2>/dev/null | awk '{print int($1/1024/1024)}')
    
    if [[ $available_mb -lt $required_mb ]]; then
        log_error "Insufficient disk space: ${available_mb}MB available, ${required_mb}MB required"
        return 1
    fi
    
    log_info "Disk space check passed: ${available_mb}MB available"
    return 0
}

# Validate network configuration
validate_network_config() {
    local hostname=$1
    
    if ! validate_hostname "$hostname"; then
        return 1
    fi
    
    # Check if hostname resolves (DNS check)
    if getent hosts "$hostname" &>/dev/null; then
        log_warn "Hostname '$hostname' already resolves to an IP address"
    fi
    
    return 0
}

# Check for encryption requirements
check_encryption_requirements() {
    if ! command -v cryptsetup &>/dev/null; then
        log_error "cryptsetup not available (required for encryption)"
        return 1
    fi
    
    # Check for AES-NI support (hardware acceleration)
    if grep -q "aes" /proc/cpuinfo; then
        log_info "CPU supports AES-NI encryption acceleration"
    else
        log_warn "CPU does not support AES-NI (encryption may be slower)"
    fi
    
    return 0
}

# Validate LUKS password strength
validate_luks_password() {
    local password=$1
    
    if [[ ${#password} -lt 8 ]]; then
        log_error "LUKS password must be at least 8 characters"
        return 1
    fi
    
    # LUKS passwords should be memorable but strong
    # Just check it's not obviously weak
    local weak_passwords=("password" "12345678" "qwerty123" "letmein1")
    
    for weak in "${weak_passwords[@]}"; do
        if [[ "$password" == "$weak" ]]; then
            log_error "LUKS password is too weak"
            return 1
        fi
    done
    
    return 0
}
