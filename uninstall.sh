#!/bin/sh
echo ">>> Removing warppluplus..."

# Stop and disable the service
/etc/init.d/warppluplus stop 2>/dev/null
/etc/init.d/warppluplus disable 2>/dev/null
rm -f /etc/init.d/warppluplus

# Remove executable
rm -f /usr/bin/warppluplus

# Remove LuCI HTML view
rm -f /www/luci-static/resources/view/warppluplus.htm

# Remove config directory and files
rm -rf /etc/warppluplus
rm -f /etc/warppluplus_status
rm -f /etc/config/warppluplus

# Remove related cron job
sed -i '/warppluplus/d' /etc/crontabs/root

# Remove passwall2 nodes related to warppluplus
for section in $(uci show passwall2 | grep warppluplus | cut -d'.' -f2 | cut -d'=' -f1); do
    uci delete passwall2.$section
done
uci commit passwall2

# Restart services
/etc/init.d/uhttpd restart
/etc/init.d/rpcd restart

echo ">>> warppluplus has been completely removed."
