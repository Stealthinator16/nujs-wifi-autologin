# iOS / iPadOS (Shortcuts)

Uses the built-in Shortcuts app to automatically log in when your iPhone or iPad connects to the NUJS campus WiFi. No app install or sideloading required.

## Requirements

- iPhone or iPad running iOS 15.4+ (for fully automatic execution)
- iOS 15.0-15.3 works but requires tapping a notification to run

## Setup

### 1. Create the WiFi automation

1. Open the **Shortcuts** app
2. Go to the **Automation** tab
3. Tap **New Automation**
4. Select **Wi-Fi**
5. Tap **Choose** and select **NUJS-CAMPUS**
6. Make sure **When Connecting** is selected
7. Tap **Next**

### 2. Add the login action

1. Tap **New Blank Automation** (or **Add Action**)
2. Search for **Get Contents of URL** and add it
3. Configure the action:
   - **URL:** `http://172.24.66.1:8090/login.xml`
   - **Method:** POST
   - Tap **Add Header:**
     - **Key:** `Content-Type`
     - **Value:** `application/x-www-form-urlencoded`
   - **Request Body** (Form): Add these fields:
     - `mode` = `191`
     - `username` = your NUJS username
     - `password` = your NUJS password
     - `a` = `0`
     - `producttype` = `0`
4. Tap **Done**

### 3. Disable confirmation prompt

1. On the automation you just created, tap the toggle for **Ask Before Running** to turn it **off**
2. Confirm when prompted

The automation will now run silently whenever your device connects to NUJS-CAMPUS WiFi.

## Optional: session timeout recovery

Campus portal sessions expire after a period of inactivity. To handle this, create a second automation:

1. Create a new automation with trigger **Screen Unlock** (under Personal Automation)
2. Add the same **Get Contents of URL** action as above
3. Disable **Ask Before Running**

This re-authenticates every time you unlock your device, catching expired sessions.

## Credentials

Credentials are stored within the Shortcut definition itself, accessible only on-device. This is similar to how the Windows PowerShell version handles credentials.

## Limitations

- **iOS < 15.4:** Requires tapping a notification each time the automation triggers
- **No retry loop:** Unlike the Python-based implementations, Shortcuts sends a single POST. This is usually sufficient since the portal responds immediately.
- **No background monitoring:** Cannot continuously watch network state like the macOS LaunchAgent. Relies on the WiFi connection and screen unlock triggers.
