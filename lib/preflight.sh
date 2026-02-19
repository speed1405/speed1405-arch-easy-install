#!/bin/bash
#
# Pre-flight system checks
#

# Run all pre-flight checks
run_preflight_checks() {
    local checks_passed=0
    local checks_failed=0
    local results=()
    
    dialog_safe --infobox "Running system checks..." 3 40
    
    # Check 1: Root privileges
    if check_root_privileges; then
        results+=("✓ Running as root")
        ((checks_passed++))
    else
        results+=("✗ Not running as root")
        ((checks_failed++))
    fi
    
    # Check 2: Architecture
    if check_architecture; then
        results+=("✓ Architecture: $(uname -m)")
        ((checks_passed++))
    else
        results+=("✗ Unsupported architecture")
        ((checks_failed++))
    fi
    
    # Check 3: Boot mode
    check_boot_mode
    results+=("✓ Boot mode: $BOOT_MODE")
    ((checks_passed++))
    
    # Check 4: RAM
    local ram_check
    if ram_check=$(check_ram); then
        results+=("$ram_check")
        ((checks_passed++))
    else
        results+=("$ram_check")
        ((checks_failed++))
    fi
    
    # Check 5: Internet
    if check_internet; then
        results+=("✓ Internet connection")
        ((checks_passed++))
    else
        results+=("✗ No internet connection")
        ((checks_failed++))
    fi
    
    # Check 6: Disk space
    if check_available_disks; then
        results+=("✓ Disks available")
        ((checks_passed++))
    else
        results+=("✗ No suitable disks found")
        ((checks_failed++))
    fi
    
    # Check 7: Required tools
    if check_required_tools; then
        results+=("✓ Required tools available")
        ((checks_passed++))
    else
        results+=("✗ Missing required tools")
        ((checks_failed++))
    fi
    
    # Check 8: CPU features
    local cpu_check
    cpu_check=$(check_cpu_features)
    results+=("$cpu_check")
    ((checks_passed++))
    
    # Check 9: System time
    if check_system_time; then
        results+=("✓ System time synchronized")
        ((checks_passed++))
    else
        results+=("⚠ System time may not be accurate")
        ((checks_passed++))
    fi
    
    # Display results
    local result_text="Pre-flight Check Results:\n\n"
    for result in "${results[@]}"; do
        result_text+="$result\n"
    done
    
    result_text+="\nPassed: $checks_passed | Failed: $checks_failed"
    
    if [[ $checks_failed -gt 0 ]]; then
        result_text+="\n\n⚠ Some checks failed.\nReview the results before continuing."
        dialog_safe --msgbox "$result_text" 20 70
        return 1
    else
        result_text+="\n\n✓ All checks passed!"
        dialog_safe --msgbox "$result_text" 20 70
        return 0
    fi
}

# Check root privileges
check_root_privileges() {
    if [[ $EUID -eq 0 ]]; then
        return 0
    fi
    return 1
}

# Check architecture
check_architecture() {
    local arch=$(uname -m)
    if [[ "$arch" == "x86_64" ]]; then
        return 0
    fi
    log_warn "Architecture $arch may not be fully supported"
    return 1
}

# Check RAM
check_ram() {
    local total_ram
    local available_ram
    
    total_ram=$(free -m | awk '/^Mem:/ {print $2}')
    available_ram=$(free -m | awk '/^Mem:/ {print $7}')
    
    if [[ $total_ram -lt 1024 ]]; then
        echo "✗ RAM: ${total_ram}MB (512MB minimum, 2GB+ recommended)"
        return 1
    elif [[ $total_ram -lt 2048 ]]; then
        echo "⚠ RAM: ${total_ram}MB (2GB+ recommended for desktop)"
        return 0
    else
        echo "✓ RAM: ${total_ram}MB"
        return 0
    fi
}

# Check available disks
check_available_disks() {
    local min_size_mb=20480  # 20GB minimum
    local found=0
    
    while read -r disk size; do
        local size_mb
        size_mb=$(echo "$size" | sed 's/G/*1024/g; s/M//g' | bc 2>/dev/null || echo 0)
        
        if [[ $size_mb -ge $min_size_mb ]]; then
            ((found++))
        fi
    done < <(lsblk -d -n -o NAME,SIZE | grep -E "^sd|^nvme|^vd" | awk '{print $1, $2}')
    
    if [[ $found -gt 0 ]]; then
        return 0
    fi
    return 1
}

