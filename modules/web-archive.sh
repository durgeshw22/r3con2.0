#!/bin/bash

# Web Archive Discovery Module for r3con VAPT Suite
# Historical data discovery from web archives and cached content

source "$(dirname "$0")/../utils/common.sh" 2>/dev/null || true

MODULE_NAME="Web Archive Discovery"
MODULE_VERSION="1.0"

# Web archive tools
TOOLS=(
    "waybackurls:waybackurls"
    "gau:gau"
    "curl:curl"
    "wget:wget"
    "httpx:httpx"
    "unfurl:unfurl"
    "anew:anew"
)

# Web archive services
ARCHIVE_SERVICES=(
    "wayback"
    "commoncrawl"
    "alienvault"
    "urlscan"
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
${GREEN}Web Archive Discovery Module${NC}

${BLUE}Usage:${NC}
    $0 -d <domain> [options]

${BLUE}Required:${NC}
    -d, --domain        Target domain

${BLUE}Options:${NC}
    -o, --output        Output directory (default: results/web-archive)
    -y, --years         Years to search back (default: 5)
    --wayback          Use Wayback Machine
    --commoncrawl      Use Common Crawl
    --alienvault       Use AlienVault OTX
    --urlscan          Use URLScan.io
    --gau              Use GetAllUrls (includes multiple sources)
    --screenshots      Take screenshots of archived pages
    --live-check       Check if archived URLs are still live
    --filter-js        Extract JavaScript files
    --filter-css       Extract CSS files
    --filter-images    Extract image files
    --filter-docs      Extract document files
    --filter-api       Extract API endpoints
    --secrets          Search for secrets in archived content
    --all              Run all available sources and filters
    -v, --verbose       Verbose output
    -h, --help          Show this help message

${BLUE}Examples:${NC}
    $0 -d example.com --all
    $0 -d example.com --wayback --gau --live-check
    $0 -d example.com --screenshots --secrets --filter-js
    $0 -d example.com -y 10 --commoncrawl --filter-api
EOF
}

# Wayback Machine discovery
discover_wayback() {
    local domain="$1"
    local output_dir="$2"
    local years="$3"
    
    echo -e "${BLUE}[*] Searching Wayback Machine for $domain...${NC}"
    
    local wayback_output="$output_dir/wayback_urls.txt"
    
    # Calculate date range
    local current_year=$(date +%Y)
    local start_year=$((current_year - years))
    
    # Use waybackurls
    waybackurls "$domain" > "$wayback_output"
    
    # Also try direct API access with date range
    local api_output="$output_dir/wayback_api.txt"
    for year in $(seq $start_year $current_year); do
        echo -e "${BLUE}[*] Checking year $year...${NC}"
        curl -s "https://web.archive.org/cdx/search/cdx?url=*.$domain&from=${year}0101&to=${year}1231&output=text&fl=original" >> "$api_output"
    done
    
    # Combine and deduplicate
    cat "$wayback_output" "$api_output" 2>/dev/null | sort -u > "$output_dir/wayback_combined.txt"
    
    if [ -f "$output_dir/wayback_combined.txt" ]; then
        local count=$(wc -l < "$output_dir/wayback_combined.txt")
        echo -e "${GREEN}[+] Wayback Machine found $count unique URLs${NC}"
    fi
}

# GetAllUrls (GAU) discovery
discover_gau() {
    local domain="$1"
    local output_dir="$2"
    
    echo -e "${BLUE}[*] Running GetAllUrls for $domain...${NC}"
    
    local gau_output="$output_dir/gau_urls.txt"
    
    # GAU includes multiple sources: wayback, commoncrawl, otx, urlscan
    gau "$domain" --subs > "$gau_output"
    
    if [ -f "$gau_output" ]; then
        local count=$(wc -l < "$gau_output")
        echo -e "${GREEN}[+] GAU found $count URLs from multiple sources${NC}"
    fi
}

# Common Crawl discovery
discover_commoncrawl() {
    local domain="$1"
    local output_dir="$2"
    
    echo -e "${BLUE}[*] Searching Common Crawl for $domain...${NC}"
    
    local cc_output="$output_dir/commoncrawl_urls.txt"
    
    # Get Common Crawl index
    local indexes=$(curl -s "https://index.commoncrawl.org/collinfo.json" | jq -r '.[].id' | head -5)
    
    for index in $indexes; do
        echo -e "${BLUE}[*] Checking index: $index${NC}"
        curl -s "https://index.commoncrawl.org/$index-index?url=*.$domain&output=text&fl=url" >> "$cc_output"
    done
    
    # Clean and deduplicate
    sort -u "$cc_output" > "$output_dir/commoncrawl_clean.txt"
    
    if [ -f "$output_dir/commoncrawl_clean.txt" ]; then
        local count=$(wc -l < "$output_dir/commoncrawl_clean.txt")
        echo -e "${GREEN}[+] Common Crawl found $count unique URLs${NC}"
    fi
}

