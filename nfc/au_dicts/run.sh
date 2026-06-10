#!/usr/bin/env bash
set -euo pipefail

# Wrapper to run the main builder script
ROOT_DIR="$(cd "$(dirname "$0")" && pwd)"
exec "$ROOT_DIR/scripts/build_keys.sh" "$@"
