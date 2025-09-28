#!/bin/bash

# OSINT (Open Source Intelligence) Module for r3con VAPT Suite
# Comprehensive information gathering from public sources

source "$(dirname "$0")/../utils/common.sh" 2>/dev/null || true

MODULE_NAME="OSINT"
MODULE_VERSION="1.0"

# OSINT tools and services
TOOLS=(
    "whois:whois"
    "dig:dig"
    "curl:curl"
    "wget:wget"
    "nslookup:nslookup"
    "host:host"
)

# External services (no installation required)
EXTERNAL_SERVICES=(
    "shodan"
    "censys"
    "virustotal"
    "haveibeenpwned"
    "urlvoid"
    "dnsdumpster"
    "crt.sh"
    "bgpview"
    "securitytrails"
    "builtwith"
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
${GREEN}OSINT (Open Source Intelligence) Module${NC}

${BLUE}Usage:${NC}
    $0 -t <target> [options] OR $0 -d <domain> [options]

${BLUE}Required (choose one):${NC}
    -t, --target        Target (domain, IP, or organization)
    -d, --domain        Domain name for focused analysis
    -e, --email         Email address for OSINT gathering

${BLUE}Options:${NC}
    -o, --output        Output directory (default: results/osint)
    --whois             Perform WHOIS lookups
    --dns               DNS information gathering
    --ssl               SSL certificate analysis
    --shodan            Shodan search (requires API key)
    --censys            Censys search (requires API key)
    --virustotal        VirusTotal analysis (requires API key)
    --haveibeenpwned    Check breach databases
    --social            Social media reconnaissance
    --email-osint       Email address intelligence
    --company           Company/organization intelligence
    --subdomains        Subdomain intelligence gathering
    --tech-stack        Technology stack identification
    --public-records    Public records search
    --search-engines    Search engine reconnaissance
    --pastors           Paste sites search
    --github            GitHub reconnaissance
    --linkedin          LinkedIn intelligence
    --google-dorking    Google dorking techniques
    --wayback           Wayback machine analysis
    --all               Run all available OSINT techniques
    -v, --verbose       Verbose output
    -h, --help          Show this help message

${BLUE}Configuration:${NC}
    API Keys can be set via environment variables:
    - SHODAN_API_KEY
    - CENSYS_API_ID and CENSYS_API_SECRET
    - VIRUSTOTAL_API_KEY
    - SECURITYTRAILS_API_KEY
    - HAVEIBEENPWNED_API_KEY

${BLUE}Examples:${NC}
    $0 -d example.com --all
    $0 -t "Example Corp" --company --social
    $0 -e user@example.com --email-osint --haveibeenpwned
    $0 -d example.com --dns --ssl --subdomains --tech-stack
EOF
}

# WHOIS information gathering
gather_whois_info() {
    local target="$1"
    local output_dir="$2"
    
    echo -e "${BLUE}[*] Gathering WHOIS information...${NC}"
    
    local whois_output="$output_dir/whois_info.txt"
    
    # Domain WHOIS
    if [[ "$target" =~ ^[a-zA-Z0-9][a-zA-Z0-9-]{1,61}[a-zA-Z0-9]\.[a-zA-Z]{2,}$ ]]; then
        whois "$target" > "$whois_output" 2>&1
        
        # Extract key information
        {
            echo "=== WHOIS Summary ==="
            echo "Domain: $target"
            echo "Registrar: $(grep -i "registrar:" "$whois_output" | head -1 | cut -d: -f2- | xargs)"
            echo "Creation Date: $(grep -i "creation date\|created" "$whois_output" | head -1 | cut -d: -f2- | xargs)"
            echo "Expiration Date: $(grep -i "expir" "$whois_output" | head -1 | cut -d: -f2- | xargs)"
            echo "Name Servers:"
            grep -i "name server" "$whois_output" | cut -d: -f2- | xargs -I {} echo "  {}"
            echo ""
        } >> "$output_dir/whois_summary.txt"
        
        echo -e "${GREEN}[+] WHOIS information gathered${NC}"
    else
        echo -e "${YELLOW}[!] Invalid domain format for WHOIS lookup${NC}"
    fi
}

# DNS information gathering
gather_dns_info() {
    local target="$1"
    local output_dir="$2"
    
    echo -e "${BLUE}[*] Gathering DNS information...${NC}"
    
    local dns_output="$output_dir/dns_info.txt"
    
    {
        echo "=== DNS Information for $target ==="
        echo "Generated: $(date)"
        echo ""
        
        # A records
        echo "=== A Records ==="
        dig +short A "$target" 2>/dev/null | head -10
        echo ""
        
        # AAAA records
        echo "=== AAAA Records (IPv6) ==="
        dig +short AAAA "$target" 2>/dev/null | head -5
        echo ""
        
        # MX records
        echo "=== MX Records ==="
        dig +short MX "$target" 2>/dev/null
        echo ""
        
        # NS records
        echo "=== NS Records ==="
        dig +short NS "$target" 2>/dev/null
        echo ""
        
        # TXT records
        echo "=== TXT Records ==="
        dig +short TXT "$target" 2>/dev/null
        echo ""
        
        # CNAME records
        echo "=== CNAME Records ==="
        dig +short CNAME "$target" 2>/dev/null
        echo ""
        
        # SOA record
        echo "=== SOA Record ==="
        dig +short SOA "$target" 2>/dev/null
        echo ""
        
    } > "$dns_output"
    
    echo -e "${GREEN}[+] DNS information gathered${NC}"
}

# SSL certificate analysis
analyze_ssl_certificates() {
    local target="$1"
    local output_dir="$2"
    
    echo -e "${BLUE}[*] Analyzing SSL certificates...${NC}"
    
    local ssl_output="$output_dir/ssl_certificates.txt"
    
    {
        echo "=== SSL Certificate Analysis for $target ==="
        echo "Generated: $(date)"
        echo ""
        
        # Get certificate information
        echo "=== Certificate Information ==="
        echo | openssl s_client -connect "$target:443" -servername "$target" 2>/dev/null | \
            openssl x509 -text -noout 2>/dev/null || echo "No SSL certificate found"
        echo ""
        
        # Certificate transparency logs
        echo "=== Certificate Transparency (crt.sh) ==="
        curl -s "https://crt.sh/?q=$target&output=json" 2>/dev/null | \
            jq -r '.[].name_value' 2>/dev/null | sort -u | head -50 || \
            echo "Could not retrieve certificate transparency data"
        echo ""
        
    } > "$ssl_output"
    
    echo -e "${GREEN}[+] SSL certificate analysis completed${NC}"
}

# Shodan search
search_shodan() {
    local target="$1"
    local output_dir="$2"
    local api_key="$3"
    
    echo -e "${BLUE}[*] Searching Shodan...${NC}"
    
    local shodan_output="$output_dir/shodan_results.txt"
    
    if [ -n "$api_key" ]; then
        # Search using Shodan API
        local shodan_url="https://api.shodan.io/shodan/host/search?key=$api_key&query=$target"
        
        curl -s "$shodan_url" > "$output_dir/shodan_raw.json" 2>/dev/null
        
        if [ -f "$output_dir/shodan_raw.json" ]; then
            {
                echo "=== Shodan Results for $target ==="
                echo "Generated: $(date)"
                echo ""
                
                # Extract key information
                jq -r '.matches[] | "IP: \(.ip_str)\nPort: \(.port)\nService: \(.product // "Unknown")\nVersion: \(.version // "Unknown")\nOS: \(.os // "Unknown")\nLocation: \(.location.city // "Unknown"), \(.location.country_name // "Unknown")\n---"' \
                    "$output_dir/shodan_raw.json" 2>/dev/null || echo "Could not parse Shodan results"
                
            } > "$shodan_output"
            
            echo -e "${GREEN}[+] Shodan search completed${NC}"
        else
            echo -e "${YELLOW}[!] Could not retrieve Shodan data${NC}"
        fi
    else
        echo -e "${YELLOW}[!] Shodan API key not provided${NC}"
        
        # Manual Shodan web search information
        {
            echo "=== Shodan Manual Search ==="
            echo "Visit: https://www.shodan.io/search?query=$target"
            echo "Search terms to try:"
            echo "  - hostname:$target"
            echo "  - org:\"$target\""
            echo "  - ssl:\"$target\""
        } > "$shodan_output"
    fi
}

# VirusTotal analysis
analyze_virustotal() {
    local target="$1"
    local output_dir="$2"
    local api_key="$3"
    
    echo -e "${BLUE}[*] Analyzing with VirusTotal...${NC}"
    
    local vt_output="$output_dir/virustotal_results.txt"
    
    if [ -n "$api_key" ]; then
        # Domain analysis
        local vt_url="https://www.virustotal.com/vtapi/v2/domain/report"
        
        curl -s --request GET \
             --url "$vt_url?apikey=$api_key&domain=$target" \
             > "$output_dir/virustotal_raw.json" 2>/dev/null
        
        if [ -f "$output_dir/virustotal_raw.json" ]; then
            {
                echo "=== VirusTotal Analysis for $target ==="
                echo "Generated: $(date)"
                echo ""
                
                # Extract key information
                local response_code=$(jq -r '.response_code' "$output_dir/virustotal_raw.json" 2>/dev/null)
                
                if [ "$response_code" = "1" ]; then
                    echo "Domain found in VirusTotal database"
                    echo ""
                    
                    echo "=== Detection Summary ==="
                    jq -r '.detected_urls[]? | "URL: \(.url)\nDetections: \(.positives)/\(.total)\nScan Date: \(.scan_date)\n---"' \
                        "$output_dir/virustotal_raw.json" 2>/dev/null | head -20
                    
                    echo ""
                    echo "=== Passive DNS ==="
                    jq -r '.resolutions[]? | "IP: \(.ip_address)\nLast Resolved: \(.last_resolved)"' \
                        "$output_dir/virustotal_raw.json" 2>/dev/null | head -20
                    
                else
                    echo "Domain not found in VirusTotal database"
                fi
                
            } > "$vt_output"
            
            echo -e "${GREEN}[+] VirusTotal analysis completed${NC}"
        else
            echo -e "${YELLOW}[!] Could not retrieve VirusTotal data${NC}"
        fi
    else
        echo -e "${YELLOW}[!] VirusTotal API key not provided${NC}"
        
        # Manual search information
        {
            echo "=== VirusTotal Manual Analysis ==="
            echo "Visit: https://www.virustotal.com/gui/domain/$target"
            echo "Check for:"
            echo "  - Malware detections"
            echo "  - Passive DNS resolutions"
            echo "  - Related URLs"
            echo "  - Security vendor analysis"
        } > "$vt_output"
    fi
}

# Have I Been Pwned check
check_haveibeenpwned() {
    local email="$1"
    local output_dir="$2"
    local api_key="$3"
    
    echo -e "${BLUE}[*] Checking Have I Been Pwned...${NC}"
    
    local hibp_output="$output_dir/haveibeenpwned_results.txt"
    
    {
        echo "=== Have I Been Pwned Results for $email ==="
        echo "Generated: $(date)"
        echo ""
        
        if [ -n "$api_key" ]; then
            # API search
            local hibp_url="https://haveibeenpwned.com/api/v3/breachedaccount/$email"
            
            local response=$(curl -s -H "hibp-api-key: $api_key" "$hibp_url" 2>/dev/null)
            
            if [ "$response" != "[]" ] && [ -n "$response" ]; then
                echo "Email found in data breaches:"
                echo "$response" | jq -r '.[] | "Breach: \(.Name)\nDomain: \(.Domain)\nBreach Date: \(.BreachDate)\nData Classes: \(.DataClasses | join(", "))\n---"' 2>/dev/null
            else
                echo "Email not found in known data breaches"
            fi
        else
            echo "Manual check required (API key not provided)"
            echo "Visit: https://haveibeenpwned.com/unifiedsearch/$email"
        fi
        
    } > "$hibp_output"
    
    echo -e "${GREEN}[+] Have I Been Pwned check completed${NC}"
}

# Social media reconnaissance
gather_social_intel() {
    local target="$1"
    local output_dir="$2"
    
    echo -e "${BLUE}[*] Gathering social media intelligence...${NC}"
    
    local social_output="$output_dir/social_media_intel.txt"
    
    {
        echo "=== Social Media Intelligence for $target ==="
        echo "Generated: $(date)"
        echo ""
        
        echo "=== Manual Search Recommendations ==="
        echo ""
        
        echo "LinkedIn:"
        echo "  - https://www.linkedin.com/search/results/companies/?keywords=$target"
        echo "  - https://www.linkedin.com/search/results/people/?keywords=$target"
        echo ""
        
        echo "Twitter:"
        echo "  - https://twitter.com/search?q=$target"
        echo "  - Search for: \"$target\" OR @$target"
        echo ""
        
        echo "Facebook:"
        echo "  - https://www.facebook.com/search/top/?q=$target"
        echo ""
        
        echo "Instagram:"
        echo "  - https://www.instagram.com/explore/tags/$target/"
        echo ""
        
        echo "GitHub:"
        echo "  - https://github.com/search?q=$target&type=users"
        echo "  - https://github.com/search?q=$target&type=repositories"
        echo ""
        
        echo "Reddit:"
        echo "  - https://www.reddit.com/search/?q=$target"
        echo ""
        
        echo "YouTube:"
        echo "  - https://www.youtube.com/results?search_query=$target"
        echo ""
        
    } > "$social_output"
    
    echo -e "${GREEN}[+] Social media intelligence gathered${NC}"
}

# Email OSINT gathering
gather_email_osint() {
    local email="$1"
    local output_dir="$2"
    
    echo -e "${BLUE}[*] Gathering email intelligence...${NC}"
    
    local email_output="$output_dir/email_osint.txt"
    local domain=$(echo "$email" | cut -d'@' -f2)
    
    {
        echo "=== Email OSINT for $email ==="
        echo "Generated: $(date)"
        echo ""
        
        echo "=== Email Validation ==="
        # Basic email format check
        if [[ "$email" =~ ^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$ ]]; then
            echo "Email format: Valid"
        else
            echo "Email format: Invalid"
        fi
        echo ""
        
        echo "=== Domain Analysis ==="
        echo "Domain: $domain"
        
        # MX record check
        echo "MX Records:"
        dig +short MX "$domain" 2>/dev/null | head -5 | sed 's/^/  /'
        echo ""
        
        echo "=== Search Recommendations ==="
        echo "Google Search:"
        echo "  - \"$email\""
        echo "  - site:linkedin.com \"$email\""
        echo "  - site:github.com \"$email\""
        echo ""
        
        echo "Specialized Tools:"
        echo "  - hunter.io: Find email patterns for $domain"
        echo "  - clearbit.com: Email and person lookup"
        echo "  - pipl.com: People search"
        echo "  - spokeo.com: Contact information"
        echo ""
        
        echo "=== Paste Sites Search ==="
        echo "Check these sites for email leaks:"
        echo "  - pastebin.com"
        echo "  - paste.ee"
        echo "  - dpaste.com"
        echo "  - justpaste.it"
        echo ""
        
    } > "$email_output"
    
    echo -e "${GREEN}[+] Email OSINT gathering completed${NC}"
}

# Company/Organization intelligence
gather_company_intel() {
    local company="$1"
    local output_dir="$2"
    
    echo -e "${BLUE}[*] Gathering company intelligence...${NC}"
    
    local company_output="$output_dir/company_intelligence.txt"
    
    {
        echo "=== Company Intelligence for $company ==="
        echo "Generated: $(date)"
        echo ""
        
        echo "=== Business Information Sources ==="
        echo ""
        
        echo "Company Registration:"
        echo "  - OpenCorporates: https://opencorporates.com/companies?q=$company"
        echo "  - SEC EDGAR: https://www.sec.gov/edgar/search/"
        echo "  - Companies House (UK): https://find-and-update.company-information.service.gov.uk/"
        echo ""
        
        echo "Financial Information:"
        echo "  - Yahoo Finance"
        echo "  - Google Finance"
        echo "  - Bloomberg"
        echo "  - Reuters"
        echo ""
        
        echo "News and Media:"
        echo "  - Google News: https://news.google.com/search?q=$company"
        echo "  - AllSides News"
        echo "  - Press releases"
        echo ""
        
        echo "Technology Stack:"
        echo "  - BuiltWith: https://builtwith.com/"
        echo "  - Wappalyzer"
        echo "  - Stackshare"
        echo ""
        
        echo "Employee Information:"
        echo "  - LinkedIn company page"
        echo "  - Glassdoor reviews"
        echo "  - Indeed company profile"
        echo ""
        
        echo "Contact Information:"
        echo "  - Company website"
        echo "  - WHOIS data"
        echo "  - Social media profiles"
        echo ""
        
    } > "$company_output"
    
    echo -e "${GREEN}[+] Company intelligence gathered${NC}"
}

# Subdomain intelligence gathering
gather_subdomain_intel() {
    local domain="$1"
    local output_dir="$2"
    
    echo -e "${BLUE}[*] Gathering subdomain intelligence...${NC}"
    
    local subdomain_output="$output_dir/subdomain_intelligence.txt"
    
    # Certificate transparency search
    echo -e "${BLUE}[*] Searching certificate transparency logs...${NC}"
    
    {
        echo "=== Subdomain Intelligence for $domain ==="
        echo "Generated: $(date)"
        echo ""
        
        echo "=== Certificate Transparency Results ==="
        curl -s "https://crt.sh/?q=%.$domain&output=json" 2>/dev/null | \
            jq -r '.[].name_value' 2>/dev/null | \
            grep -E "^[a-zA-Z0-9][a-zA-Z0-9\.-]*\.$domain$" | \
            sort -u | head -100 || echo "Could not retrieve certificate data"
        echo ""
        
        echo "=== DNS Enumeration Recommendations ==="
        echo "Use these tools for comprehensive subdomain discovery:"
        echo "  - subfinder -d $domain"
        echo "  - assetfinder $domain"
        echo "  - amass enum -d $domain"
        echo "  - dnsenum $domain"
        echo ""
        
        echo "=== Public Sources ==="
        echo "  - VirusTotal: Search for subdomains"
        echo "  - DNSDumpster: https://dnsdumpster.com/"
        echo "  - Pentest-tools: https://pentest-tools.com/information-gathering/find-subdomains-of-domain"
        echo "  - SecurityTrails: Historical DNS data"
        echo ""
        
    } > "$subdomain_output"
    
    echo -e "${GREEN}[+] Subdomain intelligence gathered${NC}"
}

# Technology stack identification
identify_tech_stack() {
    local target="$1"
    local output_dir="$2"
    
    echo -e "${BLUE}[*] Identifying technology stack...${NC}"
    
    local tech_output="$output_dir/technology_stack.txt"
    
    {
        echo "=== Technology Stack Analysis for $target ==="
        echo "Generated: $(date)"
        echo ""
        
        # HTTP headers analysis
        echo "=== HTTP Headers Analysis ==="
        curl -I -s "http://$target" 2>/dev/null | head -20 || echo "Could not retrieve HTTP headers"
        echo ""
        
        curl -I -s "https://$target" 2>/dev/null | head -20 || echo "Could not retrieve HTTPS headers"
        echo ""
        
        echo "=== Technology Detection Services ==="
        echo "Manual analysis recommended:"
        echo "  - BuiltWith: https://builtwith.com/$target"
        echo "  - Wappalyzer: Browser extension or https://www.wappalyzer.com/"
        echo "  - WhatRuns: Browser extension"
        echo "  - Netcraft: https://sitereport.netcraft.com/?url=$target"
        echo ""
        
        echo "=== Common Technology Indicators ==="
        echo "Check for these in source code and headers:"
        echo "  - Server headers (Apache, Nginx, IIS)"
        echo "  - X-Powered-By headers"
        echo "  - Framework-specific cookies"
        echo "  - CSS/JS library references"
        echo "  - CMS-specific paths and files"
        echo ""
        
    } > "$tech_output"
    
    echo -e "${GREEN}[+] Technology stack analysis completed${NC}"
}

# Google dorking techniques
perform_google_dorking() {
    local target="$1"
    local output_dir="$2"
    
    echo -e "${BLUE}[*] Generating Google dorking queries...${NC}"
    
    local dorking_output="$output_dir/google_dorking.txt"
    
    {
        echo "=== Google Dorking Queries for $target ==="
        echo "Generated: $(date)"
        echo ""
        
        echo "=== Basic Information Gathering ==="
        echo "site:$target"
        echo "site:*.$target"
        echo "\"$target\""
        echo "inurl:$target"
        echo "intitle:$target"
        echo ""
        
        echo "=== File Discovery ==="
        echo "site:$target filetype:pdf"
        echo "site:$target filetype:doc"
        echo "site:$target filetype:docx"
        echo "site:$target filetype:xls"
        echo "site:$target filetype:xlsx"
        echo "site:$target filetype:ppt"
        echo "site:$target filetype:txt"
        echo "site:$target filetype:xml"
        echo "site:$target filetype:json"
        echo ""
        
        echo "=== Configuration and Sensitive Files ==="
        echo "site:$target inurl:admin"
        echo "site:$target inurl:login"
        echo "site:$target inurl:wp-admin"
        echo "site:$target inurl:phpmyadmin"
        echo "site:$target \"index of\""
        echo "site:$target \"server at\""
        echo "site:$target \"403 forbidden\""
        echo ""
        
        echo "=== Directory Listings ==="
        echo "site:$target intitle:\"index of\" \"parent directory\""
        echo "site:$target intitle:\"index of\" inurl:backup"
        echo "site:$target intitle:\"index of\" inurl:config"
        echo "site:$target intitle:\"index of\" inurl:log"
        echo ""
        
        echo "=== Error Pages and Debug Info ==="
        echo "site:$target \"error\" OR \"exception\" OR \"warning\""
        echo "site:$target \"debug\" OR \"trace\" OR \"stack\""
        echo "site:$target \"mysql\" OR \"sql\" OR \"database\""
        echo ""
        
        echo "=== Social Media and External References ==="
        echo "\"$target\" site:linkedin.com"
        echo "\"$target\" site:twitter.com"
        echo "\"$target\" site:facebook.com"
        echo "\"$target\" site:github.com"
        echo "\"$target\" site:pastebin.com"
        echo ""
        
        echo "=== Email and Contact Information ==="
        echo "\"@$target\""
        echo "\"email\" site:$target"
        echo "\"contact\" site:$target"
        echo "\"phone\" OR \"tel\" site:$target"
        echo ""
        
    } > "$dorking_output"
    
    echo -e "${GREEN}[+] Google dorking queries generated${NC}"
}

# Wayback machine analysis
analyze_wayback_machine() {
    local target="$1"
    local output_dir="$2"
    
    echo -e "${BLUE}[*] Analyzing Wayback Machine data...${NC}"
    
    local wayback_output="$output_dir/wayback_analysis.txt"
    
    {
        echo "=== Wayback Machine Analysis for $target ==="
        echo "Generated: $(date)"
        echo ""
        
        echo "=== Archive Statistics ==="
        # Get basic archive statistics
        curl -s "http://web.archive.org/cdx/search/cdx?url=$target&output=json&limit=1000" 2>/dev/null | \
            jq -r '.[] | select(length > 0) | .[1] + " - " + .[2]' 2>/dev/null | \
            head -20 || echo "Could not retrieve Wayback Machine data"
        echo ""
        
        echo "=== Historical URLs (Sample) ==="
        curl -s "http://web.archive.org/cdx/search/cdx?url=$target/*&output=json&limit=100" 2>/dev/null | \
            jq -r '.[] | select(length > 0) | .[2]' 2>/dev/null | \
            sort -u | head -50 || echo "Could not retrieve historical URLs"
        echo ""
        
        echo "=== Manual Analysis Recommendations ==="
        echo "Visit these URLs for detailed analysis:"
        echo "  - https://web.archive.org/web/*/$target"
        echo "  - https://archive.today/$target"
        echo ""
        
        echo "Look for:"
        echo "  - Old versions of the site"
        echo "  - Removed content or pages"
        echo "  - Historical contact information"
        echo "  - Technology changes over time"
        echo "  - Exposed development/test content"
        echo ""
        
    } > "$wayback_output"
    
    echo -e "${GREEN}[+] Wayback Machine analysis completed${NC}"
}

# Generate comprehensive OSINT report
generate_osint_report() {
    local target="$1"
    local output_dir="$2"
    
    echo -e "${BLUE}[*] Generating comprehensive OSINT report...${NC}"
    
    local report_file="$output_dir/osint_comprehensive_report.txt"
    
    {
        echo "=========================================="
        echo "    COMPREHENSIVE OSINT REPORT"
        echo "=========================================="
        echo ""
        echo "Target: $target"
        echo "Generated: $(date)"
        echo "Report Location: $output_dir"
        echo ""
        
        echo "=== EXECUTIVE SUMMARY ==="
        echo ""
        
        # Count available data sources
        local data_sources=0
        [ -f "$output_dir/whois_info.txt" ] && ((data_sources++)) && echo "✓ WHOIS Information Available"
        [ -f "$output_dir/dns_info.txt" ] && ((data_sources++)) && echo "✓ DNS Information Available"
        [ -f "$output_dir/ssl_certificates.txt" ] && ((data_sources++)) && echo "✓ SSL Certificate Data Available"
        [ -f "$output_dir/shodan_results.txt" ] && ((data_sources++)) && echo "✓ Shodan Intelligence Available"
        [ -f "$output_dir/virustotal_results.txt" ] && ((data_sources++)) && echo "✓ VirusTotal Analysis Available"
        [ -f "$output_dir/social_media_intel.txt" ] && ((data_sources++)) && echo "✓ Social Media Intelligence Available"
        [ -f "$output_dir/subdomain_intelligence.txt" ] && ((data_sources++)) && echo "✓ Subdomain Intelligence Available"
        [ -f "$output_dir/technology_stack.txt" ] && ((data_sources++)) && echo "✓ Technology Stack Analysis Available"
        [ -f "$output_dir/google_dorking.txt" ] && ((data_sources++)) && echo "✓ Google Dorking Queries Available"
        [ -f "$output_dir/wayback_analysis.txt" ] && ((data_sources++)) && echo "✓ Wayback Machine Analysis Available"
        
        echo ""
        echo "Total Data Sources Analyzed: $data_sources"
        echo ""
        
        echo "=== KEY FINDINGS SUMMARY ==="
        echo ""
        
        # Domain information summary
        if [ -f "$output_dir/whois_summary.txt" ]; then
            echo "--- Domain Registration ---"
            cat "$output_dir/whois_summary.txt"
            echo ""
        fi
        
        # SSL certificate summary
        if [ -f "$output_dir/ssl_certificates.txt" ]; then
            echo "--- SSL Certificate Status ---"
            if grep -q "Certificate:" "$output_dir/ssl_certificates.txt"; then
                echo "✓ SSL Certificate Found and Analyzed"
            else
                echo "✗ No SSL Certificate Found"
            fi
            echo ""
        fi
        
        echo "=== DETAILED FINDINGS ==="
        echo ""
        echo "Detailed analysis results are available in individual files:"
        
        find "$output_dir" -name "*.txt" -not -name "*report*" -not -name "*summary*" | while read -r file; do
            echo "  - $(basename "$file")"
        done
        
        echo ""
        
        echo "=== RECOMMENDATIONS ==="
        echo ""
        echo "1. Review all gathered intelligence for sensitive information exposure"
        echo "2. Analyze subdomain enumeration results for attack surface mapping"
        echo "3. Check social media and public records for information leakage"
        echo "4. Verify SSL certificate configuration and validity"
        echo "5. Monitor paste sites and breach databases for credential exposure"
        echo "6. Use Google dorking results to identify potential security issues"
        echo "7. Analyze technology stack for known vulnerabilities"
        echo ""
        
        echo "=== NEXT STEPS ==="
        echo ""
        echo "1. Technical Reconnaissance:"
        echo "   - Port scanning and service enumeration"
        echo "   - Web application security testing"
        echo "   - Network infrastructure analysis"
        echo ""
        echo "2. Vulnerability Assessment:"
        echo "   - Automated vulnerability scanning"
        echo "   - Manual security testing"
        echo "   - Configuration review"
        echo ""
        echo "3. Risk Assessment:"
        echo "   - Analyze exposed information for business impact"
        echo "   - Prioritize findings based on exploitability"
        echo "   - Develop remediation recommendations"
        echo ""
        
    } > "$report_file"
    
    echo -e "${GREEN}[+] Comprehensive OSINT report generated: $report_file${NC}"
}

