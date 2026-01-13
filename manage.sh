#!/bin/bash

# DNSTT Server Management Script

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

WORK_DIR="/opt/dnstt"
SERVICE_NAME="dnstt-server"

if [ "$EUID" -ne 0 ]; then 
    echo -e "${RED}Please run as root${NC}"
    exit 1
fi

show_menu() {
    echo -e "${BLUE}========================================${NC}"
    echo -e "${BLUE}  DNSTT Server Management${NC}"
    echo -e "${BLUE}========================================${NC}"
    echo ""
    echo "1. View service status"
    echo "2. View logs (live)"
    echo "3. View logs (last 50 lines)"
    echo "4. Restart service"
    echo "5. Stop service"
    echo "6. Start service"
    echo "7. Show connection info"
    echo "8. Show public key"
    echo "9. Check ports"
    echo "10. Check iptables"
    echo "11. Free port 53 (if using port 53)"
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
    show_status
}

stop_service() {
    echo -e "${YELLOW}Stopping service...${NC}"
    systemctl stop $SERVICE_NAME
    sleep 1
    show_status
}

start_service() {
    echo -e "${YELLOW}Starting service...${NC}"
    systemctl start $SERVICE_NAME
    sleep 2
    show_status
}

show_info() {
    if [ -f "$WORK_DIR/info.txt" ]; then
        cat $WORK_DIR/info.txt
    else
        echo -e "${RED}Info file not found${NC}"
    fi
}

show_pubkey() {
    if [ -f "$WORK_DIR/server.pub" ]; then
        echo -e "${YELLOW}Public key:${NC}"
        cat $WORK_DIR/server.pub
    else
        echo -e "${RED}Public key file not found${NC}"
    fi
}

check_ports() {
    echo -e "${YELLOW}Checking open ports:${NC}"
    netstat -tulpn | grep -E ":(5300|1080)" || ss -tulpn | grep -E ":(5300|1080)"
}

check_iptables() {
    echo -e "${YELLOW}iptables rules:${NC}"
    iptables -t nat -L -n -v
    echo ""
    echo -e "${YELLOW}INPUT rules:${NC}"
    iptables -L INPUT -n -v
}

free_port_53() {
    echo -e "${YELLOW}Freeing port 53...${NC}"
    
    # Stop services
    systemctl stop dnstt-server 2>/dev/null
    systemctl stop systemd-resolved 2>/dev/null
    systemctl stop dnsmasq 2>/dev/null
    systemctl stop named 2>/dev/null
    systemctl stop bind9 2>/dev/null
    
    # Kill processes
    pkill -9 -f dnstt-server 2>/dev/null
    pkill -9 systemd-resolved 2>/dev/null
    pkill -9 dnsmasq 2>/dev/null
    pkill -9 named 2>/dev/null
    
    sleep 2
    
    # Check what's using port 53
    PORT_53_USAGE=$(netstat -tulpn 2>/dev/null | grep -E "udp.*:53 " || ss -tulpn 2>/dev/null | grep -E "udp.*:53 " || echo "")
    
    if [ -n "$PORT_53_USAGE" ]; then
        # Try to extract and kill PID
        PID=$(echo "$PORT_53_USAGE" | awk '{for(i=1;i<=NF;i++) if($i ~ /^[0-9]+\//) {print $i; exit}}' | cut -d'/' -f1)
        if [ -n "$PID" ] && [ "$PID" != "-" ] && [ "$PID" != "0" ]; then
            echo -e "${YELLOW}Killing process PID: $PID${NC}"
            kill -9 $PID 2>/dev/null
            sleep 1
        fi
        
        # Try fuser if available
        if command -v fuser &> /dev/null; then
            echo -e "${YELLOW}Using fuser to kill processes on port 53...${NC}"
            fuser -k 53/udp 2>/dev/null
            sleep 1
        fi
        
        # Final check
        PORT_53_USAGE=$(netstat -tulpn 2>/dev/null | grep -E "udp.*:53 " || ss -tulpn 2>/dev/null | grep -E "udp.*:53 " || echo "")
        if [ -n "$PORT_53_USAGE" ]; then
            echo -e "${RED}Port 53 is still in use:${NC}"
            echo "$PORT_53_USAGE"
            echo -e "${YELLOW}You may need to manually investigate${NC}"
        else
            echo -e "${GREEN}Port 53 is now free${NC}"
        fi
    else
        echo -e "${GREEN}Port 53 is already free${NC}"
    fi
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
            show_pubkey
            ;;
        9)
            check_ports
            ;;
        10)
            check_iptables
            ;;
        11)
            free_port_53
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
