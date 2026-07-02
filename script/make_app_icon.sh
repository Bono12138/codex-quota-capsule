#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SOURCE_SVG="${1:-$ROOT_DIR/Sources/QuotaCapsuleMac/Resources/app-icon.svg}"
OUTPUT_ICNS="${2:-$ROOT_DIR/artifacts/generated/QuotaCapsuleAppIcon.icns}"

if [[ ! -f "$SOURCE_SVG" ]]; then
  echo "missing app icon source: $SOURCE_SVG" >&2
  exit 1
fi

TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

ICONSET="$TMP_DIR/QuotaCapsuleAppIcon.iconset"
mkdir -p "$ICONSET"

make_png() {
  local pixels="$1"
  local name="$2"
  /usr/bin/sips -s format png -z "$pixels" "$pixels" "$SOURCE_SVG" --out "$ICONSET/$name" >/dev/null
}

make_png 16 "icon_16x16.png"
make_png 32 "icon_16x16@2x.png"
make_png 32 "icon_32x32.png"
make_png 64 "icon_32x32@2x.png"
make_png 128 "icon_128x128.png"
make_png 256 "icon_128x128@2x.png"
make_png 256 "icon_256x256.png"
make_png 512 "icon_256x256@2x.png"
make_png 512 "icon_512x512.png"
make_png 1024 "icon_512x512@2x.png"

mkdir -p "$(dirname "$OUTPUT_ICNS")"
/usr/bin/iconutil -c icns "$ICONSET" -o "$OUTPUT_ICNS"
echo "$OUTPUT_ICNS"
