#!/bin/bash

# Parameter Discovery Module for r3con VAPT Suite
# Discovers hidden parameters, endpoints, and input vectors

source "$(dirname "$0")/../utils/common.sh" 2>/dev/null || true

MODULE_NAME="Parameter Discovery"
MODULE_VERSION="1.0"

# Parameter discovery tools
TOOLS=(
    "arjun:python3 -m arjun"
    "paramspider:paramspider"
    "x8:x8"
    "ffuf:ffuf"
    "wfuzz:wfuzz"
    "gobuster:gobuster"
)

# Tool installation check
check_tools() {
    local missing_tools=()
    
    for tool_def in "${TOOLS[@]}"; do
        tool_name="${tool_def%%:*}"
        case $tool_name in
            "arjun")
                if ! python3 -c "import arjun" 2>/dev/null; then
                    missing_tools+=("$tool_name")
                fi
                ;;
            *)
                if ! command -v "$tool_name" &> /dev/null; then
                    missing_tools+=("$tool_name")
                fi
                ;;
        esac
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
${GREEN}Parameter Discovery Module${NC}

${BLUE}Usage:${NC}
    $0 -d <domain> [options]

${BLUE}Required:${NC}
    -d, --domain        Target domain

${BLUE}Options:${NC}
    -w, --wordlist      Custom wordlist for parameter discovery
    -o, --output        Output directory (default: results/param-discovery)
    -t, --threads       Number of threads (default: 20)
    -u, --urls          File containing URLs to test
    --arjun             Use Arjun for parameter discovery
    --paramspider       Use ParamSpider for parameter extraction
    --x8                Use x8 for parameter bruteforce
    --ffuf              Use ffuf for parameter fuzzing
    --wfuzz             Use wfuzz for parameter discovery
    --gobuster          Use gobuster for parameter bruteforce
    --all               Run all available tools
    -v, --verbose       Verbose output
    -h, --help          Show this help message

${BLUE}Examples:${NC}
    $0 -d example.com --all
    $0 -d example.com --arjun --paramspider
    $0 -d example.com -u urls.txt --x8 --threads 50
    $0 -d example.com -w custom-params.txt --ffuf
EOF
}

# Arjun parameter discovery
run_arjun() {
    local domain="$1"
    local output_dir="$2"
    local urls_file="$3"
    local threads="$4"
    
    echo -e "${BLUE}[*] Running Arjun parameter discovery...${NC}"
    
    if [ -n "$urls_file" ] && [ -f "$urls_file" ]; then
        python3 -m arjun -i "$urls_file" -o "$output_dir/arjun_params.json" -t "$threads" --stable
    else
        python3 -m arjun -u "https://$domain" -o "$output_dir/arjun_params.json" -t "$threads" --stable
    fi
    
    if [ -f "$output_dir/arjun_params.json" ]; then
        echo -e "${GREEN}[+] Arjun results saved to: $output_dir/arjun_params.json${NC}"
    fi
}

# ParamSpider parameter extraction
run_paramspider() {
    local domain="$1"
    local output_dir="$2"
    
    echo -e "${BLUE}[*] Running ParamSpider parameter extraction...${NC}"
    
    paramspider -d "$domain" -o "$output_dir/paramspider_results.txt" --exclude woff,css,js,png,svg,jpg,jpeg
    
    if [ -f "$output_dir/paramspider_results.txt" ]; then
        echo -e "${GREEN}[+] ParamSpider results saved to: $output_dir/paramspider_results.txt${NC}"
        
        # Extract unique parameters
        grep -oP '\?[^&\s]*' "$output_dir/paramspider_results.txt" | sed 's/?//' | cut -d'=' -f1 | sort -u > "$output_dir/paramspider_params.txt"
        echo -e "${GREEN}[+] Unique parameters saved to: $output_dir/paramspider_params.txt${NC}"
    fi
}

# x8 parameter bruteforce
run_x8() {
    local domain="$1"
    local output_dir="$2"
    local urls_file="$3"
    local wordlist="$4"
    local threads="$5"
    
    echo -e "${BLUE}[*] Running x8 parameter bruteforce...${NC}"
    
    local x8_wordlist="${wordlist:-/usr/share/seclists/Discovery/Web-Content/burp-parameter-names.txt}"
    
    if [ -n "$urls_file" ] && [ -f "$urls_file" ]; then
        x8 -u "$urls_file" -w "$x8_wordlist" -o "$output_dir/x8_results.txt" --max-time 300 --workers "$threads"
    else
        echo "https://$domain" | x8 -u - -w "$x8_wordlist" -o "$output_dir/x8_results.txt" --max-time 300 --workers "$threads"
    fi
    
    if [ -f "$output_dir/x8_results.txt" ]; then
        echo -e "${GREEN}[+] x8 results saved to: $output_dir/x8_results.txt${NC}"
    fi
}

# ffuf parameter fuzzing
run_ffuf() {
    local domain="$1"
    local output_dir="$2"
    local wordlist="$3"
    local threads="$4"
    
    echo -e "${BLUE}[*] Running ffuf parameter fuzzing...${NC}"
    
    local ffuf_wordlist="${wordlist:-/usr/share/seclists/Discovery/Web-Content/burp-parameter-names.txt}"
    
    # GET parameter fuzzing
    ffuf -u "https://$domain/?FUZZ=test" -w "$ffuf_wordlist" -o "$output_dir/ffuf_get_params.json" -of json -t "$threads" -ac -sf
    
    # POST parameter fuzzing
    ffuf -u "https://$domain/" -w "$ffuf_wordlist" -X POST -d "FUZZ=test" -H "Content-Type: application/x-www-form-urlencoded" -o "$output_dir/ffuf_post_params.json" -of json -t "$threads" -ac -sf
    
    if [ -f "$output_dir/ffuf_get_params.json" ]; then
        echo -e "${GREEN}[+] ffuf GET parameter results saved to: $output_dir/ffuf_get_params.json${NC}"
    fi
    
    if [ -f "$output_dir/ffuf_post_params.json" ]; then
        echo -e "${GREEN}[+] ffuf POST parameter results saved to: $output_dir/ffuf_post_params.json${NC}"
    fi
}

# wfuzz parameter discovery
run_wfuzz() {
    local domain="$1"
    local output_dir="$2"
    local wordlist="$3"
    local threads="$4"
    
    echo -e "${BLUE}[*] Running wfuzz parameter discovery...${NC}"
    
    local wfuzz_wordlist="${wordlist:-/usr/share/seclists/Discovery/Web-Content/burp-parameter-names.txt}"
    
    # GET parameter fuzzing
    wfuzz -c -z file,"$wfuzz_wordlist" -u "https://$domain/?FUZZ=test" --hc 404 -t "$threads" -f "$output_dir/wfuzz_get_params.txt"
    
    # POST parameter fuzzing
    wfuzz -c -z file,"$wfuzz_wordlist" -u "https://$domain/" -d "FUZZ=test" -H "Content-Type: application/x-www-form-urlencoded" --hc 404 -t "$threads" -f "$output_dir/wfuzz_post_params.txt"
    
    if [ -f "$output_dir/wfuzz_get_params.txt" ]; then
        echo -e "${GREEN}[+] wfuzz GET parameter results saved to: $output_dir/wfuzz_get_params.txt${NC}"
    fi
    
    if [ -f "$output_dir/wfuzz_post_params.txt" ]; then
        echo -e "${GREEN}[+] wfuzz POST parameter results saved to: $output_dir/wfuzz_post_params.txt${NC}"
    fi
}

# gobuster parameter discovery
run_gobuster() {
    local domain="$1"
    local output_dir="$2"
    local wordlist="$3"
    local threads="$4"
    
    echo -e "${BLUE}[*] Running gobuster parameter discovery...${NC}"
    
    local gobuster_wordlist="${wordlist:-/usr/share/seclists/Discovery/Web-Content/burp-parameter-names.txt}"
    
    # Note: gobuster doesn't have direct parameter fuzzing, using dir mode with parameter-like patterns
    gobuster dir -u "https://$domain" -w "$gobuster_wordlist" -o "$output_dir/gobuster_endpoints.txt" -t "$threads" -x php,html,asp,aspx,jsp -q
    
    if [ -f "$output_dir/gobuster_endpoints.txt" ]; then
        echo -e "${GREEN}[+] gobuster endpoint results saved to: $output_dir/gobuster_endpoints.txt${NC}"
    fi
}

# Main execution function
main() {
    local domain=""
    local output_dir=""
    local wordlist=""
    local threads=20
    local urls_file=""
    local run_arjun=false
    local run_paramspider=false
    local run_x8=false
    local run_ffuf=false
    local run_wfuzz=false
    local run_gobuster=false
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
            -u|--urls)
                urls_file="$2"
                shift 2
                ;;
            --arjun)
                run_arjun=true
                shift
                ;;
            --paramspider)
                run_paramspider=true
                shift
                ;;
            --x8)
                run_x8=true
                shift
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
        output_dir="results/param-discovery/$domain"
    fi
    
    # Create output directory
    mkdir -p "$output_dir"
    
    # Check tools
    if ! check_tools; then
        exit 1
    fi
    
    echo -e "${GREEN}[+] Starting parameter discovery for: $domain${NC}"
    echo -e "${BLUE}[*] Output directory: $output_dir${NC}"
    echo -e "${BLUE}[*] Threads: $threads${NC}"
    
    # Run tools based on flags
    if [ "$run_all" = true ]; then
        run_arjun=true
        run_paramspider=true
        run_x8=true
        run_ffuf=true
        run_wfuzz=true
        run_gobuster=true
    fi
    
    # If no specific tools selected, run default set
    if [ "$run_arjun" = false ] && [ "$run_paramspider" = false ] && [ "$run_x8" = false ] && [ "$run_ffuf" = false ] && [ "$run_wfuzz" = false ] && [ "$run_gobuster" = false ]; then
        run_arjun=true
        run_paramspider=true
        run_x8=true
    fi
    
    # Execute selected tools
    [ "$run_arjun" = true ] && run_arjun "$domain" "$output_dir" "$urls_file" "$threads"
    [ "$run_paramspider" = true ] && run_paramspider "$domain" "$output_dir"
    [ "$run_x8" = true ] && run_x8 "$domain" "$output_dir" "$urls_file" "$wordlist" "$threads"
    [ "$run_ffuf" = true ] && run_ffuf "$domain" "$output_dir" "$wordlist" "$threads"
    [ "$run_wfuzz" = true ] && run_wfuzz "$domain" "$output_dir" "$wordlist" "$threads"
    [ "$run_gobuster" = true ] && run_gobuster "$domain" "$output_dir" "$wordlist" "$threads"
    
    # Generate summary report
    echo -e "\n${GREEN}[+] Parameter Discovery Completed!${NC}"
    echo -e "${BLUE}[*] Results saved in: $output_dir${NC}"
    
    # Count discovered parameters
    local total_params=0
    for file in "$output_dir"/*.txt "$output_dir"/*.json; do
        if [ -f "$file" ]; then
            echo -e "${YELLOW}[*] Found results in: $(basename "$file")${NC}"
        fi
    done
    
    echo -e "${GREEN}[+] Parameter discovery scan completed for $domain${NC}"
}

# Run main function if script is executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi