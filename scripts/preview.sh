#!/usr/bin/env bash
# Rendert een voorbeeld van het menupaneel (licht/donker, vier toestanden) naar build/preview.png.
#   scripts/preview.sh docs   -> schrijft ook losse afbeeldingen voor de README naar docs/
set -euo pipefail
cd "$(dirname "$0")/.."
APP_NAME=$(plutil -extract appName raw -o - config.json)
[[ -d "build/$APP_NAME.app" ]] || scripts/build.sh
swiftc -swift-version 5 $(ls Sources/*.swift | grep -v '/App.swift$') Preview/main.swift -o build/preview
build/preview "build/$APP_NAME.app" build/preview.png "${1:-}"
