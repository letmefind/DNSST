#!/bin/bash
# سرور B (خارج) — ترافیک دریافتی از کاربران روی A را دریافت می‌کند.
# فقط DNSTT Server اجرا می‌شود و ترافیک را به 127.0.0.1:پورت تحویل می‌دهد
# (MTProxy یا هر سرویس دیگر روی همین سرور). پورت از کاربر پرسیده می‌شود.

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

if [ "$EUID" -ne 0 ]; then
    echo -e "${RED}با دستور root یا sudo اجرا کنید.${NC}"
    exit 1
fi

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}  سرور B (خارج) — نصب DNSTT Server${NC}"
echo -e "${BLUE}  ترافیک تونل به 127.0.0.1:پورت (MTProxy یا سرویس دیگر) تحویل داده می‌شود.${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""

# دامنه (از آرگومان یا سوال)
DOMAIN="$1"
if [ -z "$DOMAIN" ]; then
    read -p "دامنه DNS (مثال: tunnel.example.com): " DOMAIN
fi
if [ -z "$DOMAIN" ]; then
    echo -e "${RED}دامنه نمی‌تواند خالی باشد.${NC}"
    exit 1
fi

# پورت سرویس مقصد روی همین سرور (127.0.0.1) — MTProxy یا هر سرویس دیگر
DEST_PORT="$2"
if [ -z "$DEST_PORT" ]; then
    read -p "پورت سرویس مقصد روی این سرور (127.0.0.1) — مثلاً MTProxy یا پراکسی دیگر (پیش‌فرض 1080): " DEST_PORT
fi
if [ -z "$DEST_PORT" ]; then
    DEST_PORT="1080"
    echo -e "${YELLOW}پیش‌فرض: $DEST_PORT${NC}"
fi

# مقصد همیشه لوکال
TARGET="127.0.0.1:$DEST_PORT"
LOCAL_PORT="5300"
MTU_VALUE="1232"

echo -e "${GREEN}تنظیمات: دامنه=$DOMAIN، مقصد=$TARGET، پورت DNSTT=$LOCAL_PORT${NC}"
echo ""

WORK_DIR="/opt/dnstt"
mkdir -p "$WORK_DIR"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

REPO_BINARIES_SERVER="$SCRIPT_DIR/binaries/dnstt-server"
REPO_BINARIES_CLIENT="$SCRIPT_DIR/binaries/dnstt-client"
LOCAL_DNSTT_SERVER="$SCRIPT_DIR/dnstt/dnstt-server/dnstt-server"
LOCAL_DNSTT_CLIENT="$SCRIPT_DIR/dnstt/dnstt-client/dnstt-client"

if [ -f "$REPO_BINARIES_SERVER" ] && [ -f "$REPO_BINARIES_CLIENT" ]; then
    echo -e "${GREEN}استفاده از باینری‌های مخزن...${NC}"
    cp "$REPO_BINARIES_SERVER" "$WORK_DIR/dnstt-server"
    cp "$REPO_BINARIES_CLIENT" "$WORK_DIR/dnstt-client"
    chmod +x "$WORK_DIR/dnstt-server" "$WORK_DIR/dnstt-client"
elif [ -f "$LOCAL_DNSTT_SERVER" ] && [ -f "$LOCAL_DNSTT_CLIENT" ]; then
    echo -e "${GREEN}استفاده از باینری‌های محلی...${NC}"
    cp "$LOCAL_DNSTT_SERVER" "$WORK_DIR/dnstt-server"
    cp "$LOCAL_DNSTT_CLIENT" "$WORK_DIR/dnstt-client"
    chmod +x "$WORK_DIR/dnstt-server" "$WORK_DIR/dnstt-client"
else
    echo -e "${YELLOW}باینری یافت نشد؛ در حال کامپایل...${NC}"
    command -v go &>/dev/null || apt-get update && apt-get install -y golang-go
    cd "$WORK_DIR" || exit 1
    [ ! -d "dnstt" ] && git clone https://github.com/Mygod/dnstt.git
    cd dnstt/plugin || exit 1
    go build -o "$WORK_DIR/dnstt-server" ./dnstt-server
    go build -o "$WORK_DIR/dnstt-client" ./dnstt-client
fi

echo -e "${YELLOW}در حال تولید کلید...${NC}"
"$WORK_DIR/dnstt-server" -gen-key -privkey-file "$WORK_DIR/server.key" -pubkey-file "$WORK_DIR/server.pub"
PUBKEY=$(grep "pubkey" "$WORK_DIR/server.pub" | awk '{print $2}')

echo -e "${YELLOW}در حال ایجاد سرویس systemd...${NC}"
cat > /etc/systemd/system/dnstt-server.service << EOF
[Unit]
Description=DNSTT Server
After=network.target

[Service]
Type=simple
User=root
WorkingDirectory=$WORK_DIR
ExecStart=$WORK_DIR/dnstt-server -udp :$LOCAL_PORT -mtu $MTU_VALUE -privkey-file $WORK_DIR/server.key $DOMAIN $TARGET
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable dnstt-server

if [ "$LOCAL_PORT" = "53" ]; then
    systemctl stop systemd-resolved 2>/dev/null; systemctl disable systemd-resolved 2>/dev/null
    systemctl stop dnsmasq 2>/dev/null; systemctl disable dnsmasq 2>/dev/null
    systemctl stop bind9 2>/dev/null; systemctl disable bind9 2>/dev/null
    systemctl stop named 2>/dev/null; systemctl disable named 2>/dev/null
    pkill -9 -f dnstt-server 2>/dev/null
    pkill -9 systemd-resolved 2>/dev/null
    pkill -9 dnsmasq 2>/dev/null
    pkill -9 named 2>/dev/null
    sleep 2
    [ -x "$(command -v fuser)" ] && fuser -k 53/udp 2>/dev/null
    [ ! -f /etc/resolv.conf.backup ] && cp /etc/resolv.conf /etc/resolv.conf.backup
    cat > /etc/resolv.conf << 'R'
nameserver 8.8.8.8
nameserver 1.1.1.1
nameserver 8.8.4.4
R
    chattr +i /etc/resolv.conf 2>/dev/null || true
fi

systemctl restart dnstt-server

echo -e "${YELLOW}تنظیم iptables...${NC}"
command -v iptables-save &>/dev/null || apt-get install -y iptables-persistent
iptables -I INPUT -p udp --dport "$LOCAL_PORT" -j ACCEPT 2>/dev/null || true
mkdir -p /etc/iptables
iptables-save > /etc/iptables/rules.v4 2>/dev/null || true
command -v netfilter-persistent &>/dev/null && netfilter-persistent save 2>/dev/null || true

cat > "$WORK_DIR/info.txt" << EOF
========================================
  اطلاعات اتصال DNSTT (سرور B)
========================================
دامنه: $DOMAIN
مقصد ترافیک روی این سرور: $TARGET

کلید عمومی (برای نصب روی سرور A حتماً ذخیره کنید):
$PUBKEY
========================================
EOF

echo ""
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}  نصب سرور B (خارج) با موفقیت انجام شد.${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""
echo -e "${BLUE}کلید عمومی (برای نصب dnstt-client روی سرور A حتماً ذخیره کنید):${NC}"
echo -e "${GREEN}$PUBKEY${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""
echo -e "${YELLOW}ترافیک تونل به $TARGET تحویل داده می‌شود. مطمئن شوید سرویس (مثلاً MTProxy) روی این پورت در حال اجرا است.${NC}"
echo -e "${YELLOW}اطلاعات کامل: $WORK_DIR/info.txt${NC}"
echo -e "${YELLOW}وضعیت سرویس: systemctl status dnstt-server${NC}"
systemctl status dnstt-server --no-pager -l 2>/dev/null || true
