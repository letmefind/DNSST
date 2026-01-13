# راه‌اندازی DNSTT Tunnel برای پراکسی تلگرام

این اسکریپت برای راه‌اندازی یک تونل DNS بین سرور B و کاربران استفاده می‌شود تا ترافیک از طریق DNS به سرور A (که پراکسی تلگرام روی آن نصب است) منتقل شود.

## ⚡ نصب سریع

```bash
git clone https://github.com/letmefind/DNSST.git
cd DNSST
chmod +x setup_dnstt.sh
sudo ./setup_dnstt.sh
```

## معماری

```
کاربران → [dnstt-client] → DNS Tunnel → [سرور B: dnstt-server] → [سرور A: پراکسی تلگرام]
```

## پیش‌نیازها

- سرور B با دسترسی root
- سرور A با پراکسی تلگرام نصب شده
- دامنه معتبر که به سرور B اشاره می‌کند
- DNS resolver که از DoH پشتیبانی می‌کند

## نصب روی سرور B

1. اسکریپت را دانلود کنید:
```bash
wget https://raw.githubusercontent.com/your-repo/setup_dnstt.sh
chmod +x setup_dnstt.sh
```

2. اسکریپت را اجرا کنید:
```bash
sudo ./setup_dnstt.sh
```

3. اطلاعات خواسته شده را وارد کنید:
   - دامنه (مثال: tunnel.example.com)
   - DNS resolver (DoH URL)
   - IP سرور A
   - پورت پراکسی تلگرام
   - پورت‌های مورد نیاز

## تنظیم DNS

باید یک رکورد DNS برای دامنه خود ایجاد کنید که به IP سرور B اشاره کند:

```
Type: A
Name: tunnel.example.com
Value: IP_SERVER_B
TTL: 300
```

## استفاده برای کاربران

### روش ساده (استفاده از اسکریپت)

1. فایل `server.pub` را از سرور B دانلود کنید:
```bash
scp root@SERVER_B_IP:/opt/dnstt/server.pub ./
```

2. اسکریپت `client_connect.sh` را دانلود و اجرا کنید:
```bash
chmod +x client_connect.sh
./client_connect.sh
```

3. اطلاعات خواسته شده را وارد کنید و اسکریپت به صورت خودکار اتصال را برقرار می‌کند.

4. در تلگرام، تنظیمات Proxy را به صورت زیر تنظیم کنید:
   - نوع: SOCKS5
   - Host: 127.0.0.1
   - Port: 1080 (یا پورتی که انتخاب کردید)

### روش دستی

1. فایل `server.pub` را از سرور B دانلود کنید:
```bash
scp root@SERVER_B_IP:/opt/dnstt/server.pub ./
```

2. dnstt-client را نصب و اجرا کنید:
```bash
# نصب Go (اگر نصب نیست)
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

3. در تلگرام، تنظیمات Proxy را به صورت زیر تنظیم کنید:
   - نوع: SOCKS5
   - Host: 127.0.0.1
   - Port: 1080

## مدیریت سرویس

### استفاده از اسکریپت مدیریت (پیشنهادی)

```bash
sudo ./manage.sh
```

این اسکریپت یک منوی تعاملی ارائه می‌دهد که شامل:
- مشاهده وضعیت سرویس
- مشاهده لاگ‌ها (زنده و آرشیو)
- راه‌اندازی/توقف/راه‌اندازی مجدد سرویس
- نمایش اطلاعات اتصال و کلید عمومی
- بررسی پورت‌ها و iptables

### دستورات دستی

```bash
# مشاهده وضعیت
systemctl status dnstt-server

# مشاهده لاگ‌ها (زنده)
journalctl -u dnstt-server -f

# مشاهده آخرین لاگ‌ها
journalctl -u dnstt-server -n 50

# راه‌اندازی مجدد
systemctl restart dnstt-server

# توقف
systemctl stop dnstt-server

# شروع
systemctl start dnstt-server
```

## عیب‌یابی

### بررسی اتصال
```bash
# بررسی اینکه سرویس در حال اجرا است
systemctl status dnstt-server

# بررسی پورت
netstat -tulpn | grep 5300

# بررسی iptables
iptables -t nat -L -n -v
```

### بررسی لاگ‌ها
```bash
journalctl -u dnstt-server -n 50
```

## نکات امنیتی

1. فایل `server.key` را محافظت کنید و هرگز آن را به اشتراک نگذارید
2. فقط فایل `server.pub` را با کاربران به اشتراک بگذارید
3. از فایروال برای محدود کردن دسترسی استفاده کنید
4. به صورت منظم لاگ‌ها را بررسی کنید

## فایل‌های پروژه

- `setup_dnstt.sh`: اسکریپت اصلی نصب و راه‌اندازی روی سرور B
- `client_connect.sh`: اسکریپت ساده برای اتصال کاربران
- `manage.sh`: اسکریپت مدیریت سرویس روی سرور B (منوی تعاملی)
- `README.md`: این فایل مستندات

## منابع

- [پروژه اصلی DNSTT](https://github.com/Mygod/dnstt)
- [مستندات DNSTT](https://www.bamsoftware.com/software/dnstt/)

