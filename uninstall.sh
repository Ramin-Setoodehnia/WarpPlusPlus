#!/bin/sh

#================================================================================
# Warp++ (WarpPlusPlus) Uninstaller
#
# Created by: PeDitX
# Version: 1.0
#
# This script will completely remove all components of the Warp++ application,
# including binaries, services, LuCI interface, and configurations.
#================================================================================

echo "Starting the complete uninstallation of Warp++..."
echo "This will remove all related files and configurations."
sleep 3

# --- 1. Stop and Disable the Service ---
echo -e "\n[Step 1/6] Stopping and disabling the Warp++ service..."
if [ -f /etc/init.d/warpplusplus ]; then
    /etc/init.d/warpplusplus stop >/dev/null 2>&1
    /etc/init.d/warpplusplus disable >/dev/null 2>&1
    rm -f /etc/init.d/warpplusplus
    echo "Service stopped, disabled, and removed."
else
    echo "Service file not found, skipping."
fi

# --- 2. Remove Binaries and Core Files ---
echo -e "\n[Step 2/6] Removing binaries and core files..."
rm -f /usr/bin/warpplusplus
rm -f /usr/bin/wpp-scanner
rm -rf /usr/bin/wpp-scanner-core
echo "Binaries removed."

# --- 3. Remove UCI Configuration ---
echo -e "\n[Step 3/6] Removing UCI configuration..."
if [ -f /etc/config/warpplusplus ]; then
    rm -f /etc/config/warpplusplus
    uci commit warpplusplus
    echo "UCI config removed."
else
    echo "UCI config file not found, skipping."
fi

# --- 4. Remove LuCI Interface Files ---
echo -e "\n[Step 4/6] Removing LuCI interface files..."
rm -f /usr/lib/lua/luci/controller/warpplusplus.lua
rm -rf /usr/lib/lua/luci/view/warpplusplus
echo "LuCI files removed."

# --- 5. Remove Cron Job and Passwall Nodes ---
echo -e "\n[Step 5/6] Removing Cron job and Passwall nodes..."
# Remove Cron job
sed -i '/#Warp++AutoReconnect/d' /etc/crontabs/root >/dev/null 2>&1
/etc/init.d/cron restart >/dev/null 2>&1
echo "Auto-reconnect cron job removed."

# Remove Passwall nodes
if uci show passwall2 >/dev/null 2>&1; then
    uci delete passwall2.WarpPlusPlus >/dev/null 2>&1
    uci commit passwall2
    /etc/init.d/passwall2 restart >/dev/null 2>&1
    echo "Passwall2 node removed."
elif uci show passwall >/dev/null 2>&1; then
    uci delete passwall.WarpPlusPlus >/dev/null 2>&1
    uci commit passwall
    /etc/init.d/passwall restart >/dev/null 2>&1
    echo "Passwall node removed."
fi

# --- 6. Finalize and Clean Up ---
echo -e "\n[Step 6/6] Finalizing..."
# Remove temporary files
rm -f /tmp/warpplusplus_debug.log
rm -f /tmp/wpp_scanner_output.log
rm -f /usr/bin/result.csv

# Clear LuCI cache and restart web server
rm -f /tmp/luci-indexcache
/etc/init.d/uhttpd restart

echo -e "\n================================================"
echo "      Warp++ has been completely uninstalled. "
echo "================================================"
echo -e "\nPlease refresh your router's web page.\n"

