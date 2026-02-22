# Uninstall NUJS WiFi auto-login from Windows.
# Run as Administrator.

$TaskName = "NUJS-WiFi-AutoLogin"

Write-Host "=== Uninstalling NUJS WiFi Auto-Login ===" -ForegroundColor Cyan

try {
    Unregister-ScheduledTask -TaskName $TaskName -Confirm:$false -ErrorAction Stop
    Write-Host "[+] Scheduled task removed." -ForegroundColor Green
} catch {
    Write-Host "[*] No scheduled task found." -ForegroundColor Yellow
}

if (Test-Path "C:\Scripts\nujs-wifi-login.ps1") {
    Remove-Item "C:\Scripts\nujs-wifi-login.ps1" -Force
    Write-Host "[+] Script removed." -ForegroundColor Green
}

if (Test-Path "C:\Scripts\nujs-wifi-login.log") {
    Remove-Item "C:\Scripts\nujs-wifi-login.log" -Force
    Write-Host "[+] Log file removed." -ForegroundColor Green
}

Write-Host "=== Done ===" -ForegroundColor Cyan
