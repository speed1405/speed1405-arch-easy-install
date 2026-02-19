#!/bin/bash
#
# Package bundles for common use cases
# Gaming, Productivity, Development, Multimedia, etc.
#

# Available bundles
BUNDLES=(
    "gaming"
    "productivity"
    "development"
    "multimedia"
    "creative"
    "streaming"
    "security"
    "science"
)

# Gaming bundle packages
declare -A BUNDLE_GAMING=(
    [name]="Gaming"
    [description]="Steam, Lutris, Wine, and gaming tools"
    [packages]="steam lutris wine wine-mono wine-gecko gamemode lib32-gamemode discord obs-studio mangohud lib32-mangohud vulkan-icd-loader lib32-vulkan-icd-loader"
    [aur_packages]="protonup-qt heroic-games-launcher-bin"
    [post_install]="configure_gaming"
)

# Productivity bundle packages
declare -A BUNDLE_PRODUCTIVITY=(
    [name]="Productivity"
    [description]="LibreOffice, email clients, note-taking, and office tools"
    [packages]="libreoffice-fresh thunderbird nextcloud-client evolution geary calibre zim cherrytree pdfarranger gnome-calculator"
    [aur_packages]="joplin-appimage notion-app-electron"
    [post_install]="configure_productivity"
)

# Development bundle packages
declare -A BUNDLE_DEVELOPMENT=(
    [name]="Development"
    [description]="IDEs, editors, compilers, and development tools"
    [packages]="code vim nano emacs neovim git lazygit github-cli docker docker-compose python python-pip nodejs npm rust go gcc gdb cmake make"
    [aur_packages]="visual-studio-code-bin jetbrains-toolbox postman-bin insomnia"
    [post_install]="configure_development"
)

# Multimedia bundle packages
declare -A BUNDLE_MULTIMEDIA=(
    [name]="Multimedia"
    [description]="Video editing, audio production, and media playback"
    [packages]="kdenlive shotcut obs-studio audacity ardour lmms vlc mpv ffmpeg handbrake kodi"
    [aur_packages]="davinci-resolve davinci-resolve-studio"
    [post_install]="configure_multimedia"
)

# Creative bundle packages
declare -A BUNDLE_CREATIVE=(
    [name]="Creative"
    [description]="Graphics design, 3D modeling, and digital art"
    [packages]="gimp inkscape krita blender freecad librecad darktable rawtherapee"
    [aur_packages]="figma-linux notion-app-electron"
    [post_install]="configure_creative"
)

# Streaming bundle packages
declare -A BUNDLE_STREAMING=(
    [name]="Streaming"
    [description]="OBS, streaming tools, and recording software"
    [packages]="obs-studio simplescreenrecorder v4l2loopback-dkms ffmpeg handbrake"
    [aur_packages]="streamdeck-ui"
    [post_install]="configure_streaming"
)

# Security bundle packages
declare -A BUNDLE_SECURITY=(
    [name]="Security"
    [description]="Security tools, VPN clients, and privacy utilities"
    [packages]="wireguard-tools openvpn networkmanager-openvpn networkmanager-wireguard tor proxychains-ng ufw gufw keepassxc bitwarden"
    [aur_packages]="protonvpn-cli windscribe-cli"
    [post_install]="configure_security"
)

# Science bundle packages
declare -A BUNDLE_SCIENCE=(
    [name]="Science"
    [description]="Scientific computing, math tools, and data analysis"
    [packages]="python-matplotlib python-numpy python-pandas python-scipy jupyter-notebook octave r maxima wxmaxima geogebra"
    [aur_packages]="anaconda"
    [post_install]="configure_science"
)

# Show bundle selection dialog
select_bundles() {
    log_info "Starting bundle selection..."
    
    local bundle_list=()
    
    # Build checklist items
    for bundle in "${BUNDLES[@]}"; do
        local name_var="BUNDLE_${bundle^^}[name]"
        local desc_var="BUNDLE_${bundle^^}[description]"
        local name=${!name_var}
        local desc=${!desc_var}
        bundle_list+=("$bundle" "$name - $desc" "off")
    done
    
    local selected
    selected=$(dialog --clear --title "Package Bundles" \
        --checklist "Select package bundles to install:\n\nThese are curated collections of software for common use cases.\n\nUse SPACE to select, ENTER to confirm:" 22 75 10 \
        "${bundle_list[@]}" \
        3>&1 1>&2 2>&3) || return 0
    
    if [[ -z "$selected" ]]; then
        log_info "No bundles selected"
        return 0
    fi
    
    # Convert to array
    local selected_bundles=($selected)
    
    log_info "Selected bundles: ${selected_bundles[*]}"
    
    # Show summary
    local summary="Selected Bundles:\n\n"
    for bundle in "${selected_bundles[@]}"; do
        local name_var="BUNDLE_${bundle^^}[name]"
        local desc_var="BUNDLE_${bundle^^}[description]"
        summary+="• ${!name_var}\n  ${!desc_var}\n\n"
    done
    
    summary+="\nInstall these bundles?"
    
    if ! dialog --yesno "$summary" 20 70; then
        return 0
    fi
    
    # Install each selected bundle
    for bundle in "${selected_bundles[@]}"; do
        install_bundle "$bundle"
    done
    
    return 0
}

# Install a specific bundle
install_bundle() {
    local bundle=$1
    local name_var="BUNDLE_${bundle^^}[name]"
    local desc_var="BUNDLE_${bundle^^}[description]"
    local pkg_var="BUNDLE_${bundle^^}[packages]"
    local aur_var="BUNDLE_${bundle^^}[aur_packages]"
    local post_var="BUNDLE_${bundle^^}[post_install]"
    
    local name=${!name_var}
    local packages=${!pkg_var}
    local aur_packages=${!aur_var}
    local post_install=${!post_var}
    
    log_info "Installing bundle: $name"
    
    dialog --infobox "Installing $name bundle...\n\nThis may take a few minutes." 6 60
    
    # Install official packages
    if [[ -n "$packages" ]]; then
        log_info "Installing official packages for $name"
        arch-chroot /mnt pacman -S --noconfirm --needed $packages 2>&1 | \
            while read -r line; do
                log_info "[pacman] $line"
            done || log_warn "Some packages in $name bundle failed to install"
    fi
    
    # Install AUR packages if yay is available
    if [[ -n "$aur_packages" ]] && command -v yay &>/dev/null; then
        log_info "Installing AUR packages for $name"
        for pkg in $aur_packages; do
            arch-chroot /mnt su - "$USERNAME" -c "yay -S --noconfirm $pkg" 2>&1 | \
                while read -r line; do
                    log_info "[yay] $line"
                done || log_warn "Failed to install AUR package: $pkg"
        done
    fi
    
    # Run post-install configuration
    if [[ -n "$post_install" ]]; then
        log_info "Running post-install for $name"
        $post_install
    fi
    
    log_info "Bundle $name installation complete"
}

# Configure gaming bundle
configure_gaming() {
    log_info "Configuring gaming bundle"
    
    # Enable gamemode service
    arch-chroot /mnt systemctl enable gamemoded
    
    # Add user to gamemode group
    arch-chroot /mnt usermod -aG gamemode "$USERNAME"
    
    # Install proton-ge if protonup-qt was installed
    if command -v protonup &>/dev/null; then
        arch-chroot /mnt su - "$USERNAME" -c "protonup -y" || true
    fi
    
    # Create gaming directories
    arch-chroot /mnt mkdir -p "/home/$USERNAME/Games"
    arch-chroot /mnt chown "$USERNAME:$USERNAME" "/home/$USERNAME/Games"
    
    log_info "Gaming bundle configured"
}

# Configure productivity bundle
configure_productivity() {
    log_info "Configuring productivity bundle"
    
    # Enable Nextcloud client autostart if installed
    if [[ -f /mnt/usr/bin/nextcloud ]]; then
        arch-chroot /mnt mkdir -p "/home/$USERNAME/.config/autostart"
        cat > "/mnt/home/$USERNAME/.config/autostart/nextcloud.desktop" <<EOF
[Desktop Entry]
Name=Nextcloud
GenericName=File Synchronizer
Exec=/usr/bin/nextcloud --background
Terminal=false
Icon=nextcloud
Type=Application
Categories=Network
StartupNotify=false
X-GNOME-Autostart-enabled=true
EOF
        arch-chroot /mnt chown -R "$USERNAME:$USERNAME" "/home/$USERNAME/.config"
    fi
    
    log_info "Productivity bundle configured"
}

# Configure development bundle
configure_development() {
    log_info "Configuring development bundle"
    
    # Enable Docker service
    if [[ -f /mnt/usr/bin/docker ]]; then
        arch-chroot /mnt systemctl enable docker
        arch-chroot /mnt usermod -aG docker "$USERNAME"
    fi
    
    # Configure git if not already configured
    if [[ -f /mnt/usr/bin/git ]]; then
        arch-chroot /mnt su - "$USERNAME" -c "git config --global init.defaultBranch main" || true
        arch-chroot /mnt su - "$USERNAME" -c "git config --global core.editor nano" || true
    fi
    
    # Create development directories
    arch-chroot /mnt mkdir -p "/home/$USERNAME/Projects"
    arch-chroot /mnt mkdir -p "/home/$USERNAME/.local/bin"
    arch-chroot /mnt chown -R "$USERNAME:$USERNAME" "/home/$USERNAME/Projects"
    arch-chroot /mnt chown -R "$USERNAME:$USERNAME" "/home/$USERNAME/.local"
    
    log_info "Development bundle configured"
}

# Configure multimedia bundle
configure_multimedia() {
    log_info "Configuring multimedia bundle"
    
    # Add user to video group for hardware acceleration
    arch-chroot /mnt usermod -aG video "$USERNAME"
    
    log_info "Multimedia bundle configured"
}

# Configure creative bundle
configure_creative() {
    log_info "Configuring creative bundle"
    
    # Add user to relevant groups
    arch-chroot /mnt usermod -aG video "$USERNAME"
    
    # Create projects directory
    arch-chroot /mnt mkdir -p "/home/$USERNAME/Projects"
    arch-chroot /mnt chown "$USERNAME:$USERNAME" "/home/$USERNAME/Projects"
    
    log_info "Creative bundle configured"
}

# Configure streaming bundle
configure_streaming() {
    log_info "Configuring streaming bundle"
    
    # Load v4l2loopback module
    if [[ -f /mnt/etc/modules-load.d/v4l2loopback.conf ]]; then
        echo "v4l2loopback" > /mnt/etc/modules-load.d/v4l2loopback.conf
    fi
    
    # Add user to video group
    arch-chroot /mnt usermod -aG video "$USERNAME"
    
    log_info "Streaming bundle configured"
}

# Configure security bundle
configure_security() {
    log_info "Configuring security bundle"
    
    # Enable UFW firewall
    if [[ -f /mnt/usr/bin/ufw ]]; then
        arch-chroot /mnt systemctl enable ufw
        arch-chroot /mnt ufw default deny incoming
        arch-chroot /mnt ufw default allow outgoing
        arch-chroot /mnt ufw enable || true
    fi
    
    # Configure Tor if installed
    if [[ -f /mnt/usr/bin/tor ]]; then
        arch-chroot /mnt systemctl enable tor
    fi
    
    log_info "Security bundle configured"
}

# Configure science bundle
configure_science() {
    log_info "Configuring science bundle"
    
    # Set up Jupyter notebook config
    if [[ -f /mnt/usr/bin/jupyter-notebook ]]; then
        arch-chroot /mnt su - "$USERNAME" -c "jupyter notebook --generate-config" || true
    fi
    
    # Create projects directory
    arch-chroot /mnt mkdir -p "/home/$USERNAME/Projects"
    arch-chroot /mnt chown "$USERNAME:$USERNAME" "/home/$USERNAME/Projects"
    
    log_info "Science bundle configured"
}

# Show bundle details
show_bundle_details() {
    local bundle=$1
    local name_var="BUNDLE_${bundle^^}[name]"
    local desc_var="BUNDLE_${bundle^^}[description]"
    local pkg_var="BUNDLE_${bundle^^}[packages]"
    local aur_var="BUNDLE_${bundle^^}[aur_packages]"
    
    local name=${!name_var}
    local desc=${!desc_var}
    local packages=${!pkg_var}
    local aur_packages=${!aur_var}
    
    local details="Bundle: $name\n\n"
    details+="Description: $desc\n\n"
    details+="Official Packages:\n"
    
    # Format package list
    local pkg_list=($packages)
    local line=""
    for pkg in "${pkg_list[@]}"; do
        if [[ ${#line} -gt 50 ]]; then
            details+="  $line\n"
            line="$pkg"
        else
            if [[ -n "$line" ]]; then
                line+=", $pkg"
            else
                line="$pkg"
            fi
        fi
    done
    [[ -n "$line" ]] && details+="  $line\n"
    
    if [[ -n "$aur_packages" ]]; then
        details+="\nAUR Packages:\n"
        details+="  $aur_packages\n"
    fi
    
    dialog --msgbox "$details" 25 75
}

# Quick bundle selection (select multiple at once)
quick_bundle_install() {
    log_info "Quick bundle installation mode"
    
    # Show all bundles with descriptions
    local menu_items=()
    for bundle in "${BUNDLES[@]}"; do
        local name_var="BUNDLE_${bundle^^}[name]"
        local desc_var="BUNDLE_${bundle^^}[description]"
        menu_items+=("$bundle" "${!name_var} - ${!desc_var:0:50}")
    done
    
    # Show menu
    local choice
    choice=$(dialog --clear --title "Quick Bundle Install" \
        --menu "Select a bundle to view details or install:\n\nUse arrows to navigate, Enter to select" 20 75 10 \
        "${menu_items[@]}" \
        "install_all" "Install multiple bundles..." \
        "back" "Return to main menu" \
        3>&1 1>&2 2>&3) || return 0
    
    case $choice in
        "install_all")
            select_bundles
            ;;
        "back")
            return 0
            ;;
        *)
            show_bundle_details "$choice"
            if dialog --yesno "Install the $choice bundle?" 7 50; then
                install_bundle "$choice"
                dialog --msgbox "✓ $choice bundle installed!" 6 40
            fi
            quick_bundle_install
            ;;
    esac
}
