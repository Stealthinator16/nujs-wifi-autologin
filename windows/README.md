# NUJS WiFi Auto-Login (Windows)

Automatically logs into the NUJS-CAMPUS WiFi captive portal (Sophos/Cyberoam) on:
- Login / restart
- Wake from sleep
- WiFi network change

## Requirements

- Windows 10 or 11 (PowerShell is pre-installed)
- No additional software needed

## Setup

1. Copy this entire `windows` folder to the Desktop (or anywhere convenient)
2. Double-click **`CLICK-ME-TO-SETUP.bat`**
3. Click **Yes** on the admin (UAC) prompt
4. Enter your NUJS username and password when prompted
5. Press Enter to close when done

That's it. The script is now running in the background.

## Manual Login

Open PowerShell and run:
```
powershell -File C:\Scripts\nujs-wifi-login.ps1
```

## Logs

- **Setup log:** `setup-log.txt` in this folder (created every time you run setup)
- **Login log:** `C:\Scripts\nujs-wifi-login.log` (created every time the auto-login runs)

## Uninstall

Double-click `CLICK-ME-TO-SETUP.bat`, but run `uninstall.ps1` instead:
```
powershell -ExecutionPolicy Bypass -File uninstall.ps1
```

## How It Works

1. A Windows Scheduled Task is created with 4 triggers:
   - At logon
   - At startup
   - On wake from sleep (System Event ID 1)
   - On network connect (NetworkProfile Event ID 10000)
2. When triggered, the script checks if internet is down and the Sophos portal at `172.24.66.1:8090` is reachable
3. If both conditions are true, it POSTs your credentials to the portal's login API
4. If internet is already working, it does nothing

## Testing

While connected to NUJS-CAMPUS WiFi, double-click **`TEST.bat`**. It will:
1. Check if you're on the NUJS network
2. Disconnect you from the portal
3. Run the auto-login script
4. Verify internet came back
5. Print **TEST PASSED** or **TEST FAILED**

You can also run the test at the end of setup when it asks "Run a test now? (y/n)".

## Troubleshooting

- **Setup window closes immediately:** Check `setup-log.txt` in this folder for the error
- **Setup ran but auto-login isn't working:** Check `C:\Scripts\nujs-wifi-login.log` for error messages
- **Want to test manually:** Open Task Scheduler, find "NUJS-WiFi-AutoLogin", right-click > Run
