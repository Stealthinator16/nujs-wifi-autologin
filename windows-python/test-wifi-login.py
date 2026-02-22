"""
End-to-end test for NUJS WiFi auto-login on Windows.
Disconnects WiFi, reconnects, waits for the Scheduled Task to auto-login.
"""

import subprocess
import time
import os
import sys
import urllib.request

TARGET_SSID = "NUJS-CAMPUS WiFi"
INSTALL_DIR = r"C:\Scripts\nujs-wifi"
LOGIN_SCRIPT = os.path.join(INSTALL_DIR, "nujs-wifi-login.py")
LOGIN_LOG = os.path.join(INSTALL_DIR, "nujs-wifi-login.log")
SCRIPT_DIR = os.path.dirname(os.path.abspath(sys.argv[0]))
TEST_LOG = os.path.join(SCRIPT_DIR, "test-log.txt")
TASK_NAME = "NUJS-WiFi-AutoLogin"


def log(msg):
    print(msg)
    try:
        with open(TEST_LOG, "a", encoding="utf-8") as f:
            f.write(msg + "\n")
    except Exception:
        pass


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


def main():
    # Clear test log
    with open(TEST_LOG, "w", encoding="utf-8") as f:
        f.write("")

    log("=== NUJS WiFi Auto-Login - Full Pipeline Test ===")
    log("")

    # Step 1: Prerequisites
    log("[1/6] Checking prerequisites...")

    if not os.path.exists(LOGIN_SCRIPT):
        log("      Login script not found. Run setup first.")
        input("Press Enter to exit...")
        return
    log("      Login script found.")

    result = subprocess.run(["schtasks", "/Query", "/TN", TASK_NAME],
                            capture_output=True, text=True)
    if result.returncode != 0:
        log("      Scheduled task not found. Run setup first.")
        input("Press Enter to exit...")
        return
    log("      Scheduled task found.")

    # Step 2: Check WiFi
    log("[2/6] Checking current WiFi...")
    ssid = get_wifi_ssid()
    log(f"      Connected to: {ssid or 'none'}")

    if ssid != TARGET_SSID:
        log(f"      Not on {TARGET_SSID}. Connect to it first.")
        input("Press Enter to exit...")
        return
    log("      On NUJS-CAMPUS WiFi.")

    # Step 3: Verify internet works
    log("[3/6] Verifying internet works before test...")
    if not internet_is_working():
        log("      Internet not working. Log in manually first, then run this test.")
        input("Press Enter to exit...")
        return
    log("      Internet is working.")

    # Step 4: Record log size
    log_size_before = 0
    if os.path.exists(LOGIN_LOG):
        log_size_before = os.path.getsize(LOGIN_LOG)

    # Step 5: Disconnect and reconnect WiFi
    log("[4/6] Disconnecting from WiFi...")
    subprocess.run(["netsh", "wlan", "disconnect"], capture_output=True)
    time.sleep(2)

    ssid_now = get_wifi_ssid()
    if ssid_now:
        log(f"      Still connected to: {ssid_now} (disconnect may have failed)")
    else:
        log("      WiFi disconnected.")

    log("[5/6] Reconnecting to NUJS-CAMPUS WiFi...")
    log("      This will trigger the scheduled task.")
    log("      Waiting for auto-login (up to 60 seconds)...")
    subprocess.run(f'netsh wlan connect name="{TARGET_SSID}"', shell=True, capture_output=True)

    # Wait for internet
    success = False
    for i in range(1, 21):
        time.sleep(3)
        ssid_now = get_wifi_ssid()
        inet = internet_is_working()
        log(f"      attempt {i}/20 - WiFi: {ssid_now or 'none'}, Internet: {inet}")
        if inet:
            success = True
            break

    # Step 6: Results
    log("[6/6] Results")
    log("")

    script_ran = False
    if os.path.exists(LOGIN_LOG):
        log_size_after = os.path.getsize(LOGIN_LOG)
        if log_size_after > log_size_before:
            script_ran = True
            log("--- Login script log (last entries) ---")
            with open(LOGIN_LOG, "r", encoding="utf-8", errors="ignore") as f:
                lines = f.readlines()
                for line in lines[-10:]:
                    log(f"      {line.rstrip()}")
            log("---------------------------------------")
            log("")

    if success and script_ran:
        log("=== TEST PASSED ===")
        log("Full pipeline working: WiFi reconnect triggered the scheduled task,")
        log("which ran the login script, and internet is back up.")
    elif success and not script_ran:
        log("=== TEST INCONCLUSIVE ===")
        log("Internet came back but the login script did not appear to run.")
        log("The portal may have remembered the session. Try again after a timeout.")
    elif not success and script_ran:
        log("=== TEST FAILED ===")
        log("The login script ran but internet is still not working.")
        log("Check the log entries above for errors.")
    else:
        log("=== TEST FAILED ===")
        log("The scheduled task did not appear to trigger, and internet is down.")
        log("Open Task Scheduler and verify NUJS-WiFi-AutoLogin exists and is enabled.")

    log("")
    log(f"Full test log saved to: {TEST_LOG}")
    input("Press Enter to exit...")


if __name__ == "__main__":
    main()
