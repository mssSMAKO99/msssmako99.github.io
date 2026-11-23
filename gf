# GhostFrame one-line installer.
#
#   irm mssSMAKO99.github.io/gf | iex
#
# The same file is served with a descriptive name and from the project site:
#   irm https://mssSMAKO99.github.io/install.ps1 | iex
#   irm https://mssSMAKO99.github.io/GhostFrame/install.ps1 | iex
#
# It downloads a release build from GitHub, verifies its SHA-256, installs it
# under %LOCALAPPDATA%\GhostFrame\bin, adds a Start Menu shortcut and starts it.
#
# This file is kept ASCII-only and without a BOM on purpose: GitHub Pages serves
# .ps1 as application/octet-stream, and Windows PowerShell 5.1 then decodes the
# body as ANSI. A BOM or any non-ASCII byte would break `irm | iex`.
#
# Parameters:
#   -Version     'latest' (default) or an exact release tag such as 2.1.0.0
#   -InstallDir  where GhostFrame.exe goes (default %LOCALAPPDATA%\GhostFrame\bin)
#   -BaseUrl     override the release base URL (forks and tests)
#   -NoRun       install but do not start it
#   -Uninstall   stop GhostFrame, remove the program, the shortcut and the data

[CmdletBinding()]
param(
    [string]$Version = 'latest',

    [string]$InstallDir = (Join-Path $env:LOCALAPPDATA 'GhostFrame\bin'),

    [string]$BaseUrl = 'https://github.com/mssSMAKO99/GhostFrame/releases',

    [switch]$NoRun,

    [switch]$Uninstall
)

$ErrorActionPreference = 'Stop'

# Windows 10 builds older than 2004 still default to TLS 1.0.
try {
    $tls = [Net.ServicePointManager]::SecurityProtocol
    [Net.ServicePointManager]::SecurityProtocol = $tls -bor [Net.SecurityProtocolType]::Tls12
} catch {
    # Older .NET without Tls12 in the enum: leave the default alone.
}

$dataDir = Join-Path $env:LOCALAPPDATA 'GhostFrame'

function Get-AssetUrl {
    param([string]$Asset)

    if ($Version -eq 'latest') {
        return "$BaseUrl/latest/download/$Asset"
    }

    $tag = $Version
    if ($tag -notmatch '^v?\d') {
        $tag = "v$tag"
    }
    return "$BaseUrl/download/$tag/$Asset"
}

function Get-ShortcutPath {
    return (Join-Path $env:APPDATA 'Microsoft\Windows\Start Menu\Programs\GhostFrame.lnk')
}

function Get-Download {
    param([string]$Url, [string]$Destination)

    Write-Host "Downloading $Url"
    Invoke-WebRequest -Uri $Url -OutFile $Destination -UseBasicParsing
}

function Stop-GhostFrame {
    Get-Process -Name 'GhostFrame' -ErrorAction SilentlyContinue |
        Stop-Process -Force -ErrorAction SilentlyContinue
    # Give the process a moment to release the executable and its payloads.
    Start-Sleep -Milliseconds 500
}

function Install-GhostFrame {
    New-Item -ItemType Directory -Force -Path $InstallDir | Out-Null

    $tmp = Join-Path $env:TEMP ('GhostFrame-install-' + [Guid]::NewGuid().ToString('N'))
    New-Item -ItemType Directory -Force -Path $tmp | Out-Null

    $exeTmp = Join-Path $tmp 'GhostFrame.exe'
    $hashTmp = Join-Path $tmp 'GhostFrame.exe.sha256'

    try {
        Get-Download (Get-AssetUrl 'GhostFrame.exe') $exeTmp
        Get-Download (Get-AssetUrl 'GhostFrame.exe.sha256') $hashTmp

        $expected = (Get-Content -LiteralPath $hashTmp -Raw).Trim().Split()[0].ToLowerInvariant()
        $actual = (Get-FileHash -LiteralPath $exeTmp -Algorithm SHA256).Hash.ToLowerInvariant()
        if ($expected -ne $actual) {
            throw "SHA256 mismatch: expected $expected, got $actual"
        }
        Write-Host "SHA256 verified: $actual"

        $signature = Get-AuthenticodeSignature -LiteralPath $exeTmp
        if ($signature.Status -ne 'Valid') {
            Write-Warning "GhostFrame.exe is not digitally signed ($($signature.Status)). Compare the SHA256 above with the release page before running it."
        }

        $target = Join-Path $InstallDir 'GhostFrame.exe'
        if (Test-Path -LiteralPath $target) {
            Stop-GhostFrame
        }
        Copy-Item -LiteralPath $exeTmp -Destination $target -Force

        $shortcut = Get-ShortcutPath
        New-Item -ItemType Directory -Force -Path (Split-Path -Parent $shortcut) | Out-Null
        $shell = New-Object -ComObject WScript.Shell
        $link = $shell.CreateShortcut($shortcut)
        $link.TargetPath = $target
        $link.WorkingDirectory = $InstallDir
        $link.Description = 'GhostFrame'
        $link.Save()

        Write-Host "Installed: $target"
        Write-Host "Shortcut:  $shortcut"
    } finally {
        Remove-Item -LiteralPath $tmp -Recurse -Force -ErrorAction SilentlyContinue
    }

    if (-not $NoRun) {
        Start-Process -FilePath (Join-Path $InstallDir 'GhostFrame.exe')
    }
    Write-Host 'Done.'
}

function Uninstall-GhostFrame {
    Stop-GhostFrame

    foreach ($path in @($InstallDir, $dataDir)) {
        if (Test-Path -LiteralPath $path) {
            Write-Host "Removing $path"
            Remove-Item -LiteralPath $path -Recurse -Force -ErrorAction SilentlyContinue
        }
    }

    $shortcut = Get-ShortcutPath
    if (Test-Path -LiteralPath $shortcut) {
        Write-Host "Removing $shortcut"
        Remove-Item -LiteralPath $shortcut -Force -ErrorAction SilentlyContinue
    }

    Write-Host 'GhostFrame uninstalled.'
}

if ($Uninstall) {
    Uninstall-GhostFrame
} else {
    Install-GhostFrame
}
