# NUJS-CAMPUS WiFi Auto-Login (Sophos/Cyberoam captive portal)
# Place this file in C:\Scripts\ and run setup.ps1 to install.

# ---- CONFIGURATION ----
$Username = "REPLACE_WITH_YOUR_USERNAME"
$Password = "REPLACE_WITH_YOUR_PASSWORD"
$PortalBase = "http://172.24.66.1:8090"
$TargetSSID = "NUJS-CAMPUS WiFi"
# ------------------------

$LogFile = 'C:\Scripts\nujs-wifi-login.log'

function Write-Log($msg) {
    $ts = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
    "$ts $msg" | Out-File -Append -FilePath $LogFile -Encoding utf8
    Write-Output $msg
}

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

# Check which WiFi we're on
$ssid = Get-WiFiName
Write-Log "[*] Current WiFi: $ssid"

if ($ssid -and $ssid -ne $TargetSSID) {
    Write-Log '[*] Not on NUJS-CAMPUS WiFi. Nothing to do.'
    exit
}

# Check if internet already works
try {
    $r = Invoke-WebRequest -Uri 'http://captive.apple.com/hotspot-detect.html' -TimeoutSec 5 -UseBasicParsing -ErrorAction Stop
    if ($r.Content -match 'Success') {
        Write-Log '[*] Internet already working. No login needed.'
        exit
    }
} catch {}

# Wait for portal to become reachable (network may still be initializing)
$portalReady = $false
for ($i = 1; $i -le 10; $i++) {
    try {
        Invoke-WebRequest -Uri $PortalBase -TimeoutSec 3 -UseBasicParsing -ErrorAction Stop | Out-Null
        $portalReady = $true
        break
    } catch {
        Write-Log "[*] Waiting for portal... attempt $i/10"
        Start-Sleep -Seconds 3
    }
}

if (-not $portalReady) {
    Write-Log '[*] Portal not reachable after 30s. Giving up.'
    exit
}

# Log in
Write-Log '[*] Internet down, portal reachable - logging in...'

$ts = [DateTimeOffset]::Now.ToUnixTimeMilliseconds()
$body = "mode=191&username=$([uri]::EscapeDataString($Username))&password=$([uri]::EscapeDataString($Password))&a=$ts&producttype=0"

try {
    $resp = Invoke-WebRequest -Uri "$PortalBase/login.xml" -Method POST -Body $body -ContentType 'application/x-www-form-urlencoded' -TimeoutSec 10 -UseBasicParsing -ErrorAction Stop

    if ($resp.Content -match 'LIVE') {
        Write-Log '[+] Logged in successfully!'
    } else {
        try {
            $xml = [xml]$resp.Content
            $st = $xml.requestresponse.status
            $mg = $xml.requestresponse.message
            Write-Log "[*] Login response - status: $st, message: $mg"
        } catch {
            Write-Log '[*] Login may have failed. Check log.'
        }
    }
} catch {
    $err = $_.Exception.Message
    Write-Log "[*] Login request failed: $err"
}
