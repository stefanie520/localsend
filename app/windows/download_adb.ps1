# Downloads ADB Platform Tools and extracts the needed files into the adb/ directory.
# Run this script before building the Windows installer.

$platformToolsUrl = "https://dl.google.com/android/repository/platform-tools-latest-windows.zip"
$outputZip = "$PSScriptRoot\platform-tools.zip"
$extractDir = "$PSScriptRoot\platform-tools"
$adbDir = "$PSScriptRoot\adb"

Write-Host "Downloading Android SDK Platform Tools..." -ForegroundColor Green
Invoke-WebRequest -Uri $platformToolsUrl -OutFile $outputZip

Write-Host "Extracting..." -ForegroundColor Green
Expand-Archive -Path $outputZip -DestinationPath $extractDir -Force

Write-Host "Copying ADB files to $adbDir..." -ForegroundColor Green
if (-not (Test-Path $adbDir)) {
    New-Item -ItemType Directory -Path $adbDir -Force
}

Copy-Item "$extractDir\platform-tools\adb.exe" -Destination "$adbDir\adb.exe" -Force
Copy-Item "$extractDir\platform-tools\AdbWinApi.dll" -Destination "$adbDir\AdbWinApi.dll" -Force
Copy-Item "$extractDir\platform-tools\AdbWinUsbApi.dll" -Destination "$adbDir\AdbWinUsbApi.dll" -Force

# Cleanup
Remove-Item $outputZip -Force
Remove-Item $extractDir -Recurse -Force

Write-Host "Done! ADB files are ready in $adbDir" -ForegroundColor Green
