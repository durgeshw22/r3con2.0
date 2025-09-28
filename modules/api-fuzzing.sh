#!/bin/bash

# API Fuzzing Module for r3con VAPT Suite
# Comprehensive API endpoint discovery and fuzzing

source "$(dirname "$0")/../utils/common.sh" 2>/dev/null || true

MODULE_NAME="API Fuzzing"
MODULE_VERSION="1.0"

# API fuzzing tools
TOOLS=(
    "ffuf:ffuf"
    "wfuzz:wfuzz"
    "gobuster:gobuster"
    "arjun:arjun"
    "kiterunner:kr"
    "httpx:httpx"
    "nuclei:nuclei"
    "curl:curl"
)

# API wordlists and patterns
API_WORDLISTS=(
    "/usr/share/seclists/Discovery/Web-Content/api/api-endpoints.txt"
    "/usr/share/seclists/Discovery/Web-Content/api/api-endpoints-res.txt"
    "/usr/share/seclists/Discovery/Web-Content/common-api-endpoints-mazen160.txt"
    "/usr/share/wordlists/dirb/common.txt"
)

# API path patterns
API_PATTERNS=(
    "api"
    "v1" "v2" "v3"
    "rest"
    "graphql"
    "swagger"
    "openapi"
    "docs"
    "documentation"
)

# HTTP methods for API testing
HTTP_METHODS=("GET" "POST" "PUT" "DELETE" "PATCH" "HEAD" "OPTIONS")

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

# Find available API wordlist
find_api_wordlist() {
    for wordlist in "${API_WORDLISTS[@]}"; do
        if [ -f "$wordlist" ]; then
            echo "$wordlist"
            return 0
        fi
    done
    echo ""
    return 1
}

# Help function
show_help() {
    cat << EOF
${GREEN}API Fuzzing Module${NC}

${BLUE}Usage:${NC}
    $0 -u <url> [options]

${BLUE}Required:${NC}
    -u, --url           Target URL/base URL

${BLUE}Options:${NC}
    -o, --output        Output directory (default: results/api-fuzzing)
    -w, --wordlist      Custom API wordlist file
    -t, --threads       Number of threads (default: 20)
    -m, --methods       HTTP methods to test (default: GET,POST,PUT,DELETE)
    --headers           Custom headers (format: "Header: Value")
    --auth              Authentication token/header
    --timeout           Request timeout in seconds (default: 10)
    --ffuf             Use ffuf for API endpoint fuzzing
    --wfuzz            Use wfuzz for API endpoint fuzzing
    --gobuster         Use gobuster for API endpoint fuzzing
    --arjun            Use arjun for parameter discovery
    --kiterunner       Use kiterunner for API discovery
    --nuclei           Use nuclei for API vulnerability scanning
    --swagger          Search for Swagger/OpenAPI documentation
    --graphql          Test for GraphQL endpoints
    --json             Test JSON endpoints
    --xml              Test XML endpoints
    --all              Run all available tools and tests
    -v, --verbose       Verbose output
    -h, --help          Show this help message

${BLUE}Examples:${NC}
    $0 -u https://api.example.com --all
    $0 -u https://example.com --ffuf --swagger --graphql
    $0 -u https://api.example.com --arjun --nuclei --json
    $0 -u https://example.com --headers "Authorization: Bearer token"
EOF
}

# Generate API endpoint patterns
generate_api_patterns() {
    local base_url="$1"
    local output_dir="$2"
    
    echo -e "${BLUE}[*] Generating API endpoint patterns...${NC}"
    
    local patterns_file="$output_dir/api_patterns.txt"
    
    # Common API patterns
    {
        for pattern in "${API_PATTERNS[@]}"; do
            echo "$pattern"
            echo "$pattern/"
        done
        
        # Versioned API patterns
        for version in {1..5}; do
            echo "api/v$version"
            echo "api/v$version/"
            echo "v$version/api"
            echo "v$version/api/"
        done
    } > "$patterns_file"
    
    echo -e "${GREEN}[+] Generated API patterns file: $patterns_file${NC}"
    echo "$patterns_file"
}

# ffuf API endpoint fuzzing
run_ffuf_api() {
    local url="$1"
    local output_dir="$2"
    local wordlist="$3"
    local threads="$4"
    local methods="$5"
    local headers="$6"
    local timeout="$7"
    
    echo -e "${BLUE}[*] Running ffuf for API endpoint discovery...${NC}"
    
    local ffuf_output="$output_dir/ffuf_api_endpoints.txt"
    local ffuf_json="$output_dir/ffuf_api_results.json"
    
    local ffuf_args=()
    ffuf_args+=(-u "$url/FUZZ")
    ffuf_args+=(-w "$wordlist")
    ffuf_args+=(-t "$threads")
    ffuf_args+=(-mc "200,201,202,301,302,400,401,403,405,500")
    ffuf_args+=(-timeout "$timeout")
    ffuf_args+=(-o "$ffuf_json")
    ffuf_args+=(-of json)
    ffuf_args+=(-s)
    
    if [ -n "$headers" ]; then
        ffuf_args+=(-H "$headers")
    fi
    
    ffuf "${ffuf_args[@]}"
    
    # Parse JSON results
    if [ -f "$ffuf_json" ]; then
        cat "$ffuf_json" | jq -r '.results[] | "\(.status) \(.length) \(.url)"' > "$ffuf_output"
        local count=$(wc -l < "$ffuf_output")
        echo -e "${GREEN}[+] ffuf found $count API endpoints${NC}"
    fi
    
    # Test different HTTP methods on found endpoints
    if [ -f "$ffuf_output" ] && [ -n "$methods" ]; then
        local methods_output="$output_dir/ffuf_methods_test.txt"
        
        IFS=',' read -ra method_array <<< "$methods"
        for method in "${method_array[@]}"; do
            echo -e "${BLUE}[*] Testing $method method...${NC}"
            while read -r line; do
                local endpoint_url=$(echo "$line" | awk '{print $3}')
                ffuf -u "$endpoint_url" -X "$method" -mc "200,201,202,301,302,400,401,403,405,500" -t 5 -timeout 5 -s >> "$methods_output"
            done < "$ffuf_output"
        done
    fi
}

# Arjun parameter discovery
run_arjun() {
    local url="$1"
    local output_dir="$2"
    local threads="$3"
    local methods="$4"
    local headers="$5"
    
    echo -e "${BLUE}[*] Running arjun for parameter discovery...${NC}"
    
    local arjun_output="$output_dir/arjun_parameters.txt"
    local arjun_args=()
    
    arjun_args+=(-u "$url")
    arjun_args+=(-t "$threads")
    arjun_args+=(-o "$arjun_output")
    
    if [ -n "$methods" ]; then
        arjun_args+=(-m "$methods")
    fi
    
    if [ -n "$headers" ]; then
        arjun_args+=(--headers "$headers")
    fi
    
    arjun "${arjun_args[@]}"
    
    if [ -f "$arjun_output" ]; then
        local count=$(wc -l < "$arjun_output")
        echo -e "${GREEN}[+] arjun found $count parameters${NC}"
    fi
}

# Kiterunner API discovery
run_kiterunner() {
    local url="$1"
    local output_dir="$2"
    local threads="$3"
    
    echo -e "${BLUE}[*] Running kiterunner for API discovery...${NC}"
    
    local kr_output="$output_dir/kiterunner_apis.txt"
    
    if command -v kr &> /dev/null; then
        kr scan -u "$url" -w /usr/share/kiterunner/routes-large.kite -o "$kr_output" -t "$threads"
        
        if [ -f "$kr_output" ]; then
            local count=$(wc -l < "$kr_output")
            echo -e "${GREEN}[+] kiterunner found $count API routes${NC}"
        fi
    else
        echo -e "${YELLOW}[!] Kiterunner not installed, skipping...${NC}"
    fi
}

# Swagger/OpenAPI discovery
discover_swagger() {
    local url="$1"
    local output_dir="$2"
    local headers="$3"
    
    echo -e "${BLUE}[*] Searching for Swagger/OpenAPI documentation...${NC}"
    
    local swagger_output="$output_dir/swagger_docs.txt"
    local swagger_paths=(
        "swagger-ui.html"
        "swagger-ui/index.html"
        "swagger/index.html"
        "api-docs"
        "api/docs"
        "api/swagger.json"
        "api/swagger.yml"
        "swagger.json"
        "swagger.yml"
        "openapi.json"
        "openapi.yml"
        "docs"
        "documentation"
        "redoc"
    )
    
    for path in "${swagger_paths[@]}"; do
        local test_url="$url/$path"
        local response
        
        if [ -n "$headers" ]; then
            response=$(curl -s -H "$headers" -w "%{http_code}" -o /dev/null "$test_url")
        else
            response=$(curl -s -w "%{http_code}" -o /dev/null "$test_url")
        fi
        
        if [[ "$response" =~ ^(200|301|302)$ ]]; then
            echo "$test_url - HTTP $response" >> "$swagger_output"
            echo -e "${GREEN}[+] Found Swagger/API documentation: $test_url${NC}"
        fi
    done
    
    if [ -f "$swagger_output" ]; then
        local count=$(wc -l < "$swagger_output")
        echo -e "${GREEN}[+] Found $count Swagger/API documentation endpoints${NC}"
    fi
}

# GraphQL endpoint discovery
discover_graphql() {
    local url="$1"
    local output_dir="$2"
    local headers="$3"
    
    echo -e "${BLUE}[*] Testing for GraphQL endpoints...${NC}"
    
    local graphql_output="$output_dir/graphql_endpoints.txt"
    local graphql_paths=(
        "graphql"
        "api/graphql"
        "v1/graphql"
        "v2/graphql"
        "graphiql"
        "graphql-playground"
        "playground"
    )
    
    # GraphQL introspection query
    local introspection_query='{"query":"query IntrospectionQuery { __schema { queryType { name } mutationType { name } subscriptionType { name } types { ...FullType } directives { name description locations args { ...InputValue } } } } fragment FullType on __Type { kind name description fields(includeDeprecated: true) { name description args { ...InputValue } type { ...TypeRef } isDeprecated deprecationReason } inputFields { ...InputValue } interfaces { ...TypeRef } enumValues(includeDeprecated: true) { name description isDeprecated deprecationReason } possibleTypes { ...TypeRef } } fragment InputValue on __InputValue { name description type { ...TypeRef } defaultValue } fragment TypeRef on __Type { kind name ofType { kind name ofType { kind name ofType { kind name ofType { kind name ofType { kind name ofType { kind name ofType { kind name } } } } } } } }"}'
    
    for path in "${graphql_paths[@]}"; do
        local test_url="$url/$path"
        local response
        
        # Test GET request
        if [ -n "$headers" ]; then
            response=$(curl -s -H "$headers" -w "%{http_code}" -o /dev/null "$test_url")
        else
            response=$(curl -s -w "%{http_code}" -o /dev/null "$test_url")
        fi
        
        if [[ "$response" =~ ^(200|400|405)$ ]]; then
            echo "$test_url - HTTP $response (GET)" >> "$graphql_output"
            
            # Test POST with introspection query
            local post_headers="Content-Type: application/json"
            if [ -n "$headers" ]; then
                post_headers="$post_headers\n$headers"
            fi
            
            local post_response
            post_response=$(curl -s -H "$post_headers" -d "$introspection_query" -w "%{http_code}" -o /dev/null "$test_url")
            
            if [[ "$post_response" =~ ^(200|400)$ ]]; then
                echo "$test_url - HTTP $post_response (POST/Introspection)" >> "$graphql_output"
                echo -e "${GREEN}[+] Found GraphQL endpoint: $test_url${NC}"
            fi
        fi
    done
    
    if [ -f "$graphql_output" ]; then
        local count=$(wc -l < "$graphql_output")
        echo -e "${GREEN}[+] Found $count GraphQL endpoints${NC}"
    fi
}

# JSON API testing
test_json_apis() {
    local url="$1"
    local output_dir="$2"
    local headers="$3"
    
    echo -e "${BLUE}[*] Testing JSON API endpoints...${NC}"
    
    local json_output="$output_dir/json_api_test.txt"
    local json_test_data='{"test": "data", "id": 1}'
    
    # Common JSON API endpoints
    local json_endpoints=(
        "api/users"
        "api/data"
        "api/items"
        "api/posts"
        "api/products"
        "users.json"
        "data.json"
        "config.json"
    )
    
    for endpoint in "${json_endpoints[@]}"; do
        local test_url="$url/$endpoint"
        
        # Test different HTTP methods
        for method in "GET" "POST" "PUT" "DELETE"; do
            local response
            local test_headers="Content-Type: application/json"
            if [ -n "$headers" ]; then
                test_headers="$test_headers\n$headers"
            fi
            
            if [ "$method" = "GET" ] || [ "$method" = "DELETE" ]; then
                response=$(curl -s -X "$method" -H "$test_headers" -w "%{http_code}" -o /dev/null "$test_url")
            else
                response=$(curl -s -X "$method" -H "$test_headers" -d "$json_test_data" -w "%{http_code}" -o /dev/null "$test_url")
            fi
            
            if [[ "$response" =~ ^(200|201|400|401|403|405|500)$ ]]; then
                echo "$test_url - $method - HTTP $response" >> "$json_output"
            fi
        done
    done
    
    if [ -f "$json_output" ]; then
        local count=$(wc -l < "$json_output")
        echo -e "${GREEN}[+] Tested $count JSON API endpoints${NC}"
    fi
}

# Nuclei API vulnerability scanning
run_nuclei_api() {
    local url="$1"
    local output_dir="$2"
    local headers="$3"
    
    echo -e "${BLUE}[*] Running nuclei for API vulnerability scanning...${NC}"
    
    local nuclei_output="$output_dir/nuclei_api_vulns.txt"
    local nuclei_args=()
    
    nuclei_args+=(-u "$url")
    nuclei_args+=(-t "api/")
    nuclei_args+=(-t "exposures/apis/")
    nuclei_args+=(-o "$nuclei_output")
    nuclei_args+=(-silent)
    
    if [ -n "$headers" ]; then
        nuclei_args+=(-H "$headers")
    fi
    
    nuclei "${nuclei_args[@]}"
    
    if [ -f "$nuclei_output" ]; then
        local count=$(wc -l < "$nuclei_output")
        echo -e "${GREEN}[+] nuclei found $count API vulnerabilities${NC}"
    fi
}

# Analyze API responses
analyze_responses() {
    local output_dir="$1"
    
    echo -e "${BLUE}[*] Analyzing API responses...${NC}"
    
    local analysis_file="$output_dir/api_analysis.txt"
    
    cat > "$analysis_file" << EOF
API Fuzzing Analysis Report
Generated: $(date)
==========================

EOF
    
    # Analyze status codes
    echo "=== Status Code Analysis ===" >> "$analysis_file"
    {
        find "$output_dir" -name "*.txt" -exec grep -h "HTTP [0-9]" {} \; 2>/dev/null | \
        sed 's/.*HTTP \([0-9]*\).*/\1/' | sort | uniq -c | sort -nr
    } >> "$analysis_file"
    
    echo "" >> "$analysis_file"
    
    # Find interesting endpoints
    echo "=== Interesting Endpoints ===" >> "$analysis_file"
    {
        echo "Admin/Management APIs:"
        find "$output_dir" -name "*.txt" -exec grep -i "admin\|manage\|control" {} \; 2>/dev/null || echo "None found"
        echo ""
        
        echo "Authentication APIs:"
        find "$output_dir" -name "*.txt" -exec grep -i "auth\|login\|token\|session" {} \; 2>/dev/null || echo "None found"
        echo ""
        
        echo "User Management APIs:"
        find "$output_dir" -name "*.txt" -exec grep -i "user\|profile\|account" {} \; 2>/dev/null || echo "None found"
        echo ""
        
        echo "Data APIs:"
        find "$output_dir" -name "*.txt" -exec grep -i "data\|export\|import\|backup" {} \; 2>/dev/null || echo "None found"
    } >> "$analysis_file"
    
    echo -e "${GREEN}[+] API analysis saved to: $analysis_file${NC}"
}

# Generate summary report
generate_summary() {
    local output_dir="$1"
    local url="$2"
    
    echo -e "${BLUE}[*] Generating summary report...${NC}"
    
    local summary_file="$output_dir/api_fuzzing_summary.txt"
    
    cat > "$summary_file" << EOF
API Fuzzing Summary for: $url
Generated: $(date)
========================================

EOF
    
    # Count results from each component
    {
        echo "=== Discovery Results ==="
        [ -f "$output_dir/ffuf_api_endpoints.txt" ] && echo "ffuf endpoints: $(wc -l < "$output_dir/ffuf_api_endpoints.txt")"
        [ -f "$output_dir/arjun_parameters.txt" ] && echo "arjun parameters: $(wc -l < "$output_dir/arjun_parameters.txt")"
        [ -f "$output_dir/kiterunner_apis.txt" ] && echo "kiterunner APIs: $(wc -l < "$output_dir/kiterunner_apis.txt")"
        [ -f "$output_dir/swagger_docs.txt" ] && echo "Swagger docs: $(wc -l < "$output_dir/swagger_docs.txt")"
        [ -f "$output_dir/graphql_endpoints.txt" ] && echo "GraphQL endpoints: $(wc -l < "$output_dir/graphql_endpoints.txt")"
        [ -f "$output_dir/json_api_test.txt" ] && echo "JSON API tests: $(wc -l < "$output_dir/json_api_test.txt")"
        [ -f "$output_dir/nuclei_api_vulns.txt" ] && echo "API vulnerabilities: $(wc -l < "$output_dir/nuclei_api_vulns.txt")"
        echo ""
    } >> "$summary_file"
    
    # Include analysis if available
    if [ -f "$output_dir/api_analysis.txt" ]; then
        echo "=== Analysis Results ===" >> "$summary_file"
        tail -n +4 "$output_dir/api_analysis.txt" >> "$summary_file"
    fi
    
    echo -e "${GREEN}[+] Summary report saved to: $summary_file${NC}"
}

# Main execution function
main() {
    local url=""
    local output_dir=""
    local wordlist=""
    local threads=20
    local methods="GET,POST,PUT,DELETE"
    local headers=""
    local auth=""
    local timeout=10
    local run_ffuf=false
    local run_wfuzz=false
    local run_gobuster=false
    local run_arjun=false
    local run_kiterunner=false
    local run_nuclei=false
    local test_swagger=false
    local test_graphql=false
    local test_json=false
    local test_xml=false
    local run_all=false
    local verbose=false
    
    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            -u|--url)
                url="$2"
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
            -m|--methods)
                methods="$2"
                shift 2
                ;;
            --headers)
                headers="$2"
                shift 2
                ;;
            --auth)
                auth="$2"
                headers="Authorization: $auth"
                shift 2
                ;;
            --timeout)
                timeout="$2"
                shift 2
                ;;
            --ffuf)
                run_ffuf=true
                shift
                ;;
            --wfuzz)
                run_wfuzz=true
                shift
                ;;
            --gobuster)
                run_gobuster=true
                shift
                ;;
            --arjun)
                run_arjun=true
                shift
                ;;
            --kiterunner)
                run_kiterunner=true
                shift
                ;;
            --nuclei)
                run_nuclei=true
                shift
                ;;
            --swagger)
                test_swagger=true
                shift
                ;;
            --graphql)
                test_graphql=true
                shift
                ;;
            --json)
                test_json=true
                shift
                ;;
            --xml)
                test_xml=true
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
    if [ -z "$url" ]; then
        echo -e "${RED}[!] URL is required${NC}"
        show_help
        exit 1
    fi
    
    # Set default output directory
    if [ -z "$output_dir" ]; then
        local domain=$(echo "$url" | sed 's|https\?://||' | sed 's|/.*||')
        output_dir="results/api-fuzzing/$domain"
    fi
    
    # Find API wordlist if not specified
    if [ -z "$wordlist" ]; then
        wordlist=$(find_api_wordlist)
        if [ -z "$wordlist" ]; then
            # Generate basic API patterns
            wordlist=$(generate_api_patterns "$url" "$output_dir")
        fi
    fi
    
    # Create output directory
    mkdir -p "$output_dir"
    
    # Check tools
    if ! check_tools; then
        exit 1
    fi
    
    echo -e "${GREEN}[+] Starting API fuzzing for: $url${NC}"
    echo -e "${BLUE}[*] Output directory: $output_dir${NC}"
    echo -e "${BLUE}[*] Wordlist: $wordlist${NC}"
    echo -e "${BLUE}[*] Threads: $threads${NC}"
    echo -e "${BLUE}[*] HTTP methods: $methods${NC}"
    
    # Run tools based on flags
    if [ "$run_all" = true ]; then
        run_ffuf=true
        run_arjun=true
        run_kiterunner=true
        run_nuclei=true
        test_swagger=true
        test_graphql=true
        test_json=true
    fi
    
    # If no specific tools selected, run default set
    if [ "$run_ffuf" = false ] && [ "$run_arjun" = false ] && [ "$run_kiterunner" = false ] && [ "$test_swagger" = false ] && [ "$test_graphql" = false ] && [ "$test_json" = false ]; then
        run_ffuf=true
        run_arjun=true
        test_swagger=true
        test_json=true
    fi
    
    # Execute selected tools and tests
    [ "$run_ffuf" = true ] && run_ffuf_api "$url" "$output_dir" "$wordlist" "$threads" "$methods" "$headers" "$timeout"
    [ "$run_arjun" = true ] && run_arjun "$url" "$output_dir" "$threads" "$methods" "$headers"
    [ "$run_kiterunner" = true ] && run_kiterunner "$url" "$output_dir" "$threads"
    [ "$test_swagger" = true ] && discover_swagger "$url" "$output_dir" "$headers"
    [ "$test_graphql" = true ] && discover_graphql "$url" "$output_dir" "$headers"
    [ "$test_json" = true ] && test_json_apis "$url" "$output_dir" "$headers"
    [ "$run_nuclei" = true ] && run_nuclei_api "$url" "$output_dir" "$headers"
    
    # Analyze results
    analyze_responses "$output_dir"
    
    # Generate summary report
    generate_summary "$output_dir" "$url"
    
    echo -e "\n${GREEN}[+] API Fuzzing Completed!${NC}"
    echo -e "${BLUE}[*] Results saved in: $output_dir${NC}"
    echo -e "${GREEN}[+] API fuzzing completed for $url${NC}"
}

# Run main function if script is executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi