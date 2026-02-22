"""
Uninstall NUJS WiFi auto-login from Windows.
"""

import subprocess
import shutil
import os

TASK_NAME = "NUJS-WiFi-AutoLogin"
INSTALL_DIR = r"C:\Scripts\nujs-wifi"


def main():
    print("=== Uninstalling NUJS WiFi Auto-Login ===")

    result = subprocess.run(["schtasks", "/Delete", "/TN", TASK_NAME, "/F"],
                            capture_output=True, text=True)
    if result.returncode == 0:
        print("[+] Scheduled task removed.")
    else:
        print("[*] No scheduled task found.")

    if os.path.exists(INSTALL_DIR):
        shutil.rmtree(INSTALL_DIR, ignore_errors=True)
        print("[+] Script and config removed.")
    else:
        print("[*] Install directory not found.")

    print("=== Done ===")
    input("Press Enter to exit...")


if __name__ == "__main__":
    main()
