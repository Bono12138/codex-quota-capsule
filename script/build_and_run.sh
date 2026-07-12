#!/usr/bin/env bash
set -euo pipefail

MODE="${1:-run}"
PRODUCT_NAME="QuotaCapsuleMac"
CHANNEL="${QUOTA_CAPSULE_CHANNEL:-internal-test}"
MIN_SYSTEM_VERSION="14.0"
APP_VERSION="${QUOTA_CAPSULE_VERSION:-0.1.2}"
APP_BUILD="${QUOTA_CAPSULE_BUILD:-$(date -u +%Y%m%d%H%M)}"

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
GIT_COMMIT="$(git -C "$ROOT_DIR" rev-parse --short=12 HEAD 2>/dev/null || echo unknown)"
BUILD_DATE="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
UNTRACKED_BUILD_INPUTS="$(git -C "$ROOT_DIR" ls-files --others --exclude-standard -- Package.swift Sources)"
if [[ -n "$UNTRACKED_BUILD_INPUTS" ]]; then
  echo "refusing an unverifiable build with untracked Swift inputs:" >&2
  echo "$UNTRACKED_BUILD_INPUTS" >&2
  exit 2
fi
SOURCE_PATCH_SHA="$(git -C "$ROOT_DIR" diff --binary HEAD -- Package.swift Sources | shasum -a 256 | awk '{print $1}')"

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

case "$BUNDLE_NAME" in
  ""|"."|".."|*/*|*$'\n'*|*$'\r'*)
    echo "unsafe bundle name: it must be one path component" >&2
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
  echo "warning: development build has no QUOTA_CAPSULE_DEV_GITHUB_ISSUES_URL; unified feedback will open an email draft." >&2
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

/usr/bin/plutil -create xml1 "$INFO_PLIST"
/usr/bin/plutil -insert CFBundleExecutable -string "$EXECUTABLE_NAME" "$INFO_PLIST"
/usr/bin/plutil -insert CFBundleIdentifier -string "$BUNDLE_ID" "$INFO_PLIST"
/usr/bin/plutil -insert CFBundleName -string "$BUNDLE_NAME" "$INFO_PLIST"
/usr/bin/plutil -insert CFBundleDisplayName -string "$BUNDLE_NAME" "$INFO_PLIST"
/usr/bin/plutil -insert CFBundleIconFile -string "QuotaCapsuleAppIcon" "$INFO_PLIST"
/usr/bin/plutil -insert CFBundlePackageType -string "APPL" "$INFO_PLIST"
/usr/bin/plutil -insert CFBundleShortVersionString -string "$APP_VERSION" "$INFO_PLIST"
/usr/bin/plutil -insert CFBundleVersion -string "$APP_BUILD" "$INFO_PLIST"
/usr/bin/plutil -insert QuotaCapsuleChannel -string "$CHANNEL" "$INFO_PLIST"
/usr/bin/plutil -insert QuotaCapsuleGitHubIssuesURL -string "$GITHUB_ISSUES_URL" "$INFO_PLIST"
/usr/bin/plutil -insert QuotaCapsuleGitCommit -string "$GIT_COMMIT" "$INFO_PLIST"
/usr/bin/plutil -insert QuotaCapsuleSourcePatchSHA256 -string "$SOURCE_PATCH_SHA" "$INFO_PLIST"
/usr/bin/plutil -insert QuotaCapsuleBuildDate -string "$BUILD_DATE" "$INFO_PLIST"
/usr/bin/plutil -insert LSMinimumSystemVersion -string "$MIN_SYSTEM_VERSION" "$INFO_PLIST"
/usr/bin/plutil -insert LSUIElement -bool YES "$INFO_PLIST"
/usr/bin/plutil -insert NSPrincipalClass -string "NSApplication" "$INFO_PLIST"
/usr/bin/plutil -insert NSHumanReadableCopyright -string "MIT" "$INFO_PLIST"

/usr/bin/codesign --force --deep --sign - "$APP_BUNDLE" >/dev/null

open_app() {
  /usr/bin/open -n "$APP_BUNDLE"
}

verify_running_path() {
  local expected_bundle="$1"
  local pid
  pid="$(pgrep -n -x "$EXECUTABLE_NAME")"
  local command
  command="$(ps -p "$pid" -o command=)"
  case "$command" in
    "$expected_bundle/Contents/MacOS/$EXECUTABLE_NAME"*) ;;
    *)
      echo "running process does not come from expected bundle: $command" >&2
      return 1
      ;;
  esac
}

install_app() {
  local target="/Applications/$BUNDLE_NAME.app"
  local temporary="/Applications/.$BUNDLE_NAME.app.installing-$$"
  local backup="/Applications/.$BUNDLE_NAME.app.backup-$$"
  rm -rf "$temporary"
  rm -rf "$backup"
  /usr/bin/ditto "$APP_BUNDLE" "$temporary"
  /usr/bin/codesign --verify --deep --strict "$temporary"
  if [[ -e "$target" ]]; then
    mv "$target" "$backup"
  fi
  if ! mv "$temporary" "$target"; then
    if [[ -e "$backup" ]]; then
      mv "$backup" "$target"
    fi
    return 1
  fi
  if ! /usr/bin/open -n "$target"; then
    rm -rf "$target"
    if [[ -e "$backup" ]]; then
      mv "$backup" "$target"
    fi
    return 1
  fi
  sleep 2
  if ! verify_running_path "$target"; then
    pkill -x "$EXECUTABLE_NAME" >/dev/null 2>&1 || true
    rm -rf "$target"
    if [[ -e "$backup" ]]; then
      mv "$backup" "$target"
      /usr/bin/open -n "$target" || true
    fi
    return 1
  fi
  rm -rf "$backup"
  echo "$target"
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
    verify_running_path "$APP_BUNDLE"
    ;;
  --install|install)
    install_app
    ;;
  *)
    echo "usage: $0 [run|--debug|--logs|--telemetry|--verify|--install]" >&2
    exit 2
    ;;
esac
