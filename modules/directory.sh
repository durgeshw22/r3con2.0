#!/bin/bash

# Directory/File Fuzzing Module for r3con VAPT Suite
# Comprehensive directory and file discovery using multiple tools

source "$(dirname "$0")/../utils/common.sh" 2>/dev/null || true

MODULE_NAME="Directory/File Fuzzing"
MODULE_VERSION="1.0"

# Directory fuzzing tools
TOOLS=(
    "ffuf:ffuf"
    "gobuster:gobuster"
    "dirsearch:dirsearch"
    "feroxbuster:feroxbuster"
    "wfuzz:wfuzz"
    "dirb:dirb"
    "httpx:httpx"
)

# Common wordlists
WORDLISTS=(
    "/usr/share/wordlists/dirbuster/directory-list-2.3-medium.txt"
    "/usr/share/wordlists/dirb/common.txt"
    "/usr/share/seclists/Discovery/Web-Content/directory-list-2.3-medium.txt"
    "/usr/share/seclists/Discovery/Web-Content/raft-medium-directories.txt"
    "/usr/share/seclists/Discovery/Web-Content/big.txt"
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

# Find available wordlist
find_wordlist() {
    for wordlist in "${WORDLISTS[@]}"; do
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
${GREEN}Directory/File Fuzzing Module${NC}

${BLUE}Usage:${NC}
    $0 -u <url> [options]

${BLUE}Required:${NC}
    -u, --url           Target URL

${BLUE}Options:${NC}
    -o, --output        Output directory (default: results/directory)
    -w, --wordlist      Custom wordlist file
    -t, --threads       Number of threads (default: 20)
    -x, --extensions    File extensions to search (e.g., php,html,js)
    --status-codes      HTTP status codes to include (default: 200,301,302,403,500)
    --timeout           Request timeout in seconds (default: 10)
    --ffuf             Use ffuf for directory fuzzing
    --gobuster         Use gobuster for directory fuzzing
    --dirsearch        Use dirsearch for directory fuzzing
    --feroxbuster      Use feroxbuster for directory fuzzing
    --wfuzz            Use wfuzz for directory fuzzing
    --dirb             Use dirb for directory fuzzing
    --all              Run all available tools
    --files            Search for files in addition to directories
    --recursive        Enable recursive directory scanning
    -v, --verbose       Verbose output
    -h, --help          Show this help message

${BLUE}Examples:${NC}
    $0 -u https://example.com --all
    $0 -u https://example.com --ffuf --gobuster --files
    $0 -u https://example.com -w custom-wordlist.txt --recursive
    $0 -u https://example.com --feroxbuster -x php,html,js
EOF
}

# ffuf directory fuzzing
run_ffuf() {
    local url="$1"
    local output_dir="$2"
    local wordlist="$3"
    local threads="$4"
    local extensions="$5"
    local status_codes="$6"
    local timeout="$7"
    local search_files="$8"
    
    echo -e "${BLUE}[*] Running ffuf...${NC}"
    
    local ffuf_output="$output_dir/ffuf_directories.txt"
    local ffuf_json="$output_dir/ffuf_results.json"
    
    # Directory fuzzing
    ffuf -u "$url/FUZZ" -w "$wordlist" -t "$threads" -mc "$status_codes" -timeout "$timeout" -o "$ffuf_json" -of json -s
    
    # Parse JSON results
    if [ -f "$ffuf_json" ]; then
        cat "$ffuf_json" | jq -r '.results[] | "\(.status) \(.length) \(.url)"' > "$ffuf_output"
        local count=$(wc -l < "$ffuf_output")
        echo -e "${GREEN}[+] ffuf found $count directories${NC}"
    fi
    
    # File fuzzing if enabled
    if [ "$search_files" = true ] && [ -n "$extensions" ]; then
        local ffuf_files="$output_dir/ffuf_files.txt"
        local ffuf_files_json="$output_dir/ffuf_files.json"
        
        IFS=',' read -ra ext_array <<< "$extensions"
        for ext in "${ext_array[@]}"; do
            ffuf -u "$url/FUZZ.$ext" -w "$wordlist" -t "$threads" -mc "$status_codes" -timeout "$timeout" -o "$ffuf_files_json" -of json -s
            if [ -f "$ffuf_files_json" ]; then
                cat "$ffuf_files_json" | jq -r '.results[] | "\(.status) \(.length) \(.url)"' >> "$ffuf_files"
            fi
        done
        
        if [ -f "$ffuf_files" ]; then
            local file_count=$(wc -l < "$ffuf_files")
            echo -e "${GREEN}[+] ffuf found $file_count files${NC}"
        fi
    fi
}

# Gobuster directory fuzzing
run_gobuster() {
    local url="$1"
    local output_dir="$2"
    local wordlist="$3"
    local threads="$4"
    local extensions="$5"
    local status_codes="$6"
    local timeout="$7"
    local search_files="$8"
    
    echo -e "${BLUE}[*] Running gobuster...${NC}"
    
    local gobuster_output="$output_dir/gobuster_directories.txt"
    
    # Directory fuzzing
    gobuster dir -u "$url" -w "$wordlist" -t "$threads" -s "$status_codes" --timeout "$timeout"s -o "$gobuster_output" -q
    
    if [ -f "$gobuster_output" ]; then
        local count=$(wc -l < "$gobuster_output")
        echo -e "${GREEN}[+] gobuster found $count directories${NC}"
    fi
    
    # File fuzzing if enabled
    if [ "$search_files" = true ] && [ -n "$extensions" ]; then
        local gobuster_files="$output_dir/gobuster_files.txt"
        gobuster dir -u "$url" -w "$wordlist" -t "$threads" -s "$status_codes" --timeout "$timeout"s -x "$extensions" -o "$gobuster_files" -q
        
        if [ -f "$gobuster_files" ]; then
            local file_count=$(wc -l < "$gobuster_files")
            echo -e "${GREEN}[+] gobuster found $file_count files${NC}"
        fi
    fi
}

# Dirsearch directory fuzzing
run_dirsearch() {
    local url="$1"
    local output_dir="$2"
    local wordlist="$3"
    local threads="$4"
    local extensions="$5"
    local status_codes="$6"
    local timeout="$7"
    local recursive="$8"
    
    echo -e "${BLUE}[*] Running dirsearch...${NC}"
    
    local dirsearch_output="$output_dir/dirsearch_results.txt"
    local dirsearch_args=()
    
    dirsearch_args+=(-u "$url")
    dirsearch_args+=(-w "$wordlist")
    dirsearch_args+=(-t "$threads")
    dirsearch_args+=(--include-status="$status_codes")
    dirsearch_args+=(--timeout="$timeout")
    dirsearch_args+=(--format=simple)
    dirsearch_args+=(-o "$dirsearch_output")
    
    if [ -n "$extensions" ]; then
        dirsearch_args+=(-e "$extensions")
    fi
    
    if [ "$recursive" = true ]; then
        dirsearch_args+=(-r)
    fi
    
    dirsearch "${dirsearch_args[@]}" --quiet
    
    if [ -f "$dirsearch_output" ]; then
        local count=$(wc -l < "$dirsearch_output")
        echo -e "${GREEN}[+] dirsearch found $count entries${NC}"
    fi
}

# Feroxbuster directory fuzzing
run_feroxbuster() {
    local url="$1"
    local output_dir="$2"
    local wordlist="$3"
    local threads="$4"
    local extensions="$5"
    local status_codes="$6"
    local timeout="$7"
    local recursive="$8"
    
    echo -e "${BLUE}[*] Running feroxbuster...${NC}"
    
    local ferox_output="$output_dir/feroxbuster_results.txt"
    local ferox_args=()
    
    ferox_args+=(-u "$url")
    ferox_args+=(-w "$wordlist")
    ferox_args+=(-t "$threads")
    ferox_args+=(-T "$timeout")
    ferox_args+=(-o "$ferox_output")
    ferox_args+=(--silent)
    
    if [ -n "$extensions" ]; then
        ferox_args+=(-x "$extensions")
    fi
    
    if [ "$recursive" = true ]; then
        ferox_args+=(-r)
    fi
    
    # Parse status codes
    IFS=',' read -ra status_array <<< "$status_codes"
    for status in "${status_array[@]}"; do
        ferox_args+=(-s "$status")
    done
    
    feroxbuster "${ferox_args[@]}"
    
    if [ -f "$ferox_output" ]; then
        local count=$(wc -l < "$ferox_output")
        echo -e "${GREEN}[+] feroxbuster found $count entries${NC}"
    fi
}

# Wfuzz directory fuzzing
run_wfuzz() {
    local url="$1"
    local output_dir="$2"
    local wordlist="$3"
    local threads="$4"
    local extensions="$5"
    local status_codes="$6"
    local timeout="$7"
    local search_files="$8"
    
    echo -e "${BLUE}[*] Running wfuzz...${NC}"
    
    local wfuzz_output="$output_dir/wfuzz_directories.txt"
    
    # Directory fuzzing
    wfuzz -c -z file,"$wordlist" --sc "$status_codes" -t "$threads" -s "$timeout" "$url/FUZZ" | tee "$wfuzz_output"
    
    if [ -f "$wfuzz_output" ]; then
        local count=$(grep -c "C=" "$wfuzz_output" 2>/dev/null || echo "0")
        echo -e "${GREEN}[+] wfuzz found $count directories${NC}"
    fi
    
    # File fuzzing if enabled
    if [ "$search_files" = true ] && [ -n "$extensions" ]; then
        local wfuzz_files="$output_dir/wfuzz_files.txt"
        
        IFS=',' read -ra ext_array <<< "$extensions"
        for ext in "${ext_array[@]}"; do
            wfuzz -c -z file,"$wordlist" --sc "$status_codes" -t "$threads" -s "$timeout" "$url/FUZZ.$ext" >> "$wfuzz_files"
        done
        
        if [ -f "$wfuzz_files" ]; then
            local file_count=$(grep -c "C=" "$wfuzz_files" 2>/dev/null || echo "0")
            echo -e "${GREEN}[+] wfuzz found $file_count files${NC}"
        fi
    fi
}

# Dirb directory fuzzing
run_dirb() {
    local url="$1"
    local output_dir="$2"
    local wordlist="$3"
    local extensions="$4"
    
    echo -e "${BLUE}[*] Running dirb...${NC}"
    
    local dirb_output="$output_dir/dirb_results.txt"
    local dirb_args=()
    
    dirb_args+=("$url")
    dirb_args+=("$wordlist")
    dirb_args+=(-o "$dirb_output")
    dirb_args+=(-S)  # Silent mode
    
    if [ -n "$extensions" ]; then
        dirb_args+=(-X ".$extensions")
    fi
    
    dirb "${dirb_args[@]}"
    
    if [ -f "$dirb_output" ]; then
        local count=$(grep -c "CODE:" "$dirb_output" 2>/dev/null || echo "0")
        echo -e "${GREEN}[+] dirb found $count entries${NC}"
    fi
}

# Merge and analyze results
merge_results() {
    local output_dir="$1"
    local url="$2"
    
    echo -e "${BLUE}[*] Merging and analyzing results...${NC}"
    
    local merged_file="$output_dir/all_directories.txt"
    local interesting_file="$output_dir/interesting_findings.txt"
    
    # Combine all results
    {
        [ -f "$output_dir/ffuf_directories.txt" ] && cat "$output_dir/ffuf_directories.txt"
        [ -f "$output_dir/gobuster_directories.txt" ] && cat "$output_dir/gobuster_directories.txt"
        [ -f "$output_dir/dirsearch_results.txt" ] && cat "$output_dir/dirsearch_results.txt"
        [ -f "$output_dir/feroxbuster_results.txt" ] && cat "$output_dir/feroxbuster_results.txt"
        [ -f "$output_dir/wfuzz_directories.txt" ] && grep "C=" "$output_dir/wfuzz_directories.txt" 2>/dev/null
        [ -f "$output_dir/dirb_results.txt" ] && grep "CODE:" "$output_dir/dirb_results.txt" 2>/dev/null
    } | sort -u > "$merged_file"
    
    # Find interesting patterns
    {
        echo "=== Interesting Findings ==="
        echo ""
        
        echo "Admin/Management Panels:"
        grep -i "admin\|manage\|control\|panel\|dashboard" "$merged_file" 2>/dev/null || echo "None found"
        echo ""
        
        echo "Configuration Files:"
        grep -i "config\|settings\|\.xml\|\.json\|\.yml\|\.yaml" "$merged_file" 2>/dev/null || echo "None found"
        echo ""
        
        echo "Backup Files:"
        grep -i "backup\|\.bak\|\.old\|\.tmp\|\.save" "$merged_file" 2>/dev/null || echo "None found"
        echo ""
        
        echo "Development/Debug:"
        grep -i "dev\|debug\|test\|staging\|phpinfo" "$merged_file" 2>/dev/null || echo "None found"
        echo ""
        
        echo "API Endpoints:"
        grep -i "api\|rest\|json\|xml\|service" "$merged_file" 2>/dev/null || echo "None found"
        echo ""
        
        echo "Login/Authentication:"
        grep -i "login\|auth\|signin\|register\|password" "$merged_file" 2>/dev/null || echo "None found"
    } > "$interesting_file"
    
    local total_count=$(wc -l < "$merged_file" 2>/dev/null || echo "0")
    echo -e "${GREEN}[+] Total unique findings: $total_count${NC}"
    echo -e "${BLUE}[*] Interesting findings saved to: $interesting_file${NC}"
}

# Generate summary report
generate_summary() {
    local output_dir="$1"
    local url="$2"
    
    echo -e "${BLUE}[*] Generating summary report...${NC}"
    
    local summary_file="$output_dir/directory_summary.txt"
    
    cat > "$summary_file" << EOF
Directory/File Fuzzing Summary for: $url
Generated: $(date)
========================================

EOF
    
    # Count results from each tool
    for file in "$output_dir"/*_directories.txt "$output_dir"/*_files.txt "$output_dir"/*_results.txt; do
        if [ -f "$file" ]; then
            local tool_name=$(basename "$file" | sed 's/_[^_]*\.txt$//')
            local count
            if [[ "$file" == *"wfuzz"* ]]; then
                count=$(grep -c "C=" "$file" 2>/dev/null || echo "0")
            elif [[ "$file" == *"dirb"* ]]; then
                count=$(grep -c "CODE:" "$file" 2>/dev/null || echo "0")
            else
                count=$(wc -l < "$file" 2>/dev/null || echo "0")
            fi
            echo "$tool_name: $count findings" >> "$summary_file"
        fi
    done
    
    echo "" >> "$summary_file"
    
    if [ -f "$output_dir/all_directories.txt" ]; then
        local total=$(wc -l < "$output_dir/all_directories.txt")
        echo "Total unique findings: $total" >> "$summary_file"
    fi
    
    if [ -f "$output_dir/interesting_findings.txt" ]; then
        echo "" >> "$summary_file"
        cat "$output_dir/interesting_findings.txt" >> "$summary_file"
    fi
    
    echo -e "${GREEN}[+] Summary report saved to: $summary_file${NC}"
}

# Main execution function
main() {
    local url=""
    local output_dir=""
    local wordlist=""
    local threads=20
    local extensions=""
    local status_codes="200,301,302,403,500"
    local timeout=10
    local run_ffuf=false
    local run_gobuster=false
    local run_dirsearch=false
    local run_feroxbuster=false
    local run_wfuzz=false
    local run_dirb=false
    local run_all=false
    local search_files=false
    local recursive=false
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
            -x|--extensions)
                extensions="$2"
                shift 2
                ;;
            --status-codes)
                status_codes="$2"
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
            --gobuster)
                run_gobuster=true
                shift
                ;;
            --dirsearch)
                run_dirsearch=true
                shift
                ;;
            --feroxbuster)
                run_feroxbuster=true
                shift
                ;;
            --wfuzz)
                run_wfuzz=true
                shift
                ;;
            --dirb)
                run_dirb=true
                shift
                ;;
            --all)
                run_all=true
                shift
                ;;
            --files)
                search_files=true
                shift
                ;;
            --recursive)
                recursive=true
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
        output_dir="results/directory/$domain"
    fi
    
    # Find wordlist if not specified
    if [ -z "$wordlist" ]; then
        wordlist=$(find_wordlist)
        if [ -z "$wordlist" ]; then
            echo -e "${RED}[!] No wordlist found. Please specify with -w option${NC}"
            exit 1
        fi
    fi
    
    # Create output directory
    mkdir -p "$output_dir"
    
    # Check tools
    if ! check_tools; then
        exit 1
    fi
    
    echo -e "${GREEN}[+] Starting directory/file fuzzing for: $url${NC}"
    echo -e "${BLUE}[*] Output directory: $output_dir${NC}"
    echo -e "${BLUE}[*] Wordlist: $wordlist${NC}"
    echo -e "${BLUE}[*] Threads: $threads${NC}"
    echo -e "${BLUE}[*] Extensions: ${extensions:-"none"}${NC}"
    echo -e "${BLUE}[*] Status codes: $status_codes${NC}"
    
    # Run tools based on flags
    if [ "$run_all" = true ]; then
        run_ffuf=true
        run_gobuster=true
        run_dirsearch=true
        run_feroxbuster=true
        run_wfuzz=true
        run_dirb=true
    fi
    
    # If no specific tools selected, run default set
    if [ "$run_ffuf" = false ] && [ "$run_gobuster" = false ] && [ "$run_dirsearch" = false ] && [ "$run_feroxbuster" = false ] && [ "$run_wfuzz" = false ] && [ "$run_dirb" = false ]; then
        run_ffuf=true
        run_gobuster=true
        run_dirsearch=true
    fi
    
    # Execute selected tools
    [ "$run_ffuf" = true ] && run_ffuf "$url" "$output_dir" "$wordlist" "$threads" "$extensions" "$status_codes" "$timeout" "$search_files"
    [ "$run_gobuster" = true ] && run_gobuster "$url" "$output_dir" "$wordlist" "$threads" "$extensions" "$status_codes" "$timeout" "$search_files"
    [ "$run_dirsearch" = true ] && run_dirsearch "$url" "$output_dir" "$wordlist" "$threads" "$extensions" "$status_codes" "$timeout" "$recursive"
    [ "$run_feroxbuster" = true ] && run_feroxbuster "$url" "$output_dir" "$wordlist" "$threads" "$extensions" "$status_codes" "$timeout" "$recursive"
    [ "$run_wfuzz" = true ] && run_wfuzz "$url" "$output_dir" "$wordlist" "$threads" "$extensions" "$status_codes" "$timeout" "$search_files"
    [ "$run_dirb" = true ] && run_dirb "$url" "$output_dir" "$wordlist" "$extensions"
    
    # Merge and analyze results
    merge_results "$output_dir" "$url"
    
    # Generate summary report
    generate_summary "$output_dir" "$url"
    
    echo -e "\n${GREEN}[+] Directory/File Fuzzing Completed!${NC}"
    echo -e "${BLUE}[*] Results saved in: $output_dir${NC}"
    echo -e "${GREEN}[+] Directory/file fuzzing completed for $url${NC}"
}

# Run main function if script is executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi