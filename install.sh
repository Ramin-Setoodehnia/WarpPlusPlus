#!/bin/sh

#================================================================================
# Warp++ (WarpPlusPlus) All-in-One Installer with LuCI UI
#
# Created by: PeDitX
# Version: 17.0 (Final - Adopted Source Logic for Maximum Stability)
#
# This script will:
# 1. Rebrand the entire project to Warp++.
# 2. Check for and install the 'curl' dependency.
# 3. Install the correct binaries.
# 4. Create a highly robust LuCI UI that directly manages the init.d script.
# 5. Set the SOCKS proxy port to 8087.
# 6. Allow using a scanned endpoint directly for the Warp++ connection.
# 7. Create a template init.d service to be managed by LuCI.
#================================================================================

echo "Starting Warp++ (WarpPlusPlus) All-in-One Installer v17.0..."
sleep 2

# --- 1. System Prerequisite Check ---
echo -e "\n[Step 1/7] Checking for dependencies..."
opkg update > /dev/null 2>&1
if ! opkg install curl > /dev/null 2>&1; then
    echo "Warning: Failed to auto-install curl. Please ensure it is installed."
fi
if ! command -v curl >/dev/null 2>&1; then
  echo 'Error: curl is not installed. Please install it first via "opkg install curl".' >&2
  exit 1
fi
echo "Dependencies are satisfied."


# --- 2. Detect Architecture and Download Binaries ---
echo -e "\n[Step 2/7] Detecting system architecture and downloading binaries..."
ARCH=$(uname -m)
case $ARCH in
    x86_64)
        WARP_URL="https://github.com/bepass-org/warp-plus/releases/download/v1.2.5/warp-plus_linux-amd64.zip"
        SCANNER_URL="https://github.com/bia-pain-bache/BPB-Warp-Scanner/releases/latest/download/BPB-Warp-Scanner-linux-amd64.tar.gz"
        ;;
    aarch64)
        WARP_URL="https://github.com/bepass-org/warp-plus/releases/download/v1.2.5/warp-plus_linux-arm64.zip"
        SCANNER_URL="https://github.com/bia-pain-bache/BPB-Warp-Scanner/releases/latest/download/BPB-Warp-Scanner-linux-aarch64.tar.gz"
        ;;
    armv7l)
        WARP_URL="https://github.com/bepass-org/warp-plus/releases/download/v1.2.5/warp-plus_linux-arm7.zip"
        SCANNER_URL="https://github.com/bia-pain-bache/BPB-Warp-Scanner/releases/latest/download/BPB-Warp-Scanner-linux-arm.tar.gz"
        ;;
    mips)
        WARP_URL="https://github.com/bepass-org/warp-plus/releases/download/v1.2.5/warp-plus_linux-mips.zip"
        SCANNER_URL="https://github.com/bia-pain-bache/BPB-Warp-Scanner/releases/latest/download/BPB-Warp-Scanner-linux-mips.tar.gz"
        ;;
    mipsle)
        WARP_URL="https://github.com/bepass-org/warp-plus/releases/download/v1.2.5/warp-plus_linux-mipsle.zip"
        SCANNER_URL="https://github.com/bia-pain-bache/BPB-Warp-Scanner/releases/latest/download/BPB-Warp-Scanner-linux-mipsle.tar.gz"
        ;;
    *)
        echo "Error: System architecture not supported."
        exit 1
        ;;
esac

cd /tmp || exit

# Download and extract Warp++
echo "Downloading Warp++..."
if ! wget --no-check-certificate -O warp.zip "$WARP_URL"; then
    echo "Error: Failed to download the Warp++ binary."
    exit 1
fi
if ! unzip -o warp.zip; then
    echo "Error: Failed to extract the Warp++ zip file."
    exit 1
fi

# Download and extract Scanner
echo "Downloading Warp++ Scanner..."
if ! wget --no-check-certificate -O scanner.tar.gz "$SCANNER_URL"; then
    echo "Error: Failed to download the scanner binary."
    exit 1
fi
if ! tar -xzf scanner.tar.gz; then
    echo "Error: Failed to extract the scanner tar.gz file."
    exit 1
fi
echo "Download and extraction successful."


# --- 3. Install Binaries ---
echo -e "\n[Step 3/7] Installing the binaries..."
mv -f warp-plus /usr/bin/warpplusplus
chmod +x /usr/bin/warpplusplus
echo "Warp++ binary installed to /usr/bin/warpplusplus."

if [ -f "/tmp/BPB-Warp-Scanner" ] && [ -d "/tmp/core" ]; then
    cp -f /tmp/BPB-Warp-Scanner /usr/bin/wpp-scanner
    rm -rf /usr/bin/wpp-scanner-core
    mkdir -p /usr/bin/wpp-scanner-core
    cp -rf /tmp/core/* /usr/bin/wpp-scanner-core/
    chmod +x /usr/bin/wpp-scanner
    chmod -R 755 /usr/bin/wpp-scanner-core
    echo "Warp++ Scanner installed to /usr/bin/wpp-scanner."
else
    echo "Error: Could not find the extracted scanner files."
    exit 1
fi


# --- 4. Create UCI Config ---
echo -e "\n[Step 4/7] Creating UCI configuration file..."
uci -q batch <<-EOF
    delete warpplusplus
    set warpplusplus.settings=warpplusplus
    set warpplusplus.settings.mode='scan'
    set warpplusplus.settings.country='US'
    set warpplusplus.settings.reconnect_enabled='0'
    set warpplusplus.settings.reconnect_interval='120'
    set warpplusplus.settings.custom_endpoint=''
    commit warpplusplus
EOF


# --- 5. Create LuCI UI Files ---
echo -e "\n[Step 5/7] Creating LuCI interface files..."

# Create LuCI Controller (Backend Logic)
mkdir -p /usr/lib/lua/luci/controller
cat > /usr/lib/lua/luci/controller/warpplusplus.lua <<'EoL'
module("luci.controller.warpplusplus", package.seeall)

function index()
    entry({"admin", "peditxos"}, nil, "PeDitXOS Tools", 55).dependent = false
    entry({"admin", "peditxos", "warpplusplus"}, template("warpplusplus/main"), "Warp++", 1).dependent = true
    entry({"admin", "peditxos", "warpplusplus_api"}, call("api_handler")).leaf = true
end

-- This function generates and writes the init.d script content using the stable source logic
function write_init_script(args)
    local safe_args = args:gsub("\"", "\\\"") -- Escape quotes just in case
    local init_script_content = "#!/bin/sh /etc/rc.common\n" ..
                                "START=91\nUSE_PROCD=1\nPROG=/usr/bin/warpplusplus\n" ..
                                "LOG_FILE=\"/tmp/warpplusplus_debug.log\"\n\n" ..
                                "log() {\n    echo \"[$(date '+%Y-%m-%d %H:%M:%S')] $1\" >> $LOG_FILE\n}\n\n" ..
                                "start_service() {\n" ..
                                "    local cmd_args=\"" .. safe_args .. "\"\n" ..
                                "    log \"Starting Warp++ with args: $cmd_args\"\n" ..
                                "    procd_open_instance\n" ..
                                "    procd_set_param command $PROG $cmd_args\n" ..
                                "    procd_set_param stdout 1\n    procd_set_param stderr 1\n" ..
                                "    procd_set_param respawn\n    procd_close_instance\n}\n\n" ..
                                "stop_service() {\n    log \"Stopping Warp++ service.\"\n    procd_kill warpplusplus\n}\n"
    
    local file = io.open("/etc/init.d/warpplusplus", "w")
    if file then
        file:write(init_script_content)
        file:close()
        luci.sys.call("chmod 755 /etc/init.d/warpplusplus")
        return true
    end
    return false
end

function api_handler()
    luci.http.prepare_content("application/json")
    local DEBUG_LOG_FILE = "/tmp/warpplusplus_debug.log"

    local function log(msg)
        luci.sys.call("echo \"[$(date '+%Y-%m-%d %H:%M:%S')] " .. msg .. "\" >> " .. DEBUG_LOG_FILE)
    end

    local ok, response_data = pcall(function()
        local action = luci.http.formvalue("action") or "status"
        local uci = luci.model.uci.cursor()
        local SCAN_LOG_FILE = "/tmp/wpp_scanner_output.log"
        local SCAN_RESULT_FILE = "/usr/bin/result.csv"
        
        if action == "status" then
            local running = (luci.sys.call("pgrep -f '/usr/bin/warpplusplus' >/dev/null") == 0)
            local ip, ipCountryCode = "N/A", "N/A"
            if running then
                local ip_urls = {"http://api.ipify.org", "http://ifconfig.me/ip"}
                for _, url in ipairs(ip_urls) do
                    local ip_cmd = "curl --socks5 127.0.0.1:8087 -m 7 -s " .. url
                    local status, fetched_ip = luci.sys.call(ip_cmd)
                    if status == 0 and fetched_ip and fetched_ip:match("%d+%.%d+%.%d+%.%d+") then
                        ip = fetched_ip:gsub("[\n\r]", "")
                        local country_cmd = "curl -m 5 -s http://ip-api.com/json/" .. ip .. "?fields=countryCode"
                        local country_status, json_str = luci.sys.call(country_cmd)
                        if country_status == 0 and json_str then
                            local code = json_str:match('"countryCode":"(..)"')
                            if code then ipCountryCode = code end
                        end
                        break
                    end
                end
                if ip == "N/A" then ip = "Connecting..." end
            end
            return {
                running = running, ip = ip, ipCountryCode = ipCountryCode,
                mode = uci:get("warpplusplus", "settings", "mode") or "scan",
                country = uci:get("warpplusplus", "settings", "country") or "US",
                custom_endpoint = uci:get("warpplusplus", "settings", "custom_endpoint") or "",
                reconnect_enabled = uci:get("warpplusplus", "settings", "reconnect_enabled") or "0",
                reconnect_interval = uci:get("warpplusplus", "settings", "reconnect_interval") or "120"
            }
        elseif action == "toggle" then
            local cmd = (luci.sys.call("pgrep -f '/usr/bin/warpplusplus' >/dev/null") == 0) and "stop" or "start"
            log("Request to " .. cmd .. " service.")
            luci.sys.call("/etc/init.d/warpplusplus " .. cmd .. " >> " .. DEBUG_LOG_FILE .. " 2>&1 &")
            return {success=true}
        elseif action == "save_settings" or action == "set_endpoint" then
            local args = "-b 127.0.0.1:8087"
            if action == "set_endpoint" then
                local endpoint = luci.http.formvalue("endpoint")
                log("Request to SET custom endpoint: " .. endpoint)
                uci:set("warpplusplus", "settings", "mode", "endpoint")
                uci:set("warpplusplus", "settings", "custom_endpoint", endpoint)
                args = args .. " -e " .. endpoint
            else
                local mode = luci.http.formvalue("mode")
                local country = luci.http.formvalue("country")
                log("Request to SAVE settings. Mode: " .. mode .. ", Country: " .. country)
                uci:set("warpplusplus", "settings", "mode", mode)
                uci:set("warpplusplus", "settings", "country", country)
                if mode ~= "endpoint" then uci:set("warpplusplus", "settings", "custom_endpoint", "") end
                if mode == "gool" then args = args .. " --gool"
                elseif mode == "cfon" then args = args .. " --cfon --country " .. country
                else args = args .. " --scan" end
            end
            uci:commit("warpplusplus")
            log("UCI settings saved. Writing new init.d script.")
            write_init_script(args)
            luci.sys.call("/etc/init.d/warpplusplus restart >> " .. DEBUG_LOG_FILE .. " 2>&1 &")
            return {success=true, message="Settings saved and service restarting."}
        elseif action == "save_reconnect" then
            local enabled = luci.http.formvalue("enabled")
            local interval = luci.http.formvalue("interval")
            log("Request to SAVE reconnect. Enabled: " .. enabled .. ", Interval: " .. interval)
            uci:set("warpplusplus", "settings", "reconnect_enabled", enabled)
            uci:set("warpplusplus", "settings", "reconnect_interval", interval)
            uci:commit("warpplusplus")
            local CRON_CMD = "/etc/init.d/warpplusplus restart"
            local CRON_TAG = "#Warp++AutoReconnect"
            luci.sys.call("sed -i '/" .. CRON_TAG .. "/d' /etc/crontabs/root")
            if enabled == "1" then
                luci.sys.call("echo '*/" .. interval .. " * * * * " .. CRON_CMD .. " " .. CRON_TAG .. "' >> /etc/crontabs/root")
            end
            luci.sys.call("/etc/init.d/cron restart")
            return {success=true}
        elseif action == "start_scan" then
            log("Request to START endpoint scan.")
            local scan_density = luci.http.formvalue("density") or "1"
            local ip_version = luci.http.formvalue("ip_version") or "1"
            local output_count = luci.http.formvalue("output_count") or "10"
            local input_cmds = string.format("%s\\n%s\\n2\\n1\\n%s\\n", scan_density, ip_version, output_count)
            local cmd = string.format("(echo -e '%s') | /usr/bin/wpp-scanner", input_cmds)
            luci.sys.call("echo 'Starting scan...' > " .. SCAN_LOG_FILE)
            luci.sys.call("cd /usr/bin && " .. cmd .. " >> " .. SCAN_LOG_FILE .. " 2>&1 &")
            return {success=true, message="Scan started."}
        elseif action == "get_scan_status" then
            local scanning = (luci.sys.call("pgrep -f '/usr/bin/wpp-scanner' >/dev/null") == 0)
            local log_content = ""
            local results = {}
            local f_log = io.open(SCAN_LOG_FILE, "r")
            if f_log then log_content = f_log:read("*a"); f_log:close() end
            if not scanning then
                local f_res = io.open(SCAN_RESULT_FILE, "r")
                if f_res then
                    f_res:read("*l") -- Skip header
                    for line in f_res:lines() do
                        local endpoint, loss, latency = line:match("([^,]+),([^,]+),([^,]+)")
                        if endpoint then table.insert(results, {endpoint = endpoint, loss = loss, latency = latency}) end
                    end
                    f_res:close()
                end
            end
            return { scanning = scanning, log = log_content, results = results }
        elseif action == "get_debug_log" then
            local log_content = ""
            local f_log = io.open(DEBUG_LOG_FILE, "r")
            if f_log then log_content = f_log:read("*a"); f_log:close() end
            return { log = log_content }
        else
            return {error="Unknown action"}
        end
    end)

    if ok then
        luci.http.write_json(response_data)
    else
        log("FATAL LUA ERROR: " .. tostring(response_data))
        luci.http.write_json({
            error = "Backend Lua error occurred.", message = tostring(response_data),
            running = false, ip = "Lua Error", ipCountryCode = "N/A",
            mode = "scan", country = "US", custom_endpoint = "",
            reconnect_enabled = "0", reconnect_interval = "120"
        })
    end
