#!/bin/bash
# zeo-rescue: delete the stub reseat logs that tests wrote into the real state folder (8 and 9 Nov), exactly as listed, on the Architect's
# word (10 Nov, section 3). Usage: junk-stub-logs.sh LIST [--apply]
#   LIST is STUB-LOGS-zeo-rescue-state-2026-11-09.tsv: a header "path size sha256", then one row per file, tab-separated.
#   Without --apply it changes nothing and says what it would do. With --apply it deletes each listed file that still reads as listed.
# A row is deleted only when every check holds: the path is STATE/reseat-YYYYMMDD-HHMMSS.log, an ordinary file and not a link; its size and
# sha256 are the row's; and its whole content is one line ending in ": stub". Anything else is SKIPPED with the reason and left as it is.
# No globs, no folders, nothing outside the state folder. One receipt line per row (WOULD DELETE, DELETED or SKIPPED), then the totals.
# The receipt is written to STATE/junk-stub-logs-<UTC time>.receipt with --apply. Exit: 0 every row deleted (or would be); 1 any row skipped
# or failed; 2 usage or a list that is wrong, and nothing was done.
set -uo pipefail
STATE=${ZEO_RESCUE_STATE:-$HOME/.local/state/zeo-rescue}
list=${1:-} apply=${2:-}
[ -f "$list" ] && { [ -z "$apply" ] || [ "$apply" = --apply ]; } || { echo "usage: junk-stub-logs.sh LIST [--apply]; nothing was done"; exit 2; }
[ "$(head -1 "$list")" = "$(printf 'path\tsize\tsha256')" ] || { echo "REFUSED, nothing was done: $list does not start with the header path, size, sha256"; exit 2; }
bad=$(tail -n +2 "$list" | awk -F'\t' 'NF != 3' | head -1)
[ -z "$bad" ] || { echo "REFUSED, nothing was done: a row of $list is not path, size, sha256: $bad"; exit 2; }
dup=$(tail -n +2 "$list" | cut -f1 | sort | uniq -d | head -1)
[ -z "$dup" ] || { echo "REFUSED, nothing was done: $dup is listed twice"; exit 2; }
receipt=/dev/null
if [ -n "$apply" ]; then receipt=$STATE/junk-stub-logs-$(date -u +%Y%m%d-%H%M%S).receipt; : > "$receipt" || { echo "FAILED, nothing was done: cannot write $receipt"; exit 2; }; fi
done_n=0 skip_n=0
say() { echo "$*"; echo "$*" >> "$receipt"; }
while IFS=$'\t' read -r p size sum; do
  why=""
  [[ "$p" =~ ^"$STATE"/reseat-[0-9]{8}-[0-9]{6}\.log$ ]] || why="not a reseat log in $STATE"
  [ -n "$why" ] || { [ -f "$p" ] && [ ! -L "$p" ]; } || why="not an ordinary file (gone, a link or a folder)"
  [ -n "$why" ] || [ "$(stat -f %z "$p")" = "$size" ] || why="its size is not $size"
  [ -n "$why" ] || [ "$(/usr/bin/shasum -a 256 "$p" | cut -d ' ' -f 1)" = "$sum" ] || why="its sha256 is not the listed one"
  [ -n "$why" ] || { [ "$(wc -l < "$p" | tr -d ' ')" = 1 ] && LC_ALL=C grep -q ': stub$' "$p"; } || why="its content is not one line ending in ': stub'"
  if [ -n "$why" ]; then say "SKIPPED $p: $why"; skip_n=$((skip_n+1)); continue; fi
  if [ -z "$apply" ]; then say "WOULD DELETE $p"; done_n=$((done_n+1)); continue; fi
  rm -f -- "$p" && [ ! -e "$p" ] && { say "DELETED $p"; done_n=$((done_n+1)); } || { say "SKIPPED $p: the delete failed"; skip_n=$((skip_n+1)); }
done < <(tail -n +2 "$list")
say "junk-stub-logs: $([ -n "$apply" ] && echo deleted || echo "would delete") $done_n, skipped $skip_n, of $((done_n+skip_n)) listed${apply:+; receipt $receipt}"
[ "$skip_n" = 0 ]
