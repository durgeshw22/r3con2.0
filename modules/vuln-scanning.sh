#!/bin/bash

# Vulnerability Scanning Module for r3con VAPT Suite
# Comprehensive vulnerability assessment using multiple scanners

source "$(dirname "$0")/../utils/common.sh" 2>/dev/null || true

MODULE_NAME="Vulnerability Scanning"
MODULE_VERSION="1.0"

# Vulnerability scanning tools
TOOLS=(
    "nuclei:nuclei"
    "nmap:nmap"
    "nikto:nikto"
    "sqlmap:sqlmap"
    "wpscan:wpscan"
    "whatweb:whatweb"
    "sslyze:sslyze"
    "testssl:testssl.sh"
    "dirb:dirb"
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
${GREEN}Vulnerability Scanning Module${NC}

${BLUE}Usage:${NC}
    $0 -u <url> [options] OR $0 -f <file> [options]

${BLUE}Required (choose one):${NC}
    -u, --url           Target URL
    -f, --file          File containing URLs (one per line)

${BLUE}Options:${NC}
    -o, --output        Output directory (default: results/vuln-scanning)
    -t, --threads       Number of threads (default: 10)
    --timeout           Request timeout in seconds (default: 30)
    --nuclei            Run nuclei vulnerability scanner
    --nmap              Run nmap vulnerability scripts
    --nikto             Run nikto web vulnerability scanner
    --sqlmap            Run sqlmap for SQL injection testing
    --wpscan            Run wpscan for WordPress vulnerabilities
    --ssl-scan          Run SSL/TLS vulnerability scanning
    --web-scan          Run web application vulnerability scanning
    --network-scan      Run network vulnerability scanning
    --auth              Authentication for scanning (user:pass)
    --severity          Minimum severity level (info,low,medium,high,critical)
    --exclude           Exclude specific vulnerability types
    --rate-limit        Rate limiting (requests per second)
    --all               Run all available vulnerability scanners
    -v, --verbose       Verbose output
    -h, --help          Show this help message

${BLUE}Examples:${NC}
    $0 -u https://example.com --all
    $0 -f targets.txt --nuclei --nmap --ssl-scan
    $0 -u https://example.com --web-scan --severity medium
    $0 -u https://wordpress.site --wpscan --sqlmap
EOF
}

# Run nuclei vulnerability scanner
run_nuclei_scan() {
    local target="$1"
    local output_dir="$2"
    local threads="$3"
    local severity="$4"
    local exclude="$5"
    
    echo -e "${BLUE}[*] Running nuclei vulnerability scanner...${NC}"
    
    local nuclei_output="$output_dir/nuclei_vulnerabilities.txt"
    local nuclei_json="$output_dir/nuclei_results.json"
    local nuclei_args=()
    
    if [ -f "$target" ]; then
        nuclei_args+=(-l "$target")
    else
        nuclei_args+=(-u "$target")
    fi
    
    nuclei_args+=(-o "$nuclei_output")
    nuclei_args+=(-j "$nuclei_json")
    nuclei_args+=(-c "$threads")
    nuclei_args+=(-silent)
    nuclei_args+=(-stats)
    
    if [ -n "$severity" ]; then
        nuclei_args+=(-severity "$severity")
    fi
    
    if [ -n "$exclude" ]; then
        nuclei_args+=(-exclude-tags "$exclude")
    fi
    
    # Run different template categories
    echo -e "${BLUE}[*] Running CVE templates...${NC}"
    nuclei "${nuclei_args[@]}" -t cves/
    
    echo -e "${BLUE}[*] Running exposure detection templates...${NC}"
    nuclei "${nuclei_args[@]}" -t exposures/
    
    echo -e "${BLUE}[*] Running misconfiguration templates...${NC}"
    nuclei "${nuclei_args[@]}" -t misconfiguration/
    
    echo -e "${BLUE}[*] Running technology detection templates...${NC}"
    nuclei "${nuclei_args[@]}" -t technologies/
    
    echo -e "${BLUE}[*] Running takeover templates...${NC}"
    nuclei "${nuclei_args[@]}" -t takeovers/
    
    if [ -f "$nuclei_output" ]; then
        local count=$(wc -l < "$nuclei_output")
        echo -e "${GREEN}[+] Nuclei found $count vulnerabilities${NC}"
    fi
}

