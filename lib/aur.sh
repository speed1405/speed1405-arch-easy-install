#!/bin/bash
#
# AUR helper installation and management
#

# Install yay AUR helper
install_aur_helper() {
    if ! dialog --yesno "Would you like to install an AUR helper (yay)?\n\nThe AUR (Arch User Repository) contains community packages.\nyay makes it easy to install software from the AUR.\n\nRecommended for most users." 12 60; then
        return 0
    fi
    
    log_info "Installing yay AUR helper..."
    
    dialog --infobox "Installing yay AUR helper...\n\nThis will compile yay from source." 6 60
    
    # Install dependencies
    arch-chroot /mnt pacman -S --noconfirm --needed base-devel git
    
    # Create temporary build user
    arch-chroot /mnt useradd -m -G wheel -s /bin/bash aurbuilder
    
    # Clone and build yay
    cat > /mnt/tmp/install-yay.sh <<'EOF'
#!/bin/bash
cd /tmp
git clone https://aur.archlinux.org/yay.git
cd yay
makepkg -si --noconfirm
EOF
    chmod +x /mnt/tmp/install-yay.sh
    
    # Run as aurbuilder user
    arch-chroot /mnt su - aurbuilder -c "bash /tmp/install-yay.sh"
    
    # Remove build user
    arch-chroot /mnt userdel -r aurbuilder 2>/dev/null || true
    
    # Configure yay for all users
    mkdir -p /mnt/etc/skel/.config/yay
    cat > /mnt/etc/skel/.config/yay/config.json <<'EOF'
{
    "aururl": "https://aur.archlinux.org",
    "buildDir": "$HOME/.cache/yay",
    "editor": "",
    "editorflags": "",
    "makepkgbin": "makepkg",
    "makepkgconf": "",
    "pacmanbin": "pacman",
    "pacmanconf": "/etc/pacman.conf",
    "redownload": "no",
    "rebuild": "no",
    "answerclean": "",
    "answerdiff": "",
    "answeredit": "",
    "answerupgrade": "",
    "gitbin": "git",
    "gpgbin": "gpg",
    "gpgflags": "",
    "mflags": "",
    "sortby": "votes",
    "searchby": "name-desc",
    "gitflags": "",
    "removemake": "ask",
    "sudobin": "sudo",
    "sudoflags": "",
    "requestsplitn": 150,
    "completionrefreshtime": 7,
    "maxconcurrentdownloads": 0,
    "bottomup": true,
    "sudoloop": false,
    "timeupdate": false,
    "devel": false,
    "cleanAfter": false,
    "provides": true,
    "pgpfetch": true,
    "upgrademenu": true,
    "cleanmenu": true,
    "diffmenu": true,
    "editmenu": false,
    "combinedupgrade": false,
    "useask": false,
    "batchinstall": false,
    "singlelineresults": false,
    "separatesources": true,
    "newinstallengine": false,
    "debug": false,
    "rpc": true,
    "doubleconfirm": true,
    "rebuildtree": false
}
EOF
    
    # Copy to existing user
    if [[ -n "$USERNAME" ]]; then
        mkdir -p "/mnt/home/$USERNAME/.config/yay"
        cp /mnt/etc/skel/.config/yay/config.json "/mnt/home/$USERNAME/.config/yay/"
        arch-chroot /mnt chown -R "$USERNAME:$USERNAME" "/home/$USERNAME/.config"
    fi
    
    log_info "yay AUR helper installed successfully"
    
    dialog --msgbox "✓ yay AUR helper installed successfully!\n\nYou can now install AUR packages with:\nyay -S package-name" 10 60
    
    return 0
}

# Install paru as alternative AUR helper
install_paru() {
    log_info "Installing paru AUR helper..."
    
    dialog --infobox "Installing paru AUR helper..." 3 40
    
    # Install dependencies
    arch-chroot /mnt pacman -S --noconfirm --needed base-devel git
    
    # Create temporary build user
    arch-chroot /mnt useradd -m -G wheel -s /bin/bash aurbuilder
    
    # Clone and build paru
    cat > /mnt/tmp/install-paru.sh <<'EOF'
#!/bin/bash
cd /tmp
git clone https://aur.archlinux.org/paru.git
cd paru
makepkg -si --noconfirm
EOF
    chmod +x /mnt/tmp/install-paru.sh
    
    arch-chroot /mnt su - aurbuilder -c "bash /tmp/install-paru.sh"
    
    # Remove build user
    arch-chroot /mnt userdel -r aurbuilder 2>/dev/null || true
    
    log_info "paru AUR helper installed successfully"
}

# Install AUR packages during installation
install_aur_packages() {
    if ! command -v yay &>/dev/null && ! command -v paru &>/dev/null; then
        log_warn "No AUR helper installed, skipping AUR packages"
        return 0
    fi
    
    local aur_packages=("$@")
    
    if [[ ${#aur_packages[@]} -eq 0 ]]; then
        return 0
    fi
    
    log_info "Installing AUR packages: ${aur_packages[*]}"
    
    dialog --infobox "Installing AUR packages...\n\nThis may take a while." 5 60
    
    local helper="yay"
    if ! command -v yay &>/dev/null; then
        helper="paru"
    fi
    
    for pkg in "${aur_packages[@]}"; do
        arch-chroot /mnt su - "$USERNAME" -c "$helper -S --noconfirm $pkg" || \
            log_warn "Failed to install AUR package: $pkg"
    done
}

# Offer to install popular AUR packages
offer_popular_aur_packages() {
    local packages_selected=()
    
    local choices
    choices=$(dialog --clear --title "Popular AUR Packages" \
        --checklist "Select packages to install:\n\nUse SPACE to select, ENTER to confirm" 20 70 15 \
        "google-chrome" "Google Chrome browser" off \
        "visual-studio-code-bin" "VS Code editor" off \
        "spotify" "Spotify music client" off \
        "discord" "Discord chat app" off \
        "slack-desktop" "Slack messaging" off \
        "zoom" "Zoom video conferencing" off \
        "brave-bin" "Brave browser" off \
        "opera" "Opera browser" off \
        "skypeforlinux-stable-bin" "Skype" off \
        "teamviewer" "TeamViewer remote desktop" off \
        "dropbox" "Dropbox cloud storage" off \
        "insync" "Google Drive sync" off \
        "megasync" "MEGA cloud storage" off \
        "protonvpn-cli" "ProtonVPN client" off \
        "windscribe-cli" "Windscribe VPN" off \
        "timeshift" "System backup tool" off \
        "timeshift-autosnap" "Auto snapshots with updates" off \
        "auto-cpufreq" "Battery optimization" off \
        "tlpui" "TLP battery GUI" off \
        "pamac-aur" "Graphical package manager" off \
        3>&1 1>&2 2>&3) || return 0
    
    # Parse selected packages
    packages_selected=($choices)
    
    if [[ ${#packages_selected[@]} -gt 0 ]]; then
        install_aur_packages "${packages_selected[@]}"
    fi
}
