#!/bin/bash

# اسکریپت مدیریت DNSTT Server

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

WORK_DIR="/opt/dnstt"
SERVICE_NAME="dnstt-server"

if [ "$EUID" -ne 0 ]; then 
    echo -e "${RED}لطفا با دسترسی root اجرا کنید${NC}"
    exit 1
fi

show_menu() {
    echo -e "${BLUE}========================================${NC}"
    echo -e "${BLUE}  مدیریت DNSTT Server${NC}"
    echo -e "${BLUE}========================================${NC}"
    echo ""
    echo "1. مشاهده وضعیت سرویس"
    echo "2. مشاهده لاگ‌ها (زنده)"
    echo "3. مشاهده لاگ‌ها (آخرین 50 خط)"
    echo "4. راه‌اندازی مجدد سرویس"
    echo "5. توقف سرویس"
    echo "6. شروع سرویس"
    echo "7. نمایش اطلاعات اتصال"
    echo "8. نمایش کلید عمومی"
    echo "9. بررسی پورت‌ها"
    echo "10. بررسی iptables"
    echo "0. خروج"
    echo ""
}

show_status() {
    echo -e "${YELLOW}وضعیت سرویس:${NC}"
    systemctl status $SERVICE_NAME --no-pager -l
}

show_logs_live() {
    echo -e "${YELLOW}لاگ‌های زنده (برای خروج Ctrl+C):${NC}"
    journalctl -u $SERVICE_NAME -f
}

show_logs_recent() {
    echo -e "${YELLOW}آخرین 50 خط لاگ:${NC}"
    journalctl -u $SERVICE_NAME -n 50 --no-pager
}

restart_service() {
    echo -e "${YELLOW}در حال راه‌اندازی مجدد...${NC}"
    systemctl restart $SERVICE_NAME
    sleep 2
    show_status
}

stop_service() {
    echo -e "${YELLOW}در حال توقف سرویس...${NC}"
    systemctl stop $SERVICE_NAME
    sleep 1
    show_status
}

start_service() {
    echo -e "${YELLOW}در حال شروع سرویس...${NC}"
    systemctl start $SERVICE_NAME
    sleep 2
    show_status
}

show_info() {
    if [ -f "$WORK_DIR/info.txt" ]; then
        cat $WORK_DIR/info.txt
    else
        echo -e "${RED}فایل اطلاعات یافت نشد${NC}"
    fi
}

show_pubkey() {
    if [ -f "$WORK_DIR/server.pub" ]; then
        echo -e "${YELLOW}کلید عمومی:${NC}"
        cat $WORK_DIR/server.pub
    else
        echo -e "${RED}فایل کلید عمومی یافت نشد${NC}"
    fi
}

check_ports() {
    echo -e "${YELLOW}بررسی پورت‌های باز:${NC}"
    netstat -tulpn | grep -E ":(5300|1080)" || ss -tulpn | grep -E ":(5300|1080)"
}

check_iptables() {
    echo -e "${YELLOW}قوانین iptables:${NC}"
    iptables -t nat -L -n -v
    echo ""
    echo -e "${YELLOW}قوانین INPUT:${NC}"
    iptables -L INPUT -n -v
}

while true; do
    show_menu
    read -p "گزینه را انتخاب کنید: " choice
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
        0)
            echo "خروج..."
            exit 0
            ;;
        *)
            echo -e "${RED}گزینه نامعتبر${NC}"
            ;;
    esac
    
    echo ""
    read -p "برای ادامه Enter را فشار دهید..."
    clear
done

