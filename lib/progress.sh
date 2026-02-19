#!/bin/bash
#
# Progress indicators and visual feedback
#

# Show a progress bar for commands that support it
show_progress_bar() {
    local title=$1
    local message=$2
    local pid=$3
    local max=${4:-100}
    
    (
        local i=0
        while kill -0 "$pid" 2>/dev/null; do
            if [[ $i -lt $max ]]; then
                ((i+=2))
            fi
            echo "$i"
            sleep 0.5
        done
        echo "100"
    ) | dialog_safe --gauge "$message" 8 70 0
}

# Show installation progress with phase information
show_installation_progress() {
    local current_phase=$1
    local total_phases=$2
    local phase_name=$3
    local percent=$((current_phase * 100 / total_phases))
    
    # Build status message for all phases
    local status_msg="Installation Progress\n\n"
    status_msg+="Phase $current_phase of $total_phases: $phase_name\n\n"
    
    local phases=("Pre-installation checks" "Disk partitioning" "Base installation" 
                  "System configuration" "Bootloader setup" "Desktop installation" "Post-installation")
    
    for i in "${!phases[@]}"; do
        if [[ $i -lt $current_phase ]]; then
            status_msg+="✓ ${phases[$i]}\n"
        elif [[ $i -eq $((current_phase - 1)) ]]; then
            status_msg+"→ ${phases[$i]} (current)\n"
        else
            status_msg+"○ ${phases[$i]}\n"
        fi
    done
    
    # Use simple gauge for whiptail compatibility
    echo "$percent" | dialog_safe --gauge "$status_msg" 15 70 "$percent"
}

# Run command with progress animation
run_with_progress() {
    local title=$1
    local message=$2
    shift 2
    
    (
        "$@" &
        local pid=$!
        
        local spinner=("⠋" "⠙" "⠹" "⠸" "⠼" "⠴" "⠦" "⠧" "⠇" "⠏")
        local i=0
        
        while kill -0 "$pid" 2>/dev/null; do
            echo "XXX"
            echo "${spinner[$i]} $message"
            echo "XXX"
            ((i=(i+1)%10))
            sleep 0.1
        done
        
        wait $pid
        local exit_code=$?
        
        if [[ $exit_code -eq 0 ]]; then
            echo "XXX"
            echo "✓ $message - Complete"
            echo "XXX"
        else
            echo "XXX"
            echo "✗ $message - Failed"
            echo "XXX"
        fi
        
        exit $exit_code
    ) | dialog_safe --gauge "" 8 60 0
}

# Show package installation progress
show_package_progress() {
    local package=$1
    local current=$2
    local total=$3
    
    local percent=$((current * 100 / total))
    local message="Installing package $current of $total:\n$package"
    
    echo "$percent"
    echo "XXX"
    echo "$message"
    echo "XXX"
}

# Run pacman with progress display
run_pacman_with_progress() {
    local operation=$1
    shift
    local packages=("$@")
    local total=${#packages[@]}
    local current=0
    
    (
        for pkg in "${packages[@]}"; do
            ((current++))
            show_package_progress "$pkg" "$current" "$total"
            pacman -S --noconfirm --needed "$pkg" &>/dev/null || true
            sleep 0.5
        done
        echo "100"
    ) | dialog_safe --gauge "Installing packages..." 10 70 0
}

# Create a tailbox dialog for showing command output
show_command_output() {
    local title=$1
    local logfile=$2
    
    # whiptail doesn't have tailbox, use textbox instead or just return
    # For whiptail, we'll show the log at the end instead
    if [[ "$DIALOG_CMD" == "whiptail" ]]; then
        # Just return, we'll show the log differently
        echo ""
        return 0
    fi
    
    dialog_safe --title "$title" --tailbox "$logfile" 20 80 &
    local pid=$!
    
    echo $pid
}

# Update progress in a running tailbox
update_progress_log() {
    local logfile=$1
    local message=$2
    
    echo "[$(date '+%H:%M:%S')] $message" >> "$logfile"
}

# Show ETA estimation
show_eta_progress() {
    local title=$1
    local start_time=$2
    local current=$3
    local total=$4
    
    local elapsed=$(($(date +%s) - start_time))
    local rate=$(echo "scale=2; $current / $elapsed" | bc)
    local remaining=$(echo "scale=0; ($total - $current) / $rate" | bc)
    
    local eta_min=$((remaining / 60))
    local eta_sec=$((remaining % 60))
    
    local percent=$((current * 100 / total))
    
    echo "$percent"
    echo "XXX"
    echo "$title\n\nProgress: $current/$total\nETA: ${eta_min}m ${eta_sec}s"
    echo "XXX"
}

# Multi-step progress indicator
show_multi_step_progress() {
    local title=$1
    shift
    local steps=("$@")
    local total=${#steps[@]}
    
    local current=0
    for step in "${steps[@]}"; do
        ((current++))
        local percent=$((current * 100 / total))
        
        dialog_safe --gauge "$title\n\nStep $current of $total:\n$step" 10 60 "$percent"
        sleep 1
    done
}

# Download progress with curl
download_with_progress() {
    local url=$1
    local output=$2
    local title=${3:-"Downloading"}
    
    (
        curl -L -o "$output" --progress-bar "$url" 2>&1 | \
        while read -r line; do
            if [[ "$line" =~ ^[0-9]+\.[0-9]+ ]]; then
                local percent=$(echo "$line" | grep -oP '^\d+')
                echo "$percent"
            fi
        done
    ) | dialog_safe --gauge "$title" 8 70 0
}
