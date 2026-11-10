#!/usr/bin/env bash
# Maakt een deelbare DMG: build/<AppName>-<versie>.dmg (met snelkoppeling naar /Applications).
# Notariseert alleen als config.json een Developer ID en een notaryProfile bevat.
set -euo pipefail
cd "$(dirname "$0")/.."

cfg() { plutil -extract "$1" raw -o - config.json; }
APP_NAME=$(cfg appName)
VERSION=$(cfg version)
IDENTITY=$(cfg signing.identity)
PROFILE=$(cfg signing.notaryProfile)

scripts/build.sh
APP="build/$APP_NAME.app"
DMG="build/$APP_NAME-$VERSION.dmg"
STAGE=$(mktemp -d)
trap 'rm -rf "$STAGE"' EXIT

cp -R "$APP" "$STAGE/"
ln -s /Applications "$STAGE/Applications"
rm -f "$DMG"
hdiutil create -quiet -volname "$APP_NAME" -srcfolder "$STAGE" -fs HFS+ -format UDZO "$DMG"

if [[ "$IDENTITY" != "-" ]]; then
  codesign --force --timestamp --sign "$IDENTITY" "$DMG"
  if [[ -n "$PROFILE" ]]; then
    xcrun notarytool submit "$DMG" --keychain-profile "$PROFILE" --wait
    xcrun stapler staple "$DMG"
  fi
fi

echo "Pakket: $DMG ($(du -h "$DMG" | cut -f1))"
[[ "$IDENTITY" == "-" ]] && echo "Let op: ad-hoc ondertekend, niet genotariseerd. Ontvangers moeten de app eenmalig toestaan."
