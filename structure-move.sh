#!/bin/bash
# zeo-rescue: one seat's move into the one code structure, on the Architect's order of 8 Nov 22:10Z. reseat-lines.sh runs it, and pins it.
#
#   structure-move.sh SEAT trust   adds the Claude trust entry for the seat's new folder, under Claude's own config lock; starts nothing
#   structure-move.sh SEAT first   restarts that one seat; rescue.sh carries its clone to the new folder while it is stopped, and moves its
#                                  project with its memory. Then it proves the note reached the transcript. It runs once, and refuses while
#                                  the seat is working, or on a Claude nobody rehearsed
#   structure-move.sh SEAT clear   deletes the backup of ~/.claude.json the trust step made, which holds account data; only once the seat checks right
#
# Each run moves exactly one seat: the one named, which must have exactly one row in structure-moves, the same move in folder-moves and its
# thread in session-pins. Every step reads first, and refuses unless the state is one of the two it knows: before (the clone at FROM with the
# inode the row records, nothing at TO) or after (that same folder at TO). Claude seats only: a Codex carry comes with its own rehearsal.
set -uo pipefail
HERE=$(cd "$(dirname "$0")" && pwd -P)
STATE=${STATE:-${ZEO_RESCUE_STATE:-$HOME/.local/state/zeo-rescue}}
PROJECTS=${ZEO_RESCUE_PROJECTS:-$HOME/.claude/projects}
CLAUDE_JSON=${ZEO_RESCUE_CLAUDE_JSON:-$HOME/.claude.json}
CLAUDE_BIN=${ZEO_RESCUE_CLAUDE:-$HOME/.local/bin/claude}
TABLE=${ZEO_RESCUE_TABLE:-$HERE/structure-moves}
MOVES=${ZEO_RESCUE_MOVES:-$HERE/folder-moves}
PINS=${ZEO_RESCUE_PINS:-$HERE/session-pins}
TEMPLATE=$HERE/notes/structure-move-claude.txt
PROOF="Read and write memories only in the new memory folder, never in the old one, and never create the old one."
REHEARSED=2.1.319
TRIES=${ZEO_RESCUE_PROOF_TRIES:-60}
seat=${1:-} step=${2:-}
case "$step" in trust|first|clear) ;; *) echo "usage: structure-move.sh SEAT trust|first|clear; nothing was run"; exit 2;; esac
[[ "$seat" =~ ^[a-z0-9][a-z0-9-]{0,63}$ ]] || { echo "usage: structure-move.sh SEAT trust|first|clear; nothing was run"; exit 2; }
cd "$HERE" || exit 2
no() { echo "REFUSED, nothing was changed: $*"; exit 2; }
key() { printf %s "$1" | LC_ALL=C sed 's/[^A-Za-z0-9]/-/g'; }
sha() { /usr/bin/shasum -a 256 "$1" 2>/dev/null | cut -d " " -f 1; }
ino() { stat -f %i "$1" 2>/dev/null; }

