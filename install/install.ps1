#
# Chell CLI Installer for Windows (PowerShell)
#
# Usage:
#   irm https://raw.githubusercontent.com/Cerulin/Chell-CLI-releases/main/install/install.ps1 | iex
#

$ErrorActionPreference = "Stop"
$ProgressPreference = "SilentlyContinue"

$GITHUB_REPO = "Cerulin/Chell-CLI-releases"
$INSTALL_DIR = "$env:USERPROFILE\.chell"
$BIN_DIR = "$INSTALL_DIR\bin"
$BINARY_NAME = "chell-windows-amd64.exe"

function Write-Info    { param([string]$Msg) Write-Host "[INFO] " -ForegroundColor Blue -NoNewline; Write-Host $Msg }
function Write-Success { param([string]$Msg) Write-Host "[OK] " -ForegroundColor Green -NoNewline; Write-Host $Msg }
function Write-Warn    { param([string]$Msg) Write-Host "[WARN] " -ForegroundColor Yellow -NoNewline; Write-Host $Msg }
function Write-Fatal   { param([string]$Msg) Write-Host "[ERROR] " -ForegroundColor Red -NoNewline; Write-Host $Msg; exit 1 }

function Get-LatestVersion {
    try {
        $response = Invoke-RestMethod -Uri "https://api.github.com/repos/$GITHUB_REPO/releases/latest" -UseBasicParsing
        return $response.tag_name
    } catch {
        Write-Fatal "Failed to fetch latest version: $_"
    }
}

function Get-InstalledVersion {
    $chellPath = Join-Path $BIN_DIR "chell.exe"
    if (Test-Path $chellPath) {
        try {
            $output = & $chellPath --version 2>$null
            if ($output -match '(v?\d+\.\d+\.\d+)') {
                return $matches[1]
            }
        } catch {}
    }
    return $null
}

function Uninstall-NpmChell {
    if (Get-Command npm -ErrorAction SilentlyContinue) {
        $npmList = npm list -g @cerulin/chell 2>$null
        if ($LASTEXITCODE -eq 0 -and $npmList -match "chell") {
            Write-Warn "Found old npm version of chell. Uninstalling..."
            npm uninstall -g @cerulin/chell 2>$null
            if ($LASTEXITCODE -eq 0) {
                Write-Success "Removed npm @cerulin/chell"
            } else {
                Write-Warn "Could not remove npm @cerulin/chell. Run manually: npm uninstall -g @cerulin/chell"
            }
        }
    }
}

function Add-ToPath {
    $currentPath = [Environment]::GetEnvironmentVariable("PATH", "User")
    if ($currentPath -notlike "*$BIN_DIR*") {
        [Environment]::SetEnvironmentVariable("PATH", "$BIN_DIR;$currentPath", "User")
        Write-Success "Added $BIN_DIR to user PATH"
    } else {
        Write-Info "$BIN_DIR already in PATH"
    }
}

function Main {
    Write-Host ""
    Write-Host "Chell CLI Installer" -ForegroundColor Green
    Write-Host "================================"
    Write-Host ""

    # Check for old npm version
    Uninstall-NpmChell

    Write-Info "Platform: windows-amd64"

    # Get latest version
    Write-Info "Fetching latest version..."
    $version = Get-LatestVersion
    if (-not $version) { Write-Fatal "Failed to get latest version" }
    Write-Success "Latest version: $version"

    # Check if already up to date
    $installed = Get-InstalledVersion
    if ($installed) {
        $installedClean = $installed -replace '^v', ''
        $versionClean = $version -replace '^v', ''
        if ($installedClean -eq $versionClean) {
            Write-Success "Already up to date ($version)"
            return
        }
        Write-Info "Upgrading from $installed to $version"
    }

    # Temp directory
    $tempDir = Join-Path $env:TEMP "chell-install-$(Get-Random)"
    New-Item -ItemType Directory -Path $tempDir -Force | Out-Null

    try {
        $baseUrl = "https://github.com/$GITHUB_REPO/releases/download/$version"

        # Download binary
        Write-Info "Downloading $BINARY_NAME..."
        Invoke-WebRequest -Uri "$baseUrl/$BINARY_NAME" -OutFile "$tempDir\chell.exe" -UseBasicParsing

        # Verify checksum
        Write-Info "Verifying checksum..."
        Invoke-WebRequest -Uri "$baseUrl/checksums.sha256" -OutFile "$tempDir\checksums.sha256" -UseBasicParsing

        $checksumLine = Get-Content "$tempDir\checksums.sha256" | Where-Object { $_ -match $BINARY_NAME }
        if ($checksumLine) {
            $expected = ($checksumLine -split '\s+')[0]
            $actual = (Get-FileHash -Path "$tempDir\chell.exe" -Algorithm SHA256).Hash.ToLower()
            if ($actual -ne $expected) {
                Write-Fatal "Checksum mismatch!`n  Expected: $expected`n  Got:      $actual"
            }
            Write-Success "Checksum verified"
        } else {
            Write-Warn "Could not verify checksum"
        }

        # Install
        Write-Info "Installing to $BIN_DIR..."
        if (-not (Test-Path $BIN_DIR)) {
            New-Item -ItemType Directory -Path $BIN_DIR -Force | Out-Null
        }
        # Handle updating a running executable (Windows locks running exes)
        $targetExe = "$BIN_DIR\chell.exe"
        $backupExe = "$BIN_DIR\chell.exe.old"
        if (Test-Path $targetExe) {
            if (Test-Path $backupExe) { Remove-Item $backupExe -Force -ErrorAction SilentlyContinue }
            Rename-Item -Path $targetExe -NewName "chell.exe.old" -Force -ErrorAction SilentlyContinue
        }
        Move-Item -Path "$tempDir\chell.exe" -Destination $targetExe -Force
        Write-Success "Installed chell $version"

        # PATH
        Add-ToPath

        Write-Host ""
        Write-Host "Installation complete!" -ForegroundColor Green
        Write-Host ""
        if ($installed) {
            Write-Host "  Upgraded: $installed -> $version"
        }
        Write-Host "  Binary: $BIN_DIR\chell.exe"
        Write-Host ""
        Write-Host "Restart your terminal, then run: chell"
        Write-Host ""

    } finally {
        if (Test-Path $tempDir) {
            Remove-Item -Path $tempDir -Recurse -Force -ErrorAction SilentlyContinue
        }
    }
}

Main
