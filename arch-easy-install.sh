#!/bin/bash
#
# Arch Linux Easy Installer
# A beginner-friendly TUI installer for Arch Linux
# Version 2.0 - With enhancements
#

set -euo pipefail

# Script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LIB_DIR="$SCRIPT_DIR/lib"

# Source libraries
source "$LIB_DIR/common.sh"
source "$LIB_DIR/config.sh"
source "$LIB_DIR/validation.sh"
source "$LIB_DIR/progress.sh"
source "$LIB_DIR/preflight.sh"
source "$LIB_DIR/encryption.sh"
source "$LIB_DIR/disk.sh"
source "$LIB_DIR/install.sh"
source "$LIB_DIR/desktop.sh"
source "$LIB_DIR/aur.sh"
source "$LIB_DIR/bundles.sh"
source "$LIB_DIR/wm_configs.sh"

# Installation phases
PHASES=(
    "pre_installation"
    "disk_partitioning"
    "base_installation"
    "system_configuration"
    "bootloader_installation"
    "desktop_installation"
    "bundle_installation"
    "post_installation"
)

# Parse command line arguments
parse_args() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            --dry-run|-d)
                set_config '.options.dry_run' 'true'
                log_info "Dry run mode enabled"
                shift
                ;;
            --verbose|-v)
                set_config '.options.verbose' 'true'
                log_info "Verbose mode enabled"
                shift
                ;;
            --config|-c)
                if [[ -f "$2" ]]; then
                    CONFIG=$(cat "$2")
                    log_info "Loaded configuration from $2"
                fi
                shift 2
                ;;
            --resume|-r)
                log_info "Resume mode enabled"
                shift
                ;;
            --help|-h)
                show_usage
                exit 0
                ;;
            *)
                log_error "Unknown option: $1"
                show_usage
                exit 1
                ;;
        esac
    done
}

# Show usage information
show_usage() {
    cat <<EOF
Arch Linux Easy Installer v2.0

Usage: sudo bash arch-easy-install.sh [OPTIONS]

Options:
    -d, --dry-run       Simulate installation without making changes
    -v, --verbose       Enable verbose logging
    -c, --config FILE   Load configuration from FILE
    -r, --resume        Resume interrupted installation
    -h, --help          Show this help message

Examples:
    sudo bash arch-easy-install.sh
    sudo bash arch-easy-install.sh --dry-run
    sudo bash arch-easy-install.sh --config my-config.json

For more information, see README.md
EOF
}

# Main menu with improved options
main_menu() {
    while true; do
        local choice
        choice=$(dialog --clear --title "Arch Linux Easy Installer v2.0" \
            --menu "Welcome! This script will guide you through installing Arch Linux.\n\nWhat would you like to do?" 18 65 8 \
            1 "Start Installation" \
            2 "System Requirements Check" \
            3 "Pre-flight Diagnostics" \
            4 "Install Software Bundles" \
            5 "Load Configuration" \
            6 "Save Configuration" \
            7 "Help / Documentation" \
            8 "Exit" \
            3>&1 1>&2 2>&3)

        case $choice in
            1) start_installation ;;
            2) check_requirements ;;
            3) run_preflight_checks ;;
            4) quick_bundle_install ;;
            5) load_external_config ;;
            6) save_external_config ;;
            7) show_help ;;
            8) exit 0 ;;
            *) exit 0 ;;
        esac
    done
}

# Load external configuration
load_external_config() {
    local config_file
    config_file=$(dialog --clear --title "Load Configuration" \
        --fselect "$HOME/" 20 70 \
        3>&1 1>&2 2>&3) || return 1
    
    if [[ -f "$config_file" ]]; then
        if cp "$config_file" "$CONFIG_FILE"; then
            load_config
            dialog --msgbox "✓ Configuration loaded successfully!" 6 40
            print_config_summary > /tmp/config-summary.txt
            dialog --textbox /tmp/config-summary.txt 20 70
        else
            dialog --msgbox "✗ Failed to load configuration file." 6 40
        fi
    else
        dialog --msgbox "Configuration file not found." 6 40
    fi
}

# Save configuration to external file
save_external_config() {
    local config_file
    config_file=$(dialog --clear --title "Save Configuration" \
        --inputbox "Enter filename to save configuration:" 10 50 "$HOME/arch-install-config.json" \
        3>&1 1>&2 2>&3) || return 1
    
    if cp "$CONFIG_FILE" "$config_file"; then
        dialog --msgbox "✓ Configuration saved to:\n$config_file" 7 60
    else
        dialog --msgbox "✗ Failed to save configuration." 6 40
    fi
}

# Start the installation process with resume support
start_installation() {
    log_info "Starting Arch Linux installation..."
    
    # Check for resume capability
    local start_phase=0
    if check_resume; then
        local resume_phase
        resume_phase=$(get_resume_phase)
        
        # Map phase name to index
        case $resume_phase in
            "pre_installation") start_phase=0 ;;
            "disk_partitioning") start_phase=1 ;;
            "base_installation") start_phase=2 ;;
            "system_configuration") start_phase=3 ;;
            "bootloader_installation") start_phase=4 ;;
            "desktop_installation") start_phase=5 ;;
            "post_installation") start_phase=6 ;;
        esac
    fi
    
    # Confirm before starting
    if [[ $start_phase -eq 0 ]]; then
        print_config_summary > /tmp/config-summary.txt
        if ! dialog --yesno "$(cat /tmp/config-summary.txt)\n\n⚠ WARNING: This will modify your disk!\n\nDo you want to proceed with the installation?" 25 70; then
            return 0
        fi
        
        # Dangerous operation confirmation
        if ! confirm_dangerous_operation "You are about to install Arch Linux. All data on the selected disk will be erased." "INSTALL"; then
            return 0
        fi
    fi
    
    # Run installation phases
    local total_phases=${#PHASES[@]}
    
    for ((i=start_phase; i<total_phases; i++)); do
        local phase_name=${PHASES[$i]}
        local phase_num=$((i + 1))
        
        log_info "Starting phase $phase_num/$total_phases: $phase_name"
        save_state "$phase_name" "in_progress"
        
        show_installation_progress "$phase_num" "$total_phases" "$phase_name"
        sleep 1
        
        case $phase_name in
            "pre_installation")
                pre_installation || handle_phase_error "$phase_name"
                ;;
            "disk_partitioning")
                partition_disk || handle_phase_error "$phase_name"
                ;;
            "base_installation")
                install_base || handle_phase_error "$phase_name"
                ;;
            "system_configuration")
                configure_system || handle_phase_error "$phase_name"
                ;;
            "bootloader_installation")
                install_bootloader || handle_phase_error "$phase_name"
                ;;
            "desktop_installation")
                if [[ "$(get_config '.desktop.install')" == "true" ]] || \
                   dialog --yesno "Would you like to install a desktop environment?" 8 50; then
                    set_config '.desktop.install' 'true'
                    install_desktop || handle_phase_error "$phase_name"
                fi
                ;;
            "bundle_installation")
                if dialog --yesno "Would you like to install software bundles?\n\nBundles are curated collections of software for specific use cases like:\n• Gaming\n• Development\n• Productivity\n• Multimedia\n• And more!" 12 60; then
                    select_bundles || log_warn "Bundle installation had errors"
                fi
                ;;
            "post_installation")
                post_installation || handle_phase_error "$phase_name"
                ;;
        esac
        
        save_state "$phase_name" "complete"
    done
    
    # Installation complete
    show_completion_dialog
}

# Handle phase errors
handle_phase_error() {
    local phase=$1
    
    log_error "Phase failed: $phase"
    save_state "$phase" "failed"
    
    dialog --msgbox "Installation failed during phase: $phase\n\nCheck the log file for details:\n$LOG_FILE\n\nYou can resume the installation later with:\nsudo bash arch-easy-install.sh --resume" 15 60
    
    return 1
}

# Show completion dialog
show_completion_dialog() {
    local message="Installation complete! 🎉\n\n"
    message+="Your Arch Linux system has been installed successfully.\n\n"
    message+="What's next:\n"
    message+="1. Remove the installation media\n"
    message+="2. Reboot into your new system\n"
    message+="3. Login with your username: $USERNAME\n\n"
    
    if [[ "$(get_config '.desktop.install')" == "true" ]]; then
        local desktop_env=$(get_config '.desktop.environment')
        message+="Desktop Environment: $desktop_env\n"
    fi
    
    message+="\nThank you for using Arch Linux Easy Installer!"
    
    dialog --msgbox "$message" 15 60
    
    # Final configuration export
    export_config_to_chroot
    
    # Ask to reboot
    if dialog --yesno "Would you like to reboot now?" 7 40; then
        cleanup_and_reboot
    else
        dialog --msgbox "You can reboot later by running:\nreboot\n\nThe installation is complete." 8 50
    fi
}

# Cleanup and reboot
cleanup_and_reboot() {
    log_info "Cleaning up and preparing for reboot..."
    
    # Close encryption containers
    cleanup_encryption
    
    # Unmount everything
    umount -R /mnt 2>/dev/null || true
    swapoff -a 2>/dev/null || true
    
    log_info "Rebooting..."
    sleep 2
    reboot
}

# Pre-installation checks
pre_installation() {
    log_info "Running pre-installation checks..."
    
    # Check boot mode
    check_boot_mode
    
    # Run full preflight checks
    if ! run_preflight_checks; then
        if ! dialog --yesno "Some pre-flight checks failed.\n\nDo you want to continue anyway?" 8 50; then
            return 1
        fi
    fi
    
    # Update keyring
    dialog --infobox "Synchronizing package database and keyring..." 3 50
    pacman -Sy --noconfirm archlinux-keyring &>/dev/null || true
    
    # Check for encryption
    if ask_encryption; then
        install_encryption_tools
    fi
    
    log_info "Pre-installation complete"
    return 0
}

# Show help
show_help() {
    dialog --msgbox "Arch Linux Easy Installer v2.0 Help\n\nThis installer provides a guided setup for Arch Linux with:\n\n✓ Automatic disk partitioning\n✓ Multiple desktop environments\n✓ Disk encryption (LUKS)\n✓ Automatic mirror selection\n✓ Hardware detection\n✓ AUR helper installation\n✓ Configuration save/load\n✓ Resume interrupted installations\n\nKeyboard Shortcuts:\n- TAB: Move between buttons\n- SPACE: Select/Deselect\n- ENTER: Confirm\n- ESC: Cancel/Go back\n\nFor detailed documentation:\nhttps://wiki.archlinux.org\n\nReport issues at:\nhttps://github.com/yourusername/arch-easy-install" 25 70
}

# Check system requirements
check_requirements() {
    local info="System Requirements Check\n\n"
    info+="Boot Mode: $BOOT_MODE\n"
    info+="Architecture: $(uname -m)\n"
    info+="Memory: $(free -h | awk '/^Mem:/ {print $2}')\n"
    info+="Available Disks:\n"
    
    while read -r name size; do
        info+="  - $name: $size\n"
    done < <(lsblk -d -n -o NAME,SIZE | grep -E "^sd|^nvme|^vd")
    
    info+="\nMinimum Requirements:\n"
    info+="- 512MB RAM (2GB+ recommended)\n"
    info+="- 20GB disk space\n"
    info+="- Internet connection\n"
    info+="- x86_64 architecture"
    
    dialog --msgbox "$info" 20 60
}

# Main entry point
main() {
    # Parse arguments
    parse_args "$@"
    
    # Check if running as root
    if [[ $EUID -ne 0 ]]; then
        echo "Error: This script must be run as root"
        echo "Please run: sudo bash arch-easy-install.sh"
        exit 1
    fi
    
    # Initialize configuration
    init_config
    load_config
    
    # Check for dialog
    if ! command -v dialog &>/dev/null; then
        echo "Installing dialog..."
        pacman -Sy --noconfirm dialog &>/dev/null
    fi
    
    # Check for jq (optional, for config management)
    if ! command -v jq &>/dev/null; then
        echo "Installing jq..."
        pacman -Sy --noconfirm jq &>/dev/null || true
    fi
    
    # Initialize logging
    init_logging
    
    log_info "============================================="
    log_info "Arch Linux Easy Installer v2.0 started"
    log_info "Working directory: $SCRIPT_DIR"
    log_info "Log file: $LOG_FILE"
    log_info "============================================="
    
    # Show welcome screen
    dialog --msgbox "Welcome to Arch Linux Easy Installer v2.0!\n\nThis script provides a guided, user-friendly installation for Arch Linux.\n\nNew features in v2.0:\n• Disk encryption support\n• Resume interrupted installations\n• Configuration save/load\n• Dry-run mode\n• Better hardware detection\n• AUR helper installation\n\n⚠ WARNING: This will modify your disk partitions.\nMake sure you have backed up important data.\n\nPress OK to continue." 18 65
    
    # Start main menu
    main_menu
    
    log_info "Installer exited"
}

# Run main function
main "$@"
