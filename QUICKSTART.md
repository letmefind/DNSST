# راهنمای سریع شروع

## روی سرور B (سرور تونل)

```bash
# 1. دانلود اسکریپت
wget https://raw.githubusercontent.com/your-repo/setup_dnstt.sh
chmod +x setup_dnstt.sh

# 2. اجرای اسکریپت
sudo ./setup_dnstt.sh
```

**اطلاعات مورد نیاز:**
- دامنه (مثال: `tunnel.example.com`)
- DNS resolver DoH (پیش‌فرض: `https://doh.cloudflare.com/dns-query`)
- IP سرور A (جایی که پراکسی تلگرام است)
- پورت پراکسی تلگرام (معمولا `1080`)
- پورت محلی dnstt (پیش‌فرض: `5300`)
- پورت کاربران (پیش‌فرض: `1080`)

**بعد از نصب:**
- فایل `server.pub` را از `/opt/dnstt/server.pub` کپی کنید
- این فایل را به کاربران بدهید

## تنظیم DNS

یک رکورد A برای دامنه خود ایجاد کنید:
```
Type: A
Name: tunnel.example.com
Value: IP_SERVER_B
TTL: 300
```

## برای کاربران

```bash
# 1. دانلود فایل کلید عمومی
scp root@SERVER_B_IP:/opt/dnstt/server.pub ./

# 2. دانلود و اجرای اسکریپت client
wget https://raw.githubusercontent.com/your-repo/client_connect.sh
chmod +x client_connect.sh
./client_connect.sh
```

**یا به صورت دستی:**
```bash
# نصب Go
sudo apt-get install golang-go

# دانلود و کامپایل
git clone https://github.com/Mygod/dnstt.git
cd dnstt/plugin
go build -o dnstt-client ./dnstt-client

# اجرا
./dnstt-client -doh https://doh.cloudflare.com/dns-query \
  -pubkey-file ./server.pub \
  tunnel.example.com \
  127.0.0.1:1080
```

## تنظیم تلگرام

1. Settings → Advanced → Connection type
2. Use proxy
3. Add proxy → SOCKS5
4. Host: `127.0.0.1`
5. Port: `1080` (یا پورتی که انتخاب کردید)

## مدیریت سرویس

```bash
# استفاده از منوی تعاملی
sudo ./manage.sh

# یا دستورات مستقیم
sudo systemctl status dnstt-server
sudo systemctl restart dnstt-server
sudo journalctl -u dnstt-server -f
```

## عیب‌یابی

```bash
# بررسی وضعیت
sudo systemctl status dnstt-server

# بررسی پورت
sudo netstat -tulpn | grep 5300

# بررسی لاگ‌ها
sudo journalctl -u dnstt-server -n 50
```

