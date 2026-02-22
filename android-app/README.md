# NUJS WiFi AutoLogin — Android App

Native Android app that automatically logs into the NUJS-CAMPUS WiFi (Sophos/Cyberoam captive portal).

## What It Does

- Runs a foreground service that monitors WiFi connectivity
- Auto-logs in when you connect to NUJS-CAMPUS WiFi and internet is down
- Re-authenticates on screen unlock (catches session timeouts)
- Auto-starts on boot if credentials are saved

## Setup

1. Open this folder (`android-app/`) in Android Studio
2. Let Gradle sync
3. Build and install on your phone (`Run > Run 'app'`)
4. Grant the location permission when prompted (needed to read WiFi SSID)
5. Enter your NUJS WiFi username and password
6. Tap **Start**

## Buttons

| Button | What it does |
| :--- | :--- |
| **Start** | Saves credentials, starts the background auto-login service |
| **Stop** | Stops the background service |
| **Test** | If internet is down: tries to login. If internet is up: logs out then re-logs in to verify credentials work |

## Permissions

| Permission | Why |
| :--- | :--- |
| Internet | HTTP POST to the captive portal |
| WiFi/Network State | Detect connectivity changes |
| Fine Location | Read WiFi SSID (Android 8+ requirement) |
| Foreground Service | Keep the login service alive in background |
| Notifications | Show the persistent service notification (Android 13+) |
| Boot Completed | Auto-start service after phone reboot |

## Requirements

- Android 8.0+ (API 26+)
- Android Studio with Kotlin support
