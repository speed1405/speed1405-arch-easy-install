#!/bin/bash
#
# Disk encryption support (LUKS)
#

LUKS_PREFIX="crypt"

# Check if encryption is available
encryption_available() {
    if command -v cryptsetup &>/dev/null; then
        return 0
    fi
    return 1
}

# Install encryption tools
install_encryption_tools() {
    if ! encryption_available; then
        dialog_safe --infobox "Installing encryption tools..." 3 40
        pacman -Sy --noconfirm cryptsetup lvm2 &>/dev/null || true
    fi
}

# Ask user if they want encryption
ask_encryption() {
    if ! encryption_available; then
        install_encryption_tools
    fi
    
    if dialog_safe --yesno "Would you like to encrypt your disk?\n\nEncryption protects your data if your device is lost or stolen.\n\n⚠ You will need to enter a password at every boot.\n⚠ Forgetting the password means losing all data!" 12 60; then
        set_config '.disk.encrypt' 'true'
        return 0
    else
        set_config '.disk.encrypt' 'false'
        return 1
    fi
}

# Setup LUKS encryption on a partition
setup_luks() {
    local partition=$1
    local name=$2
    
    log_info "Setting up LUKS encryption on $partition (name: $name)"
    
    # Get password from user
    local password
    local password_confirm
    
    while true; do
        password=$(dialog_safe --clear --title "LUKS Encryption Password" \
            --passwordbox "Enter encryption password for $name:\n\n(8+ characters, don't forget this!)" 10 50 \
            3>&1 1>&2 2>&3) || return 1
        
        password_confirm=$(dialog_safe --clear --title "Confirm Password" \
            --passwordbox "Confirm encryption password:" 8 50 \
            3>&1 1>&2 2>&3) || return 1
        
        if [[ "$password" != "$password_confirm" ]]; then
            dialog_safe --msgbox "Passwords do not match. Please try again." 7 50
            continue
        fi
        
        if ! validate_luks_password "$password"; then
            dialog_safe --msgbox "Password is too weak.\n\nRequirements:\n- At least 8 characters\n- Not a common password" 10 50
            continue
        fi
        
        break
    done
    
    # Wipe the partition (optional but recommended for security)
    if dialog_safe --yesno "Would you like to securely wipe the partition before encryption?\n\nThis makes it harder to recover old data but takes time." 10 60; then
        dialog_safe --infobox "Wiping partition (this may take a while)..." 3 50
        cryptsetup open --type plain "$partition" container --key-file /dev/urandom
        dd if=/dev/zero of=/dev/mapper/container status=progress bs=1M || true
        cryptsetup close container
    fi
    
    # Setup LUKS
    dialog_safe --infobox "Creating encrypted container..." 3 40
    
    # Use LUKS2 with argon2id for better security
    echo "$password" | cryptsetup luksFormat --type luks2 \
        --cipher aes-xts-plain64 \
        --key-size 512 \
        --pbkdf argon2id \
        --pbkdf-force-iterations 4 \
        "$partition" -
    
    # Open the encrypted container
    echo "$password" | cryptsetup open "$partition" "$LUKS_PREFIX$name" -
    
    log_info "LUKS encryption setup complete for $name"
    
    # Return the mapped device path
    echo "/dev/mapper/$LUKS_PREFIX$name"
}

# Setup encrypted root partition
setup_encrypted_root() {
    local root_partition=$1
    local filesystem=$2
    
    log_info "Setting up encrypted root partition"
    
    # Create LUKS container
    local mapped_device
    mapped_device=$(setup_luks "$root_partition" "root")
    
    if [[ -z "$mapped_device" ]]; then
        log_error "Failed to setup encrypted root"
        return 1
    fi
    
    # Format the encrypted device
    dialog_safe --infobox "Formatting encrypted root partition..." 3 40
    mkfs.$filesystem -F "$mapped_device"
    
    # Mount it
    mount "$mapped_device" /mnt
    
    # Save the LUKS UUID for crypttab
    local luks_uuid
    luks_uuid=$(cryptsetup luksUUID "$root_partition")
    set_config '.security.luks_uuid_root' "$luks_uuid"
    
    log_info "Encrypted root setup complete"
    return 0
}

