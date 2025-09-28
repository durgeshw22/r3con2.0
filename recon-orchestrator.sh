#!/bin/bash

# r3con VAPT Suite - Main Orchestrator (POSIX Compatible)
# Modular reconnaissance framework with dual operation modes

# Source utilities if available (disabled for now due to compatibility issues)
# if [ -f "utils/common.sh" ]; then
#     . utils/common.sh
# elif [ -f "$(dirname "$0")/utils/common.sh" ]; then
#     . "$(dirname "$0")/utils/common.sh"
# fi

# Color definitions (fallback if not in common.sh)
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

# Script information
SCRIPT_NAME="r3con VAPT Suite"
SCRIPT_VERSION="2.0"

# Module path mapping
get_module_path() {
    case "$1" in
        "subdomain") echo "modules/subdomain.sh" ;;
        "directory") echo "modules/directory.sh" ;;
        "api-fuzzing") echo "modules/api-fuzzing.sh" ;;
        "web-archive") echo "modules/web-archive.sh" ;;
        "live-probing") echo "modules/live-probing.sh" ;;
        "js-discovery") echo "modules/js-discovery.sh" ;;
        "vuln-scanning") echo "modules/vuln-scanning.sh" ;;
        "screenshots") echo "modules/screenshots.sh" ;;
        "dns-resolution") echo "modules/dns-resolution.sh" ;;
        "port-scanning") echo "modules/port-scanning.sh" ;;
        "osint") echo "modules/osint.sh" ;;
        "param-discovery") echo "modules/param-discovery.sh" ;;
        "tech-detection") echo "modules/tech-detection.sh" ;;
        "anon") echo "modules/anon.sh" ;;
        *) echo "" ;;
    esac
}

# Get all available module names
get_all_modules() {
    echo "subdomain directory api-fuzzing web-archive live-probing js-discovery vuln-scanning screenshots dns-resolution port-scanning osint param-discovery tech-detection anon"
}

# Get module display names
get_module_display_name() {
    case "$1" in
        "subdomain") echo "Subdomain Enumeration" ;;
        "directory") echo "Directory/File Discovery" ;;
        "api-fuzzing") echo "API Testing & Fuzzing" ;;
        "web-archive") echo "Web Archive Enumeration" ;;
        "live-probing") echo "Live Host Probing" ;;
        "js-discovery") echo "JavaScript Discovery" ;;
        "vuln-scanning") echo "Vulnerability Scanning" ;;
        "screenshots") echo "Screenshot Capture" ;;
        "dns-resolution") echo "DNS Resolution" ;;
        "port-scanning") echo "Port Scanning" ;;
        "osint") echo "OSINT Gathering" ;;
        "param-discovery") echo "Parameter Discovery & Fuzzing" ;;
        "tech-detection") echo "Technology Detection & Identification" ;;
        "anon") echo "Anonymity & IP Rotation" ;;
        *) echo "$1" ;;
    esac
}

# Show banner
show_main_banner() {
    echo -e "${CYAN}"
    cat << "EOF"
                 ____                        
    _____  _____/  _/_____  ____  ____ ___  
   / ___/ / ___/   // ___/_/ ___\/  _ `/  \ 
  / /    / /  __   // /__  / /_/\/ ___/ /\ \
 /_/    /_/  /___/_/\___/  \____/\___//_/\_\
                                            
    Modular VAPT Reconnaissance Suite v2.0
    Advanced Security Testing Framework
EOF
    echo -e "${NC}"
    echo -e "${BLUE}$SCRIPT_NAME v$SCRIPT_VERSION${NC}"
    echo
}

# Show help
show_help() {
    cat << EOF
${GREEN}$SCRIPT_NAME v$SCRIPT_VERSION${NC}

${BLUE}Usage:${NC}
    $0 [OPTIONS] -d <domain>
    $0 --interactive
    $0 --list-modules

${BLUE}OPTIONS:${NC}
    -d, --domain <domain>     Target domain for reconnaissance
    -o, --output <dir>        Output directory (default: results)
    -t, --threads <num>       Number of threads (default: 20)
    --all                     Run all available modules
    --subdomain               Subdomain enumeration only
    --port-scan               Port scanning only
    --osint                   OSINT gathering only
    --interactive             Interactive mode with menu
    --list-modules            List all available modules
    -h, --help               Show this help message
    -v, --version            Show version information

${BLUE}Examples:${NC}
    $0 -d example.com --all
    $0 -d example.com --subdomain -o /tmp/results
    $0 --interactive
    $0 --list-modules

${BLUE}Interactive Mode:${NC}
    Use --interactive for a user-friendly menu interface.
    This mode allows you to select specific modules and provides 
    real-time progress updates.

EOF
}

# Get available modules (check which ones exist)
get_available_modules() {
    available_modules=""
    script_dir="$(dirname "$0")"
    
    if [ "$script_dir" = "." ]; then
        script_dir="$(pwd)"
    fi
    
    for module in $(get_all_modules); do
        module_rel_path="$(get_module_path "$module")"
        module_path="$script_dir/$module_rel_path"
        
        if [ ! -f "$module_path" ]; then
            module_path="$module_rel_path"
        fi
        
        if [ -f "$module_path" ]; then
            if [ -z "$available_modules" ]; then
                available_modules="$module"
            else
                available_modules="$available_modules $module"
            fi
        fi
    done
    
    echo "$available_modules"
}

# List modules with status
list_modules() {
    echo -e "${GREEN}Available Modules:${NC}\n"
    
    for module in $(get_all_modules); do
        status="❌"
        script_dir="$(dirname "$0")"
        
        if [ "$script_dir" = "." ]; then
            script_dir="$(pwd)"
        fi
        
        module_rel_path="$(get_module_path "$module")"
        module_path="$script_dir/$module_rel_path"
        
        if [ ! -f "$module_path" ]; then
            module_path="$module_rel_path"
        fi
        
        if [ -f "$module_path" ]; then
            status="✅"
        fi
        
        description=""
        case "$module" in
            "subdomain") description="Subdomain enumeration using multiple tools" ;;
            "directory") description="Directory and file discovery" ;;
            "api-fuzzing") description="API endpoint testing and parameter fuzzing" ;;
            "web-archive") description="Web archive enumeration" ;;
            "live-probing") description="Live host detection and HTTP probing" ;;
            "js-discovery") description="JavaScript file analysis and secret discovery" ;;
            "vuln-scanning") description="Vulnerability assessment" ;;
            "screenshots") description="Visual reconnaissance and screenshot capture" ;;
            "dns-resolution") description="DNS analysis and enumeration" ;;
            "port-scanning") description="Port and service discovery" ;;
            "osint") description="Open source intelligence gathering" ;;
            "param-discovery") description="Parameter discovery and fuzzing" ;;
            "tech-detection") description="Technology and framework identification" ;;
            "anon") description="Anonymity features and IP rotation" ;;
            *) description="Module description not available" ;;
        esac
        
        printf "  %-18s %s %s\n" "$module" "$status" "$description"
    done
    echo
}

# Interactive mode
interactive_mode() {
    clear
    
    available_modules_str="$(get_available_modules)"
    module_count=0
    
    # Count modules
    for module in $available_modules_str; do
        module_count=$((module_count + 1))
    done
    
    while true; do
        # Show interactive banner
        echo -e "${CYAN}"
        echo "╔══════════════════════════════════════╗"
        echo "║           R3CON VAPT Suite           ║"
        echo "╚══════════════════════════════════════╝"
        echo -e "${NC}"
        echo
        
        if [ "$module_count" -eq 0 ]; then
            echo -e "${RED}[ERROR] No modules found!${NC}"
            echo -e "${YELLOW}Please ensure you're running from the correct directory${NC}"
            return 1
        fi
        
        menu_choice=1
        module_map=""
        
        # Show available modules
        for module in $available_modules_str; do
            display_name="$(get_module_display_name "$module")"
            echo -e "${YELLOW}$menu_choice)${NC} $display_name"
            
            if [ -z "$module_map" ]; then
                module_map="$menu_choice:$module"
            else
                module_map="$module_map $menu_choice:$module"
            fi
            menu_choice=$((menu_choice + 1))
        done
        
        echo
        echo -e "${BLUE}$menu_choice)${NC} Full Reconnaissance"
        run_all_choice=$menu_choice
        menu_choice=$((menu_choice + 1))
        
        echo -e "${RED}0)${NC} Exit"
        echo
        printf "${BLUE}Select option [0-$menu_choice]: ${NC}"
        read choice
        
        # Handle choice
        if [ "$choice" -ge 1 ] && [ "$choice" -le "$module_count" ]; then
            echo
            printf "${BLUE}Enter target domain: ${NC}"
            read target_domain
            
            if [ -n "$target_domain" ]; then
                # Find selected module
                for mapping in $module_map; do
                    map_choice="${mapping%%:*}"
                    map_module="${mapping##*:}"
                    if [ "$map_choice" = "$choice" ]; then
                        run_single_module "$map_module" "$target_domain"
                        break
                    fi
                done
            else
                echo -e "${RED}Domain is required!${NC}"
            fi
            
        elif [ "$choice" -eq "$run_all_choice" ]; then
            echo
            printf "${BLUE}Enter target domain: ${NC}"
            read target_domain
            
            if [ -n "$target_domain" ]; then
                run_all_modules_interactive "$target_domain"
            else
                echo -e "${RED}Domain is required!${NC}"
            fi
            
        elif [ "$choice" -eq 0 ]; then
            echo -e "${GREEN}Thank you for using r3con VAPT Suite!${NC}"
            exit 0
        else
            echo -e "${RED}Invalid option!${NC}"
        fi
        
        echo
        printf "${BLUE}Press Enter to continue...${NC}"
        read
        clear
    done
}

# Run single module
run_single_module() {
    module="$1"
    domain="$2"
    script_dir="$(dirname "$0")"
    
    if [ "$script_dir" = "." ]; then
        script_dir="$(pwd)"
    fi
    
    module_rel_path="$(get_module_path "$module")"
    module_script="$script_dir/$module_rel_path"
    
    if [ ! -f "$module_script" ]; then
        module_script="$module_rel_path"
    fi
    
    if [ ! -f "$module_script" ]; then
        echo -e "${RED}[ERROR] Module not found: $module_script${NC}"
        return 1
    fi
    
    echo -e "${GREEN}Running module: $(get_module_display_name "$module")${NC}"
    echo -e "${YELLOW}Target: $domain${NC}"
    echo
    
    chmod +x "$module_script"
    sh "$module_script" -d "$domain"
}

# Run all modules in interactive mode
run_all_modules_interactive() {
    domain="$1"
    available_modules_str="$(get_available_modules)"
    module_count=0
    
    for module in $available_modules_str; do
        module_count=$((module_count + 1))
    done
    
    echo -e "${BLUE}=== Full Reconnaissance Suite ===${NC}"
    echo -e "${YELLOW}Target: $domain${NC}"
    echo -e "${CYAN}Available modules: $module_count${NC}"
    echo
    
    output_dir="results/${domain}_full_$(date +%Y%m%d_%H%M%S)"
    mkdir -p "$output_dir"
    
    current=0
    for module in $available_modules_str; do
        current=$((current + 1))
        echo -e "${BLUE}[${current}/${module_count}] Running $(get_module_display_name "$module")...${NC}"
        
        run_single_module "$module" "$domain"
        
        echo -e "${GREEN}✓ Completed: $(get_module_display_name "$module")${NC}"
        echo
    done
    
    echo -e "${GREEN}🎉 Full reconnaissance completed!${NC}"
    echo -e "${YELLOW}Results saved in: $output_dir${NC}"
}

# Main function
main() {
    domain=""
    output_dir="results"
    threads=20
    interactive_mode_flag=false
    run_all_flag=false
    modules_to_run=""
    
    # Parse arguments
    while [ $# -gt 0 ]; do
        case $1 in
            -d|--domain)
                domain="$2"
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
            --all)
                run_all_flag=true
                shift
                ;;
            --subdomain|--directory|--api-fuzzing|--web-archive|--live-probing|--js-discovery|--vuln-scanning|--screenshots|--dns-resolution|--port-scanning|--osint|--param-discovery|--tech-detection|--anon)
                module_name="${1#--}"
                if [ -z "$modules_to_run" ]; then
                    modules_to_run="$module_name"
                else
                    modules_to_run="$modules_to_run $module_name"
                fi
                shift
                ;;
            --interactive)
                interactive_mode_flag=true
                shift
                ;;
            -v|--version)
                echo "$SCRIPT_NAME v$SCRIPT_VERSION"
                exit 0
                ;;
            --list-modules)
                list_modules
                exit 0
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
    
    # Handle interactive mode
    if [ "$interactive_mode_flag" = true ]; then
        interactive_mode
        exit 0
    fi
    
    # Show banner for CLI mode
    show_main_banner
    
    # Check if domain is provided for non-interactive modes
    if [ -z "$domain" ] && [ "$run_all_flag" = true ] || [ -n "$modules_to_run" ]; then
        echo -e "${RED}[!] Domain is required for CLI mode${NC}"
        echo -e "${YELLOW}Use -d <domain> or try --interactive mode${NC}"
        exit 1
    fi
    
    # Run modules based on flags
    if [ "$run_all_flag" = true ]; then
        run_all_modules_interactive "$domain"
    elif [ -n "$modules_to_run" ]; then
        for module in $modules_to_run; do
            run_single_module "$module" "$domain"
        done
    else
        show_help
    fi
}

# Run main function with all arguments
main "$@"