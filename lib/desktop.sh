#!/bin/bash
#
# Desktop environment installation
#

# Source WM configs
source "$LIB_DIR/wm_configs.sh"

# Install desktop environment
install_desktop() {
    log_info "Starting desktop environment installation..."
    
    # Select desktop environment
    select_desktop_environment || return 1
    
    # Install selected DE
    case $DESKTOP_ENV in
        "gnome") install_gnome ;;
        "kde") install_kde ;;
        "xfce") install_xfce ;;
        "cinnamon") install_cinnamon ;;
        "mate") install_mate ;;
        "lxqt") install_lxqt ;;
        "budgie") install_budgie ;;
        "deepin") install_deepin ;;
        "enlightenment") install_enlightenment ;;
        "lxde") install_lxde ;;
        "i3") install_i3 ;;
        "openbox") install_openbox ;;
        "sway") install_sway ;;
        "awesome") install_awesome ;;
        "bspwm") install_bspwm ;;
        "qtile") install_qtile ;;
        "dwm") install_dwm ;;
        "xmonad") install_xmonad ;;
        *) return 1 ;;
    esac
    
    # Install graphics drivers
    install_graphics_drivers
    
    # Install common applications
    install_common_apps
    
    return 0
}

# Select desktop environment
select_desktop_environment() {
    DESKTOP_ENV=$(dialog_safe --clear --title "Desktop Environment / Window Manager" \
        --menu "Choose your desktop environment or window manager:\n\nDesktop Environments:" 30 75 25 \
        "gnome" "GNOME - Modern, user-friendly (Recommended for beginners)" \
        "kde" "KDE Plasma - Highly customizable, Windows-like" \
        "xfce" "XFCE - Lightweight, traditional desktop" \
        "cinnamon" "Cinnamon - Traditional, familiar interface" \
        "mate" "MATE - Classic GNOME 2 style" \
        "lxqt" "LXQt - Very lightweight, modern" \
        "budgie" "Budgie - Elegant, macOS-like" \
        "deepin" "Deepin - Beautiful, unique design" \
        "enlightenment" "Enlightenment - Fast, beautiful, customizable" \
        "lxde" "LXDE - Ultra lightweight" \
        "TILING_WINDOW_MANAGERS" "────────── Tiling WMs ──────────" \
        "i3" "i3 - Most popular tiling WM (Recommended)" \
        "sway" "Sway - Wayland drop-in for i3" \
        "awesome" "AwesomeWM - Lua configurable, powerful" \
        "bspwm" "BSPWM - Binary space partitioning" \
        "qtile" "Qtile - Python configured" \
        "xmonad" "XMonad - Haskell-based" \
        "FLOATING_WINDOW_MANAGERS" "────────── Floating WMs ──────────" \
        "openbox" "Openbox - Highly configurable, lightweight" \
        "dwm" "DWM - Suckless dynamic WM" \
        "minimal" "Minimal X11 - No desktop, basic X server" \
        3>&1 1>&2 2>&3) || return 1
    
    # Check if user selected a separator
    if [[ "$DESKTOP_ENV" == "TILING_WINDOW_MANAGERS" ]] || [[ "$DESKTOP_ENV" == "FLOATING_WINDOW_MANAGERS" ]]; then
        select_desktop_environment
        return $?
    fi
    
    log_info "Selected desktop environment: $DESKTOP_ENV"
    
    return 0
}

# Install GNOME
install_gnome() {
    log_info "Installing GNOME..."
    
    dialog_safe --infobox "Installing GNOME desktop environment...\nThis may take several minutes." 5 60
    
    arch-chroot /mnt pacman -S --noconfirm \
        gnome \
        gnome-tweaks \
        gdm
    
    arch-chroot /mnt systemctl enable gdm
    
    log_info "GNOME installed"
}

# Install KDE Plasma
install_kde() {
    log_info "Installing KDE Plasma..."
    
    dialog_safe --infobox "Installing KDE Plasma desktop environment...\nThis may take several minutes." 5 60
    
    arch-chroot /mnt pacman -S --noconfirm \
        plasma \
        kde-applications \
        sddm
    
    arch-chroot /mnt systemctl enable sddm
    
    log_info "KDE Plasma installed"
}

