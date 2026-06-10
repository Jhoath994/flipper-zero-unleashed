#!/usr/bin/env bash
set -euo pipefail

# ------------------------------------------------------------
# build_keys.sh
# 1) Download all sources listed in sources/urls.tsv
# 2) Create all_keys.dic (raw concatenation, de-duped by line)
# 3) Create clean_keys.dic (TOKENS, only de-dupe + length sort)
# 4) Create out/ categorized dictionaries:
#      - out/<category>_tokens.dic (per category, dedup+len sort, NO validation)
#      - out/<category>.dic        (per category, "useful" filtered if known)
#      - out/flipper/mf_classic_dict_user.nfc (generated from out/mifare_classic.dic)
#      - out/by_length/*.dic       (handy splits: hex12, hex8, hex16, hex32, hex48, nonhex, otherhex)
# 5) Writes out/report.txt with stats + failed URLs
# ------------------------------------------------------------

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

export LC_ALL=C LANG=C  # keep locale ASCII-safe to avoid multibyte conversion errors from raw sources

RAW_OUTPUT="all_keys.dic"
CLEAN_OUTPUT="clean_keys.dic"

URLS_FILE="sources/urls.tsv"
OUTDIR="out"

TMPDIR="$(mktemp -d)"
trap 'rm -rf "$TMPDIR"' EXIT

DOWNLOAD_DIR="$TMPDIR/downloads"
TOKENS_DIR="$TMPDIR/tokens"
RAW_NEW="$TMPDIR/all_keys.new"
RAW_MERGED="$TMPDIR/all_keys.merged"
CLEAN_MERGED="$TMPDIR/clean_keys.merged"
mkdir -p "$DOWNLOAD_DIR" "$TOKENS_DIR" "$OUTDIR" "$OUTDIR/flipper" "$OUTDIR/by_length"
CATEGORIES_FILE="$TMPDIR/categories.list"
STATUS_FILE="$TMPDIR/status.tsv"
: > "$CATEGORIES_FILE"
: > "$STATUS_FILE"

# -------- Helpers --------

log() { printf "%s\n" "$*" >&2; }

# Tokenizer:
# - strips inline comments (#, //, --) in a safer way (won't chop "http://", only "//" preceded by whitespace or at start)
# - replaces commas/semicolons with spaces
# - splits by whitespace into tokens
# - trims surrounding punctuation
# - removes 0x prefix for hex tokens
# - uppercases hex-only tokens
tokenize_stream() {
  awk '
    function rtrim_punct(s) { sub(/[^[:alnum:]]+$/, "", s); return s }
    function ltrim_punct(s) { sub(/^[^[:alnum:]]+/, "", s); return s }

    function strip_comments(line) {
      # Remove shell-style comments
      sub(/[[:space:]]*#.*/, "", line)

      # Remove C++-style comments but try not to break URLs:
      #  - line starts with //
      #  - or whitespace before //
      if (line ~ /^\/\//) { line=""; return line }
      sub(/[[:space:]]+\/\/.*/, "", line)

      # Remove SQL-style comments:
      if (line ~ /^--/) { line=""; return line }
      sub(/[[:space:]]+--.*/, "", line)

      return line
    }

    {
      gsub(/\r/, "", $0)
      line = $0
      line = strip_comments(line)

      # turn separators into whitespace
      gsub(/[,;]/, " ", line)
      gsub(/[[:space:]]+/, " ", line)
      gsub(/^[[:space:]]+|[[:space:]]+$/, "", line)

      if (line == "") next

      n = split(line, a, " ")
      for (i=1; i<=n; i++) {
        tok = a[i]
        tok = ltrim_punct(tok)
        tok = rtrim_punct(tok)
        if (tok == "") continue

        # drop 0x prefix
        if (tok ~ /^0[xX][0-9A-Fa-f]+$/) tok = substr(tok, 3)

        # normalize hex case
        if (tok ~ /^[0-9A-Fa-f]+$/) tok = toupper(tok)

        # avoid absurdly long tokens
        if (length(tok) > 256) continue

        print tok
      }
    }
  '
}

# Deduplicate and sort by length (shortest -> longest), then lexicographically for stability
dedup_len_sort() {
  awk 'NF && !seen[$0]++' \
  | awk '{ print length($0) "\t" $0 }' \
  | LC_ALL=C sort -n -k1,1 -k2,2 \
  | cut -f2-
}

# Deduplicate lines while preserving first occurrence order
dedup_lines_stable() {
  awk '!seen[$0]++'
}

short_hash() {
  local data="$1"
  if command -v sha256sum >/dev/null 2>&1; then
    printf "%s" "$data" | sha256sum | cut -c1-10
  elif command -v shasum >/dev/null 2>&1; then
    printf "%s" "$data" | shasum -a 256 | cut -c1-10
  else
    SHORT_HASH_DATA="$data" python3 - <<'PY'
import hashlib, os
print(hashlib.sha256(os.environ["SHORT_HASH_DATA"].encode()).hexdigest()[:10])
PY
  fi
}

safe_filename() {
  # stable-ish filename from URL (basename can collide, so append a short hash)
  local url="$1"
  local base
  base="$(basename "${url%%\?*}")"
  [[ -n "$base" ]] || base="download"
  printf "%s__%s" "$base" "$(short_hash "$url")"
}

merge_append_only_lines() {
  local base="$1"
  local incoming="$2"
  local out="$3"

  if [[ -f "$base" ]]; then
    cat "$base" > "$out"
    awk 'NR==FNR{seen[$0]++; next} !seen[$0] {print}' "$base" "$incoming" >> "$out"
  else
    cat "$incoming" > "$out"
  fi
}

merge_dedup_tokens() {
  local base="$1"
  local incoming="$2"
  local out="$3"

  if [[ -f "$base" ]]; then
    cat "$base" "$incoming" | dedup_len_sort > "$out"
  else
    dedup_len_sort < "$incoming" > "$out"
  fi
}

# Filter "useful" per category (keeps only matching hex lengths where it makes sense).
# NOTE: we do NOT delete anything from clean_keys.dic; this is only for out/<category>.dic convenience.
filter_for_category() {
  local category="$1"
  awk -v cat="$category" '
    function ishex(s){ return (s ~ /^[0-9A-F]+$/) }

    {
      s=$0
      if (cat=="mifare_classic") {
        if (ishex(s) && length(s)==12) print s
      } else if (cat=="t55xx" || cat=="hitag2") {
        if (ishex(s) && length(s)==8) print s
      } else if (cat=="iclass") {
        if (ishex(s) && (length(s)==16 || length(s)==32)) print s
      } else if (cat=="mifare_ultralightc") {
        if (ishex(s) && length(s)==32) print s
      } else if (cat=="mifare_plus") {
        if (ishex(s) && length(s)==32) print s
      } else if (cat=="desfire") {
        if (ishex(s) && (length(s)==16 || length(s)==32 || length(s)==48)) print s
      } else {
        # unknown category: keep all tokens as-is
        print s
      }
    }
  '
}

update_readme_report() {
  local readme="$ROOT_DIR/README.md"
  python3 - "$readme" "$REPORT_FILE" <<'PY'
import pathlib, re, sys

readme = pathlib.Path(sys.argv[1])
report_path = pathlib.Path(sys.argv[2])
lines = report_path.read_text().splitlines()

total = ok = failed = None
rows = []
failed_urls = []

cat_re = re.compile(r"-\s+(\S+)\s+urls=(\d+)\s+ok=(\d+)\s+fail=(\d+)\s+tokens=(\d+)\s+filtered=(\d+)")

it = iter(lines)
for line in it:
    if line.startswith("Total URLs:"):
        total = line.split(":")[1].strip()
    elif line.startswith("OK URLs:"):
        ok = line.split(":")[1].strip()
    elif line.startswith("Failed URLs:"):
        failed = line.split(":")[1].strip()

for line in lines:
    m = cat_re.search(line)
    if m:
        rows.append({
            "cat": m.group(1),
            "urls": m.group(2),
            "ok": m.group(3),
            "fail": m.group(4),
            "tokens": m.group(5),
            "filtered": m.group(6),
        })

if "Failed URLs:" in lines:
    start = lines.index("Failed URLs:") + 2  # skip separator line
    for l in lines[start:]:
        if not l.strip():
            continue
        parts = [p.strip() for p in l.split("\t")]
        if len(parts) >= 2:
            cat = parts[0]
            url = parts[1]
            status = parts[2] if len(parts) >= 3 and parts[2] else "INVALID/UNAVAILABLE"
            failed_urls.append((cat, url, status))
        else:
            failed_urls.append(("", parts[0], "INVALID/UNAVAILABLE"))

table_header = "| Category | URLs | OK | Fail | Tokens | Filtered |"
table_sep = "| --- | ---: | ---: | ---: | ---: | ---: |"
table_rows = [table_header, table_sep]
for r in sorted(rows, key=lambda x: x["cat"]):
    table_rows.append(f"| {r['cat']} | {r['urls']} | {r['ok']} | {r['fail']} | {r['tokens']} | {r['filtered']} |")

def status_label(status):
    if status and status != "INVALID/UNAVAILABLE":
        return f"INVALID/UNAVAILABLE ({status})"
    return "INVALID/UNAVAILABLE"

failed_section = "None"
if failed_urls:
    failed_lines = [
        f"- {cat}: <{url}> - {status_label(status)}" if cat else f"- <{url}> - {status_label(status)}"
        for cat, url, status in failed_urls
    ]
    failed_section = "\n".join(failed_lines)

totals_line = "Totals: URLs {total}, OK {ok}, Failed {failed}".format(
    total=total or "?", ok=ok or "?", failed=failed or "?"
)

block = "\n".join([
    "## Build Report",
    "",
    "<!-- build-report-start -->",
    totals_line,
    "",
    "\n".join(table_rows),
    "",
    "Failed URLs:",
    failed_section,
    "<!-- build-report-end -->",
])

text = readme.read_text()
pattern = re.compile(r"## Build Report\s*<!-- build-report-start -->.*?<!-- build-report-end -->", re.S)

if pattern.search(text):
    text = pattern.sub(block, text)
else:
    if not text.endswith("\n"):
        text += "\n"
    text += "\n" + block + "\n"

readme.write_text(text)
PY
}

# -------- Main --------

if [[ ! -f "$URLS_FILE" ]]; then
  log "ERROR: missing $URLS_FILE"
  exit 1
fi

log "=== Download & merge sources from: $URLS_FILE ==="
: > "$RAW_NEW"

FAILED_LIST="$TMPDIR/failed.tsv"
: > "$FAILED_LIST"

TOTAL_URLS=0
OK_URLS=0
FAIL_URLS=0

GLOBAL_TOKENS_FILE="$TOKENS_DIR/all.tokens"
: > "$GLOBAL_TOKENS_FILE"

while IFS=$'\t' read -r category url; do
  # skip comments/empty
  [[ -z "${category:-}" ]] && continue
  [[ "$category" =~ ^[[:space:]]*# ]] && continue
  [[ -z "${url:-}" ]] && continue

  # trim
  category="${category#"${category%%[![:space:]]*}"}"
  category="${category%"${category##*[![:space:]]}"}"
  url="${url#"${url%%[![:space:]]*}"}"
  url="${url%"${url##*[![:space:]]}"}"

  [[ -z "$category" || -z "$url" ]] && continue

  ((TOTAL_URLS++)) || true

  tokens_file="$TOKENS_DIR/${category}.tokens"
  if [[ ! -f "$tokens_file" ]]; then
    : > "$tokens_file"
    echo "$category" >> "$CATEGORIES_FILE"
  fi

  local_file="$DOWNLOAD_DIR/$(safe_filename "$url")"

  log "  • [$category] $url"

  if curl -fsSL --connect-timeout 15 --max-time 60 "$url" -o "$local_file"; then
    ((OK_URLS++)) || true
    echo -e "${category}\tok" >> "$STATUS_FILE"

    {
      printf "\n# --- SOURCE: %s\t%s ---\n" "$category" "$url"
      cat "$local_file"
      printf "\n"
    } >> "$RAW_NEW"

    # tokenize into per-category and global tokens
    tokenize_stream < "$local_file" >> "$tokens_file"
    tokenize_stream < "$local_file" >> "$GLOBAL_TOKENS_FILE"
  else
    ((FAIL_URLS++)) || true
    echo -e "${category}\tfail" >> "$STATUS_FILE"
    printf "%s\t%s\n" "$category" "$url" >> "$FAILED_LIST"
    log "    ! FAILED: $url"
    # continue on failure
  fi

done < "$URLS_FILE"

log "=== Merge all_keys.dic (append-only) ==="
merge_append_only_lines "$RAW_OUTPUT" "$RAW_NEW" "$RAW_MERGED"
dedup_lines_stable < "$RAW_MERGED" > "$RAW_OUTPUT"

log "=== Build clean_keys.dic (append-only) ==="
# clean_keys.dic contains ALL TOKENS (hex + non-hex), only duplicates removed
merge_dedup_tokens "$CLEAN_OUTPUT" "$GLOBAL_TOKENS_FILE" "$CLEAN_MERGED"
mv "$CLEAN_MERGED" "$CLEAN_OUTPUT"

log "=== Build out/ per-category ==="
REPORT_FILE="$OUTDIR/report.txt"
: > "$REPORT_FILE"

{
  echo "Build report"
  echo "============"
  echo "Total URLs:   $TOTAL_URLS"
  echo "OK URLs:      $OK_URLS"
  echo "Failed URLs:  $FAIL_URLS"
  echo
  echo "Per-category:"
} >> "$REPORT_FILE"

for category in $(sort -u "$CATEGORIES_FILE"); do
  tokens_file="$TOKENS_DIR/${category}.tokens"
  out_tokens="$OUTDIR/${category}_tokens.dic"
  out_filtered="$OUTDIR/${category}.dic"

  tmp_tokens_new="$TMPDIR/${category}.tokens.new"
  tmp_tokens_merged="$TMPDIR/${category}.tokens.merged"
  tmp_filtered_new="$TMPDIR/${category}.filtered.new"
  tmp_filtered_merged="$TMPDIR/${category}.filtered.merged"

  # tokens: dedup + length sort, then merge with existing (append-only)
  dedup_len_sort < "$tokens_file" > "$tmp_tokens_new"
  merge_dedup_tokens "$out_tokens" "$tmp_tokens_new" "$tmp_tokens_merged"
  mv "$tmp_tokens_merged" "$out_tokens"

  # filtered: only if we know sensible filter; unknown categories will keep all
  filter_for_category "$category" < "$out_tokens" | dedup_len_sort > "$tmp_filtered_new" || true
  merge_dedup_tokens "$out_filtered" "$tmp_filtered_new" "$tmp_filtered_merged"
  mv "$tmp_filtered_merged" "$out_filtered"

  tok_count="$(wc -l < "$out_tokens" | tr -d ' ')"
  fil_count="$(wc -l < "$out_filtered" | tr -d ' ')"

  urlc="$(awk -v c="$category" '$1==c {n++} END{print n+0}' "$STATUS_FILE")"
  okc="$(awk -v c="$category" '$1==c && $2=="ok" {n++} END{print n+0}' "$STATUS_FILE")"
  failc="$(awk -v c="$category" '$1==c && $2=="fail" {n++} END{print n+0}' "$STATUS_FILE")"

  {
    printf "  - %-18s urls=%-3s ok=%-3s fail=%-3s tokens=%-6s filtered=%-6s\n" \
      "$category" "$urlc" "$okc" "$failc" "$tok_count" "$fil_count"
  } >> "$REPORT_FILE"
done

log "=== Build out/by_length splits (from clean_keys.dic) ==="
HEX12="$OUTDIR/by_length/hex_len_12.dic"
HEX8="$OUTDIR/by_length/hex_len_8.dic"
HEX16="$OUTDIR/by_length/hex_len_16.dic"
HEX32="$OUTDIR/by_length/hex_len_32.dic"
HEX48="$OUTDIR/by_length/hex_len_48.dic"
OTHERHEX="$OUTDIR/by_length/hex_other.dic"
NONHEX="$OUTDIR/by_length/non_hex.dic"

: > "$HEX12"; : > "$HEX8"; : > "$HEX16"; : > "$HEX32"; : > "$HEX48"; : > "$OTHERHEX"; : > "$NONHEX"

awk '
  function ishex(s){ return (s ~ /^[0-9A-F]+$/) }
  {
    s=$0
    if (ishex(s)) {
      if (length(s)==12) print s >> "'"$HEX12"'"
      else if (length(s)==8) print s >> "'"$HEX8"'"
      else if (length(s)==16) print s >> "'"$HEX16"'"
      else if (length(s)==32) print s >> "'"$HEX32"'"
      else if (length(s)==48) print s >> "'"$HEX48"'"
      else print s >> "'"$OTHERHEX"'"
    } else {
      print s >> "'"$NONHEX"'"
    }
  }
' "$CLEAN_OUTPUT"

# ensure dedup/sorted inside each length file (clean_keys already deduped, but this keeps them stable)
for f in "$HEX12" "$HEX8" "$HEX16" "$HEX32" "$HEX48" "$OTHERHEX" "$NONHEX"; do
  tmp="$TMPDIR/$(basename "$f").tmp"
  dedup_len_sort < "$f" > "$tmp"
  mv "$tmp" "$f"
done

log "=== Generate Flipper-friendly out/flipper/mf_classic_dict_user.nfc ==="
FLIPPER_USER_DICT="$OUTDIR/flipper/mf_classic_dict_user.nfc"
{
  echo "# MF Classic user dictionary (generated)"
  echo "# One key per line (12 HEX chars)."
  echo "# Source: clean build from sources/urls.tsv"
  echo
  # Prefer the filtered mifare_classic list if present; otherwise fall back to hex_len_12
  if [[ -s "$OUTDIR/mifare_classic.dic" ]]; then
    cat "$OUTDIR/mifare_classic.dic"
  else
    cat "$HEX12"
  fi
} > "$FLIPPER_USER_DICT"

log "=== Failed URLs (if any) appended to report ==="
if [[ -s "$FAILED_LIST" ]]; then
  {
    echo
    echo "Failed URLs:"
    echo "-----------"
    while IFS=$'\t' read -r failed_category failed_url; do
      [[ -z "${failed_category:-}" && -z "${failed_url:-}" ]] && continue
      printf "%s\t%s\tINVALID/UNAVAILABLE\n" "$failed_category" "$failed_url"
    done < "$FAILED_LIST"
  } >> "$REPORT_FILE"
fi

log "=== Update README build report ==="
update_readme_report

log "=== Done ==="
log "Raw:        $RAW_OUTPUT"
log "Clean:      $CLEAN_OUTPUT"
log "Out dir:    $OUTDIR/"
log "Report:     $REPORT_FILE"
