#!/bin/bash
#
# Chell CLI Installer for Linux and macOS
#
# Usage:
#   curl -fsSL https://raw.githubusercontent.com/Cerulin/Chell-CLI-Releases/main/install/install.sh | bash
#
set -e

GITHUB_REPO="Cerulin/Chell-CLI-Releases"
INSTALL_DIR="$HOME/.chell"
BIN_DIR="$INSTALL_DIR/bin"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

info() {
  echo -e "${BLUE}[INFO]${NC} $1"
}

success() {
  echo -e "${GREEN}[OK]${NC} $1"
}

warn() {
  echo -e "${YELLOW}[WARN]${NC} $1"
}

error() {
  echo -e "${RED}[ERROR]${NC} $1"
  exit 1
}

# Detect OS
detect_os() {
  case "$(uname -s)" in
    Linux*)  echo "linux" ;;
    Darwin*) echo "darwin" ;;
    *)       error "Unsupported operating system: $(uname -s)" ;;
  esac
}

# Detect architecture
detect_arch() {
  case "$(uname -m)" in
    x86_64|amd64)  echo "x64" ;;
    arm64|aarch64) echo "arm64" ;;
    *)             error "Unsupported architecture: $(uname -m)" ;;
  esac
}

# Get latest release version from GitHub
get_latest_version() {
  local version
  if command -v curl &> /dev/null; then
    version=$(curl -fsSL "https://api.github.com/repos/${GITHUB_REPO}/releases/latest" | grep '"tag_name"' | sed -E 's/.*"v?([^"]+)".*/\1/')
  elif command -v wget &> /dev/null; then
    version=$(wget -qO- "https://api.github.com/repos/${GITHUB_REPO}/releases/latest" | grep '"tag_name"' | sed -E 's/.*"v?([^"]+)".*/\1/')
  else
    error "Neither curl nor wget found. Please install one of them."
  fi

  if [ -z "$version" ]; then
    error "Failed to fetch latest version from GitHub"
  fi

  echo "$version"
}

# Download file
download() {
  local url="$1"
  local output="$2"

  if command -v curl &> /dev/null; then
    curl -fsSL "$url" -o "$output"
  elif command -v wget &> /dev/null; then
    wget -q "$url" -O "$output"
  else
    error "Neither curl nor wget found. Please install one of them."
  fi
}

# Compute SHA256 checksum
compute_sha256() {
  local file="$1"
  if command -v sha256sum &> /dev/null; then
    sha256sum "$file" | awk '{print $1}'
  elif command -v shasum &> /dev/null; then
    shasum -a 256 "$file" | awk '{print $1}'
  else
    warn "No SHA256 tool found, skipping checksum verification"
    echo ""
  fi
}

# Get expected checksum from manifest
get_expected_checksum() {
  local manifest="$1"
  local platform="$2"

  if command -v jq &> /dev/null; then
    jq -r ".files[\"$platform\"].sha256" "$manifest"
  else
    # Fallback: parse JSON with grep/sed
    grep -o "\"$platform\"[^}]*sha256\"[^\"]*\"[^\"]*\"" "$manifest" | grep -o 'sha256"[^"]*"[^"]*"' | sed 's/sha256"[^"]*"//' | tr -d '"'
  fi
}

# Get filename from manifest
get_filename() {
  local manifest="$1"
  local platform="$2"

  if command -v jq &> /dev/null; then
    jq -r ".files[\"$platform\"].filename" "$manifest"
  else
    # Fallback: parse JSON with grep/sed
    grep -o "\"$platform\"[^}]*filename\"[^\"]*\"[^\"]*\"" "$manifest" | grep -o 'filename"[^"]*"[^"]*"' | sed 's/filename"[^"]*"//' | tr -d '"'
  fi
}

# Add to PATH
add_to_path() {
  local shell_config=""
  local shell_name=""

  # Detect shell
  case "$SHELL" in
    */bash)
      shell_name="bash"
      if [ -f "$HOME/.bashrc" ]; then
        shell_config="$HOME/.bashrc"
      elif [ -f "$HOME/.bash_profile" ]; then
        shell_config="$HOME/.bash_profile"
      fi
      ;;
    */zsh)
      shell_name="zsh"
      shell_config="$HOME/.zshrc"
      ;;
    */fish)
      shell_name="fish"
      shell_config="$HOME/.config/fish/config.fish"
      ;;
    *)
      shell_name="unknown"
      ;;
  esac

  local path_line="export PATH=\"$BIN_DIR:\$PATH\""

  if [ -n "$shell_config" ] && [ -f "$shell_config" ]; then
    if ! grep -q "$BIN_DIR" "$shell_config" 2>/dev/null; then
      echo "" >> "$shell_config"
      echo "# Chell CLI" >> "$shell_config"
      echo "$path_line" >> "$shell_config"
      success "Added $BIN_DIR to PATH in $shell_config"
    else
      info "$BIN_DIR already in PATH"
    fi
  else
    warn "Could not detect shell config file. Please add the following to your shell config:"
    echo "  $path_line"
  fi
}

main() {
  echo ""
  echo -e "${GREEN}Chell CLI Installer${NC}"
  echo "================================"
  echo ""

  # Detect platform
  local os=$(detect_os)
  local arch=$(detect_arch)
  local platform="${os}-${arch}"

  info "Detected platform: $platform"

  # Get latest version
  info "Fetching latest version..."
  local version=$(get_latest_version)
  success "Latest version: v$version"

  # Create temp directory
  local tmp_dir=$(mktemp -d)
  trap "rm -rf $tmp_dir" EXIT

  # Download manifest
  info "Downloading manifest..."
  local manifest_url="https://github.com/${GITHUB_REPO}/releases/download/v${version}/manifest.json"
  download "$manifest_url" "$tmp_dir/manifest.json"

  # Get filename for platform
  local filename=$(get_filename "$tmp_dir/manifest.json" "$platform")
  if [ -z "$filename" ] || [ "$filename" = "null" ]; then
    error "No binary available for platform: $platform"
  fi

  # Download binary
  info "Downloading chell binary..."
  local binary_url="https://github.com/${GITHUB_REPO}/releases/download/v${version}/${filename}"
  download "$binary_url" "$tmp_dir/chell"

  # Verify checksum
  local expected_checksum=$(get_expected_checksum "$tmp_dir/manifest.json" "$platform")
  if [ -n "$expected_checksum" ]; then
    info "Verifying checksum..."
    local actual_checksum=$(compute_sha256 "$tmp_dir/chell")
    if [ -n "$actual_checksum" ]; then
      if [ "$actual_checksum" != "$expected_checksum" ]; then
        error "Checksum verification failed!\n  Expected: $expected_checksum\n  Got:      $actual_checksum"
      fi
      success "Checksum verified"
    fi
  fi

  # Install
  info "Installing to $BIN_DIR..."
  mkdir -p "$BIN_DIR"
  mv "$tmp_dir/chell" "$BIN_DIR/chell"
  chmod +x "$BIN_DIR/chell"
  success "Binary installed"

  # Add to PATH
  add_to_path

  echo ""
  echo -e "${GREEN}Installation complete!${NC}"
  echo ""
  echo "To get started, either:"
  echo "  1. Restart your terminal, or"
  echo "  2. Run: export PATH=\"$BIN_DIR:\$PATH\""
  echo ""
  echo "Then run: chell"
  echo ""
}

main "$@"