# Install XFCE
install_xfce() {
    log_info "Installing XFCE..."
    
    dialog_safe --infobox "Installing XFCE desktop environment...\nThis may take several minutes." 5 60
    
    arch-chroot /mnt pacman -S --noconfirm \
        xfce4 \
        xfce4-goodies \
        lightdm \
        lightdm-gtk-greeter
    
    arch-chroot /mnt systemctl enable lightdm
    
    log_info "XFCE installed"
}

# Install Cinnamon
install_cinnamon() {
    log_info "Installing Cinnamon..."
    
    dialog_safe --infobox "Installing Cinnamon desktop environment...\nThis may take several minutes." 5 60
    
    arch-chroot /mnt pacman -S --noconfirm \
        cinnamon \
        cinnamon-translations \
        gnome-terminal \
        lightdm \
        lightdm-gtk-greeter
    
    arch-chroot /mnt systemctl enable lightdm
    
    log_info "Cinnamon installed"
}

# Install MATE
install_mate() {
    log_info "Installing MATE..."
    
    dialog_safe --infobox "Installing MATE desktop environment...\nThis may take several minutes." 5 60
    
    arch-chroot /mnt pacman -S --noconfirm \
        mate \
        mate-extra \
        lightdm \
        lightdm-gtk-greeter
    
    arch-chroot /mnt systemctl enable lightdm
    
    log_info "MATE installed"
}

# Install LXQt
install_lxqt() {
    log_info "Installing LXQt..."
    
    dialog_safe --infobox "Installing LXQt desktop environment...\nThis may take several minutes." 5 60
    
    arch-chroot /mnt pacman -S --noconfirm \
        lxqt \
        sddm
    
    arch-chroot /mnt systemctl enable sddm
    
    log_info "LXQt installed"
}

# Install Budgie
install_budgie() {
    log_info "Installing Budgie..."
    
    dialog_safe --infobox "Installing Budgie desktop environment...\nThis may take several minutes." 5 60
    
    arch-chroot /mnt pacman -S --noconfirm \
        budgie-desktop \
        budgie-screensaver \
        gnome-control-center \
        gnome-terminal \
        lightdm \
        lightdm-gtk-greeter
    
    arch-chroot /mnt systemctl enable lightdm
    
    log_info "Budgie installed"
}

# Install Deepin
install_deepin() {
    log_info "Installing Deepin..."
    
    dialog_safe --infobox "Installing Deepin desktop environment...\nThis may take several minutes." 5 60
    
    arch-chroot /mnt pacman -S --noconfirm \
        deepin \
        deepin-extra \
        lightdm
    
    # Configure Deepin greeter
    sed -i 's/#greeter-session=.*/greeter-session=lightdm-deepin-greeter/' /mnt/etc/lightdm/lightdm.conf
    
    arch-chroot /mnt systemctl enable lightdm
    
    log_info "Deepin installed"
}

# Install Enlightenment
install_enlightenment() {
    log_info "Installing Enlightenment..."
    
    dialog_safe --infobox "Installing Enlightenment desktop environment...\nThis may take several minutes." 5 60
    
    arch-chroot /mnt pacman -S --noconfirm \
        enlightenment \
        terminology \
        lightdm \
        lightdm-gtk-greeter \
        connman
    
    arch-chroot /mnt systemctl enable lightdm
    arch-chroot /mnt systemctl enable connman
    
    log_info "Enlightenment installed"
}

# Install LXDE
install_lxde() {
    log_info "Installing LXDE..."
    
    dialog_safe --infobox "Installing LXDE desktop environment...\nThis may take several minutes." 5 60
    
    arch-chroot /mnt pacman -S --noconfirm \
        lxde-common \
        lxde-icon-theme \
        lxappearance \
        lxappearance-obconf \
        lxinput \
        lxrandr \
        lxsession \
        openbox \
        pcmanfm \
        lightdm \
        lightdm-gtk-greeter
    
    arch-chroot /mnt systemctl enable lightdm
    
    log_info "LXDE installed"
}