# Generate summary report
generate_summary() {
    local target="$1"
    local output_dir="$2"
    
    echo -e "${BLUE}[*] Generating OSINT summary...${NC}"
    
    local summary_file="$output_dir/osint_summary.txt"
    
    {
        echo "OSINT Summary for: $target"
        echo "Generated: $(date)"
        echo "================================="
        echo ""
        
        echo "=== Data Collection Summary ==="
        
        # Count files and data points
        local total_files=$(find "$output_dir" -name "*.txt" | wc -l)
        local total_json=$(find "$output_dir" -name "*.json" | wc -l)
        
        echo "Total text reports: $total_files"
        echo "Total JSON data files: $total_json"
        echo ""
        
        echo "=== Available Intelligence ==="
        
        find "$output_dir" -name "*.txt" -not -name "*summary*" -not -name "*report*" | while read -r file; do
            local filename=$(basename "$file")
            local line_count=$(wc -l < "$file" 2>/dev/null || echo "0")
            echo "$filename: $line_count lines"
        done
        
        echo ""
        
        echo "=== Manual Review Required ==="
        echo "- Check all generated reports for sensitive information"
        echo "- Verify accuracy of automated data collection"
        echo "- Cross-reference findings across multiple sources"
        echo "- Analyze patterns and correlations in the data"
        
    } > "$summary_file"
    
    echo -e "${GREEN}[+] OSINT summary generated: $summary_file${NC}"
}

# Main execution function
main() {
    local target=""
    local domain=""
    local email=""
    local output_dir=""
    local run_whois=false
    local run_dns=false
    local run_ssl=false
    local run_shodan=false
    local run_censys=false
    local run_virustotal=false
    local run_haveibeenpwned=false
    local run_social=false
    local run_email_osint=false
    local run_company=false
    local run_subdomains=false
    local run_tech_stack=false
    local run_public_records=false
    local run_search_engines=false
    local run_pastors=false
    local run_github=false
    local run_linkedin=false
    local run_google_dorking=false
    local run_wayback=false
    local run_all=false
    local verbose=false
    
    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            -t|--target)
                target="$2"
                shift 2
                ;;
            -d|--domain)
                domain="$2"
                target="$2"
                shift 2
                ;;
            -e|--email)
                email="$2"
                shift 2
                ;;
            -o|--output)
                output_dir="$2"
                shift 2
                ;;
            --whois)
                run_whois=true
                shift
                ;;
            --dns)
                run_dns=true
                shift
                ;;
            --ssl)
                run_ssl=true
                shift
                ;;
            --shodan)
                run_shodan=true
                shift
                ;;
            --censys)
                run_censys=true
                shift
                ;;
            --virustotal)
                run_virustotal=true
                shift
                ;;
            --haveibeenpwned)
                run_haveibeenpwned=true
                shift
                ;;
            --social)
                run_social=true
                shift
                ;;
            --email-osint)
                run_email_osint=true
                shift
                ;;
            --company)
                run_company=true
                shift
                ;;
            --subdomains)
                run_subdomains=true
                shift
                ;;
            --tech-stack)
                run_tech_stack=true
                shift
                ;;
            --public-records)
                run_public_records=true
                shift
                ;;
            --search-engines)
                run_search_engines=true
                shift
                ;;
            --pastors)
                run_pastors=true
                shift
                ;;
            --github)
                run_github=true
                shift
                ;;
            --linkedin)
                run_linkedin=true
                shift
                ;;
            --google-dorking)
                run_google_dorking=true
                shift
                ;;
            --wayback)
                run_wayback=true
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
    if [ -z "$target" ] && [ -z "$email" ]; then
        echo -e "${RED}[!] Either target (-t/-d) or email (-e) is required${NC}"
        show_help
        exit 1
    fi
    
    # Set target for email analysis
    if [ -n "$email" ] && [ -z "$target" ]; then
        target="$email"
    fi
    
    # Set default output directory
    if [ -z "$output_dir" ]; then
        local safe_target=$(echo "$target" | sed 's|[^a-zA-Z0-9._-]|_|g')
        output_dir="results/osint/$safe_target"
    fi
    
    # Create output directory
    mkdir -p "$output_dir"
    
    # Check basic tools
    if ! check_tools; then
        exit 1
    fi
    
    echo -e "${GREEN}[+] Starting OSINT gathering...${NC}"
    echo -e "${BLUE}[*] Target: $target${NC}"
    echo -e "${BLUE}[*] Output directory: $output_dir${NC}"
    
    # Set defaults if no specific modules selected
    if [ "$run_all" = true ]; then
        run_whois=true
        run_dns=true
        run_ssl=true
        run_shodan=true
        run_virustotal=true
        run_social=true
        run_subdomains=true
        run_tech_stack=true
        run_google_dorking=true
        run_wayback=true
        
        if [ -n "$email" ]; then
            run_email_osint=true
            run_haveibeenpwned=true
        fi
    fi
    
    # If no modules selected, run basic set
    if [ "$run_whois" = false ] && [ "$run_dns" = false ] && [ "$run_ssl" = false ] && 
       [ "$run_shodan" = false ] && [ "$run_virustotal" = false ] && [ "$run_social" = false ] &&
       [ "$run_email_osint" = false ] && [ "$run_company" = false ] && [ "$run_subdomains" = false ] &&
       [ "$run_tech_stack" = false ] && [ "$run_google_dorking" = false ] && [ "$run_wayback" = false ]; then
        run_whois=true
        run_dns=true
        run_ssl=true
        run_social=true
        run_google_dorking=true
    fi
    
    # Execute selected modules
    [ "$run_whois" = true ] && [ -n "$domain" ] && gather_whois_info "$domain" "$output_dir"
    [ "$run_dns" = true ] && [ -n "$domain" ] && gather_dns_info "$domain" "$output_dir"
    [ "$run_ssl" = true ] && [ -n "$domain" ] && analyze_ssl_certificates "$domain" "$output_dir"
    [ "$run_shodan" = true ] && search_shodan "$target" "$output_dir" "$SHODAN_API_KEY"
    [ "$run_virustotal" = true ] && analyze_virustotal "$target" "$output_dir" "$VIRUSTOTAL_API_KEY"
    [ "$run_haveibeenpwned" = true ] && [ -n "$email" ] && check_haveibeenpwned "$email" "$output_dir" "$HAVEIBEENPWNED_API_KEY"
    [ "$run_social" = true ] && gather_social_intel "$target" "$output_dir"
    [ "$run_email_osint" = true ] && [ -n "$email" ] && gather_email_osint "$email" "$output_dir"
    [ "$run_company" = true ] && gather_company_intel "$target" "$output_dir"
    [ "$run_subdomains" = true ] && [ -n "$domain" ] && gather_subdomain_intel "$domain" "$output_dir"
    [ "$run_tech_stack" = true ] && [ -n "$domain" ] && identify_tech_stack "$domain" "$output_dir"
    [ "$run_google_dorking" = true ] && perform_google_dorking "$target" "$output_dir"
    [ "$run_wayback" = true ] && [ -n "$domain" ] && analyze_wayback_machine "$domain" "$output_dir"
    
    # Generate reports
    generate_osint_report "$target" "$output_dir"
    generate_summary "$target" "$output_dir"
    
    echo -e "\n${GREEN}[+] OSINT Gathering Completed!${NC}"
    echo -e "${BLUE}[*] Results saved in: $output_dir${NC}"
    echo -e "${GREEN}[+] OSINT gathering completed for $target${NC}"
}

# Run main function if script is executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi