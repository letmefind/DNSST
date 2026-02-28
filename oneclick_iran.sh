#!/bin/bash
# سرور A (ایران) — جایی که ترافیک کاربران دریافت می‌شود.
# روی این سرور فقط DNSTT Client اجرا می‌شود: ترافیک کاربران را می‌گیرد و از طریق تونل به سرور B (خارج) می‌فرستد.

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
echo -e "${BLUE}  سرور A (ایران) — نصب DNSTT Client${NC}"
echo -e "${BLUE}  ترافیک کاربران اینجا دریافت و به سرور B (خارج) فرستاده می‌شود.${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""

# ورودی‌ها: دامنه، کلید عمومی (از سرور B)، پورت گوش دادن برای کاربران
DOMAIN="$1"
PUBKEY_STRING="$2"
USER_PORT="${3:-1080}"

if [ -z "$DOMAIN" ]; then
    read -p "دامنه DNS (همان دامنهٔ تنظیم‌شده روی سرور B): " DOMAIN
fi
if [ -z "$DOMAIN" ]; then
    echo -e "${RED}دامنه نمی‌تواند خالی باشد.${NC}"
    exit 1
fi

if [ -z "$PUBKEY_STRING" ]; then
    echo -e "${YELLOW}کلید عمومی را از نصب سرور B کپی کنید (مثال: pubkey:xxxx...).${NC}"
    read -p "کلید عمومی (Public Key): " PUBKEY_STRING
fi
if [ -z "$PUBKEY_STRING" ]; then
    echo -e "${RED}کلید عمومی نمی‌تواند خالی باشد.${NC}"
    exit 1
fi

if [ -z "$3" ]; then
    read -p "پورتی که کاربران به آن وصل شوند روی این سرور (پیش‌فرض 1080): " INPUT_PORT
    USER_PORT="${INPUT_PORT:-1080}"
fi

# گوش دادن روی همه اینترفیس‌ها تا کاربران بتوانند به IP این سرور وصل شوند
LISTEN_ADDR="0.0.0.0:$USER_PORT"
DNS_METHOD="doh"
DNS_URL="https://doh.cloudflare.com/dns-query"

WORK_DIR="/opt/dnstt"
mkdir -p "$WORK_DIR"
PUBKEY_FILE="$WORK_DIR/server.pub"
echo "$PUBKEY_STRING" > "$PUBKEY_FILE"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_BINARIES_CLIENT="$SCRIPT_DIR/binaries/dnstt-client"
LOCAL_DNSTT_CLIENT="$SCRIPT_DIR/dnstt/dnstt-client/dnstt-client"

if [ -f "$REPO_BINARIES_CLIENT" ]; then
    echo -e "${GREEN}استفاده از باینری مخزن...${NC}"
    cp "$REPO_BINARIES_CLIENT" "$WORK_DIR/dnstt-client"
    chmod +x "$WORK_DIR/dnstt-client"
elif [ -f "$LOCAL_DNSTT_CLIENT" ]; then
    echo -e "${GREEN}استفاده از باینری محلی...${NC}"
    cp "$LOCAL_DNSTT_CLIENT" "$WORK_DIR/dnstt-client"
    chmod +x "$WORK_DIR/dnstt-client"
else
    echo -e "${YELLOW}باینری یافت نشد؛ در حال کامپایل...${NC}"
    command -v go &>/dev/null || apt-get update && apt-get install -y golang-go
    cd "$WORK_DIR" || exit 1
    [ ! -d "dnstt" ] && git clone https://github.com/Mygod/dnstt.git
    cd dnstt/plugin || exit 1
    go build -o "$WORK_DIR/dnstt-client" ./dnstt-client
    chmod +x "$WORK_DIR/dnstt-client"
    cd "$WORK_DIR" || exit 1
fi

# سرویس: کلاینت با DoH، گوش دادن روی 0.0.0.0:USER_PORT
CLIENT_CMD="$WORK_DIR/dnstt-client -doh $DNS_URL -pubkey-file $PUBKEY_FILE $DOMAIN $LISTEN_ADDR"

echo -e "${YELLOW}در حال ایجاد سرویس systemd...${NC}"
cat > /etc/systemd/system/dnstt-client.service << EOF
[Unit]
Description=DNSTT Client (سرور A - دریافت ترافیک کاربران و ارسال به B)
After=network.target

[Service]
Type=simple
User=root
WorkingDirectory=$WORK_DIR
ExecStart=$CLIENT_CMD
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable dnstt-client
systemctl restart dnstt-client

# فایروال
echo -e "${YELLOW}باز کردن پورت $USER_PORT برای اتصال کاربران...${NC}"
if command -v ufw &>/dev/null; then
    ufw allow "$USER_PORT"/tcp 2>/dev/null
    ufw allow "$USER_PORT"/udp 2>/dev/null
    echo "y" | ufw reload 2>/dev/null || true
fi
iptables -I INPUT -p tcp --dport "$USER_PORT" -j ACCEPT 2>/dev/null
iptables -I INPUT -p udp --dport "$USER_PORT" -j ACCEPT 2>/dev/null
mkdir -p /etc/iptables
iptables-save > /etc/iptables/rules.v4 2>/dev/null || true

SERVER_A_IP=$(curl -sL --max-time 5 icanhazip.com 2>/dev/null || curl -sL --max-time 5 ifconfig.me 2>/dev/null || echo "IP_سرور_A")

echo ""
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}  نصب سرور A (ایران) با موفقیت انجام شد.${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""
echo -e "${YELLOW}کاربران برای اتصال از این تنظیمات استفاده کنند:${NC}"
echo -e "  نوع: SOCKS5"
echo -e "  Host: ${GREEN}$SERVER_A_IP${NC} (یا دامنهٔ این سرور)"
echo -e "  Port: ${GREEN}$USER_PORT${NC}"
echo ""
echo -e "${YELLOW}ترافیک از کاربران به این سرور (A) می‌آید و از طریق تونل به سرور B فرستاده می‌شود.${NC}"
echo -e "${YELLOW}وضعیت سرویس: systemctl status dnstt-client${NC}"
systemctl status dnstt-client --no-pager -l 2>/dev/null || true