# Setup encrypted home partition
setup_encrypted_home() {
    local home_partition=$1
    local filesystem=$2
    
    log_info "Setting up encrypted home partition"
    
    # Create LUKS container
    local mapped_device
    mapped_device=$(setup_luks "$home_partition" "home")
    
    if [[ -z "$mapped_device" ]]; then
        log_error "Failed to setup encrypted home"
        return 1
    fi
    
    # Format and mount
    dialog_safe --infobox "Formatting encrypted home partition..." 3 40
    mkfs.$filesystem -F "$mapped_device"
    
    mkdir -p /mnt/home
    mount "$mapped_device" /mnt/home
    
    log_info "Encrypted home setup complete"
    return 0
}

# Setup swap encryption (optional, recommended for security)
setup_encrypted_swap() {
    local swap_size=$1
    
    log_info "Setting up encrypted swap"
    
    # For encrypted swap, we use a random key each boot
    # This is secure and doesn't require a password
    
    # Create swap file instead of partition for encryption
    local swapfile="/swapfile"
    
    dialog_safe --infobox "Creating encrypted swap file..." 3 40
    
    # Create swap file
    dd if=/dev/zero of=/mnt$swapfile bs=1M count=$swap_size status=progress
    chmod 600 /mnt$swapfile
    mkswap /mnt$swapfile
    swapon /mnt$swapfile
    
    # Add to fstab
    echo "$swapfile none swap defaults 0 0" >> /mnt/etc/fstab
    
    log_info "Encrypted swap setup complete"
    return 0
}

# Configure mkinitcpio for encryption
configure_mkinitcpio_encryption() {
    log_info "Configuring mkinitcpio for encryption"
    
    # Add encryption hooks to mkinitcpio.conf
    local hooks="base udev autodetect keyboard keymap consolefont modconf block encrypt filesystems fsck"
    
    sed -i "s/^HOOKS=.*/HOOKS=($hooks)/" /mnt/etc/mkinitcpio.conf
    
    # Regenerate initramfs
    arch-chroot /mnt mkinitcpio -P
    
    log_info "mkinitcpio configured for encryption"
}

# Create crypttab for encrypted partitions
create_crypttab() {
    log_info "Creating crypttab"
    
    local crypttab=""
    
    # Root partition (if encrypted)
    if [[ "$(get_config '.disk.encrypt')" == "true" ]]; then
        local root_uuid
        root_uuid=$(get_config '.security.luks_uuid_root')
        if [[ -n "$root_uuid" ]]; then
            crypttab+="cryptroot UUID=$root_uuid none luks\n"
        fi
    fi
    
    # Write crypttab
    echo -e "$crypttab" > /mnt/etc/crypttab
    
    log_info "crypttab created"
}

# Configure bootloader for encryption
configure_bootloader_encryption() {
    local bootloader=$1
    
    log_info "Configuring $bootloader for encryption"
    
    # Get encrypted partition UUID
    local root_uuid
    root_uuid=$(get_config '.security.luks_uuid_root')
    
    case $bootloader in
        "systemd-boot")
            # Update systemd-boot entry
            local entry_file="/mnt/boot/loader/entries/arch.conf"
            if [[ -f "$entry_file" ]]; then
                # Add cryptdevice parameter
                sed -i "s/options root=/options cryptdevice=UUID=$root_uuid:cryptroot root=/" "$entry_file"
            fi
            ;;
        "grub")
            # Update GRUB config
            local grub_cmdline="cryptdevice=UUID=$root_uuid:cryptroot"
            sed -i "s/GRUB_CMDLINE_LINUX_DEFAULT=\"/GRUB_CMDLINE_LINUX_DEFAULT=\"$grub_cmdline /" /mnt/etc/default/grub
            
            # Enable cryptodisk support in GRUB
            sed -i 's/^#GRUB_ENABLE_CRYPTODISK/GRUB_ENABLE_CRYPTODISK/' /mnt/etc/default/grub
            
            # Regenerate GRUB config
            arch-chroot /mnt grub-mkconfig -o /boot/grub/grub.cfg
            ;;
    esac
    
    log_info "Bootloader configured for encryption"
}

# Close encrypted containers
cleanup_encryption() {
    log_info "Cleaning up encrypted containers"
    
    # Close all LUKS containers
    for mapped in /dev/mapper/$LUKS_PREFIX*; do
        if [[ -b "$mapped" ]]; then
            cryptsetup close "$mapped" 2>/dev/null || true
        fi
    done
    
    log_info "Encryption cleanup complete"
}
