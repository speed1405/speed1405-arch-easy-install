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

# Initialize logging
init_logging() {
    touch "$LOG_FILE"
    exec 1> >(tee -a "$LOG_FILE")
    exec 2> >(tee -a "$LOG_FILE" >&2)
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
    dialog --msgbox "Error: $1\n\nCheck the log file for details:\n$LOG_FILE" 10 60
    exit 1
}

# Confirm action
confirm_action() {
    local message=$1
    if dialog --yesno "$message" 10 60; then
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
    
    (
        while kill -0 "$pid" 2>/dev/null; do
            echo "XXX"
            echo "Processing..."
            echo "XXX"
            sleep 1
        done
    ) | dialog --gauge "$message" 8 60 0
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
