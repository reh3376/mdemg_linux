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
SHARE_DIR="${INSTALL_PREFIX}/share/mdemg"
SYSTEMD_DIR="/etc/systemd/system"
BASH_COMPLETION_DIR="/etc/bash_completion.d"
ZSH_COMPLETION_DIR="${INSTALL_PREFIX}/share/zsh/site-functions"
FISH_COMPLETION_DIR="${INSTALL_PREFIX}/share/fish/vendor_completions.d"
MAN_DIR="${INSTALL_PREFIX}/share/man/man1"
VERSION=""
ACTION="install"
NO_PLUGINS=false

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
        --prefix)     INSTALL_PREFIX="$2"; BIN_DIR="${INSTALL_PREFIX}/bin"; SHARE_DIR="${INSTALL_PREFIX}/share/mdemg"; shift 2 ;;
        --no-plugins) NO_PLUGINS=true;     shift ;;
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
            echo "  --no-plugins    Skip UxTS plugin installation"
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

    # Download tarball
    info "Downloading ${url}..."
    if command -v curl &>/dev/null; then
        curl -fsSL -o "${tmpdir}/${tarball}" "$url"
    else
        wget -q -O "${tmpdir}/${tarball}" "$url"
    fi

    # Download and verify SHA256 checksum (mirrors Windows Install-MDEMG.ps1 pattern)
    local checksums_url="https://github.com/${REPO}/releases/download/${version}/checksums.txt"
    info "Verifying checksum..."
    local checksums_file="${tmpdir}/checksums.txt"
    if command -v curl &>/dev/null; then
        curl -fsSL -o "$checksums_file" "$checksums_url" 2>/dev/null || true
    else
        wget -q -O "$checksums_file" "$checksums_url" 2>/dev/null || true
    fi

    if [[ -f "$checksums_file" && -s "$checksums_file" ]]; then
        local expected_hash actual_hash
        expected_hash=$(grep "${tarball}" "$checksums_file" | awk '{print $1}')
        if [[ -n "$expected_hash" ]]; then
            actual_hash=$(sha256sum "${tmpdir}/${tarball}" | awk '{print $1}')
            if [[ "$expected_hash" == "$actual_hash" ]]; then
                success "Checksum verified (SHA256)"
            else
                error "Checksum mismatch!"
                error "  Expected: ${expected_hash}"
                error "  Actual:   ${actual_hash}"
                exit 1
            fi
        else
            warn "No checksum entry found for ${tarball} — skipping verification"
        fi
    else
        warn "checksums.txt not available — skipping verification"
    fi

    info "Extracting..."
    tar -xzf "${tmpdir}/${tarball}" -C "$tmpdir"

    # Install binary
    info "Installing to ${BIN_DIR}/mdemg..."
    sudo mkdir -p "$BIN_DIR"
    sudo install -m 755 "${tmpdir}/mdemg" "${BIN_DIR}/mdemg"

    # Install man pages (all of them, mirrors Homebrew formula: man1.install Dir["man/man1/*.1"])
    if [[ -d "${tmpdir}/man/man1" ]]; then
        info "Installing man pages..."
        sudo mkdir -p "$MAN_DIR"
        for manfile in "${tmpdir}"/man/man1/*.1; do
            [[ -f "$manfile" ]] && sudo install -m 644 "$manfile" "${MAN_DIR}/"
        done
        success "Man pages installed to ${MAN_DIR}/"
    fi

    # Install UxTS plugin (mirrors Homebrew formula: share/"mdemg/plugins/uxts-module")
    if [[ "$NO_PLUGINS" != true ]]; then
        if [[ -f "${tmpdir}/uxts-module" ]]; then
            info "Installing UxTS plugin..."
            local plugdir="${SHARE_DIR}/plugins/uxts-module"
            sudo mkdir -p "$plugdir"
            sudo install -m 755 "${tmpdir}/uxts-module" "${plugdir}/uxts-module"
            if [[ -f "${tmpdir}/plugins/uxts-module/manifest.json" ]]; then
                sudo install -m 644 "${tmpdir}/plugins/uxts-module/manifest.json" "${plugdir}/manifest.json"
            fi
            success "UxTS plugin installed to ${plugdir}/"
        fi
    fi

    # Install shell completions
    if [[ -f "${tmpdir}/completions/mdemg.bash" ]]; then
        info "Installing shell completions..."
        sudo mkdir -p "$BASH_COMPLETION_DIR"
        sudo install -m 644 "${tmpdir}/completions/mdemg.bash" "${BASH_COMPLETION_DIR}/mdemg"
    fi
    if [[ -f "${tmpdir}/completions/mdemg.zsh" ]]; then
        sudo mkdir -p "$ZSH_COMPLETION_DIR"
        sudo install -m 644 "${tmpdir}/completions/mdemg.zsh" "${ZSH_COMPLETION_DIR}/_mdemg"
    fi
    if [[ -f "${tmpdir}/completions/mdemg.fish" ]]; then
        sudo mkdir -p "$FISH_COMPLETION_DIR"
        sudo install -m 644 "${tmpdir}/completions/mdemg.fish" "${FISH_COMPLETION_DIR}/mdemg.fish"
    fi

    # Install systemd units (if systemd is available)
    # Units are bundled in the release tarball under systemd/ (goreleaser archives.files)
    if [[ -d /run/systemd/system ]]; then
        if [[ -f "${tmpdir}/systemd/mdemg.service" ]]; then
            info "Installing systemd service files..."
            sudo install -m 644 "${tmpdir}/systemd/mdemg.service" "${SYSTEMD_DIR}/mdemg@.service"
            sudo install -m 644 "${tmpdir}/systemd/mdemg-rsic.service" "${SYSTEMD_DIR}/mdemg-rsic@.service"
            sudo install -m 644 "${tmpdir}/systemd/mdemg-rsic.timer" "${SYSTEMD_DIR}/mdemg-rsic@.timer"
            sudo systemctl daemon-reload
            info "Enable with: sudo systemctl enable --now mdemg@\$USER"
        fi
    fi

    # Write VERSION file (mirrors Windows Install-MDEMG.ps1 pattern)
    local version_file="${BIN_DIR}/../share/mdemg/VERSION"
    sudo mkdir -p "$(dirname "$version_file")"
    sudo tee "$version_file" > /dev/null <<VEOF
{
  "version": "${version#v}",
  "installed_at": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "platform": "${platform}",
  "installer": "install.sh",
  "prefix": "${INSTALL_PREFIX}"
}
VEOF

    success "MDEMG ${version} installed successfully!"
    echo ""
    info "Next steps:"
    info "  1. Verify:    mdemg version"
    info "  2. Init:      cd your-project && mdemg init"
    info "  3. Start:     mdemg start --auto-migrate"
    info "  4. Status:    mdemg status"
    info "  5. Jiminy:    Inner-voice guidance configured during 'mdemg init'"
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

    # Remove man pages
    local removed_man=0
    for manfile in "${MAN_DIR}"/mdemg*.1; do
        if [[ -f "$manfile" ]]; then
            sudo rm -f "$manfile"
            removed_man=$((removed_man + 1))
        fi
    done
    [[ $removed_man -gt 0 ]] && success "Removed ${removed_man} man page(s)"

    # Remove UxTS plugin
    if [[ -d "${SHARE_DIR}/plugins/uxts-module" ]]; then
        sudo rm -rf "${SHARE_DIR}/plugins/uxts-module"
        success "Removed UxTS plugin"
    fi

    # Remove VERSION file
    if [[ -f "${SHARE_DIR}/VERSION" ]]; then
        sudo rm -f "${SHARE_DIR}/VERSION"
    fi

    # Clean up share dir if empty
    sudo rmdir "${SHARE_DIR}/plugins" "${SHARE_DIR}" 2>/dev/null || true

    # Remove shell completions
    for comp_file in "${BASH_COMPLETION_DIR}/mdemg" "${ZSH_COMPLETION_DIR}/_mdemg" "${FISH_COMPLETION_DIR}/mdemg.fish"; do
        if [[ -f "$comp_file" ]]; then
            sudo rm -f "$comp_file"
            success "Removed $(basename "$comp_file")"
        fi
    done

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
