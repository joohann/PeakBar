#!/usr/bin/env bash
# Bouwt de .app uit config.json (enige plek voor naam, bundle-id en versie).
#   scripts/build.sh            -> build/<AppName>.app
#   scripts/build.sh install    -> ook kopiëren naar /Applications
set -euo pipefail
cd "$(dirname "$0")/.."

source scripts/lib.sh
APP_NAME=$(cfg appName)
BUNDLE_ID=$(cfg bundleId)
VERSION=$(cfg version)
MIN_OS=$(cfg minimumMacOS)
LSREGISTER=/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister

# .env afleiden uit config.json, zodat er één bron is.
cat > .env <<ENV
# Gegenereerd uit config.json door scripts/build.sh. Niet handmatig wijzigen.
APP_NAME=$APP_NAME
BUNDLE_ID=$BUNDLE_ID
VERSION=$VERSION
ENV

scripts/i18n.sh || echo "Let op: vertalingen niet compleet (valt terug op EN)."

APP="build/$APP_NAME.app"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources" "$APP/Contents/Frameworks"

# Sparkle (updates), pinned in config.json and checked against its SHA-256.
SPARKLE=$(sparkle_dir)
ditto "$SPARKLE/Sparkle.framework" "$APP/Contents/Frameworks/Sparkle.framework"
# The XPC services are only needed by sandboxed apps.
rm -rf "$APP/Contents/Frameworks/Sparkle.framework/Versions/B/XPCServices" \
       "$APP/Contents/Frameworks/Sparkle.framework/XPCServices"

# Universal binary: Apple silicon + Intel.
for ARCH in arm64 x86_64; do
  swiftc -O -swift-version 5 -parse-as-library \
    -target "$ARCH-apple-macos$MIN_OS" \
    -F "$SPARKLE" -framework Sparkle -Xlinker -rpath -Xlinker @executable_path/../Frameworks \
    Sources/*.swift -o "build/$APP_NAME-$ARCH"
done
lipo -create "build/$APP_NAME-arm64" "build/$APP_NAME-x86_64" -output "$APP/Contents/MacOS/$APP_NAME"
rm -f "build/$APP_NAME-arm64" "build/$APP_NAME-x86_64"

# App icon, drawn in code (Icon/IconDrawing.swift).
swiftc -swift-version 5 Icon/IconDrawing.swift Icon/Generate/main.swift -o build/icon-generator
rm -rf build/AppIcon.iconset
build/icon-generator build/AppIcon.iconset
iconutil -c icns build/AppIcon.iconset -o "$APP/Contents/Resources/AppIcon.icns"

cp config.json "$APP/Contents/Resources/"
cp -R Resources/*.lproj "$APP/Contents/Resources/"
LANGS=$(ls -d Resources/*.lproj | xargs -n1 basename | sed 's/\.lproj//' | sed 's/.*/<string>&<\/string>/' | tr -d '\n')

cat > "$APP/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
  <key>CFBundleName</key><string>$APP_NAME</string>
  <key>CFBundleDisplayName</key><string>$APP_NAME</string>
  <key>CFBundleExecutable</key><string>$APP_NAME</string>
  <key>CFBundleIdentifier</key><string>$BUNDLE_ID</string>
  <key>CFBundleShortVersionString</key><string>$VERSION</string>
  <key>CFBundleVersion</key><string>$VERSION</string>
  <key>CFBundleIconFile</key><string>AppIcon</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>CFBundleDevelopmentRegion</key><string>en</string>
  <key>CFBundleLocalizations</key><array>$LANGS</array>
  <key>LSMinimumSystemVersion</key><string>$MIN_OS</string>
  <key>LSUIElement</key><true/>
  <key>NSHighResolutionCapable</key><true/>
  <key>SUFeedURL</key><string>$(expand "$(cfg update.feedUrl)")</string>
  <key>SUPublicEDKey</key><string>$(cfg update.publicKey)</string>
  <key>SUEnableAutomaticChecks</key><true/>
  <key>SURequireSignedFeed</key><true/>
  <key>SUVerifyUpdateBeforeExtraction</key><true/>
  <key>SUAutomaticallyUpdate</key><false/>
  <key>SUScheduledCheckInterval</key><integer>$(cfg update.checkSeconds)</integer>
</dict></plist>
PLIST

IDENTITY=$(cfg signing.identity)
OPTS=()
[[ "$IDENTITY" != "-" ]] && OPTS=(--options runtime --timestamp)
# Sign inside out: Sparkle's helpers, the framework (changed above), then the app.
FW="$APP/Contents/Frameworks/Sparkle.framework"
for ITEM in "$FW/Versions/B/Autoupdate" "$FW/Versions/B/Updater.app" "$FW" "$APP"; do
  codesign --force ${OPTS[@]+"${OPTS[@]}"} --sign "$IDENTITY" "$ITEM" 2>/dev/null
done
touch "$APP"
# Re-register so Finder picks up a changed icon instead of a cached one.
"$LSREGISTER" -f "$APP" 2>/dev/null || true
echo "Gebouwd: $APP ($(du -sh "$APP" | cut -f1))"

if [[ "${1:-}" == install ]]; then
  pkill -x "$APP_NAME" 2>/dev/null || true
  rm -rf "/Applications/$APP_NAME.app"
  cp -R "$APP" /Applications/
  touch "/Applications/$APP_NAME.app"
  "$LSREGISTER" -f "/Applications/$APP_NAME.app" 2>/dev/null || true
  open "/Applications/$APP_NAME.app"
  echo "Geïnstalleerd in /Applications en gestart."
fi
