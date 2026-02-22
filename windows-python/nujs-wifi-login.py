"""
Auto-login script for NUJS-CAMPUS WiFi (Sophos/Cyberoam captive portal).
Windows version — uses netsh for SSID detection.
Credentials stored in config.json next to this script.
"""

import subprocess
import json
import time
import os
import sys
import urllib.request
import urllib.parse
from xml.etree import ElementTree

PORTAL_BASE = "http://172.24.66.1:8090"
TARGET_SSID = "NUJS-CAMPUS WiFi"
SCRIPT_DIR = os.path.dirname(os.path.abspath(sys.argv[0]))
CONFIG_FILE = os.path.join(SCRIPT_DIR, "config.json")
LOG_FILE = os.path.join(SCRIPT_DIR, "nujs-wifi-login.log")


def log(msg):
    ts = time.strftime("%Y-%m-%d %H:%M:%S")
    line = f"{ts} {msg}"
    print(line)
    try:
        with open(LOG_FILE, "a", encoding="utf-8") as f:
            f.write(line + "\n")
    except Exception:
        pass


def load_config():
    try:
        with open(CONFIG_FILE, "r") as f:
            return json.load(f)
    except Exception:
        return {}


def get_wifi_ssid():
    try:
        r = subprocess.run(["netsh", "wlan", "show", "interfaces"],
                           capture_output=True, text=True, timeout=5)
        for line in r.stdout.splitlines():
            if line.strip().startswith("SSID") and "BSSID" not in line:
                return line.split(":", 1)[1].strip()
    except Exception:
        pass
    return None


def internet_is_working():
    try:
        resp = urllib.request.urlopen("http://captive.apple.com/hotspot-detect.html", timeout=5)
        return "Success" in resp.read().decode("utf-8", errors="ignore")
    except Exception:
        return False


def portal_is_reachable():
    try:
        urllib.request.urlopen(PORTAL_BASE, timeout=3)
        return True
    except Exception:
        return False


def sophos_login(username, password):
    params = urllib.parse.urlencode({
        "mode": "191",
        "username": username,
        "password": password,
        "a": str(int(time.time() * 1000)),
        "producttype": "0",
    }).encode("utf-8")

    req = urllib.request.Request(
        f"{PORTAL_BASE}/login.xml",
        data=params,
        method="POST",
        headers={"Content-Type": "application/x-www-form-urlencoded"},
    )
    resp = urllib.request.urlopen(req, timeout=10)
    body = resp.read().decode("utf-8", errors="ignore")
    root = ElementTree.fromstring(body)
    status = root.findtext("status", "").strip()
    message = root.findtext("message", "").strip()
    return status, message


def main():
    # Check SSID
    ssid = get_wifi_ssid()
    log(f"[*] Current WiFi: {ssid or '(none)'}")

    if ssid and ssid != TARGET_SSID:
        log("[*] Not on NUJS-CAMPUS WiFi. Nothing to do.")
        return

    # Check internet
    if internet_is_working():
        log("[*] Internet already working. No login needed.")
        return

    # Wait for portal (network may still be initializing)
    portal_ready = False
    for attempt in range(1, 11):
        if portal_is_reachable():
            portal_ready = True
            break
        log(f"[*] Waiting for portal... attempt {attempt}/10")
        time.sleep(3)

    if not portal_ready:
        log("[*] Portal not reachable after 30s. Not on NUJS network.")
        return

    log("[*] Internet down, portal reachable - logging in...")

    # Load credentials
    cfg = load_config()
    username = cfg.get("username", "")
    password = cfg.get("password", "")

    if not username or not password:
        log("[*] No credentials found in config.json. Run setup first.")
        return

    try:
        status, message = sophos_login(username, password)
        log(f"[*] Portal response: status={status}, message={message}")
        if status == "LIVE":
            log("[+] Logged in successfully!")
        else:
            log(f"[*] Login returned unexpected status: {status}")
    except Exception as e:
        log(f"[*] Login request failed: {e}")


if __name__ == "__main__":
    main()
