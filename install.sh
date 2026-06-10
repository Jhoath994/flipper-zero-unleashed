#!/bin/bash
# ============================================================
# flipper-zero-unleashed — One-command Flipper Zero deployer
# ============================================================
# Deploys all unlocked apps, SubGHz signals, NFC dicts, IR remotes,
# and BadUSB payloads to a Flipper Zero connected via USB.
#
# Optimized for AUSTRALIA (433.92 MHz SubGHz band).
#
# Usage:
#   ./install.sh              # Full install (apps + subghz + nfc + ir + badusb)
#   ./install.sh --apps-only   # Only install FAP/FAL apps
#   ./install.sh --subghz-only # Only install .sub signal files
#   ./install.sh --nfc-only    # Only install NFC dictionaries
#   ./install.sh --ir-only     # Only install IR remote files
#   ./install.sh --badusb-only # Only install BadUSB payloads
#   ./install.sh --firmware    # Flash Momentum firmware via DFU
#   ./install.sh --uninstall   # Remove all deployed files
#
# Requirements:
#   - Flipper Zero connected via USB (Storage/DFU/serial mode)
#   - For DFU flash: dfu-util installed
# ============================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FLIPPER_MOUNT=""
FLIPPER_MNT="/media/${USER}/Little OrangE"
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
    for mnt in "/media/${USER}/Little OrangG" "/media/${USER}/Little OrangE" \
               "/run/media/${USER}/Little OrangG" "/run/media/${USER}/Little OrangE" \
               "/mnt/flipper" "/media/flipper"; do
        if [ -d "$mnt" ]; then
            FLIPPER_MOUNT="$mnt"
            log "Found Flipper SD mounted at $mnt"
            return 0
        fi
    done

    if command -v flipper &>/dev/null; then
        log "Found flipper CLI tool"
        return 0
    fi

    if [ -c "/dev/ttyACM0" ]; then
        SERIAL_PORT="/dev/ttyACM0"
        log "Found Flipper serial at /dev/ttyACM0"
        return 0
    fi

    for dev in /dev/serial/by-id/*Flipper*; do
        if [ -e "$dev" ]; then
            SERIAL_PORT="$(readlink -f "$dev")"
            log "Found Flipper serial at $SERIAL_PORT"
            return 0
        fi
    done

    return 1
}

serial_cmd() {
    local cmd="$1"
    if [ -n "$SERIAL_PORT" ]; then
        echo "$cmd" > "$SERIAL_PORT" 2>/dev/null || true
        sleep 0.5
    fi
}

ensure_dir() {
    local dir="$1"
    if [ -n "$FLIPPER_MOUNT" ]; then
        mkdir -p "$FLIPPER_MOUNT/$dir"
    else
        serial_cmd "mkdir $dir"
    fi
}

flipper_cp() {
    local src="$1"
    local dst="$2"
    if [ -n "$FLIPPER_MOUNT" ]; then
        cp -r "$src" "$FLIPPER_MOUNT/$dst" 2>/dev/null || warn "Failed to copy $src"
    else
        warn "Serial-only mode: mount SD card for automatic deployment."
        return 1
    fi
}

# ----------------------------------------------------------
# Install FAP/FAL apps
# ----------------------------------------------------------
install_apps() {
    log "Installing unlocked apps..."

    # Sub-GHz apps
    ensure_dir "apps/Sub-GHz"
    ensure_dir "apps_data/proto_pirate"
    ensure_dir "apps_data/proto_pirate/plugins"

    log "  ProtoPirate v3.0 (ALL FEATURES UNLOCKED)"
    flipper_cp "$SCRIPT_DIR/apps/proto_pirate.fap" "apps/Sub-GHz/"
    flipper_cp "$SCRIPT_DIR/apps/protopirate_am_plugin.fal" "apps_data/proto_pirate/plugins/"
    flipper_cp "$SCRIPT_DIR/apps/protopirate_fm_plugin.fal" "apps_data/proto_pirate/plugins/"
    flipper_cp "$SCRIPT_DIR/apps/protopirate_emulate_plugin.fal" "apps_data/proto_pirate/plugins/"
    flipper_cp "$SCRIPT_DIR/apps/protopirate_psa_bf_plugin.fal" "apps_data/proto_pirate/plugins/"
    [ -d "$SCRIPT_DIR/apps/keystore" ] && flipper_cp "$SCRIPT_DIR/apps/keystore/" "apps_data/proto_pirate/keystore/"

    log "  AU SubGHz Brute Force (8 protocols @ 433.92 MHz)"
    flipper_cp "$SCRIPT_DIR/apps/au_subghz_brute.fap" "apps/Sub-GHz/"

    log "  AU RollJam (rolling code capture, ext CC1101)"
    flipper_cp "$SCRIPT_DIR/apps/au_rolljam.fap" "apps/Sub-GHz/"

    log "  CarJacker (car key fob analysis)"
    flipper_cp "$SCRIPT_DIR/apps/carjacker.fap" "apps/Sub-GHz/"

    log "  RF Jammer (multi-freq, adjustable)"
    flipper_cp "$SCRIPT_DIR/apps/rf_jammer_jammer_app.fap" "apps/Sub-GHz/"

    log "  SubGHz Toolkit (signal gen/analyzer)"
    flipper_cp "$SCRIPT_DIR/apps/subghz_toolkit.fap" "apps/Sub-GHz/"

    log "  SubGHz Jammer Detector"
    flipper_cp "$SCRIPT_DIR/apps/subghz_jammer_detect.fap" "apps/Sub-GHz/"

    log "  ProtoPirate Extra (extended decoder)"
    flipper_cp "$SCRIPT_DIR/apps/proto_pirate_extra.fap" "apps/Sub-GHz/"

    # NFC apps
    ensure_dir "apps/NFC"
    log "  NFC Magic (card write/clone)"
    flipper_cp "$SCRIPT_DIR/apps/nfc_magic.fap" "apps/NFC/"

    log "  NFC Fuzzer (protocol fuzzer)"
    flipper_cp "$SCRIPT_DIR/apps/nfc_fuzzer.fap" "apps/NFC/"

    log "  NFC Detector (field detector)"
    flipper_cp "$SCRIPT_DIR/apps/nfc_detector.fap" "apps/NFC/"

    log "  NFC Sniffer (traffic sniffer)"
    flipper_cp "$SCRIPT_DIR/apps/nfc_sniffer.fap" "apps/NFC/"

    log "  NFC Relay (relay attack)"
    flipper_cp "$SCRIPT_DIR/apps/nfc_relay.fap" "apps/NFC/"

    log "  MFKey (MIFARE Classic key recovery)"
    flipper_cp "$SCRIPT_DIR/apps/mfkey.fap" "apps/NFC/"
    flipper_cp "$SCRIPT_DIR/apps/mfkey_init_plugin.fal" "apps/NFC/"

    log "  ULCBrute (MIFARE Ultralight C brute)"
    flipper_cp "$SCRIPT_DIR/apps/ulcbrute.fap" "apps/NFC/"

    # IR apps
    ensure_dir "apps/Infrared"
    log "  IR Blaster (IR blaster/spammer)"
    flipper_cp "$SCRIPT_DIR/apps/irblaster.fap" "apps/Infrared/"

    # BadUSB apps
    ensure_dir "apps/Bad USB"
    log "  BadUSB Pro (enhanced script engine)"
    flipper_cp "$SCRIPT_DIR/apps/badusb_pro.fap" "apps/Bad USB/"

    log "  USB HID Autofire"
    flipper_cp "$SCRIPT_DIR/apps/usb_hid_autofire.fap" "apps/Bad USB/"

    # GPIO apps
    ensure_dir "apps/GPIO"
    log "  GPIO Explorer (pin explorer)"
    flipper_cp "$SCRIPT_DIR/apps/gpio_explorer.fap" "apps/GPIO/"

    log "Apps installed successfully!"
}

# ----------------------------------------------------------
# Install SubGHz signal files
# ----------------------------------------------------------
install_subghz() {
    log "Installing SubGHz signal files..."

    # AU-specific files (433.92 MHz — TRY THESE FIRST)
    log "  AU car fob signals (676 .sub files — 17 AU car brands)"
    ensure_dir "subghz/au_specific"
    [ -d "$SCRIPT_DIR/subghz/au_specific" ] && flipper_cp "$SCRIPT_DIR/subghz/au_specific/" "subghz/au_specific/"

    # AU top fixed-code keys
    log "  AU top fixed codes (highest hit-rate keys)"
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

    # CAME/NICE 433 MHz brute-force
    log "  CAME/NICE 433 MHz brute-force sets"
    ensure_dir "subghz/bruteforce-433"
    [ -d "$SCRIPT_DIR/subghz/bruteforce-433" ] && flipper_cp "$SCRIPT_DIR/subghz/bruteforce-433/" "subghz/bruteforce-433/"

    # CAME 433 brute
    log "  CAME 433 gate brute-force"
    ensure_dir "subghz/CAME-bruteforce"
    [ -d "$SCRIPT_DIR/subghz/CAME-bruteforce" ] && flipper_cp "$SCRIPT_DIR/subghz/CAME-bruteforce/" "subghz/CAME-bruteforce/"

    # Gate brute-force files
    log "  Gate brute-force sets (SMC5326 330MHz)"
    ensure_dir "subghz/gate_bruteforce"
    [ -d "$SCRIPT_DIR/subghz/gate_bruteforce" ] && flipper_cp "$SCRIPT_DIR/subghz/gate_bruteforce/" "subghz/gate_bruteforce/"

    # UberGuidoZ SubGHz collection
    log "  UberGuidoZ SubGHz collection (11,290 .sub files)"
    ensure_dir "subghz/UberGuidoZ"
    [ -d "$SCRIPT_DIR/subghz/UberGuidoZ" ] && flipper_cp "$SCRIPT_DIR/subghz/UberGuidoZ/" "subghz/UberGuidoZ/"

    # RocketGod SubGHz collection
    log "  RocketGod SubGHz collection (21,948 .sub files)"
    ensure_dir "subghz/rocketgod_sd"
    [ -d "$SCRIPT_DIR/subghz/rocketgod_sd" ] && flipper_cp "$SCRIPT_DIR/subghz/rocketgod_sd/" "subghz/rocketgod_sd/"

    # European automotive
    log "  European automotive signals (132 .sub files)"
    ensure_dir "subghz/euro_automotive"
    [ -d "$SCRIPT_DIR/subghz/euro_automotive" ] && flipper_cp "$SCRIPT_DIR/subghz/euro_automotive/" "subghz/euro_automotive/"

    # Playlists
    log "  AU SubGHz playlists"
    ensure_dir "subghz/playlists"
    [ -d "$SCRIPT_DIR/subghz/playlists" ] && flipper_cp "$SCRIPT_DIR/subghz/playlists/" "subghz/playlists/"
    [ -d "$SCRIPT_DIR/subghz/subplaylist" ] && flipper_cp "$SCRIPT_DIR/subghz/subplaylist/" "subghz/subplaylist/"

    # SubGHz assets
    log "  SubGHz assets (KeeLoq codes, AU presets)"
    ensure_dir "subghz/assets"

    # Merge setting_user (append, don't overwrite!)
    if [ -n "$FLIPPER_MOUNT" ] && [ -f "$SCRIPT_DIR/subghz/assets/setting_user" ]; then
        if [ -f "$FLIPPER_MOUNT/subghz/assets/setting_user" ]; then
            warn "  Existing setting_user found — merging"
            while IFS= read -r line; do
                grep -qF "$line" "$FLIPPER_MOUNT/subghz/assets/setting_user" 2>/dev/null || \
                    echo "$line" >> "$FLIPPER_MOUNT/subghz/assets/setting_user"
            done < "$SCRIPT_DIR/subghz/assets/setting_user"
        else
            cp "$SCRIPT_DIR/subghz/assets/setting_user" "$FLIPPER_MOUNT/subghz/assets/setting_user"
        fi
    fi

    # Merge keeloq_mfcodes_user
    if [ -n "$FLIPPER_MOUNT" ] && [ -f "$SCRIPT_DIR/subghz/assets/keeloq_mfcodes_user" ]; then
        if [ -f "$FLIPPER_MOUNT/subghz/assets/keeloq_mfcodes_user" ]; then
            warn "  Existing keeloq_mfcodes_user found — merging"
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
# Install NFC dictionaries and files
# ----------------------------------------------------------
install_nfc() {
    log "Installing NFC/RFID dictionaries and files..."

    # AU NFC dictionaries
    log "  AU NFC key dictionaries (4,483+ MIFARE keys)"
    ensure_dir "nfc/au_dicts"
    [ -d "$SCRIPT_DIR/nfc/au_dicts" ] && flipper_cp "$SCRIPT_DIR/nfc/au_dicts/" "nfc/au_dicts/"

    # AU NFC keys
    log "  AU NFC key files"
    ensure_dir "nfc/au_keys"
    [ -d "$SCRIPT_DIR/nfc/au_keys" ] && flipper_cp "$SCRIPT_DIR/nfc/au_keys/" "nfc/au_keys/"

    # NFC dictionaries
    log "  Global NFC dictionaries"
    ensure_dir "nfc"
    [ -f "$SCRIPT_DIR/nfc/mf_classic_dict_user.nfc" ] && flipper_cp "$SCRIPT_DIR/nfc/mf_classic_dict_user.nfc" "nfc/"
    [ -f "$SCRIPT_DIR/nfc/mf_classic_dict.nfc" ] && flipper_cp "$SCRIPT_DIR/nfc/mf_classic_dict.nfc" "nfc/"

    # RocketGod NFC collection
    log "  RocketGod NFC collection (2,108 .nfc files)"
    ensure_dir "nfc/rocketgod"
    [ -d "$SCRIPT_DIR/nfc/rocketgod" ] && flipper_cp "$SCRIPT_DIR/nfc/rocketgod/" "nfc/rocketgod/"

    # NFC fun files
    log "  NFC fun files"
    ensure_dir "nfc/Fun_Files"
    [ -d "$SCRIPT_DIR/nfc/Fun_Files" ] && flipper_cp "$SCRIPT_DIR/nfc/Fun_Files/" "nfc/Fun_Files/"

    # RFID
    log "  RFID files"
    ensure_dir "nfc/RFID"
    [ -d "$SCRIPT_DIR/nfc/RFID" ] && flipper_cp "$SCRIPT_DIR/nfc/RFID/" "nfc/RFID/"

    log "NFC/RFID files installed!"
}

# ----------------------------------------------------------
# Install IR remote files
# ----------------------------------------------------------
install_ir() {
    log "Installing infrared remote files..."

    # AU appliance IR codes
    log "  AU appliance IR codes (Daikin, Mitsubishi, LG, Samsung, etc)"
    ensure_dir "infrared/au_appliances"
    [ -d "$SCRIPT_DIR/infrared/au_appliances" ] && flipper_cp "$SCRIPT_DIR/infrared/au_appliances/" "infrared/au_appliances/"

    # RocketGod IR collection
    log "  RocketGod IR collection (16,630 .ir files)"
    ensure_dir "infrared/rocketgod"
    [ -d "$SCRIPT_DIR/infrared/rocketgod" ] && flipper_cp "$SCRIPT_DIR/infrared/rocketgod/" "infrared/rocketgod/"

    # Flipper-IRDB
    log "  Flipper-IRDB (8,901 .ir files)"
    ensure_dir "infrared"
    [ -d "$SCRIPT_DIR/infrared" ] && find "$SCRIPT_DIR/infrared" -maxdepth 1 -name "*.ir" -exec cp {} "$FLIPPER_MOUNT/infrared/" \; 2>/dev/null || true

    log "Infrared remotes installed!"
}

# ----------------------------------------------------------
# Install BadUSB payloads
# ----------------------------------------------------------
install_badusb() {
    log "Installing BadUSB payloads..."

    # AU-specific payloads
    log "  AU BadUSB payloads (NBN lure, AusPost lure)"
    ensure_dir "badusb/badusb_au"
    [ -d "$SCRIPT_DIR/badusb/badusb_au" ] && flipper_cp "$SCRIPT_DIR/badusb/badusb_au/" "badusb/badusb_au/"

    # UberGuidoZ BadUSB
    log "  UberGuidoZ BadUSB collection (353 payloads)"
    ensure_dir "badusb/UberGuidoZ"
    [ -d "$SCRIPT_DIR/badusb/UberGuidoZ" ] && flipper_cp "$SCRIPT_DIR/badusb/UberGuidoZ/" "badusb/UberGuidoZ/"

    # RocketGod BadUSB
    log "  RocketGod BadUSB collection (3,200 payloads)"
    ensure_dir "badusb/rocketgod"
    [ -d "$SCRIPT_DIR/badusb/rocketgod" ] && flipper_cp "$SCRIPT_DIR/badusb/rocketgod/" "badusb/rocketgod/"

    log "BadUSB payloads installed!"
}

# ----------------------------------------------------------
# Flash Momentum firmware via DFU
# ----------------------------------------------------------
install_firmware() {
    log "Checking for Momentum firmware..."

    if ! command -v dfu-util &>/dev/null; then
        err "dfu-util not found. Install it first:"
        err "  Debian/Ubuntu: sudo apt install dfu-util"
        err "  macOS: brew install dfu-util"
        err "  Arch: sudo pacman -S dfu-util"
        exit 1
    fi

    local fw_file="$SCRIPT_DIR/firmware/momentum.dfu"
    if [ ! -f "$fw_file" ]; then
        log "Downloading latest Momentum firmware..."
        mkdir -p "$SCRIPT_DIR/firmware"
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
    log "After reboot, run this script again to deploy content."
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
    rm -f "$FLIPPER_MOUNT/apps/Sub-GHz/carjacker.fap" 2>/dev/null
    rm -f "$FLIPPER_MOUNT/apps/Sub-GHz/rf_jammer_jammer_app.fap" 2>/dev/null
    rm -f "$FLIPPER_MOUNT/apps/Sub-GHz/subghz_toolkit.fap" 2>/dev/null
    rm -f "$FLIPPER_MOUNT/apps/Sub-GHz/subghz_jammer_detect.fap" 2>/dev/null
    rm -f "$FLIPPER_MOUNT/apps/Sub-GHz/proto_pirate_extra.fap" 2>/dev/null
    rm -f "$FLIPPER_MOUNT/apps/NFC/nfc_magic.fap" 2>/dev/null
    rm -f "$FLIPPER_MOUNT/apps/NFC/nfc_fuzzer.fap" 2>/dev/null
    rm -f "$FLIPPER_MOUNT/apps/NFC/nfc_detector.fap" 2>/dev/null
    rm -f "$FLIPPER_MOUNT/apps/NFC/nfc_sniffer.fap" 2>/dev/null
    rm -f "$FLIPPER_MOUNT/apps/NFC/nfc_relay.fap" 2>/dev/null
    rm -f "$FLIPPER_MOUNT/apps/NFC/mfkey.fap" 2>/dev/null
    rm -f "$FLIPPER_MOUNT/apps/NFC/ulcbrute.fap" 2>/dev/null
    rm -f "$FLIPPER_MOUNT/apps/Infrared/irblaster.fap" 2>/dev/null
    rm -f "$FLIPPER_MOUNT/apps/Bad USB/badusb_pro.fap" 2>/dev/null
    rm -f "$FLIPPER_MOUNT/apps/Bad USB/usb_hid_autofire.fap" 2>/dev/null
    rm -f "$FLIPPER_MOUNT/apps/GPIO/gpio_explorer.fap" 2>/dev/null
    rm -rf "$FLIPPER_MOUNT/apps_data/proto_pirate/" 2>/dev/null

    # Remove signal/payload files
    rm -rf "$FLIPPER_MOUNT/subghz/au_specific/" 2>/dev/null
    rm -rf "$FLIPPER_MOUNT/subghz/car_hacks_au/" 2>/dev/null
    rm -rf "$FLIPPER_MOUNT/subghz/UberGuidoZ/" 2>/dev/null
    rm -rf "$FLIPPER_MOUNT/subghz/rocketgod_sd/" 2>/dev/null
    rm -rf "$FLIPPER_MOUNT/subghz/bruteforce-433/" 2>/dev/null
    rm -rf "$FLIPPER_MOUNT/subghz/CAME-bruteforce/" 2>/dev/null
    rm -rf "$FLIPPER_MOUNT/subghz/euro_automotive/" 2>/dev/null
    rm -rf "$FLIPPER_MOUNT/subghz/gate_bruteforce/" 2>/dev/null
    rm -rf "$FLIPPER_MOUNT/subghz/playlists/" 2>/dev/null
    rm -rf "$FLIPPER_MOUNT/subghz/subplaylist/" 2>/dev/null
    rm -rf "$FLIPPER_MOUNT/nfc/au_dicts/" 2>/dev/null
    rm -rf "$FLIPPER_MOUNT/nfc/au_keys/" 2>/dev/null
    rm -rf "$FLIPPER_MOUNT/nfc/rocketgod/" 2>/dev/null
    rm -rf "$FLIPPER_MOUNT/nfc/Fun_Files/" 2>/dev/null
    rm -rf "$FLIPPER_MOUNT/nfc/RFID/" 2>/dev/null
    rm -rf "$FLIPPER_MOUNT/infrared/au_appliances/" 2>/dev/null
    rm -rf "$FLIPPER_MOUNT/infrared/rocketgod/" 2>/dev/null
    rm -rf "$FLIPPER_MOUNT/badusb/badusb_au/" 2>/dev/null
    rm -rf "$FLIPPER_MOUNT/badusb/UberGuidoZ/" 2>/dev/null
    rm -rf "$FLIPPER_MOUNT/badusb/rocketgod/" 2>/dev/null

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
    echo "  APPS (19 FAP, all unlocked):"
    echo "    SubGHz:  ProtoPirate, AU Brute, RollJam, CarJacker,"
    echo "             RF Jammer, Toolkit, Jammer Detect, Extra"
    echo "    NFC:     Magic, Fuzzer, Detector, Sniffer, Relay,"
    echo "             MFKey, ULCBrute"
    echo "    IR:      Blaster"
    echo "    BadUSB:  Pro, HID Autofire"
    echo "    GPIO:    Explorer"
    echo ""
    echo "  SUBGHZ (37,000+ .sub files):"
    echo "    AU cars/gates  — 676 car fobs, 1,389 gate files"
    echo "    Brute-force    — CAME/NICE 433MHz, SMC5326 330MHz"
    echo "    Mega packs     — UberGuidoZ (11K), RocketGod (22K)"
    echo ""
    echo "  INFRARED (25,600+ .ir files):"
    echo "    AU appliances  — 54 AC codes (15 brands), 94 TV codes"
    echo "    Mega packs     — RocketGod (17K), Flipper-IRDB (9K)"
    echo ""
    echo "  NFC/RFID (1,776 files):"
    echo "    Key dicts      — 4,483 MIFARE Classic keys"
    echo "    iCLASS/Hitag2  — T55xx, DESFire dictionaries"
    echo "    RocketGod      — 2,108 .nfc capture files"
    echo ""
    echo "  BADUSB (1,100+ payloads):"
    echo "    AU lures       — NBN, AusPost"
    echo "    UberGuidoZ     — 353 scripts"
    echo "    RocketGod      — 3,200 scripts"
    echo ""
    if [ -n "$FLIPPER_MOUNT" ]; then
        echo "  DEPLOYED TO: $FLIPPER_MOUNT"
    else
        echo "  FLIPPER: Not connected"
    fi
    echo ""
    echo "  NEXT STEPS:"
    echo "    1. Reboot Flipper after first deployment"
    echo "    2. AU ops: set frequency to 433.92 MHz"
    echo "    3. Try KEYS_TOP_CODES_playlist.txt first"
    echo "    4. RollJam: connect ext CC1101 to GPIO"
    echo "    5. NFC: load au_dicts/mf_classic_dict_user.nfc"
    echo "============================================================"
}

# ----------------------------------------------------------
# Main
# ----------------------------------------------------------
MODE="full"

case "${1:-}" in
    --apps-only)     MODE="apps" ;;
    --subghz-only)   MODE="subghz" ;;
    --nfc-only)      MODE="nfc" ;;
    --ir-only)       MODE="ir" ;;
    --badusb-only)   MODE="badusb" ;;
    --firmware)      MODE="firmware" ;;
    --uninstall)     MODE="uninstall" ;;
    --help|-h)       MODE="help" ;;
    "")              MODE="full" ;;
    *)               err "Unknown option: $1"; MODE="help" ;;
esac

if [ "$MODE" = "help" ]; then
    echo "Usage: $0 [OPTION]"
    echo ""
    echo "Options:"
    echo "  (no option)       Full install: apps + subghz + nfc + ir + badusb"
    echo "  --apps-only        Install FAP/FAL apps only"
    echo "  --subghz-only      Install .sub signal files only"
    echo "  --nfc-only         Install NFC dictionaries only"
    echo "  --ir-only          Install IR remote files only"
    echo "  --badusb-only      Install BadUSB payloads only"
    echo "  --firmware         Flash Momentum firmware via DFU"
    echo "  --uninstall        Remove all deployed files"
    echo "  --help             Show this help"
    echo ""
    echo "Connection methods:"
    echo "  1. USB Mass Storage: Flipper shows as 'Little OrangE' drive"
    echo "  2. Serial CDC: /dev/ttyACM0 (for CLI commands)"
    echo "  3. DFU Mode: Hold DOWN + RESET for firmware flash"
    exit 0
fi

echo ""
info "flipper-zero-unleashed installer (AU-optimized)"
echo ""

if ! detect_flipper; then
    warn "Flipper not detected!"
    echo ""
    echo "Connect your Flipper Zero via USB and ensure it's in one of these modes:"
    echo "  - Storage Mode: Flipper > Settings > System > Storage"
    echo "  - DFU Mode: Hold DOWN button + press RESET"
    echo ""
    if [ "$MODE" = "firmware" ]; then
        info "Continuing with DFU flash..."
    else
        err "Cannot deploy files without Flipper connection."
        exit 1
    fi
fi

case "$MODE" in
    full)
        install_apps
        install_subghz
        install_nfc
        install_ir
        install_badusb
        ;;
    apps)
        install_apps
        ;;
    subghz)
        install_subghz
        ;;
    nfc)
        install_nfc
        ;;
    ir)
        install_ir
        ;;
    badusb)
        install_badusb
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
