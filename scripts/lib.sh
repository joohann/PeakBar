#!/usr/bin/env bash
# Shared helpers for the scripts. All values come from config.json.

cfg() { plutil -extract "$1" raw -o - config.json; }

# Fills {appName}, {repository} and {version} in a config template.
expand() {
  local s=$1 version=${2:-$(cfg version)}
  s=${s//\{appName\}/$(cfg appName)}
  s=${s//\{repository\}/$(cfg repository)}
  s=${s//\{version\}/$version}
  printf '%s' "$s"
}

# Downloads the pinned Sparkle release once, checks its SHA-256 and prints the folder.
sparkle_dir() {
  local version sha dir archive
  version=$(cfg update.sparkleVersion)
  sha=$(cfg update.sparkleSha256)
  dir="build/vendor/Sparkle-$version"
  if [[ ! -d "$dir/Sparkle.framework" ]]; then
    mkdir -p "$dir"
    archive="$dir.tar.xz"
    curl -sSfL -o "$archive" \
      "https://github.com/sparkle-project/Sparkle/releases/download/$version/Sparkle-$version.tar.xz"
    if [[ $(shasum -a 256 "$archive" | cut -d' ' -f1) != "$sha" ]]; then
      rm -rf "$dir" "$archive"
      echo "Sparkle $version: checksum klopt niet, gestopt." >&2
      return 1
    fi
    tar -xJf "$archive" -C "$dir"
    rm -f "$archive"
  fi
  printf '%s' "$dir"
}