# AlienVault OTX discovery
discover_alienvault() {
    local domain="$1"
    local output_dir="$2"
    
    echo -e "${BLUE}[*] Searching AlienVault OTX for $domain...${NC}"
    
    local otx_output="$output_dir/alienvault_urls.txt"
    
    # AlienVault OTX API
    curl -s "https://otx.alienvault.com/api/v1/indicators/domain/$domain/url_list" | \
        jq -r '.url_list[].url' > "$otx_output" 2>/dev/null
    
    if [ -f "$otx_output" ]; then
        local count=$(wc -l < "$otx_output")
        echo -e "${GREEN}[+] AlienVault OTX found $count URLs${NC}"
    fi
}

# URLScan.io discovery
discover_urlscan() {
    local domain="$1"
    local output_dir="$2"
    
    echo -e "${BLUE}[*] Searching URLScan.io for $domain...${NC}"
    
    local urlscan_output="$output_dir/urlscan_urls.txt"
    
    # URLScan.io API
    curl -s "https://urlscan.io/api/v1/search/?q=domain:$domain" | \
        jq -r '.results[].page.url' > "$urlscan_output" 2>/dev/null
    
    if [ -f "$urlscan_output" ]; then
        local count=$(wc -l < "$urlscan_output")
        echo -e "${GREEN}[+] URLScan.io found $count URLs${NC}"
    fi
}

# Filter JavaScript files
filter_javascript() {
    local input_file="$1"
    local output_dir="$2"
    
    echo -e "${BLUE}[*] Filtering JavaScript files...${NC}"
    
    local js_output="$output_dir/javascript_files.txt"
    
    grep -i "\.js\|javascript" "$input_file" | \
        grep -v "\.json" | \
        sort -u > "$js_output"
    
    if [ -f "$js_output" ]; then
        local count=$(wc -l < "$js_output")
        echo -e "${GREEN}[+] Found $count JavaScript files${NC}"
    fi
}

# Filter CSS files
filter_css() {
    local input_file="$1"
    local output_dir="$2"
    
    echo -e "${BLUE}[*] Filtering CSS files...${NC}"
    
    local css_output="$output_dir/css_files.txt"
    
    grep -i "\.css" "$input_file" | sort -u > "$css_output"
    
    if [ -f "$css_output" ]; then
        local count=$(wc -l < "$css_output")
        echo -e "${GREEN}[+] Found $count CSS files${NC}"
    fi
}

# Filter image files
filter_images() {
    local input_file="$1"
    local output_dir="$2"
    
    echo -e "${BLUE}[*] Filtering image files...${NC}"
    
    local img_output="$output_dir/image_files.txt"
    
    grep -i "\.\(jpg\|jpeg\|png\|gif\|bmp\|svg\|webp\|ico\)" "$input_file" | \
        sort -u > "$img_output"
    
    if [ -f "$img_output" ]; then
        local count=$(wc -l < "$img_output")
        echo -e "${GREEN}[+] Found $count image files${NC}"
    fi
}

# Filter document files
filter_documents() {
    local input_file="$1"
    local output_dir="$2"
    
    echo -e "${BLUE}[*] Filtering document files...${NC}"
    
    local doc_output="$output_dir/document_files.txt"
    
    grep -i "\.\(pdf\|doc\|docx\|xls\|xlsx\|ppt\|pptx\|txt\|rtf\|odt\)" "$input_file" | \
        sort -u > "$doc_output"
    
    if [ -f "$doc_output" ]; then
        local count=$(wc -l < "$doc_output")
        echo -e "${GREEN}[+] Found $count document files${NC}"
    fi
}

# Filter API endpoints
filter_api_endpoints() {
    local input_file="$1"
    local output_dir="$2"
    
    echo -e "${BLUE}[*] Filtering API endpoints...${NC}"
    
    local api_output="$output_dir/api_endpoints.txt"
    
    grep -i "\(api\|rest\|graphql\|json\|xml\)" "$input_file" | \
        grep -v "\.\(jpg\|jpeg\|png\|gif\|css\|js\|ico\)" | \
        sort -u > "$api_output"
    
    if [ -f "$api_output" ]; then
        local count=$(wc -l < "$api_output")
        echo -e "${GREEN}[+] Found $count potential API endpoints${NC}"
    fi
}

# Check live URLs
check_live_urls() {
    local input_file="$1"
    local output_dir="$2"
    
    echo -e "${BLUE}[*] Checking which archived URLs are still live...${NC}"
    
    local live_output="$output_dir/live_urls.txt"
    
    if command -v httpx &> /dev/null; then
        httpx -l "$input_file" -o "$live_output" -silent -status-code -title
        
        if [ -f "$live_output" ]; then
            local count=$(wc -l < "$live_output")
            echo -e "${GREEN}[+] Found $count live URLs${NC}"
        fi
    else
        echo -e "${YELLOW}[!] httpx not available, skipping live check${NC}"
    fi
}

# Take screenshots of archived pages
take_screenshots() {
    local input_file="$1"
    local output_dir="$2"
    
    echo -e "${BLUE}[*] Taking screenshots of archived pages...${NC}"
    
    local screenshot_dir="$output_dir/screenshots"
    mkdir -p "$screenshot_dir"
    
    # Use gowitness or aquatone if available
    if command -v gowitness &> /dev/null; then
        gowitness file -f "$input_file" -P "$screenshot_dir" --disable-logging
        echo -e "${GREEN}[+] Screenshots saved to: $screenshot_dir${NC}"
    elif command -v aquatone &> /dev/null; then
        cat "$input_file" | aquatone -out "$screenshot_dir" -silent
        echo -e "${GREEN}[+] Screenshots saved to: $screenshot_dir${NC}"
    else
        echo -e "${YELLOW}[!] No screenshot tool available (gowitness/aquatone)${NC}"
    fi
}

# Search for secrets in archived content
search_secrets() {
    local domain="$1"
    local output_dir="$2"
    local all_urls_file="$3"
    
    echo -e "${BLUE}[*] Searching for secrets in archived content...${NC}"
    
    local secrets_output="$output_dir/potential_secrets.txt"
    local temp_content_dir="$output_dir/temp_content"
    mkdir -p "$temp_content_dir"
    
    # Download sample of URLs for content analysis
    local sample_urls="$temp_content_dir/sample_urls.txt"
    head -50 "$all_urls_file" > "$sample_urls"
    
    echo "=== Potential Secrets Found ===" > "$secrets_output"
    echo "Generated: $(date)" >> "$secrets_output"
    echo "" >> "$secrets_output"
    
    while read -r url; do
        if [[ "$url" =~ \.(js|json|xml|txt|config)$ ]]; then
            local content_file="$temp_content_dir/$(echo "$url" | md5sum | cut -d' ' -f1).txt"
            
            # Download content
            curl -s --connect-timeout 5 --max-time 10 "$url" > "$content_file" 2>/dev/null
            
            if [ -s "$content_file" ]; then
                # Search for common secret patterns
                {
                    echo "=== $url ==="
                    
                    # API Keys
                    grep -i "api[_-]key\|apikey" "$content_file" | head -3
                    
                    # Tokens
                    grep -i "token\|jwt\|bearer" "$content_file" | head -3
                    
                    # Database connections
                    grep -i "database\|db_\|mysql\|postgres" "$content_file" | head -3
                    
                    # AWS keys
                    grep -i "aws\|amazon\|s3" "$content_file" | head -3
                    
                    # Email/credentials
                    grep -E "[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}" "$content_file" | head -3
                    
                    echo ""
                } >> "$secrets_output"
            fi
            
            rm -f "$content_file"
        fi
    done < "$sample_urls"
    
    # Clean up
    rm -rf "$temp_content_dir"
    
    local secret_count=$(grep -c "===" "$secrets_output")
    echo -e "${GREEN}[+] Analyzed content from $secret_count URLs for secrets${NC}"
}

# Merge all discovered URLs
merge_all_urls() {
    local output_dir="$1"
    local domain="$2"
    
    echo -e "${BLUE}[*] Merging all discovered URLs...${NC}"
    
    local all_urls="$output_dir/all_archived_urls.txt"
    
    # Combine all URL files
    {
        [ -f "$output_dir/wayback_combined.txt" ] && cat "$output_dir/wayback_combined.txt"
        [ -f "$output_dir/gau_urls.txt" ] && cat "$output_dir/gau_urls.txt"
        [ -f "$output_dir/commoncrawl_clean.txt" ] && cat "$output_dir/commoncrawl_clean.txt"
        [ -f "$output_dir/alienvault_urls.txt" ] && cat "$output_dir/alienvault_urls.txt"
        [ -f "$output_dir/urlscan_urls.txt" ] && cat "$output_dir/urlscan_urls.txt"
    } | grep -v "^$" | sort -u > "$all_urls"
    
    local total_count=$(wc -l < "$all_urls")
    echo -e "${GREEN}[+] Total unique URLs discovered: $total_count${NC}"
    
    echo "$all_urls"
}

# Generate analysis report
generate_analysis() {
    local output_dir="$1"
    local domain="$2"
    local all_urls_file="$3"
    
    echo -e "${BLUE}[*] Generating analysis report...${NC}"
    
    local analysis_file="$output_dir/archive_analysis.txt"
    
    cat > "$analysis_file" << EOF
Web Archive Discovery Analysis for: $domain
Generated: $(date)
========================================

EOF
    
    # URL statistics
    echo "=== URL Statistics ===" >> "$analysis_file"
    echo "Total URLs: $(wc -l < "$all_urls_file")" >> "$analysis_file"
    echo "" >> "$analysis_file"
    
    # Top level domains/subdomains
    echo "=== Top Subdomains ===" >> "$analysis_file"
    cat "$all_urls_file" | unfurl domains 2>/dev/null | sort | uniq -c | sort -nr | head -10 >> "$analysis_file"
    echo "" >> "$analysis_file"
    
    # File extensions
    echo "=== File Extensions ===" >> "$analysis_file"
    cat "$all_urls_file" | unfurl format %s 2>/dev/null | grep '\.' | rev | cut -d'.' -f1 | rev | tr '[:upper:]' '[:lower:]' | sort | uniq -c | sort -nr | head -10 >> "$analysis_file"
    echo "" >> "$analysis_file"
    
    # URL paths
    echo "=== Common Paths ===" >> "$analysis_file"
    cat "$all_urls_file" | unfurl paths 2>/dev/null | cut -d'/' -f2 | sort | uniq -c | sort -nr | head -10 >> "$analysis_file"
    echo "" >> "$analysis_file"
    
    # Parameters
    echo "=== URL Parameters ===" >> "$analysis_file"
    cat "$all_urls_file" | unfurl keys 2>/dev/null | sort | uniq -c | sort -nr | head -10 >> "$analysis_file"
    
    echo -e "${GREEN}[+] Analysis report saved to: $analysis_file${NC}"
}

# Generate summary report
generate_summary() {
    local output_dir="$1"
    local domain="$2"
    
    echo -e "${BLUE}[*] Generating summary report...${NC}"
    
    local summary_file="$output_dir/web_archive_summary.txt"
    
    cat > "$summary_file" << EOF
Web Archive Discovery Summary for: $domain
Generated: $(date)
========================================

EOF
    
    # Count results from each source
    {
        echo "=== Discovery Sources ==="
        [ -f "$output_dir/wayback_combined.txt" ] && echo "Wayback Machine: $(wc -l < "$output_dir/wayback_combined.txt") URLs"
        [ -f "$output_dir/gau_urls.txt" ] && echo "GetAllUrls (Multiple sources): $(wc -l < "$output_dir/gau_urls.txt") URLs"
        [ -f "$output_dir/commoncrawl_clean.txt" ] && echo "Common Crawl: $(wc -l < "$output_dir/commoncrawl_clean.txt") URLs"
        [ -f "$output_dir/alienvault_urls.txt" ] && echo "AlienVault OTX: $(wc -l < "$output_dir/alienvault_urls.txt") URLs"
        [ -f "$output_dir/urlscan_urls.txt" ] && echo "URLScan.io: $(wc -l < "$output_dir/urlscan_urls.txt") URLs"
        echo ""
        
        echo "=== Filtered Results ==="
        [ -f "$output_dir/javascript_files.txt" ] && echo "JavaScript files: $(wc -l < "$output_dir/javascript_files.txt")"
        [ -f "$output_dir/css_files.txt" ] && echo "CSS files: $(wc -l < "$output_dir/css_files.txt")"
        [ -f "$output_dir/image_files.txt" ] && echo "Image files: $(wc -l < "$output_dir/image_files.txt")"
        [ -f "$output_dir/document_files.txt" ] && echo "Document files: $(wc -l < "$output_dir/document_files.txt")"
        [ -f "$output_dir/api_endpoints.txt" ] && echo "API endpoints: $(wc -l < "$output_dir/api_endpoints.txt")"
        [ -f "$output_dir/live_urls.txt" ] && echo "Live URLs: $(wc -l < "$output_dir/live_urls.txt")"
        echo ""
    } >> "$summary_file"
    
    if [ -f "$output_dir/all_archived_urls.txt" ]; then
        local total=$(wc -l < "$output_dir/all_archived_urls.txt")
        echo "Total unique URLs: $total" >> "$summary_file"
    fi
    
    echo -e "${GREEN}[+] Summary report saved to: $summary_file${NC}"
}

