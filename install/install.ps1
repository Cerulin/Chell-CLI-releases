#
# Chell CLI Installer for Windows (PowerShell)
#
# Usage:
#   irm https://raw.githubusercontent.com/Cerulin/Chell-CLI-Releases/main/install/install.ps1 | iex
#

$ErrorActionPreference = "Stop"

$GITHUB_REPO = "Cerulin/Chell-CLI-Releases"
$INSTALL_DIR = "$env:USERPROFILE\.chell"
$BIN_DIR = "$INSTALL_DIR\bin"

function Write-Info {
    param([string]$Message)
    Write-Host "[INFO] " -ForegroundColor Blue -NoNewline
    Write-Host $Message
}

function Write-Success {
    param([string]$Message)
    Write-Host "[OK] " -ForegroundColor Green -NoNewline
    Write-Host $Message
}

function Write-Warn {
    param([string]$Message)
    Write-Host "[WARN] " -ForegroundColor Yellow -NoNewline
    Write-Host $Message
}

function Write-Error-Exit {
    param([string]$Message)
    Write-Host "[ERROR] " -ForegroundColor Red -NoNewline
    Write-Host $Message
    exit 1
}

function Get-Platform {
    if ([Environment]::Is64BitOperatingSystem) {
        return "win32-x64"
    } else {
        Write-Error-Exit "Chell CLI does not support 32-bit Windows. Please use a 64-bit version."
    }
}

function Get-LatestVersion {
    try {
        $response = Invoke-RestMethod -Uri "https://api.github.com/repos/$GITHUB_REPO/releases/latest" -UseBasicParsing
        $version = $response.tag_name -replace '^v', ''
        return $version
    } catch {
        Write-Error-Exit "Failed to fetch latest version from GitHub: $_"
    }
}

function Get-FileChecksum {
    param([string]$FilePath)
    $hash = Get-FileHash -Path $FilePath -Algorithm SHA256
    return $hash.Hash.ToLower()
}

function Add-ToPath {
    $currentPath = [Environment]::GetEnvironmentVariable("PATH", "User")

    if ($currentPath -notlike "*$BIN_DIR*") {
        $newPath = "$BIN_DIR;$currentPath"
        [Environment]::SetEnvironmentVariable("PATH", $newPath, "User")
        Write-Success "Added $BIN_DIR to user PATH"
        Write-Info "Restart your terminal for PATH changes to take effect"
    } else {
        Write-Info "$BIN_DIR already in PATH"
    }
}

function Main {
    Write-Host ""
    Write-Host "Chell CLI Installer" -ForegroundColor Green
    Write-Host "================================"
    Write-Host ""

    # Detect platform
    $platform = Get-Platform
    Write-Info "Detected platform: $platform"

    # Get latest version
    Write-Info "Fetching latest version..."
    $version = Get-LatestVersion
    Write-Success "Latest version: v$version"

    # Create temp directory
    $tempDir = Join-Path $env:TEMP "chell-install-$(Get-Random)"
    New-Item -ItemType Directory -Path $tempDir -Force | Out-Null

    try {
        # Download manifest
        Write-Info "Downloading manifest..."
        $manifestUrl = "https://github.com/$GITHUB_REPO/releases/download/v$version/manifest.json"
        $manifestPath = Join-Path $tempDir "manifest.json"
        Invoke-WebRequest -Uri $manifestUrl -OutFile $manifestPath -UseBasicParsing

        # Parse manifest
        $manifest = Get-Content $manifestPath | ConvertFrom-Json
        $fileInfo = $manifest.files.$platform

        if (-not $fileInfo) {
            Write-Error-Exit "No binary available for platform: $platform"
        }

        $filename = $fileInfo.filename
        $expectedChecksum = $fileInfo.sha256

        # Download binary
        Write-Info "Downloading chell binary..."
        $binaryUrl = "https://github.com/$GITHUB_REPO/releases/download/v$version/$filename"
        $binaryPath = Join-Path $tempDir "chell.exe"
        Invoke-WebRequest -Uri $binaryUrl -OutFile $binaryPath -UseBasicParsing

        # Verify checksum
        Write-Info "Verifying checksum..."
        $actualChecksum = Get-FileChecksum -FilePath $binaryPath
        if ($actualChecksum -ne $expectedChecksum) {
            Write-Error-Exit "Checksum verification failed!`n  Expected: $expectedChecksum`n  Got:      $actualChecksum"
        }
        Write-Success "Checksum verified"

        # Install
        Write-Info "Installing to $BIN_DIR..."
        if (-not (Test-Path $BIN_DIR)) {
            New-Item -ItemType Directory -Path $BIN_DIR -Force | Out-Null
        }

        $destPath = Join-Path $BIN_DIR "chell.exe"
        Move-Item -Path $binaryPath -Destination $destPath -Force
        Write-Success "Binary installed"

        # Add to PATH
        Add-ToPath

        Write-Host ""
        Write-Host "Installation complete!" -ForegroundColor Green
        Write-Host ""
        Write-Host "To get started, restart your terminal and run: chell"
        Write-Host ""

    } finally {
        # Cleanup
        if (Test-Path $tempDir) {
            Remove-Item -Path $tempDir -Recurse -Force -ErrorAction SilentlyContinue
        }
    }
}

Main
