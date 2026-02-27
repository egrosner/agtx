#!/bin/bash
set -e

# Build agtx from source
# Usage: ./scripts/build.sh [--release]

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

# ── Check prerequisites ──────────────────────────────────

check_dep() {
    if ! command -v "$1" &> /dev/null; then
        error "$1 is required but not found. Run: ansible-playbook scripts/setup.yml"
    fi
}

check_dep cargo
check_dep rustc

# ── Parse args ────────────────────────────────────────────

BUILD_MODE="release"
CARGO_FLAGS=("--release")

for arg in "$@"; do
    case "$arg" in
        --debug)
            BUILD_MODE="debug"
            CARGO_FLAGS=()
            ;;
        --release)
            BUILD_MODE="release"
            CARGO_FLAGS=("--release")
            ;;
        *)
            error "Unknown argument: $arg (use --debug or --release)"
            ;;
    esac
done

# ── Build ─────────────────────────────────────────────────

cd "$PROJECT_DIR"

info "Building agtx ($BUILD_MODE)..."
cargo build "${CARGO_FLAGS[@]}"

BINARY="$PROJECT_DIR/target/$BUILD_MODE/agtx"

if [ ! -f "$BINARY" ]; then
    error "Build succeeded but binary not found at $BINARY"
fi

SIZE=$(du -h "$BINARY" | cut -f1 | xargs)
success "Built: $BINARY ($SIZE)"

# ── Run tests ─────────────────────────────────────────────

info "Running tests..."
if cargo test --features test-mocks 2>&1; then
    success "All tests passed"
else
    warn "Some tests failed (binary was still built)"
fi

echo ""
info "To install locally: ./scripts/localinstall.sh"
