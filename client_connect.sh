#!/bin/bash

# تنظیمات RTL برای نمایش صحیح فارسی
export LC_ALL=C.UTF-8
export LANG=C.UTF-8

# کاراکترهای کنترل Unicode برای RTL
RLE=$'\u202B'  # Right-to-Left Embedding
PDF=$'\u202C'  # Pop Directional Formatting

# اسکریپت اتصال کاربر به DNSTT Tunnel

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}${RLE}  اتصال به DNSTT Tunnel${PDF}${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""

# بررسی وجود Go
if ! command -v go &> /dev/null; then
    echo -e "${YELLOW}${RLE}Go نصب نیست. در حال نصب...${PDF}${NC}"
    if [[ "$OSTYPE" == "linux-gnu"* ]]; then
        if command -v apt-get &> /dev/null; then
            sudo apt-get update
            sudo apt-get install -y golang-go
        elif command -v yum &> /dev/null; then
            sudo yum install -y golang
        else
            echo -e "${RED}${RLE}لطفا Go را به صورت دستی نصب کنید${PDF}${NC}"
            exit 1
        fi
    elif [[ "$OSTYPE" == "darwin"* ]]; then
        if command -v brew &> /dev/null; then
            brew install go
        else
            echo -e "${RED}${RLE}لطفا Go را به صورت دستی نصب کنید${PDF}${NC}"
            exit 1
        fi
    fi
fi

# دریافت اطلاعات
read -p "${RLE}دامنه (مثال: tunnel.example.com): ${PDF}" DOMAIN
if [ -z "$DOMAIN" ]; then
    echo -e "${RED}${RLE}دامنه نمی‌تواند خالی باشد${PDF}${NC}"
    exit 1
fi

read -p "${RLE}DNS resolver DoH (پیش‌فرض: https://doh.cloudflare.com/dns-query): ${PDF}" DOH_URL
if [ -z "$DOH_URL" ]; then
    DOH_URL="https://doh.cloudflare.com/dns-query"
fi

read -p "${RLE}مسیر فایل کلید عمومی server.pub: ${PDF}" PUBKEY_FILE
if [ -z "$PUBKEY_FILE" ]; then
    PUBKEY_FILE="./server.pub"
fi

if [ ! -f "$PUBKEY_FILE" ]; then
    echo -e "${RED}${RLE}فایل کلید عمومی یافت نشد: $PUBKEY_FILE${PDF}${NC}"
    exit 1
fi

read -p "${RLE}پورت محلی برای اتصال (پیش‌فرض: 1080): ${PDF}" LOCAL_PORT
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
    echo -e "${GREEN}${RLE}استفاده از فایل کامپایل شده موجود...${PDF}${NC}"
    cp "$LOCAL_DNSTT_CLIENT" $WORK_DIR/dnstt-client
    chmod +x $WORK_DIR/dnstt-client
    echo -e "${GREEN}${RLE}فایل کپی شد${PDF}${NC}"
else
    echo -e "${YELLOW}${RLE}فایل کامپایل شده یافت نشد. در حال دانلود و کامپایل...${PDF}${NC}"
    cd $WORK_DIR
    
    # دانلود و کامپایل
    if [ ! -d "dnstt" ]; then
        echo -e "${YELLOW}${RLE}در حال دانلود dnstt...${PDF}${NC}"
        git clone https://github.com/Mygod/dnstt.git
    fi
    
    cd dnstt/plugin
    
    # کامپایل مستقیم به دایرکتوری کار
    if [ ! -f "$WORK_DIR/dnstt-client" ]; then
        echo -e "${YELLOW}${RLE}در حال کامپایل dnstt-client...${PDF}${NC}"
        go build -o $WORK_DIR/dnstt-client ./dnstt-client
    fi
fi

echo ""
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}${RLE}  در حال اتصال...${PDF}${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""
echo -e "${YELLOW}${RLE}تنظیمات:${PDF}${NC}"
echo -e "${RLE}  دامنه: $DOMAIN${PDF}"
echo -e "${RLE}  DNS: $DOH_URL${PDF}"
echo -e "${RLE}  پورت محلی: $LOCAL_PORT${PDF}"
echo ""
echo -e "${YELLOW}${RLE}در تنظیمات تلگرام از این تنظیمات استفاده کنید:${PDF}${NC}"
echo -e "${RLE}  نوع: SOCKS5${PDF}"
echo -e "${RLE}  Host: 127.0.0.1${PDF}"
echo -e "${RLE}  Port: $LOCAL_PORT${PDF}"
echo ""
echo -e "${YELLOW}${RLE}برای توقف، Ctrl+C را فشار دهید${PDF}${NC}"
echo ""

# اجرای client از دایرکتوری کار (همان پوشه server)
cd $WORK_DIR
./dnstt-client -doh "$DOH_URL" -pubkey-file "$PUBKEY_FILE" "$DOMAIN" "127.0.0.1:$LOCAL_PORT"

