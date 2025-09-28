#!/bin/bash

# Anonymity & IP Rotation Module for r3con VAPT Suite
# Provides IP rotation, proxy management, and anonymization features

source "$(dirname "$0")/../utils/common.sh" 2>/dev/null || true

MODULE_NAME="Anonymity & IP Rotation"
MODULE_VERSION="1.0"

# Anonymity tools
TOOLS=(
    "tor:tor"
    "proxychains:proxychains"
    "proxychains4:proxychains4"
    "curl:curl"
    "wget:wget"
)

# Configuration files
TOR_CONFIG="/etc/tor/torrc"
PROXYCHAINS_CONFIG="/etc/proxychains.conf"
PROXYCHAINS4_CONFIG="/etc/proxychains4.conf"

# Tool installation check
check_tools() {
    local missing_tools=()
    
    for tool_def in "${TOOLS[@]}"; do
        tool_name="${tool_def%%:*}"
        if ! command -v "$tool_name" &> /dev/null; then
            missing_tools+=("$tool_name")
        fi
    done
    
    if [ ${#missing_tools[@]} -gt 0 ]; then
        echo -e "${RED}[!] Missing tools: ${missing_tools[*]}${NC}"
        echo -e "${YELLOW}[*] Run the installer to install missing tools${NC}"
        return 1
    fi
    return 0
}

# Help function
show_help() {
    cat << EOF
${GREEN}Anonymity & IP Rotation Module${NC}

${BLUE}Usage:${NC}
    $0 [options] -- <command>

${BLUE}Options:${NC}
    --start-tor         Start Tor service
    --stop-tor          Stop Tor service  
    --restart-tor       Restart Tor service
    --status-tor        Check Tor service status
    --new-identity      Request new Tor identity
    --check-ip          Check current public IP
    --setup-proxychains Configure proxychains for Tor
    --test-proxy        Test proxy configuration
    --rotate-ip         Rotate IP address (restart Tor)
    --proxy-list        Show available proxy configurations
    -o, --output        Output directory for logs
    -v, --verbose       Verbose output
    -h, --help          Show this help message

${BLUE}Command Execution:${NC}
    $0 --start-tor -- nmap -sS target.com
    $0 --rotate-ip -- curl -s http://httpbin.org/ip
    $0 --check-ip

${BLUE}Examples:${NC}
    $0 --start-tor
    $0 --check-ip
    $0 --new-identity
    $0 --setup-proxychains
    $0 --test-proxy
    $0 -- curl -s http://httpbin.org/ip
EOF
}

# Check if running as root
check_root() {
    if [ "$EUID" -ne 0 ]; then
        echo -e "${RED}[!] This module requires root privileges for Tor management${NC}"
        echo -e "${YELLOW}[*] Please run with sudo${NC}"
        return 1
    fi
    return 0
}

# Start Tor service
start_tor() {
    echo -e "${BLUE}[*] Starting Tor service...${NC}"
    
    # Check if Tor is already running
    if systemctl is-active --quiet tor; then
        echo -e "${YELLOW}[*] Tor is already running${NC}"
        return 0
    fi
    
    # Start Tor service
    systemctl start tor
    
    if systemctl is-active --quiet tor; then
        echo -e "${GREEN}[+] Tor service started successfully${NC}"
        sleep 5  # Wait for Tor to establish circuits
        return 0
    else
        echo -e "${RED}[!] Failed to start Tor service${NC}"
        return 1
    fi
}

# Stop Tor service
stop_tor() {
    echo -e "${BLUE}[*] Stopping Tor service...${NC}"
    
    systemctl stop tor
    
    if ! systemctl is-active --quiet tor; then
        echo -e "${GREEN}[+] Tor service stopped successfully${NC}"
        return 0
    else
        echo -e "${RED}[!] Failed to stop Tor service${NC}"
        return 1
    fi
}

# Restart Tor service
restart_tor() {
    echo -e "${BLUE}[*] Restarting Tor service...${NC}"
    
    systemctl restart tor
    
    if systemctl is-active --quiet tor; then
        echo -e "${GREEN}[+] Tor service restarted successfully${NC}"
        sleep 5  # Wait for Tor to establish circuits
        return 0
    else
        echo -e "${RED}[!] Failed to restart Tor service${NC}"
        return 1
    fi
}

# Check Tor service status
check_tor_status() {
    echo -e "${BLUE}[*] Checking Tor service status...${NC}"
    
    if systemctl is-active --quiet tor; then
        echo -e "${GREEN}[+] Tor service is running${NC}"
        
        # Check if control port is accessible
        if nc -z 127.0.0.1 9051 2>/dev/null; then
            echo -e "${GREEN}[+] Tor control port (9051) is accessible${NC}"
        else
            echo -e "${YELLOW}[*] Tor control port (9051) is not accessible${NC}"
        fi
        
        # Check if SOCKS port is accessible
        if nc -z 127.0.0.1 9050 2>/dev/null; then
            echo -e "${GREEN}[+] Tor SOCKS port (9050) is accessible${NC}"
        else
            echo -e "${RED}[!] Tor SOCKS port (9050) is not accessible${NC}"
        fi
        
        return 0
    else
        echo -e "${RED}[!] Tor service is not running${NC}"
        return 1
    fi
}

# Request new Tor identity
new_tor_identity() {
    echo -e "${BLUE}[*] Requesting new Tor identity...${NC}"
    
    # Check if Tor is running
    if ! systemctl is-active --quiet tor; then
        echo -e "${RED}[!] Tor service is not running${NC}"
        return 1
    fi
    
    # Send NEWNYM signal to Tor control port
    if command -v timeout &> /dev/null; then
        echo -e 'AUTHENTICATE ""\r\nSIGNAL NEWNYM\r\nQUIT\r\n' | timeout 10 nc 127.0.0.1 9051
    else
        echo -e 'AUTHENTICATE ""\r\nSIGNAL NEWNYM\r\nQUIT\r\n' | nc 127.0.0.1 9051
    fi
    
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}[+] New Tor identity requested successfully${NC}"
        sleep 3  # Wait for new identity to be established
        return 0
    else
        echo -e "${RED}[!] Failed to request new Tor identity${NC}"
        echo -e "${YELLOW}[*] Trying alternative method...${NC}"
        
        # Alternative: restart Tor service
        restart_tor
        return $?
    fi
}

# Check current public IP
check_current_ip() {
    echo -e "${BLUE}[*] Checking current public IP address...${NC}"
    
    # Direct IP check
    echo -e "${YELLOW}[*] Direct IP:${NC}"
    local direct_ip=$(curl -s --max-time 10 http://httpbin.org/ip | grep -oP '(?<="origin": ")[^"]*' 2>/dev/null)
    if [ -n "$direct_ip" ]; then
        echo -e "${GREEN}[+] $direct_ip${NC}"
    else
        echo -e "${RED}[!] Failed to retrieve direct IP${NC}"
    fi
    
    # Tor IP check (if available)
    if systemctl is-active --quiet tor && command -v proxychains &> /dev/null; then
        echo -e "${YELLOW}[*] Tor IP:${NC}"
        local tor_ip=$(proxychains -q curl -s --max-time 15 http://httpbin.org/ip 2>/dev/null | grep -oP '(?<="origin": ")[^"]*' 2>/dev/null)
        if [ -n "$tor_ip" ]; then
            echo -e "${GREEN}[+] $tor_ip${NC}"
            
            if [ "$direct_ip" != "$tor_ip" ]; then
                echo -e "${GREEN}[+] IP anonymization is working!${NC}"
            else
                echo -e "${RED}[!] Warning: Tor IP matches direct IP${NC}"
            fi
        else
            echo -e "${RED}[!] Failed to retrieve Tor IP${NC}"
        fi
    else
        echo -e "${YELLOW}[*] Tor service not available for IP check${NC}"
    fi
}

# Setup proxychains configuration
setup_proxychains() {
    echo -e "${BLUE}[*] Setting up proxychains configuration...${NC}"
    
    # Check for proxychains4 first, then proxychains
    local config_file=""
    if [ -f "$PROXYCHAINS4_CONFIG" ]; then
        config_file="$PROXYCHAINS4_CONFIG"
    elif [ -f "$PROXYCHAINS_CONFIG" ]; then
        config_file="$PROXYCHAINS_CONFIG"
    else
        echo -e "${RED}[!] Proxychains configuration file not found${NC}"
        return 1
    fi
    
    echo -e "${BLUE}[*] Using configuration file: $config_file${NC}"
    
    # Backup original configuration
    cp "$config_file" "${config_file}.backup.$(date +%s)"
    
    # Create new configuration
    cat > "$config_file" << EOF
# Proxychains configuration for r3con
# Generated by r3con anonymity module

strict_chain
proxy_dns
remote_dns_subnet 224
tcp_read_time_out 15000
tcp_connect_time_out 8000
localnet 127.0.0.0/255.0.0.0
quiet_mode

[ProxyList]
# Tor SOCKS5 proxy
socks5 127.0.0.1 9050
EOF
    
    echo -e "${GREEN}[+] Proxychains configured for Tor${NC}"
    echo -e "${YELLOW}[*] Configuration backed up to: ${config_file}.backup.$(date +%s)${NC}"
    
    return 0
}

# Test proxy configuration
test_proxy() {
    echo -e "${BLUE}[*] Testing proxy configuration...${NC}"
    
    # Check if Tor is running
    if ! systemctl is-active --quiet tor; then
        echo -e "${RED}[!] Tor service is not running${NC}"
        echo -e "${YELLOW}[*] Starting Tor service...${NC}"
        start_tor
        if [ $? -ne 0 ]; then
            return 1
        fi
    fi
    
    # Test proxychains
    if command -v proxychains4 &> /dev/null; then
        echo -e "${BLUE}[*] Testing proxychains4...${NC}"
        local test_result=$(proxychains4 -q curl -s --max-time 10 http://httpbin.org/ip 2>/dev/null)
    elif command -v proxychains &> /dev/null; then
        echo -e "${BLUE}[*] Testing proxychains...${NC}"
        local test_result=$(proxychains -q curl -s --max-time 10 http://httpbin.org/ip 2>/dev/null)
    else
        echo -e "${RED}[!] Proxychains not available${NC}"
        return 1
    fi
    
    if [ -n "$test_result" ]; then
        local proxy_ip=$(echo "$test_result" | grep -oP '(?<="origin": ")[^"]*' 2>/dev/null)
        if [ -n "$proxy_ip" ]; then
            echo -e "${GREEN}[+] Proxy test successful${NC}"
            echo -e "${GREEN}[+] Proxy IP: $proxy_ip${NC}"
            return 0
        fi
    fi
    
    echo -e "${RED}[!] Proxy test failed${NC}"
    return 1
}

# Rotate IP address
rotate_ip() {
    echo -e "${BLUE}[*] Rotating IP address...${NC}"
    
    # Get current IP
    local old_ip=""
    if systemctl is-active --quiet tor && command -v proxychains &> /dev/null; then
        old_ip=$(proxychains -q curl -s --max-time 10 http://httpbin.org/ip 2>/dev/null | grep -oP '(?<="origin": ")[^"]*' 2>/dev/null)
    fi
    
    # Request new identity
    new_tor_identity
    
    # Wait and check new IP
    sleep 5
    local new_ip=""
    if systemctl is-active --quiet tor && command -v proxychains &> /dev/null; then
        new_ip=$(proxychains -q curl -s --max-time 10 http://httpbin.org/ip 2>/dev/null | grep -oP '(?<="origin": ")[^"]*' 2>/dev/null)
    fi
    
    if [ -n "$old_ip" ] && [ -n "$new_ip" ]; then
        echo -e "${BLUE}[*] Old IP: $old_ip${NC}"
        echo -e "${BLUE}[*] New IP: $new_ip${NC}"
        
        if [ "$old_ip" != "$new_ip" ]; then
            echo -e "${GREEN}[+] IP rotation successful!${NC}"
        else
            echo -e "${YELLOW}[*] IP rotation may not have completed yet${NC}"
        fi
    else
        echo -e "${YELLOW}[*] IP rotation requested, but verification failed${NC}"
    fi
}

# Show proxy configurations
show_proxy_list() {
    echo -e "${GREEN}Available Proxy Configurations:${NC}"
    echo ""
    
    echo -e "${BLUE}1. Tor SOCKS5 Proxy${NC}"
    echo "   - Host: 127.0.0.1"
    echo "   - Port: 9050"
    echo "   - Type: SOCKS5"
    echo "   - Status: $(systemctl is-active tor 2>/dev/null || echo 'inactive')"
    echo ""
    
    echo -e "${BLUE}2. Manual Proxy Configuration${NC}"
    echo "   - Edit /etc/proxychains.conf or /etc/proxychains4.conf"
    echo "   - Add custom proxy servers"
    echo "   - Support for HTTP, SOCKS4, SOCKS5"
    echo ""
    
    echo -e "${BLUE}3. Environment Variables${NC}"
    echo "   - HTTP_PROXY=http://proxy:port"
    echo "   - HTTPS_PROXY=https://proxy:port"
    echo "   - SOCKS_PROXY=socks5://proxy:port"
}

# Execute command with proxy
execute_with_proxy() {
    local command="$1"
    
    if [ -z "$command" ]; then
        echo -e "${RED}[!] No command provided${NC}"
        return 1
    fi
    
    echo -e "${BLUE}[*] Executing command with proxy: $command${NC}"
    
    # Check if Tor is running
    if ! systemctl is-active --quiet tor; then
        echo -e "${YELLOW}[*] Starting Tor service...${NC}"
        start_tor
        if [ $? -ne 0 ]; then
            return 1
        fi
    fi
    
    # Execute command through proxychains
    if command -v proxychains4 &> /dev/null; then
        proxychains4 $command
    elif command -v proxychains &> /dev/null; then
        proxychains $command
    else
        echo -e "${RED}[!] Proxychains not available${NC}"
        return 1
    fi
}

# Main execution function
main() {
    local output_dir=""
    local verbose=false
    local command_to_execute=""
    local start_tor_flag=false
    local stop_tor_flag=false
    local restart_tor_flag=false
    local status_tor_flag=false
    local new_identity_flag=false
    local check_ip_flag=false
    local setup_proxychains_flag=false
    local test_proxy_flag=false
    local rotate_ip_flag=false
    local proxy_list_flag=false
    local command_mode=false
    
    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            --start-tor)
                start_tor_flag=true
                shift
                ;;
            --stop-tor)
                stop_tor_flag=true
                shift
                ;;
            --restart-tor)
                restart_tor_flag=true
                shift
                ;;
            --status-tor)
                status_tor_flag=true
                shift
                ;;
            --new-identity)
                new_identity_flag=true
                shift
                ;;
            --check-ip)
                check_ip_flag=true
                shift
                ;;
            --setup-proxychains)
                setup_proxychains_flag=true
                shift
                ;;
            --test-proxy)
                test_proxy_flag=true
                shift
                ;;
            --rotate-ip)
                rotate_ip_flag=true
                shift
                ;;
            --proxy-list)
                proxy_list_flag=true
                shift
                ;;
            -o|--output)
                output_dir="$2"
                shift 2
                ;;
            -v|--verbose)
                verbose=true
                shift
                ;;
            -h|--help)
                show_help
                exit 0
                ;;
            --)
                command_mode=true
                shift
                command_to_execute="$*"
                break
                ;;
            *)
                echo -e "${RED}[!] Unknown option: $1${NC}"
                show_help
                exit 1
                ;;
        esac
    done
    
    # Set default output directory
    if [ -z "$output_dir" ]; then
        output_dir="results/anonymity"
    fi
    
    # Create output directory
    mkdir -p "$output_dir"
    
    # Check tools
    if ! check_tools; then
        exit 1
    fi
    
    echo -e "${GREEN}[+] r3con Anonymity & IP Rotation Module${NC}"
    
    # Execute based on flags
    if [ "$command_mode" = true ]; then
        execute_with_proxy "$command_to_execute"
    elif [ "$start_tor_flag" = true ]; then
        check_root && start_tor
    elif [ "$stop_tor_flag" = true ]; then
        check_root && stop_tor
    elif [ "$restart_tor_flag" = true ]; then
        check_root && restart_tor
    elif [ "$status_tor_flag" = true ]; then
        check_tor_status
    elif [ "$new_identity_flag" = true ]; then
        new_tor_identity
    elif [ "$check_ip_flag" = true ]; then
        check_current_ip
    elif [ "$setup_proxychains_flag" = true ]; then
        check_root && setup_proxychains
    elif [ "$test_proxy_flag" = true ]; then
        test_proxy
    elif [ "$rotate_ip_flag" = true ]; then
        rotate_ip
    elif [ "$proxy_list_flag" = true ]; then
        show_proxy_list
    else
        # Default: show current status
        check_tor_status
        echo ""
        check_current_ip
    fi
}

# Run main function if script is executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi