#!/bin/bash

# تنظیمات RTL برای نمایش صحیح فارسی
export LC_ALL=C.UTF-8
export LANG=C.UTF-8

# کاراکترهای کنترل Unicode برای RTL
RLE=$'\u202B'  # Right-to-Left Embedding
PDF=$'\u202C'  # Pop Directional Formatting

# رنگ‌ها برای خروجی
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# تابع برای نمایش متن فارسی
print_fa() {
    echo -e "${RLE}${1}${PDF}"
}

# بررسی root بودن
if [ "$EUID" -ne 0 ]; then 
    echo -e "${RED}${RLE}لطفا با دسترسی root اجرا کنید${PDF}${NC}"
    exit 1
fi

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}${RLE}  نصب و راه‌اندازی DNSTT Tunnel${PDF}${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""

# دریافت اطلاعات از کاربر
read -p "${RLE}دامنه شما (مثال: tunnel.example.com): ${PDF}" DOMAIN
if [ -z "$DOMAIN" ]; then
    echo -e "${RED}${RLE}دامنه نمی‌تواند خالی باشد${PDF}${NC}"
    exit 1
fi

read -p "${RLE}DNS resolver برای DoH (مثال: https://doh.cloudflare.com/dns-query): ${PDF}" DOH_URL
if [ -z "$DOH_URL" ]; then
    DOH_URL="https://doh.cloudflare.com/dns-query"
    echo -e "${YELLOW}${RLE}استفاده از DNS پیش‌فرض: $DOH_URL${PDF}${NC}"
fi

read -p "${RLE}IP سرور A (سرور دریافت کننده ترافیک از B - جایی که پراکسی تلگرام یا سایر اپ‌ها نصب است): ${PDF}" SERVER_A_IP
if [ -z "$SERVER_A_IP" ]; then
    echo -e "${RED}${RLE}IP سرور A نمی‌تواند خالی باشد${PDF}${NC}"
    exit 1
fi

read -p "${RLE}پورت پراکسی/اپلیکیشن روی سرور A (مثال: 1080): ${PDF}" PROXY_PORT
if [ -z "$PROXY_PORT" ]; then
    PROXY_PORT="1080"
    echo -e "${YELLOW}${RLE}استفاده از پورت پیش‌فرض: $PROXY_PORT${PDF}${NC}"
fi

read -p "${RLE}پورت محلی برای dnstt-server روی سرور B (سرور دریافت کننده ترافیک کاربران - مثال: 5300): ${PDF}" LOCAL_PORT
if [ -z "$LOCAL_PORT" ]; then
    LOCAL_PORT="5300"
    echo -e "${YELLOW}${RLE}استفاده از پورت پیش‌فرض: $LOCAL_PORT${PDF}${NC}"
fi

read -p "${RLE}پورت خروجی برای کاربران (مثال: 1080): ${PDF}" USER_PORT
if [ -z "$USER_PORT" ]; then
    USER_PORT="1080"
    echo -e "${YELLOW}${RLE}استفاده از پورت پیش‌فرض: $USER_PORT${PDF}${NC}"
fi

echo ""
echo -e "${GREEN}${RLE}خلاصه تنظیمات:${PDF}${NC}"
echo -e "${RLE}  دامنه: $DOMAIN${PDF}"
echo -e "${RLE}  DNS: $DOH_URL${PDF}"
echo -e "${RLE}  IP سرور A (مقصد نهایی): $SERVER_A_IP${PDF}"
echo -e "${RLE}  پورت پراکسی/اپلیکیشن روی سرور A: $PROXY_PORT${PDF}"
echo -e "${RLE}  پورت محلی dnstt روی سرور B: $LOCAL_PORT${PDF}"
echo -e "${RLE}  پورت خروجی برای کاربران: $USER_PORT${PDF}"
echo ""
read -p "${RLE}ادامه می‌دهید؟ (y/n): ${PDF}" CONFIRM
if [ "$CONFIRM" != "y" ] && [ "$CONFIRM" != "Y" ]; then
    echo -e "${RLE}لغو شد${PDF}"
    exit 1
fi

# نصب Go اگر نصب نباشد
if ! command -v go &> /dev/null; then
    echo -e "${YELLOW}${RLE}در حال نصب Go...${PDF}${NC}"
    apt-get update
    apt-get install -y golang-go
fi

# ایجاد دایرکتوری کار
WORK_DIR="/opt/dnstt"
mkdir -p $WORK_DIR

# بررسی مسیر اسکریپت برای فایل‌های کامپایل شده
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOCAL_DNSTT_SERVER="$SCRIPT_DIR/dnstt/dnstt-server/dnstt-server"
LOCAL_DNSTT_CLIENT="$SCRIPT_DIR/dnstt/dnstt-client/dnstt-client"

# بررسی وجود فایل‌های کامپایل شده محلی
if [ -f "$LOCAL_DNSTT_SERVER" ] && [ -f "$LOCAL_DNSTT_CLIENT" ]; then
    echo -e "${GREEN}${RLE}استفاده از فایل‌های کامپایل شده موجود...${PDF}${NC}"
    cp "$LOCAL_DNSTT_SERVER" $WORK_DIR/dnstt-server
    cp "$LOCAL_DNSTT_CLIENT" $WORK_DIR/dnstt-client
    chmod +x $WORK_DIR/dnstt-server $WORK_DIR/dnstt-client
    echo -e "${GREEN}${RLE}فایل‌ها کپی شدند${PDF}${NC}"
else
    echo -e "${YELLOW}${RLE}فایل‌های کامپایل شده یافت نشد. در حال دانلود و کامپایل...${PDF}${NC}"
    cd $WORK_DIR
    
    # دانلود و کامپایل dnstt
    if [ ! -d "dnstt" ]; then
        git clone https://github.com/Mygod/dnstt.git
    fi
    
    cd dnstt/plugin
    
    echo -e "${YELLOW}${RLE}در حال کامپایل dnstt-server...${PDF}${NC}"
    go build -o $WORK_DIR/dnstt-server ./dnstt-server
    
    echo -e "${YELLOW}${RLE}در حال کامپایل dnstt-client...${PDF}${NC}"
    go build -o $WORK_DIR/dnstt-client ./dnstt-client
fi

# تولید کلیدها
echo -e "${YELLOW}${RLE}در حال تولید کلیدها...${PDF}${NC}"
$WORK_DIR/dnstt-server -gen-key -privkey-file $WORK_DIR/server.key -pubkey-file $WORK_DIR/server.pub

# خواندن کلید عمومی
PUBKEY=$(cat $WORK_DIR/server.pub | grep "pubkey" | awk '{print $2}')

# ایجاد فایل systemd service برای dnstt-server
echo -e "${YELLOW}${RLE}در حال ایجاد سرویس systemd...${PDF}${NC}"
cat > /etc/systemd/system/dnstt-server.service << EOF
[Unit]
Description=DNSTT Server
After=network.target

[Service]
Type=simple
User=root
WorkingDirectory=$WORK_DIR
ExecStart=$WORK_DIR/dnstt-server -udp :$LOCAL_PORT -privkey-file $WORK_DIR/server.key $DOMAIN $SERVER_A_IP:$PROXY_PORT
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF

# فعال‌سازی و راه‌اندازی سرویس
systemctl daemon-reload
systemctl enable dnstt-server
systemctl restart dnstt-server

# تنظیم iptables برای فایروال و ریدایرکت
echo -e "${YELLOW}${RLE}در حال تنظیم iptables...${PDF}${NC}"

# نصب iptables-persistent اگر نصب نباشد
if ! command -v iptables-save &> /dev/null; then
    apt-get install -y iptables-persistent
fi

# اجازه UDP برای پورت dnstt-server
iptables -I INPUT -p udp --dport $LOCAL_PORT -j ACCEPT

# اگر نیاز به ریدایرکت پورت دیگری به پورت dnstt دارید، این خط را فعال کنید:
# iptables -t nat -A PREROUTING -p udp --dport $USER_PORT -j REDIRECT --to-port $LOCAL_PORT

# ذخیره قوانین iptables
mkdir -p /etc/iptables
iptables-save > /etc/iptables/rules.v4

# برای سیستم‌های با netfilter-persistent
if command -v netfilter-persistent &> /dev/null; then
    netfilter-persistent save
fi

# ایجاد اسکریپت client برای کاربران
cat > $WORK_DIR/client_setup.sh << 'CLIENT_EOF'
#!/bin/bash

# دریافت اطلاعات از کاربر
read -p "دامنه: " DOMAIN
read -p "DNS resolver (DoH): " DOH_URL
read -p "مسیر فایل کلید عمومی (server.pub): " PUBKEY_FILE
read -p "پورت محلی برای اتصال (مثال: 1080): " LOCAL_PORT

if [ -z "$DOMAIN" ] || [ -z "$DOH_URL" ] || [ -z "$PUBKEY_FILE" ] || [ -z "$LOCAL_PORT" ]; then
    echo "همه فیلدها الزامی هستند"
    exit 1
fi

# دانلود و کامپایل dnstt-client
WORK_DIR="$HOME/dnstt-client"
mkdir -p $WORK_DIR
cd $WORK_DIR

if [ ! -d "dnstt" ]; then
    git clone https://github.com/Mygod/dnstt.git
fi

cd dnstt/plugin
go build -o dnstt-client ./dnstt-client

# اجرای client
echo "در حال اتصال..."
./dnstt-client -doh "$DOH_URL" -pubkey-file "$PUBKEY_FILE" "$DOMAIN" "127.0.0.1:$LOCAL_PORT"
CLIENT_EOF

chmod +x $WORK_DIR/client_setup.sh

# ایجاد فایل اطلاعات
cat > $WORK_DIR/info.txt << EOF
========================================
  اطلاعات اتصال DNSTT
========================================

دامنه: $DOMAIN
DNS: $DOH_URL
IP سرور A (مقصد نهایی): $SERVER_A_IP
پورت پراکسی/اپلیکیشن روی سرور A: $PROXY_PORT

توضیح:
- سرور B: سرور دریافت کننده ترافیک کاربران (جایی که این اسکریپت اجرا می‌شود)
- سرور A: سرور دریافت کننده ترافیک از B (جایی که پراکسی تلگرام یا سایر اپ‌ها نصب است)

کلید عمومی (PUBKEY):
$PUBKEY

فایل کلید عمومی: $WORK_DIR/server.pub

مسیر باینری‌ها (server و client در همان پوشه):
$WORK_DIR/dnstt-server
$WORK_DIR/dnstt-client

========================================
  دستورات برای کاربران:
========================================

1. فایل server.pub را از سرور B دانلود کنید:
   scp root@SERVER_B_IP:$WORK_DIR/server.pub ./

2. روی سیستم کاربر، dnstt-client را نصب و اجرا کنید:
   $WORK_DIR/client_setup.sh

   یا به صورت دستی:
   ./dnstt-client -doh "$DOH_URL" -pubkey-file ./server.pub $DOMAIN 127.0.0.1:$USER_PORT

3. در تنظیمات تلگرام، از SOCKS5 proxy استفاده کنید:
   Host: 127.0.0.1
   Port: $USER_PORT

========================================
  دستورات مدیریت:
========================================

مشاهده وضعیت سرویس:
systemctl status dnstt-server

مشاهده لاگ‌ها:
journalctl -u dnstt-server -f

راه‌اندازی مجدد:
systemctl restart dnstt-server

توقف:
systemctl stop dnstt-server

========================================
EOF

echo ""
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}${RLE}  نصب با موفقیت انجام شد!${PDF}${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""
echo -e "${YELLOW}${RLE}اطلاعات کامل در فایل زیر ذخیره شده:${PDF}${NC}"
echo "$WORK_DIR/info.txt"
echo ""
echo -e "${YELLOW}${RLE}کلید عمومی:${PDF}${NC}"
echo "$PUBKEY"
echo ""
echo -e "${YELLOW}${RLE}وضعیت سرویس:${PDF}${NC}"
systemctl status dnstt-server --no-pager -l
echo ""
echo -e "${GREEN}${RLE}برای مشاهده لاگ‌ها: journalctl -u dnstt-server -f${PDF}${NC}"

