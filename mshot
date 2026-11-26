<#
.SYNOPSIS
    MisterShot installer: downloads the latest release and starts the tray app.

.DESCRIPTION
    Usage (no admin rights required):
        irm https://overcumatosis.github.io/mshot | iex

    Downloads MisterShot.exe into %LOCALAPPDATA%\MisterShot, adds a shortcut
    to the user Startup folder, and launches it.
#>

$ErrorActionPreference = 'Stop'

$repo     = 'overcumatosis/mister-shot'
$asset    = 'MisterShot.exe'
$destDir  = Join-Path $env:LOCALAPPDATA 'MisterShot'
$exePath  = Join-Path $destDir $asset

Write-Host 'MisterShot installer' -ForegroundColor Cyan

New-Item -ItemType Directory -Force -Path $destDir | Out-Null

Write-Host "Looking up the latest release of $repo ..."
$release = Invoke-RestMethod -Uri "https://api.github.com/repos/$repo/releases/latest" -Headers @{ 'User-Agent' = 'MisterShot-Installer' }
$downloadUrl = ($release.assets | Where-Object { $_.name -eq $asset }).browser_download_url

if (-not $downloadUrl) {
    throw "Asset '$asset' was not found in the latest release of '$repo'."
}

Write-Host "Downloading $asset ..."
Invoke-WebRequest -Uri $downloadUrl -OutFile $exePath -UseBasicParsing

# Stop a running instance before replacing/starting.
Get-Process -Name 'MisterShot' -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue

# Autostart shortcut in the per-user Startup folder.
$startup = [Environment]::GetFolderPath('Startup')
$lnkPath = Join-Path $startup 'MisterShot.lnk'
$shell   = New-Object -ComObject WScript.Shell
$shortcut = $shell.CreateShortcut($lnkPath)
$shortcut.TargetPath       = $exePath
$shortcut.WorkingDirectory = $destDir
$shortcut.Description      = 'MisterShot - screenshot of the active window to clipboard'
$shortcut.Save()

Write-Host "Installed to $exePath"
Start-Process -FilePath $exePath

Write-Host 'Done. MisterShot is in the tray; Ctrl+Alt+S captures the active window.' -ForegroundColor Green
