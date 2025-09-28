#!/bin/bash

# Technology Detection Module for r3con VAPT Suite
# Identifies technologies, frameworks, and services running on target

source "$(dirname "$0")/../utils/common.sh" 2>/dev/null || true

MODULE_NAME="Technology Detection"
MODULE_VERSION="1.0"

# Technology detection tools
TOOLS=(
    "whatweb:whatweb"
    "wappalyzer:wappalyzer"
    "httpx:httpx"
    "wafw00f:wafw00f"
    "nuclei:nuclei"
    "nmap:nmap"
    "nikto:nikto"
)

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
${GREEN}Technology Detection Module${NC}

${BLUE}Usage:${NC}
    $0 -d <domain> [options]

${BLUE}Required:${NC}
    -d, --domain        Target domain

${BLUE}Options:${NC}
    -o, --output        Output directory (default: results/tech-detection)
    -t, --threads       Number of threads (default: 20)
    -u, --urls          File containing URLs to analyze
    --whatweb           Use WhatWeb for technology detection
    --wappalyzer        Use Wappalyzer for technology profiling
    --httpx             Use httpx for technology probing
    --wafw00f           Use wafw00f for WAF detection
    --nuclei            Use Nuclei for technology templates
    --nmap              Use Nmap for service detection
    --nikto             Use Nikto for web server analysis
    --all               Run all available tools
    -v, --verbose       Verbose output
    -h, --help          Show this help message

${BLUE}Examples:${NC}
    $0 -d example.com --all
    $0 -d example.com --whatweb --wafw00f
    $0 -d example.com -u urls.txt --httpx --nuclei
    $0 -d example.com --nmap --nikto --threads 50
EOF
}

# WhatWeb technology detection
run_whatweb() {
    local domain="$1"
    local output_dir="$2"
    local urls_file="$3"
    local threads="$4"
    
    echo -e "${BLUE}[*] Running WhatWeb technology detection...${NC}"
    
    if [ -n "$urls_file" ] && [ -f "$urls_file" ]; then
        whatweb -i "$urls_file" --color=never --no-errors -t "$threads" > "$output_dir/whatweb_results.txt"
    else
        whatweb "https://$domain" "http://$domain" --color=never --no-errors -t "$threads" > "$output_dir/whatweb_results.txt"
    fi
    
    # Generate JSON output
    if [ -n "$urls_file" ] && [ -f "$urls_file" ]; then
        whatweb -i "$urls_file" --color=never --no-errors -t "$threads" --log-json="$output_dir/whatweb_results.json"
    else
        whatweb "https://$domain" "http://$domain" --color=never --no-errors -t "$threads" --log-json="$output_dir/whatweb_results.json"
    fi
    
    if [ -f "$output_dir/whatweb_results.txt" ]; then
        echo -e "${GREEN}[+] WhatWeb results saved to: $output_dir/whatweb_results.txt${NC}"
    fi
}

# Wappalyzer technology profiling
run_wappalyzer() {
    local domain="$1"
    local output_dir="$2"
    local urls_file="$3"
    
    echo -e "${BLUE}[*] Running Wappalyzer technology profiling...${NC}"
    
    if [ -n "$urls_file" ] && [ -f "$urls_file" ]; then
        while IFS= read -r url; do
            echo "Analyzing: $url"
            wappalyzer "$url" --pretty --output-format=json >> "$output_dir/wappalyzer_results.json"
        done < "$urls_file"
    else
        wappalyzer "https://$domain" --pretty --output-format=json > "$output_dir/wappalyzer_results.json"
        wappalyzer "http://$domain" --pretty --output-format=json >> "$output_dir/wappalyzer_results.json"
    fi
    
    if [ -f "$output_dir/wappalyzer_results.json" ]; then
        echo -e "${GREEN}[+] Wappalyzer results saved to: $output_dir/wappalyzer_results.json${NC}"
    fi
}

# httpx technology probing
run_httpx() {
    local domain="$1"
    local output_dir="$2"
    local urls_file="$3"
    local threads="$4"
    
    echo -e "${BLUE}[*] Running httpx technology probing...${NC}"
    
    if [ -n "$urls_file" ] && [ -f "$urls_file" ]; then
        httpx -l "$urls_file" -tech-detect -server -title -content-length -status-code -threads "$threads" -o "$output_dir/httpx_tech_results.txt"
    else
        echo -e "https://$domain\nhttp://$domain" | httpx -tech-detect -server -title -content-length -status-code -threads "$threads" -o "$output_dir/httpx_tech_results.txt"
    fi
    
    # Generate JSON output
    if [ -n "$urls_file" ] && [ -f "$urls_file" ]; then
        httpx -l "$urls_file" -tech-detect -server -title -json -threads "$threads" -o "$output_dir/httpx_tech_results.json"
    else
        echo -e "https://$domain\nhttp://$domain" | httpx -tech-detect -server -title -json -threads "$threads" -o "$output_dir/httpx_tech_results.json"
    fi
    
    if [ -f "$output_dir/httpx_tech_results.txt" ]; then
        echo -e "${GREEN}[+] httpx technology results saved to: $output_dir/httpx_tech_results.txt${NC}"
    fi
}

# wafw00f WAF detection
run_wafw00f() {
    local domain="$1"
    local output_dir="$2"
    local urls_file="$3"
    
    echo -e "${BLUE}[*] Running wafw00f WAF detection...${NC}"
    
    if [ -n "$urls_file" ] && [ -f "$urls_file" ]; then
        wafw00f -i "$urls_file" -o "$output_dir/wafw00f_results.txt"
    else
        wafw00f "https://$domain" -o "$output_dir/wafw00f_results.txt"
        wafw00f "http://$domain" -o "$output_dir/wafw00f_results.txt.2"
        cat "$output_dir/wafw00f_results.txt.2" >> "$output_dir/wafw00f_results.txt" 2>/dev/null
        rm -f "$output_dir/wafw00f_results.txt.2"
    fi
    
    if [ -f "$output_dir/wafw00f_results.txt" ]; then
        echo -e "${GREEN}[+] wafw00f results saved to: $output_dir/wafw00f_results.txt${NC}"
    fi
}

# Nuclei technology templates
run_nuclei() {
    local domain="$1"
    local output_dir="$2"
    local urls_file="$3"
    local threads="$4"
    
    echo -e "${BLUE}[*] Running Nuclei technology detection templates...${NC}"
    
    # Update nuclei templates
    nuclei -update-templates >/dev/null 2>&1
    
    if [ -n "$urls_file" ] && [ -f "$urls_file" ]; then
        nuclei -l "$urls_file" -t technologies/ -c "$threads" -o "$output_dir/nuclei_tech_results.txt" -silent
    else
        echo -e "https://$domain\nhttp://$domain" | nuclei -t technologies/ -c "$threads" -o "$output_dir/nuclei_tech_results.txt" -silent
    fi
    
    # Generate JSON output
    if [ -n "$urls_file" ] && [ -f "$urls_file" ]; then
        nuclei -l "$urls_file" -t technologies/ -c "$threads" -json -o "$output_dir/nuclei_tech_results.json" -silent
    else
        echo -e "https://$domain\nhttp://$domain" | nuclei -t technologies/ -c "$threads" -json -o "$output_dir/nuclei_tech_results.json" -silent
    fi
    
    if [ -f "$output_dir/nuclei_tech_results.txt" ]; then
        echo -e "${GREEN}[+] Nuclei technology results saved to: $output_dir/nuclei_tech_results.txt${NC}"
    fi
}

# Nmap service detection
run_nmap() {
    local domain="$1"
    local output_dir="$2"
    local threads="$3"
    
    echo -e "${BLUE}[*] Running Nmap service detection...${NC}"
    
    # Service version detection
    nmap -sV -sC --top-ports 1000 --min-rate "$threads" "$domain" -oA "$output_dir/nmap_services"
    
    # HTTP service enumeration
    nmap -sV -p 80,443,8080,8443 --script http-enum,http-headers,http-methods,http-title "$domain" -oA "$output_dir/nmap_http_enum"
    
    if [ -f "$output_dir/nmap_services.nmap" ]; then
        echo -e "${GREEN}[+] Nmap service detection results saved to: $output_dir/nmap_services.*${NC}"
    fi
}

# Nikto web server analysis
run_nikto() {
    local domain="$1"
    local output_dir="$2"
    
    echo -e "${BLUE}[*] Running Nikto web server analysis...${NC}"
    
    # Scan HTTPS
    nikto -h "https://$domain" -output "$output_dir/nikto_https_results.txt"
    
    # Scan HTTP
    nikto -h "http://$domain" -output "$output_dir/nikto_http_results.txt"
    
    # Generate XML output
    nikto -h "https://$domain" -Format xml -output "$output_dir/nikto_https_results.xml"
    nikto -h "http://$domain" -Format xml -output "$output_dir/nikto_http_results.xml"
    
    if [ -f "$output_dir/nikto_https_results.txt" ]; then
        echo -e "${GREEN}[+] Nikto HTTPS results saved to: $output_dir/nikto_https_results.txt${NC}"
    fi
    
    if [ -f "$output_dir/nikto_http_results.txt" ]; then
        echo -e "${GREEN}[+] Nikto HTTP results saved to: $output_dir/nikto_http_results.txt${NC}"
    fi
}

# Generate technology summary
generate_summary() {
    local output_dir="$1"
    local domain="$2"
    
    echo -e "${BLUE}[*] Generating technology summary...${NC}"
    
    local summary_file="$output_dir/technology_summary.txt"
    
    cat > "$summary_file" << EOF
Technology Detection Summary for: $domain
Generated: $(date)
========================================

EOF
    
    # Extract technologies from various tools
    if [ -f "$output_dir/whatweb_results.txt" ]; then
        echo "=== WhatWeb Technologies ===" >> "$summary_file"
        grep -E "^\[.*\]" "$output_dir/whatweb_results.txt" | head -20 >> "$summary_file"
        echo "" >> "$summary_file"
    fi
    
    if [ -f "$output_dir/httpx_tech_results.txt" ]; then
        echo "=== httpx Technology Detection ===" >> "$summary_file"
        grep -E "\[.*\]" "$output_dir/httpx_tech_results.txt" | head -20 >> "$summary_file"
        echo "" >> "$summary_file"
    fi
    
    if [ -f "$output_dir/wafw00f_results.txt" ]; then
        echo "=== WAF Detection ===" >> "$summary_file"
        cat "$output_dir/wafw00f_results.txt" >> "$summary_file"
        echo "" >> "$summary_file"
    fi
    
    if [ -f "$output_dir/nuclei_tech_results.txt" ]; then
        echo "=== Nuclei Technology Templates ===" >> "$summary_file"
        head -20 "$output_dir/nuclei_tech_results.txt" >> "$summary_file"
        echo "" >> "$summary_file"
    fi
    
    echo -e "${GREEN}[+] Technology summary saved to: $summary_file${NC}"
}

# Main execution function
main() {
    local domain=""
    local output_dir=""
    local threads=20
    local urls_file=""
    local run_whatweb=false
    local run_wappalyzer=false
    local run_httpx=false
    local run_wafw00f=false
    local run_nuclei=false
    local run_nmap=false
    local run_nikto=false
    local run_all=false
    local verbose=false
    
    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            -d|--domain)
                domain="$2"
                shift 2
                ;;
            -o|--output)
                output_dir="$2"
                shift 2
                ;;
            -t|--threads)
                threads="$2"
                shift 2
                ;;
            -u|--urls)
                urls_file="$2"
                shift 2
                ;;
            --whatweb)
                run_whatweb=true
                shift
                ;;
            --wappalyzer)
                run_wappalyzer=true
                shift
                ;;
            --httpx)
                run_httpx=true
                shift
                ;;
            --wafw00f)
                run_wafw00f=true
                shift
                ;;
            --nuclei)
                run_nuclei=true
                shift
                ;;
            --nmap)
                run_nmap=true
                shift
                ;;
            --nikto)
                run_nikto=true
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
    if [ -z "$domain" ]; then
        echo -e "${RED}[!] Domain is required${NC}"
        show_help
        exit 1
    fi
    
    # Set default output directory
    if [ -z "$output_dir" ]; then
        output_dir="results/tech-detection/$domain"
    fi
    
    # Create output directory
    mkdir -p "$output_dir"
    
    # Check tools
    if ! check_tools; then
        exit 1
    fi
    
    echo -e "${GREEN}[+] Starting technology detection for: $domain${NC}"
    echo -e "${BLUE}[*] Output directory: $output_dir${NC}"
    echo -e "${BLUE}[*] Threads: $threads${NC}"
    
    # Run tools based on flags
    if [ "$run_all" = true ]; then
        run_whatweb=true
        run_wappalyzer=true
        run_httpx=true
        run_wafw00f=true
        run_nuclei=true
        run_nmap=true
        run_nikto=true
    fi
    
    # If no specific tools selected, run default set
    if [ "$run_whatweb" = false ] && [ "$run_wappalyzer" = false ] && [ "$run_httpx" = false ] && [ "$run_wafw00f" = false ] && [ "$run_nuclei" = false ] && [ "$run_nmap" = false ] && [ "$run_nikto" = false ]; then
        run_whatweb=true
        run_httpx=true
        run_wafw00f=true
        run_nuclei=true
    fi
    
    # Execute selected tools
    [ "$run_whatweb" = true ] && run_whatweb "$domain" "$output_dir" "$urls_file" "$threads"
    [ "$run_wappalyzer" = true ] && run_wappalyzer "$domain" "$output_dir" "$urls_file"
    [ "$run_httpx" = true ] && run_httpx "$domain" "$output_dir" "$urls_file" "$threads"
    [ "$run_wafw00f" = true ] && run_wafw00f "$domain" "$output_dir" "$urls_file"
    [ "$run_nuclei" = true ] && run_nuclei "$domain" "$output_dir" "$urls_file" "$threads"
    [ "$run_nmap" = true ] && run_nmap "$domain" "$output_dir" "$threads"
    [ "$run_nikto" = true ] && run_nikto "$domain" "$output_dir"
    
    # Generate summary report
    generate_summary "$output_dir" "$domain"
    
    echo -e "\n${GREEN}[+] Technology Detection Completed!${NC}"
    echo -e "${BLUE}[*] Results saved in: $output_dir${NC}"
    
    # Count discovered technologies
    for file in "$output_dir"/*.txt "$output_dir"/*.json; do
        if [ -f "$file" ]; then
            echo -e "${YELLOW}[*] Found results in: $(basename "$file")${NC}"
        fi
    done
    
    echo -e "${GREEN}[+] Technology detection completed for $domain${NC}"
}

# Run main function if script is executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi