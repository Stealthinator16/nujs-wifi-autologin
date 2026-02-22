# End-to-end test for NUJS WiFi auto-login.
# Disconnects WiFi, reconnects, and waits for the scheduled task to auto-login.

$PortalBase = 'http://172.24.66.1:8090'
$TargetSSID = 'NUJS-CAMPUS WiFi'
$LoginScript = 'C:\Scripts\nujs-wifi-login.ps1'
$LoginLog = 'C:\Scripts\nujs-wifi-login.log'
$TestLog = Join-Path $PSScriptRoot 'test-log.txt'

Start-Transcript -Path $TestLog -Force

function Get-WiFiName {
    try {
        $output = netsh wlan show interfaces
        foreach ($line in $output) {
            if ($line -match '^\s*SSID\s*:\s*(.+)$') {
                return $Matches[1].Trim()
            }
        }
    } catch {}
    return $null
}

function Test-Internet {
    try {
        $r = Invoke-WebRequest -Uri 'http://captive.apple.com/hotspot-detect.html' -TimeoutSec 5 -UseBasicParsing -ErrorAction Stop
        return $r.Content -match 'Success'
    } catch {
        return $false
    }
}

Write-Host '=== NUJS WiFi Auto-Login - Full Pipeline Test ===' -ForegroundColor Cyan
Write-Host

# Step 1: Check prerequisites
Write-Host '[1/6] Checking prerequisites...' -ForegroundColor Yellow

if (-not (Test-Path $LoginScript)) {
    Write-Host '      Login script not found. Run setup first.' -ForegroundColor Red
    Stop-Transcript
    Read-Host 'Press Enter to exit'
    exit
}
Write-Host '      Login script found.' -ForegroundColor Green

$taskExists = Get-ScheduledTask -TaskName 'NUJS-WiFi-AutoLogin' -ErrorAction SilentlyContinue
if (-not $taskExists) {
    Write-Host '      Scheduled task not found. Run setup first.' -ForegroundColor Red
    Stop-Transcript
    Read-Host 'Press Enter to exit'
    exit
}
Write-Host '      Scheduled task found.' -ForegroundColor Green

# Step 2: Check current WiFi
Write-Host '[2/6] Checking current WiFi...' -ForegroundColor Yellow
$ssid = Get-WiFiName
Write-Host "      Connected to: $ssid"

if ($ssid -ne $TargetSSID) {
    Write-Host "      Not on '$TargetSSID'. Connect to it first, then run this test." -ForegroundColor Red
    Stop-Transcript
    Read-Host 'Press Enter to exit'
    exit
}
Write-Host "      On NUJS-CAMPUS WiFi." -ForegroundColor Green

# Step 3: Verify internet works right now
Write-Host '[3/6] Verifying internet works before test...' -ForegroundColor Yellow
if (-not (Test-Internet)) {
    Write-Host '      Internet not working. Log in manually first, then run this test.' -ForegroundColor Red
    Stop-Transcript
    Read-Host 'Press Enter to exit'
    exit
}
Write-Host '      Internet is working.' -ForegroundColor Green

# Step 4: Record login log size (to detect new entries later)
$logSizeBefore = 0
if (Test-Path $LoginLog) {
    $logSizeBefore = (Get-Item $LoginLog).Length
}

# Step 5: Disconnect WiFi entirely and reconnect
Write-Host '[4/6] Disconnecting from WiFi...' -ForegroundColor Yellow
netsh wlan disconnect | Out-Null
Start-Sleep -Seconds 2

# Verify disconnected
$ssidNow = Get-WiFiName
if ($ssidNow) {
    Write-Host "      Still connected to: $ssidNow (disconnect may have failed)" -ForegroundColor Yellow
} else {
    Write-Host '      WiFi disconnected.' -ForegroundColor Green
}

Write-Host '[5/6] Reconnecting to NUJS-CAMPUS WiFi...' -ForegroundColor Yellow
Write-Host '      This will trigger the scheduled task.' -ForegroundColor DarkGray
Write-Host '      Waiting for auto-login (up to 60 seconds)...' -ForegroundColor DarkGray
netsh wlan connect name=`"$TargetSSID`" | Out-Null

# Step 6: Wait for internet to come back (auto-login should handle it)
$success = $false
for ($i = 1; $i -le 20; $i++) {
    Start-Sleep -Seconds 3

    # Check if WiFi reconnected
    $ssidNow = Get-WiFiName
    $internetUp = Test-Internet

    $status = "attempt $i/20 - WiFi: $ssidNow, Internet: $internetUp"
    Write-Host "      $status" -ForegroundColor DarkGray

    if ($internetUp) {
        $success = $true
        break
    }
}

Write-Host '[6/6] Results' -ForegroundColor Yellow
Write-Host

# Check if the login script actually ran (new log entries)
$scriptRan = $false
if (Test-Path $LoginLog) {
    $logSizeAfter = (Get-Item $LoginLog).Length
    if ($logSizeAfter -gt $logSizeBefore) {
        $scriptRan = $true
        # Show new log entries
        $logContent = Get-Content $LoginLog -Tail 10
        Write-Host '--- Login script log (last entries) ---' -ForegroundColor DarkGray
        foreach ($line in $logContent) {
            Write-Host "      $line" -ForegroundColor DarkGray
        }
        Write-Host '---------------------------------------' -ForegroundColor DarkGray
        Write-Host
    }
}

if ($success -and $scriptRan) {
    Write-Host '=== TEST PASSED ===' -ForegroundColor Green
    Write-Host 'Full pipeline working: WiFi reconnect triggered the scheduled task,' -ForegroundColor Green
    Write-Host 'which ran the login script, and internet is back up.' -ForegroundColor Green
} elseif ($success -and -not $scriptRan) {
    Write-Host '=== TEST INCONCLUSIVE ===' -ForegroundColor Yellow
    Write-Host 'Internet came back but the login script did not appear to run.' -ForegroundColor Yellow
    Write-Host 'The portal may have remembered the session. Try again after a timeout.' -ForegroundColor Yellow
} elseif (-not $success -and $scriptRan) {
    Write-Host '=== TEST FAILED ===' -ForegroundColor Red
    Write-Host 'The login script ran but internet is still not working.' -ForegroundColor Red
    Write-Host 'Check the log entries above for errors.' -ForegroundColor Red
} else {
    Write-Host '=== TEST FAILED ===' -ForegroundColor Red
    Write-Host 'The scheduled task did not appear to trigger, and internet is down.' -ForegroundColor Red
    Write-Host 'Check Task Scheduler to verify NUJS-WiFi-AutoLogin exists and is enabled.' -ForegroundColor Red
}

Stop-Transcript
Write-Host
Write-Host "Full test log saved to: $TestLog"
Read-Host 'Press Enter to close'