# Run nmap vulnerability scanning
run_nmap_vuln_scan() {
    local target="$1"
    local output_dir="$2"
    local threads="$3"
    
    echo -e "${BLUE}[*] Running nmap vulnerability scripts...${NC}"
    
    local nmap_output="$output_dir/nmap_vulnerabilities.txt"
    local nmap_xml="$output_dir/nmap_vulns.xml"
    
    # Extract hostname/IP from URL if needed
    local host="$target"
    if [[ "$target" =~ ^https?:// ]]; then
        host=$(echo "$target" | sed 's|https\?://||' | sed 's|/.*||' | sed 's|:.*||')
    fi
    
    # Run vulnerability scripts
    nmap -sV --script vuln -T4 -Pn \
         --max-hostgroup "$threads" \
         -oN "$nmap_output" \
         -oX "$nmap_xml" \
         "$host"
    
    if [ -f "$nmap_output" ]; then
        local vuln_count=$(grep -c "VULNERABLE" "$nmap_output" 2>/dev/null || echo "0")
        echo -e "${GREEN}[+] Nmap found $vuln_count potential vulnerabilities${NC}"
    fi
}

# Run nikto web vulnerability scanner
run_nikto_scan() {
    local target="$1"
    local output_dir="$2"
    local timeout="$3"
    
    echo -e "${BLUE}[*] Running nikto web vulnerability scanner...${NC}"
    
    local nikto_output="$output_dir/nikto_scan.txt"
    local nikto_xml="$output_dir/nikto_results.xml"
    
    nikto -h "$target" \
          -output "$nikto_output" \
          -Format txt \
          -timeout "$timeout" \
          -ask no \
          -Plugins "@@ALL"
    
    # Also generate XML output
    nikto -h "$target" \
          -output "$nikto_xml" \
          -Format xml \
          -timeout "$timeout" \
          -ask no \
          -Plugins "@@ALL"
    
    if [ -f "$nikto_output" ]; then
        local finding_count=$(grep -c "+" "$nikto_output" 2>/dev/null || echo "0")
        echo -e "${GREEN}[+] Nikto found $finding_count potential issues${NC}"
    fi
}

# Run sqlmap for SQL injection testing
run_sqlmap_scan() {
    local target="$1"
    local output_dir="$2"
    local auth="$3"
    
    echo -e "${BLUE}[*] Running sqlmap for SQL injection testing...${NC}"
    
    local sqlmap_output="$output_dir/sqlmap_results.txt"
    local sqlmap_args=()
    
    sqlmap_args+=(-u "$target")
    sqlmap_args+=(--batch)
    sqlmap_args+=(--random-agent)
    sqlmap_args+=(--level=2)
    sqlmap_args+=(--risk=2)
    sqlmap_args+=(--threads=5)
    sqlmap_args+=(--output-dir="$output_dir/sqlmap_data")
    
    if [ -n "$auth" ]; then
        sqlmap_args+=(--auth-type=basic)
        sqlmap_args+=(--auth-cred="$auth")
    fi
    
    # Test common parameters
    sqlmap_args+=(--crawl=2)
    sqlmap_args+=(--forms)
    
    sqlmap "${sqlmap_args[@]}" | tee "$sqlmap_output"
    
    if [ -f "$sqlmap_output" ]; then
        local injection_count=$(grep -c "Parameter.*is vulnerable" "$sqlmap_output" 2>/dev/null || echo "0")
        echo -e "${GREEN}[+] SQLMap found $injection_count SQL injection vulnerabilities${NC}"
    fi
}

# Run wpscan for WordPress vulnerabilities
run_wpscan() {
    local target="$1"
    local output_dir="$2"
    local threads="$3"
    
    echo -e "${BLUE}[*] Running wpscan for WordPress vulnerabilities...${NC}"
    
    local wpscan_output="$output_dir/wpscan_results.txt"
    local wpscan_json="$output_dir/wpscan_results.json"
    
    # Check if target is WordPress
    if curl -s "$target/wp-admin/" | grep -qi "wordpress"; then
        wpscan --url "$target" \
               --output "$wpscan_output" \
               --format cli \
               --threads "$threads" \
               --enumerate ap,at,cb,dbe \
               --random-user-agent \
               --plugins-detection aggressive \
               --themes-detection aggressive
        
        # Also generate JSON output
        wpscan --url "$target" \
               --output "$wpscan_json" \
               --format json \
               --threads "$threads" \
               --enumerate ap,at,cb,dbe \
               --random-user-agent
        
        if [ -f "$wpscan_output" ]; then
            local vuln_count=$(grep -c "\[!\]" "$wpscan_output" 2>/dev/null || echo "0")
            echo -e "${GREEN}[+] WPScan found $vuln_count WordPress vulnerabilities${NC}"
        fi
    else
        echo -e "${YELLOW}[!] Target does not appear to be WordPress, skipping WPScan${NC}"
    fi
}

# Run SSL/TLS vulnerability scanning
run_ssl_scan() {
    local target="$1"
    local output_dir="$2"
    
    echo -e "${BLUE}[*] Running SSL/TLS vulnerability scanning...${NC}"
    
    # Extract hostname from URL
    local host=$(echo "$target" | sed 's|https\?://||' | sed 's|/.*||' | sed 's|:.*||')
    local port=443
    
    # Check if port is specified
    if [[ "$target" =~ :[0-9]+/ ]]; then
        port=$(echo "$target" | sed 's|.*:\([0-9]*\)/.*|\1|')
    fi
    
    # Run testssl.sh if available
    if command -v testssl.sh &> /dev/null; then
        local testssl_output="$output_dir/testssl_results.txt"
        testssl.sh --quiet --jsonfile "$output_dir/testssl_results.json" "$host:$port" > "$testssl_output"
        
        if [ -f "$testssl_output" ]; then
            local vuln_count=$(grep -c "VULNERABLE" "$testssl_output" 2>/dev/null || echo "0")
            echo -e "${GREEN}[+] TestSSL found $vuln_count SSL/TLS vulnerabilities${NC}"
        fi
    fi
    
    # Run sslyze if available
    if command -v sslyze &> /dev/null; then
        local sslyze_output="$output_dir/sslyze_results.json"
        sslyze --json_out="$sslyze_output" "$host:$port"
        
        if [ -f "$sslyze_output" ]; then
            echo -e "${GREEN}[+] SSLyze scan completed${NC}"
        fi
    fi
    
    if ! command -v testssl.sh &> /dev/null && ! command -v sslyze &> /dev/null; then
        echo -e "${YELLOW}[!] No SSL scanning tools available (testssl.sh/sslyze)${NC}"
    fi
}

# Run comprehensive web application scanning
run_web_app_scan() {
    local target="$1"
    local output_dir="$2"
    local threads="$3"
    local timeout="$4"
    
    echo -e "${BLUE}[*] Running comprehensive web application scanning...${NC}"
    
    # Technology detection
    echo -e "${BLUE}[*] Detecting web technologies...${NC}"
    local whatweb_output="$output_dir/whatweb_results.txt"
    if command -v whatweb &> /dev/null; then
        whatweb "$target" --aggression=3 --log-brief="$whatweb_output"
        
        if [ -f "$whatweb_output" ]; then
            echo -e "${GREEN}[+] Technology detection completed${NC}"
        fi
    fi
    
    # Directory/file discovery with vulnerability focus
    echo -e "${BLUE}[*] Scanning for vulnerable files and directories...${NC}"
    local dirb_output="$output_dir/dirb_vulns.txt"
    if command -v dirb &> /dev/null; then
        # Use vulnerability-focused wordlist
        local vuln_wordlist="/usr/share/dirb/wordlists/vulns/tests.txt"
        if [ -f "$vuln_wordlist" ]; then
            dirb "$target" "$vuln_wordlist" -o "$dirb_output" -S
        else
            dirb "$target" -o "$dirb_output" -S
        fi
        
        if [ -f "$dirb_output" ]; then
            local found_files=$(grep -c "CODE:" "$dirb_output" 2>/dev/null || echo "0")
            echo -e "${GREEN}[+] Found $found_files potentially vulnerable files${NC}"
        fi
    fi
    
    # Check for common web vulnerabilities
    check_web_vulnerabilities "$target" "$output_dir" "$timeout"
}

# Check for common web vulnerabilities
check_web_vulnerabilities() {
    local target="$1"
    local output_dir="$2"
    local timeout="$3"
    
    echo -e "${BLUE}[*] Checking for common web vulnerabilities...${NC}"
    
    local web_vulns="$output_dir/web_vulnerabilities.txt"
    
    cat > "$web_vulns" << EOF
Web Vulnerability Assessment for: $target
Generated: $(date)
========================================

EOF
    
    # Check for information disclosure
    echo "=== Information Disclosure Tests ===" >> "$web_vulns"
    
    local info_paths=(
        "/.env"
        "/config.php"
        "/wp-config.php"
        "/database.php"
        "/.git/config"
        "/robots.txt"
        "/sitemap.xml"
        "/phpinfo.php"
        "/info.php"
        "/test.php"
        "/backup.sql"
        "/dump.sql"
    )
    
    for path in "${info_paths[@]}"; do
        local test_url="$target$path"
        local response=$(curl -s -w "%{http_code}" -o /dev/null --connect-timeout "$timeout" --max-time "$timeout" "$test_url")
        
        if [ "$response" = "200" ]; then
            echo "FOUND: $test_url - HTTP $response" >> "$web_vulns"
        fi
    done
    
    echo "" >> "$web_vulns"
    
    # Check for admin interfaces
    echo "=== Admin Interface Detection ===" >> "$web_vulns"
    
    local admin_paths=(
        "/admin"
        "/admin.php"
        "/administrator"
        "/wp-admin"
        "/phpmyadmin"
        "/cpanel"
        "/webmail"
        "/mail"
        "/panel"
        "/control"
        "/manage"
    )
    
    for path in "${admin_paths[@]}"; do
        local test_url="$target$path"
        local response=$(curl -s -w "%{http_code}" -o /dev/null --connect-timeout "$timeout" --max-time "$timeout" "$test_url")
        
        if [[ "$response" =~ ^(200|301|302|401|403)$ ]]; then
            echo "FOUND: $test_url - HTTP $response" >> "$web_vulns"
        fi
    done
    
    echo "" >> "$web_vulns"
    
    # Check HTTP security headers
    echo "=== Security Headers Analysis ===" >> "$web_vulns"
    
    local headers_output=$(curl -I -s --connect-timeout "$timeout" --max-time "$timeout" "$target")
    
    local security_headers=(
        "X-Frame-Options"
        "X-XSS-Protection"
        "X-Content-Type-Options"
        "Strict-Transport-Security"
        "Content-Security-Policy"
        "Referrer-Policy"
    )
    
    for header in "${security_headers[@]}"; do
        if echo "$headers_output" | grep -qi "$header"; then
            echo "PRESENT: $header" >> "$web_vulns"
        else
            echo "MISSING: $header" >> "$web_vulns"
        fi
    done
    
    echo -e "${GREEN}[+] Web vulnerability assessment completed${NC}"
}

# Analyze and prioritize vulnerabilities
analyze_vulnerabilities() {
    local output_dir="$1"
    
    echo -e "${BLUE}[*] Analyzing and prioritizing vulnerabilities...${NC}"
    
    local analysis_file="$output_dir/vulnerability_analysis.txt"
    
    cat > "$analysis_file" << EOF
Vulnerability Analysis and Prioritization
Generated: $(date)
========================================

EOF
    
    # Count vulnerabilities by severity
    echo "=== Vulnerability Summary ===" >> "$analysis_file"
    
    if [ -f "$output_dir/nuclei_results.json" ]; then
        echo "Nuclei Findings by Severity:" >> "$analysis_file"
        jq -r '.info.severity' "$output_dir/nuclei_results.json" 2>/dev/null | sort | uniq -c | sort -nr >> "$analysis_file"
        echo "" >> "$analysis_file"
    fi
    
    # High priority findings
    echo "=== High Priority Findings ===" >> "$analysis_file"
    
    {
        [ -f "$output_dir/sqlmap_results.txt" ] && grep -i "vulnerable" "$output_dir/sqlmap_results.txt" | head -5
        [ -f "$output_dir/nuclei_vulnerabilities.txt" ] && grep -E "(critical|high)" "$output_dir/nuclei_vulnerabilities.txt" | head -10
        [ -f "$output_dir/nmap_vulnerabilities.txt" ] && grep "VULNERABLE" "$output_dir/nmap_vulnerabilities.txt" | head -5
    } >> "$analysis_file"
    
    echo "" >> "$analysis_file"
    
    # Recommendations
    echo "=== Recommendations ===" >> "$analysis_file"
    echo "1. Address critical and high severity vulnerabilities immediately" >> "$analysis_file"
    echo "2. Implement missing security headers" >> "$analysis_file"
    echo "3. Remove or secure exposed admin interfaces" >> "$analysis_file"
    echo "4. Fix information disclosure issues" >> "$analysis_file"
    echo "5. Implement SSL/TLS best practices" >> "$analysis_file"
    
    echo -e "${GREEN}[+] Vulnerability analysis saved to: $analysis_file${NC}"
}

# Generate comprehensive report
generate_report() {
    local output_dir="$1"
    local target="$2"
    
    echo -e "${BLUE}[*] Generating comprehensive vulnerability report...${NC}"
    
    local report_file="$output_dir/vulnerability_report.txt"
    
    cat > "$report_file" << EOF
Comprehensive Vulnerability Assessment Report
Target: $target
Generated: $(date)
============================================

EOF
    
    # Executive Summary
    echo "=== Executive Summary ===" >> "$report_file"
    
    local total_vulns=0
    local critical_vulns=0
    local high_vulns=0
    
    if [ -f "$output_dir/nuclei_vulnerabilities.txt" ]; then
        local nuclei_count=$(wc -l < "$output_dir/nuclei_vulnerabilities.txt")
        total_vulns=$((total_vulns + nuclei_count))
        echo "Nuclei Scanner: $nuclei_count findings" >> "$report_file"
    fi
    
    if [ -f "$output_dir/nikto_scan.txt" ]; then
        local nikto_count=$(grep -c "+" "$output_dir/nikto_scan.txt" 2>/dev/null || echo "0")
        total_vulns=$((total_vulns + nikto_count))
        echo "Nikto Scanner: $nikto_count findings" >> "$report_file"
    fi
    
    if [ -f "$output_dir/nmap_vulnerabilities.txt" ]; then
        local nmap_count=$(grep -c "VULNERABLE" "$output_dir/nmap_vulnerabilities.txt" 2>/dev/null || echo "0")
        total_vulns=$((total_vulns + nmap_count))
        echo "Nmap Vulnerability Scripts: $nmap_count findings" >> "$report_file"
    fi
    
    echo "" >> "$report_file"
    echo "Total Vulnerabilities Found: $total_vulns" >> "$report_file"
    echo "" >> "$report_file"
    
    # Include detailed findings from each scanner
    for scanner_file in "$output_dir"/*.txt "$output_dir"/*.json; do
        if [ -f "$scanner_file" ] && [ -s "$scanner_file" ]; then
            local scanner_name=$(basename "$scanner_file" | sed 's/\.[^.]*$//')
            echo "=== $scanner_name Results ===" >> "$report_file"
            
            case "$scanner_file" in
                *.json)
                    if command -v jq &> /dev/null; then
                        jq -r '.[] | select(.info.severity == "critical" or .info.severity == "high") | "\(.info.name) - \(.info.severity)"' "$scanner_file" 2>/dev/null | head -10 >> "$report_file"
                    fi
                    ;;
                *.txt)
                    head -20 "$scanner_file" >> "$report_file"
                    ;;
            esac
            
            echo "" >> "$report_file"
            echo "----------------------------------------" >> "$report_file"
            echo "" >> "$report_file"
        fi
    done
    
    echo -e "${GREEN}[+] Comprehensive report saved to: $report_file${NC}"
}

# Generate summary
generate_summary() {
    local output_dir="$1"
    local target="$2"
    
    echo -e "${BLUE}[*] Generating vulnerability scanning summary...${NC}"
    
    local summary_file="$output_dir/vuln_scan_summary.txt"
    
    cat > "$summary_file" << EOF
Vulnerability Scanning Summary for: $target
Generated: $(date)
==========================================

EOF
    
    # Scan results summary
    {
        echo "=== Scan Results Summary ==="
        [ -f "$output_dir/nuclei_vulnerabilities.txt" ] && echo "Nuclei findings: $(wc -l < "$output_dir/nuclei_vulnerabilities.txt")"
        [ -f "$output_dir/nikto_scan.txt" ] && echo "Nikto findings: $(grep -c "+" "$output_dir/nikto_scan.txt" 2>/dev/null || echo "0")"
        [ -f "$output_dir/nmap_vulnerabilities.txt" ] && echo "Nmap vulns: $(grep -c "VULNERABLE" "$output_dir/nmap_vulnerabilities.txt" 2>/dev/null || echo "0")"
        [ -f "$output_dir/sqlmap_results.txt" ] && echo "SQL injections: $(grep -c "vulnerable" "$output_dir/sqlmap_results.txt" 2>/dev/null || echo "0")"
        [ -f "$output_dir/wpscan_results.txt" ] && echo "WordPress vulns: $(grep -c "\[!\]" "$output_dir/wpscan_results.txt" 2>/dev/null || echo "0")"
        [ -f "$output_dir/testssl_results.txt" ] && echo "SSL/TLS vulns: $(grep -c "VULNERABLE" "$output_dir/testssl_results.txt" 2>/dev/null || echo "0")"
        echo ""
        
        echo "=== Files Generated ==="
        find "$output_dir" -name "*.txt" -o -name "*.json" -o -name "*.xml" | wc -l | xargs echo "Report files:"
        
        if [ -d "$output_dir/sqlmap_data" ]; then
            echo "SQLMap data directory created"
        fi
    } >> "$summary_file"
    
    echo -e "${GREEN}[+] Summary report saved to: $summary_file${NC}"
}

# Main execution function
main() {
    local target=""
    local target_file=""
    local output_dir=""
    local threads=10
    local timeout=30
    local auth=""
    local severity=""
    local exclude=""
    local rate_limit=""
    local run_nuclei=false
    local run_nmap=false
    local run_nikto=false
    local run_sqlmap=false
    local run_wpscan=false
    local run_ssl_scan=false
    local run_web_scan=false
    local run_network_scan=false
    local run_all=false
    local verbose=false
    
    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            -u|--url)
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
            -t|--threads)
                threads="$2"
                shift 2
                ;;
            --timeout)
                timeout="$2"
                shift 2
                ;;
            --auth)
                auth="$2"
                shift 2
                ;;
            --severity)
                severity="$2"
                shift 2
                ;;
            --exclude)
                exclude="$2"
                shift 2
                ;;
            --rate-limit)
                rate_limit="$2"
                shift 2
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
            --sqlmap)
                run_sqlmap=true
                shift
                ;;
            --wpscan)
                run_wpscan=true
                shift
                ;;
            --ssl-scan)
                run_ssl_scan=true
                shift
                ;;
            --web-scan)
                run_web_scan=true
                shift
                ;;
            --network-scan)
                run_network_scan=true
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
        echo -e "${RED}[!] Either target URL (-u) or target file (-f) is required${NC}"
        show_help
        exit 1
    fi
    
    # Use file or create temp file for single target
    local scan_target="$target_file"
    if [ -n "$target" ]; then
        scan_target="/tmp/vuln_scan_target_$$"
        echo "$target" > "$scan_target"
    fi
    
    # Check if target file exists
    if [ ! -f "$scan_target" ]; then
        echo -e "${RED}[!] Target file not found: $scan_target${NC}"
        exit 1
    fi
    
    # Set default output directory
    if [ -z "$output_dir" ]; then
        if [ -n "$target" ]; then
            local domain=$(echo "$target" | sed 's|https\?://||' | sed 's|/.*||')
            output_dir="results/vuln-scanning/$domain"
        else
            output_dir="results/vuln-scanning/$(basename "$target_file" .txt)"
        fi
    fi
    
    # Create output directory
    mkdir -p "$output_dir"
    
    # Check tools
    if ! check_tools; then
        exit 1
    fi
    
    echo -e "${GREEN}[+] Starting vulnerability scanning...${NC}"
    [ -n "$target" ] && echo -e "${BLUE}[*] Target: $target${NC}"
    [ -n "$target_file" ] && echo -e "${BLUE}[*] Target file: $target_file${NC}"
    echo -e "${BLUE}[*] Output directory: $output_dir${NC}"
    echo -e "${BLUE}[*] Threads: $threads${NC}"
    echo -e "${BLUE}[*] Timeout: $timeout seconds${NC}"
    
    # Run scanners based on flags
    if [ "$run_all" = true ]; then
        run_nuclei=true
        run_nmap=true
        run_nikto=true
        run_sqlmap=true
        run_wpscan=true
        run_ssl_scan=true
        run_web_scan=true
        run_network_scan=true
    fi
    
    # If no specific scanners selected, run default set
    if [ "$run_nuclei" = false ] && [ "$run_nmap" = false ] && [ "$run_nikto" = false ] && [ "$run_sqlmap" = false ] && [ "$run_wpscan" = false ] && [ "$run_ssl_scan" = false ] && [ "$run_web_scan" = false ]; then
        run_nuclei=true
        run_nikto=true
        run_ssl_scan=true
        run_web_scan=true
    fi
    
    # Get first target for single-target scanners
    local first_target=$(head -1 "$scan_target")
    
    # Execute selected scanners
    [ "$run_nuclei" = true ] && run_nuclei_scan "$scan_target" "$output_dir" "$threads" "$severity" "$exclude"
    [ "$run_nmap" = true ] && run_nmap_vuln_scan "$first_target" "$output_dir" "$threads"
    [ "$run_nikto" = true ] && run_nikto_scan "$first_target" "$output_dir" "$timeout"
    [ "$run_sqlmap" = true ] && run_sqlmap_scan "$first_target" "$output_dir" "$auth"
    [ "$run_wpscan" = true ] && run_wpscan "$first_target" "$output_dir" "$threads"
    [ "$run_ssl_scan" = true ] && run_ssl_scan "$first_target" "$output_dir"
    [ "$run_web_scan" = true ] && run_web_app_scan "$first_target" "$output_dir" "$threads" "$timeout"
    
    # Analyze results
    analyze_vulnerabilities "$output_dir"
    
    # Generate reports
    generate_report "$output_dir" "${target:-$target_file}"
    generate_summary "$output_dir" "${target:-$target_file}"
    
    # Clean up temporary file if created
    if [ -n "$target" ] && [ -f "/tmp/vuln_scan_target_$$" ]; then
        rm -f "/tmp/vuln_scan_target_$$"
    fi
    
    echo -e "\n${GREEN}[+] Vulnerability Scanning Completed!${NC}"
    echo -e "${BLUE}[*] Results saved in: $output_dir${NC}"
    echo -e "${GREEN}[+] Vulnerability scanning completed for ${target:-$target_file}${NC}"
}

# Run main function if script is executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi