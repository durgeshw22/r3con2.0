#!/bin/bash

# DNS Resolution Module for r3con VAPT Suite
# Comprehensive DNS analysis and resolution

source "$(dirname "$0")/../utils/common.sh" 2>/dev/null || true

MODULE_NAME="DNS Resolution"
MODULE_VERSION="1.0"

# DNS tools
TOOLS=(
    "dig:dig"
    "nslookup:nslookup"
    "host:host"
    "dnsx:dnsx"
    "dnsrecon:dnsrecon"
    "fierce:fierce"
    "dnsmap:dnsmap"
    "massdns:massdns"
)

# Common DNS record types
DNS_TYPES=("A" "AAAA" "CNAME" "MX" "NS" "TXT" "SOA" "PTR" "SRV")

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
${GREEN}DNS Resolution Module${NC}

${BLUE}Usage:${NC}
    $0 -d <domain> [options] OR $0 -f <file> [options]

${BLUE}Required (choose one):${NC}
    -d, --domain        Target domain
    -f, --file          File containing domains (one per line)

${BLUE}Options:${NC}
    -o, --output        Output directory (default: results/dns-resolution)
    -t, --threads       Number of threads (default: 20)
    --timeout           DNS query timeout in seconds (default: 5)
    --resolvers         Custom DNS resolvers file
    --record-types      DNS record types to query (default: A,AAAA,CNAME,MX,NS,TXT)
    --dnsx              Use dnsx for fast DNS resolution
    --dnsrecon          Use dnsrecon for comprehensive DNS enumeration
    --fierce            Use fierce for DNS brute forcing
    --dnsmap            Use dnsmap for DNS enumeration
    --massdns           Use massdns for mass DNS resolution
    --zone-transfer     Attempt DNS zone transfers
    --reverse-dns       Perform reverse DNS lookups
    --wildcard-test     Test for wildcard DNS responses
    --dns-cache         Check DNS cache poisoning
    --subdomain-brute   Brute force subdomains via DNS
    --all               Run all DNS analysis methods
    -v, --verbose       Verbose output
    -h, --help          Show this help message

${BLUE}Examples:${NC}
    $0 -d example.com --all
    $0 -f domains.txt --dnsx --dnsrecon --zone-transfer
    $0 -d example.com --record-types A,AAAA,MX,TXT --reverse-dns
    $0 -d example.com --resolvers custom_resolvers.txt --massdns
EOF
}

# Basic DNS resolution with dig
run_basic_dns() {
    local domain="$1"
    local output_dir="$2"
    local record_types="$3"
    
    echo -e "${BLUE}[*] Running basic DNS resolution with dig...${NC}"
    
    local dns_output="$output_dir/basic_dns_records.txt"
    
    cat > "$dns_output" << EOF
Basic DNS Records for: $domain
Generated: $(date)
===============================

EOF
    
    IFS=',' read -ra types <<< "$record_types"
    
    for record_type in "${types[@]}"; do
        echo "=== $record_type Records ===" >> "$dns_output"
        dig "$domain" "$record_type" +short >> "$dns_output" 2>/dev/null
        echo "" >> "$dns_output"
    done
    
    # Additional useful queries
    echo "=== SOA Record ===" >> "$dns_output"
    dig "$domain" SOA +short >> "$dns_output" 2>/dev/null
    echo "" >> "$dns_output"
    
    echo "=== Authoritative Name Servers ===" >> "$dns_output"
    dig "$domain" NS +short >> "$dns_output" 2>/dev/null
    echo "" >> "$dns_output"
    
    echo -e "${GREEN}[+] Basic DNS resolution completed${NC}"
}

# DNS resolution with dnsx
run_dnsx() {
    local target="$1"
    local output_dir="$2"
    local threads="$3"
    local timeout="$4"
    local record_types="$5"
    local resolvers="$6"
    
    echo -e "${BLUE}[*] Running dnsx for fast DNS resolution...${NC}"
    
    local dnsx_output="$output_dir/dnsx_resolution.txt"
    local dnsx_json="$output_dir/dnsx_results.json"
    local dnsx_args=()
    
    if [ -f "$target" ]; then
        dnsx_args+=(-l "$target")
    else
        dnsx_args+=(-d "$target")
    fi
    
    dnsx_args+=(-o "$dnsx_output")
    dnsx_args+=(-json -o "$dnsx_json")
    dnsx_args+=(-t "$threads")
    dnsx_args+=(-timeout "$timeout")
    dnsx_args+=(-silent)
    
    if [ -n "$record_types" ]; then
        dnsx_args+=(-a -aaaa -cname -mx -ns -txt -soa)
    fi
    
    if [ -n "$resolvers" ] && [ -f "$resolvers" ]; then
        dnsx_args+=(-r "$resolvers")
    fi
    
    dnsx "${dnsx_args[@]}"
    
    if [ -f "$dnsx_output" ]; then
        local count=$(wc -l < "$dnsx_output")
        echo -e "${GREEN}[+] dnsx resolved $count DNS records${NC}"
    fi
}

# DNS reconnaissance with dnsrecon
run_dnsrecon() {
    local domain="$1"
    local output_dir="$2"
    local threads="$3"
    
    echo -e "${BLUE}[*] Running dnsrecon for comprehensive DNS enumeration...${NC}"
    
    local dnsrecon_output="$output_dir/dnsrecon_results.txt"
    local dnsrecon_json="$output_dir/dnsrecon_results.json"
    
    # Standard enumeration
    dnsrecon -d "$domain" --threads "$threads" -j "$dnsrecon_json" > "$dnsrecon_output" 2>&1
    
    # Zone transfer attempt
    echo -e "${BLUE}[*] Attempting zone transfer...${NC}"
    local zone_transfer_output="$output_dir/zone_transfer.txt"
    dnsrecon -d "$domain" -a > "$zone_transfer_output" 2>&1
    
    # Reverse DNS lookup
    echo -e "${BLUE}[*] Performing reverse DNS lookup...${NC}"
    local reverse_dns_output="$output_dir/reverse_dns.txt"
    
    # Get IP addresses first
    local ips=$(dig "$domain" A +short | grep -E '^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$')
    
    if [ -n "$ips" ]; then
        for ip in $ips; do
            echo "=== Reverse DNS for $ip ===" >> "$reverse_dns_output"
            dnsrecon -r "$ip/24" --threads "$threads" >> "$reverse_dns_output" 2>&1
            echo "" >> "$reverse_dns_output"
        done
    fi
    
    if [ -f "$dnsrecon_output" ]; then
        echo -e "${GREEN}[+] dnsrecon enumeration completed${NC}"
    fi
}

# DNS brute forcing with fierce
run_fierce() {
    local domain="$1"
    local output_dir="$2"
    local threads="$3"
    
    echo -e "${BLUE}[*] Running fierce for DNS brute forcing...${NC}"
    
    local fierce_output="$output_dir/fierce_results.txt"
    
    if command -v fierce &> /dev/null; then
        fierce --domain "$domain" --threads "$threads" > "$fierce_output" 2>&1
        
        if [ -f "$fierce_output" ]; then
            local subdomain_count=$(grep -c "Found:" "$fierce_output" 2>/dev/null || echo "0")
            echo -e "${GREEN}[+] fierce found $subdomain_count subdomains${NC}"
        fi
    else
        echo -e "${YELLOW}[!] fierce not available, skipping...${NC}"
    fi
}

# DNS enumeration with dnsmap
run_dnsmap() {
    local domain="$1"
    local output_dir="$2"
    local threads="$3"
    
    echo -e "${BLUE}[*] Running dnsmap for DNS enumeration...${NC}"
    
    local dnsmap_output="$output_dir/dnsmap_results.txt"
    
    if command -v dnsmap &> /dev/null; then
        dnsmap "$domain" -r "$dnsmap_output" -t "$threads"
        
        if [ -f "$dnsmap_output" ]; then
            echo -e "${GREEN}[+] dnsmap enumeration completed${NC}"
        fi
    else
        echo -e "${YELLOW}[!] dnsmap not available, skipping...${NC}"
    fi
}

# Mass DNS resolution with massdns
run_massdns() {
    local target="$1"
    local output_dir="$2"
    local threads="$3"
    local resolvers="$4"
    
    echo -e "${BLUE}[*] Running massdns for mass DNS resolution...${NC}"
    
    local massdns_output="$output_dir/massdns_results.txt"
    
    if command -v massdns &> /dev/null; then
        local massdns_args=()
        massdns_args+=(-r "$resolvers")
        massdns_args+=(-t A)
        massdns_args+=(-o S)
        massdns_args+=(-w "$massdns_output")
        massdns_args+=(-s "$threads")
        
        if [ -f "$target" ]; then
            massdns "${massdns_args[@]}" "$target"
        else
            echo "$target" | massdns "${massdns_args[@]}"
        fi
        
        if [ -f "$massdns_output" ]; then
            local count=$(wc -l < "$massdns_output")
            echo -e "${GREEN}[+] massdns resolved $count records${NC}"
        fi
    else
        echo -e "${YELLOW}[!] massdns not available, skipping...${NC}"
    fi
}

# Test for wildcard DNS responses
test_wildcard_dns() {
    local domain="$1"
    local output_dir="$2"
    
    echo -e "${BLUE}[*] Testing for wildcard DNS responses...${NC}"
    
    local wildcard_output="$output_dir/wildcard_test.txt"
    
    cat > "$wildcard_output" << EOF
Wildcard DNS Test for: $domain
Generated: $(date)
=============================

EOF
    
    # Test with random subdomains
    local random_subdomains=(
        "$(openssl rand -hex 8)"
        "$(openssl rand -hex 12)"
        "test-$(date +%s)"
        "random-$(shuf -i 1000-9999 -n 1)"
        "nonexistent-$(openssl rand -hex 6)"
    )
    
    local wildcard_detected=false
    
    for subdomain in "${random_subdomains[@]}"; do
        local test_domain="${subdomain}.${domain}"
        local result=$(dig "$test_domain" A +short 2>/dev/null)
        
        echo "Testing: $test_domain" >> "$wildcard_output"
        
        if [ -n "$result" ]; then
            echo "  Result: $result" >> "$wildcard_output"
            wildcard_detected=true
        else
            echo "  Result: NXDOMAIN" >> "$wildcard_output"
        fi
        
        echo "" >> "$wildcard_output"
    done
    
    if [ "$wildcard_detected" = true ]; then
        echo "WILDCARD DNS DETECTED: $domain uses wildcard DNS" >> "$wildcard_output"
        echo -e "${YELLOW}[!] Wildcard DNS detected for $domain${NC}"
    else
        echo "NO WILDCARD: $domain does not use wildcard DNS" >> "$wildcard_output"
        echo -e "${GREEN}[+] No wildcard DNS detected for $domain${NC}"
    fi
}

# Attempt DNS zone transfers
attempt_zone_transfer() {
    local domain="$1"
    local output_dir="$2"
    
    echo -e "${BLUE}[*] Attempting DNS zone transfers...${NC}"
    
    local zone_transfer_output="$output_dir/zone_transfers.txt"
    
    cat > "$zone_transfer_output" << EOF
DNS Zone Transfer Attempts for: $domain
Generated: $(date)
=====================================

EOF
    
    # Get authoritative name servers
    local name_servers=$(dig "$domain" NS +short 2>/dev/null)
    
    if [ -n "$name_servers" ]; then
        echo "Authoritative Name Servers:" >> "$zone_transfer_output"
        echo "$name_servers" >> "$zone_transfer_output"
        echo "" >> "$zone_transfer_output"
        
        for ns in $name_servers; do
            echo "=== Attempting zone transfer from $ns ===" >> "$zone_transfer_output"
            
            local transfer_result=$(dig @"$ns" "$domain" AXFR 2>/dev/null)
            
            if echo "$transfer_result" | grep -q "XFR size"; then
                echo "SUCCESS: Zone transfer succeeded" >> "$zone_transfer_output"
                echo "$transfer_result" >> "$zone_transfer_output"
                echo -e "${RED}[!] Zone transfer succeeded from $ns${NC}"
            else
                echo "FAILED: Zone transfer denied or failed" >> "$zone_transfer_output"
            fi
            
            echo "" >> "$zone_transfer_output"
            echo "----------------------------------------" >> "$zone_transfer_output"
            echo "" >> "$zone_transfer_output"
        done
    else
        echo "No authoritative name servers found" >> "$zone_transfer_output"
    fi
}

# Check DNS cache poisoning vulnerability
check_dns_cache_poisoning() {
    local domain="$1"
    local output_dir="$2"
    
    echo -e "${BLUE}[*] Checking for DNS cache poisoning vulnerabilities...${NC}"
    
    local cache_test_output="$output_dir/dns_cache_test.txt"
    
    cat > "$cache_test_output" << EOF
DNS Cache Poisoning Test for: $domain
Generated: $(date)
===================================

EOF
    
    # Test DNS server randomization
    echo "=== DNS Query ID Randomization Test ===" >> "$cache_test_output"
    
    local query_ids=()
    for i in {1..10}; do
        local query_output=$(dig "$domain" A +noall +comments 2>/dev/null | grep "id:")
        if [ -n "$query_output" ]; then
            local query_id=$(echo "$query_output" | sed 's/.*id: \([0-9]*\).*/\1/')
            query_ids+=("$query_id")
            echo "Query $i ID: $query_id" >> "$cache_test_output"
        fi
    done
    
    echo "" >> "$cache_test_output"
    
    # Check for randomization
    local unique_ids=$(printf '%s\n' "${query_ids[@]}" | sort -u | wc -l)
    local total_queries=${#query_ids[@]}
    
    if [ "$unique_ids" -eq "$total_queries" ]; then
        echo "GOOD: Query IDs appear to be randomized ($unique_ids unique out of $total_queries)" >> "$cache_test_output"
        echo -e "${GREEN}[+] DNS query IDs appear randomized${NC}"
    else
        echo "POTENTIAL ISSUE: Query IDs may not be properly randomized ($unique_ids unique out of $total_queries)" >> "$cache_test_output"
        echo -e "${YELLOW}[!] Potential DNS query ID randomization issue${NC}"
    fi
    
    echo "" >> "$cache_test_output"
    
    # Test source port randomization
    echo "=== Source Port Randomization Test ===" >> "$cache_test_output"
    echo "Note: This test requires root privileges for accurate results" >> "$cache_test_output"
    
    if [ "$EUID" -eq 0 ]; then
        # This would require more complex testing with packet capture
        echo "Root privileges detected - detailed port randomization test could be performed" >> "$cache_test_output"
    else
        echo "Non-root user - basic port test only" >> "$cache_test_output"
    fi
}

# Analyze DNS security
analyze_dns_security() {
    local domain="$1"
    local output_dir="$2"
    
    echo -e "${BLUE}[*] Analyzing DNS security configuration...${NC}"
    
    local security_analysis="$output_dir/dns_security_analysis.txt"
    
    cat > "$security_analysis" << EOF
DNS Security Analysis for: $domain
Generated: $(date)
=================================

EOF
    
    # Check for DNSSEC
    echo "=== DNSSEC Analysis ===" >> "$security_analysis"
    local dnssec_result=$(dig "$domain" DNSKEY +short 2>/dev/null)
    
    if [ -n "$dnssec_result" ]; then
        echo "DNSSEC: ENABLED" >> "$security_analysis"
        echo "DNSKEY records found:" >> "$security_analysis"
        echo "$dnssec_result" >> "$security_analysis"
        echo -e "${GREEN}[+] DNSSEC is enabled for $domain${NC}"
    else
        echo "DNSSEC: NOT DETECTED" >> "$security_analysis"
        echo -e "${YELLOW}[!] DNSSEC not detected for $domain${NC}"
    fi
    
    echo "" >> "$security_analysis"
    
    # Check CAA records
    echo "=== CAA Records Analysis ===" >> "$security_analysis"
    local caa_result=$(dig "$domain" CAA +short 2>/dev/null)
    
    if [ -n "$caa_result" ]; then
        echo "CAA Records: PRESENT" >> "$security_analysis"
        echo "$caa_result" >> "$security_analysis"
        echo -e "${GREEN}[+] CAA records found for $domain${NC}"
    else
        echo "CAA Records: NOT FOUND" >> "$security_analysis"
        echo -e "${YELLOW}[!] No CAA records found for $domain${NC}"
    fi
    
    echo "" >> "$security_analysis"
    
    # Check TXT records for security policies
    echo "=== Security-related TXT Records ===" >> "$security_analysis"
    local txt_records=$(dig "$domain" TXT +short 2>/dev/null)
    
    if [ -n "$txt_records" ]; then
        echo "TXT Records found:" >> "$security_analysis"
        echo "$txt_records" >> "$security_analysis"
        
        # Check for SPF, DKIM, DMARC
        if echo "$txt_records" | grep -qi "spf"; then
            echo -e "${GREEN}[+] SPF record found${NC}"
        fi
        
        if echo "$txt_records" | grep -qi "dkim"; then
            echo -e "${GREEN}[+] DKIM record found${NC}"
        fi
        
        if echo "$txt_records" | grep -qi "dmarc"; then
            echo -e "${GREEN}[+] DMARC record found${NC}"
        fi
    else
        echo "No TXT records found" >> "$security_analysis"
    fi
}

# Generate comprehensive DNS report
generate_dns_report() {
    local output_dir="$1"
    local domain="$2"
    
    echo -e "${BLUE}[*] Generating comprehensive DNS report...${NC}"
    
    local report_file="$output_dir/dns_comprehensive_report.txt"
    
    cat > "$report_file" << EOF
Comprehensive DNS Analysis Report
Domain: $domain
Generated: $(date)
================================

EOF
    
    # Include all analysis results
    for analysis_file in "$output_dir"/*.txt; do
        if [ -f "$analysis_file" ] && [ "$(basename "$analysis_file")" != "dns_comprehensive_report.txt" ]; then
            echo "=== $(basename "$analysis_file" .txt | tr '_' ' ' | tr '[:lower:]' '[:upper:]') ===" >> "$report_file"
            cat "$analysis_file" >> "$report_file"
            echo "" >> "$report_file"
            echo "========================================" >> "$report_file"
            echo "" >> "$report_file"
        fi
    done
    
    echo -e "${GREEN}[+] Comprehensive DNS report saved to: $report_file${NC}"
}

# Generate summary
generate_summary() {
    local output_dir="$1"
    local target="$2"
    
    echo -e "${BLUE}[*] Generating DNS resolution summary...${NC}"
    
    local summary_file="$output_dir/dns_summary.txt"
    
    cat > "$summary_file" << EOF
DNS Resolution Summary for: $target
Generated: $(date)
==================================

EOF
    
    # Count results from different analyses
    {
        echo "=== Analysis Results ==="
        [ -f "$output_dir/basic_dns_records.txt" ] && echo "Basic DNS records: Available"
        [ -f "$output_dir/dnsx_resolution.txt" ] && echo "dnsx resolution: $(wc -l < "$output_dir/dnsx_resolution.txt") records"
        [ -f "$output_dir/dnsrecon_results.txt" ] && echo "dnsrecon analysis: Available"
        [ -f "$output_dir/fierce_results.txt" ] && echo "fierce brute force: $(grep -c "Found:" "$output_dir/fierce_results.txt" 2>/dev/null || echo "0") subdomains"
        [ -f "$output_dir/massdns_results.txt" ] && echo "massdns resolution: $(wc -l < "$output_dir/massdns_results.txt") records"
        echo ""
        
        echo "=== Security Analysis ==="
        if [ -f "$output_dir/dns_security_analysis.txt" ]; then
            if grep -q "DNSSEC: ENABLED" "$output_dir/dns_security_analysis.txt"; then
                echo "DNSSEC: Enabled"
            else
                echo "DNSSEC: Not detected"
            fi
            
            if grep -q "CAA Records: PRESENT" "$output_dir/dns_security_analysis.txt"; then
                echo "CAA Records: Present"
            else
                echo "CAA Records: Not found"
            fi
        fi
        
        if [ -f "$output_dir/wildcard_test.txt" ]; then
            if grep -q "WILDCARD DNS DETECTED" "$output_dir/wildcard_test.txt"; then
                echo "Wildcard DNS: Detected"
            else
                echo "Wildcard DNS: Not detected"
            fi
        fi
        
        if [ -f "$output_dir/zone_transfers.txt" ]; then
            if grep -q "SUCCESS: Zone transfer succeeded" "$output_dir/zone_transfers.txt"; then
                echo "Zone Transfer: VULNERABLE"
            else
                echo "Zone Transfer: Protected"
            fi
        fi
    } >> "$summary_file"
    
    echo -e "${GREEN}[+] Summary report saved to: $summary_file${NC}"
}

# Main execution function
main() {
    local domain=""
    local target_file=""
    local output_dir=""
    local threads=20
    local timeout=5
    local resolvers=""
    local record_types="A,AAAA,CNAME,MX,NS,TXT"
    local use_dnsx=false
    local use_dnsrecon=false
    local use_fierce=false
    local use_dnsmap=false
    local use_massdns=false
    local zone_transfer=false
    local reverse_dns=false
    local wildcard_test=false
    local dns_cache=false
    local subdomain_brute=false
    local run_all=false
    local verbose=false
    
    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            -d|--domain)
                domain="$2"
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
            -t|--threads)
                threads="$2"
                shift 2
                ;;
            --timeout)
                timeout="$2"
                shift 2
                ;;
            --resolvers)
                resolvers="$2"
                shift 2
                ;;
            --record-types)
                record_types="$2"
                shift 2
                ;;
            --dnsx)
                use_dnsx=true
                shift
                ;;
            --dnsrecon)
                use_dnsrecon=true
                shift
                ;;
            --fierce)
                use_fierce=true
                shift
                ;;
            --dnsmap)
                use_dnsmap=true
                shift
                ;;
            --massdns)
                use_massdns=true
                shift
                ;;
            --zone-transfer)
                zone_transfer=true
                shift
                ;;
            --reverse-dns)
                reverse_dns=true
                shift
                ;;
            --wildcard-test)
                wildcard_test=true
                shift
                ;;
            --dns-cache)
                dns_cache=true
                shift
                ;;
            --subdomain-brute)
                subdomain_brute=true
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
    if [ -z "$domain" ] && [ -z "$target_file" ]; then
        echo -e "${RED}[!] Either domain (-d) or target file (-f) is required${NC}"
        show_help
        exit 1
    fi
    
    # Use file or create temp file for single domain
    local dns_target="$target_file"
    if [ -n "$domain" ]; then
        dns_target="/tmp/dns_target_$$"
        echo "$domain" > "$dns_target"
    fi
    
    # Check if target file exists
    if [ ! -f "$dns_target" ]; then
        echo -e "${RED}[!] Target file not found: $dns_target${NC}"
        exit 1
    fi
    
    # Set default output directory
    if [ -z "$output_dir" ]; then
        if [ -n "$domain" ]; then
            output_dir="results/dns-resolution/$domain"
        else
            output_dir="results/dns-resolution/$(basename "$target_file" .txt)"
        fi
    fi
    
    # Create output directory
    mkdir -p "$output_dir"
    
    # Check tools
    if ! check_tools; then
        exit 1
    fi
    
    echo -e "${GREEN}[+] Starting DNS resolution analysis...${NC}"
    [ -n "$domain" ] && echo -e "${BLUE}[*] Domain: $domain${NC}"
    [ -n "$target_file" ] && echo -e "${BLUE}[*] Target file: $target_file${NC}"
    echo -e "${BLUE}[*] Output directory: $output_dir${NC}"
    echo -e "${BLUE}[*] Threads: $threads${NC}"
    echo -e "${BLUE}[*] Record types: $record_types${NC}"
    
    # Set default resolvers if not specified
    if [ -z "$resolvers" ]; then
        resolvers="/tmp/resolvers_$$"
        cat > "$resolvers" << EOF
8.8.8.8
8.8.4.4
1.1.1.1
1.0.0.1
208.67.222.222
208.67.220.220
EOF
    fi
    
    # Run analysis based on flags
    if [ "$run_all" = true ]; then
        use_dnsx=true
        use_dnsrecon=true
        use_fierce=true
        use_dnsmap=true
        use_massdns=true
        zone_transfer=true
        reverse_dns=true
        wildcard_test=true
        dns_cache=true
        subdomain_brute=true
    fi
    
    # If no specific methods selected, run default set
    if [ "$use_dnsx" = false ] && [ "$use_dnsrecon" = false ] && [ "$use_fierce" = false ] && [ "$use_dnsmap" = false ] && [ "$use_massdns" = false ]; then
        use_dnsx=true
        use_dnsrecon=true
        zone_transfer=true
        wildcard_test=true
    fi
    
    # Get first domain for single-domain analyses
    local first_domain=$(head -1 "$dns_target")
    
    # Always run basic DNS resolution
    run_basic_dns "$first_domain" "$output_dir" "$record_types"
    
    # Execute selected DNS analysis methods
    [ "$use_dnsx" = true ] && run_dnsx "$dns_target" "$output_dir" "$threads" "$timeout" "$record_types" "$resolvers"
    [ "$use_dnsrecon" = true ] && run_dnsrecon "$first_domain" "$output_dir" "$threads"
    [ "$use_fierce" = true ] && run_fierce "$first_domain" "$output_dir" "$threads"
    [ "$use_dnsmap" = true ] && run_dnsmap "$first_domain" "$output_dir" "$threads"
    [ "$use_massdns" = true ] && run_massdns "$dns_target" "$output_dir" "$threads" "$resolvers"
    
    # Additional security tests
    [ "$zone_transfer" = true ] && attempt_zone_transfer "$first_domain" "$output_dir"
    [ "$wildcard_test" = true ] && test_wildcard_dns "$first_domain" "$output_dir"
    [ "$dns_cache" = true ] && check_dns_cache_poisoning "$first_domain" "$output_dir"
    
    # DNS security analysis
    analyze_dns_security "$first_domain" "$output_dir"
    
    # Generate reports
    generate_dns_report "$output_dir" "$first_domain"
    generate_summary "$output_dir" "${domain:-$target_file}"
    
    # Clean up temporary files
    [ -n "$domain" ] && [ -f "/tmp/dns_target_$$" ] && rm -f "/tmp/dns_target_$$"
    [ -z "$2" ] && [ -f "/tmp/resolvers_$$" ] && rm -f "/tmp/resolvers_$$"
    
    echo -e "\n${GREEN}[+] DNS Resolution Analysis Completed!${NC}"
    echo -e "${BLUE}[*] Results saved in: $output_dir${NC}"
    echo -e "${GREEN}[+] DNS analysis completed for ${domain:-$target_file}${NC}"
}

# Run main function if script is executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi