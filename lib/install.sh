#!/bin/bash
#
# Base installation and system configuration with improvements
#

# Install base system
install_base() {
    log_info "Starting base installation..."
    
    # Install reflector if not present
    install_reflector
    
    # Select mirror
    select_mirror || return 1
    
    # Install base packages with progress
    dialog_safe --infobox "Installing base packages...\n\nThis may take 5-15 minutes depending on your internet speed." 6 60
    
    local base_packages=("base" "base-devel" "linux" "linux-firmware")
    
    # Add microcode based on CPU
    if grep -q "Intel" /proc/cpuinfo; then
        base_packages+=("intel-ucode")
    elif grep -q "AMD" /proc/cpuinfo; then
        base_packages+=("amd-ucode")
    fi
    
    # Dry run mode
    if [[ "$(get_config '.options.dry_run')" == "true" ]]; then
        log_info "DRY RUN: Would install packages: ${base_packages[*]}"
        sleep 2
    else
        # Install packages
        if ! pacstrap /mnt "${base_packages[@]}"; then
            dialog_safe --msgbox "Error: Failed to install base packages.\n\nCheck your internet connection and try again." 10 60
            return 1
        fi
    fi
    
    log_info "Base packages installed successfully"
    
    # Generate fstab
    dialog_safe --infobox "Generating fstab..." 3 40
    
    if [[ "$(get_config '.options.dry_run')" != "true" ]]; then
        genfstab -U /mnt >> /mnt/etc/fstab
    fi
    
    # Export configuration to chroot
    export_config_to_chroot
    
    # Save state
    save_state "base_install" "complete"
    
    return 0
}

# Install and configure reflector
install_reflector() {
    if ! command -v reflector &>/dev/null; then
        log_info "Installing reflector..."
        pacman -Sy --noconfirm reflector &>/dev/null || true
    fi
}

# Select mirror using reflector
select_mirror() {
    log_info "Selecting mirror with reflector..."
    
    # Ask user for preference
    local mirror_choice
    mirror_choice=$(dialog_safe --clear --title "Mirror Selection" \
        --menu "How would you like to select mirrors?\n\nReflector automatically finds the fastest mirrors." 15 60 3 \
        1 "Auto - Use reflector (recommended)" \
        2 "Manual - Select country/region" \
        3 "Skip - Use default mirrors" \
        3>&1 1>&2 2>&3) || return 0
    
    case $mirror_choice in
        1) use_reflector ;;
        2) select_manual_mirror ;;
        3) log_info "Using default mirrors" ;;
    esac
    
    return 0
}

# Use reflector to find fastest mirrors
use_reflector() {
    if ! command -v reflector &>/dev/null; then
        log_warn "Reflector not available, falling back to manual selection"
        select_manual_mirror
        return
    fi
    
    # Get user's country for better results
    local country
    country=$(curl -s ipinfo.io/country 2>/dev/null || echo "")
    
    local reflector_opts="--age 12 --protocol https --sort rate --save /etc/pacman.d/mirrorlist"
    
    if [[ -n "$country" ]]; then
        dialog_safe --infobox "Finding fastest mirrors in your country ($country)...\n\nThis may take a moment..." 6 60
        reflector_opts="--country '$country' $reflector_opts"
    else
        dialog_safe --infobox "Finding fastest mirrors worldwide...\n\nThis may take a moment..." 5 60
    fi
    
    # Run reflector
    if eval "reflector $reflector_opts" &>/dev/null; then
        log_info "Reflector updated mirrorlist successfully"
    else
        log_warn "Reflector failed, using default mirrors"
        return
    fi
    
    # Copy to installation
    if [[ "$(get_config '.options.dry_run')" != "true" ]]; then
        cp /etc/pacman.d/mirrorlist /mnt/etc/pacman.d/mirrorlist
    fi
    
    # Show results
    local fastest_mirror
    fastest_mirror=$(head -5 /etc/pacman.d/mirrorlist | grep "^#Server" | head -1 | sed 's/#Server = //')
    
    if [[ -n "$fastest_mirror" ]]; then
        dialog_safe --msgbox "✓ Fastest mirror found:\n\n$fastest_mirror\n\nMirrorlist updated successfully!" 10 60
    fi
}

# Manual mirror selection
select_manual_mirror() {
    local region
    region=$(dialog_safe --clear --title "Select Mirror Region" \
        --menu "Choose your region for fastest downloads:" 20 60 15 \
        "Worldwide" "Global CDN" \
        "Australia" "Australia" \
        "Austria" "Austria" \
        "Belgium" "Belgium" \
        "Brazil" "Brazil" \
        "Bulgaria" "Bulgaria" \
        "Canada" "Canada" \
        "Chile" "Chile" \
        "China" "China" \
        "Czechia" "Czechia" \
        "Denmark" "Denmark" \
        "Finland" "Finland" \
        "France" "France" \
        "Germany" "Germany" \
        "Greece" "Greece" \
        "Hungary" "Hungary" \
        "Iceland" "Iceland" \
        "India" "India" \
        "Ireland" "Ireland" \
        "Italy" "Italy" \
        "Japan" "Japan" \
        "Netherlands" "Netherlands" \
        "New Zealand" "New Zealand" \
        "Norway" "Norway" \
        "Poland" "Poland" \
        "Portugal" "Portugal" \
        "Romania" "Romania" \
        "Russia" "Russia" \
        "Singapore" "Singapore" \
        "South Korea" "South Korea" \
        "Spain" "Spain" \
        "Sweden" "Sweden" \
        "Switzerland" "Switzerland" \
        "Taiwan" "Taiwan" \
        "Turkey" "Turkey" \
        "Ukraine" "Ukraine" \
        "United Kingdom" "United Kingdom" \
        "United States" "United States" \
        3>&1 1>&2 2>&3) || return 0
    
    dialog_safe --infobox "Updating mirrorlist for $region..." 3 50
    
    if [[ "$region" == "Worldwide" ]]; then
        curl -s "https://archlinux.org/mirrorlist/all/https/" | sed 's/^#Server/Server/' > /etc/pacman.d/mirrorlist
    else
        # Convert region to URL parameter
        local country_param
        country_param=$(echo "$region" | sed 's/ /%20/g')
        curl -s "https://archlinux.org/mirrorlist/?country=${country_param}&protocol=https&use_mirror_status=on" | \
            sed 's/^#Server/Server/' > /etc/pacman.d/mirrorlist
    fi
    
    # Copy to installation
    cp /etc/pacman.d/mirrorlist /mnt/etc/pacman.d/mirrorlist
    
    log_info "Mirrorlist updated for region: $region"
}

# Configure system
configure_system() {
    log_info "Configuring system..."
    
    # Timezone
    configure_timezone || return 1
    
    # Locale
    configure_locale || return 1
    
    # Keyboard
    configure_keyboard || return 1
    
    # Hostname
    configure_hostname || return 1
    
    # Users
    configure_users || return 1
    
    # Save state
    save_state "system_config" "complete"
    
    return 0
}

# Configure timezone
configure_timezone() {
    log_info "Configuring timezone..."
    
    # Select region
    local region
    region=$(dialog_safe --clear --title "Timezone - Region" \
        --menu "Select your region:" 20 60 15 \
        "Africa" "Africa" \
        "America" "America" \
        "Antarctica" "Antarctica" \
        "Arctic" "Arctic" \
        "Asia" "Asia" \
        "Atlantic" "Atlantic" \
        "Australia" "Australia" \
        "Europe" "Europe" \
        "Indian" "Indian" \
        "Pacific" "Pacific" \
        3>&1 1>&2 2>&3) || return 1
    
    # Select city
    local cities
    cities=$(find /usr/share/zoneinfo/$region -type f | sed 's|/usr/share/zoneinfo/||' | sort)
    
    local menu_items=()
    while IFS= read -r city; do
        if [[ -n "$city" ]]; then
            local city_name=$(basename "$city")
            menu_items+=("$city" "$city_name")
        fi
    done <<< "$cities"
    
    TIMEZONE=$(dialog_safe --clear --title "Timezone - City" \
        --menu "Select your city or nearest timezone:" 25 70 20 \
        "${menu_items[@]}" \
        3>&1 1>&2 2>&3) || return 1
    
    # Set timezone
    if [[ "$(get_config '.options.dry_run')" != "true" ]]; then
        arch-chroot /mnt ln -sf "/usr/share/zoneinfo/$TIMEZONE" /etc/localtime
        arch-chroot /mnt hwclock --systohc
    fi
    
    set_config '.system.timezone' "$TIMEZONE"
    log_info "Timezone set to: $TIMEZONE"
    
    return 0
}

# Configure locale
configure_locale() {
    log_info "Configuring locale..."
    
    LOCALE=$(dialog_safe --clear --title "Locale" \
        --menu "Select your locale:\n(These are the most common)" 20 70 15 \
        "en_US.UTF-8" "English (United States)" \
        "en_GB.UTF-8" "English (United Kingdom)" \
        "en_CA.UTF-8" "English (Canada)" \
        "en_AU.UTF-8" "English (Australia)" \
        "de_DE.UTF-8" "German (Germany)" \
        "fr_FR.UTF-8" "French (France)" \
        "es_ES.UTF-8" "Spanish (Spain)" \
        "it_IT.UTF-8" "Italian (Italy)" \
        "pt_BR.UTF-8" "Portuguese (Brazil)" \
        "pt_PT.UTF-8" "Portuguese (Portugal)" \
        "ru_RU.UTF-8" "Russian (Russia)" \
        "ja_JP.UTF-8" "Japanese (Japan)" \
        "ko_KR.UTF-8" "Korean (South Korea)" \
        "zh_CN.UTF-8" "Chinese (Simplified)" \
        "zh_TW.UTF-8" "Chinese (Traditional)" \
        "ar_SA.UTF-8" "Arabic (Saudi Arabia)" \
        "hi_IN.UTF-8" "Hindi (India)" \
        "pl_PL.UTF-8" "Polish (Poland)" \
        "nl_NL.UTF-8" "Dutch (Netherlands)" \
        "sv_SE.UTF-8" "Swedish (Sweden)" \
        3>&1 1>&2 2>&3) || return 1
    
    if [[ "$(get_config '.options.dry_run')" != "true" ]]; then
        # Generate locale
        sed -i "s/^#$LOCALE/$LOCALE/" /mnt/etc/locale.gen
        arch-chroot /mnt locale-gen
        
        # Set system locale
        echo "LANG=$LOCALE" > /mnt/etc/locale.conf
    fi
    
    set_config '.system.locale' "$LOCALE"
    log_info "Locale set to: $LOCALE"
    
    return 0
}

# Configure keyboard
configure_keyboard() {
    log_info "Configuring keyboard..."
    
    KEYBOARD=$(dialog_safe --clear --title "Keyboard Layout" \
        --menu "Select your keyboard layout:\n(These are the most common)" 25 60 20 \
        "us" "US English" \
        "uk" "UK English" \
        "de" "German" \
        "fr" "French" \
        "es" "Spanish" \
        "it" "Italian" \
        "pt" "Portuguese" \
        "br" "Brazilian (ABNT2)" \
        "ru" "Russian" \
        "jp" "Japanese" \
        "kr" "Korean" \
        "cn" "Chinese" \
        "pl" "Polish" \
        "nl" "Dutch" \
        "se" "Swedish" \
        "no" "Norwegian" \
        "dk" "Danish" \
        "fi" "Finnish" \
        "be" "Belgian" \
        "ch" "Swiss" \
        "at" "Austrian" \
        "cz" "Czech" \
        "hu" "Hungarian" \
        "ro" "Romanian" \
        "tr" "Turkish" \
        "ara" "Arabic" \
        "in" "Indian" \
        "latam" "Latin American" \
        "dvorak" "Dvorak (US)" \
        "colemak" "Colemak (US)" \
        3>&1 1>&2 2>&3) || return 1
    
    if [[ "$(get_config '.options.dry_run')" != "true" ]]; then
        # Set keyboard layout
        echo "KEYMAP=$KEYBOARD" > /mnt/etc/vconsole.conf
        
        # Also set for X11
        mkdir -p /mnt/etc/X11/xorg.conf.d
        cat > /mnt/etc/X11/xorg.conf.d/00-keyboard.conf <<EOF
Section "InputClass"
    Identifier "system-keyboard"
    MatchIsKeyboard "on"
    Option "XkbLayout" "$KEYBOARD"
EndSection
EOF
    fi
    
    set_config '.system.keymap' "$KEYBOARD"
    log_info "Keyboard layout set to: $KEYBOARD"
    
    return 0
}

# Configure hostname
configure_hostname() {
    log_info "Configuring hostname..."
    
    while true; do
        HOSTNAME=$(dialog_safe --clear --title "Hostname" \
            --inputbox "Enter a hostname for your computer:\n(Only letters, numbers, and hyphens)" 10 50 "archpc" \
            3>&1 1>&2 2>&3) || return 1
        
        if ! validate_hostname "$HOSTNAME"; then
            dialog_safe --msgbox "Error: Invalid hostname.\n\n- 1-63 characters\n- Letters, numbers, hyphens only\n- Cannot start/end with hyphen\n- Cannot be all numeric" 12 50
            continue
        fi
        
        break
    done
    
    if [[ "$(get_config '.options.dry_run')" != "true" ]]; then
        # Set hostname
        echo "$HOSTNAME" > /mnt/etc/hostname
        
        # Configure hosts file
        cat > /mnt/etc/hosts <<EOF
127.0.0.1   localhost
::1         localhost
127.0.1.1   $HOSTNAME.localdomain   $HOSTNAME
EOF
    fi
    
    set_config '.system.hostname' "$HOSTNAME"
    log_info "Hostname set to: $HOSTNAME"
    
    return 0
}

# Configure users
configure_users() {
    log_info "Configuring users..."
    
    # Set root password
    dialog_safe --msgbox "You will now set the ROOT password.\n\nThis is the administrator account.\nKeep it secure!" 10 50
    
    while true; do
        local root_pass
        root_pass=$(dialog_safe --clear --title "Root Password" \
            --passwordbox "Enter root password:" 8 50 \
            3>&1 1>&2 2>&3) || return 1
        
        local root_pass_confirm
        root_pass_confirm=$(dialog_safe --clear --title "Confirm Root Password" \
            --passwordbox "Confirm root password:" 8 50 \
            3>&1 1>&2 2>&3) || return 1
        
        if [[ "$root_pass" != "$root_pass_confirm" ]]; then
            dialog_safe --msgbox "Passwords do not match. Please try again." 7 50
            continue
        fi
        
        if ! validate_password "$root_pass" 6; then
            dialog_safe --msgbox "Password is too weak.\n\n- At least 6 characters\n- Not a common password" 9 50
            continue
        fi
        
        if [[ "$(get_config '.options.dry_run')" != "true" ]]; then
            echo "root:$root_pass" | arch-chroot /mnt chpasswd
        fi
        
        log_info "Root password set"
        break
    done
    
    # Create user account
    dialog_safe --msgbox "Now you'll create a regular user account.\n\nThis will be your daily use account." 10 50
    
    while true; do
        USERNAME=$(dialog_safe --clear --title "Create User" \
            --inputbox "Enter username:\n(lowercase letters and numbers only)" 10 50 \
            3>&1 1>&2 2>&3) || return 1
        
        if ! validate_username "$USERNAME"; then
            dialog_safe --msgbox "Error: Invalid username.\n\n- Start with a letter\n- Lowercase letters, numbers, hyphens\n- Not a reserved system name" 11 50
            continue
        fi
        
        if arch-chroot /mnt id "$USERNAME" &>/dev/null; then
            dialog_safe --msgbox "Error: User '$USERNAME' already exists." 7 50
            continue
        fi
        
        break
    done
    
    # Create user
    if [[ "$(get_config '.options.dry_run')" != "true" ]]; then
        arch-chroot /mnt useradd -m -G wheel,audio,video,storage,optical,network -s /bin/bash "$USERNAME"
    fi
    
    # Set user password
    while true; do
        local user_pass
        user_pass=$(dialog_safe --clear --title "User Password" \
            --passwordbox "Enter password for $USERNAME:" 8 50 \
            3>&1 1>&2 2>&3) || return 1
        
        local user_pass_confirm
        user_pass_confirm=$(dialog_safe --clear --title "Confirm Password" \
            --passwordbox "Confirm password for $USERNAME:" 8 50 \
            3>&1 1>&2 2>&3) || return 1
        
        if [[ "$user_pass" != "$user_pass_confirm" ]]; then
            dialog_safe --msgbox "Passwords do not match. Please try again." 7 50
            continue
        fi
        
        if ! validate_password "$user_pass" 6; then
            dialog_safe --msgbox "Password is too weak.\n\n- At least 6 characters\n- Not a common password" 9 50
            continue
        fi
        
        if [[ "$(get_config '.options.dry_run')" != "true" ]]; then
            echo "$USERNAME:$user_pass" | arch-chroot /mnt chpasswd
        fi
        
        log_info "User '$USERNAME' created with password"
        break
    done
    
    # Configure sudo
    if [[ "$(get_config '.options.dry_run')" != "true" ]]; then
        echo "%wheel ALL=(ALL:ALL) ALL" > /mnt/etc/sudoers.d/wheel
        chmod 440 /mnt/etc/sudoers.d/wheel
    fi
    
    set_config '.system.username' "$USERNAME"
    log_info "Sudo configured for wheel group"
    
    return 0
}

# Install bootloader
install_bootloader() {
    log_info "Installing bootloader..."
    
    # Ask for bootloader preference
    local bootloader_choice
    if [[ "$BOOT_MODE" == "UEFI" ]]; then
        bootloader_choice=$(dialog_safe --clear --title "Bootloader Selection" \
            --menu "Choose a bootloader:\n\nFor UEFI systems, systemd-boot is simpler." 12 60 2 \
            "systemd-boot" "systemd-boot - Simple, native to systemd" \
            "grub" "GRUB - More features, dual-boot support" \
            3>&1 1>&2 2>&3) || bootloader_choice="systemd-boot"
    else
        bootloader_choice="grub"
    fi
    
    if [[ "$(get_config '.options.dry_run')" == "true" ]]; then
        log_info "DRY RUN: Would install $bootloader_choice bootloader"
        return 0
    fi
    
    case $bootloader_choice in
        "systemd-boot")
            install_systemd_boot
            ;;
        "grub")
            if [[ "$BOOT_MODE" == "UEFI" ]]; then
                install_grub_uefi
            else
                install_grub_bios
            fi
            ;;
    esac
    
    # Configure encryption in bootloader if enabled
    if [[ "$(get_config '.disk.encrypt')" == "true" ]]; then
        configure_bootloader_encryption "$bootloader_choice"
    fi
    
    # Save state
    save_state "bootloader" "complete"
    
    return 0
}

# Install systemd-boot
install_systemd_boot() {
    log_info "Installing systemd-boot..."
    
    dialog_safe --infobox "Installing systemd-boot..." 3 40
    
    # Install systemd-boot
    arch-chroot /mnt bootctl install
    
    # Get root partition UUID
    local root_uuid
    root_uuid=$(findmnt -n -o UUID /mnt)
    
    # Detect microcode
    local ucode=""
    if [[ -f /mnt/boot/intel-ucode.img ]]; then
        ucode="initrd /intel-ucode.img"
    elif [[ -f /mnt/boot/amd-ucode.img ]]; then
        ucode="initrd /amd-ucode.img"
    fi
    
    # Create bootloader entry
    cat > /mnt/boot/loader/entries/arch.conf <<EOF
title   Arch Linux
linux   /vmlinuz-linux
$ucode
initrd  /initramfs-linux.img
options root=UUID=$root_uuid rw quiet
EOF
    
    # Set default bootloader
    cat > /mnt/boot/loader/loader.conf <<EOF
default arch
timeout 3
console-mode max
EOF
    
    set_config '.bootloader.type' 'systemd-boot'
    log_info "systemd-boot installed"
    
    return 0
}

# Install GRUB for UEFI
install_grub_uefi() {
    log_info "Installing GRUB for UEFI..."
    
    dialog_safe --infobox "Installing GRUB for UEFI..." 3 40
    
    arch-chroot /mnt pacman -S --noconfirm grub efibootmgr
    arch-chroot /mnt grub-install --target=x86_64-efi --efi-directory=/boot --bootloader-id=GRUB
    arch-chroot /mnt grub-mkconfig -o /boot/grub/grub.cfg
    
    set_config '.bootloader.type' 'grub'
    log_info "GRUB (UEFI) installed"
    
    return 0
}

# Install GRUB for BIOS
install_grub_bios() {
    log_info "Installing GRUB for BIOS..."
    
    dialog_safe --infobox "Installing GRUB for BIOS..." 3 40
    
    arch-chroot /mnt pacman -S --noconfirm grub
    arch-chroot /mnt grub-install --target=i386-pc "$INSTALL_DISK"
    arch-chroot /mnt grub-mkconfig -o /boot/grub/grub.cfg
    
    set_config '.bootloader.type' 'grub'
    log_info "GRUB (BIOS) installed on $INSTALL_DISK"
    
    return 0
}

# Post-installation
post_installation() {
    log_info "Running post-installation tasks..."
    
    if [[ "$(get_config '.options.dry_run')" == "true" ]]; then
        log_info "DRY RUN: Would configure post-installation settings"
        sleep 1
    else
        dialog_safe --infobox "Configuring system services..." 3 40
        
        # Enable essential services
        arch-chroot /mnt systemctl enable NetworkManager
        arch-chroot /mnt systemctl enable bluetooth
        
        # Configure pacman
        sed -i 's/^#Color/Color/' /mnt/etc/pacman.conf
        sed -i 's/^#ParallelDownloads/ParallelDownloads/' /mnt/etc/pacman.conf
        sed -i 's/^#VerbosePkgLists/VerbosePkgLists/' /mnt/etc/pacman.conf
        
        # Install and configure firewall
        arch-chroot /mnt pacman -S --noconfirm ufw
        arch-chroot /mnt systemctl enable ufw
        
        # Install essential utilities
        arch-chroot /mnt pacman -S --noconfirm \
            vim nano \
            man-db man-pages texinfo \
            bash-completion \
            git \
            wget curl \
            htop \
            neofetch \
            networkmanager \
            bluez \
            bluez-utils \
            pipewire \
            pipewire-pulse \
            pipewire-alsa \
            wireplumber
        
        # Create reflector service for automatic mirror updates
        if command -v reflector &>/dev/null; then
            arch-chroot /mnt pacman -S --noconfirm reflector
            
            # Create systemd service for weekly mirror updates
            cat > /mnt/etc/systemd/system/reflector.service <<EOF
[Unit]
Description=Refresh Pacman mirrorlist with Reflector
After=network-online.target
Wants=network-online.target

[Service]
Type=oneshot
ExecStart=/usr/bin/reflector --latest 20 --protocol https --sort rate --save /etc/pacman.d/mirrorlist
EOF
            
            cat > /mnt/etc/systemd/system/reflector.timer <<EOF
[Unit]
Description=Run reflector weekly

[Timer]
OnCalendar=weekly
Persistent=true

[Install]
WantedBy=timers.target
EOF
            
            arch-chroot /mnt systemctl enable reflector.timer
        fi
        
        # Install AUR helper if requested
        if [[ "$(get_config '.packages.aur_helper')" == "true" ]]; then
            source "$LIB_DIR/aur.sh"
            install_aur_helper
        fi
    fi
    
    # Save state
    save_state "post_install" "complete"
    
    log_info "Post-installation complete"
    
    return 0
}
