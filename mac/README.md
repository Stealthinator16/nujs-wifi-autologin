# NUJS WiFi Auto-Login (macOS)

Automatically logs into the NUJS-CAMPUS WiFi captive portal (Sophos/Cyberoam) on:
- Login / restart
- Wake from sleep
- WiFi network change

Password is stored securely in macOS Keychain.

## Requirements

- macOS 10.15+ (Python 3 is pre-installed)
- No additional dependencies needed

## Setup

1. Open Terminal
2. Navigate to this folder:
   ```
   cd /path/to/this/mac/folder
   ```
3. Run the setup script:
   ```
   bash setup.sh
   ```
4. Enter your NUJS username and password when prompted
5. If on NUJS WiFi, it will auto-run a full pipeline test

That's it. The script is now running in the background.

## Manual Login

```
python3 ~/scripts/nujs-wifi-login.py
```

## Testing

While connected to NUJS-CAMPUS WiFi, run:
```
bash test-wifi-login.sh
```

It will:
1. Check prerequisites (script installed, LaunchAgent loaded)
2. Turn WiFi off
3. Turn WiFi back on (triggers the LaunchAgent)
4. Wait up to 60 seconds for auto-login
5. Print **TEST PASSED** or **TEST FAILED**

The test does NOT manually run the login script — it verifies the full automation pipeline.

## Logs

- **Setup log:** `setup-log.txt` in this folder
- **Test log:** `test-log.txt` in this folder
- **Login log:** `~/scripts/nujs-wifi-login.log` (auto-login activity)

## Uninstall

```
bash uninstall.sh
```

## How It Works

1. A LaunchAgent watches `/Library/Preferences/SystemConfiguration` for changes (which happen on WiFi connect, wake from sleep, and login)
2. When triggered, the script waits up to 30 seconds for the portal at `172.24.66.1:8090` to become reachable
3. If internet is down and portal is reachable, it POSTs credentials to the Sophos login API
4. If internet is already working, it does nothing

## macOS vs Windows Differences

- macOS redacts the WiFi SSID for privacy, so the script checks portal reachability instead of SSID name
- Password is stored in macOS Keychain (not in the script file)
- Automation uses LaunchAgent + WatchPaths (instead of Windows Task Scheduler + event triggers)
