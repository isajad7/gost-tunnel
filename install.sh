#!/bin/bash

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Check Root
if [ "$EUID" -ne 0 ]; then
  echo -e "${RED}Please run as root! (sudo -i)${NC}"
  exit
fi

# Functions
install_gost() {
    if command -v gost &> /dev/null; then
        echo -e "${GREEN}GOST is already installed.${NC}"
    else
        echo -e "${YELLOW}Installing GOST...${NC}"
        wget https://github.com/ginuerzh/gost/releases/download/v2.11.5/gost-linux-amd64-2.11.5.gz
        gunzip gost-linux-amd64-2.11.5.gz
        mv gost-linux-amd64-2.11.5 /usr/local/bin/gost
        chmod +x /usr/local/bin/gost
        echo -e "${GREEN}GOST installed successfully.${NC}"
    fi
}

setup_service() {
    local CMD=$1
    echo -e "${YELLOW}Creating Systemd Service...${NC}"
    
    cat > /etc/systemd/system/gost-tunnel.service <<EOF
[Unit]
Description=GOST Tunnel Service by Sajjad
After=network.target

[Service]
Type=simple
User=root
ExecStart=/usr/local/bin/gost $CMD
Restart=always
RestartSec=3

[Install]
WantedBy=multi-user.target
EOF

    systemctl daemon-reload
    systemctl enable gost-tunnel
    systemctl restart gost-tunnel
    echo -e "${GREEN}Service started and enabled on boot.${NC}"
}

show_menu() {
    clear
    echo -e "${BLUE}=========================================${NC}"
    echo -e "${BLUE}    GOST Tunnel Auto-Script by Sajjad    ${NC}"
    echo -e "${BLUE}=========================================${NC}"
    echo -e "1) Configure as ${YELLOW}FOREIGN${NC} Server (Dest)"
    echo -e "2) Configure as ${YELLOW}IRAN${NC} Server (Source)"
    echo -e "3) Check Tunnel Logs"
    echo -e "4) Stop & Uninstall Service"
    echo -e "0) Exit"
    echo -e "${BLUE}=========================================${NC}"
    read -p "Select an option: " choice
}

# Main Logic
while true; do
    show_menu
    case $choice in
        1)
            install_gost
            echo -e "${YELLOW}--- Foreign Server Setup ---${NC}"
            read -p "Enter Tunnel Port (Default 2083): " T_PORT
            T_PORT=${T_PORT:-2083}
            read -p "Enter Tunnel Username: " T_USER
            read -p "Enter Tunnel Password: " T_PASS
            
            # Open Firewall
            if command -v ufw &> /dev/null; then
                ufw allow $T_PORT/tcp
            fi

            # Command for Foreign: Listen on WS
            CMD="-L=ws://${T_USER}:${T_PASS}@:${T_PORT}"
            
            setup_service "$CMD"
            echo -e "${GREEN}Foreign Server Configured on Port $T_PORT!${NC}"
            read -p "Press Enter to continue..."
            ;;
        2)
            install_gost
            echo -e "${YELLOW}--- Iran Server Setup ---${NC}"
            read -p "Enter Foreign Server IP: " F_IP
            read -p "Enter Foreign Tunnel Port (e.g., 2083): " F_PORT
            read -p "Enter Tunnel Username: " F_USER
            read -p "Enter Tunnel Password: " F_PASS
            
            echo -e "${BLUE}Enter the ports you want to tunnel (separate with SPACE).${NC}"
            echo -e "Example: 2095 443 2053"
            read -p "Ports: " USER_PORTS

            # Build Command
            L_FLAGS=""
            for PORT in $USER_PORTS; do
                # Listen on IPv4 0.0.0.0 explicitly to avoid IPv6 issues
                L_FLAGS+=" -L=tcp://0.0.0.0:$PORT/127.0.0.1:$PORT"
                
                # Open Firewall
                if command -v ufw &> /dev/null; then
                    ufw allow $PORT/tcp
                    echo -e "Opened port $PORT in UFW."
                fi
            done
            
            # Final Command for Iran
            CMD="$L_FLAGS -F=ws://${F_USER}:${F_PASS}@${F_IP}:${F_PORT}"
            
            setup_service "$CMD"
            echo -e "${GREEN}Iran Server Configured! Tunneling ports: $USER_PORTS${NC}"
            read -p "Press Enter to continue..."
            ;;
        3)
            echo -e "${YELLOW}Showing last 20 logs (Press Ctrl+C to exit logs)${NC}"
            journalctl -u gost-tunnel -n 20 -f
            ;;
        4)
            systemctl stop gost-tunnel
            systemctl disable gost-tunnel
            rm /etc/systemd/system/gost-tunnel.service
            systemctl daemon-reload
            echo -e "${RED}Service Removed.${NC}"
            read -p "Press Enter to continue..."
            ;;
        0)
            exit 0
            ;;
        *)
            echo "Invalid option."
            ;;
    esac
done
