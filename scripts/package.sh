#!/usr/bin/env bash
# Maakt een deelbare DMG: build/<AppName>-<versie>.dmg (met snelkoppeling naar /Applications).
# Notariseert alleen als config.json een Developer ID en een notaryProfile bevat.
set -euo pipefail
cd "$(dirname "$0")/.."

source scripts/lib.sh
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

# Appcast for Sparkle: the DMG is signed with the EdDSA key in the Keychain, then the feed itself.
SPARKLE=$(sparkle_dir)
ACCOUNT=$(cfg update.keyAccount)
ENCLOSURE=$("$SPARKLE/bin/sign_update" --account "$ACCOUNT" "$DMG")
NOTES=$(awk -v v="## $VERSION" '$0 == v {on=1; next} /^## / {on=0} on' CHANGELOG.md)
[[ -n "$NOTES" ]] || { echo "CHANGELOG.md heeft geen sectie '## $VERSION'." >&2; exit 1; }
cat > appcast.xml <<XML
<?xml version="1.0" encoding="utf-8"?>
<rss version="2.0" xmlns:sparkle="http://www.andymatuschak.org/xml-namespaces/sparkle">
  <channel>
    <title>$APP_NAME</title>
    <item>
      <title>$APP_NAME $VERSION</title>
      <pubDate>$(LC_ALL=C date -u "+%a, %d %b %Y %H:%M:%S +0000")</pubDate>
      <sparkle:version>$VERSION</sparkle:version>
      <sparkle:shortVersionString>$VERSION</sparkle:shortVersionString>
      <sparkle:minimumSystemVersion>$(cfg minimumMacOS)</sparkle:minimumSystemVersion>
      <sparkle:fullReleaseNotesLink>$(expand "$(cfg update.releaseNotesUrl)" "$VERSION")</sparkle:fullReleaseNotesLink>
      <description sparkle:format="markdown"><![CDATA[$NOTES
]]></description>
      <enclosure url="$(expand "$(cfg update.downloadUrl)" "$VERSION")" type="application/octet-stream" $ENCLOSURE/>
    </item>
  </channel>
</rss>
XML
"$SPARKLE/bin/sign_update" --account "$ACCOUNT" appcast.xml
echo "Appcast: appcast.xml. Publiceer eerst de GitHub-release met de DMG, push daarna appcast.xml."
[[ "$IDENTITY" == "-" ]] && echo "Let op: ad-hoc ondertekend, niet genotariseerd. Ontvangers moeten de app eenmalig toestaan."
