# NUJS WiFi Auto-Login (Android — Automate)

Automatically logs into the NUJS-CAMPUS WiFi captive portal using Automate (free app, no limits).

## Requirements

- Android 7+ phone
- Automate app (free on Play Store, by LlamaLab)

## Setup

### 1. Install Automate

Download from Play Store: search "Automate" by **LlamaLab**. Grant all permissions it asks for (WiFi, background access).

On first launch, tap through the intro. Make sure it has permission to run in the background.

### 2. Create the Flow

Automate uses a flowchart UI. You'll connect blocks together.

Tap **+** (new flow) → tap the **pencil icon** to edit.

#### Add these blocks (tap + to add each one):

**Block 1 — WiFi trigger:**
1. Search for **WiFi connected?**
2. Add it to the flow
3. Tap the block to configure:
   - **SSID:** `NUJS-CAMPUS WiFi`
   - **Is connected:** YES
4. This block has two outputs: **YES** and **NO**

**Block 2 — Delay:**
1. Search for **Delay**
2. Add it and connect it to the **YES** output of Block 1
3. Configure:
   - **Seconds:** `5`

**Block 3 — Login request:**
1. Search for **HTTP request**
2. Add it and connect it after the Delay block
3. Configure:
   - **Method:** `POST`
   - **URL:** `http://172.24.66.1:8090/login.xml`
   - **Request headers:**
     ```
     Content-Type: application/x-www-form-urlencoded
     ```
   - **Request body:**
     ```
     mode=191&username=YOUR_USERNAME&password=YOUR_PASSWORD&a=0&producttype=0
     ```
     Replace `YOUR_USERNAME` and `YOUR_PASSWORD` with your actual credentials.

**Block 4 — Loop back:**
1. Connect the output of Block 3 back to Block 1
2. This makes it continuously watch for WiFi connections

The flow should look like:

```
[WiFi connected? NUJS-CAMPUS WiFi]
    |YES                |NO
    v                   (loops back to itself)
[Delay 5s]
    |
    v
[HTTP POST login.xml]
    |
    v
(back to WiFi connected?)
```

#### Save and start

1. Tap the **save icon** (floppy disk)
2. Name it `NUJS WiFi Auto-Login`
3. Tap **Start** (play button)

### 3. Add Screen Unlock Trigger (catches session timeouts)

Create a second flow for re-auth on screen unlock:

**Block 1 — Screen unlock trigger:**
1. Search for **Screen on/unlocked?**
2. Add it, set to: **Screen unlocked**

**Block 2 — WiFi check:**
1. Search for **WiFi connected?**
2. Configure SSID: `NUJS-CAMPUS WiFi`
3. Connect to **YES** output of Block 1

**Block 3 — Delay:**
1. Search for **Delay**, set to **3** seconds
2. Connect to **YES** output of Block 2

**Block 4 — Login request:**
1. Same HTTP POST as before:
   - **Method:** `POST`
   - **URL:** `http://172.24.66.1:8090/login.xml`
   - **Request headers:** `Content-Type: application/x-www-form-urlencoded`
   - **Request body:** `mode=191&username=YOUR_USERNAME&password=YOUR_PASSWORD&a=0&producttype=0`

**Block 5 — Loop back** to Block 1.

```
[Screen unlocked?]
    |YES
    v
[WiFi connected? NUJS-CAMPUS WiFi]
    |YES                |NO
    v                   (back to Screen unlocked?)
[Delay 3s]
    |
    v
[HTTP POST login.xml]
    |
    v
(back to Screen unlocked?)
```

Save and start this flow too.

### 4. Keep Automate Running

For reliable background operation:

1. Phone **Settings** → **Apps** → **Automate**
2. **Battery** → set to **Unrestricted**
3. In Automate → **Settings** (gear icon):
   - **Run on system startup:** ON
   - **Show notification:** ON (keeps the app alive)

## Testing

1. Connect to NUJS-CAMPUS WiFi
2. Open Automate → find "NUJS WiFi Auto-Login" → tap **Start**
3. Wait 5-10 seconds, check if internet works
4. Or: disconnect from NUJS WiFi, reconnect, and see if internet works automatically

## How It Works

- **Flow 1 (WiFi connect):** When you connect to NUJS-CAMPUS WiFi, it waits 5 seconds for DHCP, then sends the login POST to the Sophos portal
- **Flow 2 (Screen unlock):** Every time you unlock your phone while on NUJS WiFi, it re-authenticates (catches session timeouts)
- If already logged in, the portal just returns success again — no harm
- If not on NUJS WiFi, the WiFi check block skips the login — no wasted requests

## Notes

- Automate is **completely free** with no macro/flow limits
- No root required
- Both flows must be started once — after that they auto-start on boot (if the setting is enabled)
- The NO outputs should loop back to the start of each flow so they keep watching
