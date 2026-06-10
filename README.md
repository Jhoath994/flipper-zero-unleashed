# Flipper Zero Unleashed

All-in-one Flipper Zero deployment package with unlocked apps and SubGHz signal collections. One command to deploy everything from DFU mode.

## What's Included

### Unlocked Apps (FAP)

| App | Features Unlocked |
|-----|------------------|
| **ProtoPirate v3.0** | Emulate, Timing Tuner, Sub Decode, Debug Logs — all feature gates removed, runtime defaults enabled |
| **AU SubGHz Brute** | 8 protocols at 433.92 MHz, state persistence across sessions |
| **AU RollJam** | Rolling code capture + replay (requires external CC1101 on GPIO) |

### SubGHz Signal Collections

| Collection | Files | Source |
|-----------|-------|--------|
| AU Top Fixed Codes | 48 | Highest hit-rate keys for CAME, Nice, Princeton, PT2260, Linear, SMC5326 |
| AU Gate Openers | ~42 | ATA, CAME, Nice FLO, Princeton gates |
| AU Car Brands | ~600 | 17 brands: Toyota, Ford, Holden, Mazda, Hyundai/Kia, Mitsubishi, etc |
| EU Automotive | 132 | VW/Audi/Skoda, PSA, Fiat, Mercedes/BMW, Lamborghini, Mazda |
| Gate Brute-force | 8,752 | SMC5326 330MHz |
| Playlists | 5 | Sub-GHz Playlist plugin format |

### ProtoPirate Protocols (all unlocked)

Subaru, Ford v0-v3, Kia v0-v7, Honda v1/static, Fiat v0/v1, PSA, VAG, Scher-Khan, Star-Line, Chrysler, Porsche Touareg, AUT64, Land Rover, Mazda, Mitsubishi, CAME, Nice, KeeLoq

## Quick Start

### 1. Connect Flipper via USB

Put your Flipper in Storage Mode:
- Flipper > Settings > System > Storage

The SD card will appear as a USB drive (usually `/media/USERNAME/Little OrangE`).

### 2. Run the installer

```bash
chmod +x install.sh
./install.sh            # Full install: apps + subghz signals
```

### 3. For fresh DFU flash

```bash
./install.sh --firmware   # Flash Momentum firmware via DFU
# Then reboot and run:
./install.sh              # Deploy apps + signals
```

## Install Options

```
./install.sh              # Full install (apps + subghz)
./install.sh --apps-only   # Only install FAP/FAL apps
./install.sh --subghz-only # Only install .sub signal files
./install.sh --firmware    # Flash Momentum firmware via DFU
./install.sh --uninstall   # Remove all deployed files
```

## What Was Unlocked in ProtoPirate

The stock ProtoPirate v3.0 ships with several features gated behind compile-time defines and runtime defaults:

| Feature | Stock | Unlocked |
|---------|-------|----------|
| `ENABLE_TIMING_TUNER_SCENE` | Commented out | **Enabled** — Timing analysis UI |
| `ENABLE_SUB_DECODE_SCENE` | Commented out | **Enabled** — RAW file decoder |
| `ENABLE_EMULATE_FEATURE` | Enabled (compile) | **Enabled** (compile + runtime) |
| `emulate_feature_enabled` | `false` (runtime) | **`true`** — Emulate works on first launch |
| `hopping_enabled` | `false` (runtime) | **`true`** — Frequency hopping on by default |
| `REMOVE_LOGS` | Defined | **Commented out** — Full debug logging restored |

Protocol-level disable flags (Scher-Khan emulate disabled) were NOT overridden — these are protocol limitations, not feature locks.

## After Deployment

1. **Reboot your Flipper** — Apps and settings only register after reboot
2. **Launch ProtoPirate** from Apps > Sub-GHz
3. **Emulate is ON by default** — no need to unlock via About screen
4. **For AU operations**: Set frequency to 433.92 MHz
5. **Try top codes first**: Load `KEYS_TOP_CODES_playlist.txt` in Sub-GHz Playlist
6. **RollJam**: Requires external CC1101 soldered to GPIO pins (see wiring guide in README)

## Sources

- ProtoPirate: https://protopirate.net/ProtoPirate/ProtoPirate.git
- AU SubGHz: Jhoath994/flipper-zero-au-subghz
- Automotive Collection: kakuzu-f0/Automotive-Sub-Ghz-Collection
- Gate Brute-force: Hong5489/flipperzero-gate-bruteforce
- Firmware: Next-Flip/Momentum-Firmware

## License

Individual components retain their original licenses. ProtoPirate is GPL-3.0. Signal files are community-contributed.
