#!/bin/bash

# رنگ‌ها برای خروجی
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# بررسی root بودن
if [ "$EUID" -ne 0 ]; then 
    echo -e "${RED}لطفا با دسترسی root اجرا کنید${NC}"
    exit 1
fi

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}  نصب و راه‌اندازی DNSTT Tunnel${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""

# دریافت اطلاعات از کاربر
read -p "دامنه شما (مثال: tunnel.example.com): " DOMAIN
if [ -z "$DOMAIN" ]; then
    echo -e "${RED}دامنه نمی‌تواند خالی باشد${NC}"
    exit 1
fi

read -p "DNS resolver برای DoH (مثال: https://doh.cloudflare.com/dns-query): " DOH_URL
if [ -z "$DOH_URL" ]; then
    DOH_URL="https://doh.cloudflare.com/dns-query"
    echo -e "${YELLOW}استفاده از DNS پیش‌فرض: $DOH_URL${NC}"
fi

read -p "IP سرور A (جایی که پراکسی تلگرام نصب است): " SERVER_A_IP
if [ -z "$SERVER_A_IP" ]; then
    echo -e "${RED}IP سرور A نمی‌تواند خالی باشد${NC}"
    exit 1
fi

read -p "پورت پراکسی تلگرام روی سرور A (مثال: 1080): " PROXY_PORT
if [ -z "$PROXY_PORT" ]; then
    PROXY_PORT="1080"
    echo -e "${YELLOW}استفاده از پورت پیش‌فرض: $PROXY_PORT${NC}"
fi

read -p "پورت محلی برای dnstt-server روی سرور B (مثال: 5300): " LOCAL_PORT
if [ -z "$LOCAL_PORT" ]; then
    LOCAL_PORT="5300"
    echo -e "${YELLOW}استفاده از پورت پیش‌فرض: $LOCAL_PORT${NC}"
fi

read -p "پورت خروجی برای کاربران (مثال: 1080): " USER_PORT
if [ -z "$USER_PORT" ]; then
    USER_PORT="1080"
    echo -e "${YELLOW}استفاده از پورت پیش‌فرض: $USER_PORT${NC}"
fi

echo ""
echo -e "${GREEN}خلاصه تنظیمات:${NC}"
echo "  دامنه: $DOMAIN"
echo "  DNS: $DOH_URL"
echo "  IP سرور A: $SERVER_A_IP"
echo "  پورت پراکسی: $PROXY_PORT"
echo "  پورت محلی dnstt: $LOCAL_PORT"
echo "  پورت کاربران: $USER_PORT"
echo ""
read -p "ادامه می‌دهید؟ (y/n): " CONFIRM
if [ "$CONFIRM" != "y" ] && [ "$CONFIRM" != "Y" ]; then
    echo "لغو شد"
    exit 1
fi

# نصب Go اگر نصب نباشد
if ! command -v go &> /dev/null; then
    echo -e "${YELLOW}در حال نصب Go...${NC}"
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
    echo -e "${GREEN}استفاده از فایل‌های کامپایل شده موجود...${NC}"
    cp "$LOCAL_DNSTT_SERVER" $WORK_DIR/dnstt-server
    cp "$LOCAL_DNSTT_CLIENT" $WORK_DIR/dnstt-client
    chmod +x $WORK_DIR/dnstt-server $WORK_DIR/dnstt-client
    echo -e "${GREEN}فایل‌ها کپی شدند${NC}"
else
    echo -e "${YELLOW}فایل‌های کامپایل شده یافت نشد. در حال دانلود و کامپایل...${NC}"
    cd $WORK_DIR
    
    # دانلود و کامپایل dnstt
    if [ ! -d "dnstt" ]; then
        git clone https://github.com/Mygod/dnstt.git
    fi
    
    cd dnstt/plugin
    
    echo -e "${YELLOW}در حال کامپایل dnstt-server...${NC}"
    go build -o $WORK_DIR/dnstt-server ./dnstt-server
    
    echo -e "${YELLOW}در حال کامپایل dnstt-client...${NC}"
    go build -o $WORK_DIR/dnstt-client ./dnstt-client
fi

# تولید کلیدها
echo -e "${YELLOW}در حال تولید کلیدها...${NC}"
$WORK_DIR/dnstt-server -gen-key -privkey-file $WORK_DIR/server.key -pubkey-file $WORK_DIR/server.pub

# خواندن کلید عمومی
PUBKEY=$(cat $WORK_DIR/server.pub | grep "pubkey" | awk '{print $2}')

# ایجاد فایل systemd service برای dnstt-server
echo -e "${YELLOW}در حال ایجاد سرویس systemd...${NC}"
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
echo -e "${YELLOW}در حال تنظیم iptables...${NC}"

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
IP سرور A: $SERVER_A_IP
پورت پراکسی: $PROXY_PORT

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
echo -e "${GREEN}  نصب با موفقیت انجام شد!${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""
echo -e "${YELLOW}اطلاعات کامل در فایل زیر ذخیره شده:${NC}"
echo "$WORK_DIR/info.txt"
echo ""
echo -e "${YELLOW}کلید عمومی:${NC}"
echo "$PUBKEY"
echo ""
echo -e "${YELLOW}وضعیت سرویس:${NC}"
systemctl status dnstt-server --no-pager -l
echo ""
echo -e "${GREEN}برای مشاهده لاگ‌ها: journalctl -u dnstt-server -f${NC}"

