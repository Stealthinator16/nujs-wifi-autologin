#!/bin/bash
# End-to-end test for NUJS WiFi auto-login on macOS.
# Toggles WiFi off/on and waits for the LaunchAgent to auto-login.

PORTAL_BASE="http://172.24.66.1:8090"
LOGIN_SCRIPT="$HOME/scripts/nujs-wifi-login.py"
LOGIN_LOG="$HOME/scripts/nujs-wifi-login.log"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
TEST_LOG="$SCRIPT_DIR/test-log.txt"
PLIST_NAME="com.nujs.wifi-autologin"

# Log everything
exec > >(tee "$TEST_LOG") 2>&1

echo "=== NUJS WiFi Auto-Login - Full Pipeline Test ==="
echo

# Step 1: Check prerequisites
echo "[1/6] Checking prerequisites..."

if [ ! -f "$LOGIN_SCRIPT" ]; then
    echo "      Login script not found. Run setup.sh first."
    exit 1
fi
echo "      Login script found."

if ! launchctl list | grep -q "$PLIST_NAME"; then
    echo "      LaunchAgent not loaded. Run setup.sh first."
    exit 1
fi
echo "      LaunchAgent loaded."

# Step 2: Check if we can reach the portal or internet
# (macOS redacts SSID, so we check portal reachability instead)
echo "[2/6] Checking network..."

INTERNET_WORKS=0
if curl -s --max-time 5 "http://captive.apple.com/hotspot-detect.html" 2>/dev/null | grep -q "Success"; then
    INTERNET_WORKS=1
    echo "      Internet is working."
fi

PORTAL_UP=0
if curl -s --max-time 3 "$PORTAL_BASE" > /dev/null 2>&1; then
    PORTAL_UP=1
fi

if [ "$INTERNET_WORKS" -eq 0 ] && [ "$PORTAL_UP" -eq 0 ]; then
    echo "      No internet and portal not reachable."
    echo "      Connect to NUJS-CAMPUS WiFi and log in manually first, then run this test."
    exit 1
fi
echo "      On NUJS network."

# Step 3: Make sure internet is working before we test
if [ "$INTERNET_WORKS" -eq 0 ]; then
    echo "[3/6] Internet down — logging in first to establish baseline..."
    python3 "$LOGIN_SCRIPT"
    sleep 2
    if ! curl -s --max-time 5 "http://captive.apple.com/hotspot-detect.html" 2>/dev/null | grep -q "Success"; then
        echo "      Could not get internet working. Fix manually first."
        exit 1
    fi
fi
echo "[3/6] Internet confirmed working."

# Step 4: Record log size to detect new entries later
LOG_SIZE_BEFORE=0
if [ -f "$LOGIN_LOG" ]; then
    LOG_SIZE_BEFORE=$(wc -c < "$LOGIN_LOG" | tr -d ' ')
fi

# Step 5: Toggle WiFi off/on to trigger LaunchAgent
echo "[4/6] Turning WiFi off..."
networksetup -setairportpower en0 off
sleep 2

echo "[5/6] Turning WiFi back on..."
echo "      This triggers the LaunchAgent via network config change."
echo "      Waiting for auto-login (up to 60 seconds)..."
networksetup -setairportpower en0 on

SUCCESS=0
for i in $(seq 1 20); do
    sleep 3

    WIFI_UP="no"
    if ipconfig getifaddr en0 > /dev/null 2>&1; then
        WIFI_UP="yes"
    fi

    INET="no"
    if curl -s --max-time 5 "http://captive.apple.com/hotspot-detect.html" 2>/dev/null | grep -q "Success"; then
        INET="yes"
        SUCCESS=1
    fi

    echo "      attempt $i/20 - WiFi IP: $WIFI_UP, Internet: $INET"

    if [ "$SUCCESS" -eq 1 ]; then
        break
    fi
done

# Step 6: Results
echo "[6/6] Results"
echo

SCRIPT_RAN=0
if [ -f "$LOGIN_LOG" ]; then
    LOG_SIZE_AFTER=$(wc -c < "$LOGIN_LOG" | tr -d ' ')
    if [ "$LOG_SIZE_AFTER" -gt "$LOG_SIZE_BEFORE" ]; then
        SCRIPT_RAN=1
        echo "--- Login script log (last entries) ---"
        tail -10 "$LOGIN_LOG" | while read -r line; do
            echo "      $line"
        done
        echo "---------------------------------------"
        echo
    fi
fi

if [ "$SUCCESS" -eq 1 ] && [ "$SCRIPT_RAN" -eq 1 ]; then
    echo "=== TEST PASSED ==="
    echo "Full pipeline working: WiFi toggle triggered the LaunchAgent,"
    echo "which ran the login script, and internet is back up."
elif [ "$SUCCESS" -eq 1 ] && [ "$SCRIPT_RAN" -eq 0 ]; then
    echo "=== TEST INCONCLUSIVE ==="
    echo "Internet came back but the login script did not appear to run."
    echo "The portal may have remembered the session. Try again after a timeout."
elif [ "$SUCCESS" -eq 0 ] && [ "$SCRIPT_RAN" -eq 1 ]; then
    echo "=== TEST FAILED ==="
    echo "The login script ran but internet is still not working."
    echo "Check the log entries above for errors."
else
    echo "=== TEST FAILED ==="
    echo "The LaunchAgent did not appear to trigger, and internet is down."
    echo "Run: launchctl list | grep nujs  — to verify the agent is loaded."
fi

echo
echo "Full test log saved to: $TEST_LOG"
