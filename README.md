# راه‌اندازی DNSTT Tunnel برای پراکسی تلگرام

راه‌اندازی تونل DNS بین سرور A (ایران) و سرور B (خارج): ترافیک کاربران روی A دریافت می‌شود و از طریق تونل به B فرستاده می‌شود؛ روی B به ۱۲۷.۰.۰.۱ (مثلاً MTProxy) تحویل داده می‌شود.

## ⚡ نصب سریع (یک‌کلیکی)

```bash
git clone https://github.com/letmefind/DNSST.git
cd DNSST
chmod +x oneclick_external.sh oneclick_iran.sh
```

**۱) سرور B (خارج)** — اول اجرا کنید؛ دامنه + پورت سرویس مقصد روی همین سرور (مثلاً MTProxy روی ۱۲۷.۰.۰.۱):

```bash
sudo ./oneclick_external.sh
# یا: sudo ./oneclick_external.sh tunnel.example.com 1080
```

بعد از نصب، **کلید عمومی** را از خروجی کپی کنید.

**۲) سرور A (ایران)** — روی سروری که ترافیک کاربران را دریافت می‌کند؛ دامنه، کلید عمومی (از B) و پورت گوش دادن برای کاربران:

```bash
sudo ./oneclick_iran.sh
# یا: sudo ./oneclick_iran.sh tunnel.example.com "pubkey:xxxx..." 1080
```

کاربران در تلگرام/اپ پراکسی را روی **IP سرور A** و همان پورت (مثلاً ۱۰۸۰) تنظیم می‌کنند.

جزئیات بیشتر: [QUICKSTART.md](QUICKSTART.md)

## معماری

```
کاربران → [سرور A (ایران): dnstt-client] → DNS Tunnel → [سرور B (خارج): dnstt-server] → 127.0.0.1:پورت (MTProxy یا سرویس دیگر)
```

| سرور | محل | سرویس | نقش |
|------|-----|--------|-----|
| **A** | ایران | `dnstt-client` | ترافیک کاربران اینجا دریافت می‌شود؛ کلاینت ترافیک را از طریق تونل به B می‌فرستد. |
| **B** | خارج | `dnstt-server` | ترافیک تونل را دریافت و به ۱۲۷.۰.۰.۱:پورت (مثلاً MTProxy روی همین سرور) تحویل می‌دهد. |

### جریان ترافیک

1. کاربران به **سرور A** (IP و پورت) وصل می‌شوند (مثلاً SOCKS5).
2. روی سرور A، `dnstt-client` ترافیک را از طریق DNS (DoH/DoT) به **سرور B** ارسال می‌کند.
3. روی سرور B، `dnstt-server` ترافیک را دریافت و رمزگشایی می‌کند.
4. ترافیک به **۱۲۷.۰.۰.۱:پورت** روی همان سرور B تحویل داده می‌شود (MTProxy یا هر سرویس دیگر).
5. پاسخ از B به A و سپس به کاربر برمی‌گردد.

## پیش‌نیازها

### برای سرور B (خارج):
- سیستم عامل Linux (Ubuntu/Debian)
- دسترسی root
- اتصال به اینترنت
- دامنه معتبر که به **IP سرور B** اشاره می‌کند (کلاینت روی A از همین دامنه برای تونل استفاده می‌کند)
- سرویس مقصد روی همین سرور (مثلاً MTProxy روی ۱۲۷.۰.۰.۱:۱۰۸۰) یا هر پورت دیگر

### برای سرور A (ایران):
- سیستم عامل Linux (Ubuntu/Debian)
- دسترسی root
- اتصال به اینترنت (و امکان استفاده از DoH برای تونل به B)
- کلید عمومی (`server.pub`) از نصب سرور B

### برای کاربران نهایی:
- در تلگرام/اپ: تنظیم پراکسی SOCKS5 با Host = **IP سرور A** و Port = پورت انتخاب‌شده روی A (معمولاً ۱۰۸۰)

## نصب روی سرور B (خارج)

سرور B ترافیک تونل را دریافت و به **۱۲۷.۰.۰.۱:پورت** تحویل می‌دهد. پورت از شما پرسیده می‌شود (پیش‌فرض ۱۰۸۰).

### روش ۱: یک‌کلیکی (پیشنهادی)

```bash
git clone https://github.com/letmefind/DNSST.git
cd DNSST
chmod +x oneclick_external.sh
sudo ./oneclick_external.sh
# دامنه + پورت سرویس مقصد روی این سرور (مثلاً 1080 برای MTProxy)
```

### روش ۲: نصب کامل (setup_dnstt.sh)

```bash
chmod +x setup_dnstt.sh
sudo ./setup_dnstt.sh
```

برای این روش می‌توانید مقصد را به IP:پورت (مثلاً ۱۲۷.۰.۰.۱:۱۰۸۰) تنظیم کنید.

### بعد از نصب سرور B:

- کلید عمومی در `/opt/dnstt/server.pub` و در خروجی اسکریپت نمایش داده می‌شود
- این کلید را برای نصب **سرور A** ذخیره کنید
- اطلاعات در `/opt/dnstt/info.txt` ذخیره می‌شود

## نصب روی سرور A (ایران)

سرور A ترافیک کاربران را دریافت می‌کند و از طریق تونل به B می‌فرستد.

### روش ۱: یک‌کلیکی (پیشنهادی)

```bash
# بعد از نصب سرور B و دریافت کلید عمومی:
sudo ./oneclick_iran.sh
# دامنه (همان دامنهٔ B)، کلید عمومی، پورت گوش دادن برای کاربران (پیش‌فرض 1080)
```

### روش ۲: استفاده از client_connect.sh

اگر ترافیک را روی **همان سرور A** می‌گیرید، می‌توانید از `client_connect.sh` با کلید و دامنهٔ B استفاده کنید و آدرس گوش دادن را `0.0.0.0:1080` قرار دهید تا کاربران به IP سرور A وصل شوند (جزئیات در QUICKSTART).

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

## استفاده برای کاربران نهایی

### روش پیشنهادی: اتصال مستقیم به سرور A

اگر سرور A را با `oneclick_iran.sh` نصب کرده‌اید، کاربران **مستقیماً به IP سرور A** وصل می‌شوند (بدون نصب کلاینت روی دستگاه خود):

1. **تنظیم تلگرام (یا اپ پراکسی):**
   - Settings → Advanced → Connection type → Use proxy
   - Add proxy → SOCKS5
   - **Host:** IP یا دامنهٔ **سرور A (ایران)**
   - **Port:** پورتی که هنگام نصب سرور A انتخاب کردید (معمولاً `1080`)

ترافیک از کاربر → سرور A (dnstt-client) → تونل → سرور B (dnstt-server) → ۱۲۷.۰.۰.۱ (مثلاً MTProxy).

### روش دیگر: اجرای کلاینت روی دستگاه کاربر

اگر بخواهید کاربران روی سیستم خودشان کلاینت اجرا کنند (اتصال به ۱۲۷.۰.۰.۱ روی همان دستگاه):

1. **دریافت کلید عمومی از سرور B:**
```bash
scp root@SERVER_B_IP:/opt/dnstt/server.pub ./
```

2. **اجرای اسکریپت client:**
```bash
git clone https://github.com/letmefind/DNSST.git
cd DNSST
chmod +x client_connect.sh
./client_connect.sh
```
   - دامنه (همان دامنهٔ B)، DoH، مسیر `server.pub`، پورت محلی (مثلاً ۱۰۸۰)

3. **تنظیم تلگرام:** Host: `127.0.0.1`, Port: `1080`

یا به صورت دستی بعد از کامپایل `dnstt-client`:
```bash
./dnstt-client -doh https://doh.cloudflare.com/dns-query \
  -pubkey-file ./server.pub \
  tunnel.example.com \
  127.0.0.1:1080
```
سپس در تلگرام: SOCKS5، Host: 127.0.0.1، Port: 1080

## مدیریت سرویس

### روی سرور B (خارج) — dnstt-server

```bash
cd DNSST
sudo ./manage.sh
```

منو: وضعیت، لاگ، راه‌اندازی مجدد، iptables، آزاد کردن پورت ۵۳.

دستورات مستقیم:
```bash
systemctl status dnstt-server
journalctl -u dnstt-server -f
systemctl restart dnstt-server
```

### روی سرور A (ایران) — dnstt-client

```bash
sudo ./manage_client.sh
# یا:
systemctl status dnstt-client
journalctl -u dnstt-client -f
systemctl restart dnstt-client
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
ExecStart=/opt/dnstt/dnstt-server -udp :5300 -mtu 1232 -privkey-file /opt/dnstt/server.key tunnel.example.com 127.0.0.1:1080
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

- `oneclick_external.sh`: نصب یک‌کلیکی **سرور B (خارج)** — dnstt-server؛ پورت مقصد (۱۲۷.۰.۰.۱) از کاربر پرسیده می‌شود.
- `oneclick_iran.sh`: نصب یک‌کلیکی **سرور A (ایران)** — dnstt-client؛ ترافیک کاربران اینجا دریافت و به B فرستاده می‌شود.
- `setup_dnstt.sh`: نصب کامل و قابل تنظیم روی سرور B.
- `client_connect.sh`: اتصال کلاینت (برای کاربران یا برای نصب دستی روی سرور A).
- `manage.sh`: مدیریت سرویس dnstt-server روی سرور B.
- `manage_client.sh`: مدیریت سرویس dnstt-client روی سرور A.
- `README.md`: این مستندات.
- `QUICKSTART.md`: راهنمای سریع و خلاصه.

## ساختار دایرکتوری

بعد از نصب روی **سرور B** (`/opt/dnstt/`):

```
├── dnstt-server          # باینری سرور
├── dnstt-client          # باینری کلاینت (برای client_setup.sh)
├── server.key            # کلید خصوصی (محرمانه!)
├── server.pub            # کلید عمومی (برای نصب سرور A)
├── info.txt              # اطلاعات اتصال
└── client_setup.sh       # اسکریپت راه‌اندازی کلاینت (تولیدشده توسط setup_dnstt.sh)
```

بعد از نصب روی **سرور A** نیز `/opt/dnstt/` با `dnstt-client` و `server.pub` ایجاد می‌شود.

## مثال‌های استفاده

### مثال ۱: پراکسی تلگرام (معماری فعلی)

```
سرور A (ایران): dnstt-client — کاربران به A:1080 وصل می‌شوند
سرور B (خارج): dnstt-server → 127.0.0.1:1080 (MTProxy روی همان B)
```

### مثال ۲: سرویس دیگر روی B

```
سرور A: dnstt-client (دریافت ترافیک کاربران)
سرور B: dnstt-server → 127.0.0.1:22 (SSH) یا 127.0.0.1:9001 (Tor) — پورت را هنگام نصب B وارد کنید.
```

## سوالات متداول (FAQ)

### Q: آیا می‌توانم سرور A و B را روی یک ماشین داشته باشم؟

A: بله. سرور B را با مقصد `127.0.0.1:پورت` نصب کنید؛ سرور A (dnstt-client) را روی همان یا ماشین دیگر با دامنهٔ اشاره‌کننده به همان IP اجرا کنید. برای تست، هر دو روی یک سرور امکان‌پذیر است.

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
