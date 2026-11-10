#!/usr/bin/env bash
# Rendert een voorbeeld van het menupaneel (licht/donker, drie toestanden) naar build/preview.png.
set -euo pipefail
cd "$(dirname "$0")/.."
APP_NAME=$(plutil -extract appName raw -o - config.json)
[[ -d "build/$APP_NAME.app" ]] || scripts/build.sh
swiftc -swift-version 5 $(ls Sources/*.swift | grep -v '/App.swift$') Preview/main.swift -o build/preview
build/preview "build/$APP_NAME.app" build/preview.png
