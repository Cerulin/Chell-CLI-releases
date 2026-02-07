#!/bin/bash
#
# Chell CLI Installer for Linux and macOS
#
# Usage:
#   curl -fsSL https://raw.githubusercontent.com/Cerulin/Chell-CLI-releases/main/install/install.sh | bash
#
set -e

GITHUB_REPO="Cerulin/Chell-CLI-releases"
INSTALL_DIR="$HOME/.chell"
BIN_DIR="$INSTALL_DIR/bin"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

info()    { echo -e "${BLUE}[INFO]${NC} $1"; }
success() { echo -e "${GREEN}[OK]${NC} $1"; }
warn()    { echo -e "${YELLOW}[WARN]${NC} $1"; }
error()   { echo -e "${RED}[ERROR]${NC} $1"; exit 1; }

detect_platform() {
  local os arch
  case "$(uname -s)" in
    Linux*)  os="linux" ;;
    Darwin*) os="darwin" ;;
    *)       error "Unsupported OS: $(uname -s)" ;;
  esac
  case "$(uname -m)" in
    x86_64|amd64)  arch="amd64" ;;
    arm64|aarch64) arch="arm64" ;;
    *)             error "Unsupported architecture: $(uname -m)" ;;
  esac
  echo "${os}-${arch}"
}

binary_name() {
  echo "chell-$1"
}

fetch() {
  local url="$1" output="$2"
  if command -v curl &>/dev/null; then
    curl -fsSL "$url" -o "$output"
  elif command -v wget &>/dev/null; then
    wget -q "$url" -O "$output"
  else
    error "Neither curl nor wget found."
  fi
}

fetch_stdout() {
  local url="$1"
  if command -v curl &>/dev/null; then
    curl -fsSL "$url"
  elif command -v wget &>/dev/null; then
    wget -qO- "$url"
  else
    error "Neither curl nor wget found."
  fi
}

get_latest_version() {
  local response
  response=$(fetch_stdout "https://api.github.com/repos/${GITHUB_REPO}/releases/latest")
  echo "$response" | grep '"tag_name"' | sed -E 's/.*"([^"]+)".*/\1/'
}

get_installed_version() {
  if [ -x "$BIN_DIR/chell" ]; then
    "$BIN_DIR/chell" --version 2>/dev/null | grep -oE 'v?[0-9]+\.[0-9]+\.[0-9]+' | head -1
  else
    echo ""
  fi
}

compute_sha256() {
  local file="$1"
  if command -v sha256sum &>/dev/null; then
    sha256sum "$file" | awk '{print $1}'
  elif command -v shasum &>/dev/null; then
    shasum -a 256 "$file" | awk '{print $1}'
  else
    echo ""
  fi
}

uninstall_npm_chell() {
  if command -v npm &>/dev/null; then
    if npm list -g @cerulin/chell 2>/dev/null | grep -q chell; then
      warn "Found old npm version of chell. Uninstalling..."
      npm uninstall -g @cerulin/chell 2>/dev/null && \
        success "Removed npm @cerulin/chell" || \
        warn "Could not remove npm @cerulin/chell. Run manually: npm uninstall -g @cerulin/chell"
    fi
  fi
}

add_to_path() {
  local shell_config=""

  case "$SHELL" in
    */bash)
      if [ -f "$HOME/.bashrc" ]; then
        shell_config="$HOME/.bashrc"
      elif [ -f "$HOME/.bash_profile" ]; then
        shell_config="$HOME/.bash_profile"
      fi
      ;;
    */zsh)  shell_config="$HOME/.zshrc" ;;
    */fish) shell_config="$HOME/.config/fish/config.fish" ;;
  esac

  local path_line="export PATH=\"$BIN_DIR:\$PATH\""

  if [ -n "$shell_config" ] && [ -f "$shell_config" ]; then
    if ! grep -q "$BIN_DIR" "$shell_config" 2>/dev/null; then
      echo "" >> "$shell_config"
      echo "# Chell CLI" >> "$shell_config"
      echo "$path_line" >> "$shell_config"
      success "Added $BIN_DIR to PATH in $shell_config"
    fi
  else
    warn "Add this to your shell config manually:"
    echo "  $path_line"
  fi
}

main() {
  echo ""
  echo -e "${GREEN}Chell CLI Installer${NC}"
  echo "================================"
  echo ""

  # Check for old npm version
  uninstall_npm_chell

  # Detect platform
  local platform
  platform=$(detect_platform)
  local binary
  binary=$(binary_name "$platform")
  info "Platform: $platform"

  # Get latest version
  info "Fetching latest version..."
  local version
  version=$(get_latest_version)
  if [ -z "$version" ]; then
    error "Failed to fetch latest version"
  fi
  success "Latest version: $version"

  # Check if already up to date
  local installed
  installed=$(get_installed_version)
  if [ -n "$installed" ]; then
    local installed_clean="${installed#v}"
    local version_clean="${version#v}"
    if [ "$installed_clean" = "$version_clean" ]; then
      success "Already up to date ($version)"
      exit 0
    fi
    info "Upgrading from $installed to $version"
  fi

  # Download
  local tmp_dir
  tmp_dir=$(mktemp -d)
  trap "rm -rf $tmp_dir" EXIT

  local base_url="https://github.com/${GITHUB_REPO}/releases/download/${version}"

  info "Downloading $binary..."
  fetch "$base_url/$binary" "$tmp_dir/chell"

  # Verify checksum
  info "Verifying checksum..."
  fetch "$base_url/checksums.sha256" "$tmp_dir/checksums.sha256"

  local expected
  expected=$(grep "$binary" "$tmp_dir/checksums.sha256" | awk '{print $1}')
  if [ -n "$expected" ]; then
    local actual
    actual=$(compute_sha256 "$tmp_dir/chell")
    if [ -n "$actual" ]; then
      if [ "$actual" != "$expected" ]; then
        error "Checksum mismatch!\n  Expected: $expected\n  Got:      $actual"
      fi
      success "Checksum verified"
    fi
  else
    warn "Could not verify checksum"
  fi

  # Install
  info "Installing to $BIN_DIR..."
  mkdir -p "$BIN_DIR"
  mv "$tmp_dir/chell" "$BIN_DIR/chell"
  chmod +x "$BIN_DIR/chell"
  success "Installed chell $version"

  # PATH
  add_to_path

  echo ""
  echo -e "${GREEN}Installation complete!${NC}"
  echo ""
  if [ -n "$installed" ]; then
    echo "  Upgraded: $installed -> $version"
  fi
  echo "  Binary: $BIN_DIR/chell"
  echo ""
  echo "Restart your terminal or run:"
  echo "  export PATH=\"$BIN_DIR:\$PATH\""
  echo ""
}

main "$@"
