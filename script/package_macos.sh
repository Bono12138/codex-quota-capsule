#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DIST_DIR="$ROOT_DIR/dist"
APP_BUNDLE="$DIST_DIR/Quota Capsule.app"
ZIP_PATH="$DIST_DIR/Quota-Capsule-macOS.zip"

"$ROOT_DIR/script/build_and_run.sh" --verify
pkill -x "QuotaCapsuleMac" >/dev/null 2>&1 || true

rm -f "$ZIP_PATH"
(
  cd "$DIST_DIR"
  /usr/bin/ditto -c -k --keepParent "Quota Capsule.app" "$ZIP_PATH"
)

echo "$ZIP_PATH"
