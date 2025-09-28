#!/bin/bash

# Live Probing Module for r3con VAPT Suite
# Comprehensive live host and service discovery

source "$(dirname "$0")/../utils/common.sh" 2>/dev/null || true

MODULE_NAME="Live Probing"
MODULE_VERSION="1.0"

# Live probing tools
TOOLS=(
    "httpx:httpx"
    "httprobe:httprobe"
    "nmap:nmap"
    "masscan:masscan"
    "naabu:naabu"
    "ping:ping"
    "curl:curl"
    "dig:dig"
)

# Common ports for web services
WEB_PORTS=(80 443 8080 8443 8000 8888 9000 9443 3000 5000 7000 7443 8081 8082 8090 8180 8181 8888 9001 9090 9443)

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
${GREEN}Live Probing Module${NC}

${BLUE}Usage:${NC}
    $0 -f <file> [options] OR $0 -d <domain> [options]

${BLUE}Required (choose one):${NC}
    -f, --file          File containing domains/IPs (one per line)
    -d, --domain        Single domain to probe

${BLUE}Options:${NC}
    -o, --output        Output directory (default: results/live-probing)
    -p, --ports         Custom ports (comma separated, default: web ports)
    -t, --threads       Number of threads (default: 50)
    --timeout           Request timeout in seconds (default: 10)
    --httpx             Use httpx for HTTP probing
    --httprobe          Use httprobe for HTTP probing  
    --nmap              Use nmap for port scanning
    --masscan           Use masscan for fast port scanning
    --naabu             Use naabu for port discovery
    --ping              Use ping for basic connectivity
    --screenshots       Take screenshots of live services
    --tech-detect       Detect technologies on live services
    --title-grab        Extract page titles
    --status-check      Check HTTP status codes
    --ssl-check         Check SSL/TLS information
    --headers           Extract HTTP headers
    --content-length    Check content lengths
    --all               Enable all probing methods
    -v, --verbose       Verbose output
    -h, --help          Show this help message

${BLUE}Examples:${NC}
    $0 -f subdomains.txt --all
    $0 -d example.com --httpx --nmap --screenshots
    $0 -f targets.txt --ports 80,443,8080,8443 --tech-detect
    $0 -d example.com --ssl-check --headers --title-grab
EOF
}

# Basic connectivity check with ping
check_ping() {
    local target="$1"
    local output_dir="$2"
    
    echo -e "${BLUE}[*] Checking basic connectivity with ping...${NC}"
    
    local ping_output="$output_dir/ping_results.txt"
    local live_hosts="$output_dir/live_hosts.txt"
    
    while read -r host; do
        if ping -c 1 -W 2 "$host" &>/dev/null; then
            echo "$host - ALIVE" >> "$ping_output"
            echo "$host" >> "$live_hosts"
        else
            echo "$host - DOWN" >> "$ping_output"
        fi
    done < "$target"
    
    if [ -f "$live_hosts" ]; then
        local count=$(wc -l < "$live_hosts")
        echo -e "${GREEN}[+] Found $count live hosts via ping${NC}"
    fi
}

# HTTP probing with httpx
run_httpx() {
    local target="$1"
    local output_dir="$2"
    local threads="$3"
    local timeout="$4"
    local ports="$5"
    local tech_detect="$6"
    local title_grab="$7"
    local status_check="$8"
    local ssl_check="$9"
    local headers="${10}"
    local content_length="${11}"
    
    echo -e "${BLUE}[*] Running httpx for HTTP probing...${NC}"
    
    local httpx_output="$output_dir/httpx_results.txt"
    local httpx_args=()
    
    httpx_args+=(-l "$target")
    httpx_args+=(-o "$httpx_output")
    httpx_args+=(-threads "$threads")
    httpx_args+=(-timeout "$timeout")
    httpx_args+=(-silent)
    httpx_args+=(-follow-redirects)
    httpx_args+=(-random-agent)
    
    if [ -n "$ports" ]; then
        httpx_args+=(-ports "$ports")
    fi
    
    if [ "$tech_detect" = true ]; then
        httpx_args+=(-tech-detect)
    fi
    
    if [ "$title_grab" = true ]; then
        httpx_args+=(-title)
    fi
    
    if [ "$status_check" = true ]; then
        httpx_args+=(-status-code)
    fi
    
    if [ "$ssl_check" = true ]; then
        httpx_args+=(-tls-probe)
    fi
    
    if [ "$headers" = true ]; then
        httpx_args+=(-response-headers)
    fi
    
    if [ "$content_length" = true ]; then
        httpx_args+=(-content-length)
    fi
    
    httpx "${httpx_args[@]}"
    
    if [ -f "$httpx_output" ]; then
        local count=$(wc -l < "$httpx_output")
        echo -e "${GREEN}[+] httpx found $count live HTTP services${NC}"
        
        # Extract just URLs for further processing
        cat "$httpx_output" | awk '{print $1}' > "$output_dir/live_urls.txt"
    fi
}

