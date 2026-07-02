#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CHANNEL="${QUOTA_CAPSULE_CHANNEL:-internal-test}"

case "$CHANNEL" in
  development|dev)
    CHANNEL="development"
    BUNDLE_NAME="${QUOTA_CAPSULE_BUNDLE_NAME:-Quota Capsule Dev Local}"
    EXECUTABLE_NAME="QuotaCapsuleDevLocal"
    ZIP_NAME="Quota-Capsule-Dev-Local-macOS.zip"
    ;;
  internal-test|internal_test|beta|public)
    CHANNEL="internal-test"
    BUNDLE_NAME="${QUOTA_CAPSULE_BUNDLE_NAME:-Quota Capsule Beta}"
    EXECUTABLE_NAME="QuotaCapsuleBeta"
    ZIP_NAME="Quota-Capsule-Beta-macOS.zip"
    ;;
  *)
    echo "unknown QUOTA_CAPSULE_CHANNEL: $CHANNEL" >&2
    echo "supported: development, internal-test" >&2
    exit 2
    ;;
esac

DIST_DIR="$ROOT_DIR/dist/$CHANNEL"
APP_BUNDLE="$DIST_DIR/$BUNDLE_NAME.app"
ZIP_PATH="$DIST_DIR/$ZIP_NAME"

QUOTA_CAPSULE_CHANNEL="$CHANNEL" "$ROOT_DIR/script/build_and_run.sh" --verify
pkill -x "$EXECUTABLE_NAME" >/dev/null 2>&1 || true

rm -f "$ZIP_PATH"
(
  cd "$DIST_DIR"
  COPYFILE_DISABLE=1 /usr/bin/ditto -c -k --norsrc --noextattr --keepParent "$BUNDLE_NAME.app" "$ZIP_PATH"
)

echo "$ZIP_PATH"
