#!/bin/bash

# JavaScript Discovery Module for r3con VAPT Suite
# Comprehensive JavaScript file discovery and analysis

source "$(dirname "$0")/../utils/common.sh" 2>/dev/null || true

MODULE_NAME="JavaScript Discovery"
MODULE_VERSION="1.0"

# JavaScript discovery tools
TOOLS=(
    "waybackurls:waybackurls"
    "gau:gau"
    "httpx:httpx"
    "curl:curl"
    "linkfinder:LinkFinder.py"
    "jsparser:js-beautify"
    "subjs:subjs"
    "nuclei:nuclei"
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
${GREEN}JavaScript Discovery Module${NC}

${BLUE}Usage:${NC}
    $0 -d <domain> [options] OR $0 -u <url> [options]

${BLUE}Required (choose one):${NC}
    -d, --domain        Target domain
    -u, --url           Target URL

${BLUE}Options:${NC}
    -o, --output        Output directory (default: results/js-discovery)
    -t, --threads       Number of threads (default: 20)
    --timeout           Request timeout in seconds (default: 10)
    --wayback           Discover JS files from Wayback Machine
    --gau               Use GetAllUrls for JS discovery
    --subjs             Use SubJS for subdomain JS discovery
    --linkfinder        Use LinkFinder for endpoint extraction
    --secrets           Search for secrets in JS files
    --endpoints         Extract API endpoints from JS
    --beautify          Beautify/format JS files
    --nuclei            Run nuclei JS-related templates
    --download          Download discovered JS files
    --analyze           Perform deep analysis on JS content
    --all               Enable all discovery and analysis options
    -v, --verbose       Verbose output
    -h, --help          Show this help message

${BLUE}Examples:${NC}
    $0 -d example.com --all
    $0 -u https://example.com --wayback --secrets --endpoints
    $0 -d example.com --subjs --linkfinder --download --analyze
    $0 -u https://app.example.com --nuclei --beautify
EOF
}

# Discover JS files from Wayback Machine
discover_wayback_js() {
    local domain="$1"
    local output_dir="$2"
    
    echo -e "${BLUE}[*] Discovering JavaScript files from Wayback Machine...${NC}"
    
    local wayback_js="$output_dir/wayback_js_files.txt"
    
    waybackurls "$domain" | grep -i "\.js" | grep -v "\.json" | sort -u > "$wayback_js"
    
    if [ -f "$wayback_js" ]; then
        local count=$(wc -l < "$wayback_js")
        echo -e "${GREEN}[+] Found $count JavaScript files from Wayback Machine${NC}"
    fi
}

# Use GetAllUrls for JS discovery
discover_gau_js() {
    local domain="$1"
    local output_dir="$2"
    
    echo -e "${BLUE}[*] Using GetAllUrls for JavaScript discovery...${NC}"
    
    local gau_js="$output_dir/gau_js_files.txt"
    
    gau "$domain" | grep -i "\.js" | grep -v "\.json" | sort -u > "$gau_js"
    
    if [ -f "$gau_js" ]; then
        local count=$(wc -l < "$gau_js")
        echo -e "${GREEN}[+] Found $count JavaScript files from GAU${NC}"
    fi
}

# Use SubJS for subdomain JS discovery
discover_subjs() {
    local domain="$1"
    local output_dir="$2"
    local threads="$3"
    
    echo -e "${BLUE}[*] Using SubJS for subdomain JavaScript discovery...${NC}"
    
    local subjs_output="$output_dir/subjs_files.txt"
    
    if command -v subjs &> /dev/null; then
        subjs -d "$domain" -t "$threads" -o "$subjs_output"
        
        if [ -f "$subjs_output" ]; then
            local count=$(wc -l < "$subjs_output")
            echo -e "${GREEN}[+] SubJS found $count JavaScript files${NC}"
        fi
    else
        echo -e "${YELLOW}[!] SubJS not available, skipping...${NC}"
    fi
}

# Discover JS files from live URLs
discover_live_js() {
    local url="$1"
    local output_dir="$2"
    local timeout="$3"
    
    echo -e "${BLUE}[*] Discovering JavaScript files from live URL...${NC}"
    
    local live_js="$output_dir/live_js_files.txt"
    local temp_html="/tmp/js_discovery_$$"
    
    # Get the HTML content
    curl -s --connect-timeout "$timeout" --max-time "$timeout" "$url" > "$temp_html"
    
    # Extract JS file references
    {
        grep -i "src=" "$temp_html" | grep -i "\.js" | sed 's/.*src=["'\'']\([^"'\'']*\.js[^"'\'']*\)["'\''].*/\1/'
        grep -i "script" "$temp_html" | grep -i "\.js" | sed 's/.*\(https\?:\/\/[^"'\'' ]*\.js[^"'\'' ]*\).*/\1/'
    } | sort -u > "$live_js"
    
    # Convert relative URLs to absolute
    local base_url=$(echo "$url" | sed 's|/[^/]*$||')
    sed -i "s|^/|$base_url/|g" "$live_js"
    sed -i "s|^[^h]|$base_url/&|g" "$live_js"
    
    # Clean up
    rm -f "$temp_html"
    
    if [ -f "$live_js" ]; then
        local count=$(wc -l < "$live_js")
        echo -e "${GREEN}[+] Found $count JavaScript files from live URL${NC}"
    fi
}

# Use LinkFinder for endpoint extraction
run_linkfinder() {
    local js_files="$1"
    local output_dir="$2"
    
    echo -e "${BLUE}[*] Running LinkFinder for endpoint extraction...${NC}"
    
    local linkfinder_output="$output_dir/linkfinder_endpoints.txt"
    
    if command -v LinkFinder.py &> /dev/null; then
        while read -r js_url; do
            echo -e "${BLUE}[*] Analyzing: $js_url${NC}"
            LinkFinder.py -i "$js_url" -o cli >> "$linkfinder_output" 2>/dev/null
        done < "$js_files"
        
        if [ -f "$linkfinder_output" ]; then
            # Clean and deduplicate results
            sort -u "$linkfinder_output" > "$output_dir/linkfinder_clean.txt"
            local count=$(wc -l < "$output_dir/linkfinder_clean.txt")
            echo -e "${GREEN}[+] LinkFinder extracted $count endpoints${NC}"
        fi
    else
        echo -e "${YELLOW}[!] LinkFinder not available, skipping...${NC}"
    fi
}

# Download JavaScript files
download_js_files() {
    local js_files="$1"
    local output_dir="$2"
    local timeout="$3"
    
    echo -e "${BLUE}[*] Downloading JavaScript files for analysis...${NC}"
    
    local download_dir="$output_dir/downloaded_js"
    mkdir -p "$download_dir"
    
    local count=0
    local max_files=50  # Limit to prevent excessive downloads
    
    while read -r js_url && [ $count -lt $max_files ]; do
        local filename=$(basename "$js_url" | sed 's/[?#].*//')
        local safe_filename="${filename//[^a-zA-Z0-9._-]/_}"
        local output_file="$download_dir/${count}_${safe_filename}"
        
        echo -e "${BLUE}[*] Downloading: $js_url${NC}"
        
        if curl -s --connect-timeout "$timeout" --max-time "$timeout" "$js_url" -o "$output_file"; then
            if [ -s "$output_file" ]; then
                echo "$js_url -> $output_file" >> "$output_dir/download_mapping.txt"
                ((count++))
            else
                rm -f "$output_file"
            fi
        fi
    done < "$js_files"
    
    echo -e "${GREEN}[+] Downloaded $count JavaScript files to: $download_dir${NC}"
}