# HTTP probing with httprobe
run_httprobe() {
    local target="$1"
    local output_dir="$2"
    local threads="$3"
    local timeout="$4"
    local ports="$5"
    
    echo -e "${BLUE}[*] Running httprobe for HTTP probing...${NC}"
    
    local httprobe_output="$output_dir/httprobe_results.txt"
    local httprobe_args=()
    
    httprobe_args+=(-c "$threads")
    httprobe_args+=(-t "$timeout"000)  # httprobe uses milliseconds
    
    if [ -n "$ports" ]; then
        # Convert comma-separated ports to httprobe format
        local port_args=""
        IFS=',' read -ra port_array <<< "$ports"
        for port in "${port_array[@]}"; do
            port_args="$port_args -p $port"
        done
        httprobe_args+=($port_args)
    else
        # Add common web ports
        for port in "${WEB_PORTS[@]}"; do
            httprobe_args+=(-p "$port")
        done
    fi
    
    cat "$target" | httprobe "${httprobe_args[@]}" > "$httprobe_output"
    
    if [ -f "$httprobe_output" ]; then
        local count=$(wc -l < "$httprobe_output")
        echo -e "${GREEN}[+] httprobe found $count live HTTP services${NC}"
    fi
}

# Port scanning with nmap
run_nmap() {
    local target="$1"
    local output_dir="$2"
    local threads="$3"
    local ports="$4"
    
    echo -e "${BLUE}[*] Running nmap for port scanning...${NC}"
    
    local nmap_output="$output_dir/nmap_results.txt"
    local nmap_xml="$output_dir/nmap_results.xml"
    local nmap_args=()
    
    nmap_args+=(-T4)
    nmap_args+=(-Pn)  # Skip host discovery
    nmap_args+=(-n)   # No DNS resolution
    nmap_args+=(-oN "$nmap_output")
    nmap_args+=(-oX "$nmap_xml")
    
    if [ -n "$ports" ]; then
        nmap_args+=(-p "$ports")
    else
        # Use top 1000 ports
        nmap_args+=(--top-ports 1000)
    fi
    
    nmap_args+=(-iL "$target")
    
    nmap "${nmap_args[@]}"
    
    if [ -f "$nmap_output" ]; then
        local open_ports=$(grep -c "open" "$nmap_output" 2>/dev/null || echo "0")
        echo -e "${GREEN}[+] nmap found $open_ports open ports${NC}"
    fi
}

# Fast port scanning with masscan
run_masscan() {
    local target="$1"
    local output_dir="$2"
    local threads="$3"
    local ports="$4"
    
    echo -e "${BLUE}[*] Running masscan for fast port scanning...${NC}"
    
    local masscan_output="$output_dir/masscan_results.txt"
    local masscan_args=()
    
    masscan_args+=(--rate "$threads"000)
    masscan_args+=(--output-format list)
    masscan_args+=(--output-filename "$masscan_output")
    
    if [ -n "$ports" ]; then
        masscan_args+=(-p "$ports")
    else
        # Use common web ports
        local port_list=$(IFS=','; echo "${WEB_PORTS[*]}")
        masscan_args+=(-p "$port_list")
    fi
    
    # Read targets and run masscan
    while read -r host; do
        masscan "$host" "${masscan_args[@]}" 2>/dev/null
    done < "$target"
    
    if [ -f "$masscan_output" ]; then
        local count=$(wc -l < "$masscan_output")
        echo -e "${GREEN}[+] masscan found $count open ports${NC}"
    fi
}

# Port discovery with naabu
run_naabu() {
    local target="$1"
    local output_dir="$2"
    local threads="$3"
    local ports="$4"
    
    echo -e "${BLUE}[*] Running naabu for port discovery...${NC}"
    
    local naabu_output="$output_dir/naabu_results.txt"
    local naabu_args=()
    
    naabu_args+=(-l "$target")
    naabu_args+=(-o "$naabu_output")
    naabu_args+=(-c "$threads")
    naabu_args+=(-silent)
    
    if [ -n "$ports" ]; then
        naabu_args+=(-p "$ports")
    else
        # Use top ports
        naabu_args+=(-top-ports 1000)
    fi
    
    naabu "${naabu_args[@]}"
    
    if [ -f "$naabu_output" ]; then
        local count=$(wc -l < "$naabu_output")
        echo -e "${GREEN}[+] naabu found $count open ports${NC}"
    fi
}

# Take screenshots of live services
take_screenshots() {
    local urls_file="$1"
    local output_dir="$2"
    
    echo -e "${BLUE}[*] Taking screenshots of live services...${NC}"
    
    local screenshot_dir="$output_dir/screenshots"
    mkdir -p "$screenshot_dir"
    
    # Use gowitness if available
    if command -v gowitness &> /dev/null; then
        gowitness file -f "$urls_file" -P "$screenshot_dir" --disable-logging --delay 2
        echo -e "${GREEN}[+] Screenshots saved to: $screenshot_dir${NC}"
    elif command -v aquatone &> /dev/null; then
        cat "$urls_file" | aquatone -out "$screenshot_dir" -silent
        echo -e "${GREEN}[+] Screenshots saved to: $screenshot_dir${NC}"
    else
        echo -e "${YELLOW}[!] No screenshot tool available (gowitness/aquatone)${NC}"
    fi
}

# Extract detailed information from live services
extract_service_info() {
    local urls_file="$1"
    local output_dir="$2"
    local timeout="$3"
    
    echo -e "${BLUE}[*] Extracting detailed service information...${NC}"
    
    local service_info="$output_dir/service_details.txt"
    
    cat > "$service_info" << EOF
Service Information Report
Generated: $(date)
=========================

EOF
    
    while read -r url; do
        echo "=== $url ===" >> "$service_info"
        
        # Get headers
        echo "HTTP Headers:" >> "$service_info"
        curl -I -s --connect-timeout "$timeout" --max-time "$timeout" "$url" | head -10 >> "$service_info" 2>/dev/null
        echo "" >> "$service_info"
        
        # Get server information
        echo "Server Information:" >> "$service_info"
        curl -s -H "User-Agent: Mozilla/5.0" --connect-timeout "$timeout" --max-time "$timeout" "$url" | \
            grep -i "<title>" | sed 's/<[^>]*>//g' | head -1 >> "$service_info" 2>/dev/null
        echo "" >> "$service_info"
        
        echo "----------------------------------------" >> "$service_info"
        echo "" >> "$service_info"
        
    done < "$urls_file"
    
    echo -e "${GREEN}[+] Service information saved to: $service_info${NC}"
}

# Check for common security headers
check_security_headers() {
    local urls_file="$1"
    local output_dir="$2"
    local timeout="$3"
    
    echo -e "${BLUE}[*] Checking security headers...${NC}"
    
    local security_report="$output_dir/security_headers.txt"
    
    cat > "$security_report" << EOF
Security Headers Analysis
Generated: $(date)
========================

EOF
    
    local security_headers=(
        "Strict-Transport-Security"
        "Content-Security-Policy"
        "X-Frame-Options"
        "X-Content-Type-Options"
        "X-XSS-Protection"
        "Referrer-Policy"
        "Feature-Policy"
        "Permissions-Policy"
    )
    
    while read -r url; do
        echo "=== $url ===" >> "$security_report"
        
        local headers_output=$(curl -I -s --connect-timeout "$timeout" --max-time "$timeout" "$url" 2>/dev/null)
        
        for header in "${security_headers[@]}"; do
            if echo "$headers_output" | grep -qi "$header"; then
                echo "✓ $header: PRESENT" >> "$security_report"
            else
                echo "✗ $header: MISSING" >> "$security_report"
            fi
        done
        
        echo "" >> "$security_report"
        echo "----------------------------------------" >> "$security_report"
        echo "" >> "$security_report"
        
    done < "$urls_file"
    
    echo -e "${GREEN}[+] Security headers analysis saved to: $security_report${NC}"
}

# Merge all probing results
merge_results() {
    local output_dir="$1"
    
    echo -e "${BLUE}[*] Merging all probing results...${NC}"
    
    local all_live="$output_dir/all_live_services.txt"
    local all_ports="$output_dir/all_open_ports.txt"
    
    # Merge HTTP services
    {
        [ -f "$output_dir/httpx_results.txt" ] && cat "$output_dir/httpx_results.txt" | awk '{print $1}'
        [ -f "$output_dir/httprobe_results.txt" ] && cat "$output_dir/httprobe_results.txt"
        [ -f "$output_dir/live_urls.txt" ] && cat "$output_dir/live_urls.txt"
    } | sort -u > "$all_live"
    
    # Merge port scan results
    {
        [ -f "$output_dir/nmap_results.txt" ] && grep "open" "$output_dir/nmap_results.txt" | awk '{print $1}'
        [ -f "$output_dir/masscan_results.txt" ] && cat "$output_dir/masscan_results.txt"
        [ -f "$output_dir/naabu_results.txt" ] && cat "$output_dir/naabu_results.txt"
    } | sort -u > "$all_ports"
    
    local live_count=$(wc -l < "$all_live" 2>/dev/null || echo "0")
    local port_count=$(wc -l < "$all_ports" 2>/dev/null || echo "0")
    
    echo -e "${GREEN}[+] Total live HTTP services: $live_count${NC}"
    echo -e "${GREEN}[+] Total open ports: $port_count${NC}"
    
    echo "$all_live"
}

# Generate comprehensive analysis
generate_analysis() {
    local output_dir="$1"
    local all_live_file="$2"
    
    echo -e "${BLUE}[*] Generating comprehensive analysis...${NC}"
    
    local analysis_file="$output_dir/live_probing_analysis.txt"
    
    cat > "$analysis_file" << EOF
Live Probing Analysis Report
Generated: $(date)
===========================

EOF
    
    # Service statistics
    echo "=== Service Statistics ===" >> "$analysis_file"
    if [ -f "$all_live_file" ]; then
        echo "Total live services: $(wc -l < "$all_live_file")" >> "$analysis_file"
        echo "" >> "$analysis_file"
        
        echo "Protocol Distribution:" >> "$analysis_file"
        grep -o "^https\?://" "$all_live_file" | sort | uniq -c | sort -nr >> "$analysis_file"
        echo "" >> "$analysis_file"
        
        echo "Port Distribution:" >> "$analysis_file"
        sed 's/.*://' "$all_live_file" | cut -d'/' -f1 | sort | uniq -c | sort -nr >> "$analysis_file"
        echo "" >> "$analysis_file"
    fi
    
    # Status code analysis
    if [ -f "$output_dir/httpx_results.txt" ]; then
        echo "=== HTTP Status Codes ===" >> "$analysis_file"
        awk '{print $2}' "$output_dir/httpx_results.txt" 2>/dev/null | sort | uniq -c | sort -nr >> "$analysis_file"
        echo "" >> "$analysis_file"
    fi
    
    # Technology detection summary
    if [ -f "$output_dir/httpx_results.txt" ] && grep -q "tech:" "$output_dir/httpx_results.txt"; then
        echo "=== Detected Technologies ===" >> "$analysis_file"
        grep "tech:" "$output_dir/httpx_results.txt" | cut -d'[' -f2 | cut -d']' -f1 | tr ',' '\n' | sort | uniq -c | sort -nr >> "$analysis_file"
        echo "" >> "$analysis_file"
    fi
    
    echo -e "${GREEN}[+] Analysis report saved to: $analysis_file${NC}"
}

# Generate summary report
generate_summary() {
    local output_dir="$1"
    local target="$2"
    
    echo -e "${BLUE}[*] Generating summary report...${NC}"
    
    local summary_file="$output_dir/live_probing_summary.txt"
    
    cat > "$summary_file" << EOF
Live Probing Summary
Generated: $(date)
===================

EOF
    
    # Count results from each method
    {
        echo "=== Probing Results ==="
        [ -f "$output_dir/ping_results.txt" ] && echo "Ping responses: $(grep -c "ALIVE" "$output_dir/ping_results.txt" 2>/dev/null || echo "0")"
        [ -f "$output_dir/httpx_results.txt" ] && echo "httpx discoveries: $(wc -l < "$output_dir/httpx_results.txt")"
        [ -f "$output_dir/httprobe_results.txt" ] && echo "httprobe discoveries: $(wc -l < "$output_dir/httprobe_results.txt")"
        [ -f "$output_dir/nmap_results.txt" ] && echo "nmap open ports: $(grep -c "open" "$output_dir/nmap_results.txt" 2>/dev/null || echo "0")"
        [ -f "$output_dir/masscan_results.txt" ] && echo "masscan discoveries: $(wc -l < "$output_dir/masscan_results.txt")"
        [ -f "$output_dir/naabu_results.txt" ] && echo "naabu discoveries: $(wc -l < "$output_dir/naabu_results.txt")"
        echo ""
        
        echo "=== Summary ==="
        [ -f "$output_dir/all_live_services.txt" ] && echo "Total live HTTP services: $(wc -l < "$output_dir/all_live_services.txt")"
        [ -f "$output_dir/all_open_ports.txt" ] && echo "Total open ports: $(wc -l < "$output_dir/all_open_ports.txt")"
        
        if [ -d "$output_dir/screenshots" ]; then
            local screenshot_count=$(find "$output_dir/screenshots" -name "*.png" 2>/dev/null | wc -l)
            echo "Screenshots taken: $screenshot_count"
        fi
    } >> "$summary_file"
    
    echo -e "${GREEN}[+] Summary report saved to: $summary_file${NC}"
}

# Main execution function
main() {
    local target_file=""
    local domain=""
    local output_dir=""
    local ports=""
    local threads=50
    local timeout=10
    local use_httpx=false
    local use_httprobe=false
    local use_nmap=false
    local use_masscan=false
    local use_naabu=false
    local use_ping=false
    local take_screenshots=false
    local tech_detect=false
    local title_grab=false
    local status_check=false
    local ssl_check=false
    local headers=false
    local content_length=false
    local run_all=false
    local verbose=false
    
    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            -f|--file)
                target_file="$2"
                shift 2
                ;;
            -d|--domain)
                domain="$2"
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
            -t|--threads)
                threads="$2"
                shift 2
                ;;
            --timeout)
                timeout="$2"
                shift 2
                ;;
            --httpx)
                use_httpx=true
                shift
                ;;
            --httprobe)
                use_httprobe=true
                shift
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
            --ping)
                use_ping=true
                shift
                ;;
            --screenshots)
                take_screenshots=true
                shift
                ;;
            --tech-detect)
                tech_detect=true
                shift
                ;;
            --title-grab)
                title_grab=true
                shift
                ;;
            --status-check)
                status_check=true
                shift
                ;;
            --ssl-check)
                ssl_check=true
                shift
                ;;
            --headers)
                headers=true
                shift
                ;;
            --content-length)
                content_length=true
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
    if [ -z "$target_file" ] && [ -z "$domain" ]; then
        echo -e "${RED}[!] Either target file (-f) or domain (-d) is required${NC}"
        show_help
        exit 1
    fi
    
    # Create temporary file for single domain
    if [ -n "$domain" ]; then
        target_file="/tmp/live_probing_target_$$"
        echo "$domain" > "$target_file"
    fi
    
    # Check if target file exists
    if [ ! -f "$target_file" ]; then
        echo -e "${RED}[!] Target file not found: $target_file${NC}"
        exit 1
    fi
    
    # Set default output directory
    if [ -z "$output_dir" ]; then
        if [ -n "$domain" ]; then
            output_dir="results/live-probing/$domain"
        else
            output_dir="results/live-probing/$(basename "$target_file" .txt)"
        fi
    fi
    
    # Create output directory
    mkdir -p "$output_dir"
    
    # Check tools
    if ! check_tools; then
        exit 1
    fi
    
    echo -e "${GREEN}[+] Starting live probing...${NC}"
    echo -e "${BLUE}[*] Target file: $target_file${NC}"
    echo -e "${BLUE}[*] Output directory: $output_dir${NC}"
    echo -e "${BLUE}[*] Threads: $threads${NC}"
    echo -e "${BLUE}[*] Timeout: $timeout seconds${NC}"
    
    # Set ports if not specified
    if [ -z "$ports" ]; then
        ports=$(IFS=','; echo "${WEB_PORTS[*]}")
    fi
    
    echo -e "${BLUE}[*] Ports: $ports${NC}"
    
    # Run tools based on flags
    if [ "$run_all" = true ]; then
        use_httpx=true
        use_httprobe=true
        use_nmap=true
        use_naabu=true
        use_ping=true
        take_screenshots=true
        tech_detect=true
        title_grab=true
        status_check=true
        ssl_check=true
        headers=true
        content_length=true
    fi
    
    # If no specific tools selected, run default set
    if [ "$use_httpx" = false ] && [ "$use_httprobe" = false ] && [ "$use_nmap" = false ] && [ "$use_masscan" = false ] && [ "$use_naabu" = false ] && [ "$use_ping" = false ]; then
        use_httpx=true
        use_nmap=true
        use_ping=true
        status_check=true
        title_grab=true
    fi
    
    # Execute selected probing methods
    [ "$use_ping" = true ] && check_ping "$target_file" "$output_dir"
    [ "$use_httpx" = true ] && run_httpx "$target_file" "$output_dir" "$threads" "$timeout" "$ports" "$tech_detect" "$title_grab" "$status_check" "$ssl_check" "$headers" "$content_length"
    [ "$use_httprobe" = true ] && run_httprobe "$target_file" "$output_dir" "$threads" "$timeout" "$ports"
    [ "$use_nmap" = true ] && run_nmap "$target_file" "$output_dir" "$threads" "$ports"
    [ "$use_masscan" = true ] && run_masscan "$target_file" "$output_dir" "$threads" "$ports"
    [ "$use_naabu" = true ] && run_naabu "$target_file" "$output_dir" "$threads" "$ports"
    
    # Merge results
    local all_live=$(merge_results "$output_dir")
    
    # Additional analysis
    if [ -f "$all_live" ] && [ -s "$all_live" ]; then
        [ "$take_screenshots" = true ] && take_screenshots "$all_live" "$output_dir"
        extract_service_info "$all_live" "$output_dir" "$timeout"
        check_security_headers "$all_live" "$output_dir" "$timeout"
    fi
    
    # Generate analysis and summary
    generate_analysis "$output_dir" "$all_live"
    generate_summary "$output_dir" "$target_file"
    
    # Clean up temporary file if created
    if [ -n "$domain" ] && [ -f "/tmp/live_probing_target_$$" ]; then
        rm -f "/tmp/live_probing_target_$$"
    fi
    
    echo -e "\n${GREEN}[+] Live Probing Completed!${NC}"
    echo -e "${BLUE}[*] Results saved in: $output_dir${NC}"
    echo -e "${GREEN}[+] Live probing completed successfully${NC}"
}

# Run main function if script is executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi