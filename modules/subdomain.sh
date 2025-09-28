#!/bin/bash

# Subdomain Enumeration Module for r3con VAPT Suite
# Comprehensive subdomain discovery using multiple tools

source "$(dirname "$0")/../utils/common.sh" 2>/dev/null || true

MODULE_NAME="Subdomain Enumeration"
MODULE_VERSION="1.0"

# Subdomain enumeration tools
TOOLS=(
    "subfinder:subfinder"
    "assetfinder:assetfinder"
    "amass:amass"
    "chaos:chaos"
    "httpx:httpx"
    "dnsx:dnsx"
    "crtsh:curl"
    "waybackurls:waybackurls"
    "gau:gau"
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
${GREEN}Subdomain Enumeration Module${NC}

${BLUE}Usage:${NC}
    $0 -d <domain> [options]

${BLUE}Required:${NC}
    -d, --domain        Target domain

${BLUE}Options:${NC}
    -o, --output        Output directory (default: results/subdomain)
    -w, --wordlist      Custom wordlist for enumeration
    -t, --threads       Number of threads (default: 20)
    --subfinder         Use Subfinder for subdomain discovery
    --assetfinder       Use Assetfinder for subdomain discovery
    --amass             Use Amass for subdomain discovery
    --chaos             Use Chaos for subdomain discovery
    --crtsh             Use crt.sh certificate transparency logs
    --wayback           Use Wayback Machine for historical subdomains
    --gau               Use GetAllUrls for subdomain discovery
    --httpx             Use httpx for live subdomain probing
    --dnsx              Use dnsx for DNS resolution
    --all               Run all available tools
    -v, --verbose       Verbose output
    -h, --help          Show this help message

${BLUE}Examples:${NC}
    $0 -d example.com --all
    $0 -d example.com --subfinder --amass --httpx
    $0 -d example.com -w custom-wordlist.txt --chaos
    $0 -d example.com --assetfinder --wayback --threads 50
EOF
}

# Subfinder enumeration
run_subfinder() {
    local domain="$1"
    local output_dir="$2"
    local threads="$3"
    
    echo -e "${BLUE}[*] Running Subfinder...${NC}"
    
    subfinder -d "$domain" -o "$output_dir/subfinder_subdomains.txt" -t "$threads" -silent
    
    if [ -f "$output_dir/subfinder_subdomains.txt" ]; then
        local count=$(wc -l < "$output_dir/subfinder_subdomains.txt")
        echo -e "${GREEN}[+] Subfinder found $count subdomains${NC}"
    fi
}

# Assetfinder enumeration
run_assetfinder() {
    local domain="$1"
    local output_dir="$2"
    
    echo -e "${BLUE}[*] Running Assetfinder...${NC}"
    
    assetfinder --subs-only "$domain" > "$output_dir/assetfinder_subdomains.txt"
    
    if [ -f "$output_dir/assetfinder_subdomains.txt" ]; then
        local count=$(wc -l < "$output_dir/assetfinder_subdomains.txt")
        echo -e "${GREEN}[+] Assetfinder found $count subdomains${NC}"
    fi
}

# Amass enumeration
run_amass() {
    local domain="$1"
    local output_dir="$2"
    local threads="$3"
    
    echo -e "${BLUE}[*] Running Amass...${NC}"
    
    amass enum -d "$domain" -o "$output_dir/amass_subdomains.txt" -w "$threads"
    
    if [ -f "$output_dir/amass_subdomains.txt" ]; then
        local count=$(wc -l < "$output_dir/amass_subdomains.txt")
        echo -e "${GREEN}[+] Amass found $count subdomains${NC}"
    fi
}

# Chaos enumeration
run_chaos() {
    local domain="$1"
    local output_dir="$2"
    
    echo -e "${BLUE}[*] Running Chaos...${NC}"
    
    chaos -d "$domain" -o "$output_dir/chaos_subdomains.txt" -silent
    
    if [ -f "$output_dir/chaos_subdomains.txt" ]; then
        local count=$(wc -l < "$output_dir/chaos_subdomains.txt")
        echo -e "${GREEN}[+] Chaos found $count subdomains${NC}"
    fi
}

# Certificate transparency logs (crt.sh)
run_crtsh() {
    local domain="$1"
    local output_dir="$2"
    
    echo -e "${BLUE}[*] Checking Certificate Transparency logs...${NC}"
    
    curl -s "https://crt.sh/?q=%.${domain}&output=json" | jq -r '.[].name_value' | sed 's/\*\.//g' | sort -u > "$output_dir/crtsh_subdomains.txt"
    
    if [ -f "$output_dir/crtsh_subdomains.txt" ]; then
        local count=$(wc -l < "$output_dir/crtsh_subdomains.txt")
        echo -e "${GREEN}[+] Certificate logs found $count subdomains${NC}"
    fi
}

# Wayback Machine enumeration
run_wayback() {
    local domain="$1"
    local output_dir="$2"
    
    echo -e "${BLUE}[*] Checking Wayback Machine...${NC}"
    
    waybackurls "$domain" | unfurl --unique domains > "$output_dir/wayback_subdomains.txt"
    
    if [ -f "$output_dir/wayback_subdomains.txt" ]; then
        local count=$(wc -l < "$output_dir/wayback_subdomains.txt")
        echo -e "${GREEN}[+] Wayback Machine found $count subdomains${NC}"
    fi
}

# GetAllUrls enumeration
run_gau() {
    local domain="$1"
    local output_dir="$2"
    
    echo -e "${BLUE}[*] Running GetAllUrls...${NC}"
    
    gau "$domain" --subs | unfurl --unique domains > "$output_dir/gau_subdomains.txt"
    
    if [ -f "$output_dir/gau_subdomains.txt" ]; then
        local count=$(wc -l < "$output_dir/gau_subdomains.txt")
        echo -e "${GREEN}[+] GetAllUrls found $count subdomains${NC}"
    fi
}

# Live subdomain probing with httpx
run_httpx() {
    local domain="$1"
    local output_dir="$2"
    local threads="$3"
    local all_subdomains="$4"
    
    echo -e "${BLUE}[*] Probing live subdomains with httpx...${NC}"
    
    if [ -f "$all_subdomains" ]; then
        httpx -l "$all_subdomains" -o "$output_dir/live_subdomains.txt" -threads "$threads" -silent -title -tech-detect -status-code
        
        if [ -f "$output_dir/live_subdomains.txt" ]; then
            local count=$(wc -l < "$output_dir/live_subdomains.txt")
            echo -e "${GREEN}[+] Found $count live subdomains${NC}"
        fi
    fi
}

# DNS resolution with dnsx
run_dnsx() {
    local domain="$1"
    local output_dir="$2"
    local threads="$3"
    local all_subdomains="$4"
    
    echo -e "${BLUE}[*] Resolving subdomains with dnsx...${NC}"
    
    if [ -f "$all_subdomains" ]; then
        dnsx -l "$all_subdomains" -o "$output_dir/resolved_subdomains.txt" -t "$threads" -silent -a -aaaa -cname
        
        if [ -f "$output_dir/resolved_subdomains.txt" ]; then
            local count=$(wc -l < "$output_dir/resolved_subdomains.txt")
            echo -e "${GREEN}[+] Resolved $count subdomains${NC}"
        fi
    fi
}

# Merge and deduplicate results
merge_results() {
    local output_dir="$1"
    local domain="$2"
    
    echo -e "${BLUE}[*] Merging and deduplicating results...${NC}"
    
    # Combine all subdomain files
    cat "$output_dir"/*_subdomains.txt 2>/dev/null | sort -u | grep "\.$domain$" > "$output_dir/all_subdomains.txt"
    
    # Remove empty lines
    sed -i '/^$/d' "$output_dir/all_subdomains.txt"
    
    local total_count=$(wc -l < "$output_dir/all_subdomains.txt")
    echo -e "${GREEN}[+] Total unique subdomains: $total_count${NC}"
    
    echo "$output_dir/all_subdomains.txt"
}

# Generate summary report
generate_summary() {
    local output_dir="$1"
    local domain="$2"
    
    echo -e "${BLUE}[*] Generating summary report...${NC}"
    
    local summary_file="$output_dir/subdomain_summary.txt"
    
    cat > "$summary_file" << EOF
Subdomain Enumeration Summary for: $domain
Generated: $(date)
========================================

EOF
    
    # Count results from each tool
    for file in "$output_dir"/*_subdomains.txt; do
        if [ -f "$file" ]; then
            local tool_name=$(basename "$file" _subdomains.txt)
            local count=$(wc -l < "$file")
            echo "$tool_name: $count subdomains" >> "$summary_file"
        fi
    done
    
    echo "" >> "$summary_file"
    
    if [ -f "$output_dir/all_subdomains.txt" ]; then
        local total=$(wc -l < "$output_dir/all_subdomains.txt")
        echo "Total unique subdomains: $total" >> "$summary_file"
        echo "" >> "$summary_file"
        echo "=== All Discovered Subdomains ===" >> "$summary_file"
        cat "$output_dir/all_subdomains.txt" >> "$summary_file"
    fi
    
    if [ -f "$output_dir/live_subdomains.txt" ]; then
        local live_count=$(wc -l < "$output_dir/live_subdomains.txt")
        echo "" >> "$summary_file"
        echo "=== Live Subdomains ($live_count) ===" >> "$summary_file"
        cat "$output_dir/live_subdomains.txt" >> "$summary_file"
    fi
    
    echo -e "${GREEN}[+] Summary report saved to: $summary_file${NC}"
}

# Main execution function
main() {
    local domain=""
    local output_dir=""
    local wordlist=""
    local threads=20
    local run_subfinder=false
    local run_assetfinder=false
    local run_amass=false
    local run_chaos=false
    local run_crtsh=false
    local run_wayback=false
    local run_gau=false
    local run_httpx=false
    local run_dnsx=false
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
            -w|--wordlist)
                wordlist="$2"
                shift 2
                ;;
            -t|--threads)
                threads="$2"
                shift 2
                ;;
            --subfinder)
                run_subfinder=true
                shift
                ;;
            --assetfinder)
                run_assetfinder=true
                shift
                ;;
            --amass)
                run_amass=true
                shift
                ;;
            --chaos)
                run_chaos=true
                shift
                ;;
            --crtsh)
                run_crtsh=true
                shift
                ;;
            --wayback)
                run_wayback=true
                shift
                ;;
            --gau)
                run_gau=true
                shift
                ;;
            --httpx)
                run_httpx=true
                shift
                ;;
            --dnsx)
                run_dnsx=true
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
        output_dir="results/subdomain/$domain"
    fi
    
    # Create output directory
    mkdir -p "$output_dir"
    
    # Check tools
    if ! check_tools; then
        exit 1
    fi
    
    echo -e "${GREEN}[+] Starting subdomain enumeration for: $domain${NC}"
    echo -e "${BLUE}[*] Output directory: $output_dir${NC}"
    echo -e "${BLUE}[*] Threads: $threads${NC}"
    
    # Run tools based on flags
    if [ "$run_all" = true ]; then
        run_subfinder=true
        run_assetfinder=true
        run_amass=true
        run_chaos=true
        run_crtsh=true
        run_wayback=true
        run_gau=true
        run_httpx=true
        run_dnsx=true
    fi
    
    # If no specific tools selected, run default set
    if [ "$run_subfinder" = false ] && [ "$run_assetfinder" = false ] && [ "$run_amass" = false ] && [ "$run_chaos" = false ] && [ "$run_crtsh" = false ] && [ "$run_wayback" = false ] && [ "$run_gau" = false ]; then
        run_subfinder=true
        run_assetfinder=true
        run_crtsh=true
        run_httpx=true
    fi
    
    # Execute selected tools
    [ "$run_subfinder" = true ] && run_subfinder "$domain" "$output_dir" "$threads"
    [ "$run_assetfinder" = true ] && run_assetfinder "$domain" "$output_dir"
    [ "$run_amass" = true ] && run_amass "$domain" "$output_dir" "$threads"
    [ "$run_chaos" = true ] && run_chaos "$domain" "$output_dir"
    [ "$run_crtsh" = true ] && run_crtsh "$domain" "$output_dir"
    [ "$run_wayback" = true ] && run_wayback "$domain" "$output_dir"
    [ "$run_gau" = true ] && run_gau "$domain" "$output_dir"
    
    # Merge results
    local all_subdomains=$(merge_results "$output_dir" "$domain")
    
    # Run probing tools if requested
    [ "$run_httpx" = true ] && run_httpx "$domain" "$output_dir" "$threads" "$all_subdomains"
    [ "$run_dnsx" = true ] && run_dnsx "$domain" "$output_dir" "$threads" "$all_subdomains"
    
    # Generate summary report
    generate_summary "$output_dir" "$domain"
    
    echo -e "\n${GREEN}[+] Subdomain Enumeration Completed!${NC}"
    echo -e "${BLUE}[*] Results saved in: $output_dir${NC}"
    echo -e "${GREEN}[+] Subdomain enumeration completed for $domain${NC}"
}

# Run main function if script is executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi