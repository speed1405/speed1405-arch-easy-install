#!/bin/bash
#
# Disk partitioning functions with validation and encryption support
#

# Partition disk
partition_disk() {
    log_info "Starting disk partitioning..."
    
    # Select disk
    select_disk || return 1
    
    # Validate disk
    if ! validate_disk "$INSTALL_DISK"; then
        log_error "Disk validation failed for $INSTALL_DISK"
        return 1
    fi
    
    # Check disk health
    check_disk_health "$INSTALL_DISK"
    
    # Check for existing installations
    if ! check_existing_installations "$INSTALL_DISK"; then
        return 1
    fi
    
    # Check disk space
    if ! check_disk_space_available "$INSTALL_DISK" 20480; then
        dialog_safe --msgbox "Insufficient disk space.\n\nMinimum 20GB required." 8 50
        return 1
    fi
    
    # Select partitioning method
    select_partitioning_method || return 1
    
    # Save state
    save_state "disk_partitioning" "complete"
    
    return 0
}

# Select disk to install to
select_disk() {
    local disks
    local menu_items=()
    
    # Build menu from available disks
    while IFS= read -r line; do
        if [[ -n "$line" ]]; then
            local device=$(echo "$line" | awk '{print $1}')
            local desc=$(echo "$line" | cut -d' ' -f2-)
            menu_items+=("$device" "$desc")
        fi
    done < <(get_available_disks)
    
    if [[ ${#menu_items[@]} -eq 0 ]]; then
        dialog_safe --msgbox "Error: No suitable disks found." 8 40
        return 1
    fi
    
    INSTALL_DISK=$(dialog_safe --clear --title "Select Disk" \
        --menu "Choose the disk to install Arch Linux on:\n\nWARNING: All data will be erased!" 20 70 10 \
        "${menu_items[@]}" \
        3>&1 1>&2 2>&3)
    
    if [[ -z "$INSTALL_DISK" ]]; then
        return 1
    fi
    
    # Validate disk selection
    if ! validate_disk "$INSTALL_DISK"; then
        return 1
    fi
    
    log_info "Selected disk: $INSTALL_DISK"
    set_config '.disk.device' "$INSTALL_DISK"
    
    # Show disk info
    local disk_size
    disk_size=$(lsblk -d -n -o SIZE "$INSTALL_DISK")
    
    # Final confirmation
    if ! dialog_safe --yesno "You have selected:\n\nDevice: $INSTALL_DISK\nSize: $disk_size\n\n⚠ WARNING: This will ERASE ALL DATA on this disk!\n\nAre you absolutely sure you want to continue?" 12 60; then
        INSTALL_DISK=""
        return 1
    fi
    
    return 0
}

# Select partitioning method
select_partitioning_method() {
    local method
    method=$(dialog_safe --clear --title "Partitioning Method" \
        --menu "Choose how to partition the disk:" 15 60 3 \
        1 "Automatic - Erase entire disk (Recommended)" \
        2 "Manual - Use cfdisk (Advanced)" \
        3 "Cancel - Go back" \
        3>&1 1>&2 2>&3)
    
    case $method in
        1) 
            set_config '.disk.partitioning' 'automatic'
            automatic_partitioning 
            ;;
        2) 
            set_config '.disk.partitioning' 'manual'
            manual_partitioning 
            ;;
        *) return 1 ;;
    esac
}

# Automatic partitioning
automatic_partitioning() {
    log_info "Using automatic partitioning..."
    
    # Get configuration from user
    local swap_size
    local separate_home
    local filesystem
    local encrypt
    
    # Swap size with validation
    while true; do
        swap_size=$(dialog_safe --clear --title "Swap Size" \
            --inputbox "Enter swap size in MB:\n(Recommended: 2048-8192 MB for systems with 4-16GB RAM)\n\nUse 0 to disable swap." 12 50 "2048" \
            3>&1 1>&2 2>&3) || return 1
        
        # Validate swap size
        if validate_integer "$swap_size" 0 131072 "Swap size"; then
            break
        else
            dialog_safe --msgbox "Invalid swap size. Please enter a number between 0 and 131072 (128GB)." 8 60
        fi
    done
    
    set_config '.disk.swap_size' "$swap_size"
    
    # Separate /home partition
    if dialog_safe --yesno "Create a separate /home partition?\n\nYes: Better for system reinstallation, keeps user data separate\nNo: All space goes to root (/), simpler setup" 11 65; then
        separate_home="yes"
        set_config '.disk.separate_home' 'true'
    else
        separate_home="no"
        set_config '.disk.separate_home' 'false'
    fi
    
    # Filesystem
    filesystem=$(dialog_safe --clear --title "Filesystem" \
        --menu "Choose a filesystem:\n\nRecommendation: ext4 for beginners, btrfs for advanced users" 13 65 3 \
        "ext4" "ext4 - Reliable, well-tested (Recommended)" \
        "btrfs" "btrfs - Modern, snapshots, compression" \
        "xfs" "xfs - High performance for large files" \
        3>&1 1>&2 2>&3) || return 1
    
    if ! validate_filesystem "$filesystem"; then
        return 1
    fi
    
    set_config '.disk.filesystem' "$filesystem"
    
    # Check if encryption is enabled
    encrypt=$(get_config '.disk.encrypt')
    
    # Calculate partition sizes
    local disk_size_bytes
    disk_size_bytes=$(blockdev --getsize64 "$INSTALL_DISK")
    local disk_size_gb=$((disk_size_bytes / 1024 / 1024 / 1024))
    
    # Show summary
    local summary="Partition Layout Summary:\n\n"
    summary+="Disk: $INSTALL_DISK ($disk_size_gb GB)\n"
    
    if [[ "$BOOT_MODE" == "UEFI" ]]; then
        summary+="Boot: 512 MB (FAT32 - EFI System Partition)\n"
    else
        summary+"Boot: 1 MB (BIOS boot partition)\n"
    fi
    
    if [[ "$swap_size" -gt 0 ]]; then
        summary+="Swap: $swap_size MB\n"
    fi
    
    if [[ "$encrypt" == "true" ]]; then
        summary+="🔒 Encryption: ENABLED (LUKS2)\n"
    fi
    
    if [[ "$separate_home" == "yes" ]]; then
        local root_size=$((disk_size_gb / 4))
        [[ $root_size -lt 30 ]] && root_size=30
        summary+="Root ( / ): ${root_size} GB ($filesystem)\n"
        summary+"Home ( /home ): Remaining space ($filesystem)\n"
    else
        summary+"Root ( / ): Remaining space ($filesystem)\n"
    fi
    
    summary+="\n⚠ This will DESTROY ALL DATA on $INSTALL_DISK!"
    summary+="\n\nProceed with this layout?"
    
    if ! dialog_safe --yesno "$summary" 18 65; then
        return 1
    fi
    
    # Final confirmation for destructive operation
    if ! confirm_dangerous_operation "You are about to format and partition $INSTALL_DISK. This CANNOT be undone." "DESTROY"; then
        return 1
    fi
    
    # Apply partitioning
    if [[ "$(get_config '.options.dry_run')" == "true" ]]; then
        log_info "DRY RUN: Would create partitions on $INSTALL_DISK"
        sleep 2
        return 0
    fi
    
    apply_automatic_partitioning "$swap_size" "$separate_home" "$filesystem"
}

# Apply automatic partitioning
apply_automatic_partitioning() {
    local swap_size=$1
    local separate_home=$2
    local filesystem=$3
    local encrypt=$(get_config '.disk.encrypt')
    
    log_info "Applying automatic partitioning to $INSTALL_DISK"
    
    dialog_safe --infobox "Creating partitions..." 3 40
    
    # Unmount if mounted
    swapoff -a 2>/dev/null || true
    umount -R /mnt 2>/dev/null || true
    
    # Wipe disk
    dialog_safe --infobox "Wiping disk signatures..." 3 40
    wipefs -af "$INSTALL_DISK" &>/dev/null
    sgdisk -Zo "$INSTALL_DISK" &>/dev/null || true
    
    # Create partitions based on boot mode
    if [[ "$BOOT_MODE" == "UEFI" ]]; then
        if [[ "$encrypt" == "true" ]]; then
            create_encrypted_efi_partitions "$swap_size" "$separate_home" "$filesystem"
        else
            create_efi_partitions "$swap_size" "$separate_home" "$filesystem"
        fi
    else
        if [[ "$encrypt" == "true" ]]; then
            create_encrypted_bios_partitions "$swap_size" "$separate_home" "$filesystem"
        else
            create_bios_partitions "$swap_size" "$separate_home" "$filesystem"
        fi
    fi
    
    dialog_safe --msgbox "Partitions created successfully!" 6 40
    
    return 0
}

# Create encrypted partitions for UEFI
create_encrypted_efi_partitions() {
    local swap_size=$1
    local separate_home=$2
    local filesystem=$3
    
    log_info "Creating encrypted UEFI partitions"
    
    # Create GPT partition table
    parted -s "$INSTALL_DISK" mklabel gpt
    
    # EFI partition (512MB) - NOT encrypted
    parted -s "$INSTALL_DISK" mkpart primary fat32 1MiB 513MiB
    parted -s "$INSTALL_DISK" set 1 esp on
    mkfs.fat -F32 "${INSTALL_DISK}1"
    
    if [[ "$separate_home" == "yes" ]]; then
        # Root partition
        local disk_size_mb
        disk_size_mb=$(blockdev --getsize64 "$INSTALL_DISK" | awk '{print int($1/1024/1024)}')
        local root_size_mb=$((disk_size_mb / 4))
        [[ $root_size_mb -lt 30720 ]] && root_size_mb=30720
        local root_end=$((513 + root_size_mb))
        
        parted -s "$INSTALL_DISK" mkpart primary "${filesystem}" 513MiB "${root_end}MiB"
        
        # Home partition (rest)
        parted -s "$INSTALL_DISK" mkpart primary "${filesystem}" "${root_end}MiB" 100%
        
        # Encrypt and setup root
        setup_encrypted_root "${INSTALL_DISK}2" "$filesystem"
        
        # Encrypt and setup home
        setup_encrypted_home "${INSTALL_DISK}3" "$filesystem"
        
        # Mount boot
        mkdir -p /mnt/boot
        mount "${INSTALL_DISK}1" /mnt/boot
        
        # Setup encrypted swap file
        if [[ "$swap_size" -gt 0 ]]; then
            setup_encrypted_swap "$swap_size"
        fi
    else
        # Single root partition with encryption
        parted -s "$INSTALL_DISK" mkpart primary "${filesystem}" 513MiB 100%
        
        # Encrypt and setup root
        setup_encrypted_root "${INSTALL_DISK}2" "$filesystem"
        
        # Mount boot
        mkdir -p /mnt/boot
        mount "${INSTALL_DISK}1" /mnt/boot
        
        # Setup encrypted swap file
        if [[ "$swap_size" -gt 0 ]]; then
            setup_encrypted_swap "$swap_size"
        fi
    fi
}

# Create encrypted partitions for BIOS
create_encrypted_bios_partitions() {
    local swap_size=$1
    local separate_home=$2
    local filesystem=$3
    
    log_info "Creating encrypted BIOS partitions"
    
    # Create MBR partition table
    parted -s "$INSTALL_DISK" mklabel msdos
    
    # Boot partition (1MB, for BIOS boot) - NOT encrypted
    parted -s "$INSTALL_DISK" mkpart primary 1MiB 2MiB
    parted -s "$INSTALL_DISK" set 1 bios_grub on
    
    if [[ "$separate_home" == "yes" ]]; then
        # Root partition
        local disk_size_mb
        disk_size_mb=$(blockdev --getsize64 "$INSTALL_DISK" | awk '{print int($1/1024/1024)}')
        local root_size_mb=$((disk_size_mb / 4))
        [[ $root_size_mb -lt 30720 ]] && root_size_mb=30720
        local root_end=$((2 + root_size_mb))
        
        parted -s "$INSTALL_DISK" mkpart primary "${filesystem}" 2MiB "${root_end}MiB"
        
        # Home partition
        parted -s "$INSTALL_DISK" mkpart primary "${filesystem}" "${root_end}MiB" 100%
        
        # Encrypt and setup root
        setup_encrypted_root "${INSTALL_DISK}2" "$filesystem"
        
        # Encrypt and setup home
        setup_encrypted_home "${INSTALL_DISK}3" "$filesystem"
        
        # Setup encrypted swap file
        if [[ "$swap_size" -gt 0 ]]; then
            setup_encrypted_swap "$swap_size"
        fi
    else
        # Single root partition
        parted -s "$INSTALL_DISK" mkpart primary "${filesystem}" 2MiB 100%
        
        # Encrypt and setup root
        setup_encrypted_root "${INSTALL_DISK}2" "$filesystem"
        
        # Setup encrypted swap file
        if [[ "$swap_size" -gt 0 ]]; then
            setup_encrypted_swap "$swap_size"
        fi
    fi
}

# Create partitions for UEFI (non-encrypted)
create_efi_partitions() {
    local swap_size=$1
    local separate_home=$2
    local filesystem=$3
    
    log_info "Creating UEFI partitions"
    
    local disk_name
    disk_name=$(basename "$INSTALL_DISK")
    
    # Create GPT partition table
    parted -s "$INSTALL_DISK" mklabel gpt
    
    # EFI partition (512MB)
    parted -s "$INSTALL_DISK" mkpart primary fat32 1MiB 513MiB
    parted -s "$INSTALL_DISK" set 1 esp on
    mkfs.fat -F32 "${INSTALL_DISK}1"
    
    if [[ "$swap_size" -gt 0 ]]; then
        # Swap partition
        local swap_end=$((513 + swap_size))
        parted -s "$INSTALL_DISK" mkpart primary linux-swap 513MiB "${swap_end}MiB"
        mkswap "${INSTALL_DISK}2"
        swapon "${INSTALL_DISK}2"
    else
        local swap_end=513
    fi
    
    if [[ "$separate_home" == "yes" ]]; then
        # Root partition (30GB or 1/4 of disk)
        local disk_size_mb
        disk_size_mb=$(blockdev --getsize64 "$INSTALL_DISK" | awk '{print int($1/1024/1024)}')
        local root_size_mb=$((disk_size_mb / 4))
        [[ $root_size_mb -lt 30720 ]] && root_size_mb=30720
        local root_end=$((swap_end + root_size_mb))
        
        parted -s "$INSTALL_DISK" mkpart primary "$filesystem" "${swap_end}MiB" "${root_end}MiB"
        mkfs.$filesystem -F "${INSTALL_DISK}3"
        
        # Home partition (rest)
        parted -s "$INSTALL_DISK" mkpart primary "$filesystem" "${root_end}MiB" 100%
        mkfs.$filesystem -F "${INSTALL_DISK}4"
    else
        # Root partition (rest of disk)
        parted -s "$INSTALL_DISK" mkpart primary "$filesystem" "${swap_end}MiB" 100%
        mkfs.$filesystem -F "${INSTALL_DISK}3"
    fi
    
    # Mount partitions
    mount "${INSTALL_DISK}3" /mnt
    mkdir -p /mnt/boot
    mount "${INSTALL_DISK}1" /mnt/boot
    
    if [[ "$separate_home" == "yes" ]]; then
        mkdir -p /mnt/home
        mount "${INSTALL_DISK}4" /mnt/home
    fi
}

# Create partitions for BIOS (non-encrypted)
create_bios_partitions() {
    local swap_size=$1
    local separate_home=$2
    local filesystem=$3
    
    log_info "Creating BIOS partitions"
    
    # Create MBR partition table
    parted -s "$INSTALL_DISK" mklabel msdos
    
    # Boot partition (1MB, for BIOS boot)
    parted -s "$INSTALL_DISK" mkpart primary 1MiB 2MiB
    parted -s "$INSTALL_DISK" set 1 bios_grub on
    
    if [[ "$swap_size" -gt 0 ]]; then
        # Swap partition
        local swap_end=$((2 + swap_size))
        parted -s "$INSTALL_DISK" mkpart primary linux-swap 2MiB "${swap_end}MiB"
        mkswap "${INSTALL_DISK}2"
        swapon "${INSTALL_DISK}2"
    else
        local swap_end=2
    fi
    
    if [[ "$separate_home" == "yes" ]]; then
        # Root partition
        local disk_size_mb
        disk_size_mb=$(blockdev --getsize64 "$INSTALL_DISK" | awk '{print int($1/1024/1024)}')
        local root_size_mb=$((disk_size_mb / 4))
        [[ $root_size_mb -lt 30720 ]] && root_size_mb=30720
        local root_end=$((swap_end + root_size_mb))
        
        parted -s "$INSTALL_DISK" mkpart primary "$filesystem" "${swap_end}MiB" "${root_end}MiB"
        mkfs.$filesystem -F "${INSTALL_DISK}3"
        
        # Home partition
        parted -s "$INSTALL_DISK" mkpart primary "$filesystem" "${root_end}MiB" 100%
        mkfs.$filesystem -F "${INSTALL_DISK}4"
    else
        # Root partition
        parted -s "$INSTALL_DISK" mkpart primary "$filesystem" "${swap_end}MiB" 100%
        mkfs.$filesystem -F "${INSTALL_DISK}3"
    fi
    
    # Mount root
    mount "${INSTALL_DISK}3" /mnt
    
    if [[ "$separate_home" == "yes" ]]; then
        mkdir -p /mnt/home
        mount "${INSTALL_DISK}4" /mnt/home
    fi
}

