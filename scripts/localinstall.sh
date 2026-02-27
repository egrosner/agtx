#!/bin/bash
set -e

# Install locally-built agtx binary
# Usage: ./scripts/localinstall.sh [--prefix ~/.local]

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

while [[ $# -gt 0 ]]; do
    case "$1" in
        --prefix)
            PREFIX="$2"
            shift 2
            ;;
        --prefix=*)
            PREFIX="${1#*=}"
            shift
            ;;
        *)
            error "Unknown argument: $1 (use --prefix <path>)"
            ;;
    esac
done

INSTALL_DIR="${PREFIX}/bin"
BINARY_SRC="$PROJECT_DIR/target/release/agtx"

# ── Check binary exists ──────────────────────────────────

if [ ! -f "$BINARY_SRC" ]; then
    # Try debug build
    if [ -f "$PROJECT_DIR/target/debug/agtx" ]; then
        BINARY_SRC="$PROJECT_DIR/target/debug/agtx"
        warn "Using debug build (run ./scripts/build.sh --release for optimized binary)"
    else
        error "No built binary found. Run ./scripts/build.sh first"
    fi
fi

# ── Install ───────────────────────────────────────────────

mkdir -p "$INSTALL_DIR"

info "Installing agtx to ${INSTALL_DIR}/agtx..."
cp "$BINARY_SRC" "${INSTALL_DIR}/agtx"
chmod +x "${INSTALL_DIR}/agtx"

VERSION=$("${INSTALL_DIR}/agtx" --version 2>/dev/null || echo "unknown")
success "Installed: ${INSTALL_DIR}/agtx ($VERSION)"

# ── PATH check ────────────────────────────────────────────

if [[ ":$PATH:" != *":${INSTALL_DIR}:"* ]]; then
    echo ""
    warn "${INSTALL_DIR} is not in your PATH"
    echo ""
    echo "  Add to your shell config:"
    echo "    export PATH=\"${INSTALL_DIR}:\$PATH\""
    echo ""
else
    echo ""
    info "Run 'agtx' to get started"
fi
