#!/bin/bash
#
# Common utilities and functions
#

# Colors for terminal output (fallback when dialog not available)
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Log file
LOG_FILE="/var/log/arch-easy-install.log"
BOOT_MODE=""
INSTALL_DISK=""
HOSTNAME=""
USERNAME=""
TIMEZONE=""
LOCALE=""
KEYBOARD=""
DESKTOP_ENV=""

# Dialog command - will be set after checking availability
DIALOG_CMD=""

# Initialize logging
init_logging() {
    touch "$LOG_FILE"
    exec 1> >(tee -a "$LOG_FILE")
    exec 2> >(tee -a "$LOG_FILE" >&2)
}

# Check and setup dialog
setup_dialog() {
    # Check if we're in a proper TTY
    if [[ ! -t 0 ]] || [[ ! -t 1 ]]; then
        log_warn "Not running in a proper terminal"
    fi
    
    # Check terminal size
    local rows=$(tput lines 2>/dev/null || echo "24")
    local cols=$(tput cols 2>/dev/null || echo "80")
    
    if [[ $rows -lt 24 ]] || [[ $cols -lt 80 ]]; then
        log_warn "Terminal size is ${cols}x${rows}, recommended is at least 80x24"
    fi
    
    # Check if dialog is available
    if command -v dialog &>/dev/null; then
        DIALOG_CMD="dialog"
        log_info "Using dialog for UI"
        return 0
    fi
    
    # Try to install dialog
    log_info "Dialog not found, attempting to install..."
    if pacman -Sy --noconfirm dialog &>/dev/null; then
        DIALOG_CMD="dialog"
        log_info "Dialog installed successfully"
        return 0
    fi
    
    # Check for whiptail as fallback
    if command -v whiptail &>/dev/null; then
        DIALOG_CMD="whiptail"
        log_info "Using whiptail as fallback"
        return 0
    fi
    
    log_error "Neither dialog nor whiptail is available"
    return 1
}

# Wrapper for dialog/whiptail commands
# Usage: dialog_wrapper <command> [args...]
dialog_wrapper() {
    local cmd=$1
    shift
    
    if [[ "$DIALOG_CMD" == "whiptail" ]]; then
        # Convert dialog options to whiptail
        case $cmd in
            --menu)
                # whiptail --menu text height width menu-height [tag item]...
                local title="$1"
                local text="$2"
                local height="$3"
                local width="$4"
                local menu_height="$5"
                shift 5
                # Build menu items differently for whiptail
                local items=()
                while [[ $# -gt 0 ]]; do
                    items+=("$1" "$2")
                    shift 2
                done
                whiptail --title "$title" --menu "$text" "$height" "$width" "$menu_height" "${items[@]}" 3>&1 1>&2 2>&3
                ;;
            --msgbox)
                local text="$1"
                local height="$2"
                local width="$3"
                whiptail --msgbox "$text" "$height" "$width" 3>&1 1>&2 2>&3
                ;;
            --yesno)
                local text="$1"
                local height="$2"
                local width="$3"
                whiptail --yesno "$text" "$height" "$width" 3>&1 1>&2 2>&3
                ;;
            --inputbox)
                local text="$1"
                local height="$2"
                local width="$3"
                local init="${4:-}"
                whiptail --inputbox "$text" "$height" "$width" "$init" 3>&1 1>&2 2>&3
                ;;
            --passwordbox)
                local text="$1"
                local height="$2"
                local width="$3"
                whiptail --passwordbox "$text" "$height" "$width" 3>&1 1>&2 2>&3
                ;;
            --infobox)
                local text="$1"
                local height="$2"
                local width="$3"
                whiptail --infobox "$text" "$height" "$width"
                ;;
            --gauge)
                local text="$1"
                local height="$2"
                local width="$3"
                local percent="${4:-0}"
                # whiptail doesn't have a direct gauge, use infobox with progress
                whiptail --gauge "$text" "$height" "$width" "$percent" 3>&1 1>&2 2>&3
                ;;
            --fselect)
                # whiptail doesn't have fselect, use inputbox as fallback
                local init="$1"
                local height="$2"
                local width="$3"
                whiptail --inputbox "Enter file path:" "$height" "$width" "$init" 3>&1 1>&2 2>&3
                ;;
            --checklist)
                local title="$1"
                local text="$2"
                local height="$3"
                local width="$4"
                local list_height="$5"
                shift 5
                # Build checklist items for whiptail
                local items=()
                while [[ $# -gt 0 ]]; do
                    local tag="$1"
                    local desc="$2"
                    local status="$3"
                    # whiptail uses ON/OFF instead of on/off
                    if [[ "$status" == "on" ]]; then
                        status="ON"
                    else
                        status="OFF"
                    fi
                    items+=("$tag" "$desc" "$status")
                    shift 3
                done
                whiptail --title "$title" --checklist "$text" "$height" "$width" "$list_height" "${items[@]}" 3>&1 1>&2 2>&3
                ;;
            --textbox)
                local file="$1"
                local height="$2"
                local width="$3"
                whiptail --textbox "$file" "$height" "$width" 3>&1 1>&2 2>&3
                ;;
            *)
                # For any other commands, try to pass through
                whiptail "$cmd" "$@" 3>&1 1>&2 2>&3
                ;;
        esac
    else
        # Use standard dialog
        dialog "$cmd" "$@" 3>&1 1>&2 2>&3
    fi
}

# Alternative: Pure text-based fallback when no dialog available
text_menu() {
    local title="$1"
    local text="$2"
    shift 2
    
    echo -e "\n${BLUE}=== $title ===${NC}"
    echo -e "$text\n"
    
    local i=1
    local items=()
    while [[ $# -gt 0 ]]; do
        echo "$i) $2"
        items+=("$1")
        shift 2
        ((i++))
    done
    
    echo -e "\n0) Cancel/Exit"
    echo -n "Enter choice: "
    read -r choice
    
    if [[ "$choice" == "0" ]]; then
        return 1
    elif [[ "$choice" =~ ^[0-9]+$ ]] && [[ $choice -le ${#items[@]} ]]; then
        echo "${items[$((choice-1))]}"
        return 0
    else
        return 1
    fi
}

text_input() {
    local prompt="$1"
    local default="${2:-}"
    
    echo -e "\n${BLUE}$prompt${NC}"
    if [[ -n "$default" ]]; then
        echo -n "[$default]: "
    else
        echo -n ": "
    fi
    read -r input
    
    if [[ -z "$input" ]] && [[ -n "$default" ]]; then
        echo "$default"
    else
        echo "$input"
    fi
}

text_yesno() {
    local prompt="$1"
    
    echo -e "\n${BLUE}$prompt${NC} (y/N): "
    read -r response
    
    if [[ "$response" =~ ^[Yy]$ ]]; then
        return 0
    else
        return 1
    fi
}

text_msg() {
    local text="$1"
    echo -e "\n${GREEN}$text${NC}"
    echo "Press Enter to continue..."
    read -r
}

# Safe dialog wrapper that handles errors
dialog_safe() {
    local result
    local exit_code
    
    if [[ -z "$DIALOG_CMD" ]]; then
        # Fallback to text mode
        case $1 in
            --menu)
                shift
                local title="$1"
                local text="$2"
                shift 3  # skip height, width
                local menu_height="$1"
                shift
                text_menu "$title" "$text" "$@"
                return $?
                ;;
            --inputbox)
                shift
                local text="$1"
                shift 2  # skip height, width
                local init="$1"
                text_input "$text" "$init"
                return 0
                ;;
            --yesno)
                shift
                local text="$1"
                text_yesno "$text"
                return $?
                ;;
            --msgbox)
                shift
                local text="$1"
                text_msg "$text"
                return 0
                ;;
            *)
                log_warn "Dialog command '$1' not supported in text mode"
                return 1
                ;;
        esac
    fi
    
    # Use dialog/whiptail
    result=$(dialog_wrapper "$@" 2>/dev/null)
    exit_code=$?
    
    if [[ $exit_code -eq 0 ]]; then
        echo "$result"
        return 0
    else
        return 1
    fi
}

# Logging functions
log_info() {
    echo "[INFO] $(date '+%Y-%m-%d %H:%M:%S') - $1" | tee -a "$LOG_FILE"
}

log_warn() {
    echo "[WARN] $(date '+%Y-%m-%d %H:%M:%S') - $1" | tee -a "$LOG_FILE"
}

log_error() {
    echo "[ERROR] $(date '+%Y-%m-%d %H:%M:%S') - $1" | tee -a "$LOG_FILE"
}

# Check boot mode (UEFI or BIOS)
check_boot_mode() {
    if [[ -d /sys/firmware/efi/efivars ]]; then
        BOOT_MODE="UEFI"
        log_info "Boot mode: UEFI"
    else
        BOOT_MODE="BIOS"
        log_info "Boot mode: BIOS/Legacy"
    fi
}

# Check internet connectivity
check_internet() {
    if ping -c 1 archlinux.org &>/dev/null; then
        log_info "Internet connection: OK"
        return 0
    else
        log_warn "Internet connection: FAILED"
        return 1
    fi
}

# Check available disk space
check_disk_space() {
    local disks
    disks=$(lsblk -d -o NAME,SIZE,TYPE | grep disk | awk '{print $1}')
    
    if [[ -z "$disks" ]]; then
        log_error "No disks found"
        return 1
    fi
    
    log_info "Available disks: $disks"
    return 0
}

# Get list of available disks
get_available_disks() {
    lsblk -d -n -o NAME,SIZE,MODEL | grep -v "rom\|loop\|airoot" | while read -r line; do
        name=$(echo "$line" | awk '{print $1}')
        size=$(echo "$line" | awk '{print $2}')
        model=$(echo "$line" | cut -d' ' -f3-)
        echo "/dev/$name" "$size - $model"
    done
}

# Get total memory
get_memory_size() {
    free -m | awk '/^Mem:/ {print $2}'
}

# Format bytes to human readable
human_readable_size() {
    local size=$1
    if [[ $size -gt 1073741824 ]]; then
        echo "$(echo "scale=2; $size/1073741824" | bc) GB"
    elif [[ $size -gt 1048576 ]]; then
        echo "$(echo "scale=2; $size/1048576" | bc) MB"
    else
        echo "$(echo "scale=2; $size/1024" | bc) KB"
    fi
}

# Error handler
error_exit() {
    log_error "$1"
    if [[ -n "$DIALOG_CMD" ]]; then
        dialog_safe --msgbox "Error: $1\n\nCheck the log file for details:\n$LOG_FILE" 10 60
    else
        text_msg "Error: $1"
    fi
    exit 1
}

# Confirm action
confirm_action() {
    local message=$1
    if dialog_safe --yesno "$message" 10 60; then
        return 0
    else
        return 1
    fi
}

# Progress dialog
show_progress() {
    local title=$1
    local message=$2
    local pid=$3
    
    if [[ -n "$DIALOG_CMD" ]]; then
        (
            while kill -0 "$pid" 2>/dev/null; do
                echo "XXX"
                echo "Processing..."
                echo "XXX"
                sleep 1
            done
        ) | dialog_safe --gauge "$message" 8 60 0
    else
        # Text fallback
        echo "$message"
        while kill -0 "$pid" 2>/dev/null; do
            echo -n "."
            sleep 1
        done
        echo " Done!"
    fi
}

# Check if package is installed
is_package_installed() {
    pacman -Qi "$1" &>/dev/null
}

# Get CPU info
get_cpu_info() {
    grep "model name" /proc/cpuinfo | head -1 | cut -d':' -f2 | sed 's/^ *//'
}

# Get GPU info
get_gpu_info() {
    lspci | grep -i vga | cut -d':' -f3 | sed 's/^ *//'
}

# Detect if system is a VM
detect_vm() {
    if [[ -d /proc/xen ]]; then
        echo "Xen"
    elif grep -q "hypervisor" /proc/cpuinfo 2>/dev/null; then
        echo "VM"
    else
        echo "Physical"
    fi
}

# Safe cleanup on exit
cleanup() {
    log_info "Cleaning up..."
    # Unmount any mounted partitions if installation was cancelled
    if [[ -n "$INSTALL_DISK" ]]; then
        umount -R /mnt 2>/dev/null || true
        swapoff -a 2>/dev/null || true
    fi
}

trap cleanup EXIT
