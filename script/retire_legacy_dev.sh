#!/usr/bin/env bash
set -euo pipefail

MODE="${1:---dry-run}"
ARCHIVE_DIR="${QUOTA_CAPSULE_ARCHIVE_DIR:-$HOME/Documents/Quota Capsule Archive/2026-07-13-dev-retirement}"
LEGACY_APP="${QUOTA_CAPSULE_LEGACY_APP:-/Applications/Quota Capsule Dev Local.app}"
LEGACY_DATA="${QUOTA_CAPSULE_LEGACY_DATA:-$HOME/Library/Application Support/Quota Capsule Dev Local}"
RETIRED_DIR="$ARCHIVE_DIR/retired-artifacts"

stop_legacy_process() {
  if [[ "${QUOTA_CAPSULE_SKIP_PROCESS:-0}" != "1" ]]; then
    pkill -x QuotaCapsuleDevLocal >/dev/null 2>&1 || true
  fi
}

verify_archive() {
  if [[ ! -f "$ARCHIVE_DIR/MANIFEST.md" || ! -f "$ARCHIVE_DIR/SHA256SUMS" ]]; then
    echo "verified retirement archive is required before legacy cleanup" >&2
    return 2
  fi
  if ! (cd "$ARCHIVE_DIR" && shasum -a 256 -c SHA256SUMS >/dev/null); then
    echo "verified retirement archive is required before legacy cleanup" >&2
    return 2
  fi
}

refresh_archive_checksums() {
  (
    cd "$ARCHIVE_DIR"
    : > SHA256SUMS.tmp
    while IFS= read -r -d '' file; do
      shasum -a 256 "$file" >> SHA256SUMS.tmp
    done < <(find . -type f ! -name SHA256SUMS ! -name SHA256SUMS.tmp -print0)
    mv SHA256SUMS.tmp SHA256SUMS
    shasum -a 256 -c SHA256SUMS >/dev/null
  )
}

describe_item() {
  local kind="$1"
  local source="$2"
  if [[ -e "$source" ]]; then
    echo "would archive legacy $kind: $source"
  else
    echo "legacy $kind is already absent: $source"
  fi
}

archive_item() {
  local source="$1"
  local destination="$2"
  if [[ ! -e "$source" ]]; then
    return
  fi
  if [[ -e "$destination" ]]; then
    echo "refusing to overwrite archived legacy artifact: $destination" >&2
    exit 2
  fi
  mv "$source" "$destination"
}

case "$MODE" in
  --dry-run)
    describe_item "application" "$LEGACY_APP"
    describe_item "data" "$LEGACY_DATA"
    ;;
  --stop-process)
    stop_legacy_process
    ;;
  --apply)
    verify_archive
    stop_legacy_process
    mkdir -p "$RETIRED_DIR"
    archive_item "$LEGACY_APP" "$RETIRED_DIR/Quota Capsule Dev Local.app"
    archive_item "$LEGACY_DATA" "$RETIRED_DIR/Quota Capsule Dev Local"
    refresh_archive_checksums
    echo "legacy Dev artifacts retired"
    ;;
  *)
    echo "usage: $0 [--dry-run|--stop-process|--apply]" >&2
    exit 2
    ;;
esac
