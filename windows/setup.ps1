# Setup script for NUJS WiFi auto-login on Windows.

# --- Log everything to setup-log.txt ---
$LogFile = Join-Path $PSScriptRoot "setup-log.txt"
Start-Transcript -Path $LogFile -Force

Write-Host "PowerShell version: $($PSVersionTable.PSVersion)"
Write-Host "Script root: $PSScriptRoot"
Write-Host "Running as admin: $(([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator))"
Write-Host

# --- Unblock all files in this folder (removes "downloaded from internet" flag) ---
try {
    Get-ChildItem -Path $PSScriptRoot -Recurse | Unblock-File -ErrorAction SilentlyContinue
    Write-Host "[+] Files unblocked."
} catch {
    Write-Host "[*] Unblock skipped: $_"
}

try {

$TaskName = "NUJS-WiFi-AutoLogin"
$ScriptPath = "C:\Scripts\nujs-wifi-login.ps1"
$SourceScript = Join-Path $PSScriptRoot "nujs-wifi-login.ps1"

Write-Host "Source script path: $SourceScript"
Write-Host "Source script exists: $(Test-Path $SourceScript)"
Write-Host

Write-Host "=== NUJS WiFi Auto-Login Setup (Windows) ===" -ForegroundColor Cyan
Write-Host

# 1. Get credentials
$Username = Read-Host "Enter your NUJS username (e.g. 221087)"
$Password = Read-Host "Enter your NUJS password"

if (-not $Username -or -not $Password) {
    Write-Host "[!] Username and password are required." -ForegroundColor Red
    Stop-Transcript
    Read-Host "Press Enter to exit"
    exit 1
}

# 2. Copy and configure script
if (-not (Test-Path "C:\Scripts")) {
    New-Item -ItemType Directory -Path "C:\Scripts" | Out-Null
}

$content = Get-Content $SourceScript -Raw
$content = $content -replace 'REPLACE_WITH_YOUR_USERNAME', $Username
$content = $content -replace 'REPLACE_WITH_YOUR_PASSWORD', $Password
Set-Content -Path $ScriptPath -Value $content -Encoding UTF8

Write-Host "[+] Script installed to $ScriptPath" -ForegroundColor Green

# 3. Remove old task if it exists
try {
    Unregister-ScheduledTask -TaskName $TaskName -Confirm:$false -ErrorAction SilentlyContinue
} catch {}

# 4. Create scheduled task with multiple triggers
$action = New-ScheduledTaskAction -Execute "powershell.exe" -Argument "-ExecutionPolicy Bypass -WindowStyle Hidden -NonInteractive -File `"$ScriptPath`""

$triggerLogon = New-ScheduledTaskTrigger -AtLogOn
$triggerStartup = New-ScheduledTaskTrigger -AtStartup

$settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -StartWhenAvailable

Register-ScheduledTask -TaskName $TaskName -Action $action -Trigger @($triggerLogon, $triggerStartup) -Settings $settings -Description "Auto-login to NUJS campus WiFi captive portal" | Out-Null

Write-Host "[+] Scheduled task created with logon and startup triggers." -ForegroundColor Green

# 5. Add event-based triggers (wake from sleep + network connect) via XML
$xml = Export-ScheduledTask -TaskName $TaskName

$eventTriggers = @"
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
"@

$xml = $xml -replace '</Triggers>', "$eventTriggers`n  </Triggers>"

Unregister-ScheduledTask -TaskName $TaskName -Confirm:$false
Register-ScheduledTask -TaskName $TaskName -Xml $xml | Out-Null

Write-Host "[+] Wake-from-sleep and network-connect triggers added." -ForegroundColor Green

Write-Host
Write-Host "=== Setup complete! ===" -ForegroundColor Cyan
Write-Host "The script will auto-run on:"
Write-Host "  - Login / restart"
Write-Host "  - Wake from sleep"
Write-Host "  - WiFi network change"
Write-Host
Write-Host "Manual run:  powershell -File $ScriptPath"
Write-Host "Check logs:  type C:\Scripts\nujs-wifi-login.log"
Write-Host "Uninstall:   Run uninstall.ps1 as Administrator"
Write-Host "Test:        Double-click TEST.bat (while on NUJS WiFi)"

# Auto-test if on NUJS WiFi
$currentSSID = $null
try {
    $wlanOutput = netsh wlan show interfaces
    foreach ($line in $wlanOutput) {
        if ($line -match '^\s*SSID\s*:\s*(.+)$') {
            $currentSSID = $Matches[1].Trim()
            break
        }
    }
} catch {}

Write-Host
if ($currentSSID -eq 'NUJS-CAMPUS WiFi') {
    Write-Host "Detected NUJS-CAMPUS WiFi. Running auto-login test..." -ForegroundColor Cyan
    Stop-Transcript
    & powershell -NoProfile -ExecutionPolicy Bypass -NoExit -File (Join-Path $PSScriptRoot "test-wifi-login.ps1")
    exit
} else {
    Write-Host "Not on NUJS-CAMPUS WiFi right now (connected to: $currentSSID)." -ForegroundColor Yellow
    Write-Host "To test, connect to NUJS-CAMPUS WiFi and double-click TEST.bat." -ForegroundColor Yellow
}

} catch {
    Write-Host
    Write-Host "[!] ERROR: $_" -ForegroundColor Red
    Write-Host $_.ScriptStackTrace -ForegroundColor DarkRed
}

Stop-Transcript
Write-Host
Write-Host "Full log saved to: $LogFile"
Read-Host "Press Enter to close"
