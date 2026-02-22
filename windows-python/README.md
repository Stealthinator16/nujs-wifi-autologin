# NUJS WiFi Auto-Login (Windows — Python)

Same approach as the macOS version, but for Windows. Background script + Scheduled Task.
No PowerShell headaches — everything is Python.

## Requirements

- Windows 10 or 11
- Python 3.8+ (download from https://www.python.org/downloads/)
  - **Important:** Check "Add Python to PATH" during install

## Setup

1. Copy this folder to the Desktop (or anywhere)
2. Double-click **`CLICK-ME-TO-SETUP.bat`**
3. Click **Yes** on the admin (UAC) prompt
4. Enter your NUJS username and password
5. If on NUJS WiFi, it auto-runs the full pipeline test

That's it. Runs in the background from now on.

## Manual Login

```
python "C:\Scripts\nujs-wifi\nujs-wifi-login.py"
```

## Testing

While on NUJS-CAMPUS WiFi, double-click **`TEST.bat`**. It will:
1. Check prerequisites (script + scheduled task)
2. Disconnect WiFi
3. Reconnect (triggers the scheduled task)
4. Wait up to 60 seconds for auto-login
5. Print **TEST PASSED** or **TEST FAILED**

## Logs

- **Setup log:** `setup-log.txt` in this folder
- **Test log:** `test-log.txt` in this folder
- **Login log:** `C:\Scripts\nujs-wifi\nujs-wifi-login.log`

## Uninstall

Double-click **`UNINSTALL.bat`**

## How It Works

1. A Scheduled Task triggers the Python script on:
   - Logon / startup
   - Wake from sleep (System Event ID 1)
   - Network connect (NetworkProfile Event ID 10000)
2. The script checks WiFi SSID via `netsh wlan show interfaces`
3. If on NUJS-CAMPUS WiFi and internet is down, waits up to 30s for the portal
4. POSTs credentials to the Sophos login API at `172.24.66.1:8090`
5. If internet already works, does nothing

## vs PowerShell version

- No execution policy issues
- No quoting/escaping bugs
- Same Task Scheduler triggers (XML import, not PowerShell cmdlets)
- Requires Python installed (the PowerShell version doesn't)
