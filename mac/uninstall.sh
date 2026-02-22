#!/bin/bash
# Uninstall NUJS WiFi auto-login from macOS.

PLIST_NAME="com.nujs.wifi-autologin"
LAUNCH_AGENTS_DIR="$HOME/Library/LaunchAgents"
INSTALL_DIR="$HOME/scripts"
KEYCHAIN_SERVICE="nujs-wifi-autologin"

echo "=== Uninstalling NUJS WiFi Auto-Login ==="

launchctl unload "$LAUNCH_AGENTS_DIR/$PLIST_NAME.plist" 2>/dev/null && echo "[+] LaunchAgent unloaded."
rm -f "$LAUNCH_AGENTS_DIR/$PLIST_NAME.plist" && echo "[+] Plist removed."
rm -f "$INSTALL_DIR/nujs-wifi-login.py" "$INSTALL_DIR/nujs-wifi-login.log" && echo "[+] Script and logs removed."
security delete-generic-password -s "$KEYCHAIN_SERVICE" 2>/dev/null && echo "[+] Keychain entry removed."

echo "=== Done ==="
