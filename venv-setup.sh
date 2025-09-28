#!/bin/bash

# R3CON VAPT Suite - Virtual Environment Setup Guide
# Step-by-step installation with proper Python virtual environment

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

echo -e "${CYAN}"
cat << "EOF"
╔══════════════════════════════════════════════════════════════╗
║                R3CON VAPT SUITE SETUP GUIDE                 ║
║            Proper Virtual Environment Installation           ║
╚══════════════════════════════════════════════════════════════╝
EOF
echo -e "${NC}"

echo -e "${BLUE}This guide will set up R3CON VAPT Suite with a proper Python virtual environment.${NC}"
echo -e "${YELLOW}Many security tools require specific Python versions and dependencies.${NC}"
echo

# Step 1: Check Python installation
echo -e "${CYAN}Step 1: Checking Python installation...${NC}"
if command -v python3 &> /dev/null; then
    python_version=$(python3 --version)
    echo -e "${GREEN}✓ Found: $python_version${NC}"
else
    echo -e "${RED}✗ Python3 not found${NC}"
    echo -e "${YELLOW}Installing Python3...${NC}"
    
    # Detect OS and install Python
    if [[ "$OSTYPE" == "linux-gnu"* ]]; then
        if command -v apt &> /dev/null; then
            sudo apt update
            sudo apt install python3 python3-pip python3-venv python3-dev -y
        elif command -v yum &> /dev/null; then
            sudo yum install python3 python3-pip python3-devel -y
        elif command -v pacman &> /dev/null; then
            sudo pacman -S python python-pip python-virtualenv
        else
            echo -e "${RED}Unable to detect package manager. Please install Python3 manually.${NC}"
            exit 1
        fi
    elif [[ "$OSTYPE" == "darwin"* ]]; then
        if command -v brew &> /dev/null; then
            brew install python3
        else
            echo -e "${RED}Please install Homebrew or Python3 manually on macOS${NC}"
            exit 1
        fi
    else
        echo -e "${RED}Unsupported operating system${NC}"
        exit 1
    fi
    
    echo -e "${GREEN}✓ Python3 installed successfully${NC}"
fi

# Step 2: Create virtual environment
echo
echo -e "${CYAN}Step 2: Creating Python virtual environment...${NC}"

if [[ -d "r3con-env" ]]; then
    echo -e "${YELLOW}Virtual environment 'r3con-env' already exists.${NC}"
    echo -e "${YELLOW}Do you want to recreate it? (y/N): ${NC}"
    read -r recreate
    if [[ "$recreate" =~ ^[Yy]$ ]]; then
        rm -rf r3con-env
        echo -e "${BLUE}Removed existing virtual environment${NC}"
    else
        echo -e "${BLUE}Using existing virtual environment${NC}"
    fi
fi

if [[ ! -d "r3con-env" ]]; then
    python3 -m venv r3con-env
    echo -e "${GREEN}✓ Virtual environment created: r3con-env${NC}"
fi

# Step 3: Activate virtual environment
echo
echo -e "${CYAN}Step 3: Activating virtual environment...${NC}"
source r3con-env/bin/activate

if [[ -n "$VIRTUAL_ENV" ]]; then
    echo -e "${GREEN}✓ Virtual environment activated: $(basename $VIRTUAL_ENV)${NC}"
else
    echo -e "${RED}✗ Failed to activate virtual environment${NC}"
    exit 1
fi

# Step 4: Upgrade pip and install dependencies
echo
echo -e "${CYAN}Step 4: Installing Python dependencies...${NC}"
pip install --upgrade pip

# Install common packages that security tools need
echo -e "${BLUE}Installing essential packages...${NC}"
pip install requests beautifulsoup4 dnspython tldextract urllib3 colorama pyyaml jinja2

# Install common security-related packages
echo -e "${BLUE}Installing security tool dependencies...${NC}"
pip install python-nmap scapy netaddr ipwhois shodan censys

# Test Python integration
echo -e "${BLUE}Testing Python integration...${NC}"
python3 -c "
import requests, dns.resolver, tldextract
print('✅ All Python packages working correctly')
" 2>/dev/null && echo -e "${GREEN}✅ Python integration test passed${NC}" || echo -e "${YELLOW}⚠️  Some Python packages may have issues${NC}"

echo -e "${GREEN}✓ Python dependencies installed${NC}"

# Step 5: Install R3CON VAPT Suite
echo
echo -e "${CYAN}Step 5: Installing R3CON VAPT Suite...${NC}"
curl -sSL https://raw.githubusercontent.com/durgeshw22/r3con2.0/main/create-installer.sh | bash

# Step 6: Final setup and instructions
echo
echo -e "${GREEN}"
cat << "EOF"
╔═══════════════════════════════════════════════╗
║              SETUP COMPLETE!                 ║
╚═══════════════════════════════════════════════╝
EOF
echo -e "${NC}"

echo -e "${CYAN}🎉 R3CON VAPT Suite has been successfully installed!${NC}"
echo
echo -e "${YELLOW}Important: Always activate the virtual environment before using r3con:${NC}"
echo -e "${BLUE}    source r3con-env/bin/activate${NC}"
echo
echo -e "${CYAN}Quick Start Commands:${NC}"
echo -e "${BLUE}    # Activate virtual environment${NC}"
echo -e "${YELLOW}    source r3con-env/bin/activate${NC}"
echo
echo -e "${BLUE}    # Test installation${NC}"
echo -e "${YELLOW}    r3con --help${NC}"
echo -e "${YELLOW}    r3con --list-modules${NC}"
echo
echo -e "${BLUE}    # Start interactive mode${NC}"
echo -e "${YELLOW}    r3con --interactive${NC}"
echo
echo -e "${BLUE}    # Run full scan${NC}"
echo -e "${YELLOW}    r3con -d example.com --all${NC}"
echo
echo -e "${BLUE}    # Deactivate when done (optional)${NC}"
echo -e "${YELLOW}    deactivate${NC}"
echo
echo -e "${CYAN}📚 For more information, see the README.md file.${NC}"
echo -e "${CYAN}🐛 Report issues at: https://github.com/durgeshw22/r3con2.0/issues${NC}"
echo

# Create a convenient activation script
cat > activate-r3con.sh << 'ACTIVATE_EOF'
#!/bin/bash
# R3CON VAPT Suite - Quick Activation Script

if [[ -f "r3con-env/bin/activate" ]]; then
    source r3con-env/bin/activate
    echo -e "\033[0;32m✓ R3CON virtual environment activated\033[0m"
    echo -e "\033[0;34mYou can now use 'r3con' commands\033[0m"
else
    echo -e "\033[0;31m✗ Virtual environment not found\033[0m"
    echo -e "\033[0;33mPlease run the setup script first\033[0m"
    exit 1
fi
ACTIVATE_EOF

chmod +x activate-r3con.sh
echo -e "${GREEN}✓ Created convenience script: ./activate-r3con.sh${NC}"
echo -e "${BLUE}You can also use: ./activate-r3con.sh${NC}"