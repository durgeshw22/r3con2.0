#!/bin/bash

# Port Scanning Module for r3con VAPT Suite
# Comprehensive network port scanning and service detection

source "$(dirname "$0")/../utils/common.sh" 2>/dev/null || true

MODULE_NAME="Port Scanning"
MODULE_VERSION="1.0"

# Port scanning tools
TOOLS=(
    "nmap:nmap"
    "masscan:masscan"
    "naabu:naabu"
    "rustscan:rustscan"
    "unicornscan:unicornscan"
    "zmap:zmap"
)

# Common port ranges
COMMON_PORTS="21,22,23,25,53,80,110,111,135,139,143,443,993,995,1723,3306,3389,5432,5900,6379"
TOP_1000_PORTS="1-1000"
ALL_PORTS="1-65535"

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
${GREEN}Port Scanning Module${NC}

${BLUE}Usage:${NC}
    $0 -t <target> [options] OR $0 -f <file> [options]

${BLUE}Required (choose one):${NC}
    -t, --target        Target IP/hostname
    -f, --file          File containing targets (one per line)

${BLUE}Options:${NC}
    -o, --output        Output directory (default: results/port-scanning)
    -p, --ports         Port specification (default: top 1000)
                        Examples: 80,443,8080 | 1-1000 | common | all
    --threads           Number of threads (default: 1000)
    --rate              Scan rate (packets per second, default: 1000)
    --timeout           Timeout per port in seconds (default: 3)
    --nmap              Use nmap for port scanning
    --masscan           Use masscan for fast port scanning
    --naabu             Use naabu for port discovery
    --rustscan          Use rustscan for fast scanning
    --unicornscan       Use unicornscan for port scanning
    --zmap              Use zmap for internet-wide scanning
    --tcp               TCP port scanning (default)
    --udp               UDP port scanning
    --syn               SYN stealth scanning
    --connect           TCP connect scanning
    --service-detect    Enable service version detection
    --os-detect         Enable OS detection
    --script-scan       Run default nmap scripts
    --aggressive        Aggressive scanning (OS, version, scripts)
    --stealth           Stealth scanning options
    --no-ping           Skip host discovery
    --fragment          Fragment packets
    --all               Use all available scanners
    -v, --verbose       Verbose output
    -h, --help          Show this help message

${BLUE}Examples:${NC}
    $0 -t 192.168.1.1 --all
    $0 -f targets.txt --nmap --masscan --service-detect
    $0 -t example.com -p 80,443,8080,8443 --aggressive
    $0 -t 192.168.1.0/24 -p all --masscan --rate 5000
EOF
}

# Validate and process port specification
process_ports() {
    local port_spec="$1"
    
    case "$port_spec" in
        "common")
            echo "$COMMON_PORTS"
            ;;
        "top1000"|"top-1000")
            echo "$TOP_1000_PORTS"
            ;;
        "all")
            echo "$ALL_PORTS"
            ;;
        *)
            echo "$port_spec"
            ;;
    esac
}

