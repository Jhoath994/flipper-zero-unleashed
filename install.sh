#!/bin/bash
# ============================================================
# flipper-zero-unleashed — One-command Flipper Zero deployer
# ============================================================
# This script deploys all unlocked apps and SubGHz signal files
# to a Flipper Zero connected via USB (DFU or serial mode).
#
# Usage:
#   ./install.sh              # Full install (apps + subghz + firmware)
#   ./install.sh --apps-only   # Only install FAP/FAL apps
#   ./install.sh --subghz-only # Only install .sub signal files
#   ./install.sh --firmware    # Flash Momentum firmware via DFU
#   ./install.sh --uninstall   # Remove all deployed files
#
# Requirements:
#   - Flipper Zero connected via USB
#   - flipper-scripts-cli or qflipper OR serial/dfu tools
#   - For DFU flash: dfu-util installed
#
# The Flipper SD card mounts at /ext/ when connected.
# ============================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FLIPPER_MOUNT=""
FLIPPER_MNT="/media/${USER}/Little OrangE"  # common auto-mount point
SERIAL_PORT=""

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

log()  { echo -e "${GREEN}[+]${NC} $*"; }
warn() { echo -e "${YELLOW}[!]${NC} $*"; }
err()  { echo -e "${RED}[-]${NC} $*"; }
info() { echo -e "${CYAN}[*]${NC} $*"; }

# ----------------------------------------------------------
# Detect Flipper connection
# ----------------------------------------------------------
detect_flipper() {
    # Method 1: Check if SD card is auto-mounted
    for mnt in "/media/${USER}/Little OrangG" "/media/${USER}/Little OrangE" \
               "/run/media/${USER}/Little OrangG" "/run/media/${USER}/Little OrangE" \
               "/mnt/flipper" "/media/flipper"; do
        if [ -d "$mnt" ]; then
            FLIPPER_MOUNT="$mnt"
            log "Found Flipper SD mounted at $mnt"
            return 0
        fi
    done

    # Method 2: Check if flipper CLI is available (Momentum/Unleashed serial)
    if command -v flipper &>/dev/null; then
        log "Found flipper CLI tool"
        return 0
    fi

    # Method 3: Check for /dev/ttyACM0 (Flipper CDC serial)
    if [ -c "/dev/ttyACM0" ]; then
        SERIAL_PORT="/dev/ttyACM0"
        log "Found Flipper serial at /dev/ttyACM0"
        return 0
    fi

    # Method 4: Check for /dev/serial/by-id Flipper device
    for dev in /dev/serial/by-id/*Flipper*; do
        if [ -e "$dev" ]; then
            SERIAL_PORT="$(readlink -f "$dev")"
            log "Found Flipper serial at $SERIAL_PORT"
            return 0
        fi
    done

    return 1
}

# ----------------------------------------------------------
# Send command via serial
# ----------------------------------------------------------
serial_cmd() {
    local cmd="$1"
    if [ -n "$SERIAL_PORT" ]; then
        echo "$cmd" > "$SERIAL_PORT" 2>/dev/null || true
        sleep 0.5
    fi
}

# ----------------------------------------------------------
# Ensure directory exists on Flipper SD
# ----------------------------------------------------------
ensure_dir() {
    local dir="$1"
    if [ -n "$FLIPPER_MOUNT" ]; then
        mkdir -p "$FLIPPER_MOUNT/$dir"
    else
        serial_cmd "mkdir $dir"
    fi
}

# ----------------------------------------------------------
# Copy file/dir to Flipper SD
# ----------------------------------------------------------
flipper_cp() {
    local src="$1"
    local dst="$2"
    if [ -n "$FLIPPER_MOUNT" ]; then
        cp -r "$src" "$FLIPPER_MOUNT/$dst" 2>/dev/null || warn "Failed to copy $src"
    else
        # Use serial storage API (slow but works without mount)
        warn "Serial-only mode: manual file copy required. Mount SD card for automatic deployment."
        return 1
    fi
}

# ----------------------------------------------------------
# Install FAP/FAL apps
# ----------------------------------------------------------
install_apps() {
    log "Installing unlocked apps..."

    # ProtoPirate (fully unlocked: emulate, timing tuner, sub-decode, debug logs)
    ensure_dir "apps/Sub-GHz"
    ensure_dir "apps_data/proto_pirate"
    ensure_dir "apps_data/proto_pirate/plugins"

    log "  ProtoPirate v3.0 (UNLOCKED — all features enabled)"
    flipper_cp "$SCRIPT_DIR/apps/proto_pirate.fap" "apps/Sub-GHz/"
    flipper_cp "$SCRIPT_DIR/apps/protopirate_am_plugin.fal" "apps_data/proto_pirate/plugins/"
    flipper_cp "$SCRIPT_DIR/apps/protopirate_fm_plugin.fal" "apps_data/proto_pirate/plugins/"
    flipper_cp "$SCRIPT_DIR/apps/protopirate_emulate_plugin.fal" "apps_data/proto_pirate/plugins/"
    flipper_cp "$SCRIPT_DIR/apps/protopirate_psa_bf_plugin.fal" "apps_data/proto_pirate/plugins/"

    # ProtoPirate keystore files
    flipper_cp "$SCRIPT_DIR/apps/keystore/" "apps_data/proto_pirate/keystore/"

    # AU SubGHz Brute Force
    log "  AU SubGHz Brute Force (8 protocols, state persistence)"
    flipper_cp "$SCRIPT_DIR/apps/au_subghz_brute.fap" "apps/Sub-GHz/"

    # AU RollJam (requires external CC1101 on GPIO)
    log "  AU RollJam (rolling code capture + replay, ext CC1101)"
    flipper_cp "$SCRIPT_DIR/apps/au_rolljam.fap" "apps/Sub-GHz/"

    log "Apps installed successfully!"
}

# ----------------------------------------------------------
# Install SubGHz signal files
# ----------------------------------------------------------
install_subghz() {
    log "Installing SubGHz signal files..."

    # AU top fixed-code keys (try these FIRST)
    log "  AU top fixed codes (48 files — highest hit-rate)"
    ensure_dir "subghz/car_hacks_au/keys"
    for dir in "$SCRIPT_DIR/subghz/au_keys"/*/; do
        [ -d "$dir" ] && flipper_cp "$dir" "subghz/car_hacks_au/keys/$(basename "$dir")/"
    done

    # AU gate opener files
    log "  AU gate opener signals"
    ensure_dir "subghz/car_hacks_au/gates"
    for dir in "$SCRIPT_DIR/subghz/au_gates"/*/; do
        [ -d "$dir" ] && flipper_cp "$dir" "subghz/car_hacks_au/gates/$(basename "$dir")/"
    done

    # Gate brute-force files (433 MHz protocols)
    log "  Gate brute-force sets (SMC5326 330MHz)"
    ensure_dir "subghz/gate_bruteforce"
    flipper_cp "$SCRIPT_DIR/subghz/gate_bruteforce/" "subghz/gate_bruteforce/"

    # European automotive collection
    log "  European automotive signals (132 .sub files, 14 brands)"
    ensure_dir "subghz/euro_automotive"
    flipper_cp "$SCRIPT_DIR/subghz/euro_automotive/" "subghz/euro_automotive/"

    # Playlists
    log "  Playlists (Sub-GHz Playlist plugin format)"
    ensure_dir "subghz/playlists"
    flipper_cp "$SCRIPT_DIR/subghz/playlists/" "subghz/playlists/"

    # SubGHz assets (keeloq mf codes, setting_user with AU frequencies)
    log "  SubGHz assets (KeeLoq manufacturer codes, custom presets)"
    ensure_dir "subghz/assets"

    # Merge setting_user (append, don't overwrite existing!)
    if [ -n "$FLIPPER_MOUNT" ] && [ -f "$SCRIPT_DIR/subghz/assets/setting_user" ]; then
        if [ -f "$FLIPPER_MOUNT/subghz/assets/setting_user" ]; then
            warn "  Existing setting_user found — merging (append mode)"
            # Append only new frequency/preset lines that don't already exist
            while IFS= read -r line; do
                grep -qF "$line" "$FLIPPER_MOUNT/subghz/assets/setting_user" 2>/dev/null || \
                    echo "$line" >> "$FLIPPER_MOUNT/subghz/assets/setting_user"
            done < "$SCRIPT_DIR/subghz/assets/setting_user"
        else
            cp "$SCRIPT_DIR/subghz/assets/setting_user" "$FLIPPER_MOUNT/subghz/assets/setting_user"
        fi
    fi

    # Merge keeloq_mfcodes_user (append, don't overwrite!)
    if [ -n "$FLIPPER_MOUNT" ] && [ -f "$SCRIPT_DIR/subghz/assets/keeloq_mfcodes_user" ]; then
        if [ -f "$FLIPPER_MOUNT/subghz/assets/keeloq_mfcodes_user" ]; then
            warn "  Existing keeloq_mfcodes_user found — merging (append mode)"
            while IFS= read -r line; do
                grep -qF "$line" "$FLIPPER_MOUNT/subghz/assets/keeloq_mfcodes_user" 2>/dev/null || \
                    echo "$line" >> "$FLIPPER_MOUNT/subghz/assets/keeloq_mfcodes_user"
            done < "$SCRIPT_DIR/subghz/assets/keeloq_mfcodes_user"
        else
            cp "$SCRIPT_DIR/subghz/assets/keeloq_mfcodes_user" "$FLIPPER_MOUNT/subghz/assets/keeloq_mfcodes_user"
        fi
    fi

    log "SubGHz signal files installed!"
}

# ----------------------------------------------------------
# Flash Momentum firmware via DFU
# ----------------------------------------------------------
install_firmware() {
    log "Checking for Momentum firmware..."

    # Check if dfu-util is available
    if ! command -v dfu-util &>/dev/null; then
        err "dfu-util not found. Install it first:"
        err "  Debian/Ubuntu: sudo apt install dfu-util"
        err "  macOS: brew install dfu-util"
        err "  Arch: sudo pacman -S dfu-util"
        exit 1
    fi

    # Download latest Momentum firmware DFU if not already present
    local fw_file="$SCRIPT_DIR/firmware/momentum.dfu"
    if [ ! -f "$fw_file" ]; then
        log "Downloading latest Momentum firmware..."
        mkdir -p "$SCRIPT_DIR/firmware"
        # Fetch the latest release URL from GitHub API
        local release_url
        release_url=$(curl -sL https://api.github.com/repos/Next-Flip/Momentum-Firmware/releases/latest \
            | grep "browser_download_url.*f7.*dfu" | head -1 | cut -d'"' -f4)
        if [ -n "$release_url" ]; then
            curl -sL "$release_url" -o "$fw_file"
            log "Downloaded: $fw_file"
        else
            err "Could not find Momentum DFU release. Download manually from:"
            err "  https://github.com/Next-Flip/Momentum-Firmware/releases"
            err "  Place the .dfu file at: $SCRIPT_DIR/firmware/momentum.dfu"
            exit 1
        fi
    fi

    log "Putting Flipper into DFU mode..."
    info "Hold DOWN button + press RESET (or: Left Back + OK for 5 sec)"
    info "The Flipper screen will show 'DFU' mode"
    sleep 2

    log "Flashing firmware via DFU..."
    sudo dfu-util -a 0 -s 0x08000000:leave -D "$fw_file" || {
        err "DFU flash failed. Make sure:"
        err "  1. Flipper is in DFU mode (screen shows DFU)"
        err "  2. USB cable is data-capable (not charge-only)"
        err "  3. No other DFU devices are connected"
        exit 1
    }

    log "Firmware flashed successfully! Flipper will reboot."
    log "After reboot, run this script again with --apps-only and --subghz-only to deploy content."
}

# ----------------------------------------------------------
# Uninstall
# ----------------------------------------------------------
uninstall() {
    warn "Removing all deployed files from Flipper..."

    if [ -z "$FLIPPER_MOUNT" ]; then
        err "No Flipper mount point found. Connect Flipper and try again."
        exit 1
    fi

    # Remove apps
    rm -f "$FLIPPER_MOUNT/apps/Sub-GHz/proto_pirate.fap" 2>/dev/null
    rm -f "$FLIPPER_MOUNT/apps/Sub-GHz/au_subghz_brute.fap" 2>/dev/null
    rm -f "$FLIPPER_MOUNT/apps/Sub-GHz/au_rolljam.fap" 2>/dev/null
    rm -rf "$FLIPPER_MOUNT/apps_data/proto_pirate/" 2>/dev/null

    # Remove subghz files
    rm -rf "$FLIPPER_MOUNT/subghz/car_hacks_au/" 2>/dev/null
    rm -rf "$FLIPPER_MOUNT/subghz/euro_automotive/" 2>/dev/null
    rm -rf "$FLIPPER_MOUNT/subghz/gate_bruteforce/" 2>/dev/null
    rm -rf "$FLIPPER_MOUNT/subghz/playlists/" 2>/dev/null

    warn "NOTE: setting_user and keeloq_mfcodes_user were NOT removed (may contain your own data)"
    log "Uninstall complete."
}

# ----------------------------------------------------------
# Summary
# ----------------------------------------------------------
show_summary() {
    echo ""
    echo "============================================================"
    echo "  FLIPPER ZERO UNLEASHED — Deploy Summary"
    echo "============================================================"
    echo ""
    echo "  APPS (all unlocked, no feature gates):"
    echo "    ProtoPirate v3.0  — Emulate, Timing Tuner, Sub Decode, Debug Logs"
    echo "                         AM/FM/Emulate/PSA-BF plugins included"
    echo "    AU SubGHz Brute   — 8 protocols @ 433.92 MHz, state persistence"
    echo "    AU RollJam        — Rolling code capture (requires ext CC1101)"
    echo ""
    echo "  SUBGHZ SIGNALS:"
    echo "    AU Top Keys       — 48 highest hit-rate fixed codes"
    echo "    AU Gates          — ATA, CAME, Nice FLO, Princeton, PT2260"
    echo "    AU Cars           — 17 brands, 70K+ total files"
    echo "    EU Automotive     — 132 .sub files, 14 car brands"
    echo "    Gate Brute-force  — SMC5326 330MHz"
    echo "    Playlists         — Sub-GHz Playlist plugin format"
    echo "    Assets            — KeeLoq mf codes, AU frequency presets"
    echo ""
    echo "  PROTOCOLS (ProtoPirate unlocked):"
    echo "    Subaru, Ford v0-v3, Kia v0-v7, Honda v1/static,"
    echo "    Fiat v0/v1, PSA, VAG, Scher-Khan, Star-Line,"
    echo "    Chrysler, Porsche Touareg, AUT64, Land Rover,"
    echo "    Mazda, Mitsubishi, CAME, Nice, KeeLoq"
    echo ""
    if [ -n "$FLIPPER_MOUNT" ]; then
        echo "  DEPLOYED TO: $FLIPPER_MOUNT"
    else
        echo "  FLIPPER: Not connected (see connection instructions below)"
    fi
    echo ""
    echo "  NEXT STEPS:"
    echo "    1. Reboot Flipper after first deployment"
    echo "    2. Launch ProtoPirate from Apps > Sub-GHz"
    echo "    3. Emulate feature is ON by default"
    echo "    4. For AU ops: use 433.92 MHz frequency"
    echo "    5. Try KEYS_TOP_CODES_playlist.txt first on any job"
    echo "    6. For rolling codes: connect ext CC1101 to GPIO for RollJam"
    echo "============================================================"
}

# ----------------------------------------------------------
# Main
# ----------------------------------------------------------
MODE="full"

case "${1:-}" in
    --apps-only)    MODE="apps" ;;
    --subghz-only)  MODE="subghz" ;;
    --firmware)     MODE="firmware" ;;
    --uninstall)    MODE="uninstall" ;;
    --help|-h)      MODE="help" ;;
    "")             MODE="full" ;;
    *)              err "Unknown option: $1"; MODE="help" ;;
esac

if [ "$MODE" = "help" ]; then
    echo "Usage: $0 [OPTION]"
    echo ""
    echo "Options:"
    echo "  (no option)      Full install: apps + subghz + firmware"
    echo "  --apps-only       Install FAP/FAL apps only"
    echo "  --subghz-only     Install .sub signal files only"
    echo "  --firmware        Flash Momentum firmware via DFU"
    echo "  --uninstall       Remove all deployed files"
    echo "  --help            Show this help"
    echo ""
    echo "Connection methods:"
    echo "  1. USB Mass Storage: Flipper shows as 'Little OrangE' drive"
    echo "  2. Serial CDC: /dev/ttyACM0 (for CLI commands)"
    echo "  3. DFU Mode: Hold DOWN + RESET for firmware flash"
    exit 0
fi

echo ""
info "flipper-zero-unleashed installer"
echo ""

# Detect Flipper
if ! detect_flipper; then
    warn "Flipper not detected!"
    echo ""
    echo "Connect your Flipper Zero via USB and ensure it's in one of these modes:"
    echo "  - Storage Mode: Flipper > Settings > System > Storage (shows as USB drive)"
    echo "  - DFU Mode: Hold DOWN button + press RESET (for firmware flash only)"
    echo ""
    echo "The Flipper SD card should auto-mount. Check with: ls /media/\$USER/"
    echo ""
    if [ "$MODE" = "firmware" ]; then
        info "DFU mode detected is not needed for firmware check — continuing with DFU flash..."
    else
        err "Cannot deploy files without Flipper connection. Aborting."
        exit 1
    fi
fi

case "$MODE" in
    full)
        install_apps
        install_subghz
        ;;
    apps)
        install_apps
        ;;
    subghz)
        install_subghz
        ;;
    firmware)
        install_firmware
        ;;
    uninstall)
        uninstall
        ;;
esac

show_summary
log "Done!"
