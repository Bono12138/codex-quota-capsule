#!/usr/bin/env bash
set -euo pipefail

MODE="${1:-run}"
PRODUCT_NAME="QuotaCapsuleMac"
CHANNEL="${QUOTA_CAPSULE_CHANNEL:-internal-test}"
MIN_SYSTEM_VERSION="14.0"

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

case "$CHANNEL" in
  development|dev)
    CHANNEL="development"
    BUNDLE_NAME="${QUOTA_CAPSULE_BUNDLE_NAME:-Quota Capsule Dev Local}"
    BUNDLE_ID="${QUOTA_CAPSULE_BUNDLE_ID:-com.bono.quota-capsule.dev}"
    EXECUTABLE_NAME="QuotaCapsuleDevLocal"
    GITHUB_ISSUES_URL="${QUOTA_CAPSULE_DEV_GITHUB_ISSUES_URL:-}"
    ;;
  internal-test|internal_test|beta|public)
    CHANNEL="internal-test"
    BUNDLE_NAME="${QUOTA_CAPSULE_BUNDLE_NAME:-Quota Capsule Beta}"
    BUNDLE_ID="${QUOTA_CAPSULE_BUNDLE_ID:-com.bono.quota-capsule.beta}"
    EXECUTABLE_NAME="QuotaCapsuleBeta"
    GITHUB_ISSUES_URL="${QUOTA_CAPSULE_PUBLIC_GITHUB_ISSUES_URL:-https://github.com/Bono12138/codex-quota-capsule/issues}"
    ;;
  *)
    echo "unknown QUOTA_CAPSULE_CHANNEL: $CHANNEL" >&2
    echo "supported: development, internal-test" >&2
    exit 2
    ;;
esac

DIST_DIR="$ROOT_DIR/dist/$CHANNEL"
APP_BUNDLE="$DIST_DIR/$BUNDLE_NAME.app"
APP_CONTENTS="$APP_BUNDLE/Contents"
APP_MACOS="$APP_CONTENTS/MacOS"
APP_RESOURCES="$APP_CONTENTS/Resources"
APP_BINARY="$APP_MACOS/$EXECUTABLE_NAME"
INFO_PLIST="$APP_CONTENTS/Info.plist"
APP_RESOURCE_SOURCE="$ROOT_DIR/Sources/QuotaCapsuleMac/Resources"

pkill -x "$EXECUTABLE_NAME" >/dev/null 2>&1 || true

if [[ "$CHANNEL" == "development" && -z "$GITHUB_ISSUES_URL" ]]; then
  echo "warning: development build has no QUOTA_CAPSULE_DEV_GITHUB_ISSUES_URL; GitHub Issues button will be hidden." >&2
fi

swift build -c release --product "$PRODUCT_NAME"
BUILD_DIR="$(swift build -c release --show-bin-path)"
BUILD_BINARY="$BUILD_DIR/$PRODUCT_NAME"

rm -rf "$APP_BUNDLE"
mkdir -p "$APP_MACOS" "$APP_RESOURCES"
cp "$BUILD_BINARY" "$APP_BINARY"
chmod +x "$APP_BINARY"
if [[ -d "$APP_RESOURCE_SOURCE" ]]; then
  cp -R "$APP_RESOURCE_SOURCE/." "$APP_RESOURCES/"
fi
"$ROOT_DIR/script/make_app_icon.sh" "$APP_RESOURCE_SOURCE/app-icon.svg" "$APP_RESOURCES/QuotaCapsuleAppIcon.icns" >/dev/null

cat >"$INFO_PLIST" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleExecutable</key>
  <string>$EXECUTABLE_NAME</string>
  <key>CFBundleIdentifier</key>
  <string>$BUNDLE_ID</string>
  <key>CFBundleName</key>
  <string>$BUNDLE_NAME</string>
  <key>CFBundleDisplayName</key>
  <string>$BUNDLE_NAME</string>
  <key>CFBundleIconFile</key>
  <string>QuotaCapsuleAppIcon</string>
  <key>CFBundlePackageType</key>
  <string>APPL</string>
  <key>CFBundleShortVersionString</key>
  <string>0.1.0</string>
  <key>CFBundleVersion</key>
  <string>1</string>
  <key>QuotaCapsuleChannel</key>
  <string>$CHANNEL</string>
  <key>QuotaCapsuleGitHubIssuesURL</key>
  <string>$GITHUB_ISSUES_URL</string>
  <key>LSMinimumSystemVersion</key>
  <string>$MIN_SYSTEM_VERSION</string>
  <key>LSUIElement</key>
  <true/>
  <key>NSPrincipalClass</key>
  <string>NSApplication</string>
  <key>NSHumanReadableCopyright</key>
  <string>MIT</string>
</dict>
</plist>
PLIST

/usr/bin/codesign --force --deep --sign - "$APP_BUNDLE" >/dev/null

open_app() {
  /usr/bin/open -n "$APP_BUNDLE"
}

case "$MODE" in
  run)
    open_app
    ;;
  --debug|debug)
    lldb -- "$APP_BINARY"
    ;;
  --logs|logs)
    open_app
    /usr/bin/log stream --info --style compact --predicate "process == \"$EXECUTABLE_NAME\""
    ;;
  --telemetry|telemetry)
    open_app
    /usr/bin/log stream --info --style compact --predicate "subsystem == \"$BUNDLE_ID\""
    ;;
  --verify|verify)
    open_app
    sleep 2
    pgrep -x "$EXECUTABLE_NAME" >/dev/null
    ;;
  *)
    echo "usage: $0 [run|--debug|--logs|--telemetry|--verify]" >&2
    exit 2
    ;;
esac