# Install i3
install_i3() {
    log_info "Installing i3..."
    
    dialog_safe --infobox "Installing i3 window manager with recommended configuration...\nThis may take several minutes." 5 60
    
    # Install display manager first
    arch-chroot /mnt pacman -S --noconfirm \
        lightdm \
        lightdm-gtk-greeter
    
    arch-chroot /mnt systemctl enable lightdm
    
    # Install i3 and configuration
    install_i3_config
    
    # Show keybinding cheat sheet
    show_keybinding_cheatsheet "i3"
    
    log_info "i3 installed with recommended configuration"
}

# Install OpenBox
install_openbox() {
    log_info "Installing OpenBox..."
    
    dialog_safe --infobox "Installing OpenBox window manager with recommended configuration...\nThis may take several minutes." 5 60
    
    # Install display manager
    arch-chroot /mnt pacman -S --noconfirm \
        lightdm \
        lightdm-gtk-greeter
    
    arch-chroot /mnt systemctl enable lightdm
    
    # Install OpenBox and configuration
    install_openbox_config
    
    # Show keybinding cheat sheet
    show_keybinding_cheatsheet "openbox"
    
    log_info "OpenBox installed with recommended configuration"
}

# Install Sway
install_sway() {
    log_info "Installing Sway..."
    
    dialog_safe --infobox "Installing Sway window manager with recommended configuration...\nThis may take several minutes." 5 60
    
    arch-chroot /mnt pacman -S --noconfirm \
        sway \
        swaylock \
        swayidle \
        waybar \
        wofi \
        foot \
        wl-clipboard \
        grim \
        slurp \
        mako \
        polkit
    
    # Install Sway configuration
    install_sway_config
    
    log_info "Sway installed"
    
    # Note: Sway doesn't use a display manager, user starts it from tty
    dialog_safe --msgbox "Sway Installation Note:\n\nSway is a Wayland compositor.\nAfter login, type 'sway' to start it.\n\nYour config is at: ~/.config/sway/config\n\nYou may want to add 'exec sway' to your ~/.bash_profile for auto-start." 14 60
}

# Install AwesomeWM
install_awesome() {
    log_info "Installing AwesomeWM..."
    
    dialog_safe --infobox "Installing AwesomeWM with recommended configuration...\nThis may take several minutes." 5 60
    
    arch-chroot /mnt pacman -S --noconfirm \
        lightdm \
        lightdm-gtk-greeter
    
    arch-chroot /mnt systemctl enable lightdm
    
    # Install AwesomeWM configuration
    install_awesome_config
    
    # Show keybinding cheat sheet
    show_keybinding_cheatsheet "awesome"
    
    log_info "AwesomeWM installed with recommended configuration"
}

# Install BSPWM
install_bspwm() {
    log_info "Installing BSPWM..."
    
    dialog_safe --infobox "Installing BSPWM with recommended configuration...\nThis may take several minutes." 5 60
    
    arch-chroot /mnt pacman -S --noconfirm \
        lightdm \
        lightdm-gtk-greeter
    
    arch-chroot /mnt systemctl enable lightdm
    
    # Install BSPWM configuration
    install_bspwm_config
    
    # Show keybinding cheat sheet
    show_keybinding_cheatsheet "bspwm"
    
    log_info "BSPWM installed with recommended configuration"
}

# Install Qtile
install_qtile() {
    log_info "Installing Qtile..."
    
    dialog_safe --infobox "Installing Qtile window manager...\nThis may take several minutes." 5 60
    
    arch-chroot /mnt pacman -S --noconfirm \
        qtile \
        python-dbus \
        python-psutil \
        lightdm \
        lightdm-gtk-greeter \
        picom \
        dunst \
        rofi \
        feh
    
    arch-chroot /mnt systemctl enable lightdm
    
    log_info "Qtile installed"
}

