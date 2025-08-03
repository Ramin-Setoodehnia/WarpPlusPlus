#!/bin/sh
echo ">>> [warppluplus] در حال حذف کامل... 🔥"

# توقف و غیرفعال‌سازی سرویس
/etc/init.d/warppluplus stop 2>/dev/null
/etc/init.d/warppluplus disable 2>/dev/null

# حذف از کرون
sed -i '/warppluplus/d' /etc/crontabs/root

# حذف رابط LuCI و فایل‌های استاتیک
rm -f /www/luci-static/resources/view/warppluplus.htm
rm -f /www/luci-static/resources/view/warppluplus.html
rm -f /www/luci-static/resources/warppluplus.js
rm -f /www/luci-static/resources/warppluplus.css
rm -rf /www/luci-static/resources/warppluplus/

# حذف اسکریپت‌ها و فایل‌های اجرایی
rm -f /usr/bin/warppluplus
rm -f /etc/init.d/warppluplus
rm -f /etc/warppluplus.sh
rm -f /etc/warppluplus_status
rm -f /etc/config/warppluplus
rm -rf /etc/warppluplus

# حذف نودهای passwall2 که مربوط به warppluplus هستن
for section in $(uci show passwall2 | grep warppluplus | cut -d'.' -f2 | cut -d'=' -f1); do
    uci delete passwall2.$section
done
uci commit passwall2

# حذف کش و موقت‌ها
rm -rf /tmp/luci-*
rm -rf /tmp/warppluplus*

# ریستارت سرویس‌های رابط وب
/etc/init.d/uhttpd restart
/etc/init.d/rpcd restart

echo ">>> [warppluplus] حذف کامل با موفقیت انجام شد ✅"