# Manual partitioning using cfdisk
manual_partitioning() {
    log_info "Starting manual partitioning with cfdisk..."
    
    dialog_safe --msgbox "Manual Partitioning Instructions:\n\n1. Create partitions using cfdisk\n2. At minimum, create:\n   - Root partition (/)\n   - Boot partition (/boot or ESP for UEFI)\n3. Optional: swap, /home\n4. Write changes and quit\n\nPress OK to launch cfdisk." 15 60
    
    clear
    cfdisk "$INSTALL_DISK"
    
    # Ask user to specify mount points
    dialog_safe --msgbox "Now you need to specify which partitions to use.\n\nPress OK to continue." 8 50
    
    # Get disk name
    local disk_name
    disk_name=$(basename "$INSTALL_DISK")
    
    # Get list of created partitions
    local partitions
    partitions=$(lsblk -n -o NAME "$INSTALL_DISK" | grep -E "^${disk_name}[0-9]+$" || true)
    
    if [[ -z "$partitions" ]]; then
        dialog_safe --msgbox "No partitions found. Please create partitions first." 8 50
        return 1
    fi
    
    # Select root partition
    local root_part
    root_part=$(dialog_safe --clear --title "Select Root Partition" \
        --menu "Choose the partition for root (/):" 20 60 10 \
        $(lsblk -n -o NAME,SIZE "$INSTALL_DISK" | grep -E "^${disk_name}[0-9]+" | awk '{print "/dev/"$1, $2}') \
        3>&1 1>&2 2>&3) || return 1
    
    # Validate root partition
    if ! validate_disk "$root_part"; then
        return 1
    fi
    
    # Select filesystem for root
    local root_fs
    root_fs=$(dialog_safe --clear --title "Root Filesystem" \
        --menu "Choose filesystem for root:" 10 50 3 \
        "ext4" "ext4 - Standard filesystem" \
        "btrfs" "btrfs - Advanced features" \
        "xfs" "xfs - High performance" \
        3>&1 1>&2 2>&3) || return 1
    
    if ! validate_filesystem "$root_fs"; then
        return 1
    fi
    
    # Format and mount root
    dialog_safe --infobox "Formatting root partition..." 3 40
    mkfs.$root_fs -F "$root_part"
    mount "$root_part" /mnt
    
    # Ask for other partitions
    if [[ "$BOOT_MODE" == "UEFI" ]]; then
        local efi_part
        efi_part=$(dialog_safe --clear --title "Select EFI Partition" \
            --menu "Choose the EFI System Partition:" 20 60 10 \
            $(lsblk -n -o NAME,SIZE "$INSTALL_DISK" | grep -E "^${disk_name}[0-9]+" | awk '{print "/dev/"$1, $2}') \
            3>&1 1>&2 2>&3)
        
        if [[ -n "$efi_part" ]]; then
            mkdir -p /mnt/boot
            mkfs.fat -F32 "$efi_part"
            mount "$efi_part" /mnt/boot
        fi
    fi
    
    # Ask for swap
    if dialog_safe --yesno "Do you have a swap partition?" 7 40; then
        local swap_part
        swap_part=$(dialog_safe --clear --title "Select Swap Partition" \
            --menu "Choose the swap partition:" 20 60 10 \
            $(lsblk -n -o NAME,SIZE "$INSTALL_DISK" | grep -E "^${disk_name}[0-9]+" | awk '{print "/dev/"$1, $2}') \
            3>&1 1>&2 2>&3)
        
        if [[ -n "$swap_part" ]]; then
            mkswap "$swap_part"
            swapon "$swap_part"
        fi
    fi
    
    # Ask for home
    if dialog_safe --yesno "Do you have a separate /home partition?" 7 40; then
        local home_part
        home_part=$(dialog_safe --clear --title "Select Home Partition" \
            --menu "Choose the home partition:" 20 60 10 \
            $(lsblk -n -o NAME,SIZE "$INSTALL_DISK" | grep -E "^${disk_name}[0-9]+" | awk '{print "/dev/"$1, $2}') \
            3>&1 1>&2 2>&3)
        
        if [[ -n "$home_part" ]]; then
            local home_fs
            home_fs=$(dialog_safe --clear --title "Home Filesystem" \
                --menu "Choose filesystem for home:" 10 50 3 \
                "ext4" "ext4" \
                "btrfs" "btrfs" \
                "xfs" "xfs" \
                3>&1 1>&2 2>&3) || home_fs="ext4"
            
            if ! validate_filesystem "$home_fs"; then
                home_fs="ext4"
            fi
            
            mkdir -p /mnt/home
            mkfs.$home_fs -F "$home_part"
            mount "$home_part" /mnt/home
        fi
    fi
    
    return 0
}
