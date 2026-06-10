# Chameleon-Ultra-Flipper-Zero-key-dictionary

Chameleon Ultra and Flipper Zero can emulate, read, write, and brute-force a wide range of RFID/NFC cards: MIFARE Classic 1K/2K/4K, MIFARE Ultralight, iCLASS, T55xx, Hitag2, NTAG210–218, MIFARE DESFire EV1/EV2 (partial), MIFARE Plus (limited), EM410x, T5577, HID Prox, Indala, PAC/Stanley, Keri, ioProx, Gallagher, Paradox, Presco, Viking, Noralsy, NexWatch, Jablotron, and others.

## What the build does

- Reads `sources/urls.tsv` (category + raw URL), tolerates 404s, logs failures.
- Updates are append-only: existing keys are never removed; if a source disappears or removes keys, they stay in this repository.
- Produces:
  - `all_keys.dic` — raw concatenation of all sources (line duplicates removed).
  - `clean_keys.dic` — dedupe + length sort only (nothing filtered out).
  - `out/<category>_tokens.dic` — per-category tokens (deduped, length-sorted).
  - `out/<category>.dic` — per-category filtered keys by expected length (where known).
  - `out/by_length/*.dic` — splits by length: 12/8/16/32/48 hex, other hex, non-hex.
  - `out/flipper/mf_classic_dict_user.nfc` — ready for Flipper (12 hex per line).
  - `out/report.txt` — stats and failed URLs.
- Works with Bash 3.2+. Uses sha256sum or shasum; falls back to python3 for hashing.

## Run locally

```bash
git clone https://github.com/nbox/Chameleon-Ultra-Flipper-Zero-key-dictionary.git
cd Chameleon-Ultra-Flipper-Zero-key-dictionary
chmod +x run.sh scripts/build_keys.sh
./run.sh
```

## Device notes

- Flipper Zero: MIFARE Classic keys are 12 hex (6 bytes) per line. Use `out/flipper/mf_classic_dict_user.nfc` (place in `SDCARD/flipper/nfc/assets/`).
- Chameleon Ultra: consumes line-by-line lists; for MIFARE Classic use 12-hex keys from `out/mifare_classic.dic` or `clean_keys.dic`.
- Other common lengths: T55xx/Hitag2 — 8 hex; iCLASS — often 16/32 hex; Ultralight C / AES — 32 hex; 3DES 24B — 48 hex. See `out/by_length/`.

## Sources

- `sources/urls.tsv` lists categories and raw URLs. Includes Flipper firmware dicts, mfterm dictionary, sorted Proxmark3 lists, Manu Custom pastebin, and more.
- Line format: `category<TAB>url`. Empty lines and comments (`#`) are ignored. Failed downloads are recorded in `out/report.txt`.

## CI

- `.github/workflows/update-keys.yml` runs on schedule (Mon 03:15 UTC) and via manual dispatch, builds outputs, and opens a PR with `all_keys.dic`, `clean_keys.dic`, `out/*`, and `sources/urls.tsv` when they change. Ensure GitHub Actions are enabled.
- CI note: `flipper.pingywon.com` blocks requests from GitHub Actions and returns HTTP 403, so those sources may fail in CI.

## License

MIT — free to use and modify.

## Build Report

<!-- build-report-start -->
Totals: URLs 36, OK 36, Failed 0

| Category | URLs | OK | Fail | Tokens | Filtered |
| --- | ---: | ---: | ---: | ---: | ---: |
| desfire | 1 | 1 | 0 | 58 | 58 |
| hitag2 | 1 | 1 | 0 | 7 | 5 |
| iclass | 3 | 3 | 0 | 835 | 835 |
| mifare_classic | 27 | 27 | 0 | 5336 | 4479 |
| mifare_plus | 1 | 1 | 0 | 32 | 32 |
| mifare_ultralightc | 1 | 1 | 0 | 7 | 7 |
| misc | 1 | 1 | 0 | 2477 | 2477 |
| t55xx | 1 | 1 | 0 | 125 | 125 |

Failed URLs:
None
<!-- build-report-end -->