# Install DWM
install_dwm() {
    log_info "Installing DWM..."
    
    dialog_safe --infobox "Installing DWM (Suckless Dynamic Window Manager)...\nThis may take several minutes." 5 60
    
    # Install dependencies
    arch-chroot /mnt pacman -S --noconfirm \
        base-devel \
        libx11 \
        libxinerama \
        libxft \
        dmenu \
        st \
        lightdm \
        lightdm-gtk-greeter
    
    # Create build directory
    mkdir -p /mnt/tmp/dwm-build
    
    # Download and compile DWM
    cat > /mnt/tmp/build-dwm.sh << 'EOF'
#!/bin/bash
cd /tmp
git clone https://git.suckless.org/dwm
cd dwm
make
sudo make install
EOF
    chmod +x /mnt/tmp/build-dwm.sh
    arch-chroot /mnt bash /tmp/build-dwm.sh
    
    # Clean up
    rm -rf /mnt/tmp/dwm-build
    
    arch-chroot /mnt systemctl enable lightdm
    
    dialog_safe --msgbox "DWM Installation Note:\n\nDWM is a suckless window manager that requires compiling.\n\nTo customize:\n1. Edit config.h in the dwm source\n2. Recompile with: sudo make clean install\n\nKeybindings:\nMod+Enter: Terminal (st)\nMod+P: dmenu\nMod+J/K: Navigate windows\nMod+Shift+Q: Close window\nMod+1-9: Switch tag\nMod+Shift+1-9: Move to tag\nMod+B: Toggle bar\nMod+T: Tiled layout\nMod+F: Floating layout\nMod+M: Monocle layout" 20 65
    
    log_info "DWM installed"
}

# Install XMonad
install_xmonad() {
    log_info "Installing XMonad..."
    
    dialog_safe --infobox "Installing XMonad (Haskell tiling WM)...\nThis may take several minutes." 5 60
    
    arch-chroot /mnt pacman -S --noconfirm \
        xmonad \
        xmonad-contrib \
        xmobar \
        dmenu \
        lightdm \
        lightdm-gtk-greeter \
        picom \
        feh \
        dunst \
        rofi
    
    # Create basic xmonad config
    mkdir -p /mnt/home/$USERNAME/.xmonad
    cat > /mnt/home/$USERNAME/.xmonad/xmonad.hs << 'EOF'
import XMonad
import XMonad.Config.Desktop
import XMonad.Hooks.DynamicLog
import XMonad.Hooks.ManageDocks
import XMonad.Layout.Spacing
import XMonad.Util.Run(spawnPipe)
import XMonad.Util.EZConfig(additionalKeys)
import System.IO

main = do
    xmproc <- spawnPipe "xmobar"
    xmonad $ desktopConfig
        { terminal    = "alacritty"
        , modMask     = mod4Mask
        , borderWidth = 2
        , focusedBorderColor = "#458588"
        , normalBorderColor  = "#3c3836"
        , manageHook = manageDocks <+> manageHook desktopConfig
        , layoutHook = avoidStruts $ spacing 5 $ Tall 1 (3/100) (1/2) ||| Full
        , logHook = dynamicLogWithPP xmobarPP
                        { ppOutput = hPutStrLn xmproc
                        , ppTitle = xmobarColor "#ebdbb2" "" . shorten 50
                        }
        } `additionalKeys`
        [ ((mod4Mask .|. shiftMask, xK_z), spawn "i3lock-fancy")
        , ((controlMask, xK_Print), spawn "sleep 0.2; scrot -s")
        , ((0, xK_Print), spawn "scrot")
        ]
EOF
    
    # Compile xmonad
    arch-chroot /mnt su - "$USERNAME" -c "xmonad --recompile" || true
    
    arch-chroot /mnt chown -R "$USERNAME:$USERNAME" "/home/$USERNAME/.xmonad"
    arch-chroot /mnt systemctl enable lightdm
    
    log_info "XMonad installed"
}

# Install graphics drivers
install_graphics_drivers() {
    log_info "Detecting and installing graphics drivers..."
    
    local gpu
    gpu=$(get_gpu_info)
    
    dialog_safe --infobox "Detecting graphics hardware...\n\nFound: ${gpu:0:50}" 5 60
    
    # Detect GPU vendor
    if echo "$gpu" | grep -qi "nvidia"; then
        install_nvidia_drivers
    elif echo "$gpu" | grep -qi "amd\|ati\|radeon"; then
        install_amd_drivers
    elif echo "$gpu" | grep -qi "intel"; then
        install_intel_drivers
    else
        # Install generic drivers
        arch-chroot /mnt pacman -S --noconfirm xf86-video-vesa
    fi
    
    # Install common X/Wayland packages
    arch-chroot /mnt pacman -S --noconfirm \
        xorg-server \
        xorg-xinit \
        xorg-apps \
        mesa \
        libglvnd \
        vulkan-icd-loader
    
    log_info "Graphics drivers installed"
}

# Install NVIDIA drivers
install_nvidia_drivers() {
    log_info "Installing NVIDIA drivers..."
    
    local driver_choice
    driver_choice=$(dialog_safe --clear --title "NVIDIA Driver" \
        --menu "Select NVIDIA driver:\n\nOpen drivers work well for most users.\nProprietary drivers offer best performance." 15 60 3 \
        "open" "nvidia-open (Open source, recommended)" \
        "proprietary" "nvidia (Proprietary, best performance)" \
        "legacy" "nvidia-470xx-dkms (Legacy cards)" \
        3>&1 1>&2 2>&3) || driver_choice="open"
    
    case $driver_choice in
        "open")
            arch-chroot /mnt pacman -S --noconfirm nvidia-open nvidia-utils nvidia-settings
            ;;
        "proprietary")
            arch-chroot /mnt pacman -S --noconfirm nvidia nvidia-utils nvidia-settings
            ;;
        "legacy")
            arch-chroot /mnt pacman -S --noconfirm nvidia-470xx-dkms nvidia-470xx-utils
            ;;
    esac
}

# Install AMD drivers
install_amd_drivers() {
    log_info "Installing AMD drivers..."
    
    arch-chroot /mnt pacman -S --noconfirm \
        xf86-video-amdgpu \
        xf86-video-ati \
        mesa \
        lib32-mesa \
        vulkan-radeon \
        lib32-vulkan-radeon \
        libva-mesa-driver \
        lib32-libva-mesa-driver \
        mesa-vdpau \
        lib32-mesa-vdpau
}

# Install Intel drivers
install_intel_drivers() {
    log_info "Installing Intel drivers..."
    
    arch-chroot /mnt pacman -S --noconfirm \
        xf86-video-intel \
        mesa \
        lib32-mesa \
        vulkan-intel \
        lib32-vulkan-intel \
        intel-media-driver \
        libva-intel-driver
}

# Install common applications
install_common_apps() {
    log_info "Installing common applications..."
    
    dialog_safe --infobox "Installing common applications..." 3 50
    
    # Web browser
    arch-chroot /mnt pacman -S --noconfirm firefox
    
    # File manager
    arch-chroot /mnt pacman -S --noconfirm thunar gvfs
    
    # Text editor
    arch-chroot /mnt pacman -S --noconfirm gedit
    
    # Terminal
    arch-chroot /mnt pacman -S --noconfirm gnome-terminal || \
        arch-chroot /mnt pacman -S --noconfirm konsole || \
        arch-chroot /mnt pacman -S --noconfirm xfce4-terminal || \
        arch-chroot /mnt pacman -S --noconfirm xterm
    
    # Archive utilities
    arch-chroot /mnt pacman -S --noconfirm file-roller p7zip unzip unrar
    
    # Media
    arch-chroot /mnt pacman -S --noconfirm vlc
    
    # Image viewer
    arch-chroot /mnt pacman -S --noconfirm eog || \
        arch-chroot /mnt pacman -S --noconfirm gwenview || \
        arch-chroot /mnt pacman -S --noconfirm ristretto
    
    # Document viewer
    arch-chroot /mnt pacman -S --noconfirm evince || \
        arch-chroot /mnt pacman -S --noconfirm okular
    
    # Fonts
    arch-chroot /mnt pacman -S --noconfirm \
        ttf-dejavu \
        ttf-liberation \
        ttf-freefont \
        noto-fonts \
        noto-fonts-cjk \
        noto-fonts-emoji \
        ttf-font-awesome
    
    # Additional utilities
    arch-chroot /mnt pacman -S --noconfirm \
        cups \
        cups-pdf \
        system-config-printer \
        pipewire \
        pipewire-pulse \
        pipewire-alsa \
        pipewire-jack \
        wireplumber
    
    # Enable services
    arch-chroot /mnt systemctl enable cups
    arch-chroot /mnt systemctl --user enable pipewire pipewire-pulse wireplumber
    
    log_info "Common applications installed"
}