end
EoL

# Create LuCI View (Frontend UI)
mkdir -p /usr/lib/lua/luci/view/warpplusplus
cat > /usr/lib/lua/luci/view/warpplusplus/main.htm <<'EoL'
<%+header%>
<style>
    .peditx-container{ max-width: 800px; margin: 40px auto; padding: 24px; background-color: rgba(30, 30, 30, 0.9); backdrop-filter: blur(10px); border: 1px solid rgba(255, 255, 255, 0.2); box-shadow: 0 8px 32px 0 rgba(0, 0, 0, 0.1); border-radius: 12px; font-family: -apple-system,BlinkMacSystemFont,"Segoe UI",Roboto,Oxygen,Ubuntu,Cantarell,"Fira Sans","Droid Sans","Helvetica Neue",sans-serif; color: #f0f0f0; }
    h2, h3 { text-align: center; color: #fff; margin-bottom: 24px; }
    .peditx-row{ display: flex; justify-content: space-between; align-items: center; padding: 12px 0; border-bottom: 1px solid rgba(255, 255, 255, 0.1); flex-wrap: wrap; }
    .peditx-row:last-child{ border-bottom: none; }
    .peditx-label{ font-weight: 600; color: #ccc; }
    .peditx-value{ font-weight: 700; color: #fff; }
    .peditx-status-indicator{ display: inline-block; width: 12px; height: 12px; border-radius: 50%; margin-right: 8px; transition: background-color 0.5s ease; }
    .status-connected{ background-color: #28a745; }
    .status-disconnected{ background-color: #dc3545; }
    .status-scanning { background-color: #007bff; animation: pulse-blue 1.5s infinite; }
    .peditx-btn{ padding: 10px 24px; font-size: 16px; font-weight: 600; border: none; border-radius: 8px; cursor: pointer; transition: all 0.2s ease; }
    .peditx-btn:hover:not(:disabled){ transform: translateY(-2px); }
    .peditx-btn:disabled{ background-color: #555 !important; cursor: not-allowed; animation: none !important; color: #aaa !important; }
    .settings-section{ margin-top: 24px; padding-top: 16px; border-top: 1px solid rgba(255, 255, 255, 0.1); }
    .controls-group { display: flex; gap: 15px; margin-top: 10px; justify-content: center; align-items: center; flex-wrap: wrap; }
    .mode-btn { background-color: rgba(255, 255, 255, 0.1); border: 1px solid rgba(255, 255, 255, 0.2); color: #fff; }
    .mode-btn.selected-mode { background-color: #9b59b6; border-color: #9b59b6; color: #fff; transform: scale(1.05); }
    .btn-save-changes { background-color: #007bff; }
    .btn-save-changes.dirty { background-color: #ffc107; color: #000; animation: pulse-yellow 1.5s infinite; }
    .btn-use-endpoint { background-color: #28a745; padding: 6px 12px; font-size: 14px; }
    @keyframes pulse-yellow { 0% { box-shadow: 0 0 0 0 rgba(255, 193, 7, 0.7); } 70% { box-shadow: 0 0 0 10px rgba(255, 193, 7, 0); } 100% { box-shadow: 0 0 0 0 rgba(255, 193, 7, 0); } }
    @keyframes pulse-blue { 0% { box-shadow: 0 0 0 0 rgba(0, 123, 255, 0.7); } 70% { box-shadow: 0 0 0 10px rgba(0, 123, 255, 0); } 100% { box-shadow: 0 0 0 0 rgba(0, 123, 255, 0); } }
    select, input[type=number] { padding: 8px; border-radius: 8px; background-color: rgba(255, 255, 255, 0.1); color: #fff; border: 1px solid rgba(255, 255, 255, 0.2); font-weight: 600; font-size: 14px; }
    select option { background-color: #333; color: #fff; }
    .log-container { margin-top: 30px; padding: 15px; background-color: rgba(0, 0, 0, 0.3); border-radius: 8px; }
    .log-output { background-color: #000; color: #00ff00; padding: 10px; border-radius: 4px; font-family: monospace; font-size: 12px; white-space: pre-wrap; max-height: 250px; overflow-y: auto; border: 1px solid #333; }
    #scan-results-table { width: 100%; margin-top: 15px; border-collapse: collapse; }
    #scan-results-table th, #scan-results-table td { padding: 8px 12px; text-align: center; border: 1px solid rgba(255, 255, 255, 0.2); }
    #scan-results-table th { background-color: rgba(255, 255, 255, 0.1); }
</style>

<div class="peditx-container">
    <div id="notification-bar" style="display: none; position: fixed; top: 20px; left: 50%; transform: translateX(-50%); background-color: #28a745; color: white; padding: 12px 20px; border-radius: 8px; z-index: 1000; box-shadow: 0 4px 8px rgba(0,0,0,0.2); font-weight: 600;"></div>
    <h2>Warp++ Manager</h2>
    <div class="peditx-row"><span class="peditx-label">Service Status:</span><span class="peditx-value"><span id="statusIndicator" class="peditx-status-indicator"></span><span id="statusText">...</span></span></div>
    <div class="peditx-row"><span class="peditx-label">Outgoing IP:</span><span class="peditx-value"><span id="ipFlag"></span> <span id="ipText">...</span></span></div>
    <div class="peditx-row" style="justify-content: center; padding-top: 20px;"><button id="connectBtn" class="peditx-btn">Connect</button><button id="disconnectBtn" class="peditx-btn" style="display:none;">Disconnect</button></div>

    <div class="settings-section">
        <h3>Service Settings</h3>
        <div class="peditx-row"><span class="peditx-label">Configured Mode:</span><span id="configuredModeText" class="peditx-value">...</span></div>
        <div class="controls-group" id="mode-btn-group">
            <button class="peditx-btn mode-btn" data-mode="scan">Default (Scan)</button>
            <button class="peditx-btn mode-btn" data-mode="gool">Gool</button>
            <button class="peditx-btn mode-btn" data-mode="cfon">Psiphon</button>
            <button class="peditx-btn mode-btn" data-mode="endpoint">Custom Endpoint</button>
        </div>
        <div id="country-selector" class="controls-group" style="display: none; margin-top: 15px;"><label for="country-select" class="peditx-label">Psiphon Country:&nbsp;</label>
            <select id="country-select">
                <option value="AT">🇦🇹 Austria</option><option value="AU">🇦🇺 Australia</option><option value="BE">🇧🇪 Belgium</option><option value="BG">🇧🇬 Bulgaria</option><option value="CA">🇨🇦 Canada</option><option value="CH">🇨🇭 Switzerland</option><option value="CZ">🇨🇿 Czech Rep</option><option value="DE">🇩🇪 Germany</option><option value="DK">🇩🇰 Denmark</option><option value="EE">🇪🇪 Estonia</option><option value="ES">🇪🇸 Spain</option><option value="FI">🇫🇮 Finland</option><option value="FR">🇫🇷 France</option><option value="GB">🇬🇧 UK</option><option value="HR">🇭🇷 Croatia</option><option value="HU">🇭🇺 Hungary</option><option value="IE">🇮🇪 Ireland</option><option value="IN">🇮🇳 India</option><option value="IT">🇮🇹 Italy</option><option value="JP">🇯🇵 Japan</option><option value="LV">🇱🇻 Latvia</option><option value="NL">🇳🇱 Netherlands</option><option value="NO">🇳🇴 Norway</option><option value="PL">🇵🇱 Poland</option><option value="PT">🇵🇹 Portugal</option><option value="RO">🇷🇴 Romania</option><option value="RS">🇷🇸 Serbia</option><option value="SE">🇸🇪 Sweden</option><option value="SG">🇸🇬 Singapore</option><option value="SK">🇸🇰 Slovakia</option><option value="US" selected>🇺🇸 USA</option>
            </select>
        </div>
        <div class="peditx-row" style="justify-content: center; padding-top: 20px;"><button id="applyBtn" class="peditx-btn btn-save-changes">Save & Apply Settings</button></div>
    </div>

    <div class="settings-section">
        <h3>Auto-Reconnect</h3>
        <div class="peditx-row"><span class="peditx-label">Status:</span><span id="reconnectStatus" class="peditx-value">Disabled</span></div>
        <div class="controls-group">
            <input type="checkbox" id="reconnectEnabled" style="transform: scale(1.5);">
            <label for="reconnectEnabled">Enable</label>
            <input type="number" id="reconnectInterval" min="1" value="120" style="width: 80px;">
            <label for="reconnectInterval">Minutes</label>
        </div>
        <div class="peditx-row" style="justify-content: center; padding-top: 20px;"><button id="reconnectSaveBtn" class="peditx-btn btn-save-changes" style="background-color: #5bc0de;">Save Reconnect Settings</button></div>
    </div>

    <div class="settings-section">
        <h3>Warp++ Scanner</h3>
        <div class="controls-group">
            <label>Scan Density: <select id="scanDensity"><option value="1">Quick (100)</option><option value="2" selected>Normal (1000)</option><option value="3">Deep (10000)</option></select></label>
            <label>IP Version: <select id="ipVersion"><option value="1">IPv4</option><option value="2">IPv6</option><option value="3">Both</option></select></label>
            <label>Results: <input type="number" id="outputCount" value="10" min="1" max="100" style="width: 70px;"></label>
        </div>
        <div class="peditx-row" style="justify-content: center; padding-top: 20px;"><button id="startScanBtn" class="peditx-btn" style="background-color: #28a745;">Start New Scan</button></div>
        <div class="log-container">
            <h4>Scan Status: <span id="scanStatusText">Idle</span></h4>
            <div id="scan-results-container" style="display: none;">
                <h4>Scan Results</h4>
                <table id="scan-results-table"><thead><tr><th>Endpoint</th><th>Loss</th><th>Latency</th><th>Action</th></tr></thead><tbody></tbody></table>
            </div>
            <pre id="scan-log-output" class="log-output">Press 'Start New Scan' to begin...</pre>
        </div>
    </div>

    <div class="log-container">
        <h3>Service Debug Log</h3>
        <pre id="debug-log-output" class="log-output">Waiting for service actions...</pre>
    </div>
</div>

<script type="text/javascript">
document.addEventListener('DOMContentLoaded', function() {
    const E = id => document.getElementById(id);
    const deepCopy = obj => JSON.parse(JSON.stringify(obj));
    const elements = {
        indicator: E('statusIndicator'), text: E('statusText'), ip: E('ipText'), ipFlag: E('ipFlag'),
        connect: E('connectBtn'), disconnect: E('disconnectBtn'), configuredMode: E('configuredModeText'),
        applyBtn: E('applyBtn'), countryContainer: E('country-selector'), countrySelect: E('country-select'),
        modeButtons: document.querySelectorAll('.mode-btn'), notificationBar: E('notification-bar'),
        reconnectStatus: E('reconnectStatus'), reconnectEnabled: E('reconnectEnabled'),
        reconnectInterval: E('reconnectInterval'), reconnectSaveBtn: E('reconnectSaveBtn'),
        scanDensity: E('scanDensity'), ipVersion: E('ipVersion'), outputCount: E('outputCount'),
        startScanBtn: E('startScanBtn'), scanStatusText: E('scanStatusText'),
        scanLogOutput: E('scan-log-output'), scanResultsContainer: E('scan-results-container'),
        scanResultsTableBody: E('scan-results-table').querySelector('tbody'),
        debugLog: E('debug-log-output'),
        allControls: document.querySelectorAll('.peditx-btn, select, input')
    };

    let uiState = {}, configState = {}, dynamicState = { running: false, ip: 'N/A' };
    let isBusy = false, isScanning = false, initialLoadComplete = false;
    let scanPollInterval, mainPollInterval, debugLogInterval;

    const callAPI = (params, callback) => {
        const url = '<%=luci.dispatcher.build_url("admin/peditxos/warpplusplus_api")%>' + params;
        const cacheBuster = (url.includes('?') ? '&' : '?') + '_t=' + new Date().getTime();
        XHR.get(url + cacheBuster, null, (x, data) => {
            if (data) {
                if (data.error) {
                    showNotification(`Backend Error: ${data.message}`, true);
                }
                callback(data);
            } else {
                showNotification('API Error: No data received.', true);
                setBusy(false);
            }
        });
    };

    const showNotification = (message, isError = false) => {
        elements.notificationBar.textContent = message;
        elements.notificationBar.style.backgroundColor = isError ? '#dc3545' : '#28a745';
        elements.notificationBar.style.display = 'block';
        setTimeout(() => { elements.notificationBar.style.display = 'none'; }, 4000);
    };

    function setBusy(busy, message = '') {
        isBusy = busy;
        elements.allControls.forEach(el => { el.disabled = busy || isScanning; });
        if (busy && message) elements.text.innerText = message;
    }

    function getFlagEmoji(countryCode) {
        if (!countryCode || countryCode.length !== 2 || countryCode === "N/A") return '';
        const codePoints = countryCode.toUpperCase().split('').map(char => 127397 + char.charCodeAt());
        return String.fromCodePoint(...codePoints);
    }

    function updateUI() {
        if (!initialLoadComplete) return;
        elements.indicator.className = 'peditx-status-indicator ' + (dynamicState.running ? 'status-connected' : 'status-disconnected');
        elements.text.innerText = isBusy ? elements.text.innerText : (dynamicState.running ? 'Connected' : 'Disconnected');
        elements.ip.innerText = dynamicState.ip || 'N/A';
        elements.ipFlag.innerText = getFlagEmoji(dynamicState.ipCountryCode) + ' ';
        elements.connect.style.display = dynamicState.running ? 'none' : 'inline-block';
        elements.disconnect.style.display = dynamicState.running ? 'inline-block' : 'none';

        let modeText = {scan: 'Default (Scan)', gool: 'Gool', cfon: 'Psiphon', endpoint: 'Custom Endpoint'}[configState.mode] || 'N/A';
        if (configState.mode === 'cfon') modeText += ` (${configState.country})`;
        if (configState.mode === 'endpoint') modeText += ` (${configState.custom_endpoint || 'Not Set'})`;
        elements.configuredMode.innerText = modeText;

        elements.modeButtons.forEach(btn => btn.classList.toggle('selected-mode', btn.dataset.mode === uiState.mode));
        elements.countryContainer.style.display = (uiState.mode === 'cfon') ? 'flex' : 'none';
        if(uiState.mode === 'cfon') elements.countrySelect.value = uiState.country;

        const serviceDirty = uiState.mode !== configState.mode || (uiState.mode === 'cfon' && uiState.country !== configState.country);
        elements.applyBtn.classList.toggle('dirty', serviceDirty);
        
        elements.reconnectStatus.innerText = configState.reconnect_enabled === '1' ? `Enabled (Every ${configState.reconnect_interval} mins)` : 'Disabled';
        elements.reconnectEnabled.checked = uiState.reconnect_enabled === '1';
        elements.reconnectInterval.value = uiState.reconnect_interval;
        const reconnectDirty = uiState.reconnect_enabled !== configState.reconnect_enabled || uiState.reconnect_interval !== configState.reconnect_interval;
        elements.reconnectSaveBtn.classList.toggle('dirty', reconnectDirty);
        
        elements.scanStatusText.innerText = isScanning ? 'Scanning...' : 'Idle';
        elements.startScanBtn.disabled = isScanning || isBusy;
    }

    function handleAPIActions() {
        elements.modeButtons.forEach(btn => btn.addEventListener('click', function() { uiState.mode = this.dataset.mode; updateUI(); }));
        elements.countrySelect.addEventListener('change', () => { uiState.country = elements.countrySelect.value; updateUI(); });
        elements.reconnectEnabled.addEventListener('change', () => { uiState.reconnect_enabled = elements.reconnectEnabled.checked ? '1' : '0'; updateUI(); });
        elements.reconnectInterval.addEventListener('input', () => { uiState.reconnect_interval = elements.reconnectInterval.value; updateUI(); });

        elements.connect.addEventListener('click', () => { setBusy(true, 'Connecting...'); callAPI('?action=toggle', () => setTimeout(() => pollSystemState(true), 5000)); });
        elements.disconnect.addEventListener('click', () => { setBusy(true, 'Disconnecting...'); callAPI('?action=toggle', () => setTimeout(() => pollSystemState(true), 5000)); });

        elements.applyBtn.addEventListener('click', () => {
            if (!elements.applyBtn.classList.contains('dirty')) return;
            setBusy(true, 'Applying Settings...');
            const params = `?action=save_settings&mode=${uiState.mode}&country=${elements.countrySelect.value}`;
            callAPI(params, () => { showNotification('Service settings applied. Restarting...'); setTimeout(() => pollSystemState(true), 8000); });
        });
        
        elements.reconnectSaveBtn.addEventListener('click', () => {
            if (!elements.reconnectSaveBtn.classList.contains('dirty')) return;
            setBusy(true, 'Saving Reconnect Settings...');
            const params = `?action=save_reconnect&enabled=${uiState.reconnect_enabled}&interval=${uiState.reconnect_interval}`;
            callAPI(params, () => { showNotification('Reconnect settings saved.'); pollSystemState(true); });
        });

        elements.startScanBtn.addEventListener('click', () => {
            if (isScanning || isBusy) return;
            isScanning = true;
            elements.scanLogOutput.textContent = 'Preparing to start scan...';
            elements.scanResultsContainer.style.display = 'none';
            updateUI();
            const params = `?action=start_scan&density=${elements.scanDensity.value}&ip_version=${elements.ipVersion.value}&output_count=${elements.outputCount.value}`;
            callAPI(params, () => { if (!scanPollInterval) scanPollInterval = setInterval(pollScanStatus, 3000); });
        });

        elements.scanResultsTableBody.addEventListener('click', function(e) {
            if (e.target && e.target.classList.contains('btn-use-endpoint')) {
                const endpoint = e.target.dataset.endpoint;
                setBusy(true, `Setting endpoint to ${endpoint}...`);
                callAPI(`?action=set_endpoint&endpoint=${encodeURIComponent(endpoint)}`, (data) => {
                    if(data.success) { showNotification(data.message); setTimeout(() => pollSystemState(true), 8000); }
                    else { showNotification('Failed to set endpoint.', true); setBusy(false); }
                });
            }
        });
    }

    function pollScanStatus() {
        callAPI('?action=get_scan_status', data => {
            if (!data) return;
            isScanning = data.scanning;
            if (elements.scanLogOutput.textContent !== data.log) {
                elements.scanLogOutput.textContent = data.log;
                elements.scanLogOutput.scrollTop = elements.scanLogOutput.scrollHeight;
            }
            if (!isScanning) {
                clearInterval(scanPollInterval);
                scanPollInterval = null;
                elements.scanResultsContainer.style.display = 'block';
                elements.scanResultsTableBody.innerHTML = '';
                if (data.results && data.results.length > 0) {
                    data.results.forEach(res => {
                        const row = elements.scanResultsTableBody.insertRow();
                        row.innerHTML = `<td>${res.endpoint}</td><td>${res.loss}</td><td>${res.latency}</td><td><button class="peditx-btn btn-use-endpoint" data-endpoint="${res.endpoint}">Use</button></td>`;
                    });
                } else {
                     elements.scanResultsTableBody.innerHTML = '<tr><td colspan="4">No results found. Check scan log.</td></tr>';
                }
            }
            updateUI();
        });
    }

    function pollDebugLog() {
        if (isBusy || isScanning || document.hidden) return;
        callAPI('?action=get_debug_log', data => {
            if (data && data.log && elements.debugLog.textContent !== data.log) {
                elements.debugLog.textContent = data.log;
                elements.debugLog.scrollTop = elements.debugLog.scrollHeight;
            }
        });
    }

    function pollSystemState(isFullSync = false) {
        if ((isBusy && !isFullSync) || document.hidden) return;
        callAPI('?action=status', newData => {
            if (!newData || typeof newData.running === 'undefined') {
                if(isFullSync) setBusy(false);
                return;
            }
            dynamicState = { ...dynamicState, ...newData };
            if (isFullSync) {
                configState = deepCopy(newData);
                uiState = deepCopy(newData);
                if (!initialLoadComplete) {
                    initialLoadComplete = true;
                    handleAPIActions();
                }
                setBusy(false);
            }
            updateUI();
        });
    }

    setBusy(true, 'Loading status...');
    pollSystemState(true);
    mainPollInterval = setInterval(() => pollSystemState(false), 7000);
    debugLogInterval = setInterval(pollDebugLog, 5000);
});
</script>
<%+footer%>
EoL
echo "LuCI UI files created successfully."


# --- 6. Create and Enable Service ---
echo -e "\n[Step 6/7] Creating and enabling the Warp++ service..."
# Create a template init.d script. LuCI will generate the real one on first save.
cat << 'EOF' > /etc/init.d/warpplusplus
#!/bin/sh /etc/rc.common

START=91
USE_PROCD=1
PROG=/usr/bin/warpplusplus
LOG_FILE="/tmp/warpplusplus_debug.log"

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" >> $LOG_FILE
}

start_service() {
    log "Starting Warp++ with default scan mode..."
    procd_open_instance
    procd_set_param command $PROG -b 127.0.0.1:8087 --scan
    procd_set_param stdout 1
    procd_set_param stderr 1
    procd_set_param respawn
    procd_close_instance
}

stop_service() {
    log "Stopping Warp++ service."
    procd_kill warpplusplus
}
EOF

chmod 755 /etc/init.d/warpplusplus
service warpplusplus enable
service warpplusplus start
echo "Warp++ service has been enabled and started."


# --- 7. Configure Passwall ---
echo -e "\n[Step 7/7] Configuring Passwall/Passwall2..."
if uci show passwall2 >/dev/null 2>&1; then
    uci -q batch <<-EOF
        delete passwall2.WarpPlusPlus
        set passwall2.WarpPlusPlus=nodes
        set passwall2.WarpPlusPlus.remarks='Warp++'
        set passwall2.WarpPlusPlus.type='Xray'
        set passwall2.WarpPlusPlus.protocol='socks'
        set passwall2.WarpPlusPlus.server='127.0.0.1'
        set passwall2.WarpPlusPlus.port='8087'
        commit passwall2
EOF
    echo "Passwall2 configured. Restarting Passwall2 service..."
    /etc/init.d/passwall2 restart >/dev/null 2>&1
    echo "Passwall2 configured successfully."
elif uci show passwall >/dev/null 2>&1; then
    uci -q batch <<-EOF
        delete passwall.WarpPlusPlus
        set passwall.WarpPlusPlus=nodes
        set passwall.WarpPlusPlus.remarks='Warp++'
        set passwall.WarpPlusPlus.type='Xray'
        set passwall.WarpPlusPlus.protocol='socks'
        set passwall.WarpPlusPlus.server='127.0.0.1'
        set passwall.WarpPlusPlus.port='8087'
        commit passwall
EOF
    echo "Passwall configured. Restarting Passwall service..."
    /etc/init.d/passwall restart >/dev/null 2>&1
    echo "Passwall configured successfully."
else
    echo "Neither Passwall nor Passwall2 found. Skipping configuration."
fi


# --- 8. Finalize ---
echo -e "\n[Step 8/8] Finalizing installation..."
rm -f /tmp/luci-indexcache
/etc/init.d/uhttpd restart
rm -f /tmp/warp.zip /tmp/warp-plus /tmp/README.md /tmp/LICENSE /tmp/scanner.tar.gz /tmp/BPB-Warp-Scanner
rm -rf /tmp/core

echo -e "\n================================================"
echo "      Warp++ Installation Completed! "
echo "================================================"
echo -e "\nPlease refresh your router's web page."
echo "You can find the new manager under: PeDitXOS Tools -> Warp++"
echo -e "\nMade By: PeDitX\n"

