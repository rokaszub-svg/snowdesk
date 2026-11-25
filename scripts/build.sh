#!/usr/bin/env bash
# Builds a universal (Apple Silicon + Intel) .app and a .dmg into ./dist
#
# Optional env:
#   APP_NAME, BUNDLE_ID, VERSION
#   DEVELOPER_ID        "Developer ID Application: Your Name (TEAMID)"  -> real signing
#   APPLE_ID, APPLE_APP_PASSWORD, APPLE_TEAM_ID                         -> notarization
set -euo pipefail

APP_NAME="${APP_NAME:-Snowdesk}"
BUNDLE_ID="${BUNDLE_ID:-com.snowdesk.mac}"
VERSION="${VERSION:-1.0.0}"
BUILD="${BUILD:-$(date +%Y%m%d%H%M)}"

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

echo "==> Compiling"
swift build -c release --arch arm64 --arch x86_64
BIN_DIR="$(swift build -c release --arch arm64 --arch x86_64 --show-bin-path)"

DIST="$ROOT/dist"
APP="$DIST/$APP_NAME.app"
rm -rf "$DIST"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"

cp "$BIN_DIR/Snowdesk" "$APP/Contents/MacOS/$APP_NAME"
sed -e "s/__APP_NAME__/$APP_NAME/g" \
    -e "s/__BUNDLE_ID__/$BUNDLE_ID/g" \
    -e "s/__VERSION__/$VERSION/g" \
    -e "s/__BUILD__/$BUILD/g" \
    Resources/Info.plist > "$APP/Contents/Info.plist"

echo "==> Icon"
ICONSET="$DIST/AppIcon.iconset"
mkdir -p "$ICONSET"
for s in 16 32 128 256 512; do
  sips -z $s $s Resources/AppIcon.png --out "$ICONSET/icon_${s}x${s}.png" >/dev/null
  d=$((s * 2))
  sips -z $d $d Resources/AppIcon.png --out "$ICONSET/icon_${s}x${s}@2x.png" >/dev/null
done
iconutil -c icns "$ICONSET" -o "$APP/Contents/Resources/AppIcon.icns"
rm -rf "$ICONSET"

echo "==> Signing"
if [[ -n "${DEVELOPER_ID:-}" ]]; then
  codesign --force --options runtime --timestamp --sign "$DEVELOPER_ID" "$APP"
else
  echo "    (no DEVELOPER_ID -> ad-hoc signature, users will see a Gatekeeper warning)"
  codesign --force --sign - "$APP"
fi

echo "==> DMG"
DMG="$DIST/$APP_NAME-$VERSION.dmg"
STAGE="$DIST/dmg"
mkdir -p "$STAGE"
cp -R "$APP" "$STAGE/"
ln -s /Applications "$STAGE/Applications"
hdiutil create -volname "$APP_NAME" -srcfolder "$STAGE" -ov -format UDZO "$DMG" >/dev/null
rm -rf "$STAGE"

if [[ -n "${DEVELOPER_ID:-}" ]]; then
  codesign --force --timestamp --sign "$DEVELOPER_ID" "$DMG"
fi

if [[ -n "${APPLE_ID:-}" && -n "${APPLE_APP_PASSWORD:-}" && -n "${APPLE_TEAM_ID:-}" ]]; then
  echo "==> Notarizing (takes a few minutes)"
  xcrun notarytool submit "$DMG" --apple-id "$APPLE_ID" --password "$APPLE_APP_PASSWORD" \
    --team-id "$APPLE_TEAM_ID" --wait
  xcrun stapler staple "$DMG"
fi

echo "==> Done: $DMG"
