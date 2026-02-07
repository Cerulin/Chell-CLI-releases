# Chell CLI

AI coding agent manager. Control Claude Code from your mobile device or integrate with Chell Desktop.

## Installation

**Linux / macOS:**
```bash
curl -fsSL https://raw.githubusercontent.com/Cerulin/Chell-CLI-releases/main/install/install.sh | bash
```

**Windows (PowerShell):**
```powershell
irm https://raw.githubusercontent.com/Cerulin/Chell-CLI-releases/main/install/install.ps1 | iex
```

**Windows (Command Prompt):**
```cmd
curl -fsSL https://raw.githubusercontent.com/Cerulin/Chell-CLI-releases/main/install/install.cmd -o install.cmd && install.cmd && del install.cmd
```

## Update

Run the same install command again — it will check the installed version and upgrade if a newer release is available.

## Usage

After installation, restart your terminal and run:

```bash
chell
```

## Manual Download

Binaries are available on the [Releases](https://github.com/Cerulin/Chell-CLI-releases/releases) page.

| Platform | Binary |
|----------|--------|
| Linux x86_64 | `chell-linux-amd64` |
| macOS ARM64 | `chell-darwin-arm64` |
| macOS x86_64 | `chell-darwin-amd64` |
| Windows x86_64 | `chell-windows-amd64.exe` |

Each release includes a `checksums.sha256` file for verification.

## Requirements

- 64-bit operating system (Linux, macOS, or Windows)
- No other dependencies required — Chell CLI is a standalone binary

## License

MIT
