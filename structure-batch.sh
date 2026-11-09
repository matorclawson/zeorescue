#!/bin/bash
# zeo-rescue: one batch of moves into the one code structure, on the Architect's order of 9 Nov 03:49Z. reseat-lines.sh runs it, and pins it
# with its table, structure-batches, and structure-move.sh, which does each step.
#
#   structure-batch.sh BATCH   for each seat of BATCH, in the table's order: structure-move.sh SEAT trust, then first, then clear, which runs
#                              only when the seat's own check says OK. A seat that is busy or down is SKIPPED, with the reason, and the batch
#                              goes on. Any other refusal or failure, or a check that is not OK, stops the batch at that seat: the seats after
#                              it are NOT REACHED and nothing is run for them. One RESULT line per seat, then the total.
#
# Each step keeps its own guards: structure-move.sh reads the seat's row, knows only the states before and after the move, refuses a Claude
# nobody rehearsed, and proves the note reached the seat's own transcript. A second run of a batch finds the moved seats ALREADY MOVED.
# Exit: 0 the batch ran to its end (seats may be skipped); 1 it stopped at a seat; 2 usage, or a table that is wrong, and nothing was run.
set -uo pipefail
HERE=$(cd "$(dirname "$0")" && pwd -P)
BATCHES=${ZEO_RESCUE_BATCHES:-$HERE/structure-batches}
TABLE=${ZEO_RESCUE_TABLE:-$HERE/structure-moves}
b=${1:-}
[[ "$b" =~ ^[a-z0-9][a-z0-9-]{0,63}$ ]] || { echo "usage: structure-batch.sh BATCH; nothing was run"; exit 2; }
cd "$HERE" || exit 2
seats=$(awk -v b="$b" '$1 !~ /^#/ && $1==b {print $2}' "$BATCHES" 2>/dev/null)
[ -n "$seats" ] || { echo "REFUSED, nothing was run: there is no batch $b in structure-batches"; exit 2; }
[ "$(awk -v b="$b" '$1 !~ /^#/ && $1==b && NF != 2' "$BATCHES" | wc -l | tr -d ' ')" = 0 ] || { echo "REFUSED, nothing was run: a line of batch $b in structure-batches is not BATCH SEAT"; exit 2; }
d=$(printf '%s\n' $seats | sort | uniq -d | head -1)
[ -z "$d" ] || { echo "REFUSED, nothing was run: $d is in batch $b twice"; exit 2; }
# Every seat is read before any is moved: one with no row, or a bad id, would stop the batch halfway.
for s in $seats; do
  [[ "$s" =~ ^[a-z0-9][a-z0-9-]{0,63}$ ]] || { echo "REFUSED, nothing was run: $s is not a seat id"; exit 2; }
  [ "$(awk -v s="$s" '$1==s' "$TABLE" | wc -l | tr -d ' ')" = 1 ] || { echo "REFUSED, nothing was run: $s needs exactly one row in structure-moves"; exit 2; }
done
n=$(printf '%s\n' $seats | wc -l | tr -d ' ')
echo "batch $b: $n seats, in this order: $(printf '%s ' $seats)"
out=$(mktemp "${TMPDIR:-/tmp}/structure-batch.XXXXXX") || exit 1
trap 'rm -f "$out"' EXIT
step() { # step SEAT STEP: runs it, its output shown as it comes and kept for the reading
  ./structure-move.sh "$1" "$2" 2>&1 | tee "$out"; return "${PIPESTATUS[0]}"
}
moved=0 already=0 skipped=0 left=0 stopped=""
for s in $seats; do
  if [ -n "$stopped" ]; then echo "RESULT $s: NOT REACHED; nothing was run for it"; left=$((left+1)); continue; fi
  echo "== $s"
  step "$s" trust; rc=$?
  [ $rc -eq 0 ] || { echo "RESULT $s: STOPPED at trust (exit $rc); the batch stops here"; stopped=$s; continue; }
  step "$s" first; rc=$?
  if [ $rc -ne 0 ]; then
    if [ $rc -eq 2 ] && grep -q '^BUSY, nothing was run' "$out"; then echo "RESULT $s: SKIPPED, it is busy: $(grep -m1 'a turn is in progress' "$out")"; skipped=$((skipped+1)); continue; fi
    if [ $rc -eq 2 ] && grep -q '^DOWN, nothing was run' "$out"; then echo "RESULT $s: SKIPPED, it is down"; skipped=$((skipped+1)); continue; fi
    echo "RESULT $s: STOPPED at first (exit $rc); the batch stops here"; stopped=$s; continue
  fi
  was=moved; grep -q '^ALREADY DONE: ' "$out" && was=already
  step "$s" clear; rc=$?
  [ $rc -eq 0 ] || { echo "RESULT $s: STOPPED at clear (exit $rc): it moved, but its own check is not OK; the batch stops here"; stopped=$s; continue; }
  if [ $was = already ]; then echo "RESULT $s: ALREADY MOVED; its backup is gone"; already=$((already+1))
  else echo "RESULT $s: MOVED: note delivered, its own check OK, its backup gone"; moved=$((moved+1)); fi
done
echo "batch $b: moved $moved, already moved $already, skipped $skipped, stopped at ${stopped:-none}, not reached $left, of $n. Tell zeo-rescue: done."
[ -z "$stopped" ]
