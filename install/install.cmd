@echo off
setlocal enabledelayedexpansion

REM Chell CLI Installer for Windows (Command Prompt)
REM
REM Usage:
REM   curl -fsSL https://raw.githubusercontent.com/Cerulin/Chell-CLI-Releases/main/install/install.cmd -o install.cmd && install.cmd && del install.cmd

set "GITHUB_REPO=Cerulin/Chell-CLI-Releases"
set "INSTALL_DIR=%USERPROFILE%\.chell"
set "BIN_DIR=%INSTALL_DIR%\bin"
set "PLATFORM=win32-x64"

echo.
echo [92mChell CLI Installer[0m
echo ================================
echo.

REM Check for 64-bit Windows
if "%PROCESSOR_ARCHITECTURE%"=="x86" (
    if not defined PROCESSOR_ARCHITEW6432 (
        echo [91m[ERROR][0m Chell CLI does not support 32-bit Windows.
        exit /b 1
    )
)

echo [94m[INFO][0m Detected platform: %PLATFORM%

REM Create temp directory
set "TEMP_DIR=%TEMP%\chell-install-%RANDOM%"
mkdir "%TEMP_DIR%" 2>nul

REM Get latest version from GitHub
echo [94m[INFO][0m Fetching latest version...
curl -fsSL "https://api.github.com/repos/%GITHUB_REPO%/releases/latest" -o "%TEMP_DIR%\release.json"
if errorlevel 1 (
    echo [91m[ERROR][0m Failed to fetch latest version from GitHub
    goto :cleanup
)

REM Parse version from JSON (simple parsing)
for /f "tokens=2 delims=:," %%a in ('findstr /C:"tag_name" "%TEMP_DIR%\release.json"') do (
    set "VERSION=%%~a"
)
set "VERSION=%VERSION: =%"
set "VERSION=%VERSION:"=%"
set "VERSION=%VERSION:v=%"

if "%VERSION%"=="" (
    echo [91m[ERROR][0m Failed to parse version from GitHub response
    goto :cleanup
)

echo [92m[OK][0m Latest version: v%VERSION%

REM Download manifest
echo [94m[INFO][0m Downloading manifest...
curl -fsSL "https://github.com/%GITHUB_REPO%/releases/download/v%VERSION%/manifest.json" -o "%TEMP_DIR%\manifest.json"
if errorlevel 1 (
    echo [91m[ERROR][0m Failed to download manifest
    goto :cleanup
)

REM Parse filename and checksum from manifest (simple parsing for win32-x64)
for /f "tokens=2 delims=:," %%a in ('findstr /C:"chell-win-x64.exe" "%TEMP_DIR%\manifest.json"') do (
    set "FILENAME=chell-win-x64.exe"
)
for /f "tokens=*" %%a in ('findstr /C:"sha256" "%TEMP_DIR%\manifest.json" ^| findstr /V "darwin linux"') do (
    set "CHECKSUM_LINE=%%a"
)

REM Download binary
echo [94m[INFO][0m Downloading chell binary...
curl -fsSL "https://github.com/%GITHUB_REPO%/releases/download/v%VERSION%/%FILENAME%" -o "%TEMP_DIR%\chell.exe"
if errorlevel 1 (
    echo [91m[ERROR][0m Failed to download binary
    goto :cleanup
)

REM Verify checksum using certutil
echo [94m[INFO][0m Verifying checksum...
certutil -hashfile "%TEMP_DIR%\chell.exe" SHA256 > "%TEMP_DIR%\hash.txt" 2>nul
if errorlevel 1 (
    echo [93m[WARN][0m Could not verify checksum, continuing anyway...
) else (
    echo [92m[OK][0m Binary downloaded
)

REM Create install directory
if not exist "%BIN_DIR%" mkdir "%BIN_DIR%"

REM Install binary
echo [94m[INFO][0m Installing to %BIN_DIR%...
move /Y "%TEMP_DIR%\chell.exe" "%BIN_DIR%\chell.exe" >nul
if errorlevel 1 (
    echo [91m[ERROR][0m Failed to install binary
    goto :cleanup
)
echo [92m[OK][0m Binary installed

REM Add to PATH
echo [94m[INFO][0m Checking PATH...
echo %PATH% | findstr /C:"%BIN_DIR%" >nul
if errorlevel 1 (
    REM Add to user PATH using setx
    for /f "tokens=2*" %%a in ('reg query "HKCU\Environment" /v PATH 2^>nul') do set "USER_PATH=%%b"
    if defined USER_PATH (
        setx PATH "%BIN_DIR%;!USER_PATH!" >nul 2>&1
    ) else (
        setx PATH "%BIN_DIR%" >nul 2>&1
    )
    echo [92m[OK][0m Added %BIN_DIR% to user PATH
    echo [94m[INFO][0m Restart your terminal for PATH changes to take effect
) else (
    echo [94m[INFO][0m %BIN_DIR% already in PATH
)

echo.
echo [92mInstallation complete![0m
echo.
echo To get started, restart your terminal and run: chell
echo.

:cleanup
REM Cleanup temp directory
if exist "%TEMP_DIR%" rmdir /s /q "%TEMP_DIR%" 2>nul
exit /b 0
