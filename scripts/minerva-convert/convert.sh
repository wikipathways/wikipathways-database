#!/usr/bin/env bash
# Convert GPML pathways with MINERVA's converter API and store static copies next to each GPML:
#
#   pathways/WPxx/WPxx-sbgn.xml          SBGN-ML
#   pathways/WPxx/WPxx-sbml.xml          SBML (with the Layout package)
#   pathways/WPxx/WPxx-celldesigner.xml  CellDesigner SBML
#   pathways/WPxx/WPxx-minerva.json      provenance: the GPML's SHA-256, MINERVA version, date, formats made
#
# Usage: scripts/minerva-convert/convert.sh pathways/WP1/WP1.gpml [more.gpml ...]
#
# A format that fails to convert keeps its previous file, but is left out of the provenance's "formats",
# so readers (e.g. scripts/layout-score) can tell that file was not made from the current GPML.
# The script never fails on a conversion error (MINERVA being down must not block anything);
# it exits non-zero only on wrong arguments. A summary is printed at the end.
#
# Environment: MINERVA_API (default https://minerva-service.lcsb.uni.lu/minerva/api),
#              MINERVA_FORMATS (default "SBGN-ML SBML CellDesigner_SBML"), MINERVA_PAUSE (seconds between calls, default 1).

set -uo pipefail

API="${MINERVA_API:-https://minerva-service.lcsb.uni.lu/minerva/api}"
FORMATS="${MINERVA_FORMATS:-SBGN-ML SBML CellDesigner_SBML}"
PAUSE="${MINERVA_PAUSE:-1}"

if [ "$#" -eq 0 ]; then
  echo "usage: $0 pathways/WPxx/WPxx.gpml [...]" >&2
  exit 2
fi

suffix() {
  case "$1" in
    SBGN-ML) echo "sbgn.xml" ;;
    SBML) echo "sbml.xml" ;;
    CellDesigner_SBML) echo "celldesigner.xml" ;;
    *) echo "$1.xml" ;;
  esac
}

# Well-formed and non-empty XML with the expected root element.
valid() {
  local file="$1" format="$2"
  [ -s "$file" ] || return 1
  case "$format" in
    SBGN-ML) grep -q '<sbgn' "$file" ;;
    SBML | CellDesigner_SBML) grep -q '<sbml' "$file" ;;
    *) true ;;
  esac || return 1
  if command -v xmllint > /dev/null; then xmllint --noout "$file" 2> /dev/null || return 1; fi
}

VERSION=$(curl -sS --max-time 30 "$API/configuration/" | grep -o '"version" *: *"[^"]*"' | head -1 | sed 's/.*: *"\(.*\)"/\1/')
VERSION="${VERSION:-unknown}"
echo "MINERVA $VERSION at $API"

ok=0
failed=0
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

for gpml in "$@"; do
  if [ ! -f "$gpml" ]; then
    echo "skip $gpml: not found"
    continue
  fi
  dir=$(dirname "$gpml")
  wpid=$(basename "$gpml" .gpml)
  if ! [[ "$wpid" =~ ^WP[0-9]+$ ]]; then
    echo "skip $gpml: not a WPID"
    continue
  fi
  sha=$(sha256sum "$gpml" | cut -d' ' -f1)
  made=()
  for format in $FORMATS; do
    out="$dir/$wpid-$(suffix "$format")"
    code=$(curl -sS -o "$tmp/out.xml" -w '%{http_code}' --retry 3 --retry-delay 10 --max-time 300 \
      -X POST "$API/convert/GPML:$format" -H 'Content-Type: text/plain' --data-binary @"$gpml" 2> "$tmp/err") || code="curl: $(tail -1 "$tmp/err")"
    if [ "$code" = "200" ] && valid "$tmp/out.xml" "$format"; then
      mv "$tmp/out.xml" "$out"
      made+=("$format")
      ok=$((ok + 1))
      echo "ok   $wpid $format"
    else
      failed=$((failed + 1))
      echo "FAIL $wpid $format ($code)"
    fi
    sleep "$PAUSE"
  done
  if [ "${#made[@]}" -gt 0 ]; then
    formats_json=$(for f in "${made[@]}"; do printf '"%s": "%s-%s",' "$f" "$wpid" "$(suffix "$f")"; done)
    cat > "$dir/$wpid-minerva.json" << EOF
{
  "source": "$wpid.gpml",
  "gpml_sha256": "$sha",
  "converter": "MINERVA $VERSION",
  "api": "$API/convert",
  "date": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "formats": {${formats_json%,}}
}
EOF
  fi
done

echo "converted: $ok, failed: $failed"
if [ -n "${GITHUB_STEP_SUMMARY:-}" ]; then
  echo "MINERVA $VERSION: $ok conversions, $failed failed" >> "$GITHUB_STEP_SUMMARY"
fi
exit 0
