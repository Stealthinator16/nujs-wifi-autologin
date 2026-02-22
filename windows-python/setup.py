"""
Setup script for NUJS WiFi auto-login on Windows.
Installs the script, saves credentials, creates a Scheduled Task.
"""

import subprocess
import shutil
import json
import os
import sys
import tempfile

TASK_NAME = "NUJS-WiFi-AutoLogin"
INSTALL_DIR = r"C:\Scripts\nujs-wifi"
SCRIPT_DIR = os.path.dirname(os.path.abspath(sys.argv[0]))
LOG_FILE = os.path.join(SCRIPT_DIR, "setup-log.txt")


def log(msg):
    print(msg)
    try:
        with open(LOG_FILE, "a", encoding="utf-8") as f:
            f.write(msg + "\n")
    except Exception:
        pass


def is_admin():
    try:
        import ctypes
        return ctypes.windll.shell32.IsUserAnAdmin() != 0
    except Exception:
        return False


def main():
    log("=== NUJS WiFi Auto-Login Setup (Windows - Python) ===")
    log(f"Python: {sys.version}")
    log(f"Admin: {is_admin()}")
    log("")

    # Get credentials
    username = input("Enter your NUJS username (e.g. 221087): ").strip()
    password = input("Enter your NUJS password: ").strip()

    if not username or not password:
        log("[!] Username and password are required.")
        input("Press Enter to exit...")
        return

    # Install script
    os.makedirs(INSTALL_DIR, exist_ok=True)

    src_script = os.path.join(SCRIPT_DIR, "nujs-wifi-login.py")
    dst_script = os.path.join(INSTALL_DIR, "nujs-wifi-login.py")
    shutil.copy2(src_script, dst_script)
    log(f"[+] Script installed to {dst_script}")

    # Save credentials
    config_file = os.path.join(INSTALL_DIR, "config.json")
    with open(config_file, "w") as f:
        json.dump({"username": username, "password": password}, f)
    log("[+] Credentials saved to config.json")

    # Find python path
    python_path = sys.executable
    # Use pythonw.exe for the scheduled task (no console window flash)
    exe_name = os.path.basename(python_path)
    if "pythonw" not in exe_name.lower():
        pythonw_path = os.path.join(os.path.dirname(python_path), exe_name.replace("python", "pythonw"))
        if os.path.exists(pythonw_path):
            python_path = pythonw_path
    log(f"[*] Using Python: {python_path}")

    # Remove old task
    subprocess.run(
        ["schtasks", "/Delete", "/TN", TASK_NAME, "/F"],
        capture_output=True
    )

    # Create scheduled task via XML (supports event triggers that schtasks CLI can't do)
    task_xml = f"""<?xml version="1.0" encoding="UTF-16"?>
<Task version="1.2" xmlns="http://schemas.microsoft.com/windows/2004/02/mit/task">
  <Triggers>
    <LogonTrigger>
      <Enabled>true</Enabled>
    </LogonTrigger>
    <BootTrigger>
      <Enabled>true</Enabled>
      <Delay>PT15S</Delay>
    </BootTrigger>
    <EventTrigger>
      <Enabled>true</Enabled>
      <Subscription>&lt;QueryList&gt;&lt;Query Id="0" Path="System"&gt;&lt;Select Path="System"&gt;*[System[Provider[@Name='Microsoft-Windows-Power-Troubleshooter'] and EventID=1]]&lt;/Select&gt;&lt;/Query&gt;&lt;/QueryList&gt;</Subscription>
      <Delay>PT5S</Delay>
    </EventTrigger>
    <EventTrigger>
      <Enabled>true</Enabled>
      <Subscription>&lt;QueryList&gt;&lt;Query Id="0" Path="Microsoft-Windows-NetworkProfile/Operational"&gt;&lt;Select Path="Microsoft-Windows-NetworkProfile/Operational"&gt;*[System[EventID=10000]]&lt;/Select&gt;&lt;/Query&gt;&lt;/QueryList&gt;</Subscription>
      <Delay>PT3S</Delay>
    </EventTrigger>
  </Triggers>
  <Settings>
    <MultipleInstancesPolicy>IgnoreNew</MultipleInstancesPolicy>
    <DisallowStartIfOnBatteries>false</DisallowStartIfOnBatteries>
    <StopIfGoingOnBatteries>false</StopIfGoingOnBatteries>
    <AllowHardTerminate>true</AllowHardTerminate>
    <StartWhenAvailable>true</StartWhenAvailable>
    <AllowStartOnDemand>true</AllowStartOnDemand>
    <Enabled>true</Enabled>
    <Hidden>false</Hidden>
    <ExecutionTimeLimit>PT5M</ExecutionTimeLimit>
  </Settings>
  <Actions>
    <Exec>
      <Command>{python_path}</Command>
      <Arguments>"{dst_script}"</Arguments>
    </Exec>
  </Actions>
</Task>"""

    # Write XML to temp file and import
    xml_path = os.path.join(tempfile.gettempdir(), "nujs-wifi-task.xml")
    with open(xml_path, "w", encoding="utf-16") as f:
        f.write(task_xml)

    result = subprocess.run(
        ["schtasks", "/Create", "/TN", TASK_NAME, "/XML", xml_path, "/F"],
        capture_output=True, text=True
    )

    os.remove(xml_path)

    if result.returncode == 0:
        log("[+] Scheduled task created with triggers:")
        log("      - At logon")
        log("      - At startup")
        log("      - On wake from sleep")
        log("      - On network connect")
    else:
        log(f"[!] Failed to create scheduled task: {result.stderr.strip()}")
        log("[*] You may need to run this as Administrator.")
        input("Press Enter to exit...")
        return

    log("")
    log("=== Setup complete! ===")
    log(f"Manual run:  python \"{dst_script}\"")
    log(f"Check logs:  type \"{os.path.join(INSTALL_DIR, 'nujs-wifi-login.log')}\"")
    log(f"Uninstall:   double-click UNINSTALL.bat")
    log(f"Test:        double-click TEST.bat")
    log("")
    log(f"Setup log saved to: {LOG_FILE}")

    # Auto-test if on NUJS WiFi
    try:
        r = subprocess.run(["netsh", "wlan", "show", "interfaces"],
                           capture_output=True, text=True, timeout=5)
        ssid = None
        for line in r.stdout.splitlines():
            if line.strip().startswith("SSID") and "BSSID" not in line:
                ssid = line.split(":", 1)[1].strip()
                break

        if ssid == "NUJS-CAMPUS WiFi":
            log("")
            log("Detected NUJS-CAMPUS WiFi. Running full pipeline test...")
            log("")
            test_script = os.path.join(SCRIPT_DIR, "test-wifi-login.py")
            subprocess.run([sys.executable, test_script])
            return
        else:
            log(f"Not on NUJS-CAMPUS WiFi (connected to: {ssid or 'none'}).")
            log("To test, connect to NUJS WiFi and double-click TEST.bat.")
    except Exception:
        pass

    input("Press Enter to exit...")


if __name__ == "__main__":
    main()
