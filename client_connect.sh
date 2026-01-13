#!/bin/bash

# اسکریپت اتصال کاربر به DNSTT Tunnel

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}  اتصال به DNSTT Tunnel${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""

# بررسی وجود Go
if ! command -v go &> /dev/null; then
    echo -e "${YELLOW}Go نصب نیست. در حال نصب...${NC}"
    if [[ "$OSTYPE" == "linux-gnu"* ]]; then
        if command -v apt-get &> /dev/null; then
            sudo apt-get update
            sudo apt-get install -y golang-go
        elif command -v yum &> /dev/null; then
            sudo yum install -y golang
        else
            echo -e "${RED}لطفا Go را به صورت دستی نصب کنید${NC}"
            exit 1
        fi
    elif [[ "$OSTYPE" == "darwin"* ]]; then
        if command -v brew &> /dev/null; then
            brew install go
        else
            echo -e "${RED}لطفا Go را به صورت دستی نصب کنید${NC}"
            exit 1
        fi
    fi
fi

# دریافت اطلاعات
read -p "دامنه (مثال: tunnel.example.com): " DOMAIN
if [ -z "$DOMAIN" ]; then
    echo -e "${RED}دامنه نمی‌تواند خالی باشد${NC}"
    exit 1
fi

read -p "DNS resolver DoH (پیش‌فرض: https://doh.cloudflare.com/dns-query): " DOH_URL
if [ -z "$DOH_URL" ]; then
    DOH_URL="https://doh.cloudflare.com/dns-query"
fi

read -p "مسیر فایل کلید عمومی server.pub: " PUBKEY_FILE
if [ -z "$PUBKEY_FILE" ]; then
    PUBKEY_FILE="./server.pub"
fi

if [ ! -f "$PUBKEY_FILE" ]; then
    echo -e "${RED}فایل کلید عمومی یافت نشد: $PUBKEY_FILE${NC}"
    exit 1
fi

read -p "پورت محلی برای اتصال (پیش‌فرض: 1080): " LOCAL_PORT
if [ -z "$LOCAL_PORT" ]; then
    LOCAL_PORT="1080"
fi

# ایجاد دایرکتوری کار
WORK_DIR="$HOME/dnstt-client"
mkdir -p $WORK_DIR

# بررسی مسیر اسکریپت برای فایل کامپایل شده
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOCAL_DNSTT_CLIENT="$SCRIPT_DIR/dnstt/dnstt-client/dnstt-client"

# بررسی وجود فایل کامپایل شده محلی
if [ -f "$LOCAL_DNSTT_CLIENT" ]; then
    echo -e "${GREEN}استفاده از فایل کامپایل شده موجود...${NC}"
    cp "$LOCAL_DNSTT_CLIENT" $WORK_DIR/dnstt-client
    chmod +x $WORK_DIR/dnstt-client
    echo -e "${GREEN}فایل کپی شد${NC}"
else
    echo -e "${YELLOW}فایل کامپایل شده یافت نشد. در حال دانلود و کامپایل...${NC}"
    cd $WORK_DIR
    
    # دانلود و کامپایل
    if [ ! -d "dnstt" ]; then
        echo -e "${YELLOW}در حال دانلود dnstt...${NC}"
        git clone https://github.com/Mygod/dnstt.git
    fi
    
    cd dnstt/plugin
    
    # کامپایل مستقیم به دایرکتوری کار
    if [ ! -f "$WORK_DIR/dnstt-client" ]; then
        echo -e "${YELLOW}در حال کامپایل dnstt-client...${NC}"
        go build -o $WORK_DIR/dnstt-client ./dnstt-client
    fi
fi

echo ""
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}  در حال اتصال...${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""
echo -e "${YELLOW}تنظیمات:${NC}"
echo "  دامنه: $DOMAIN"
echo "  DNS: $DOH_URL"
echo "  پورت محلی: $LOCAL_PORT"
echo ""
echo -e "${YELLOW}در تنظیمات تلگرام از این تنظیمات استفاده کنید:${NC}"
echo "  نوع: SOCKS5"
echo "  Host: 127.0.0.1"
echo "  Port: $LOCAL_PORT"
echo ""
echo -e "${YELLOW}برای توقف، Ctrl+C را فشار دهید${NC}"
echo ""

# اجرای client از دایرکتوری کار (همان پوشه server)
cd $WORK_DIR
./dnstt-client -doh "$DOH_URL" -pubkey-file "$PUBKEY_FILE" "$DOMAIN" "127.0.0.1:$LOCAL_PORT"

