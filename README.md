# راه‌اندازی DNSTT Tunnel برای پراکسی تلگرام

این اسکریپت برای راه‌اندازی یک تونل DNS بین سرور B و کاربران استفاده می‌شود تا ترافیک از طریق DNS به سرور A منتقل شود.

## ⚡ نصب سریع

```bash
git clone https://github.com/letmefind/DNSST.git
cd DNSST
chmod +x setup_dnstt.sh
sudo ./setup_dnstt.sh
```

## معماری

```
کاربران → [dnstt-client] → DNS Tunnel → [سرور B: dnstt-server] → [سرور A: پراکسی/اپلیکیشن]
```

**توضیح:**
- **سرور B**: سرور دریافت کننده ترافیک کاربران (جایی که `dnstt-server` نصب می‌شود)
- **سرور A**: سرور دریافت کننده ترافیک از B (جایی که پراکسی تلگرام یا سایر اپلیکیشن‌ها نصب است)

### جریان ترافیک:

1. کاربر `dnstt-client` را روی سیستم خود اجرا می‌کند
2. `dnstt-client` ترافیک را از طریق DNS queries (DoH/DoT) به سرور B ارسال می‌کند
3. `dnstt-server` روی سرور B ترافیک را دریافت و رمزگشایی می‌کند
4. ترافیک به سرور A (مقصد نهایی) منتقل می‌شود
5. پاسخ از سرور A به کاربر برمی‌گردد

## پیش‌نیازها

### برای سرور B:
- سیستم عامل Linux (Ubuntu/Debian/CentOS)
- دسترسی root
- اتصال به اینترنت
- دامنه معتبر که به IP سرور B اشاره می‌کند
- DNS resolver که از DoH پشتیبانی می‌کند

### برای سرور A:
- پراکسی تلگرام یا هر اپلیکیشن دیگری که می‌خواهید از طریق تونل به آن دسترسی داشته باشید
- اتصال شبکه بین سرور A و B

### برای کاربران:
- سیستم عامل Linux/macOS/Windows
- دسترسی به اینترنت
- فایل `server.pub` از سرور B

## نصب روی سرور B

### روش 1: استفاده از Git (پیشنهادی)

```bash
git clone https://github.com/letmefind/DNSST.git
cd DNSST
chmod +x setup_dnstt.sh
sudo ./setup_dnstt.sh
```

### روش 2: دانلود مستقیم

```bash
wget https://raw.githubusercontent.com/letmefind/DNSST/main/setup_dnstt.sh
chmod +x setup_dnstt.sh
sudo ./setup_dnstt.sh
```

### اطلاعات مورد نیاز در حین نصب:

1. **دامنه**: دامنه‌ای که به IP سرور B اشاره می‌کند (مثال: `tunnel.example.com`)
2. **DNS resolver**: آدرس DoH resolver (پیش‌فرض: `https://doh.cloudflare.com/dns-query`)
3. **IP سرور A**: آدرس IP سرور A که پراکسی یا اپلیکیشن روی آن نصب است
4. **پورت پراکسی/اپلیکیشن**: پورت سرویس روی سرور A (معمولا `1080` برای SOCKS5)
5. **پورت محلی dnstt**: پورتی که `dnstt-server` روی سرور B گوش می‌دهد (پیش‌فرض: `5300`)
6. **پورت خروجی کاربران**: پورتی که کاربران از آن استفاده می‌کنند (پیش‌فرض: `1080`)

### بعد از نصب:

- فایل `server.pub` در `/opt/dnstt/server.pub` ایجاد می‌شود
- این فایل را به کاربران بدهید
- اطلاعات کامل در `/opt/dnstt/info.txt` ذخیره می‌شود

## تنظیم DNS

باید یک رکورد DNS برای دامنه خود ایجاد کنید که به IP سرور B اشاره کند:

```
Type: A
Name: tunnel.example.com
Value: IP_SERVER_B
TTL: 300
```

**مثال:**
- اگر دامنه شما `tunnel.example.com` است
- و IP سرور B شما `192.0.2.1` است
- باید یک رکورد A با نام `tunnel` و مقدار `192.0.2.1` ایجاد کنید

## استفاده برای کاربران

### روش ساده (استفاده از اسکریپت)

1. **دانلود فایل کلید عمومی:**
```bash
scp root@SERVER_B_IP:/opt/dnstt/server.pub ./
```

2. **دانلود و اجرای اسکریپت client:**
```bash
git clone https://github.com/letmefind/DNSST.git
cd DNSST
chmod +x client_connect.sh
./client_connect.sh
```

3. **وارد کردن اطلاعات:**
   - دامنه (همان دامنه‌ای که در سرور B استفاده کردید)
   - DNS resolver DoH
   - مسیر فایل `server.pub`
   - پورت محلی (معمولا `1080`)

4. **تنظیم تلگرام:**
   - Settings → Advanced → Connection type
   - Use proxy
   - Add proxy → SOCKS5
   - Host: `127.0.0.1`
   - Port: `1080` (یا پورتی که انتخاب کردید)

### روش دستی

1. **دانلود فایل کلید عمومی:**
```bash
scp root@SERVER_B_IP:/opt/dnstt/server.pub ./
```

2. **نصب Go (اگر نصب نیست):**
```bash
# Ubuntu/Debian
sudo apt-get update
sudo apt-get install golang-go

# CentOS/RHEL
sudo yum install golang

# macOS
brew install go
```

3. **دانلود و کامپایل dnstt-client:**
```bash
git clone https://github.com/Mygod/dnstt.git
cd dnstt/plugin
go build -o dnstt-client ./dnstt-client
```

4. **اجرای client:**
```bash
./dnstt-client -doh https://doh.cloudflare.com/dns-query \
  -pubkey-file ./server.pub \
  tunnel.example.com \
  127.0.0.1:1080
```

5. **تنظیم تلگرام:**
   - نوع: SOCKS5
   - Host: 127.0.0.1
   - Port: 1080

## مدیریت سرویس

### استفاده از اسکریپت مدیریت (پیشنهادی)

```bash
cd DNSST
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

# غیرفعال کردن سرویس
systemctl disable dnstt-server

# فعال کردن سرویس
systemctl enable dnstt-server
```

## عیب‌یابی

### مشکلات رایج

#### 1. سرویس اجرا نمی‌شود

```bash
# بررسی وضعیت
systemctl status dnstt-server

# بررسی لاگ‌ها
journalctl -u dnstt-server -n 50

# بررسی فایل کلید
ls -la /opt/dnstt/server.key
```

#### 2. اتصال برقرار نمی‌شود

```bash
# بررسی پورت
sudo netstat -tulpn | grep 5300
# یا
sudo ss -tulpn | grep 5300

# بررسی iptables
sudo iptables -L -n -v | grep 5300

# تست اتصال از سرور A به B
telnet SERVER_B_IP 5300
```

#### 3. DNS resolve نمی‌شود

```bash
# تست DNS
dig tunnel.example.com
nslookup tunnel.example.com

# بررسی اینکه دامنه به IP صحیح اشاره می‌کند
```

#### 4. کاربر نمی‌تواند متصل شود

```bash
# بررسی فایل server.pub
cat /opt/dnstt/server.pub

# بررسی لاگ‌های سرور
journalctl -u dnstt-server -f

# بررسی فایروال
sudo ufw status
sudo iptables -L -n -v
```

### بررسی اتصال

```bash
# بررسی اینکه سرویس در حال اجرا است
systemctl status dnstt-server

# بررسی پورت
netstat -tulpn | grep 5300
ss -tulpn | grep 5300

# بررسی iptables
iptables -t nat -L -n -v
iptables -L INPUT -n -v

# بررسی فایل‌های کلید
ls -la /opt/dnstt/server.*
```

### بررسی لاگ‌ها

```bash
# لاگ‌های زنده
journalctl -u dnstt-server -f

# آخرین 50 خط
journalctl -u dnstt-server -n 50

# لاگ‌های از زمان خاص
journalctl -u dnstt-server --since "1 hour ago"

# لاگ‌های با خطا
journalctl -u dnstt-server -p err
```

## تنظیمات پیشرفته

### تغییر پورت‌ها

برای تغییر پورت‌ها، فایل سرویس را ویرایش کنید:

```bash
sudo nano /etc/systemd/system/dnstt-server.service
```

سپس سرویس را راه‌اندازی مجدد کنید:

```bash
sudo systemctl daemon-reload
sudo systemctl restart dnstt-server
```

### استفاده از DoT به جای DoH

برای استفاده از DoT (DNS over TLS) به جای DoH، در client از `-dot` استفاده کنید:

```bash
./dnstt-client -dot dot.example:853 \
  -pubkey-file ./server.pub \
  tunnel.example.com \
  127.0.0.1:1080
```

### تنظیم MTU

برای تنظیم MTU (Maximum Transmission Unit) در سرور:

```bash
# ویرایش فایل سرویس
sudo nano /etc/systemd/system/dnstt-server.service

# اضافه کردن -mtu به دستور
ExecStart=/opt/dnstt/dnstt-server -udp :5300 -mtu 1232 -privkey-file /opt/dnstt/server.key tunnel.example.com SERVER_A_IP:1080
```

### استفاده از uTLS برای تغییر TLS fingerprint

در client می‌توانید از uTLS برای تغییر fingerprint استفاده کنید:

```bash
./dnstt-client -doh https://doh.cloudflare.com/dns-query \
  -utls Firefox \
  -pubkey-file ./server.pub \
  tunnel.example.com \
  127.0.0.1:1080
```

## نکات امنیتی

1. **محافظت از کلید خصوصی:**
   - فایل `server.key` را محافظت کنید و هرگز آن را به اشتراک نگذارید
   - دسترسی به فایل را محدود کنید: `chmod 600 /opt/dnstt/server.key`

2. **اشتراک‌گذاری کلید عمومی:**
   - فقط فایل `server.pub` را با کاربران به اشتراک بگذارید
   - کلید عمومی برای احراز هویت استفاده می‌شود

3. **فایروال:**
   - از فایروال برای محدود کردن دسترسی استفاده کنید
   - فقط پورت‌های لازم را باز کنید

4. **بررسی لاگ‌ها:**
   - به صورت منظم لاگ‌ها را بررسی کنید
   - برای فعالیت‌های مشکوک جستجو کنید

5. **به‌روزرسانی:**
   - به صورت منظم سیستم و نرم‌افزارها را به‌روزرسانی کنید

## فایل‌های پروژه

- `setup_dnstt.sh`: اسکریپت اصلی نصب و راه‌اندازی روی سرور B
- `client_connect.sh`: اسکریپت ساده برای اتصال کاربران
- `manage.sh`: اسکریپت مدیریت سرویس روی سرور B (منوی تعاملی)
- `README.md`: این فایل مستندات
- `QUICKSTART.md`: راهنمای سریع شروع

## ساختار دایرکتوری

بعد از نصب، ساختار دایرکتوری به صورت زیر است:

```
/opt/dnstt/
├── dnstt-server          # باینری سرور
├── dnstt-client          # باینری کلاینت
├── server.key            # کلید خصوصی (محرمانه!)
├── server.pub            # کلید عمومی (به اشتراک بگذارید)
├── info.txt              # اطلاعات اتصال
└── client_setup.sh       # اسکریپت راه‌اندازی کلاینت
```

## مثال‌های استفاده

### مثال 1: پراکسی تلگرام

```
سرور A: پراکسی تلگرام روی پورت 1080
سرور B: dnstt-server روی پورت 5300
کاربر: اتصال از طریق dnstt-client به پورت محلی 1080
```

### مثال 2: SSH Tunnel

```
سرور A: SSH server روی پورت 22
سرور B: dnstt-server که به سرور A متصل می‌شود
کاربر: اتصال از طریق dnstt-client
```

### مثال 3: Tor Bridge

```
سرور A: Tor bridge روی پورت 9001
سرور B: dnstt-server که به Tor bridge متصل می‌شود
کاربر: اتصال از طریق dnstt-client
```

## سوالات متداول (FAQ)

### Q: آیا می‌توانم از یک سرور برای A و B استفاده کنم؟

A: بله، می‌توانید هر دو را روی یک سرور نصب کنید. در این صورت IP سرور A را `127.0.0.1` قرار دهید.

### Q: آیا می‌توانم از چندین کاربر استفاده کنم؟

A: بله، همه کاربران می‌توانند از همان فایل `server.pub` استفاده کنند.

### Q: آیا ترافیک رمزگذاری می‌شود؟

A: بله، ترافیک بین client و server با Noise protocol رمزگذاری می‌شود.

### Q: آیا می‌توانم از DNS معمولی استفاده کنم؟

A: بله، اما توصیه می‌شود از DoH یا DoT استفاده کنید برای امنیت بیشتر.

### Q: چطور می‌توانم پورت را تغییر دهم؟

A: فایل `/etc/systemd/system/dnstt-server.service` را ویرایش کنید و سرویس را راه‌اندازی مجدد کنید.

## پشتیبانی

برای مشکلات و سوالات:
- Issues: [GitHub Issues](https://github.com/letmefind/DNSST/issues)
- پروژه اصلی: [DNSTT](https://github.com/Mygod/dnstt)

## منابع

- [پروژه اصلی DNSTT](https://github.com/Mygod/dnstt)
- [مستندات DNSTT](https://www.bamsoftware.com/software/dnstt/)
- [Noise Protocol](https://noiseprotocol.org/)

## مجوز

این پروژه تحت مجوز CC0-1.0 منتشر شده است.