# Nmap port scanning
run_nmap_scan() {
    local target="$1"
    local output_dir="$2"
    local ports="$3"
    local threads="$4"
    local timeout="$5"
    local scan_type="$6"
    local service_detect="$7"
    local os_detect="$8"
    local script_scan="$9"
    local stealth="${10}"
    local no_ping="${11}"
    local fragment="${12}"
    
    echo -e "${BLUE}[*] Running nmap port scan...${NC}"
    
    local nmap_output="$output_dir/nmap_scan.txt"
    local nmap_xml="$output_dir/nmap_scan.xml"
    local nmap_greppable="$output_dir/nmap_scan.gnmap"
    
    local nmap_args=()
    
    # Target specification
    if [ -f "$target" ]; then
        nmap_args+=(-iL "$target")
    else
        nmap_args+=("$target")
    fi
    
    # Output formats
    nmap_args+=(-oN "$nmap_output")
    nmap_args+=(-oX "$nmap_xml")
    nmap_args+=(-oG "$nmap_greppable")
    
    # Port specification
    if [ -n "$ports" ]; then
        nmap_args+=(-p "$ports")
    else
        nmap_args+=(--top-ports 1000)
    fi
    
    # Scan type
    case "$scan_type" in
        "syn")
            nmap_args+=(-sS)
            ;;
        "connect")
            nmap_args+=(-sT)
            ;;
        "udp")
            nmap_args+=(-sU)
            ;;
        *)
            nmap_args+=(-sS)  # Default to SYN scan
            ;;
    esac
    
    # Performance options
    nmap_args+=(-T4)
    nmap_args+=(--min-parallelism "$threads")
    nmap_args+=(--host-timeout "${timeout}m")
    
    # Detection options
    [ "$service_detect" = true ] && nmap_args+=(-sV)
    [ "$os_detect" = true ] && nmap_args+=(-O)
    [ "$script_scan" = true ] && nmap_args+=(-sC)
    
    # Stealth options
    if [ "$stealth" = true ]; then
        nmap_args+=(-f)  # Fragment packets
        nmap_args+=(--scan-delay 1s)
        nmap_args+=(-T2)  # Polite timing
    fi
    
    # Host discovery
    [ "$no_ping" = true ] && nmap_args+=(-Pn)
    
    # Packet fragmentation
    [ "$fragment" = true ] && nmap_args+=(-f)
    
    # Execute scan
    nmap "${nmap_args[@]}"
    
    # Parse results
    if [ -f "$nmap_output" ]; then
        local open_ports=$(grep -c "open" "$nmap_output" 2>/dev/null || echo "0")
        echo -e "${GREEN}[+] nmap found $open_ports open ports${NC}"
        
        # Extract open ports to separate file
        grep "open" "$nmap_output" > "$output_dir/nmap_open_ports.txt" 2>/dev/null
    fi
}

# Masscan port scanning
run_masscan_scan() {
    local target="$1"
    local output_dir="$2"
    local ports="$3"
    local rate="$4"
    
    echo -e "${BLUE}[*] Running masscan fast port scan...${NC}"
    
    local masscan_output="$output_dir/masscan_scan.txt"
    local masscan_xml="$output_dir/masscan_scan.xml"
    
    local masscan_args=()
    
    # Target specification
    if [ -f "$target" ]; then
        # Read targets from file
        local targets=$(cat "$target" | tr '\n' ' ')
        masscan_args+=($targets)
    else
        masscan_args+=("$target")
    fi
    
    # Port specification
    if [ -n "$ports" ]; then
        masscan_args+=(-p "$ports")
    else
        masscan_args+=(-p 1-1000)
    fi
    
    # Output options
    masscan_args+=(--output-format list)
    masscan_args+=(--output-filename "$masscan_output")
    
    # Performance options
    masscan_args+=(--rate "$rate")
    masscan_args+=(--wait 3)
    
    # Execute scan
    masscan "${masscan_args[@]}"
    
    # Also generate XML output
    masscan "${masscan_args[@]}" --output-format xml --output-filename "$masscan_xml"
    
    # Parse results
    if [ -f "$masscan_output" ]; then
        local open_ports=$(wc -l < "$masscan_output")
        echo -e "${GREEN}[+] masscan found $open_ports open ports${NC}"
    fi
}

# Naabu port scanning
run_naabu_scan() {
    local target="$1"
    local output_dir="$2"
    local ports="$3"
    local threads="$4"
    local timeout="$5"
    
    echo -e "${BLUE}[*] Running naabu port discovery...${NC}"
    
    local naabu_output="$output_dir/naabu_scan.txt"
    local naabu_json="$output_dir/naabu_scan.json"
    
    local naabu_args=()
    
    # Target specification
    if [ -f "$target" ]; then
        naabu_args+=(-l "$target")
    else
        naabu_args+=(-host "$target")
    fi
    
    # Output options
    naabu_args+=(-o "$naabu_output")
    naabu_args+=(-json -o "$naabu_json")
    
    # Port specification
    if [ -n "$ports" ]; then
        naabu_args+=(-p "$ports")
    else
        naabu_args+=(-top-ports 1000)
    fi
    
    # Performance options
    naabu_args+=(-c "$threads")
    naabu_args+=(-timeout "${timeout}s")
    naabu_args+=(-silent)
    
    # Execute scan
    naabu "${naabu_args[@]}"
    
    # Parse results
    if [ -f "$naabu_output" ]; then
        local open_ports=$(wc -l < "$naabu_output")
        echo -e "${GREEN}[+] naabu found $open_ports open ports${NC}"
    fi
}

