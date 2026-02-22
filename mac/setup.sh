#!/bin/bash
# Setup script for NUJS WiFi auto-login on macOS.
# Run: bash setup.sh

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
INSTALL_DIR="$HOME/scripts"
PLIST_NAME="com.nujs.wifi-autologin"
LAUNCH_AGENTS_DIR="$HOME/Library/LaunchAgents"
KEYCHAIN_SERVICE="nujs-wifi-autologin"
PORTAL_BASE="http://172.24.66.1:8090"
SETUP_LOG="$SCRIPT_DIR/setup-log.txt"

# Log everything
exec > >(tee "$SETUP_LOG") 2>&1

echo "macOS version: $(sw_vers -productVersion)"
echo "Script dir: $SCRIPT_DIR"
echo

echo "=== NUJS WiFi Auto-Login Setup (macOS) ==="
echo

# 1. Get credentials
read -p "Enter your NUJS username (e.g. 221087): " USERNAME
read -s -p "Enter your NUJS password: " PASSWORD
echo

if [ -z "$USERNAME" ] || [ -z "$PASSWORD" ]; then
    echo "[!] Username and password are required."
    exit 1
fi

# 2. Copy script
mkdir -p "$INSTALL_DIR"
cp "$SCRIPT_DIR/nujs-wifi-login.py" "$INSTALL_DIR/nujs-wifi-login.py"
chmod +x "$INSTALL_DIR/nujs-wifi-login.py"

# Update username in the script
sed -i '' "s/REPLACE_WITH_YOUR_USERNAME/$USERNAME/" "$INSTALL_DIR/nujs-wifi-login.py"

echo "[+] Script installed to $INSTALL_DIR/nujs-wifi-login.py"

# 3. Store password in Keychain
security delete-generic-password -s "$KEYCHAIN_SERVICE" -a "$USERNAME" 2>/dev/null || true
security add-generic-password -s "$KEYCHAIN_SERVICE" -a "$USERNAME" -w "$PASSWORD"
echo "[+] Password saved to macOS Keychain."

# 4. Install LaunchAgent
mkdir -p "$LAUNCH_AGENTS_DIR"

# Unload old agent if present
launchctl unload "$LAUNCH_AGENTS_DIR/$PLIST_NAME.plist" 2>/dev/null || true

cat > "$LAUNCH_AGENTS_DIR/$PLIST_NAME.plist" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>$PLIST_NAME</string>
    <key>ProgramArguments</key>
    <array>
        <string>/usr/bin/python3</string>
        <string>$INSTALL_DIR/nujs-wifi-login.py</string>
    </array>
    <key>WatchPaths</key>
    <array>
        <string>/Library/Preferences/SystemConfiguration</string>
    </array>
    <key>StandardOutPath</key>
    <string>$INSTALL_DIR/nujs-wifi-login.log</string>
    <key>StandardErrorPath</key>
    <string>$INSTALL_DIR/nujs-wifi-login.log</string>
    <key>RunAtLoad</key>
    <true/>
</dict>
</plist>
EOF

launchctl load "$LAUNCH_AGENTS_DIR/$PLIST_NAME.plist"
echo "[+] LaunchAgent installed and loaded."

echo
echo "=== Setup complete! ==="
echo "The script will auto-run on:"
echo "  - Login / restart"
echo "  - Wake from sleep"
echo "  - WiFi network change"
echo
echo "Manual run:  python3 $INSTALL_DIR/nujs-wifi-login.py"
echo "Check logs:  cat $INSTALL_DIR/nujs-wifi-login.log"
echo "Uninstall:   bash $SCRIPT_DIR/uninstall.sh"
echo "Test:        bash $SCRIPT_DIR/test-wifi-login.sh"
echo
echo "Setup log saved to: $SETUP_LOG"

# Auto-test if portal is reachable or internet works on NUJS network
PORTAL_UP=0
curl -s --max-time 3 "$PORTAL_BASE" > /dev/null 2>&1 && PORTAL_UP=1

INTERNET_UP=0
curl -s --max-time 5 "http://captive.apple.com/hotspot-detect.html" 2>/dev/null | grep -q "Success" && INTERNET_UP=1

if [ "$PORTAL_UP" -eq 1 ] || [ "$INTERNET_UP" -eq 1 ]; then
    echo
    echo "Detected NUJS network. Running full pipeline test..."
    echo
    bash "$SCRIPT_DIR/test-wifi-login.sh"
else
    echo
    echo "Not on NUJS network right now."
    echo "To test, connect to NUJS-CAMPUS WiFi and run: bash test-wifi-login.sh"
fi
