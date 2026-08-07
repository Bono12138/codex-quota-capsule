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
node --import tsx "$ROOT_DIR/scripts/audit-release-artifact.ts" "$APP_BUNDLE"

rm -f "$ZIP_PATH"
(
  cd "$DIST_DIR"
  COPYFILE_DISABLE=1 /usr/bin/ditto -c -k --norsrc --noextattr --keepParent "$BUNDLE_NAME.app" "$ZIP_PATH"
)

ARCHIVE_CHECK_DIR="$(mktemp -d "${TMPDIR:-/tmp}/quota-capsule-archive.XXXXXX")"
trap 'rm -rf "$ARCHIVE_CHECK_DIR"' EXIT
/usr/bin/ditto -x -k "$ZIP_PATH" "$ARCHIVE_CHECK_DIR"
node --import tsx "$ROOT_DIR/scripts/audit-release-artifact.ts" "$ARCHIVE_CHECK_DIR/$BUNDLE_NAME.app"

echo "$ZIP_PATH"
