#!/bin/bash

# Screenshots Module for r3con VAPT Suite
# Comprehensive web application screenshot capture

source "$(dirname "$0")/../utils/common.sh" 2>/dev/null || true

MODULE_NAME="Screenshots"
MODULE_VERSION="1.0"

# Screenshot tools
TOOLS=(
    "gowitness:gowitness"
    "aquatone:aquatone"
    "cutycapt:cutycapt"
    "wkhtmltopdf:wkhtmltopdf"
    "httpx:httpx"
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
${GREEN}Screenshots Module${NC}

${BLUE}Usage:${NC}
    $0 -f <file> [options] OR $0 -u <url> [options]

${BLUE}Required (choose one):${NC}
    -f, --file          File containing URLs (one per line)
    -u, --url           Single URL to screenshot

${BLUE}Options:${NC}
    -o, --output        Output directory (default: results/screenshots)
    -t, --threads       Number of threads (default: 10)
    --timeout           Request timeout in seconds (default: 30)
    --resolution        Screen resolution (default: 1920x1080)
    --format            Output format (png/jpg, default: png)
    --quality           Image quality 1-100 (default: 90)
    --delay             Delay before screenshot in seconds (default: 3)
    --gowitness         Use gowitness for screenshots
    --aquatone          Use aquatone for screenshots
    --cutycapt          Use cutycapt for screenshots
    --wkhtmltopdf       Use wkhtmltopdf for screenshots
    --full-page         Capture full page (not just viewport)
    --mobile            Use mobile viewport
    --headers           Custom headers (format: "Header: Value")
    --user-agent        Custom user agent string
    --all               Use all available screenshot tools
    -v, --verbose       Verbose output
    -h, --help          Show this help message

${BLUE}Examples:${NC}
    $0 -f live_urls.txt --all
    $0 -u https://example.com --gowitness --full-page
    $0 -f targets.txt --resolution 1920x1080 --delay 5
    $0 -u https://example.com --mobile --format jpg
EOF
}

# Take screenshots with gowitness
run_gowitness() {
    local target="$1"
    local output_dir="$2"
    local threads="$3"
    local timeout="$4"
    local resolution="$5"
    local delay="$6"
    local headers="$7"
    local user_agent="$8"
    local full_page="$9"
    
    echo -e "${BLUE}[*] Taking screenshots with gowitness...${NC}"
    
    local gowitness_dir="$output_dir/gowitness"
    mkdir -p "$gowitness_dir"
    
    local gowitness_args=()
    
    if [ -f "$target" ]; then
        gowitness_args+=(file -f "$target")
    else
        gowitness_args+=(single "$target")
    fi
    
    gowitness_args+=(-P "$gowitness_dir")
    gowitness_args+=(--threads "$threads")
    gowitness_args+=(--timeout "$timeout")
    gowitness_args+=(--delay "$delay")
    gowitness_args+=(--resolution "$resolution")
    gowitness_args+=(--disable-logging)
    
    if [ "$full_page" = true ]; then
        gowitness_args+=(--fullpage)
    fi
    
    if [ -n "$headers" ]; then
        gowitness_args+=(--header "$headers")
    fi
    
    if [ -n "$user_agent" ]; then
        gowitness_args+=(--user-agent "$user_agent")
    fi
    
    gowitness "${gowitness_args[@]}"
    
    # Count screenshots
    local count=$(find "$gowitness_dir" -name "*.png" 2>/dev/null | wc -l)
    echo -e "${GREEN}[+] gowitness captured $count screenshots${NC}"
}

# Take screenshots with aquatone
run_aquatone() {
    local target="$1"
    local output_dir="$2"
    local threads="$3"
    local timeout="$4"
    local resolution="$5"
    
    echo -e "${BLUE}[*] Taking screenshots with aquatone...${NC}"
    
    local aquatone_dir="$output_dir/aquatone"
    mkdir -p "$aquatone_dir"
    
    local aquatone_args=()
    aquatone_args+=(-out "$aquatone_dir")
    aquatone_args+=(-threads "$threads")
    aquatone_args+=(-timeout "$timeout"000)  # aquatone uses milliseconds
    aquatone_args+=(-resolution "$resolution")
    aquatone_args+=(-silent)
    
    if [ -f "$target" ]; then
        cat "$target" | aquatone "${aquatone_args[@]}"
    else
        echo "$target" | aquatone "${aquatone_args[@]}"
    fi
    
    # Count screenshots
    local count=$(find "$aquatone_dir" -name "*.png" 2>/dev/null | wc -l)
    echo -e "${GREEN}[+] aquatone captured $count screenshots${NC}"
}

# Take screenshots with cutycapt
run_cutycapt() {
    local target="$1"
    local output_dir="$2"
    local timeout="$3"
    local format="$4"
    local quality="$5"
    local user_agent="$6"
    
    echo -e "${BLUE}[*] Taking screenshots with cutycapt...${NC}"
    
    local cutycapt_dir="$output_dir/cutycapt"
    mkdir -p "$cutycapt_dir"
    
    local count=0
    local max_screenshots=50  # Limit to prevent excessive processing
    
    if [ -f "$target" ]; then
        while read -r url && [ $count -lt $max_screenshots ]; do
            local filename=$(echo "$url" | sed 's|https\?://||' | sed 's|[^a-zA-Z0-9._-]|_|g')
            local output_file="$cutycapt_dir/${count}_${filename}.$format"
            
            echo -e "${BLUE}[*] Capturing: $url${NC}"
            
            local cutycapt_args=()
            cutycapt_args+=(--url="$url")
            cutycapt_args+=(--out="$output_file")
            cutycapt_args+=(--max-wait="$((timeout * 1000))")
            cutycapt_args+=(--quality="$quality")
            
            if [ -n "$user_agent" ]; then
                cutycapt_args+=(--user-agent="$user_agent")
            fi
            
            cutycapt "${cutycapt_args[@]}" 2>/dev/null
            
            if [ -f "$output_file" ]; then
                ((count++))
            fi
        done < "$target"
    else
        local filename=$(echo "$target" | sed 's|https\?://||' | sed 's|[^a-zA-Z0-9._-]|_|g')
        local output_file="$cutycapt_dir/${filename}.$format"
        
        cutycapt --url="$target" --out="$output_file" --max-wait="$((timeout * 1000))" --quality="$quality"
        
        if [ -f "$output_file" ]; then
            count=1
        fi
    fi
    
    echo -e "${GREEN}[+] cutycapt captured $count screenshots${NC}"
}

# Take screenshots with wkhtmltopdf
run_wkhtmltopdf() {
    local target="$1"
    local output_dir="$2"
    local timeout="$3"
    local format="$4"
    local user_agent="$5"
    
    echo -e "${BLUE}[*] Taking screenshots with wkhtmltopdf...${NC}"
    
    local wkhtml_dir="$output_dir/wkhtmltopdf"
    mkdir -p "$wkhtml_dir"
    
    local count=0
    local max_screenshots=30
    
    if [ -f "$target" ]; then
        while read -r url && [ $count -lt $max_screenshots ]; do
            local filename=$(echo "$url" | sed 's|https\?://||' | sed 's|[^a-zA-Z0-9._-]|_|g')
            local output_file="$wkhtml_dir/${count}_${filename}.$format"
            
            echo -e "${BLUE}[*] Capturing: $url${NC}"
            
            local wkhtml_args=()
            wkhtml_args+=(--javascript-delay "$((timeout * 1000))")
            wkhtml_args+=(--load-error-handling ignore)
            wkhtml_args+=(--load-media-error-handling ignore)
            
            if [ -n "$user_agent" ]; then
                wkhtml_args+=(--custom-header "User-Agent" "$user_agent")
            fi
            
            if [ "$format" = "png" ]; then
                wkhtmltoimage "${wkhtml_args[@]}" "$url" "$output_file" 2>/dev/null
            else
                wkhtmltopdf "${wkhtml_args[@]}" "$url" "$output_file" 2>/dev/null
            fi
            
            if [ -f "$output_file" ]; then
                ((count++))
            fi
        done < "$target"
    else
        local filename=$(echo "$target" | sed 's|https\?://||' | sed 's|[^a-zA-Z0-9._-]|_|g')
        local output_file="$wkhtml_dir/${filename}.$format"
        
        if [ "$format" = "png" ]; then
            wkhtmltoimage --javascript-delay "$((timeout * 1000))" "$target" "$output_file" 2>/dev/null
        else
            wkhtmltopdf --javascript-delay "$((timeout * 1000))" "$target" "$output_file" 2>/dev/null
        fi
        
        if [ -f "$output_file" ]; then
            count=1
        fi
    fi
    
    echo -e "${GREEN}[+] wkhtmltopdf captured $count screenshots${NC}"
}

# Organize screenshots
organize_screenshots() {
    local output_dir="$1"
    
    echo -e "${BLUE}[*] Organizing screenshots...${NC}"
    
    local organized_dir="$output_dir/organized"
    mkdir -p "$organized_dir"
    
    # Create index HTML file
    local index_file="$organized_dir/index.html"
    
    cat > "$index_file" << EOF
<!DOCTYPE html>
<html>
<head>
    <title>Screenshot Gallery</title>
    <style>
        body { font-family: Arial, sans-serif; margin: 20px; }
        .screenshot { margin: 20px; padding: 10px; border: 1px solid #ccc; }
        .screenshot img { max-width: 400px; height: auto; border: 1px solid #ddd; }
        .screenshot h3 { color: #333; }
        .screenshot p { color: #666; font-size: 12px; }
    </style>
</head>
<body>
    <h1>Screenshot Gallery</h1>
    <p>Generated: $(date)</p>
EOF
    
    # Process screenshots from each tool
    local screenshot_count=0
    
    for tool_dir in "$output_dir"/*/; do
        if [ -d "$tool_dir" ] && [ "$(basename "$tool_dir")" != "organized" ]; then
            local tool_name=$(basename "$tool_dir")
            
            echo "<h2>$tool_name Screenshots</h2>" >> "$index_file"
            
            for screenshot in "$tool_dir"/*.{png,jpg,jpeg} 2>/dev/null; do
                if [ -f "$screenshot" ]; then
                    local filename=$(basename "$screenshot")
                    local url=$(echo "$filename" | sed 's|_|.|g' | sed 's|^\([0-9]*\)\.||')
                    
                    # Copy to organized directory
                    cp "$screenshot" "$organized_dir/"
                    
                    # Add to HTML index
                    cat >> "$index_file" << EOF
    <div class="screenshot">
        <h3>$url</h3>
        <img src="$filename" alt="Screenshot of $url">
        <p>Tool: $tool_name | File: $filename</p>
    </div>
EOF
                    ((screenshot_count++))
                fi
            done
        fi
    done
    
    echo "</body></html>" >> "$index_file"
    
    echo -e "${GREEN}[+] Organized $screenshot_count screenshots${NC}"
    echo -e "${BLUE}[*] HTML gallery created: $index_file${NC}"
}

# Generate screenshot analysis
analyze_screenshots() {
    local output_dir="$1"
    
    echo -e "${BLUE}[*] Analyzing screenshots...${NC}"
    
    local analysis_file="$output_dir/screenshot_analysis.txt"
    
    cat > "$analysis_file" << EOF
Screenshot Analysis Report
Generated: $(date)
=========================

EOF
    
    # Count screenshots by tool
    echo "=== Screenshots by Tool ===" >> "$analysis_file"
    
    for tool_dir in "$output_dir"/*/; do
        if [ -d "$tool_dir" ] && [ "$(basename "$tool_dir")" != "organized" ]; then
            local tool_name=$(basename "$tool_dir")
            local count=$(find "$tool_dir" -name "*.png" -o -name "*.jpg" -o -name "*.jpeg" 2>/dev/null | wc -l)
            echo "$tool_name: $count screenshots" >> "$analysis_file"
        fi
    done
    
    echo "" >> "$analysis_file"
    
    # File sizes
    echo "=== File Size Analysis ===" >> "$analysis_file"
    local total_size=$(du -sh "$output_dir" 2>/dev/null | cut -f1)
    echo "Total size: $total_size" >> "$analysis_file"
    
    # Largest files
    echo "" >> "$analysis_file"
    echo "=== Largest Screenshots ===" >> "$analysis_file"
    find "$output_dir" -name "*.png" -o -name "*.jpg" -o -name "*.jpeg" 2>/dev/null | \
        xargs ls -lh | sort -k5 -hr | head -10 | awk '{print $9 " - " $5}' >> "$analysis_file"
    
    echo -e "${GREEN}[+] Screenshot analysis saved to: $analysis_file${NC}"
}

# Generate summary report
generate_summary() {
    local output_dir="$1"
    local target="$2"
    
    echo -e "${BLUE}[*] Generating summary report...${NC}"
    
    local summary_file="$output_dir/screenshot_summary.txt"
    
    cat > "$summary_file" << EOF
Screenshot Capture Summary
Target: $target
Generated: $(date)
=========================

EOF
    
    # Count total screenshots
    local total_screenshots=$(find "$output_dir" -name "*.png" -o -name "*.jpg" -o -name "*.jpeg" 2>/dev/null | wc -l)
    echo "Total screenshots captured: $total_screenshots" >> "$summary_file"
    echo "" >> "$summary_file"
    
    # Tool statistics
    echo "=== Tool Statistics ===" >> "$summary_file"
    for tool_dir in "$output_dir"/*/; do
        if [ -d "$tool_dir" ] && [ "$(basename "$tool_dir")" != "organized" ]; then
            local tool_name=$(basename "$tool_dir")
            local count=$(find "$tool_dir" -name "*.png" -o -name "*.jpg" -o -name "*.jpeg" 2>/dev/null | wc -l)
            echo "$tool_name: $count screenshots" >> "$summary_file"
        fi
    done
    
    echo "" >> "$summary_file"
    
    # Storage information
    echo "=== Storage Information ===" >> "$summary_file"
    local total_size=$(du -sh "$output_dir" 2>/dev/null | cut -f1)
    echo "Total storage used: $total_size" >> "$summary_file"
    
    if [ -f "$output_dir/organized/index.html" ]; then
        echo "HTML gallery created: $output_dir/organized/index.html" >> "$summary_file"
    fi
    
    echo -e "${GREEN}[+] Summary report saved to: $summary_file${NC}"
}

# Main execution function
main() {
    local target=""
    local target_file=""
    local output_dir=""
    local threads=10
    local timeout=30
    local resolution="1920x1080"
    local format="png"
    local quality=90
    local delay=3
    local headers=""
    local user_agent=""
    local use_gowitness=false
    local use_aquatone=false
    local use_cutycapt=false
    local use_wkhtmltopdf=false
    local full_page=false
    local mobile=false
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
            --resolution)
                resolution="$2"
                shift 2
                ;;
            --format)
                format="$2"
                shift 2
                ;;
            --quality)
                quality="$2"
                shift 2
                ;;
            --delay)
                delay="$2"
                shift 2
                ;;
            --headers)
                headers="$2"
                shift 2
                ;;
            --user-agent)
                user_agent="$2"
                shift 2
                ;;
            --gowitness)
                use_gowitness=true
                shift
                ;;
            --aquatone)
                use_aquatone=true
                shift
                ;;
            --cutycapt)
                use_cutycapt=true
                shift
                ;;
            --wkhtmltopdf)
                use_wkhtmltopdf=true
                shift
                ;;
            --full-page)
                full_page=true
                shift
                ;;
            --mobile)
                mobile=true
                resolution="375x667"
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
    local screenshot_target="$target_file"
    if [ -n "$target" ]; then
        screenshot_target="/tmp/screenshot_target_$$"
        echo "$target" > "$screenshot_target"
    fi
    
    # Check if target file exists
    if [ ! -f "$screenshot_target" ]; then
        echo -e "${RED}[!] Target file not found: $screenshot_target${NC}"
        exit 1
    fi
    
    # Set default output directory
    if [ -z "$output_dir" ]; then
        if [ -n "$target" ]; then
            local domain=$(echo "$target" | sed 's|https\?://||' | sed 's|/.*||')
            output_dir="results/screenshots/$domain"
        else
            output_dir="results/screenshots/$(basename "$target_file" .txt)"
        fi
    fi
    
    # Create output directory
    mkdir -p "$output_dir"
    
    # Check tools
    if ! check_tools; then
        exit 1
    fi
    
    echo -e "${GREEN}[+] Starting screenshot capture...${NC}"
    [ -n "$target" ] && echo -e "${BLUE}[*] Target: $target${NC}"
    [ -n "$target_file" ] && echo -e "${BLUE}[*] Target file: $target_file${NC}"
    echo -e "${BLUE}[*] Output directory: $output_dir${NC}"
    echo -e "${BLUE}[*] Resolution: $resolution${NC}"
    echo -e "${BLUE}[*] Format: $format${NC}"
    echo -e "${BLUE}[*] Quality: $quality${NC}"
    
    # Run screenshot tools based on flags
    if [ "$run_all" = true ]; then
        use_gowitness=true
        use_aquatone=true
        use_cutycapt=true
        use_wkhtmltopdf=true
    fi
    
    # If no specific tools selected, run default set
    if [ "$use_gowitness" = false ] && [ "$use_aquatone" = false ] && [ "$use_cutycapt" = false ] && [ "$use_wkhtmltopdf" = false ]; then
        use_gowitness=true
        use_aquatone=true
    fi
    
    # Execute selected screenshot tools
    [ "$use_gowitness" = true ] && command -v gowitness &> /dev/null && run_gowitness "$screenshot_target" "$output_dir" "$threads" "$timeout" "$resolution" "$delay" "$headers" "$user_agent" "$full_page"
    [ "$use_aquatone" = true ] && command -v aquatone &> /dev/null && run_aquatone "$screenshot_target" "$output_dir" "$threads" "$timeout" "$resolution"
    [ "$use_cutycapt" = true ] && command -v cutycapt &> /dev/null && run_cutycapt "$screenshot_target" "$output_dir" "$timeout" "$format" "$quality" "$user_agent"
    [ "$use_wkhtmltopdf" = true ] && command -v wkhtmltoimage &> /dev/null && run_wkhtmltopdf "$screenshot_target" "$output_dir" "$timeout" "$format" "$user_agent"
    
    # Organize and analyze screenshots
    organize_screenshots "$output_dir"
    analyze_screenshots "$output_dir"
    generate_summary "$output_dir" "${target:-$target_file}"
    
    # Clean up temporary file if created
    if [ -n "$target" ] && [ -f "/tmp/screenshot_target_$$" ]; then
        rm -f "/tmp/screenshot_target_$$"
    fi
    
    echo -e "\n${GREEN}[+] Screenshot Capture Completed!${NC}"
    echo -e "${BLUE}[*] Results saved in: $output_dir${NC}"
    echo -e "${GREEN}[+] Screenshot capture completed for ${target:-$target_file}${NC}"
}

# Run main function if script is executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi