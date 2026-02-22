# NUJS WiFi Auto-Login

Automatic login utility for the NUJS campus WiFi network (Sophos/Cyberoam captive portal). Runs silently in the background and authenticates whenever you connect to the network, wake from sleep, or unlock your device.

## How It Works

The NUJS campus WiFi uses a Sophos captive portal at `172.24.66.1:8090` that requires manual browser login after every connection, sleep, or session timeout. This project automates that process across platforms:

1. Detects WiFi connection, wake-from-sleep, or screen unlock events
2. Checks if internet access is down and the captive portal is reachable
3. Sends an HTTP POST with your credentials to the portal's login API
4. If already authenticated, does nothing

## Platforms

### macOS

LaunchAgent watches for system configuration changes (WiFi connect, wake, login) and triggers a Python script that authenticates via the portal API. Credentials are stored in the macOS Keychain.

- **Requirements:** macOS 10.15+ (Python 3 pre-installed)
- **Setup:** Run `bash setup.sh` and enter credentials
- [Full instructions](mac/README.md)

### Windows (PowerShell)

Windows Task Scheduler triggers a PowerShell script on logon, startup, wake from sleep, and network connect events. Credentials are stored in Windows Credential Manager.

- **Requirements:** Windows 10/11 (PowerShell pre-installed)
- **Setup:** Double-click `CLICK-ME-TO-SETUP.bat` and enter credentials
- [Full instructions](windows/README.md)

### Windows (Python)

Same Task Scheduler approach as the PowerShell version, but implemented in Python. Avoids PowerShell execution policy and quoting issues.

- **Requirements:** Windows 10/11, Python 3.8+
- **Setup:** Double-click `CLICK-ME-TO-SETUP.bat` and enter credentials
- [Full instructions](windows-python/README.md)

### Android (Automate)

No-code solution using the free Automate app by LlamaLab. Two flows handle WiFi connection and screen unlock events, sending login requests via HTTP blocks.

- **Requirements:** Android 7+, Automate app (free, no limits)
- **Setup:** Create flows following the step-by-step guide
- [Full instructions](android/README.md)

### Android (Native App)

Native Kotlin app with a foreground service that monitors WiFi connectivity. Provides Start/Stop/Test controls and auto-starts on boot.

- **Requirements:** Android 8.0+ (API 26+), Android Studio to build
- **Setup:** Build in Android Studio, install, enter credentials, tap Start
- [Full instructions](android-app/README.md)

## Security

Credentials are never stored in plaintext script files:

- **macOS:** Stored in the system Keychain via `security` CLI
- **Windows (PowerShell):** Stored in Windows Credential Manager
- **Windows (Python):** Stored in Windows Credential Manager via `cmdkey`
- **Android Automate:** Credentials are embedded in the Automate flow (stored within the app's private data)
- **Android App:** Stored in SharedPreferences (app-private storage)

## License

MIT
