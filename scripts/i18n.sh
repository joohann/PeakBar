#!/usr/bin/env bash
# Toont ontbrekende sleutels per taal t.o.v. EN (bron).
#   scripts/i18n.sh            -> rapport voor alle talen
#   scripts/i18n.sh new de     -> maakt de.lproj met alle sleutels leeg ("")
#   scripts/i18n.sh fill nl    -> voegt alleen ontbrekende sleutels leeg toe aan nl
set -euo pipefail
cd "$(dirname "$0")/.."
RES=Resources
SRC="$RES/en.lproj/Localizable.strings"

keys() { { grep -oE '^"[^"]+"' "$1" || true; } | tr -d '"' | sort -u; }
empty() { { grep -E '^"[^"]+"[[:space:]]*=[[:space:]]*""' "$1" || true; } | { grep -oE '^"[^"]+"' || true; } | tr -d '"' | sort -u; }

case "${1:-report}" in
  new)
    lang="${2:?taalcode ontbreekt, bijv. de}"
    dir="$RES/$lang.lproj"; [[ -e "$dir" ]] && { echo "$dir bestaat al"; exit 1; }
    mkdir -p "$dir"
    keys "$SRC" | sed 's/.*/"&" = "";/' > "$dir/Localizable.strings"
    echo "Aangemaakt: $dir/Localizable.strings ($(keys "$SRC" | wc -l | tr -d ' ') lege sleutels)"
    ;;
  fill)
    lang="${2:?taalcode ontbreekt}"; f="$RES/$lang.lproj/Localizable.strings"
    comm -23 <(keys "$SRC") <(keys "$f") | sed 's/.*/"&" = "";/' >> "$f"
    echo "Ontbrekende sleutels leeg toegevoegd aan $f"
    ;;
  report)
    status=0
    for f in "$RES"/*.lproj/Localizable.strings; do
      lang=$(basename "$(dirname "$f")" .lproj); [[ $lang == en ]] && continue
      missing=$(comm -23 <(keys "$SRC") <(keys "$f"))
      blank=$(empty "$f")
      extra=$(comm -13 <(keys "$SRC") <(keys "$f"))
      if [[ -z "$missing$blank$extra" ]]; then echo "[$lang] compleet"; continue; fi
      status=1
      [[ -n $missing ]] && { echo "[$lang] ontbreekt:"; sed 's/^/  - /' <<<"$missing"; }
      [[ -n $blank ]]   && { echo "[$lang] leeg (valt terug op EN):"; sed 's/^/  - /' <<<"$blank"; }
      [[ -n $extra ]]   && { echo "[$lang] niet in EN:"; sed 's/^/  - /' <<<"$extra"; }
    done
    exit $status
    ;;
  *) echo "Gebruik: $0 [report|new <taal>|fill <taal>]"; exit 2 ;;
esac