# Check required tools
check_required_tools() {
    local required=("pacman" "lsblk" "parted" "mkfs.ext4" "dialog")
    local missing=()
    
    for tool in "${required[@]}"; do
        if ! command -v "$tool" &>/dev/null; then
            missing+=("$tool")
        fi
    done
    
    if [[ ${#missing[@]} -eq 0 ]]; then
        return 0
    else
        log_error "Missing required tools: ${missing[*]}"
        return 1
    fi
}

# Check CPU features
check_cpu_features() {
    local features=""
    
    if grep -q "aes" /proc/cpuinfo; then
        features+="AES "
    fi
    
    if grep -q "vmx\|svm" /proc/cpuinfo; then
        features+="Virtualization "
    fi
    
    if grep -q "sse4" /proc/cpuinfo; then
        features+="SSE4 "
    fi
    
    local cpu_model
    cpu_model=$(grep "model name" /proc/cpuinfo | head -1 | cut -d':' -f2 | xargs)
    
    if [[ -n "$features" ]]; then
        echo "✓ CPU: $cpu_model ($features)"
    else
        echo "✓ CPU: $cpu_model"
    fi
}

# Check system time
check_system_time() {
    # Check if time is reasonable (after 2020)
    local year
    year=$(date +%Y)
    
    if [[ $year -ge 2020 ]]; then
        # Try to sync with NTP
        if command -v timedatectl &>/dev/null; then
            timedatectl set-ntp true &>/dev/null
        fi
        return 0
    fi
    return 1
}

# Check disk health (basic)
check_disk_health() {
    local disk=$1
    
    log_info "Checking disk health for $disk"
    
    if ! command -v smartctl &>/dev/null; then
        log_warn "smartmontools not available, skipping disk health check"
        return 0
    fi
    
    # Run short SMART test
    local smart_status
    smart_status=$(smartctl -H "$disk" 2>/dev/null | grep "SMART overall-health")
    
    if echo "$smart_status" | grep -q "PASSED"; then
        log_info "Disk health check passed"
        return 0
    else
        log_warn "Disk health check inconclusive or failed"
        return 1
    fi
}

# Check for existing installations
check_existing_installations() {
    local disk=$1
    local found=0
    
    log_info "Checking for existing installations on $disk"
    
    # Check for common filesystem signatures
    if blkid "$disk"* 2>/dev/null | grep -qE "ext4|btrfs|xfs|ntfs|vfat"; then
        found=1
    fi
    
    # Check partition table
    if parted -s "$disk" print 2>/dev/null | grep -q "Partition Table"; then
        local partition_count
        partition_count=$(parted -s "$disk" print 2>/dev/null | grep -c "^ [0-9]")
        
        if [[ $partition_count -gt 0 ]]; then
            log_warn "Found $partition_count existing partitions on $disk"
            found=1
        fi
    fi
    
    if [[ $found -eq 1 ]]; then
        if dialog_safe --yesno "Existing partitions detected on $disk!\n\nContinuing will ERASE ALL DATA.\n\nAre you sure you want to proceed?" 10 60; then
            return 0
        else
            return 1
        fi
    fi
    
    return 0
}

# Check for virtualization
detect_virtualization() {
    local virt=""
    
    if [[ -d /proc/xen ]]; then
        virt="Xen"
    elif grep -q "hypervisor" /proc/cpuinfo 2>/dev/null; then
        if systemd-detect-virt &>/dev/null; then
            virt=$(systemd-detect-virt)
        else
            virt="VM (unknown type)"
        fi
    fi
    
    if [[ -n "$virt" ]]; then
        log_info "Running in virtualized environment: $virt"
        echo "$virt"
        return 0
    fi
    
    return 1
}

# Benchmark disk speed
benchmark_disk() {
    local disk=$1
    
    log_info "Benchmarking disk $disk"
    
    # Quick read benchmark
    local read_speed
    read_speed=$(hdparm -t "$disk" 2>/dev/null | grep "Timing buffered disk reads" | awk '{print $10 " " $11}')
    
    if [[ -n "$read_speed" ]]; then
        log_info "Disk read speed: $read_speed"
        echo "$read_speed"
    else
        log_warn "Could not benchmark disk"
    fi
}
