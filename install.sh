#!/bin/sh
# aiframework installer — works on macOS, Linux, and Windows (Git Bash / WSL / MSYS2)
#
# Usage:
#   curl -fsSL https://raw.githubusercontent.com/evergonlabs/aiframework/main/install.sh | sh
#
# Options (env vars):
#   PREFIX=/usr/local       install prefix (default: auto-detected per platform)
#   AIFRAMEWORK_DIR=...     clone target (default: auto-detected per platform)
#   BRANCH=main             git branch to install
#   SKIP_SHEAL=1            skip sheal install

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

# ── Platform detection ──

detect_platform() {
  OS="$(uname -s)"
  ARCH="$(uname -m)"

  case "$OS" in
    Darwin)
      PLATFORM="macos"
      ;;
    Linux)
      # Check if running inside WSL
      if [ -f /proc/version ] && grep -qi microsoft /proc/version 2>/dev/null; then
        PLATFORM="wsl"
      else
        PLATFORM="linux"
      fi
      ;;
    MINGW*|MSYS*|CYGWIN*)
      PLATFORM="windows"
      ;;
    *)
      die "Unsupported OS: $OS. aiframework supports macOS, Linux, WSL, and Windows (Git Bash/MSYS2)."
      ;;
  esac

  case "$ARCH" in
    x86_64|amd64)  ARCH="x86_64" ;;
    arm64|aarch64) ARCH="arm64" ;;
    i686|i386)     ARCH="x86" ;;
    *)             warn "Unusual architecture: $ARCH. Proceeding anyway." ;;
  esac
}

# ── Default paths per platform ──

set_default_paths() {
  BRANCH="${BRANCH:-main}"
  GITHUB_REPO="https://github.com/evergonlabs/aiframework.git"

  # Set AIFRAMEWORK_DIR
  if [ -z "${AIFRAMEWORK_DIR:-}" ]; then
    case "$PLATFORM" in
      windows|MINGW*|MSYS*|CYGWIN*)
        # Windows: use LOCALAPPDATA or USERPROFILE
        if [ -n "${LOCALAPPDATA:-}" ]; then
          AIFRAMEWORK_DIR="$(cygpath -u "$LOCALAPPDATA" 2>/dev/null || echo "$LOCALAPPDATA")/aiframework"
        else
          AIFRAMEWORK_DIR="$HOME/.aiframework-src"
        fi
        ;;
      *)
        AIFRAMEWORK_DIR="$HOME/.aiframework-src"
        ;;
    esac
  fi

  # Set PREFIX
  if [ -z "${PREFIX:-}" ]; then
    case "$PLATFORM" in
      windows)
        # Windows Git Bash: use ~/bin (commonly in PATH)
        PREFIX="$HOME"
        ;;
      *)
        # Unix: ~/.local for non-root, /usr/local for root
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

check_dependencies() {
  missing=0

  # git (required)
  if check_command git; then
    git_ver="$(git --version | awk '{print $3}')"
    ok "git $git_ver"
  else
    err "git is required but not installed"
    case "$PLATFORM" in
      macos)   info "  Install: brew install git  OR  xcode-select --install" ;;
      linux)   info "  Install: sudo apt install git  (or dnf/pacman/zypper)" ;;
      wsl)     info "  Install: sudo apt install git" ;;
      windows) info "  Install: https://git-scm.com/download/win" ;;
    esac
    missing=1
  fi

  # bash (required, 3.2+)
  if check_command bash; then
    bash_ver="$(bash --version | head -1 | sed 's/.*version \([0-9.]*\).*/\1/')"
    ok "bash $bash_ver"
  else
    err "bash is required but not installed"
    missing=1
  fi

  # python3 (required, 3.10+)
  # On Windows, python3 might not exist but python does
  PY_CMD=""
  if check_command python3; then
    PY_CMD="python3"
  elif check_command python; then
    # Verify it's Python 3, not Python 2
    py_check="$(python -c 'import sys; print(sys.version_info.major)' 2>/dev/null || echo "2")"
    if [ "$py_check" = "3" ]; then
      PY_CMD="python"
    fi
  fi

  if [ -n "$PY_CMD" ]; then
    py_ver="$($PY_CMD -c 'import sys; print("{}.{}.{}".format(sys.version_info.major, sys.version_info.minor, sys.version_info.micro))')"
    py_minor="$($PY_CMD -c 'import sys; print(sys.version_info.minor)')"
    py_major="$($PY_CMD -c 'import sys; print(sys.version_info.major)')"
    if [ "$py_major" -ge 3 ] && [ "$py_minor" -ge 10 ]; then
      ok "$PY_CMD $py_ver"
    else
      err "python 3.10+ required (found $py_ver)"
      missing=1
    fi
  else
    err "python3 is required but not installed"
    case "$PLATFORM" in
      macos)   info "  Install: brew install python@3.12" ;;
      linux)   info "  Install: sudo apt install python3  (or dnf/pacman/zypper)" ;;
      wsl)     info "  Install: sudo apt install python3" ;;
      windows) info "  Install: https://python.org/downloads/  (check 'Add to PATH')" ;;
    esac
    missing=1
  fi

  # jq (required)
  if check_command jq; then
    jq_ver="$(jq --version 2>/dev/null | tr -d 'jq-')"
    ok "jq $jq_ver"
  else
    err "jq is required but not installed"
    case "$PLATFORM" in
      macos)   info "  Install: brew install jq" ;;
      linux)   info "  Install: sudo apt install jq  (or dnf/pacman/zypper)" ;;
      wsl)     info "  Install: sudo apt install jq" ;;
      windows) info "  Install: choco install jq  OR  scoop install jq  OR  https://jqlang.github.io/jq/download/" ;;
    esac
    missing=1
  fi

  if [ "$missing" -ne 0 ]; then
    echo ""
    die "Missing dependencies. Install them and re-run the installer."
  fi
}

# ── Install ──

install_aiframework() {
  echo ""
  info "Install directory: ${BOLD}$AIFRAMEWORK_DIR${NC}"
  info "Binaries:          ${BOLD}$BIN_DIR${NC}"
  info "Branch:            ${BOLD}$BRANCH${NC}"
  echo ""

  # Clone or update
  if [ -d "$AIFRAMEWORK_DIR/.git" ]; then
    info "Existing installation found -- updating..."
    cd "$AIFRAMEWORK_DIR"
    if git remote get-url origin >/dev/null 2>&1; then
      git fetch origin "$BRANCH" --quiet
      git checkout "$BRANCH" --quiet 2>/dev/null || true
      git reset --hard "origin/$BRANCH" --quiet
      ok "Updated to latest"
    else
      git remote add origin "$GITHUB_REPO" 2>/dev/null || git remote set-url origin "$GITHUB_REPO"
      git fetch origin "$BRANCH" --quiet
      git checkout "$BRANCH" --quiet 2>/dev/null || true
      git reset --hard "origin/$BRANCH" --quiet
      ok "Updated to latest (added remote)"
    fi
  else
    info "Cloning aiframework..."
    git clone --depth 1 --branch "$BRANCH" "$GITHUB_REPO" "$AIFRAMEWORK_DIR" --quiet
    ok "Cloned to $AIFRAMEWORK_DIR"
  fi

  # Create bin directory
  mkdir -p "$BIN_DIR"

  # Create symlinks or copies (Windows MSYS/Git Bash can't always symlink)
  case "$PLATFORM" in
    windows)
      # Windows: copy scripts instead of symlinking (symlinks require admin)
      cp -f "$AIFRAMEWORK_DIR/bin/aiframework" "$BIN_DIR/aiframework"
      cp -f "$AIFRAMEWORK_DIR/bin/aiframework-mcp" "$BIN_DIR/aiframework-mcp"
      cp -f "$AIFRAMEWORK_DIR/bin/aiframework-telemetry" "$BIN_DIR/aiframework-telemetry"
      ok "Copied binaries to $BIN_DIR"
      warn "On Windows, run 'aiframework update' after updates (files are copied, not symlinked)"
      ;;
    *)
      ln -sf "$AIFRAMEWORK_DIR/bin/aiframework" "$BIN_DIR/aiframework"
      ln -sf "$AIFRAMEWORK_DIR/bin/aiframework-mcp" "$BIN_DIR/aiframework-mcp"
      ln -sf "$AIFRAMEWORK_DIR/bin/aiframework-telemetry" "$BIN_DIR/aiframework-telemetry"
      ok "Symlinked binaries to $BIN_DIR"
      ;;
  esac

  # Install sheal (optional)
  if [ "${SKIP_SHEAL:-0}" != "1" ]; then
    if check_command npm; then
      info "Installing sheal (runtime session intelligence)..."
      npm install -g @liwala/sheal@latest 2>/dev/null && ok "sheal installed" || warn "sheal install failed (non-fatal)"
    else
      info "Tip: Install Node.js 22+ and run 'npm install -g @liwala/sheal' for runtime session intelligence"
    fi
  fi

  # Verify install
  VERSION="$(cat "$AIFRAMEWORK_DIR/VERSION" 2>/dev/null | tr -d '[:space:]')"
  if [ -x "$BIN_DIR/aiframework" ] || [ -L "$BIN_DIR/aiframework" ] || [ -f "$BIN_DIR/aiframework" ]; then
    ok "aiframework v${VERSION} installed successfully"
  else
    die "Installation failed -- $BIN_DIR/aiframework not found"
  fi
}

# ── PATH setup ──

ensure_path() {
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
    info "PATH entry already in $SHELL_RC -- restart your shell or run: source $SHELL_RC"
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
  rm -f "$BIN_DIR/aiframework" "$BIN_DIR/aiframework-mcp" "$BIN_DIR/aiframework-telemetry"
  if [ -d "$AIFRAMEWORK_DIR" ]; then
    rm -rf "$AIFRAMEWORK_DIR"
    ok "Removed $AIFRAMEWORK_DIR"
  fi
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
      --help|-h)
        echo "Usage: curl -fsSL https://raw.githubusercontent.com/evergonlabs/aiframework/main/install.sh | sh"
        echo ""
        echo "Supported platforms: macOS, Linux, WSL, Windows (Git Bash / MSYS2)"
        echo ""
        echo "Options (env vars):"
        echo "  PREFIX=~/.local        Install prefix (default: auto-detected)"
        echo "  AIFRAMEWORK_DIR=...    Clone directory (default: ~/.aiframework-src)"
        echo "  BRANCH=main            Git branch"
        echo "  SKIP_SHEAL=1           Skip sheal install"
        echo ""
        echo "Flags:"
        echo "  --uninstall            Remove aiframework"
        echo "  --help                 Show this help"
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

  install_aiframework
  ensure_path

  echo ""
  echo "================================"
  printf "${BOLD}Next steps:${NC}\n"
  echo ""
  echo "  1. Bootstrap a project:"
  echo "     aiframework run --target ~/your-project"
  echo ""
  echo "  2. Open Claude Code and run:"
  echo "     /aif-ready"
  echo ""
  echo "  Docs: https://github.com/evergonlabs/aiframework"
  echo ""
}

main "$@"
