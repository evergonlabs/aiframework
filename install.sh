#!/bin/sh
# aiframework installer — downloads pre-built Rust binary or builds from source
#
# Usage:
#   curl -fsSL https://raw.githubusercontent.com/evergonlabs/aiframework/main/install.sh | sh
#
# Options (env vars):
#   PREFIX=/usr/local       install prefix (default: auto-detected per platform)
#   BRANCH=main             git branch for source build fallback

set -e

# ── Colors (skip if not a terminal or on dumb terminals) ──

BOLD='' GREEN='' YELLOW='' RED='' CYAN='' NC=''
if [ -t 1 ] && [ "${TERM:-dumb}" != "dumb" ]; then
  BOLD='\033[1m'
  GREEN='\033[0;32m'
  YELLOW='\033[0;33m'
  RED='\033[0;31m'
  CYAN='\033[0;36m'
  NC='\033[0m'
fi

info()  { printf "${CYAN}>${NC}  %s\n" "$1"; }
ok()    { printf "${GREEN}+${NC}  %s\n" "$1"; }
warn()  { printf "${YELLOW}!${NC}  %s\n" "$1"; }
err()   { printf "${RED}x${NC}  %s\n" "$1" >&2; }
die()   { err "$1"; exit 1; }

# Replace $HOME with ~ in paths for cleaner output
tildify() {
  case "$1" in "$HOME"/*) printf '%s' "~/${1#"$HOME"/}" ;; *) printf '%s' "$1" ;; esac
}

# ── Platform detection ──

detect_platform() {
  OS="$(uname -s)"
  ARCH="$(uname -m)"

  case "$OS" in
    Darwin)
      PLATFORM="macos"
      RELEASE_PLATFORM="apple-darwin"
      ;;
    Linux)
      if [ -f /proc/version ] && grep -qi microsoft /proc/version 2>/dev/null; then
        PLATFORM="wsl"
      else
        PLATFORM="linux"
      fi
      RELEASE_PLATFORM="unknown-linux-gnu"
      ;;
    MINGW*|MSYS*|CYGWIN*)
      PLATFORM="windows"
      RELEASE_PLATFORM="pc-windows-msvc"
      ;;
    *)
      die "Unsupported OS: $OS. aiframework supports macOS, Linux, WSL, and Windows (Git Bash/MSYS2)."
      ;;
  esac

  case "$ARCH" in
    x86_64|amd64)  ARCH="x86_64"; RELEASE_ARCH="x86_64" ;;
    arm64|aarch64) ARCH="arm64";  RELEASE_ARCH="aarch64" ;;
    *)             die "Unsupported architecture: $ARCH. Pre-built binaries are available for x86_64 and arm64." ;;
  esac
}

# ── Default paths per platform ──

set_default_paths() {
  BRANCH="${BRANCH:-main}"
  # Validate BRANCH to prevent git flag injection
  case "$BRANCH" in
    -*) die "Invalid BRANCH value: $BRANCH (cannot start with -)" ;;
  esac
  if ! printf '%s' "$BRANCH" | grep -qE '^[a-zA-Z0-9._/-]+$'; then
    die "Invalid BRANCH value: $BRANCH (only alphanumeric, dots, slashes, dashes allowed)"
  fi
  GITHUB_REPO="https://github.com/evergonlabs/aiframework.git"
  GITHUB_RELEASE_BASE="https://github.com/evergonlabs/aiframework/releases/latest/download"

  # Set PREFIX
  if [ -z "${PREFIX:-}" ]; then
    case "$PLATFORM" in
      windows)
        PREFIX="$HOME"
        ;;
      *)
        if [ "$(id -u)" -eq 0 ]; then
          PREFIX="/usr/local"
        else
          PREFIX="$HOME/.local"
        fi
        ;;
    esac
  fi

  BIN_DIR="$PREFIX/bin"
}

# ── Dependency checks ──

check_command() {
  command -v "$1" >/dev/null 2>&1
}

# Detect Linux package manager
detect_pkg_manager() {
  if check_command apt-get; then echo "apt"
  elif check_command dnf; then echo "dnf"
  elif check_command yum; then echo "yum"
  elif check_command pacman; then echo "pacman"
  elif check_command apk; then echo "apk"
  elif check_command zypper; then echo "zypper"
  else echo "unknown"
  fi
}

# Generate install command for a package per distro
pkg_install_hint() {
  pkg="$1"
  case "$PLATFORM" in
    macos)
      echo "brew install $pkg"
      ;;
    linux|wsl)
      mgr=$(detect_pkg_manager)
      case "$mgr" in
        apt)     echo "sudo apt-get install -y $pkg" ;;
        dnf)     echo "sudo dnf install -y $pkg" ;;
        yum)     echo "sudo yum install -y $pkg" ;;
        pacman)  echo "sudo pacman -S --noconfirm $pkg" ;;
        apk)     echo "sudo apk add $pkg" ;;
        zypper)  echo "sudo zypper install -y $pkg" ;;
        *)       echo "Install $pkg using your package manager" ;;
      esac
      ;;
    windows)
      case "$pkg" in
        git)   echo "https://git-scm.com/download/win" ;;
        curl)  echo "Git Bash includes curl, or install via scoop/choco" ;;
        cargo) echo "https://rustup.rs" ;;
        *)     echo "Install $pkg manually" ;;
      esac
      ;;
  esac
}

# Auto-install a missing dependency (only with --auto-deps)
try_auto_install() {
  pkg="$1"
  if [ "${AUTO_DEPS:-0}" != "1" ]; then
    return 1
  fi
  case "$PLATFORM" in
    macos)
      if check_command brew; then
        info "  Auto-installing $pkg via Homebrew..."
        brew install "$pkg" 2>/dev/null && return 0
      fi
      ;;
    linux|wsl)
      mgr=$(detect_pkg_manager)
      case "$mgr" in
        apt)
          info "  Auto-installing $pkg via apt..."
          sudo apt-get update -qq && sudo apt-get install -y "$pkg" 2>/dev/null && return 0
          ;;
        dnf)
          info "  Auto-installing $pkg via dnf..."
          sudo dnf install -y "$pkg" 2>/dev/null && return 0
          ;;
        pacman)
          info "  Auto-installing $pkg via pacman..."
          sudo pacman -S --noconfirm "$pkg" 2>/dev/null && return 0
          ;;
        apk)
          info "  Auto-installing $pkg via apk..."
          sudo apk add "$pkg" 2>/dev/null && return 0
          ;;
        zypper)
          info "  Auto-installing $pkg via zypper..."
          sudo zypper install -y "$pkg" 2>/dev/null && return 0
          ;;
      esac
      ;;
  esac
  return 1
}

check_dependencies() {
  missing=0
  missing_pkgs=""

  # bash (required, 3.2+)
  if check_command bash; then
    bash_ver="$(bash --version | head -1 | sed 's/.*version \([0-9.]*\).*/\1/')"
    ok "bash $bash_ver"
  else
    err "bash is required but not installed"
    missing=1
    missing_pkgs="$missing_pkgs bash"
  fi

  # git (required for source build fallback)
  if check_command git; then
    git_ver="$(git --version | awk '{print $3}')"
    ok "git $git_ver"
  else
    if try_auto_install git; then
      git_ver="$(git --version | awk '{print $3}')"
      ok "git $git_ver (auto-installed)"
    else
      err "git is required but not installed"
      info "  Install: $(pkg_install_hint git)"
      missing=1
      missing_pkgs="$missing_pkgs git"
    fi
  fi

  # curl or wget (required for binary download)
  if check_command curl; then
    ok "curl $(curl --version | head -1 | awk '{print $2}')"
    DOWNLOAD_CMD="curl"
  elif check_command wget; then
    ok "wget $(wget --version 2>/dev/null | head -1 | awk '{print $3}')"
    DOWNLOAD_CMD="wget"
  else
    if try_auto_install curl; then
      ok "curl (auto-installed)"
      DOWNLOAD_CMD="curl"
    else
      err "curl or wget is required but neither is installed"
      info "  Install: $(pkg_install_hint curl)"
      missing=1
      missing_pkgs="$missing_pkgs curl"
    fi
  fi

  # cargo (optional — for source build fallback)
  if check_command cargo; then
    cargo_ver="$(cargo --version | awk '{print $2}')"
    ok "cargo $cargo_ver (optional, for source builds)"
  else
    info "cargo not found (optional — needed only if pre-built binary is unavailable)"
  fi

  if [ "$missing" -ne 0 ]; then
    echo ""
    if [ "${AUTO_DEPS:-0}" != "1" ]; then
      info "Tip: Re-run with --auto-deps to auto-install missing packages:"
      info "  curl -fsSL https://raw.githubusercontent.com/evergonlabs/aiframework/main/install.sh | sh -s -- --auto-deps"
    fi
    echo ""
    die "Missing dependencies:${missing_pkgs}. Install them and re-run the installer."
  fi
}

# ── Download helper ──

download() {
  url="$1"
  output="$2"
  case "${DOWNLOAD_CMD:-curl}" in
    curl) curl -fsSL --retry 3 -o "$output" "$url" ;;
    wget) wget -q -O "$output" "$url" ;;
  esac
}

# Check if a URL exists (HTTP 200)
url_exists() {
  url="$1"
  case "${DOWNLOAD_CMD:-curl}" in
    curl) curl -fsSL --head --retry 1 -o /dev/null "$url" 2>/dev/null ;;
    wget) wget -q --spider "$url" 2>/dev/null ;;
  esac
}

# ── Install ──

install_binary() {
  TARBALL_NAME="aiframework-${RELEASE_ARCH}-${RELEASE_PLATFORM}.tar.gz"
  RELEASE_URL="${GITHUB_RELEASE_BASE}/${TARBALL_NAME}"

  echo ""
  info "Binary directory: ${BOLD}$BIN_DIR${NC}"
  echo ""

  # Create bin directory
  mkdir -p "$BIN_DIR"

  # Try pre-built binary first
  info "Checking for pre-built binary..."
  info "  URL: $RELEASE_URL"

  TMPDIR_INSTALL="$(mktemp -d)"
  trap 'rm -rf "$TMPDIR_INSTALL"' EXIT

  if url_exists "$RELEASE_URL"; then
    info "Downloading pre-built binary for ${RELEASE_ARCH}-${RELEASE_PLATFORM}..."
    if download "$RELEASE_URL" "$TMPDIR_INSTALL/$TARBALL_NAME"; then
      (
        cd "$TMPDIR_INSTALL" || die "Cannot cd to temp dir"
        tar xzf "$TARBALL_NAME"
      )
      # Find the binary in the extracted archive
      if [ -f "$TMPDIR_INSTALL/aiframework" ]; then
        EXTRACTED_BIN="$TMPDIR_INSTALL/aiframework"
      elif [ -f "$TMPDIR_INSTALL/aiframework/aiframework" ]; then
        EXTRACTED_BIN="$TMPDIR_INSTALL/aiframework/aiframework"
      else
        # Search for it
        EXTRACTED_BIN="$(find "$TMPDIR_INSTALL" -name 'aiframework' -type f ! -name '*.tar.gz' | head -1)"
      fi

      if [ -n "$EXTRACTED_BIN" ] && [ -f "$EXTRACTED_BIN" ]; then
        cp "$EXTRACTED_BIN" "$BIN_DIR/aiframework"
        chmod +x "$BIN_DIR/aiframework"
        INSTALL_METHOD="binary"
        ok "Installed pre-built binary to $BIN_DIR/aiframework"
      else
        warn "Archive downloaded but binary not found inside — falling back to source build"
        INSTALL_METHOD=""
      fi
    else
      warn "Download failed — falling back to source build"
      INSTALL_METHOD=""
    fi
  else
    info "No pre-built binary available for ${RELEASE_ARCH}-${RELEASE_PLATFORM}"
    INSTALL_METHOD=""
  fi

  # Fallback: git clone + cargo build
  if [ -z "${INSTALL_METHOD:-}" ]; then
    if ! check_command cargo; then
      echo ""
      die "No pre-built binary available and cargo is not installed. Install Rust via https://rustup.rs and re-run."
    fi

    SRC_DIR="$(mktemp -d)"
    # Update trap to clean both temp dirs
    trap 'rm -rf "$TMPDIR_INSTALL" "$SRC_DIR"' EXIT

    info "Building from source (this may take a few minutes)..."
    git clone --quiet --depth 1 --branch "$BRANCH" "$GITHUB_REPO" "$SRC_DIR"
    ok "Cloned source to $SRC_DIR"

    info "Running cargo build --release..."
    (cd "$SRC_DIR" && cargo build --release --quiet)

    if [ -f "$SRC_DIR/target/release/aiframework" ]; then
      cp "$SRC_DIR/target/release/aiframework" "$BIN_DIR/aiframework"
      chmod +x "$BIN_DIR/aiframework"
      INSTALL_METHOD="source"
      ok "Built and installed from source to $BIN_DIR/aiframework"
    else
      die "Cargo build succeeded but binary not found at target/release/aiframework"
    fi
  fi

  # Verify install
  if [ -x "$BIN_DIR/aiframework" ]; then
    VERSION="$("$BIN_DIR/aiframework" --version 2>/dev/null | awk '{print $NF}' || echo "unknown")"
    ok "aiframework ${VERSION} installed successfully"
  else
    die "Installation failed — $BIN_DIR/aiframework not found or not executable"
  fi
}

# ── PATH setup ──

ensure_path() {
  # Skip PATH modification if --no-modify-rc was passed or BIN_DIR is under /tmp
  if [ "${NO_MODIFY_RC:-0}" = "1" ]; then
    return 0
  fi
  case "$BIN_DIR" in
    /tmp/*|/private/tmp/*|/var/tmp/*) return 0 ;;
  esac

  case ":$PATH:" in
    *":$BIN_DIR:"*) return 0 ;;
  esac

  warn "$BIN_DIR is not in your PATH"
  echo ""

  # Platform-specific PATH instructions
  case "$PLATFORM" in
    windows)
      info "Add to your PATH manually:"
      info "  1. Open System Properties > Environment Variables"
      info "  2. Add $BIN_DIR to your user PATH"
      info "  OR in PowerShell (admin): [Environment]::SetEnvironmentVariable('PATH', \$env:PATH + ';$BIN_DIR', 'User')"
      return 0
      ;;
  esac

  # Unix: detect shell config file
  SHELL_NAME="$(basename "${SHELL:-/bin/sh}")"
  case "$SHELL_NAME" in
    zsh)  SHELL_RC="$HOME/.zshrc" ;;
    bash) SHELL_RC="$HOME/.bashrc" ;;
    fish) SHELL_RC="$HOME/.config/fish/config.fish" ;;
    *)    SHELL_RC="$HOME/.profile" ;;
  esac

  PATH_LINE="export PATH=\"$BIN_DIR:\$PATH\""
  if [ "$SHELL_NAME" = "fish" ]; then
    PATH_LINE="set -gx PATH $BIN_DIR \$PATH"
  fi

  # Check if already in rc file
  if [ -f "$SHELL_RC" ] && grep -qF "$BIN_DIR" "$SHELL_RC" 2>/dev/null; then
    info "PATH entry already in $SHELL_RC — restart your shell or run: source $SHELL_RC"
    return 0
  fi

  # Add to rc file
  printf '\n# aiframework\n%s\n' "$PATH_LINE" >> "$SHELL_RC"
  ok "Added $BIN_DIR to PATH in $SHELL_RC"
  info "Run: ${BOLD}source $SHELL_RC${NC} (or restart your terminal)"
}

# ── Uninstall ──

uninstall_aiframework() {
  set_default_paths

  info "Removing aiframework..."

  # Remove binary
  if [ -f "$BIN_DIR/aiframework" ] || [ -L "$BIN_DIR/aiframework" ]; then
    rm -f "$BIN_DIR/aiframework"
    ok "Removed $BIN_DIR/aiframework"
  else
    warn "Binary not found at $BIN_DIR/aiframework"
  fi

  # Remove legacy symlinks if they exist
  rm -f "$BIN_DIR/aiframework-mcp" "$BIN_DIR/aiframework-telemetry" "$BIN_DIR/aiframework-update-check"

  # Remove legacy source directory if it exists
  if [ -d "$HOME/.aiframework-src" ]; then
    rm -rf "$HOME/.aiframework-src"
    ok "Removed legacy source directory ~/.aiframework-src"
  fi

  # Remove the exact PATH block we added (2-line: "# aiframework" + PATH export)
  for rc_file in "$HOME/.zshrc" "$HOME/.bashrc" "$HOME/.profile" "$HOME/.config/fish/config.fish"; do
    if [ -f "$rc_file" ] && grep -qF "$BIN_DIR" "$rc_file" 2>/dev/null; then
      cp "$rc_file" "${rc_file}.aif-backup"
      awk -v bindir="$BIN_DIR" '
        /^# aiframework$/ { pending = $0; next }
        pending && index($0, bindir) > 0 { pending = ""; next }
        pending { print pending; pending = "" }
        { print }
        END { if (pending) print pending }
      ' "$rc_file" > "${rc_file}.aif-tmp"
      mv "${rc_file}.aif-tmp" "$rc_file"
      ok "Removed PATH entry from $rc_file (backup: ${rc_file}.aif-backup)"
    fi
  done

  ok "aiframework uninstalled"
  info "Note: ~/.aiframework/ config directory preserved. Remove manually if desired."
}

# ── Main ──

main() {
  echo ""
  printf "${BOLD}aiframework installer${NC}\n"
  echo "================================"
  echo ""

  # Handle flags
  for arg in "$@"; do
    case "$arg" in
      --uninstall)
        detect_platform
        uninstall_aiframework
        exit 0
        ;;
      --no-modify-rc)
        NO_MODIFY_RC=1
        ;;
      --auto-deps)
        AUTO_DEPS=1
        ;;
      --dry-run)
        DRY_RUN=1
        ;;
      --help|-h)
        echo "Usage: curl -fsSL https://raw.githubusercontent.com/evergonlabs/aiframework/main/install.sh | sh"
        echo ""
        echo "Installs the aiframework Rust binary. No runtime dependencies required."
        echo ""
        echo "Supported platforms: macOS (x86_64, arm64), Linux (x86_64, arm64), WSL, Windows (Git Bash / MSYS2)"
        echo ""
        echo "Options (env vars):"
        echo "  PREFIX=~/.local        Install prefix (default: auto-detected)"
        echo "  BRANCH=main            Git branch (used for source build fallback)"
        echo ""
        echo "Flags:"
        echo "  --uninstall            Remove aiframework"
        echo "  --no-modify-rc         Don't modify shell RC files (PATH)"
        echo "  --auto-deps            Auto-install missing dependencies (requires sudo on Linux)"
        echo "  --dry-run              Show what would be installed without making changes"
        echo "  --help                 Show this help"
        echo ""
        echo "Install flow:"
        echo "  1. Download pre-built binary from GitHub Releases"
        echo "  2. If unavailable, fall back to: git clone + cargo build --release"
        echo ""
        echo "Dependencies:"
        echo "  Required: bash 3.2+, git, curl (or wget)"
        echo "  Optional: cargo (only needed if no pre-built binary for your platform)"
        exit 0
        ;;
    esac
  done

  detect_platform
  info "Platform: $PLATFORM ($ARCH)"
  echo ""

  set_default_paths

  info "Checking dependencies..."
  check_dependencies
  echo ""

  # --dry-run: show what would happen and exit
  if [ "${DRY_RUN:-0}" = "1" ]; then
    TARBALL_NAME="aiframework-${RELEASE_ARCH}-${RELEASE_PLATFORM}.tar.gz"
    RELEASE_URL="${GITHUB_RELEASE_BASE}/${TARBALL_NAME}"
    echo ""
    printf "${BOLD}Dry run — no changes will be made${NC}\n"
    echo ""
    info "Would download:  $RELEASE_URL"
    info "Fallback:        git clone $GITHUB_REPO + cargo build --release"
    info "Install binary:  $BIN_DIR/aiframework"
    # Check PATH
    case ":$PATH:" in
      *":$BIN_DIR:"*) info "PATH: $BIN_DIR already in PATH" ;;
      *)
        SHELL_NAME="$(basename "${SHELL:-/bin/sh}")"
        case "$SHELL_NAME" in
          zsh)  SHELL_RC="$HOME/.zshrc" ;;
          bash) SHELL_RC="$HOME/.bashrc" ;;
          fish) SHELL_RC="$HOME/.config/fish/config.fish" ;;
          *)    SHELL_RC="$HOME/.profile" ;;
        esac
        info "Would add to PATH:   $BIN_DIR (in $SHELL_RC)"
        ;;
    esac
    echo ""
    ok "Dry run complete. Re-run without --dry-run to install."
    exit 0
  fi

  install_binary
  ensure_path

  # Write install receipt for self-update and diagnostics
  mkdir -p "${HOME}/.aiframework"
  cat > "${HOME}/.aiframework/install-receipt.json" << RECEIPT_EOF
{
  "version": "${VERSION}",
  "method": "${INSTALL_METHOD}",
  "bin_dir": "$(tildify "$BIN_DIR")",
  "platform": "${PLATFORM}-${ARCH}",
  "installed_at": "$(date -u +%Y-%m-%dT%H:%M:%SZ 2>/dev/null || date +%Y-%m-%dT%H:%M:%SZ)"
}
RECEIPT_EOF

  # Clean success output
  echo ""
  ok "aiframework ${VERSION} installed"
  echo ""
  echo "  To get started:"
  echo ""
  printf "    ${BOLD}aiframework run --target ~/your-project${NC}\n"
  echo ""
  echo "  Docs: https://github.com/evergonlabs/aiframework"
  echo ""
}

main "$@"
