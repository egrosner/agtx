#!/bin/bash
set -e

# One-shot: install dependencies, build, and install agtx locally
# Usage: ./scripts/setup-build-install.sh [OPTIONS]
#
# Options:
#   --prefix <path>   Install prefix (default: ~/.local, binary goes to <prefix>/bin)
#   --debug           Build in debug mode
#   --skip-setup      Skip Ansible dependency installation
#   --skip-tests      Skip running tests after build

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m'

info()    { echo -e "${BLUE}==>${NC} $1"; }
success() { echo -e "${GREEN}==>${NC} $1"; }
warn()    { echo -e "${YELLOW}==>${NC} $1"; }
error()   { echo -e "${RED}==>${NC} $1"; exit 1; }

# ── Parse args ────────────────────────────────────────────

PREFIX="${HOME}/.local"
BUILD_MODE="release"
CARGO_FLAGS=("--release")
SKIP_SETUP=false
SKIP_TESTS=false

while [[ $# -gt 0 ]]; do
    case "$1" in
        --prefix)    PREFIX="$2"; shift 2 ;;
        --prefix=*)  PREFIX="${1#*=}"; shift ;;
        --debug)     BUILD_MODE="debug"; CARGO_FLAGS=(); shift ;;
        --skip-setup) SKIP_SETUP=true; shift ;;
        --skip-tests) SKIP_TESTS=true; shift ;;
        -h|--help)
            echo "Usage: $0 [--prefix <path>] [--debug] [--skip-setup] [--skip-tests]"
            exit 0
            ;;
        *) error "Unknown argument: $1" ;;
    esac
done

INSTALL_DIR="${PREFIX}/bin"

echo ""
echo "  ╭──────────────────────────────╮"
echo "  │  agtx setup + build + install │"
echo "  ╰──────────────────────────────╯"
echo ""

# ── Step 1: Ansible setup ─────────────────────────────────

if [ "$SKIP_SETUP" = true ]; then
    info "Skipping dependency setup (--skip-setup)"
else
    info "Step 1/3: Installing dependencies via Ansible..."

    if ! command -v ansible-playbook &> /dev/null; then
        warn "ansible-playbook not found, attempting to install Ansible..."
        if command -v pip3 &> /dev/null; then
            pip3 install --user ansible
        elif command -v brew &> /dev/null; then
            brew install ansible
        elif command -v apt-get &> /dev/null; then
            sudo apt-get update && sudo apt-get install -y ansible
        elif command -v dnf &> /dev/null; then
            sudo dnf install -y ansible
        else
            error "Cannot install Ansible automatically. Install it manually and re-run, or use --skip-setup"
        fi
    fi

    ansible-playbook "$SCRIPT_DIR/setup.yml" \
        --connection=local \
        -i localhost, \
        --ask-become-pass

    # Ensure cargo is on PATH for the rest of this script (fresh rustup install)
    if [ -f "$HOME/.cargo/env" ]; then
        source "$HOME/.cargo/env"
    fi
    # Also add directly in case env file doesn't exist yet
    export PATH="$HOME/.cargo/bin:$PATH"

    success "Dependencies installed"
fi

# ── Step 2: Build ─────────────────────────────────────────

info "Step 2/3: Building agtx ($BUILD_MODE)..."

if ! command -v cargo &> /dev/null; then
    error "cargo not found. Run without --skip-setup to install Rust"
fi

cd "$PROJECT_DIR"
cargo build "${CARGO_FLAGS[@]}"

BINARY="$PROJECT_DIR/target/$BUILD_MODE/agtx"

if [ ! -f "$BINARY" ]; then
    error "Build succeeded but binary not found at $BINARY"
fi

SIZE=$(du -h "$BINARY" | cut -f1 | xargs)
success "Built: $BINARY ($SIZE)"

if [ "$SKIP_TESTS" = true ]; then
    info "Skipping tests (--skip-tests)"
else
    info "Running tests..."
    if cargo test --features test-mocks 2>&1; then
        success "All tests passed"
    else
        warn "Some tests failed (continuing with install)"
    fi
fi

# ── Step 3: Install ──────────────────────────────────────

info "Step 3/3: Installing to ${INSTALL_DIR}/agtx..."

mkdir -p "$INSTALL_DIR"
cp "$BINARY" "${INSTALL_DIR}/agtx"
chmod +x "${INSTALL_DIR}/agtx"

VERSION=$("${INSTALL_DIR}/agtx" --version 2>/dev/null || echo "unknown")

echo ""
success "agtx installed! ($VERSION)"
echo ""

if [[ ":$PATH:" != *":${INSTALL_DIR}:"* ]]; then
    warn "${INSTALL_DIR} is not in your PATH"
    echo ""
    echo "  Add to your shell config:"
    echo "    export PATH=\"${INSTALL_DIR}:\$PATH\""
    echo ""
else
    echo "  Run 'agtx' to get started"
    echo ""
fi