# Beautify JavaScript files
beautify_js_files() {
    local download_dir="$1"
    local output_dir="$2"
    
    echo -e "${BLUE}[*] Beautifying JavaScript files...${NC}"
    
    local beautified_dir="$output_dir/beautified_js"
    mkdir -p "$beautified_dir"
    
    local count=0
    
    if command -v js-beautify &> /dev/null; then
        for js_file in "$download_dir"/*.js; do
            if [ -f "$js_file" ]; then
                local basename=$(basename "$js_file")
                js-beautify "$js_file" > "$beautified_dir/beautified_$basename"
                ((count++))
            fi
        done
        
        echo -e "${GREEN}[+] Beautified $count JavaScript files${NC}"
    else
        echo -e "${YELLOW}[!] js-beautify not available, skipping beautification${NC}"
    fi
}

# Search for secrets in JavaScript files
search_js_secrets() {
    local js_files="$1"
    local output_dir="$2"
    local timeout="$3"
    
    echo -e "${BLUE}[*] Searching for secrets in JavaScript files...${NC}"
    
    local secrets_output="$output_dir/js_secrets.txt"
    local temp_js="/tmp/js_secrets_$$"
    
    cat > "$secrets_output" << EOF
JavaScript Secrets Analysis
Generated: $(date)
==========================

EOF
    
    # Secret patterns
    local patterns=(
        "api[_-]?key"
        "secret[_-]?key"
        "access[_-]?token"
        "auth[_-]?token"
        "jwt"
        "bearer"
        "password"
        "passwd"
        "pwd"
        "database"
        "db_"
        "mysql"
        "postgresql"
        "mongodb"
        "redis"
        "aws[_-]?access"
        "aws[_-]?secret"
        "s3[_-]?bucket"
        "google[_-]?api"
        "facebook[_-]?app"
        "twitter[_-]?api"
        "github[_-]?token"
    )
    
    local file_count=0
    local max_files=20  # Limit analysis
    
    while read -r js_url && [ $file_count -lt $max_files ]; do
        echo -e "${BLUE}[*] Analyzing: $js_url${NC}"
        
        # Download JS content
        curl -s --connect-timeout "$timeout" --max-time "$timeout" "$js_url" > "$temp_js"
        
        if [ -s "$temp_js" ]; then
            echo "=== $js_url ===" >> "$secrets_output"
            
            local found_secrets=false
            for pattern in "${patterns[@]}"; do
                local matches=$(grep -i "$pattern" "$temp_js" | head -3)
                if [ -n "$matches" ]; then
                    echo "Pattern: $pattern" >> "$secrets_output"
                    echo "$matches" >> "$secrets_output"
                    echo "" >> "$secrets_output"
                    found_secrets=true
                fi
            done
            
            if [ "$found_secrets" = false ]; then
                echo "No secrets found" >> "$secrets_output"
            fi
            
            echo "----------------------------------------" >> "$secrets_output"
            echo "" >> "$secrets_output"
        fi
        
        ((file_count++))
        rm -f "$temp_js"
    done < "$js_files"
    
    echo -e "${GREEN}[+] Analyzed $file_count JavaScript files for secrets${NC}"
}

# Extract API endpoints from JavaScript
extract_api_endpoints() {
    local js_files="$1"
    local output_dir="$2"
    local timeout="$3"
    
    echo -e "${BLUE}[*] Extracting API endpoints from JavaScript files...${NC}"
    
    local endpoints_output="$output_dir/js_api_endpoints.txt"
    local temp_js="/tmp/js_endpoints_$$"
    
    # API endpoint patterns
    local api_patterns=(
        "\/api\/[a-zA-Z0-9_\/-]+"
        "\/rest\/[a-zA-Z0-9_\/-]+"
        "\/v[0-9]+\/[a-zA-Z0-9_\/-]+"
        "\/graphql"
        "\.json"
        "\.xml"
    )
    
    echo "=== Extracted API Endpoints ===" > "$endpoints_output"
    echo "Generated: $(date)" >> "$endpoints_output"
    echo "" >> "$endpoints_output"
    
    local file_count=0
    local max_files=30
    
    while read -r js_url && [ $file_count -lt $max_files ]; do
        echo -e "${BLUE}[*] Extracting endpoints from: $js_url${NC}"
        
        curl -s --connect-timeout "$timeout" --max-time "$timeout" "$js_url" > "$temp_js"
        
        if [ -s "$temp_js" ]; then
            echo "=== $js_url ===" >> "$endpoints_output"
            
            for pattern in "${api_patterns[@]}"; do
                grep -o "$pattern" "$temp_js" | sort -u >> "$endpoints_output"
            done
            
            # Look for URL patterns
            grep -o "https\?://[a-zA-Z0-9.-]*[a-zA-Z0-9]/[a-zA-Z0-9._/?=&-]*" "$temp_js" | \
                grep -E "(api|rest|v[0-9]+)" | sort -u >> "$endpoints_output"
            
            echo "" >> "$endpoints_output"
        fi
        
        ((file_count++))
        rm -f "$temp_js"
    done < "$js_files"
    
    # Clean and deduplicate
    grep -v "^===" "$endpoints_output" | grep -v "^Generated:" | grep -v "^$" | sort -u > "$output_dir/clean_api_endpoints.txt"
    
    local endpoint_count=$(wc -l < "$output_dir/clean_api_endpoints.txt")
    echo -e "${GREEN}[+] Extracted $endpoint_count unique API endpoints${NC}"
}

# Run nuclei JS-related templates
run_nuclei_js() {
    local js_files="$1"
    local output_dir="$2"
    
    echo -e "${BLUE}[*] Running nuclei JavaScript-related templates...${NC}"
    
    local nuclei_output="$output_dir/nuclei_js_findings.txt"
    
    if command -v nuclei &> /dev/null; then
        # Create temporary URL list
        local temp_urls="/tmp/nuclei_js_urls_$$"
        head -20 "$js_files" > "$temp_urls"  # Limit to prevent excessive scanning
        
        nuclei -l "$temp_urls" -t exposures/files/javascript/ -t exposures/configs/ -o "$nuclei_output" -silent
        
        rm -f "$temp_urls"
        
        if [ -f "$nuclei_output" ]; then
            local finding_count=$(wc -l < "$nuclei_output")
            echo -e "${GREEN}[+] Nuclei found $finding_count JavaScript-related issues${NC}"
        fi
    else
        echo -e "${YELLOW}[!] Nuclei not available, skipping template scan${NC}"
    fi
}

# Merge all discovered JavaScript files
merge_js_files() {
    local output_dir="$1"
    
    echo -e "${BLUE}[*] Merging all discovered JavaScript files...${NC}"
    
    local all_js="$output_dir/all_js_files.txt"
    
    # Combine all JS discovery results
    {
        [ -f "$output_dir/wayback_js_files.txt" ] && cat "$output_dir/wayback_js_files.txt"
        [ -f "$output_dir/gau_js_files.txt" ] && cat "$output_dir/gau_js_files.txt"
        [ -f "$output_dir/subjs_files.txt" ] && cat "$output_dir/subjs_files.txt"
        [ -f "$output_dir/live_js_files.txt" ] && cat "$output_dir/live_js_files.txt"
    } | grep -v "^$" | sort -u > "$all_js"
    
    local total_count=$(wc -l < "$all_js")
    echo -e "${GREEN}[+] Total unique JavaScript files: $total_count${NC}"
    
    echo "$all_js"
}

# Generate analysis report
generate_analysis() {
    local output_dir="$1"
    local domain="$2"
    
    echo -e "${BLUE}[*] Generating JavaScript analysis report...${NC}"
    
    local analysis_file="$output_dir/js_analysis.txt"
    
    cat > "$analysis_file" << EOF
JavaScript Discovery Analysis for: $domain
Generated: $(date)
========================================

EOF
    
    # Statistics
    echo "=== Discovery Statistics ===" >> "$analysis_file"
    [ -f "$output_dir/wayback_js_files.txt" ] && echo "Wayback Machine: $(wc -l < "$output_dir/wayback_js_files.txt") files" >> "$analysis_file"
    [ -f "$output_dir/gau_js_files.txt" ] && echo "GetAllUrls: $(wc -l < "$output_dir/gau_js_files.txt") files" >> "$analysis_file"
    [ -f "$output_dir/subjs_files.txt" ] && echo "SubJS: $(wc -l < "$output_dir/subjs_files.txt") files" >> "$analysis_file"
    [ -f "$output_dir/live_js_files.txt" ] && echo "Live Discovery: $(wc -l < "$output_dir/live_js_files.txt") files" >> "$analysis_file"
    [ -f "$output_dir/all_js_files.txt" ] && echo "Total Unique: $(wc -l < "$output_dir/all_js_files.txt") files" >> "$analysis_file"
    echo "" >> "$analysis_file"
    
    # Analysis Results
    echo "=== Analysis Results ===" >> "$analysis_file"
    [ -f "$output_dir/linkfinder_clean.txt" ] && echo "LinkFinder Endpoints: $(wc -l < "$output_dir/linkfinder_clean.txt")" >> "$analysis_file"
    [ -f "$output_dir/clean_api_endpoints.txt" ] && echo "API Endpoints: $(wc -l < "$output_dir/clean_api_endpoints.txt")" >> "$analysis_file"
    [ -f "$output_dir/nuclei_js_findings.txt" ] && echo "Nuclei Findings: $(wc -l < "$output_dir/nuclei_js_findings.txt")" >> "$analysis_file"
    
    if [ -d "$output_dir/downloaded_js" ]; then
        local download_count=$(find "$output_dir/downloaded_js" -name "*.js" 2>/dev/null | wc -l)
        echo "Downloaded Files: $download_count" >> "$analysis_file"
    fi
    
    echo "" >> "$analysis_file"
    
    # Include interesting findings
    if [ -f "$output_dir/js_secrets.txt" ]; then
        echo "=== Potential Secrets ===" >> "$analysis_file"
        tail -n +4 "$output_dir/js_secrets.txt" | head -20 >> "$analysis_file"
        echo "" >> "$analysis_file"
    fi
    
    echo -e "${GREEN}[+] Analysis report saved to: $analysis_file${NC}"
}

# Generate summary report
generate_summary() {
    local output_dir="$1"
    local target="$2"
    
    echo -e "${BLUE}[*] Generating summary report...${NC}"
    
    local summary_file="$output_dir/js_discovery_summary.txt"
    
    cat > "$summary_file" << EOF
JavaScript Discovery Summary for: $target
Generated: $(date)
========================================

EOF
    
    # Discovery summary
    {
        echo "=== Discovery Summary ==="
        [ -f "$output_dir/all_js_files.txt" ] && echo "Total JavaScript files discovered: $(wc -l < "$output_dir/all_js_files.txt")"
        [ -f "$output_dir/clean_api_endpoints.txt" ] && echo "API endpoints extracted: $(wc -l < "$output_dir/clean_api_endpoints.txt")"
        [ -f "$output_dir/linkfinder_clean.txt" ] && echo "LinkFinder endpoints: $(wc -l < "$output_dir/linkfinder_clean.txt")"
        [ -f "$output_dir/nuclei_js_findings.txt" ] && echo "Security findings: $(wc -l < "$output_dir/nuclei_js_findings.txt")"
        echo ""
        
        echo "=== File Analysis ==="
        if [ -d "$output_dir/downloaded_js" ]; then
            echo "Downloaded for analysis: $(find "$output_dir/downloaded_js" -name "*.js" 2>/dev/null | wc -l) files"
        fi
        if [ -d "$output_dir/beautified_js" ]; then
            echo "Beautified files: $(find "$output_dir/beautified_js" -name "*.js" 2>/dev/null | wc -l) files"
        fi
        
        if [ -f "$output_dir/js_secrets.txt" ]; then
            local secret_files=$(grep -c "^===" "$output_dir/js_secrets.txt" 2>/dev/null || echo "0")
            echo "Files analyzed for secrets: $secret_files"
        fi
    } >> "$summary_file"
    
    echo -e "${GREEN}[+] Summary report saved to: $summary_file${NC}"
}

# Main execution function
main() {
    local domain=""
    local url=""
    local output_dir=""
    local threads=20
    local timeout=10
    local use_wayback=false
    local use_gau=false
    local use_subjs=false
    local use_linkfinder=false
    local search_secrets=false
    local extract_endpoints=false
    local beautify_files=false
    local use_nuclei=false
    local download_files=false
    local analyze_content=false
    local run_all=false
    local verbose=false
    
    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            -d|--domain)
                domain="$2"
                shift 2
                ;;
            -u|--url)
                url="$2"
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
            --wayback)
                use_wayback=true
                shift
                ;;
            --gau)
                use_gau=true
                shift
                ;;
            --subjs)
                use_subjs=true
                shift
                ;;
            --linkfinder)
                use_linkfinder=true
                shift
                ;;
            --secrets)
                search_secrets=true
                shift
                ;;
            --endpoints)
                extract_endpoints=true
                shift
                ;;
            --beautify)
                beautify_files=true
                shift
                ;;
            --nuclei)
                use_nuclei=true
                shift
                ;;
            --download)
                download_files=true
                shift
                ;;
            --analyze)
                analyze_content=true
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
    if [ -z "$domain" ] && [ -z "$url" ]; then
        echo -e "${RED}[!] Either domain (-d) or URL (-u) is required${NC}"
        show_help
        exit 1
    fi
    
    # Extract domain from URL if provided
    if [ -n "$url" ] && [ -z "$domain" ]; then
        domain=$(echo "$url" | sed 's|https\?://||' | sed 's|/.*||')
    fi
    
    # Set default output directory
    if [ -z "$output_dir" ]; then
        output_dir="results/js-discovery/$domain"
    fi
    
    # Create output directory
    mkdir -p "$output_dir"
    
    # Check tools
    if ! check_tools; then
        exit 1
    fi
    
    echo -e "${GREEN}[+] Starting JavaScript discovery...${NC}"
    echo -e "${BLUE}[*] Target: ${domain}${NC}"
    [ -n "$url" ] && echo -e "${BLUE}[*] URL: ${url}${NC}"
    echo -e "${BLUE}[*] Output directory: $output_dir${NC}"
    echo -e "${BLUE}[*] Threads: $threads${NC}"
    
    # Run discovery based on flags
    if [ "$run_all" = true ]; then
        use_wayback=true
        use_gau=true
        use_subjs=true
        use_linkfinder=true
        search_secrets=true
        extract_endpoints=true
        beautify_files=true
        use_nuclei=true
        download_files=true
        analyze_content=true
    fi
    
    # If no specific methods selected, run default set
    if [ "$use_wayback" = false ] && [ "$use_gau" = false ] && [ "$use_subjs" = false ] && [ -z "$url" ]; then
        use_wayback=true
        use_gau=true
        extract_endpoints=true
    fi
    
    # Execute discovery methods
    [ "$use_wayback" = true ] && discover_wayback_js "$domain" "$output_dir"
    [ "$use_gau" = true ] && discover_gau_js "$domain" "$output_dir"
    [ "$use_subjs" = true ] && discover_subjs "$domain" "$output_dir" "$threads"
    [ -n "$url" ] && discover_live_js "$url" "$output_dir" "$timeout"
    
    # Merge all JS files
    local all_js_files=$(merge_js_files "$output_dir")
    
    # Perform analysis if JS files were found
    if [ -f "$all_js_files" ] && [ -s "$all_js_files" ]; then
        [ "$use_linkfinder" = true ] && run_linkfinder "$all_js_files" "$output_dir"
        [ "$extract_endpoints" = true ] && extract_api_endpoints "$all_js_files" "$output_dir" "$timeout"
        [ "$search_secrets" = true ] && search_js_secrets "$all_js_files" "$output_dir" "$timeout"
        [ "$use_nuclei" = true ] && run_nuclei_js "$all_js_files" "$output_dir"
        
        if [ "$download_files" = true ] || [ "$beautify_files" = true ] || [ "$analyze_content" = true ]; then
            download_js_files "$all_js_files" "$output_dir" "$timeout"
            
            if [ -d "$output_dir/downloaded_js" ]; then
                [ "$beautify_files" = true ] && beautify_js_files "$output_dir/downloaded_js" "$output_dir"
            fi
        fi
    else
        echo -e "${YELLOW}[!] No JavaScript files discovered${NC}"
    fi
    
    # Generate analysis and summary
    generate_analysis "$output_dir" "$domain"
    generate_summary "$output_dir" "${url:-$domain}"
    
    echo -e "\n${GREEN}[+] JavaScript Discovery Completed!${NC}"
    echo -e "${BLUE}[*] Results saved in: $output_dir${NC}"
    echo -e "${GREEN}[+] JavaScript discovery completed for ${url:-$domain}${NC}"
}

# Run main function if script is executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi