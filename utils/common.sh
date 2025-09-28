#!/bin/bash

# Common utilities and functions for r3con VAPT Suite
# Shared functions across all modules

# Color definitions
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
WHITE='\033[1;37m'
NC='\033[0m' # No Color

# Banner function
show_banner() {
    echo -e "${CYAN}"
    cat << "EOF"
                 ____                        
    _____  _____/  _/_____  ____  ____ ___  
   / ___/ / ___/   // ___/_/ ___\/  _ `/  \ 
  / /    / /  __   // /__  / /_/\/ ___/ /\ \
 /_/    /_/  /___/_/\___/  \____/\___//_/\_\
                                            
    Modular VAPT Reconnaissance Suite v2.0
    Advanced Security Testing Framework
EOF
    echo -e "${NC}"
}

# Logging functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1" | tee -a "$LOG_FILE" 2>/dev/null
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1" | tee -a "$LOG_FILE" 2>/dev/null
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1" | tee -a "$LOG_FILE" 2>/dev/null
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1" | tee -a "$LOG_FILE" 2>/dev/null
}

# Progress bar function
show_progress() {
    local current=$1
    local total=$2
    local width=50
    local percentage=$((current * 100 / total))
    local completed=$((current * width / total))
    local remaining=$((width - completed))
    
    printf "\r${BLUE}[Progress]${NC} ["
    printf "%*s" $completed | tr ' ' '='
    printf "%*s" $remaining | tr ' ' '-'
    printf "] %d%% (%d/%d)" $percentage $current $total
}

# Domain validation
validate_domain() {
    local domain="$1"
    
    if [[ -z "$domain" ]]; then
        return 1
    fi
    
    # Basic domain regex validation
    if [[ $domain =~ ^[a-zA-Z0-9][a-zA-Z0-9\.-]*\.[a-zA-Z]{2,}$ ]]; then
        return 0
    else
        return 1
    fi
}

# URL validation
validate_url() {
    local url="$1"
    
    if [[ -z "$url" ]]; then
        return 1
    fi
    
    # Basic URL regex validation
    if [[ $url =~ ^https?://[a-zA-Z0-9][a-zA-Z0-9\.-]*\.[a-zA-Z]{2,}.*$ ]]; then
        return 0
    else
        return 1
    fi
}

# Check if file exists and is readable
check_file() {
    local file="$1"
    
    if [[ -f "$file" && -r "$file" ]]; then
        return 0
    else
        return 1
    fi
}

# Check if directory exists and create if not
ensure_directory() {
    local dir="$1"
    
    if [[ ! -d "$dir" ]]; then
        mkdir -p "$dir"
        if [[ $? -eq 0 ]]; then
            log_info "Created directory: $dir"
            return 0
        else
            log_error "Failed to create directory: $dir"
            return 1
        fi
    fi
    return 0
}

# Check if command exists
command_exists() {
    local cmd="$1"
    command -v "$cmd" >/dev/null 2>&1
}

# Check if port is open
check_port() {
    local host="$1"
    local port="$2"
    local timeout="${3:-5}"
    
    if command_exists nc; then
        nc -z -w"$timeout" "$host" "$port" >/dev/null 2>&1
    elif command_exists timeout; then
        timeout "$timeout" bash -c "</dev/tcp/$host/$port" >/dev/null 2>&1
    else
        return 1
    fi
}

# Get public IP address
get_public_ip() {
    local ip=""
    
    # Try multiple services
    for service in "http://httpbin.org/ip" "http://icanhazip.com" "http://ipecho.net/plain"; do
        ip=$(curl -s --max-time 10 "$service" 2>/dev/null | grep -oE '[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}' | head -1)
        if [[ -n "$ip" ]]; then
            echo "$ip"
            return 0
        fi
    done
    
    return 1
}

# Convert seconds to human readable time
seconds_to_time() {
    local seconds="$1"
    local hours=$((seconds / 3600))
    local minutes=$(((seconds % 3600) / 60))
    local secs=$((seconds % 60))
    
    if [[ $hours -gt 0 ]]; then
        printf "%02d:%02d:%02d" $hours $minutes $secs
    else
        printf "%02d:%02d" $minutes $secs
    fi
}

# Generate random string
generate_random_string() {
    local length="${1:-16}"
    local chars="abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
    local result=""
    
    for i in $(seq 1 "$length"); do
        result+="${chars:RANDOM%${#chars}:1}"
    done
    
    echo "$result"
}

# Extract domain from URL
extract_domain() {
    local url="$1"
    echo "$url" | sed -E 's|^https?://||' | sed -E 's|/.*$||' | sed -E 's|:.*$||'
}

# Clean filename for safe storage
clean_filename() {
    local filename="$1"
    echo "$filename" | sed 's/[^a-zA-Z0-9._-]/_/g'
}

# Count lines in file
count_lines() {
    local file="$1"
    if check_file "$file"; then
        wc -l < "$file"
    else
        echo "0"
    fi
}

# Remove duplicates from file
remove_duplicates() {
    local input_file="$1"
    local output_file="$2"
    
    if check_file "$input_file"; then
        sort "$input_file" | uniq > "$output_file"
        return $?
    else
        return 1
    fi
}

# Merge multiple files and remove duplicates
merge_files() {
    local output_file="$1"
    shift
    
    if [ $# -eq 0 ]; then
        return 1
    fi
    
    # Merge all files
    cat "$@" 2>/dev/null | sort | uniq > "$output_file"
    return $?
}

# Check if process is running
is_process_running() {
    local process_name="$1"
    pgrep -f "$process_name" >/dev/null 2>&1
}

# Kill process by name
kill_process() {
    local process_name="$1"
    local signal="${2:-TERM}"
    
    if is_process_running "$process_name"; then
        pkill -"$signal" -f "$process_name"
        return $?
    else
        return 1
    fi
}

# Setup trap for cleanup
setup_trap() {
    local cleanup_function="$1"
    trap "$cleanup_function" EXIT INT TERM
}

# Download file with retry
download_file() {
    local url="$1"
    local output="$2"
    local retries="${3:-3}"
    local timeout="${4:-30}"
    
    for i in $(seq 1 "$retries"); do
        if curl -L -o "$output" --max-time "$timeout" "$url" >/dev/null 2>&1; then
            log_success "Downloaded: $output"
            return 0
        else
            log_warning "Download attempt $i failed for: $url"
            sleep 2
        fi
    done
    
    log_error "Failed to download: $url"
    return 1
}

# Check internet connectivity
check_internet() {
    local test_hosts=("8.8.8.8" "1.1.1.1" "google.com")
    
    for host in "${test_hosts[@]}"; do
        if ping -c 1 -W 5 "$host" >/dev/null 2>&1; then
            return 0
        fi
    done
    
    return 1
}

# Get OS information
get_os_info() {
    if [[ -f /etc/os-release ]]; then
        source /etc/os-release
        echo "$NAME $VERSION_ID"
    elif command_exists lsb_release; then
        lsb_release -d | cut -f2
    elif [[ -f /etc/redhat-release ]]; then
        cat /etc/redhat-release
    elif [[ -f /etc/debian_version ]]; then
        echo "Debian $(cat /etc/debian_version)"
    else
        uname -s
    fi
}

# Check system resources
check_system_resources() {
    local min_ram_gb="${1:-2}"
    local min_disk_gb="${2:-5}"
    
    # Check RAM
    local total_ram_kb=$(grep MemTotal /proc/meminfo | awk '{print $2}')
    local total_ram_gb=$((total_ram_kb / 1024 / 1024))
    
    if [[ $total_ram_gb -lt $min_ram_gb ]]; then
        log_warning "Low RAM: ${total_ram_gb}GB (minimum: ${min_ram_gb}GB)"
    fi
    
    # Check disk space
    local available_disk_gb=$(df . | tail -1 | awk '{print int($4/1024/1024)}')
    
    if [[ $available_disk_gb -lt $min_disk_gb ]]; then
        log_warning "Low disk space: ${available_disk_gb}GB (minimum: ${min_disk_gb}GB)"
    fi
    
    log_info "System resources - RAM: ${total_ram_gb}GB, Disk: ${available_disk_gb}GB"
}

# Initialize module
init_module() {
    local module_name="$1"
    local output_dir="$2"
    
    # Setup logging
    LOG_FILE="$output_dir/${module_name,,}_$(date +%Y%m%d_%H%M%S).log"
    ensure_directory "$(dirname "$LOG_FILE")"
    
    # Log module start
    log_info "Starting module: $module_name"
    log_info "Output directory: $output_dir"
    log_info "Log file: $LOG_FILE"
    log_info "OS: $(get_os_info)"
    log_info "User: $(whoami)"
    log_info "Working directory: $(pwd)"
    
    # Check system resources
    check_system_resources
    
    return 0
}

# Cleanup function
cleanup() {
    log_info "Cleaning up temporary files and processes"
    
    # Kill any background processes we started
    # This is module-specific and should be implemented per module
    
    # Remove temporary files
    if [[ -n "$TEMP_DIR" && -d "$TEMP_DIR" ]]; then
        rm -rf "$TEMP_DIR"
        log_info "Removed temporary directory: $TEMP_DIR"
    fi
    
    log_info "Cleanup completed"
}

# Export functions for use in modules
export -f show_banner log_info log_success log_warning log_error
export -f show_progress validate_domain validate_url check_file ensure_directory
export -f command_exists check_port get_public_ip seconds_to_time
export -f generate_random_string extract_domain clean_filename count_lines
export -f remove_duplicates merge_files is_process_running kill_process
export -f setup_trap download_file check_internet get_os_info
export -f check_system_resources init_module cleanup

# Export color variables
export RED GREEN YELLOW BLUE PURPLE CYAN WHITE NC