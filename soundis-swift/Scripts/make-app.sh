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

echo "==> ad-hoc code signing"
codesign --force --sign - --timestamp=none "$APP"

echo "==> done: $APP"
