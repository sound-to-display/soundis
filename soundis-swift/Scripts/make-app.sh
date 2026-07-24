#!/usr/bin/env bash
# Assemble Soundis.app so macOS will grant mic + system-audio permissions.
#
# A bare `swift run` binary has no Info.plist, so macOS refuses the microphone
# (needs NSMicrophoneUsageDescription) and system-audio capture. This bundles
# the release binary with an Info.plist and ad-hoc code signature.
#
#   ./Scripts/make-app.sh
#   open build/Soundis.app
#
# Screen Recording permission (required by ScreenCaptureKit for system audio)
# is still prompted on first SYSTEM use — allow it in
# System Settings › Privacy & Security › Screen Recording.
set -euo pipefail

cd "$(dirname "$0")/.."

APP="build/Soundis.app"
CONTENTS="$APP/Contents"

echo "==> swift build -c release"
swift build -c release

BIN="$(swift build -c release --show-bin-path)/Soundis"

echo "==> assembling $APP"
rm -rf "$APP"
mkdir -p "$CONTENTS/MacOS" "$CONTENTS/Resources"
cp "$BIN" "$CONTENTS/MacOS/Soundis"
cp "Scripts/Info.plist" "$CONTENTS/Info.plist"
[ -f "Scripts/AppIcon.icns" ] && cp "Scripts/AppIcon.icns" "$CONTENTS/Resources/AppIcon.icns"

# Prefer the stable self-signed identity (permissions persist across rebuilds);
# fall back to ad-hoc if it hasn't been created yet.
IDENTITY="Soundis Self-Signed"
if security find-identity -p codesigning 2>/dev/null | grep -q "$IDENTITY"; then
  echo "==> code signing with stable identity '$IDENTITY'"
  codesign --force --sign "$IDENTITY" --timestamp=none "$APP"
else
  echo "==> ad-hoc code signing"
  echo "    (run ./Scripts/make-signing-cert.sh once so Screen Recording / Mic permission sticks)"
  codesign --force --sign - --timestamp=none "$APP"
fi

echo "==> done: $APP"
