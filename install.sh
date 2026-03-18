#!/usr/bin/env bash
#
# MDEMG Linux Installer
# https://github.com/reh3376/mdemg_linux
#
# Usage:
#   curl -fsSL https://raw.githubusercontent.com/reh3376/mdemg_linux/main/install.sh | bash
#   bash install.sh [--upgrade|--uninstall|--version VERSION|--prefix DIR]
#
set -euo pipefail

# ─── Configuration ───────────────────────────────────────────────────────────
REPO="reh3376/mdemg"
INSTALL_PREFIX="${MDEMG_INSTALL_PREFIX:-/usr/local}"
BIN_DIR="${INSTALL_PREFIX}/bin"
SYSTEMD_DIR="/etc/systemd/system"
BASH_COMPLETION_DIR="/etc/bash_completion.d"
MAN_DIR="${INSTALL_PREFIX}/share/man/man1"
VERSION=""
ACTION="install"

# ─── Colors ──────────────────────────────────────────────────────────────────
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

info()    { echo -e "${BLUE}[INFO]${NC} $*"; }
success() { echo -e "${GREEN}[OK]${NC} $*"; }
warn()    { echo -e "${YELLOW}[WARN]${NC} $*"; }
error()   { echo -e "${RED}[ERROR]${NC} $*" >&2; }

# ─── Parse Arguments ─────────────────────────────────────────────────────────
while [[ $# -gt 0 ]]; do
    case "$1" in
        --upgrade)    ACTION="upgrade";    shift ;;
        --uninstall)  ACTION="uninstall";  shift ;;
        --version)    VERSION="$2";        shift 2 ;;
        --prefix)     INSTALL_PREFIX="$2"; BIN_DIR="${INSTALL_PREFIX}/bin"; shift 2 ;;
        --help|-h)
            echo "MDEMG Linux Installer"
            echo ""
            echo "Usage: install.sh [OPTIONS]"
            echo ""
            echo "Options:"
            echo "  --upgrade       Upgrade existing installation"
            echo "  --uninstall     Remove MDEMG"
            echo "  --version VER   Install specific version (e.g., v0.2.14)"
            echo "  --prefix DIR    Install prefix (default: /usr/local)"
            echo "  --help          Show this help"
            exit 0
            ;;
        *) error "Unknown option: $1"; exit 1 ;;
    esac
done

# ─── Detect Platform ─────────────────────────────────────────────────────────
detect_platform() {
    local os arch

    os="$(uname -s)"
    if [[ "$os" != "Linux" ]]; then
        error "This installer is for Linux only. Detected: $os"
        error "For macOS, use: brew install reh3376/mdemg/mdemg"
        error "For Windows, see: https://github.com/reh3376/mdemg-windows"
        exit 1
    fi

    arch="$(uname -m)"
    case "$arch" in
        x86_64)  arch="amd64" ;;
        aarch64) arch="arm64" ;;
        armv7l)  arch="armv7" ;;
        *)
            error "Unsupported architecture: $arch"
            exit 1
            ;;
    esac

    echo "linux_${arch}"
}

# ─── Detect Distro ───────────────────────────────────────────────────────────
detect_distro() {
    if [[ -f /etc/os-release ]]; then
        # shellcheck source=/dev/null
        . /etc/os-release
        echo "${ID:-unknown}"
    elif command -v lsb_release &>/dev/null; then
        lsb_release -si | tr '[:upper:]' '[:lower:]'
    else
        echo "unknown"
    fi
}

# ─── Check Prerequisites ─────────────────────────────────────────────────────
check_prerequisites() {
    local missing=()

    if ! command -v curl &>/dev/null && ! command -v wget &>/dev/null; then
        missing+=("curl or wget")
    fi
    if ! command -v tar &>/dev/null; then
        missing+=("tar")
    fi
    if ! command -v docker &>/dev/null; then
        missing+=("docker")
    fi

    if [[ ${#missing[@]} -gt 0 ]]; then
        error "Missing required tools: ${missing[*]}"
        echo ""
        local distro
        distro="$(detect_distro)"
        case "$distro" in
            ubuntu|debian|pop|linuxmint)
                info "Install with: sudo apt install ${missing[*]}" ;;
            fedora|rhel|centos|rocky|alma)
                info "Install with: sudo dnf install ${missing[*]}" ;;
            arch|manjaro|endeavouros)
                info "Install with: sudo pacman -S ${missing[*]}" ;;
            opensuse*)
                info "Install with: sudo zypper install ${missing[*]}" ;;
        esac
        exit 1
    fi

    # Check Docker daemon
    if ! docker info &>/dev/null; then
        warn "Docker daemon is not running or current user lacks permissions."
        echo ""
        info "Start Docker:       sudo systemctl start docker"
        info "Add user to group:  sudo usermod -aG docker \$USER"
        info "Then log out and back in for group changes to take effect."
    fi

    success "Prerequisites satisfied"
}

# ─── Get Latest Version ──────────────────────────────────────────────────────
get_latest_version() {
    local url="https://api.github.com/repos/${REPO}/releases/latest"
    if command -v curl &>/dev/null; then
        curl -fsSL "$url" | grep '"tag_name"' | head -1 | sed -E 's/.*"([^"]+)".*/\1/'
    else
        wget -qO- "$url" | grep '"tag_name"' | head -1 | sed -E 's/.*"([^"]+)".*/\1/'
    fi
}

# ─── Download & Install ──────────────────────────────────────────────────────
do_install() {
    local platform version tarball url tmpdir

    platform="$(detect_platform)"
    info "Detected platform: ${platform}"

    if [[ -n "$VERSION" ]]; then
        version="$VERSION"
    else
        info "Fetching latest release..."
        version="$(get_latest_version)"
    fi

    if [[ -z "$version" ]]; then
        error "Could not determine version. Use --version to specify."
        exit 1
    fi

    info "Installing MDEMG ${version} for ${platform}..."

    tarball="mdemg_${version#v}_${platform}.tar.gz"
    url="https://github.com/${REPO}/releases/download/${version}/${tarball}"

    tmpdir="$(mktemp -d)"
    trap 'rm -rf "$tmpdir"' EXIT

    info "Downloading ${url}..."
    if command -v curl &>/dev/null; then
        curl -fsSL -o "${tmpdir}/${tarball}" "$url"
    else
        wget -q -O "${tmpdir}/${tarball}" "$url"
    fi

    info "Extracting..."
    tar -xzf "${tmpdir}/${tarball}" -C "$tmpdir"

    # Install binary
    info "Installing to ${BIN_DIR}/mdemg..."
    sudo install -m 755 "${tmpdir}/mdemg" "${BIN_DIR}/mdemg"

    # Install man page if present
    if [[ -f "${tmpdir}/mdemg.1" ]]; then
        sudo mkdir -p "$MAN_DIR"
        sudo install -m 644 "${tmpdir}/mdemg.1" "${MAN_DIR}/mdemg.1"
    fi

    # Install bash completion if present
    if [[ -f "${tmpdir}/completions/mdemg.bash" ]]; then
        sudo mkdir -p "$BASH_COMPLETION_DIR"
        sudo install -m 644 "${tmpdir}/completions/mdemg.bash" "${BASH_COMPLETION_DIR}/mdemg"
    fi

    # Install systemd units (optional)
    if [[ -d /run/systemd/system ]]; then
        info "Installing systemd service files..."
        local script_dir
        script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
        if [[ -f "${script_dir}/systemd/mdemg.service" ]]; then
            sudo install -m 644 "${script_dir}/systemd/mdemg.service" "${SYSTEMD_DIR}/mdemg@.service"
            sudo install -m 644 "${script_dir}/systemd/mdemg-rsic.service" "${SYSTEMD_DIR}/mdemg-rsic@.service"
            sudo install -m 644 "${script_dir}/systemd/mdemg-rsic.timer" "${SYSTEMD_DIR}/mdemg-rsic@.timer"
            sudo systemctl daemon-reload
            info "Enable with: sudo systemctl enable --now mdemg@\$USER"
        fi
    fi

    success "MDEMG ${version} installed successfully!"
    echo ""
    info "Next steps:"
    info "  1. Verify:    mdemg version"
    info "  2. Init:      cd your-project && mdemg init"
    info "  3. Start:     mdemg start --auto-migrate"
    info "  4. Status:    mdemg status"
    echo ""
    info "Documentation: https://github.com/reh3376/mdemg_linux"
}

# ─── Upgrade ──────────────────────────────────────────────────────────────────
do_upgrade() {
    if ! command -v mdemg &>/dev/null; then
        error "MDEMG is not installed. Run without --upgrade to install."
        exit 1
    fi

    local current
    current="$(mdemg version 2>/dev/null | grep -oE 'v[0-9]+\.[0-9]+\.[0-9]+' || echo 'unknown')"
    info "Current version: ${current}"

    do_install

    local updated
    updated="$(mdemg version 2>/dev/null | grep -oE 'v[0-9]+\.[0-9]+\.[0-9]+' || echo 'unknown')"
    success "Upgraded: ${current} → ${updated}"
}

# ─── Uninstall ────────────────────────────────────────────────────────────────
do_uninstall() {
    info "Uninstalling MDEMG..."

    # Stop service if running
    if systemctl is-active --quiet "mdemg@${USER}" 2>/dev/null; then
        info "Stopping mdemg service..."
        sudo systemctl stop "mdemg@${USER}"
        sudo systemctl disable "mdemg@${USER}" 2>/dev/null || true
    fi

    # Remove binary
    if [[ -f "${BIN_DIR}/mdemg" ]]; then
        sudo rm -f "${BIN_DIR}/mdemg"
        success "Removed ${BIN_DIR}/mdemg"
    fi

    # Remove systemd units
    for unit in mdemg@.service mdemg-rsic@.service mdemg-rsic@.timer; do
        if [[ -f "${SYSTEMD_DIR}/${unit}" ]]; then
            sudo rm -f "${SYSTEMD_DIR}/${unit}"
            success "Removed ${SYSTEMD_DIR}/${unit}"
        fi
    done
    sudo systemctl daemon-reload 2>/dev/null || true

    # Remove man page
    if [[ -f "${MAN_DIR}/mdemg.1" ]]; then
        sudo rm -f "${MAN_DIR}/mdemg.1"
        success "Removed man page"
    fi

    # Remove bash completion
    if [[ -f "${BASH_COMPLETION_DIR}/mdemg" ]]; then
        sudo rm -f "${BASH_COMPLETION_DIR}/mdemg"
        success "Removed bash completion"
    fi

    success "MDEMG uninstalled."
    echo ""
    info "User data preserved in ~/.mdemg/"
    info "To remove all data: rm -rf ~/.mdemg"
    info "To remove Docker volumes: docker volume rm mdemg_neo4j_data"
}

# ─── Main ─────────────────────────────────────────────────────────────────────
main() {
    echo ""
    echo "╔══════════════════════════════════════╗"
    echo "║     MDEMG Linux Installer            ║"
    echo "║     Multi-Dimensional Emergent       ║"
    echo "║     Memory Graph                     ║"
    echo "╚══════════════════════════════════════╝"
    echo ""

    case "$ACTION" in
        install)   check_prerequisites; do_install ;;
        upgrade)   check_prerequisites; do_upgrade ;;
        uninstall) do_uninstall ;;
    esac
}

main
