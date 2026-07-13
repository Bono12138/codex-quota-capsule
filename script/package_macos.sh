#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BUNDLE_NAME="${QUOTA_CAPSULE_BUNDLE_NAME:-Quota Capsule Beta}"
EXECUTABLE_NAME="QuotaCapsuleBeta"
ZIP_NAME="Quota-Capsule-Beta-macOS.zip"

DIST_DIR="$ROOT_DIR/dist/beta"
APP_BUNDLE="$DIST_DIR/$BUNDLE_NAME.app"
ZIP_PATH="$DIST_DIR/$ZIP_NAME"

"$ROOT_DIR/script/build_and_run.sh" --verify
pkill -x "$EXECUTABLE_NAME" >/dev/null 2>&1 || true

rm -f "$ZIP_PATH"
(
  cd "$DIST_DIR"
  COPYFILE_DISABLE=1 /usr/bin/ditto -c -k --norsrc --noextattr --keepParent "$BUNDLE_NAME.app" "$ZIP_PATH"
)

echo "$ZIP_PATH"