# Read: the seat's row, and the same move in the two files rescue.sh reads.
row=$(awk -v s="$seat" '$1==s' "$TABLE" 2>/dev/null)
[ -n "$row" ] && [ "$(printf '%s\n' "$row" | wc -l | tr -d ' ')" = 1 ] || no "$seat needs exactly one row in structure-moves"
read -r _ HARNESS TSESS SID FROM TO FINO EXTRA <<< "$row"
[ -n "$FINO" ] && [ -z "${EXTRA:-}" ] && [[ "$FINO" =~ ^[0-9]+$ ]] && [[ "$FROM" = /* ]] && [[ "$TO" = /* ]] || no "the row for $seat in structure-moves is not SEAT HARNESS TMUX-SESSION SESSION-ID FROM TO FROM-INODE"
[ "$HARNESS" = claude ] || no "$seat is a $HARNESS seat, and only a Claude carry is rehearsed"
[ "$(awk -v s="$seat" '$1==s {print $2 " " $3 " " $4}' "$MOVES")" = "$TO carry " ] || no "folder-moves needs exactly one line: $seat $TO carry"
[ "$(awk -v s="$seat" '$1==s {print $2}' "$PINS")" = "$SID" ] || no "session-pins needs $seat $SID"
if [ "$(ino "$FROM")" = "$FINO" ] && [ ! -e "$TO" ] && [ ! -L "$TO" ]; then at=before
elif [ -d "$TO" ] && [ ! -L "$TO" ] && [ "$(ino "$TO")" = "$FINO" ]; then at=after
else no "neither $FROM nor $TO is the folder read for $seat (inode $FINO): an unknown state. Bring this to zeo-rescue."; fi
D=$STATE/structure-move-$seat BACKUP=$STATE/claude-json.before-$seat
t=$PROJECTS/$(key "$FROM")/$SID.jsonl tn=$PROJECTS/$(key "$TO")/$SID.jsonl

case "$step" in
trust)
  if [ "$(jq -r --arg d "$TO" '.projects[$d].hasTrustDialogAccepted // false' "$CLAUDE_JSON")" = true ]; then echo "NOTHING TO ADD: $TO is already trusted; nothing was changed"; exit 0; fi
  # Every Claude process rewrites this file. Claude's lock is taken, but rehearsal/claude-lock.sh shows Claude writing through it, so the hash below is what guards the change.
  i=0; until mkdir "$CLAUDE_JSON.lock" 2>/dev/null; do i=$((i+1)); [ $i -lt 40 ] || { echo "FAILED, nothing was changed: Claude's config lock stayed held"; exit 1; }; perl -e 'select(undef,undef,undef,0.25)'; done
  tmp="$CLAUDE_JSON.zeo"; made=""
  drop() { rm -f "$tmp"; [ -z "$made" ] || rm -f "$BACKUP"; }
  trap 'drop; rmdir "$CLAUDE_JSON.lock" 2>/dev/null' EXIT
  # A writer that ignores the lock would be overwritten without a trace, so the file must be the same bytes at the end as at the start.
  was=$(sha "$CLAUDE_JSON"); [ -n "$was" ] || { echo "FAILED, nothing was changed: cannot read $CLAUDE_JSON"; exit 1; }
  cp -p "$CLAUDE_JSON" "$tmp" && jq --arg d "$TO" '.projects[$d] = ((.projects[$d] // {}) + {hasTrustDialogAccepted: true})' "$CLAUDE_JSON" > "$tmp" && jq -e --arg d "$TO" '.projects[$d].hasTrustDialogAccepted == true' "$tmp" >/dev/null || { echo "FAILED, nothing was changed"; exit 1; }
  # It holds account data, so it is 600 from its first byte, whatever the file's own mode is.
  if [ ! -e "$BACKUP" ]; then (umask 077; /bin/cat "$CLAUDE_JSON" > "$BACKUP") || { echo "FAILED, nothing was changed: no backup"; exit 1; }; made=1; fi
  chmod 600 "$BACKUP" && [ "$(stat -f %Lp "$BACKUP")" = 600 ] || { echo "FAILED, nothing was changed: the backup is not mode 600"; exit 1; }
  if [ "$(sha "$CLAUDE_JSON")" != "$was" ]; then echo "REFUSED, nothing was changed: $CLAUDE_JSON changed while the lock was held, so a writer does not honour it. Bring this to zeo-rescue."; exit 2; fi
  mv -f "$tmp" "$CLAUDE_JSON" || { echo "FAILED, nothing was changed"; exit 1; }
  made=""
  echo "ADDED: $TO is trusted, before the folder is there; backup at $BACKUP, mode 600. Tell zeo-rescue: done."; exit 0;;
first)
  # Once: after the move the seat reads as right, so only this mark tells a move done from one still to run.
  [ ! -f "$D/first.done" ] || { echo "ALREADY DONE: $seat moved to $TO and its note arrived ($(cat "$D/first.done")). Nothing was run."; exit 0; }
  v=$("$CLAUDE_BIN" --version 2>/dev/null | awk 'NR==1 {print $1}'); echo "the Claude that will run: ${v:-unknown}; rehearsed on $REHEARSED"
  [ "$v" = "$REHEARSED" ] || no "Claude is ${v:-unknown} and the rehearsal ran on $REHEARSED. Bring this to zeo-rescue."
  [ -f "$t" ] || t=$tn # a run stopped after the project's rename
  [ -f "$t" ] || { echo "NOT READY, nothing was run: no transcript for $seat under either folder"; exit 2; }
  ! LC_ALL=C grep -qF -e "$PROOF" "$t" || no "the note's words are already in $t, so the proof could not tell this run's from an earlier one. Bring this to zeo-rescue."
  plan=$(./rescue.sh --reseat --relaunch --harness claude --seat "$seat" 2>&1)
  w=$(grep 'a turn is in progress' <<< "$plan")
  [ -z "$w" ] || { echo "BUSY, nothing was run. Try again when it is idle:"; echo "$w"; exit 2; }
  grep -q "^RESEAT $seat: claude $SID .* in $TSESS\$" <<< "$plan" && grep -qF "MOVE $seat: from $FROM to $TO" <<< "$plan" || { echo "REFUSED, nothing was run: the plan does not move $seat from $FROM to $TO:"; printf '%s\n' "$plan"; exit 2; }
  (umask 077; mkdir -p "$D") || { echo "FAILED, nothing was run: cannot make $D"; exit 1; }
  note=$D/note.txt
  sed -e "s#{FROM}#$FROM#g" -e "s#{TO}#$TO#g" -e "s#{OLDMEM}#$PROJECTS/$(key "$FROM")/memory/#g" -e "s#{NEWMEM}#$PROJECTS/$(key "$TO")/memory/#g" "$TEMPLATE" > "$note" \
    && LC_ALL=C grep -qF -e "$PROOF" "$note" && ! grep -q '{[A-Z]*}' "$note" || { echo "FAILED, nothing was run: the note did not render"; exit 1; }
  echo "the note, from $(basename "$TEMPLATE"): $(sha "$note")"
  b=$(stat -f %z "$t")
  { echo "claude $v"; make reseat ARGS="--relaunch --harness claude --seat $seat --note-file $note" && make check ARGS="--seat $seat"; }; rc=$?
  [ "$rc" -eq 0 ] || { echo "STOPPED: the move or its check failed; the note's delivery is not proved. Bring this to zeo-rescue."; exit 1; }
  i=0; until [ "$(tail -c +$((b+1)) "$tn" 2>/dev/null | LC_ALL=C grep -cF -e "$PROOF")" -ge 1 ]; do
    i=$((i+1)); [ $i -lt "$TRIES" ] || { echo "NOT DELIVERED: the note's words are not in $tn after the restart. Bring this to zeo-rescue."; exit 1; }; perl -e 'select(undef,undef,undef,1)'; done
  date -u +%Y-%m-%dT%H:%M:%SZ > "$D/first.done"
  echo "NOTE DELIVERED $seat: its words are in session $SID under $TO, after byte $b; a second run says ALREADY DONE. Tell zeo-rescue: done.";;
clear)
  [ "$at" = after ] || { echo "OUT OF ORDER, nothing was deleted: $seat has not moved to $TO yet."; exit 2; }
  ./rescue.sh --check --seat "$seat" 2>&1 | grep "^OK $seat " >/dev/null || { echo "OUT OF ORDER, nothing was deleted: $seat is not right yet."; exit 2; }
  [ -e "$BACKUP" ] || { echo "NOTHING TO DELETE: there is no backup"; exit 0; }
  rm -f "$BACKUP" && [ ! -e "$BACKUP" ] || { echo "FAILED: $BACKUP is still there"; exit 1; }
  echo "DELETED: the backup of $CLAUDE_JSON is gone. Tell zeo-rescue: done."; exit 0;;
esac
