#!/bin/bash
# mk.sh: builds ENG-POMAR-UPGRADE-2026-11-11.sh from body.sh, the note and bootstrap's model-answered.sh, byte for byte.
set -euo pipefail
cd "$(dirname "$0")"
awk -v note=upgrade-note.txt -v ma=../model-answered.sh '
  $0 == "@@NOTE@@" { while ((getline l < note) > 0) print l; next }
  $0 == "@@MA@@"   { while ((getline l < ma) > 0) print l; next }
  { print }' body.sh > ENG-POMAR-UPGRADE-2026-11-11.sh
shasum -a 256 ENG-POMAR-UPGRADE-2026-11-11.sh
