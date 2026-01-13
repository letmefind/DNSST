#!/bin/bash

# DNSTT Client Management Script

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

WORK_DIR="/opt/dnstt"
SERVICE_NAME="dnstt-client"

if [ "$EUID" -ne 0 ]; then 
    echo -e "${RED}Please run as root${NC}"
    exit 1
fi

show_menu() {
    echo -e "${BLUE}========================================${NC}"
    echo -e "${BLUE}  DNSTT Client Management${NC}"
    echo -e "${BLUE}========================================${NC}"
    echo ""
    echo "1. View service status"
    echo "2. View logs (live)"
    echo "3. View logs (last 50 lines)"
    echo "4. Restart service"
    echo "5. Stop service"
    echo "6. Start service"
    echo "7. Show configuration"
    echo "8. Check ports"
    echo "0. Exit"
    echo ""
}

show_status() {
    echo -e "${YELLOW}Service status:${NC}"
    systemctl status $SERVICE_NAME --no-pager -l
}

show_logs_live() {
    echo -e "${YELLOW}Live logs (Press Ctrl+C to exit):${NC}"
    journalctl -u $SERVICE_NAME -f
}

show_logs_recent() {
    echo -e "${YELLOW}Last 50 lines of logs:${NC}"
    journalctl -u $SERVICE_NAME -n 50 --no-pager
}

restart_service() {
    echo -e "${YELLOW}Restarting service...${NC}"
    systemctl restart $SERVICE_NAME
    sleep 2
    systemctl status $SERVICE_NAME --no-pager -l
}

stop_service() {
    echo -e "${YELLOW}Stopping service...${NC}"
    systemctl stop $SERVICE_NAME
    echo -e "${GREEN}Service stopped${NC}"
}

start_service() {
    echo -e "${YELLOW}Starting service...${NC}"
    systemctl start $SERVICE_NAME
    sleep 2
    systemctl status $SERVICE_NAME --no-pager -l
}

show_info() {
    echo -e "${YELLOW}Configuration file:${NC}"
    if [ -f "$WORK_DIR/client.conf" ]; then
        cat $WORK_DIR/client.conf
    else
        echo -e "${RED}Configuration file not found${NC}"
    fi
    
    echo ""
    echo -e "${YELLOW}Public key file:${NC}"
    if [ -f "$WORK_DIR/server.pub" ]; then
        cat $WORK_DIR/server.pub
    else
        echo -e "${RED}Public key file not found${NC}"
    fi
    
    echo ""
    echo -e "${YELLOW}Service file:${NC}"
    if [ -f "/etc/systemd/system/$SERVICE_NAME.service" ]; then
        cat /etc/systemd/system/$SERVICE_NAME.service
    else
        echo -e "${RED}Service file not found${NC}"
    fi
}

check_ports() {
    echo -e "${YELLOW}Checking open ports:${NC}"
    netstat -tulpn | grep -E ":(1080|8080)" || ss -tulpn | grep -E ":(1080|8080)"
}

while true; do
    show_menu
    read -p "Select option: " choice
    echo ""
    
    case $choice in
        1)
            show_status
            ;;
        2)
            show_logs_live
            ;;
        3)
            show_logs_recent
            ;;
        4)
            restart_service
            ;;
        5)
            stop_service
            ;;
        6)
            start_service
            ;;
        7)
            show_info
            ;;
        8)
            check_ports
            ;;
        0)
            echo "Exiting..."
            exit 0
            ;;
        *)
            echo -e "${RED}Invalid option${NC}"
            ;;
    esac
    
    echo ""
    read -p "Press Enter to continue..."
    clear
done