# Main execution function
main() {
    local domain=""
    local output_dir=""
    local years=5
    local use_wayback=false
    local use_commoncrawl=false
    local use_alienvault=false
    local use_urlscan=false
    local use_gau=false
    local take_screenshots=false
    local check_live=false
    local filter_js=false
    local filter_css=false
    local filter_images=false
    local filter_docs=false
    local filter_api=false
    local search_secrets=false
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
            -y|--years)
                years="$2"
                shift 2
                ;;
            --wayback)
                use_wayback=true
                shift
                ;;
            --commoncrawl)
                use_commoncrawl=true
                shift
                ;;
            --alienvault)
                use_alienvault=true
                shift
                ;;
            --urlscan)
                use_urlscan=true
                shift
                ;;
            --gau)
                use_gau=true
                shift
                ;;
            --screenshots)
                take_screenshots=true
                shift
                ;;
            --live-check)
                check_live=true
                shift
                ;;
            --filter-js)
                filter_js=true
                shift
                ;;
            --filter-css)
                filter_css=true
                shift
                ;;
            --filter-images)
                filter_images=true
                shift
                ;;
            --filter-docs)
                filter_docs=true
                shift
                ;;
            --filter-api)
                filter_api=true
                shift
                ;;
            --secrets)
                search_secrets=true
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
        output_dir="results/web-archive/$domain"
    fi
    
    # Create output directory
    mkdir -p "$output_dir"
    
    # Check tools
    if ! check_tools; then
        exit 1
    fi
    
    echo -e "${GREEN}[+] Starting web archive discovery for: $domain${NC}"
    echo -e "${BLUE}[*] Output directory: $output_dir${NC}"
    echo -e "${BLUE}[*] Years to search back: $years${NC}"
    
    # Run tools based on flags
    if [ "$run_all" = true ]; then
        use_wayback=true
        use_gau=true
        use_commoncrawl=true
        use_alienvault=true
        use_urlscan=true
        check_live=true
        filter_js=true
        filter_css=true
        filter_images=true
        filter_docs=true
        filter_api=true
        search_secrets=true
        take_screenshots=true
    fi
    
    # If no specific sources selected, run default set
    if [ "$use_wayback" = false ] && [ "$use_gau" = false ] && [ "$use_commoncrawl" = false ] && [ "$use_alienvault" = false ] && [ "$use_urlscan" = false ]; then
        use_wayback=true
        use_gau=true
    fi
    
    # Execute selected discovery methods
    [ "$use_wayback" = true ] && discover_wayback "$domain" "$output_dir" "$years"
    [ "$use_gau" = true ] && discover_gau "$domain" "$output_dir"
    [ "$use_commoncrawl" = true ] && discover_commoncrawl "$domain" "$output_dir"
    [ "$use_alienvault" = true ] && discover_alienvault "$domain" "$output_dir"
    [ "$use_urlscan" = true ] && discover_urlscan "$domain" "$output_dir"
    
    # Merge all URLs
    local all_urls=$(merge_all_urls "$output_dir" "$domain")
    
    # Apply filters
    [ "$filter_js" = true ] && filter_javascript "$all_urls" "$output_dir"
    [ "$filter_css" = true ] && filter_css "$all_urls" "$output_dir"
    [ "$filter_images" = true ] && filter_images "$all_urls" "$output_dir"
    [ "$filter_docs" = true ] && filter_documents "$all_urls" "$output_dir"
    [ "$filter_api" = true ] && filter_api_endpoints "$all_urls" "$output_dir"
    
    # Additional analysis
    [ "$check_live" = true ] && check_live_urls "$all_urls" "$output_dir"
    [ "$take_screenshots" = true ] && take_screenshots "$all_urls" "$output_dir"
    [ "$search_secrets" = true ] && search_secrets "$domain" "$output_dir" "$all_urls"
    
    # Generate analysis and summary
    generate_analysis "$output_dir" "$domain" "$all_urls"
    generate_summary "$output_dir" "$domain"
    
    echo -e "\n${GREEN}[+] Web Archive Discovery Completed!${NC}"
    echo -e "${BLUE}[*] Results saved in: $output_dir${NC}"
    echo -e "${GREEN}[+] Web archive discovery completed for $domain${NC}"
}

# Run main function if script is executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi