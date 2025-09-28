# 🔍 R3CON VAPT Suite - Advanced Modular Rec### **🚀 Step 2: One-Liner Installation (Recommended)**
```bash
# Make sure virtual environment is activated first!
source r3con-env/bin/activate  # Linux/macOS

# Install R3CON
curl -sSL https://raw.githubusercontent.com/durgeshw22/r3con2.0/main/create-installer.sh | bash
```

### **🐍 Complete Automated Setup (Beginner-Friendly)**
For a fully automated setup that handles everything:
```bash
# This script sets up venv + installs everything
curl -sSL https://raw.githubusercontent.com/durgeshw22/r3con2.0/main/venv-setup.sh | bash
```nce Framework

```
██████╗ ██████╗  ██████╗ ██████╗ ███╗   ██╗
██╔══██╗╚════██╗██╔════╝██╔═══██╗████╗  ██║  
██████╔╝ █████╔╝██║     ██║   ██║██╔██╗ ██║  
██╔══██╗ ╚═══██╗██║     ██║   ██║██║╚██╗██║  
██║  ██║██████╔╝╚██████╗╚██████╔╝██║ ╚████║  
╚═╝  ╚═╝╚═════╝  ╚═════╝ ╚═════╝ ╚═╝  ╚═══╝  
    VAPT Suite - Professional Security Framework
```

> **🎯 Comprehensive • 🚀 Automated • 🔧 Modular • 💯 Professional**

A cutting-edge **Vulnerability Assessment and Penetration Testing (VAPT)** suite with **14 specialized modules** and **50+ integrated security tools**. Designed for bug bounty hunters, penetration testers, and security researchers who demand efficiency and comprehensive coverage.

## ⚡ Lightning-Fast Installation

> **⚠️ IMPORTANT**: Many security tools require Python virtual environment for optimal performance and dependency management.

### **🤔 Why Virtual Environment?**
- **🔒 Isolation**: Prevents conflicts with system Python packages
- **🛠️ Tool Compatibility**: Many security tools need specific Python versions
- **📦 Clean Dependencies**: Easier to manage and troubleshoot installations
- **🚀 Better Performance**: Optimized package versions for security tools
- **🔄 Easy Cleanup**: Remove entire environment without affecting system

### **� Step 1: Create Python Virtual Environment (Recommended)**
```bash
# Install Python and pip (if not already installed)
sudo apt update && sudo apt install python3 python3-pip python3-venv -y  # Ubuntu/Debian
# OR
sudo yum install python3 python3-pip -y  # CentOS/RHEL
# OR
brew install python3  # macOS

# Create virtual environment
python3 -m venv r3con-env

# Activate virtual environment
source r3con-env/bin/activate  # Linux/macOS
# OR
r3con-env\Scripts\activate  # Windows

# Upgrade pip
pip install --upgrade pip

# Install common security tools dependencies
pip install requests beautifulsoup4 dnspython tldextract urllib3 colorama
```

### **�🚀 Step 2: One-Liner Installation (Recommended)**
```bash
# Make sure virtual environment is activated first!
source r3con-env/bin/activate  # Linux/macOS

# Install R3CON
curl -sSL https://raw.githubusercontent.com/durgeshw22/r3con2.0/main/create-installer.sh | bash
```

### **🔧 If You Encounter Issues**
```bash
# Fix any issues with the repair script
curl -sSL https://raw.githubusercontent.com/durgeshw22/r3con2.0/main/ultimate-fix.sh | bash
```

### **📦 Alternative Manual Installation**
```bash
# Make sure virtual environment is activated first!
source r3con-env/bin/activate

# Clone and install
git clone https://github.com/durgeshw22/r3con2.0.git
cd r3con2.0
chmod +x create-installer.sh
./create-installer.sh
```

### **🔄 Daily Usage Workflow**
```bash
# Always activate virtual environment before using r3con
source r3con-env/bin/activate

# Use r3con normally
r3con --interactive
r3con -d example.com --all

# Deactivate when done (optional)
deactivate
```

## 🛠️ What Gets Installed

### **🔧 Core Security Tools (50+)**
- **Subdomain Discovery**: subfinder, assetfinder, amass, chaos, httpx
- **Directory Fuzzing**: ffuf, gobuster, dirsearch, feroxbuster, wfuzz
- **Port Scanning**: nmap, masscan, naabu, rustscan, unicornscan, zmap
- **Vulnerability Assessment**: nuclei, nikto, sqlmap, wpscan, nmap-scripts
- **Web Analysis**: httpx, gowitness, aquatone, cutycapt, whatweb
- **OSINT Gathering**: whois, dig, shodan, virustotal, haveibeenpwned
- **DNS Analysis**: dnsx, dnsrecon, fierce, massdns, amass
- **JavaScript Discovery**: wayback, gau, linkfinder, secretfinder
- **API Testing**: arjun, kiterunner, x8, param-miner
- **Screenshots**: gowitness, aquatone, cutycapt, webscreenshot

### **📋 Reconnaissance Modules (14)**
1. **Subdomain Enumeration** - Comprehensive subdomain discovery
2. **Directory Fuzzing** - Web directory and file discovery  
3. **API Fuzzing** - REST API endpoint discovery and testing
4. **Web Archive Discovery** - Historical data from web archives
5. **Live Probing** - Active host and service discovery
6. **JavaScript Analysis** - JS file discovery and secrets extraction
7. **Vulnerability Scanning** - Automated vulnerability assessment
8. **Screenshot Capture** - Visual reconnaissance of web applications
9. **DNS Resolution** - Comprehensive DNS analysis and enumeration
10. **Port Scanning** - Network port discovery and service detection
11. **OSINT Gathering** - Open source intelligence collection
12. **Parameter Discovery** - Hidden parameter and endpoint discovery
13. **Technology Detection** - Tech stack identification and analysis
14. **Anonymous Scanning** - Proxy-based reconnaissance

## 🎯 Quick Usage

### **🖥️ Interactive Mode**
```bash
r3con --interactive
```

### **🚀 Quick Scans**
```bash
# Full reconnaissance suite
r3con -d example.com --all

# Subdomain enumeration only
r3con -d example.com --subdomain

# Port scanning
r3con -t 192.168.1.1 --port-scan

# Vulnerability assessment
r3con -d example.com --vuln-scan

# OSINT gathering
r3con -d example.com --osint
```

### **🔧 Advanced Usage**
```bash
# Custom output directory
r3con -d example.com --all -o /tmp/results

# Specific modules with custom settings
r3con -d example.com --subdomain --threads 50

# Stealth mode with proxies
r3con -d example.com --all --stealth --proxy

# API mode for automation
r3con -d example.com --json --output results.json
```

## 📊 Features

### **🚀 Performance**
- ⚡ **Multi-threaded** - Parallel execution for maximum speed
- 🎯 **Intelligent filtering** - Smart duplicate removal and correlation
- 📈 **Progress tracking** - Real-time progress indicators
- 🔄 **Resume capability** - Continue interrupted scans

### **🔧 Flexibility**
- 🎛️ **Modular design** - Use individual modules or full suite
- ⚙️ **Configurable** - Extensive customization options
- 🔌 **Extensible** - Easy to add new tools and modules
- 🎨 **Multiple output formats** - JSON, XML, CSV, HTML reports

### **🛡️ Operational Security**
- 🕵️ **Stealth modes** - Low-profile scanning options
- 🌐 **Proxy support** - Tor and custom proxy integration
- 🎭 **User-agent rotation** - Evade basic detection
- ⏱️ **Rate limiting** - Respectful scanning practices

### **📋 Reporting**
- 📊 **Comprehensive reports** - Detailed HTML and PDF reports
- 📈 **Executive summaries** - High-level overview for management
- 🔍 **Technical details** - In-depth findings for analysts
- 📤 **Export options** - Multiple format support

## 🗂️ Project Structure

```
r3con/
├── 📁 modules/          # 14 specialized reconnaissance modules
│   ├── subdomain.sh     # Subdomain enumeration
│   ├── directory.sh     # Directory/file fuzzing
│   ├── api-fuzzing.sh   # API endpoint testing
│   ├── web-archive.sh   # Web archive discovery
│   ├── live-probing.sh  # Live host discovery
│   ├── js-discovery.sh  # JavaScript analysis
│   ├── vuln-scanning.sh # Vulnerability assessment
│   ├── screenshots.sh   # Screenshot capture
│   ├── dns-resolution.sh# DNS analysis
│   ├── port-scanning.sh # Port scanning
│   ├── osint.sh         # OSINT gathering
│   ├── param-discovery.sh# Parameter discovery
│   ├── tech-detection.sh# Technology detection
│   └── anon.sh          # Anonymous scanning
├── 📁 utils/            # Shared utilities and libraries
├── 📁 wordlists/        # Curated wordlists for fuzzing
├── 📁 results/          # Scan results and reports
├── 🚀 create-installer.sh # Self-contained installer
├── ⚙️ recon-orchestrator.sh # Main orchestration engine
└── 📚 README.md         # This file
```

## 🎓 Documentation

### **📖 Module Documentation**
Each module includes comprehensive help:
```bash
./modules/subdomain.sh --help
./modules/port-scanning.sh --help
./modules/vuln-scanning.sh --help
```

### **🔧 Configuration**
- **API Keys**: Set environment variables for external services
- **Wordlists**: Custom wordlist locations and formats
- **Proxies**: Proxy configuration and rotation
- **Output**: Custom report templates and formats

## 🤝 Contributing

We welcome contributions! Please see our contributing guidelines:

1. **Fork** the repository
2. **Create** a feature branch
3. **Test** thoroughly on multiple systems
4. **Submit** a pull request with detailed description

## ⚖️ Legal Disclaimer

This tool is for **authorized testing only**. Users are responsible for:
- ✅ Obtaining proper authorization before testing
- ✅ Complying with local laws and regulations
- ✅ Using the tool responsibly and ethically
- ❌ The authors are not responsible for misuse

## �️ Troubleshooting

### **❌ "No modules found" Error**
If you see this error in interactive mode:
```bash
curl -sSL https://raw.githubusercontent.com/durgeshw22/r3con2.0/main/ultimate-fix.sh | bash
```

### **❌ Interactive Menu Shows Same Names**
If all modules show as "Anonymity & IP Rotation":
```bash
curl -sSL https://raw.githubusercontent.com/durgeshw22/r3con2.0/main/ultimate-fix.sh | bash
```

### **❌ Installation Issues**
- **Python errors**: Make sure you've activated the virtual environment first
- **Tool not found errors**: Install missing tools in the virtual environment with `pip install <tool>`
- **Permission denied**: Don't run as root, use regular user with sudo
- **Network issues**: Check internet connection and firewall settings
- **Virtual environment issues**: Recreate the venv if corrupted:
  ```bash
  rm -rf r3con-env
  python3 -m venv r3con-env
  source r3con-env/bin/activate
  pip install --upgrade pip
  ```

### **✅ Verify Installation**
```bash
r3con --help                 # Should show comprehensive help
r3con --list-modules         # Should list all 14 modules
r3con --interactive          # Should show working menu
```

## �📞 Support

- **🐛 Issues**: Report bugs via GitHub Issues
- **💡 Features**: Request features via GitHub Discussions  
- **📧 Contact**: security@example.com
- **📱 Discord**: Join our community server

## 🏆 Credits

Built with ❤️ by the security community. Special thanks to:
- ProjectDiscovery team for amazing tools
- OWASP for security guidance
- Bug bounty community for feedback and testing

---

**⭐ Star this repository if you find it useful!**

[![GitHub stars](https://img.shields.io/github/stars/durgeshw22/r3con2.0.svg)](https://github.com/durgeshw22/r3con2.0/stargazers)
[![GitHub forks](https://img.shields.io/github/forks/durgeshw22/r3con2.0.svg)](https://github.com/durgeshw22/r3con2.0/network)
[![GitHub issues](https://img.shields.io/github/issues/durgeshw22/r3con2.0.svg)](https://github.com/durgeshw22/r3con2.0/issues)