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

# Get bundle info function
get_bundle_info() {
    local bundle=$1
    local field=$2
    
    case "$bundle" in
        "gaming")
            case "$field" in
                "name") echo "Gaming" ;;
                "description") echo "Steam, Lutris, Wine, and gaming tools" ;;
                "packages") echo "steam lutris wine wine-mono wine-gecko gamemode lib32-gamemode discord obs-studio mangohud lib32-mangohud vulkan-icd-loader lib32-vulkan-icd-loader" ;;
                "aur_packages") echo "protonup-qt heroic-games-launcher-bin" ;;
                "post_install") echo "configure_gaming" ;;
            esac
            ;;
        "productivity")
            case "$field" in
                "name") echo "Productivity" ;;
                "description") echo "LibreOffice, email clients, note-taking, and office tools" ;;
                "packages") echo "libreoffice-fresh thunderbird nextcloud-client evolution geary calibre zim cherrytree pdfarranger gnome-calculator" ;;
                "aur_packages") echo "joplin-appimage notion-app-electron" ;;
                "post_install") echo "configure_productivity" ;;
            esac
            ;;
        "development")
            case "$field" in
                "name") echo "Development" ;;
                "description") echo "IDEs, editors, compilers, and development tools" ;;
                "packages") echo "code vim nano emacs neovim git lazygit github-cli docker docker-compose python python-pip nodejs npm rust go gcc gdb cmake make" ;;
                "aur_packages") echo "visual-studio-code-bin jetbrains-toolbox postman-bin insomnia" ;;
                "post_install") echo "configure_development" ;;
            esac
            ;;
        "multimedia")
            case "$field" in
                "name") echo "Multimedia" ;;
                "description") echo "Video editing, audio production, and media playback" ;;
                "packages") echo "kdenlive shotcut obs-studio audacity ardour lmms vlc mpv ffmpeg handbrake kodi" ;;
                "aur_packages") echo "davinci-resolve davinci-resolve-studio" ;;
                "post_install") echo "configure_multimedia" ;;
            esac
            ;;
        "creative")
            case "$field" in
                "name") echo "Creative" ;;
                "description") echo "Graphics design, 3D modeling, and digital art" ;;
                "packages") echo "gimp inkscape krita blender freecad librecad darktable rawtherapee" ;;
                "aur_packages") echo "figma-linux notion-app-electron" ;;
                "post_install") echo "configure_creative" ;;
            esac
            ;;
        "streaming")
            case "$field" in
                "name") echo "Streaming" ;;
                "description") echo "OBS, streaming tools, and recording software" ;;
                "packages") echo "obs-studio simplescreenrecorder v4l2loopback-dkms ffmpeg handbrake" ;;
                "aur_packages") echo "streamdeck-ui" ;;
                "post_install") echo "configure_streaming" ;;
            esac
            ;;
        "security")
            case "$field" in
                "name") echo "Security" ;;
                "description") echo "Security tools, VPN clients, and privacy utilities" ;;
                "packages") echo "wireguard-tools openvpn networkmanager-openvpn networkmanager-wireguard tor proxychains-ng ufw gufw keepassxc bitwarden" ;;
                "aur_packages") echo "protonvpn-cli windscribe-cli" ;;
                "post_install") echo "configure_security" ;;
            esac
            ;;
        "science")
            case "$field" in
                "name") echo "Science" ;;
                "description") echo "Scientific computing, math tools, and data analysis" ;;
                "packages") echo "python-matplotlib python-numpy python-pandas python-scipy jupyter-notebook octave r maxima wxmaxima geogebra" ;;
                "aur_packages") echo "anaconda" ;;
                "post_install") echo "configure_science" ;;
            esac
            ;;
    esac
}

# Show bundle selection dialog
select_bundles() {
    log_info "Starting bundle selection..."
    
    local bundle_list=()
    
    # Build checklist items
    for bundle in "${BUNDLES[@]}"; do
        local name=$(get_bundle_info "$bundle" "name")
        local desc=$(get_bundle_info "$bundle" "description")
        bundle_list+=("$bundle" "$name - $desc" "off")
    done
    
    local selected
    selected=$(dialog_safe --clear --title "Package Bundles" \
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
        local name=$(get_bundle_info "$bundle" "name")
        local desc=$(get_bundle_info "$bundle" "description")
        summary+="• $name\n  $desc\n\n"
    done
    
    summary+="\nInstall these bundles?"
    
    if ! dialog_safe --yesno "$summary" 20 70; then
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
    local name=$(get_bundle_info "$bundle" "name")
    local packages=$(get_bundle_info "$bundle" "packages")
    local aur_packages=$(get_bundle_info "$bundle" "aur_packages")
    local post_install=$(get_bundle_info "$bundle" "post_install")
    
    log_info "Installing bundle: $name"
    
    dialog_safe --infobox "Installing $name bundle...\n\nThis may take a few minutes." 6 60
    
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
    local name=$(get_bundle_info "$bundle" "name")
    local desc=$(get_bundle_info "$bundle" "description")
    local packages=$(get_bundle_info "$bundle" "packages")
    local aur_packages=$(get_bundle_info "$bundle" "aur_packages")
    
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
    
    dialog_safe --msgbox "$details" 25 75
}

# Quick bundle selection (select multiple at once)
quick_bundle_install() {
    log_info "Quick bundle installation mode"
    
    # Show all bundles with descriptions
    local menu_items=()
    for bundle in "${BUNDLES[@]}"; do
        local name=$(get_bundle_info "$bundle" "name")
        local desc=$(get_bundle_info "$bundle" "description")
        menu_items+=("$bundle" "$name - ${desc:0:50}")
    done
    
    # Show menu
    local choice
    choice=$(dialog_safe --clear --title "Quick Bundle Install" \
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
            if dialog_safe --yesno "Install the $choice bundle?" 7 50; then
                install_bundle "$choice"
                dialog_safe --msgbox "✓ $choice bundle installed!" 6 40
            fi
            quick_bundle_install
            ;;
    esac
}
