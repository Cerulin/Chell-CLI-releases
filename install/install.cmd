@echo off
REM Chell CLI Installer for Windows (Command Prompt)
REM Delegates to PowerShell installer
REM
REM Usage:
REM   curl -fsSL https://raw.githubusercontent.com/Cerulin/Chell-CLI-releases/main/install/install.cmd -o install.cmd && install.cmd && del install.cmd

powershell -ExecutionPolicy Bypass -Command "irm https://raw.githubusercontent.com/Cerulin/Chell-CLI-releases/main/install/install.ps1 | iex"
