# PowerShell installer for quick-shot Native Messaging Host on Windows
$ErrorActionPreference = "Stop"

Write-Host "========================================================" -ForegroundColor Cyan
Write-Host "Installing quick-shot Native Messaging Host (Windows)" -ForegroundColor Cyan
Write-Host "========================================================" -ForegroundColor Cyan

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$installDir = Join-Path $env:USERPROFILE ".quick-shot"

if (!(Test-Path $installDir)) {
    New-Item -ItemType Directory -Path $installDir -Force | Out-Null
}

Write-Host "[*] Copying host files to $installDir..."
Copy-Item (Join-Path $scriptDir "native-host\quick_screen_host.py") -Destination $installDir -Force
Copy-Item (Join-Path $scriptDir "native-host\quick-screen-host.bat") -Destination $installDir -Force

$batPath = Join-Path $installDir "quick-screen-host.bat"
$manifestPath = Join-Path $installDir "com.quickscreen.host.json"

$manifest = @{
    name = "com.quickscreen.host"
    description = "quick-shot Native Messaging Host for automatic saving to temp"
    path = $batPath
    type = "stdio"
    allowed_origins = @(
        "chrome-extension://lfjkmkbgdkejeefmjkcgakkeeajkccdo/",
        "chrome-extension://gnamflndgdnmkpjnkbocgkffdkmmbieh/"
    )
}

$manifestJson = $manifest | ConvertTo-Json -Depth 5
[System.IO.File]::WriteAllText($manifestPath, $manifestJson, [System.Text.Encoding]::UTF8)
Write-Host "[*] Generated manifest at $manifestPath"

$browsers = @(
    "HKCU:\Software\Google\Chrome\NativeMessagingHosts\com.quickscreen.host",
    "HKCU:\Software\Chromium\NativeMessagingHosts\com.quickscreen.host",
    "HKCU:\Software\Microsoft\Edge\NativeMessagingHosts\com.quickscreen.host",
    "HKCU:\Software\BraveSoftware\Brave-Browser\NativeMessagingHosts\com.quickscreen.host"
)

foreach ($regPath in $browsers) {
    try {
        $parent = Split-Path -Parent $regPath
        if (!(Test-Path $parent)) {
            New-Item -Path $parent -Force | Out-Null
        }
        New-Item -Path $regPath -Force | Out-Null
        Set-ItemProperty -Path $regPath -Name "(Default)" -Value $manifestPath
        Write-Host "    [+] Registered for $(Split-Path (Split-Path $parent -Parent) -Leaf)" -ForegroundColor Green
    } catch {
        Write-Warning "Failed to register at $($regPath): $_"
    }
}

Write-Host "========================================================" -ForegroundColor Cyan
Write-Host "Installation complete! Native host is ready." -ForegroundColor Green
Write-Host "========================================================" -ForegroundColor Cyan
