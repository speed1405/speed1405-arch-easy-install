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
export DIALOG_CMD=""

# Initialize logging
init_logging() {
    # Create log directory if it doesn't exist
    local log_dir=$(dirname "$LOG_FILE")
    if [[ ! -d "$log_dir" ]]; then
        mkdir -p "$log_dir" 2>/dev/null || {
            # Fallback to /tmp if we can't create the log directory
            LOG_FILE="/tmp/arch-easy-install.log"
        }
    fi
    touch "$LOG_FILE" 2>/dev/null || true
    # Don't redirect stdout/stderr as it breaks dialog
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
    
    # Try to install both whiptail and dialog
    log_info "Checking for dialog tools..."
    
    # Check if whiptail is available
    if command -v whiptail &>/dev/null; then
        DIALOG_CMD="whiptail"
        export DIALOG_CMD
        log_info "Using whiptail for UI (already installed)"
        return 0
    fi
    
    # Check if dialog is available
    if command -v dialog &>/dev/null; then
        DIALOG_CMD="dialog"
        export DIALOG_CMD
        log_info "Using dialog for UI (already installed)"
        return 0
    fi
    
    # Neither is available, try to install
    log_info "Installing whiptail and dialog..."
    
    # Update package database
    if ! pacman -Sy &>/dev/null; then
        log_warn "Failed to sync package database"
    fi
    
    # Install whiptail first (preferred)
    if pacman -S --noconfirm whiptail &>/dev/null; then
        if command -v whiptail &>/dev/null; then
            DIALOG_CMD="whiptail"
            export DIALOG_CMD
            log_info "Using whiptail for UI (installed)"
            return 0
        fi
    fi
    
    # Try dialog as fallback
    if pacman -S --noconfirm dialog &>/dev/null; then
        if command -v dialog &>/dev/null; then
            DIALOG_CMD="dialog"
            export DIALOG_CMD
            log_info "Using dialog for UI (installed)"
            return 0
        fi
    fi
    
    log_error "Neither whiptail nor dialog could be installed"
    log_error "Falling back to text-based interface"
    DIALOG_CMD=""
    export DIALOG_CMD
    return 1
}

# Wrapper for dialog/whiptail commands
# Usage: dialog_wrapper [options] --<command> [args...]
dialog_wrapper() {
    if [[ "$DIALOG_CMD" == "whiptail" ]]; then
        # Build whiptail command, filtering unsupported options
        local args=()
        local i=0
        while [[ $# -gt 0 ]]; do
            case "$1" in
                --clear)
                    # Skip - not supported by whiptail
                    shift
                    ;;
                --title)
                    args+=("--title" "$2")
                    shift 2
                    ;;
                --backtitle)
                    # Skip - not supported by whiptail  
                    shift 2
                    ;;
                --menu)
                    # whiptail --menu uses same syntax as dialog
                    args+=("--menu" "$2" "$3" "$4" "$5")
                    shift 5
                    # Add remaining menu items
                    while [[ $# -gt 0 ]]; do
                        args+=("$1" "$2")
                        shift 2
                    done
                    ;;
                --checklist)
                    # Convert on/off to ON/OFF for whiptail
                    args+=("--checklist" "$2" "$3" "$4" "$5")
                    shift 5
                    while [[ $# -gt 0 ]]; do
                        local tag="$1" desc="$2" status="$3"
                        [[ "$status" == "on" ]] && status="ON"
                        [[ "$status" == "off" ]] && status="OFF"
                        args+=("$tag" "$desc" "$status")
                        shift 3
                    done
                    ;;
                --radiolist)
                    args+=("--radiolist" "$2" "$3" "$4" "$5")
                    shift 5
                    while [[ $# -gt 0 ]]; do
                        local tag="$1" desc="$2" status="$3"
                        [[ "$status" == "on" ]] && status="ON"
                        [[ "$status" == "off" ]] && status="OFF"
                        args+=("$tag" "$desc" "$status")
                        shift 3
                    done
                    ;;
                --msgbox|--yesno|--infobox|--inputbox|--passwordbox)
                    args+=("$1" "$2" "$3" "$4")
                    shift 4
                    ;;
                --gauge)
                    args+=("--gauge" "$2" "$3" "$4" "$5")
                    shift 5
                    ;;
                --textbox)
                    args+=("--textbox" "$2" "$3" "$4")
                    shift 4
                    ;;
                --fselect)
                    # whiptail doesn't have fselect, use inputbox
                    args+=("--inputbox" "Enter file path:" "$3" "$4" "$2")
                    shift 4
                    ;;
                *)
                    args+=("$1")
                    shift
                    ;;
            esac
        done
        whiptail "${args[@]}" 3>&1 1>&2 2>&3
    else
        dialog "$@" 3>&1 1>&2 2>&3
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
    
    # Filter out --clear option (not supported by whiptail, ignored by dialog)
    local args=()
    while [[ $# -gt 0 ]]; do
        if [[ "$1" != "--clear" ]]; then
            args+=("$1")
        fi
        shift
    done
    set -- "${args[@]}"
    
    if [[ -z "$DIALOG_CMD" ]]; then
        # Fallback to text mode - parse dialog-style arguments
        local title=""
        local text=""
        local height=""
        local width=""
        local menu_height=""
        
        # Parse options
        while [[ $# -gt 0 ]]; do
            case "$1" in
                --title)
                    title="$2"
                    shift 2
                    ;;
                --backtitle)
                    shift 2
                    ;;
                --menu)
                    shift
                    text="$1"
                    height="$2"
                    width="$3"
                    menu_height="$4"
                    shift 4
                    # Remaining argsuiments are menu items
                    text_menu "$title" "$text" "$@"
                    return $?
                    ;;
                --msgbox)
                    shift
                    text="$1"
                    text_msg "$text"
                    return 0
                    ;;
                --yesno)
                    shift
                    text="$1"
                    text_yesno "$text"
                    return $?
                    ;;
                --inputbox)
                    shift
                    text="$1"
                    shift 2
                    local init="$1"
                    text_input "$text" "$init"
                    return 0
                    ;;
                *)
                    shift
                    ;;
            esac
        done
        
        log_warn "Dialog command not recognized in text mode"
        return 1
    fi
    
    # Use dialog/whiptail directly without capturing output for simple dialogs
    case $1 in
        --msgbox|--yesno|--infobox)
            dialog_wrapper "$@"
            return $?
            ;;
        --gauge)
            result=$(dialog_wrapper "$@")
            exit_code=$?
            if [[ $exit_code -eq 0 ]]; then
                echo "$result"
            fi
            return $exit_code
            ;;
        *)
            result=$(dialog_wrapper "$@")
            exit_code=$?
            if [[ $exit_code -eq 0 ]]; then
                echo "$result"
            fi
            return $exit_code
            ;;
    esac
}

# Logging functions
log_info() {
    local msg="[INFO] $(date '+%Y-%m-%d %H:%M:%S') - $1"
    echo "$msg"
    if [[ -w "$LOG_FILE" ]] || [[ -w $(dirname "$LOG_FILE") ]]; then
        echo "$msg" >> "$LOG_FILE" 2>/dev/null || true
    fi
}

log_warn() {
    local msg="[WARN] $(date '+%Y-%m-%d %H:%M:%S') - $1"
    echo "$msg"
    if [[ -w "$LOG_FILE" ]] || [[ -w $(dirname "$LOG_FILE") ]]; then
        echo "$msg" >> "$LOG_FILE" 2>/dev/null || true
    fi
}

log_error() {
    local msg="[ERROR] $(date '+%Y-%m-%d %H:%M:%S') - $1"
    echo "$msg" >&2
    if [[ -w "$LOG_FILE" ]] || [[ -w $(dirname "$LOG_FILE") ]]; then
        echo "$msg" >> "$LOG_FILE" 2>/dev/null || true
    fi
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
