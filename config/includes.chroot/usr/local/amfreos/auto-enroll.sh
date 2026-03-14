#!/bin/bash
# AmfreOS Auto-Enrollment Script
# Automatically discovers Wazuh server and enrolls endpoint

RED='\033[0;31m'
GREEN='\033[0;32m'
CYAN='\033[0;36m'
YELLOW='\033[1;33m'
NC='\033[0m'

WAZUH_AGENT_SERVICE="wazuh-agent"
WAZUH_PORT=1514   # Wazuh manager port (TCP)

echo -e "${CYAN}Starting auto-enrollment process...${NC}"

# Function to discover Wazuh server on the local subnet
discover_server() {
    echo -e "${CYAN}Scanning local network for Wazuh server...${NC}"

    # Get local network range (assumes /24 subnet)
    NET=$(ip -o -f inet addr show | awk '/scope global/ {print $4}' | head -n1)

    if [ -z "$NET" ]; then
        echo -e "${RED}Could not detect local network. Please enter Wazuh server IP manually.${NC}"
        read -p "Server IP: " SERVER
        return
    fi

    # Scan for host with Wazuh manager port open
    SERVER=$(nmap -p $WAZUH_PORT --open $NET | grep "report for" | awk '{print $5}' | head -n1)

    if [ -z "$SERVER" ]; then
        echo -e "${YELLOW}No Wazuh server found automatically. Please enter IP manually.${NC}"
        read -p "Server IP: " SERVER
    fi
}

# Function to install and configure the Wazuh agent
install_agent() {
    echo -e "${CYAN}Installing and configuring Wazuh agent...${NC}"

    # Install agent if missing
    if ! command -v wazuh-agent >/dev/null 2>&1; then
        echo -e "${CYAN}Installing Wazuh agent package...${NC}"
        sudo apt update
        sudo apt install -y wazuh-agent
    fi

    # Configure agent to point to discovered server
    if [ -f /var/ossec/etc/ossec.conf ]; then
        sudo sed -i "s/<address>.*<\/address>/<address>$SERVER<\/address>/g" /var/ossec/etc/ossec.conf
    fi

    # Enable and start agent
    sudo systemctl enable $WAZUH_AGENT_SERVICE
    sudo systemctl restart $WAZUH_AGENT_SERVICE

    echo -e "${GREEN}Wazuh agent enrolled to server at $SERVER${NC}"
}

# Main
discover_server
install_agent

echo -e "${CYAN}Auto-enrollment completed.${NC}"
