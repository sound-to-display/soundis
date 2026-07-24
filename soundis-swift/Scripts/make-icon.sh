#!/usr/bin/env bash
# Render the galaxy app icon and build Scripts/AppIcon.icns.
# Run when the icon design (icon-gen.swift) changes; make-app.sh copies the
# resulting .icns into the bundle.
set -euo pipefail
cd "$(dirname "$0")"

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

echo "==> rendering 1024px master"
swift icon-gen.swift "$TMP/icon-1024.png"

ISET="$TMP/AppIcon.iconset"
mkdir -p "$ISET"
sizes=(16 32 32 64 128 256 256 512 512 1024)
names=(icon_16x16 icon_16x16@2x icon_32x32 icon_32x32@2x icon_128x128
       icon_128x128@2x icon_256x256 icon_256x256@2x icon_512x512 icon_512x512@2x)
for i in "${!sizes[@]}"; do
  sips -z "${sizes[$i]}" "${sizes[$i]}" "$TMP/icon-1024.png" --out "$ISET/${names[$i]}.png" >/dev/null
done

echo "==> iconutil → AppIcon.icns"
iconutil -c icns "$ISET" -o AppIcon.icns
echo "✔ wrote Scripts/AppIcon.icns"
