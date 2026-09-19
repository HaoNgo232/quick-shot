param(
    [string]$ExtensionId = ""
)

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

# Base known IDs
$allowedOrigins = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
[void]$allowedOrigins.Add("chrome-extension://lfjkmkbgdkejeefmjkcgakkeeajkccdo/")
[void]$allowedOrigins.Add("chrome-extension://gnamflndgdnmkpjnkbocgkffdkmmbieh/")
[void]$allowedOrigins.Add("chrome-extension://lmpelmbldegmgokigphaahjdbcnkmcci/")

if ($ExtensionId -and $ExtensionId.Trim() -ne "") {
    $cleanId = $ExtensionId.Trim().TrimEnd('/')
    if ($cleanId -notlike "chrome-extension://*") {
        $cleanId = "chrome-extension://$cleanId/"
    } else {
        $cleanId = "$cleanId/"
    }
    [void]$allowedOrigins.Add($cleanId)
    Write-Host "[*] Added explicit extension origin: $cleanId"
}

# Auto-detect extension IDs from browser preferences
Write-Host "[*] Auto-detecting extension IDs from browser profiles..."
$browserBases = @(
    (Join-Path $env:LOCALAPPDATA "Google\Chrome\User Data"),
    (Join-Path $env:LOCALAPPDATA "Microsoft\Edge\User Data"),
    (Join-Path $env:LOCALAPPDATA "BraveSoftware\Brave-Browser\User Data"),
    (Join-Path $env:LOCALAPPDATA "Chromium\User Data")
)

foreach ($base in $browserBases) {
    if (Test-Path $base) {
        $prefFiles = Get-ChildItem -Path $base -Filter "*Preferences" -Recurse -Depth 2 -File -ErrorAction SilentlyContinue
        foreach ($file in $prefFiles) {
            try {
                $content = Get-Content -Path $file.FullName -Raw -ErrorAction SilentlyContinue
                if ($content -and ($content -match "quick-shot" -or $content -match "quick-screen")) {
                    $json = $content | ConvertFrom-Json -ErrorAction SilentlyContinue
                    if ($json.extensions.settings) {
                        $json.extensions.settings.PSObject.Properties | ForEach-Object {
                            $valStr = ($_.Value | ConvertTo-Json -Compress -Depth 3)
                            if ($valStr -match "quick-shot" -or $valStr -match "quick-screen") {
                                $detectedOrigin = "chrome-extension://$($_.Name)/"
                                if ($allowedOrigins.Add($detectedOrigin)) {
                                    Write-Host "    [+] Detected extension ID: $($_.Name)" -ForegroundColor Green
                                }
                            }
                        }
                    }
                }
            } catch {}
        }
    }
}

$manifest = @{
    name = "com.quickscreen.host"
    description = "quick-shot Native Messaging Host for automatic saving to temp"
    path = $batPath
    type = "stdio"
    allowed_origins = @($allowedOrigins)
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