# RustScan port scanning
run_rustscan() {
    local target="$1"
    local output_dir="$2"
    local ports="$3"
    local threads="$4"
    local timeout="$5"
    
    echo -e "${BLUE}[*] Running rustscan fast port scanner...${NC}"
    
    local rustscan_output="$output_dir/rustscan_scan.txt"
    
    if command -v rustscan &> /dev/null; then
        local rustscan_args=()
        
        # Target specification
        if [ -f "$target" ]; then
            # RustScan doesn't support file input directly, scan first target
            local first_target=$(head -1 "$target")
            rustscan_args+=(-a "$first_target")
        else
            rustscan_args+=(-a "$target")
        fi
        
        # Port specification
        if [ -n "$ports" ]; then
            rustscan_args+=(-p "$ports")
        fi
        
        # Performance options
        rustscan_args+=(-b "$threads")
        rustscan_args+=(-t "${timeout}000")  # RustScan uses milliseconds
        rustscan_args+=(--no-config)
        
        # Execute scan and save output
        rustscan "${rustscan_args[@]}" > "$rustscan_output" 2>&1
        
        # Parse results
        if [ -f "$rustscan_output" ]; then
            local open_ports=$(grep -c "Open" "$rustscan_output" 2>/dev/null || echo "0")
            echo -e "${GREEN}[+] rustscan found $open_ports open ports${NC}"
        fi
    else
        echo -e "${YELLOW}[!] rustscan not available, skipping...${NC}"
    fi
}

# Unicornscan port scanning
run_unicornscan() {
    local target="$1"
    local output_dir="$2"
    local ports="$3"
    local rate="$4"
    
    echo -e "${BLUE}[*] Running unicornscan...${NC}"
    
    local unicorn_output="$output_dir/unicornscan_scan.txt"
    
    if command -v unicornscan &> /dev/null; then
        local unicorn_args=()
        
        # Scan type and target
        unicorn_args+=(-mT)  # TCP scan
        
        # Port specification
        if [ -n "$ports" ]; then
            unicorn_args+=(-p "$ports")
        else
            unicorn_args+=(-p 1-1000)
        fi
        
        # Performance
        unicorn_args+=(-r "$rate")
        
        # Target
        if [ -f "$target" ]; then
            local first_target=$(head -1 "$target")
            unicorn_args+=("$first_target")
        else
            unicorn_args+=("$target")
        fi
        
        # Execute scan
        unicornscan "${unicorn_args[@]}" > "$unicorn_output" 2>&1
        
        # Parse results
        if [ -f "$unicorn_output" ]; then
            local open_ports=$(grep -c "open" "$unicorn_output" 2>/dev/null || echo "0")
            echo -e "${GREEN}[+] unicornscan found $open_ports open ports${NC}"
        fi
    else
        echo -e "${YELLOW}[!] unicornscan not available, skipping...${NC}"
    fi
}

