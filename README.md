# Flipper Zero Unleashed

All-in-one Flipper Zero deployment package with unlocked apps, SubGHz signal collections, NFC dictionaries, IR remotes, and BadUSB payloads. Optimized for **Australia (433.92 MHz)**. One command to deploy everything from DFU mode.

## What's Included

### Unlocked Apps (19 FAP + 5 plugins)

| App | Category | Description |
|-----|----------|-------------|
| **ProtoPirate v3.0** | SubGHz | Emulate, Timing Tuner, Sub Decode, Debug Logs — all feature gates removed |
| **AU SubGHz Brute** | SubGHz | 8 protocols at 433.92 MHz, state persistence |
| **AU RollJam** | SubGHz | Rolling code capture + replay (CC1101 on GPIO) |
| **CarJacker** | SubGHz | Protocol analysis + brute force for car key fobs |
| **RF Jammer** | SubGHz | Multi-frequency RF jammer (adjustable freq/mod) |
| **SubGHz Toolkit** | SubGHz | Signal generator and analyzer |
| **SubGHz Jammer Detect** | SubGHz | Detect active jamming on AU bands |
| **ProtoPirate Extra** | SubGHz | Extended protocol decoder |
| **NFC Magic** | NFC | Magic card write/clone tool |
| **NFC Fuzzer** | NFC | NFC protocol fuzzer |
| **NFC Detector** | NFC/RFID | NFC & RFID field detector |
| **NFC Sniffer** | NFC | NFC traffic sniffer |
| **NFC Relay** | NFC | NFC relay attack tool |
| **MFKey + plugin** | NFC | MIFARE Classic key recovery (mfkey32) |
| **ULCBrute** | NFC | MIFARE Ultralight C brute forcer |
| **IR Blaster** | IR | IR blaster/spammer |
| **BadUSB Pro** | BadUSB | Enhanced BadUSB with script engine |
| **USB HID Autofire** | BadUSB | USB HID autofire tool |
| **GPIO Explorer** | GPIO | GPIO pin explorer/hardware hack tool |

### ProtoPirate Plugins (.fal)

| Plugin | Description |
|--------|-------------|
| protopirate_am_plugin | Amplitude modulation plugin |
| protopirate_emulate_plugin | Enhanced emulate mode |
| protopirate_fm_plugin | Frequency modulation plugin |
| protopirate_psa_bf_plugin | PSA brute force plugin |
| mfkey_init_plugin | MFKey initialization hook |

### SubGHz Signal Collections (37,000+ .sub files)

| Collection | Files | AU-Relevant | Source |
|-----------|-------|-------------|--------|
| RocketGod SD Collection | 21,948 | Mixed | RocketGod-git/Flipper_Zero |
| UberGuidoZ Mega Pack | 11,290 | Mixed | UberGuidoZ/Flipper |
| AU Car Fobs | 676 | YES | Jhoath994/flipper-zero-au-subghz |
| AU Gate/Garage Openers | 1,389 | YES | CAME, NICE, ATA, Centurion, B&D |
| AU Jamming Files | 10 | YES | 433.22/433.92/434.39 MHz |
| CAME/NICE 433 Brute | 321 | YES | tobiabocchi/flipperzero-bruteforce |
| CAME 433 Gate Brute | 59 | YES | BitcoinRaven/CAMEbruteforcer |
| Gate Brute-force (SMC5326) | 8,752 | No (300MHz) | Hong5489/flipperzero-gate-bruteforce |
| EU Automotive | 132 | No | kakuzu-f0/Automotive-Sub-Ghz-Collection |
| AU Playlists | 21 | YES | Organized brute-force playlists |

### Infrared Collections (25,600+ .ir files)

| Collection | Files | AU-Relevant | Source |
|-----------|-------|-------------|--------|
| RocketGod IR | 16,630 | Mixed | RocketGod-git/Flipper_Zero |
| Flipper-IRDB | 8,901 | Mixed | Lucaslhm/Flipper-IRDB |
| AU Appliances (ACs) | 54 | YES | Daikin, Mitsubishi, LG, Fujitsu, etc |
| AU TVs | 94 | YES | Samsung, LG AU models |

### NFC/RFID Collections (1,776 files)

| Collection | Description | Source |
|-----------|-------------|--------|
| MIFARE Classic Dict | 4,483 keys | Chameleon-Ultra dictionary |
| AU Key Dictionaries | MIFARE, iCLASS, DESFire, Hitag2, T55xx | Multi-source |
| RocketGod NFC | 2,108 .nfc files | RocketGod-git/Flipper_Zero |
| AU Format Docs | Attack workflows, common AU formats | Custom |

### BadUSB Payloads (1,100+ scripts)

| Collection | Files | Source |
|-----------|-------|--------|
| RocketGod BadUSB | 3,200 | RocketGod-git/Flipper_Zero |
| UberGuidoZ BadUSB | 353 | UberGuidoZ/Flipper |
| AU-Specific Payloads | 2 | NBN lure, AusPost parcel lure |

### WiFi Resources

| Collection | Description |
|-----------|-------------|
| AU SSID List | Common AU WiFi network names |
| Evil Portal HTML | Compressed portal templates |

## Quick Start

### 1. Connect Flipper via USB

Put your Flipper in Storage Mode:
- Flipper > Settings > System > Storage

The SD card appears as a USB drive (usually `/media/USERNAME/Little OrangE`).

### 2. Run the installer

```bash
chmod +x install.sh
./install.sh            # Full install: apps + subghz + ir + nfc + badusb
```

### 3. For fresh DFU flash

```bash
./install.sh --firmware   # Flash Momentum firmware via DFU
# Then reboot and run:
./install.sh              # Deploy everything
```

## Install Options

```
./install.sh              # Full install (apps + subghz + ir + nfc + badusb)
./install.sh --apps-only   # Only install FAP/FAL apps
./install.sh --subghz-only # Only install .sub signal files
./install.sh --firmware    # Flash Momentum firmware via DFU
./install.sh --uninstall   # Remove all deployed files
```

## What Was Unlocked in ProtoPirate

| Feature | Stock | Unlocked |
|---------|-------|----------|
| `ENABLE_TIMING_TUNER_SCENE` | Commented out | **Enabled** — Timing analysis UI |
| `ENABLE_SUB_DECODE_SCENE` | Commented out | **Enabled** — RAW file decoder |
| `emulate_feature_enabled` | `false` (runtime) | **`true`** — Emulate on first launch |
| `hopping_enabled` | `false` (runtime) | **`true`** — Frequency hopping default |
| `REMOVE_LOGS` | Defined | **Commented out** — Full debug logging |

## AU-Specific Setup

1. **Frequency**: Set to **433.92 MHz** (AU legal ISM band)
2. **Try AU playlists first**: `KEYS_TOP_CODES_playlist.txt` in Sub-GHz Playlist
3. **AU AC codes**: Check `infrared/au_appliances/` for Daikin, Mitsubishi, etc
4. **NFC keys**: Load `nfc/au_dicts/mf_classic_dict_user.nfc` (4,483 keys)
5. **Gate protocols**: CAME 12bit, NICE FLO, ATA Princeton at 433 MHz

## After Deployment

1. **Reboot your Flipper** — Apps register after reboot
2. **Launch ProtoPirate** from Apps > Sub-GHz
3. **Emulate is ON by default** — no unlock needed
4. **For AU operations**: Set frequency to 433.92 MHz
5. **RollJam**: Requires external CC1101 on GPIO pins

## Sources

- ProtoPirate: https://protopirate.net/ProtoPirate/ProtoPirate.git
- RocketGod Apps: RocketGod-git (betaskynet.com)
- AU SubGHz: Jhoath994/flipper-zero-au-subghz
- UberGuidoZ: UberGuidoZ/Flipper
- Flipper-IRDB: Lucaslhm/Flipper-IRDB
- NFC Dicts: nbox/Chameleon-Ultra-Flipper-Zero-key-dictionary
- Gate Brute-force: Hong5489/flipperzero-gate-bruteforce
- Brute-force: tobiabocchi/flipperzero-bruteforce
- Firmware: Next-Flip/Momentum-Firmware

## License

Individual components retain their original licenses. ProtoPirate is GPL-3.0. Signal files are community-contributed.
