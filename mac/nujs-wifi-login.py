#!/usr/bin/env python3
"""
Auto-login script for NUJS-CAMPUS WiFi (Sophos/Cyberoam captive portal).
Credentials stored in macOS Keychain.
"""

import subprocess
import sys
import time
import urllib.request
import urllib.parse
import urllib.error
from xml.etree import ElementTree

# ---- CONFIGURATION ----
PORTAL_BASE = "http://172.24.66.1:8090"
KEYCHAIN_SERVICE = "nujs-wifi-autologin"
USERNAME = "REPLACE_WITH_YOUR_USERNAME"
# Password is stored in macOS Keychain (run setup.sh to configure)
# -----------------------


def keychain_get_password():
    try:
        r = subprocess.run(
            ["security", "find-generic-password", "-s", KEYCHAIN_SERVICE, "-a", USERNAME, "-w"],
            capture_output=True, text=True,
        )
        if r.returncode == 0:
            return r.stdout.strip()
    except Exception:
        pass
    return None


def keychain_set_password(password):
    subprocess.run(
        ["security", "delete-generic-password", "-s", KEYCHAIN_SERVICE, "-a", USERNAME],
        capture_output=True,
    )
    r = subprocess.run(
        ["security", "add-generic-password", "-s", KEYCHAIN_SERVICE, "-a", USERNAME, "-w", password],
        capture_output=True, text=True,
    )
    return r.returncode == 0


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


def sophos_login(password):
    params = urllib.parse.urlencode({
        "mode": "191",
        "username": USERNAME,
        "password": password,
        "a": str(int(time.time() * 1000)),
        "producttype": "0",
    }).encode("utf-8")

    try:
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

        print(f"[*] Portal response — status: {status}, message: {message}")
        return status == "LIVE"

    except Exception as e:
        print(f"[!] Login request failed: {e}")
        return False


def main():
    if internet_is_working():
        print("[*] Internet already working. No login needed.")
        return

    # Wait for portal to become reachable (network may still be initializing after wake/connect)
    portal_ready = False
    for attempt in range(1, 11):
        if portal_is_reachable():
            portal_ready = True
            break
        print(f"[*] Waiting for portal... attempt {attempt}/10")
        time.sleep(3)

    if not portal_ready:
        print("[*] Portal not reachable after 30s — not on NUJS network.")
        return

    print("[*] Internet down, portal reachable — logging in...")

    password = keychain_get_password()
    if not password:
        password = input("Enter your NUJS WiFi password (saved to Keychain): ").strip()
        if not password:
            print("[!] No password. Exiting.")
            sys.exit(1)
        keychain_set_password(password)

    if sophos_login(password):
        print("[+] Logged in successfully!")
    else:
        print("[!] Login may have failed. Try running again or check credentials.")


if __name__ == "__main__":
    main()