# ZMap scanning (for single ports across networks)
run_zmap_scan() {
    local target="$1"
    local output_dir="$2"
    local port="$3"
    local rate="$4"
    
    echo -e "${BLUE}[*] Running zmap for network scanning...${NC}"
    
    local zmap_output="$output_dir/zmap_scan.txt"
    
    if command -v zmap &> /dev/null; then
        # ZMap is designed for scanning single ports across networks
        local scan_port="80"  # Default to HTTP
        
        if [[ "$port" =~ ^[0-9]+$ ]]; then
            scan_port="$port"
        elif [[ "$port" =~ ^[0-9]+, ]]; then
            scan_port=$(echo "$port" | cut -d',' -f1)
        fi
        
        echo -e "${BLUE}[*] Scanning port $scan_port across network...${NC}"
        
        # Only scan if target looks like a network
        if [[ "$target" =~ /[0-9]+$ ]] || [[ "$target" =~ \*$ ]]; then
            zmap -p "$scan_port" -r "$rate" -o "$zmap_output" "$target" 2>/dev/null
            
            if [ -f "$zmap_output" ]; then
                local host_count=$(wc -l < "$zmap_output")
                echo -e "${GREEN}[+] zmap found $host_count hosts with port $scan_port open${NC}"
            fi
        else
            echo -e "${YELLOW}[!] zmap requires network targets (e.g., 192.168.1.0/24)${NC}"
        fi
    else
        echo -e "${YELLOW}[!] zmap not available, skipping...${NC}"
    fi
}

# Service detection on discovered ports
run_service_detection() {
    local target="$1"
    local output_dir="$2"
    local open_ports_file="$3"
    
    echo -e "${BLUE}[*] Running service detection on discovered ports...${NC}"
    
    local service_output="$output_dir/service_detection.txt"
    
    if [ -f "$open_ports_file" ] && [ -s "$open_ports_file" ]; then
        # Extract unique ports from all scan results
        local discovered_ports=$(cat "$output_dir"/*_scan.txt 2>/dev/null | \
            grep -oE '[0-9]+/tcp|[0-9]+/udp' | \
            cut -d'/' -f1 | sort -n | uniq | tr '\n' ',' | sed 's/,$//')
        
        if [ -n "$discovered_ports" ]; then
            echo -e "${BLUE}[*] Detecting services on ports: $discovered_ports${NC}"
            
            nmap -sV -sC -p "$discovered_ports" \
                 -oN "$service_output" \
                 --version-intensity 9 \
                 "$target"
            
            if [ -f "$service_output" ]; then
                echo -e "${GREEN}[+] Service detection completed${NC}"
            fi
        fi
    else
        echo -e "${YELLOW}[!] No open ports found for service detection${NC}"
    fi
}

# Merge and analyze scan results
analyze_scan_results() {
    local output_dir="$1"
    local target="$2"
    
    echo -e "${BLUE}[*] Analyzing port scan results...${NC}"
    
    local analysis_file="$output_dir/port_scan_analysis.txt"
    
    cat > "$analysis_file" << EOF
Port Scan Analysis for: $target
Generated: $(date)
==============================

EOF
    
    # Combine all open ports
    local all_ports_file="$output_dir/all_open_ports.txt"
    
    {
        [ -f "$output_dir/nmap_open_ports.txt" ] && cat "$output_dir/nmap_open_ports.txt"
        [ -f "$output_dir/masscan_scan.txt" ] && cat "$output_dir/masscan_scan.txt"
        [ -f "$output_dir/naabu_scan.txt" ] && cat "$output_dir/naabu_scan.txt"
        [ -f "$output_dir/rustscan_scan.txt" ] && grep "Open" "$output_dir/rustscan_scan.txt"
        [ -f "$output_dir/unicornscan_scan.txt" ] && grep "open" "$output_dir/unicornscan_scan.txt"
    } | sort -u > "$all_ports_file"
    
    # Port statistics
    echo "=== Port Statistics ===" >> "$analysis_file"
    
    if [ -s "$all_ports_file" ]; then
        local total_ports=$(wc -l < "$all_ports_file")
        echo "Total unique open ports: $total_ports" >> "$analysis_file"
        echo "" >> "$analysis_file"
        
        # Common service ports
        echo "=== Common Services Detected ===" >> "$analysis_file"
        
        local common_services=(
            "21:FTP"
            "22:SSH"
            "23:Telnet"
            "25:SMTP"
            "53:DNS"
            "80:HTTP"
            "110:POP3"
            "143:IMAP"
            "443:HTTPS"
            "993:IMAPS"
            "995:POP3S"
            "3306:MySQL"
            "3389:RDP"
            "5432:PostgreSQL"
            "6379:Redis"
        )
        
        for service in "${common_services[@]}"; do
            local port="${service%%:*}"
            local service_name="${service##*:}"
            
            if grep -q ":$port\|/$port\|port $port" "$all_ports_file"; then
                echo "$service_name (port $port): OPEN" >> "$analysis_file"
            fi
        done
        
        echo "" >> "$analysis_file"
        
        # Port ranges analysis
        echo "=== Port Range Analysis ===" >> "$analysis_file"
        
        local well_known=$(grep -E ":[1-9][0-9]{0,2}[^0-9]|/[1-9][0-9]{0,2}[^0-9]" "$all_ports_file" | wc -l)
        local registered=$(grep -E ":(102[4-9]|10[3-9][0-9]|1[1-9][0-9]{2}|[2-9][0-9]{3}|[1-4][0-9]{4}|4916[0-7])" "$all_ports_file" | wc -l)
        local dynamic=$(grep -E ":(4916[8-9]|491[7-9][0-9]|49[2-9][0-9]{2}|[5-9][0-9]{4}|6[0-4][0-9]{3}|65[0-4][0-9]{2}|655[0-2][0-9]|6553[0-5])" "$all_ports_file" | wc -l)
        
        echo "Well-known ports (1-1023): $well_known" >> "$analysis_file"
        echo "Registered ports (1024-49151): $registered" >> "$analysis_file"
        echo "Dynamic ports (49152-65535): $dynamic" >> "$analysis_file"
        
    else
        echo "No open ports detected" >> "$analysis_file"
    fi
    
    echo "" >> "$analysis_file"
    
    # Scanner comparison
    echo "=== Scanner Results Comparison ===" >> "$analysis_file"
    
    [ -f "$output_dir/nmap_scan.txt" ] && echo "nmap: $(grep -c "open" "$output_dir/nmap_scan.txt" 2>/dev/null || echo "0") ports" >> "$analysis_file"
    [ -f "$output_dir/masscan_scan.txt" ] && echo "masscan: $(wc -l < "$output_dir/masscan_scan.txt") ports" >> "$analysis_file"
    [ -f "$output_dir/naabu_scan.txt" ] && echo "naabu: $(wc -l < "$output_dir/naabu_scan.txt") ports" >> "$analysis_file"
    [ -f "$output_dir/rustscan_scan.txt" ] && echo "rustscan: $(grep -c "Open" "$output_dir/rustscan_scan.txt" 2>/dev/null || echo "0") ports" >> "$analysis_file"
    [ -f "$output_dir/unicornscan_scan.txt" ] && echo "unicornscan: $(grep -c "open" "$output_dir/unicornscan_scan.txt" 2>/dev/null || echo "0") ports" >> "$analysis_file"
    
    echo -e "${GREEN}[+] Port scan analysis saved to: $analysis_file${NC}"
}

# Generate summary report
generate_summary() {
    local output_dir="$1"
    local target="$2"
    
    echo -e "${BLUE}[*] Generating port scanning summary...${NC}"
    
    local summary_file="$output_dir/port_scan_summary.txt"
    
    cat > "$summary_file" << EOF
Port Scanning Summary for: $target
Generated: $(date)
==================================

EOF
    
    # Scan results summary
    {
        echo "=== Scan Results Summary ==="
        
        # Count results from each scanner
        [ -f "$output_dir/nmap_scan.txt" ] && echo "nmap scan: $(grep -c "open" "$output_dir/nmap_scan.txt" 2>/dev/null || echo "0") open ports"
        [ -f "$output_dir/masscan_scan.txt" ] && echo "masscan scan: $(wc -l < "$output_dir/masscan_scan.txt") open ports"
        [ -f "$output_dir/naabu_scan.txt" ] && echo "naabu scan: $(wc -l < "$output_dir/naabu_scan.txt") open ports"
        [ -f "$output_dir/rustscan_scan.txt" ] && echo "rustscan scan: $(grep -c "Open" "$output_dir/rustscan_scan.txt" 2>/dev/null || echo "0") open ports"
        [ -f "$output_dir/unicornscan_scan.txt" ] && echo "unicornscan scan: $(grep -c "open" "$output_dir/unicornscan_scan.txt" 2>/dev/null || echo "0") open ports"
        [ -f "$output_dir/zmap_scan.txt" ] && echo "zmap scan: $(wc -l < "$output_dir/zmap_scan.txt") responsive hosts"
        
        echo ""
        
        # Total unique ports
        if [ -f "$output_dir/all_open_ports.txt" ]; then
            echo "Total unique open ports: $(wc -l < "$output_dir/all_open_ports.txt")"
        fi
        
        # Service detection
        if [ -f "$output_dir/service_detection.txt" ]; then
            echo "Service detection: Completed"
            local services=$(grep -c "open" "$output_dir/service_detection.txt" 2>/dev/null || echo "0")
            echo "Services identified: $services"
        fi
        
        echo ""
        
        echo "=== Files Generated ==="
        find "$output_dir" -name "*.txt" -o -name "*.xml" -o -name "*.json" -o -name "*.gnmap" | wc -l | xargs echo "Total output files:"
    } >> "$summary_file"
    
    echo -e "${GREEN}[+] Summary report saved to: $summary_file${NC}"
}

# Main execution function
main() {
    local target=""
    local target_file=""
    local output_dir=""
    local ports=""
    local threads=1000
    local rate=1000
    local timeout=3
    local scan_type="tcp"
    local use_nmap=false
    local use_masscan=false
    local use_naabu=false
    local use_rustscan=false
    local use_unicornscan=false
    local use_zmap=false
    local tcp_scan=true
    local udp_scan=false
    local syn_scan=false
    local connect_scan=false
    local service_detect=false
    local os_detect=false
    local script_scan=false
    local aggressive=false
    local stealth=false
    local no_ping=false
    local fragment=false
    local run_all=false
    local verbose=false
    
    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            -t|--target)
                target="$2"
                shift 2
                ;;
            -f|--file)
                target_file="$2"
                shift 2
                ;;
            -o|--output)
                output_dir="$2"
                shift 2
                ;;
            -p|--ports)
                ports="$2"
                shift 2
                ;;
            --threads)
                threads="$2"
                shift 2
                ;;
            --rate)
                rate="$2"
                shift 2
                ;;
            --timeout)
                timeout="$2"
                shift 2
                ;;
            --nmap)
                use_nmap=true
                shift
                ;;
            --masscan)
                use_masscan=true
                shift
                ;;
            --naabu)
                use_naabu=true
                shift
                ;;
            --rustscan)
                use_rustscan=true
                shift
                ;;
            --unicornscan)
                use_unicornscan=true
                shift
                ;;
            --zmap)
                use_zmap=true
                shift
                ;;
            --tcp)
                tcp_scan=true
                scan_type="tcp"
                shift
                ;;
            --udp)
                udp_scan=true
                scan_type="udp"
                shift
                ;;
            --syn)
                syn_scan=true
                scan_type="syn"
                shift
                ;;
            --connect)
                connect_scan=true
                scan_type="connect"
                shift
                ;;
            --service-detect)
                service_detect=true
                shift
                ;;
            --os-detect)
                os_detect=true
                shift
                ;;
            --script-scan)
                script_scan=true
                shift
                ;;
            --aggressive)
                aggressive=true
                service_detect=true
                os_detect=true
                script_scan=true
                shift
                ;;
            --stealth)
                stealth=true
                shift
                ;;
            --no-ping)
                no_ping=true
                shift
                ;;
            --fragment)
                fragment=true
                shift
                ;;
            --all)
                run_all=true
                shift
                ;;
            -v|--verbose)
                verbose=true
                shift
                ;;
            -h|--help)
                show_help
                exit 0
                ;;
            *)
                echo -e "${RED}[!] Unknown option: $1${NC}"
                show_help
                exit 1
                ;;
        esac
    done
    
    # Validate required arguments
    if [ -z "$target" ] && [ -z "$target_file" ]; then
        echo -e "${RED}[!] Either target (-t) or target file (-f) is required${NC}"
        show_help
        exit 1
    fi
    
    # Use file or create temp file for single target
    local scan_target="$target_file"
    if [ -n "$target" ]; then
        scan_target="/tmp/port_scan_target_$$"
        echo "$target" > "$scan_target"
    fi
    
    # Check if target file exists
    if [ ! -f "$scan_target" ]; then
        echo -e "${RED}[!] Target file not found: $scan_target${NC}"
        exit 1
    fi
    
    # Process port specification
    if [ -n "$ports" ]; then
        ports=$(process_ports "$ports")
    fi
    
    # Set default output directory
    if [ -z "$output_dir" ]; then
        if [ -n "$target" ]; then
            local safe_target=$(echo "$target" | sed 's|[^a-zA-Z0-9._-]|_|g')
            output_dir="results/port-scanning/$safe_target"
        else
            output_dir="results/port-scanning/$(basename "$target_file" .txt)"
        fi
    fi
    
    # Create output directory
    mkdir -p "$output_dir"
    
    # Check tools
    if ! check_tools; then
        exit 1
    fi
    
    echo -e "${GREEN}[+] Starting port scanning...${NC}"
    [ -n "$target" ] && echo -e "${BLUE}[*] Target: $target${NC}"
    [ -n "$target_file" ] && echo -e "${BLUE}[*] Target file: $target_file${NC}"
    echo -e "${BLUE}[*] Output directory: $output_dir${NC}"
    echo -e "${BLUE}[*] Ports: ${ports:-"top 1000"}${NC}"
    echo -e "${BLUE}[*] Scan type: $scan_type${NC}"
    echo -e "${BLUE}[*] Threads: $threads${NC}"
    echo -e "${BLUE}[*] Rate: $rate pps${NC}"
    
    # Run scanners based on flags
    if [ "$run_all" = true ]; then
        use_nmap=true
        use_masscan=true
        use_naabu=true
        use_rustscan=true
        use_unicornscan=true
        service_detect=true
    fi
    
    # If no specific scanners selected, run default set
    if [ "$use_nmap" = false ] && [ "$use_masscan" = false ] && [ "$use_naabu" = false ] && [ "$use_rustscan" = false ] && [ "$use_unicornscan" = false ] && [ "$use_zmap" = false ]; then
        use_nmap=true
        use_masscan=true
        service_detect=true
    fi
    
    # Get first target for single-target scanners
    local first_target=$(head -1 "$scan_target")
    
    # Execute selected scanners
    [ "$use_nmap" = true ] && run_nmap_scan "$first_target" "$output_dir" "$ports" "$threads" "$timeout" "$scan_type" "$service_detect" "$os_detect" "$script_scan" "$stealth" "$no_ping" "$fragment"
    [ "$use_masscan" = true ] && run_masscan_scan "$first_target" "$output_dir" "$ports" "$rate"
    [ "$use_naabu" = true ] && run_naabu_scan "$scan_target" "$output_dir" "$ports" "$threads" "$timeout"
    [ "$use_rustscan" = true ] && run_rustscan "$first_target" "$output_dir" "$ports" "$threads" "$timeout"
    [ "$use_unicornscan" = true ] && run_unicornscan "$first_target" "$output_dir" "$ports" "$rate"
    [ "$use_zmap" = true ] && run_zmap_scan "$first_target" "$output_dir" "$ports" "$rate"
    
    # Service detection on discovered ports
    if [ "$service_detect" = true ]; then
        run_service_detection "$first_target" "$output_dir" "$output_dir/all_open_ports.txt"
    fi
    
    # Analyze results
    analyze_scan_results "$output_dir" "${target:-$target_file}"
    
    # Generate summary
    generate_summary "$output_dir" "${target:-$target_file}"
    
    # Clean up temporary file if created
    if [ -n "$target" ] && [ -f "/tmp/port_scan_target_$$" ]; then
        rm -f "/tmp/port_scan_target_$$"
    fi
    
    echo -e "\n${GREEN}[+] Port Scanning Completed!${NC}"
    echo -e "${BLUE}[*] Results saved in: $output_dir${NC}"
    echo -e "${GREEN}[+] Port scanning completed for ${target:-$target_file}${NC}"
}

# Run main function if script is executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi