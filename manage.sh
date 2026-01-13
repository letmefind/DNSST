#!/bin/bash

# تنظیمات RTL برای نمایش صحیح فارسی
export LC_ALL=C.UTF-8
export LANG=C.UTF-8

# کاراکترهای کنترل Unicode برای RTL
RLE=$'\u202B'  # Right-to-Left Embedding
PDF=$'\u202C'  # Pop Directional Formatting

# اسکریپت مدیریت DNSTT Server

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

WORK_DIR="/opt/dnstt"
SERVICE_NAME="dnstt-server"

if [ "$EUID" -ne 0 ]; then 
    printf "%b\n" "${RED}${RLE}لطفا با دسترسی root اجرا کنید${PDF}${NC}"
    exit 1
fi

show_menu() {
    echo -e "${BLUE}========================================${NC}"
    printf "%b\n" "${BLUE}${RLE}  مدیریت DNSTT Server${PDF}${NC}"
    echo -e "${BLUE}========================================${NC}"
    echo ""
    printf "%b\n" "${RLE}1. مشاهده وضعیت سرویس${PDF}"
    printf "%b\n" "${RLE}2. مشاهده لاگ‌ها (زنده)${PDF}"
    printf "%b\n" "${RLE}3. مشاهده لاگ‌ها (آخرین 50 خط)${PDF}"
    printf "%b\n" "${RLE}4. راه‌اندازی مجدد سرویس${PDF}"
    printf "%b\n" "${RLE}5. توقف سرویس${PDF}"
    printf "%b\n" "${RLE}6. شروع سرویس${PDF}"
    printf "%b\n" "${RLE}7. نمایش اطلاعات اتصال${PDF}"
    printf "%b\n" "${RLE}8. نمایش کلید عمومی${PDF}"
    printf "%b\n" "${RLE}9. بررسی پورت‌ها${PDF}"
    printf "%b\n" "${RLE}10. بررسی iptables${PDF}"
    printf "%b\n" "${RLE}0. خروج${PDF}"
    echo ""
}

show_status() {
    printf "%b\n" "${YELLOW}${RLE}وضعیت سرویس:${PDF}${NC}"
    systemctl status $SERVICE_NAME --no-pager -l
}

show_logs_live() {
    printf "%b\n" "${YELLOW}${RLE}لاگ‌های زنده (برای خروج Ctrl+C):${PDF}${NC}"
    journalctl -u $SERVICE_NAME -f
}

show_logs_recent() {
    printf "%b\n" "${YELLOW}${RLE}آخرین 50 خط لاگ:${PDF}${NC}"
    journalctl -u $SERVICE_NAME -n 50 --no-pager
}

restart_service() {
    printf "%b\n" "${YELLOW}${RLE}در حال راه‌اندازی مجدد...${PDF}${NC}"
    systemctl restart $SERVICE_NAME
    sleep 2
    show_status
}

stop_service() {
    printf "%b\n" "${YELLOW}${RLE}در حال توقف سرویس...${PDF}${NC}"
    systemctl stop $SERVICE_NAME
    sleep 1
    show_status
}

start_service() {
    printf "%b\n" "${YELLOW}${RLE}در حال شروع سرویس...${PDF}${NC}"
    systemctl start $SERVICE_NAME
    sleep 2
    show_status
}

show_info() {
    if [ -f "$WORK_DIR/info.txt" ]; then
        cat $WORK_DIR/info.txt
    else
        printf "%b\n" "${RED}${RLE}فایل اطلاعات یافت نشد${PDF}${NC}"
    fi
}

show_pubkey() {
    if [ -f "$WORK_DIR/server.pub" ]; then
        printf "%b\n" "${YELLOW}${RLE}کلید عمومی:${PDF}${NC}"
        cat $WORK_DIR/server.pub
    else
        printf "%b\n" "${RED}${RLE}فایل کلید عمومی یافت نشد${PDF}${NC}"
    fi
}

check_ports() {
    printf "%b\n" "${YELLOW}${RLE}بررسی پورت‌های باز:${PDF}${NC}"
    netstat -tulpn | grep -E ":(5300|1080)" || ss -tulpn | grep -E ":(5300|1080)"
}

check_iptables() {
    printf "%b\n" "${YELLOW}${RLE}قوانین iptables:${PDF}${NC}"
    iptables -t nat -L -n -v
    echo ""
    printf "%b\n" "${YELLOW}${RLE}قوانین INPUT:${PDF}${NC}"
    iptables -L INPUT -n -v
}

while true; do
    show_menu
    printf "%b" "${RLE}گزینه را انتخاب کنید: ${PDF}"
read choice
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
            printf "%b\n" "${RLE}خروج...${PDF}"
            exit 0
            ;;
        *)
            printf "%b\n" "${RED}${RLE}گزینه نامعتبر${PDF}${NC}"
            ;;
    esac
    
    echo ""
    read -p "${RLE}برای ادامه Enter را فشار دهید...${PDF}"
    clear
done

