#!/bin/bash
# zeo-rescue: one Codex seat's move into the one code structure. structure-move.sh hands a Codex row here; reseat-lines.sh pins both.
#
#   structure-move-codex.sh SEAT trust   adds [projects."TO"] trust_level = "trusted" to Codex's config, before the folder is there; starts nothing
#   structure-move-codex.sh SEAT first   restarts that one seat; rescue.sh carries its clone to the new folder while it is stopped and resumes the
#                                        same thread there with -C TO. Then it proves the note's words reached the seat's own rollout after the
#                                        restart, and that the thread recorded the new folder. It runs once, and refuses while the seat is working,
#                                        or on a Codex nobody rehearsed
#   structure-move-codex.sh SEAT clear   deletes the backup of the config the trust step made; only once the seat checks right
#
# The row, folder-moves, session-pins and the optional pinned addition are read exactly as structure-move.sh reads them, and the same two states
# are the only ones known: before (the clone at FROM with the row's inode, nothing at TO) or after (that same folder at TO).
# Codex has no lock on its config, and a running Codex may write it, so the file must be the same bytes at the end as at the start.
set -uo pipefail
HERE=$(cd "$(dirname "$0")" && pwd -P)
STATE=${STATE:-${ZEO_RESCUE_STATE:-$HOME/.local/state/zeo-rescue}}
CODEX_CONFIG=${ZEO_RESCUE_CODEX_CONFIG:-$HOME/.codex/config.toml}
CODEX_BIN=${ZEO_RESCUE_CODEX:-$HOME/.local/bin/codex}
CODEX_DB=${ZEO_RESCUE_CODEX_DB:-$HOME/.codex/state_5.sqlite}
SESSIONS=${ZEO_RESCUE_SESSIONS:-$HOME/.codex/sessions}
TABLE=${ZEO_RESCUE_TABLE:-$HERE/structure-moves}
MOVES=${ZEO_RESCUE_MOVES:-$HERE/folder-moves}
PINS=${ZEO_RESCUE_PINS:-$HERE/session-pins}
TEMPLATE=$HERE/notes/structure-move-codex.txt
PROOF="This is a planned move, not a fault: make nothing at the old path, and never create it again."
REHEARSED=0.164.0
TRIES=${ZEO_RESCUE_PROOF_TRIES:-60}
ID_RE='^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$'
seat=${1:-} step=${2:-}
case "$step" in trust|first|clear) ;; *) echo "usage: structure-move-codex.sh SEAT trust|first|clear; nothing was run"; exit 2;; esac
[[ "$seat" =~ ^[a-z0-9][a-z0-9-]{0,63}$ ]] || { echo "usage: structure-move-codex.sh SEAT trust|first|clear; nothing was run"; exit 2; }
cd "$HERE" || exit 2
no() { echo "REFUSED, nothing was changed: $*"; exit 2; }
sha() { /usr/bin/shasum -a 256 "$1" 2>/dev/null | cut -d " " -f 1; }
ino() { stat -f %i "$1" 2>/dev/null; }
db() { sqlite3 "file:$CODEX_DB?mode=ro" "$1" 2>/dev/null || sqlite3 "file:$CODEX_DB?mode=ro&immutable=1" "$1" 2>/dev/null; } # WAL: see thread_db in rescue.sh

# Read: the seat's row, and the same move in the two files rescue.sh reads.
row=$(awk -v s="$seat" '$1==s' "$TABLE" 2>/dev/null)
[ -n "$row" ] && [ "$(printf '%s\n' "$row" | wc -l | tr -d ' ')" = 1 ] || no "$seat needs exactly one row in structure-moves"
read -r _ HARNESS TSESS SID FROM TO FINO ADDSHA EXTRA <<< "$row"
[ -n "$FINO" ] && [ -z "${EXTRA:-}" ] && [[ "$FINO" =~ ^[0-9]+$ ]] && [[ "$FROM" = /* ]] && [[ "$TO" = /* ]] && [[ "$SID" =~ $ID_RE ]] && [[ -z "$ADDSHA" || "$ADDSHA" =~ ^[0-9a-f]{64}$ ]] || no "the row for $seat in structure-moves is not SEAT HARNESS TMUX-SESSION SESSION-ID FROM TO FROM-INODE [ADDITION-SHA256]"
[ "$HARNESS" = codex ] || no "$seat is a $HARNESS seat, and this step moves only Codex seats"
ADD=$HERE/notes/structure-move-$seat.txt
if [ -n "$ADDSHA" ]; then
  [ "$(sha "$ADD")" = "$ADDSHA" ] || no "notes/structure-move-$seat.txt is not the addition its row pins ($ADDSHA)"
  [ "$(wc -l < "$ADD" | tr -d " ")" = 1 ] && ! LC_ALL=C grep -q "[{}\\]" "$ADD" || no "notes/structure-move-$seat.txt must be one line, with no brace or backslash"
elif [ -e "$ADD" ] || [ -L "$ADD" ]; then no "notes/structure-move-$seat.txt is there, but its row pins no addition"; fi
[ "$(awk -v s="$seat" '$1==s {print $2 " " $3 " " $4}' "$MOVES")" = "$TO carry " ] || no "folder-moves needs exactly one line: $seat $TO carry"
[ "$(awk -v s="$seat" '$1==s {print $2}' "$PINS")" = "$SID" ] || no "session-pins needs $seat $SID"
if [ "$(ino "$FROM")" = "$FINO" ] && [ ! -e "$TO" ] && [ ! -L "$TO" ]; then at=before
elif [ -d "$TO" ] && [ ! -L "$TO" ] && [ "$(ino "$TO")" = "$FINO" ]; then at=after
else no "neither $FROM nor $TO is the folder read for $seat (inode $FINO): an unknown state. Bring this to zeo-rescue."; fi
D=$STATE/structure-move-$seat BACKUP=$STATE/codex-config.before-$seat
entry="[projects.\"$TO\"]"

case "$step" in
trust)
  if /usr/bin/grep -qxF "$entry" "$CODEX_CONFIG"; then
    awk -v p="$entry" '$0==p {f=1; next} f && /^\[/ {exit} f && /^trust_level *= *"trusted"/ {t=1} END {exit !t}' "$CODEX_CONFIG" \
      || no "$TO has an entry in $CODEX_CONFIG that is not trusted. Bring this to zeo-rescue."
    echo "NOTHING TO ADD: $TO is already trusted; nothing was changed"; exit 0
  fi
  tmp="$CODEX_CONFIG.zeo"; made=""
  trap 'rm -f "$tmp"; [ -z "$made" ] || rm -f "$BACKUP"' EXIT
  was=$(sha "$CODEX_CONFIG"); [ -n "$was" ] || { echo "FAILED, nothing was changed: cannot read $CODEX_CONFIG"; exit 1; }
  # The entry starts with a newline, so a file that does not end in one keeps its last line whole.
  cp -p "$CODEX_CONFIG" "$tmp" && printf '\n%s\ntrust_level = "trusted"\n' "$entry" >> "$tmp" || { echo "FAILED, nothing was changed"; exit 1; }
  [ "$(/usr/bin/grep -cxF "$entry" "$tmp")" = 1 ] && cmp -s <(head -c "$(stat -f %z "$CODEX_CONFIG")" "$tmp") "$CODEX_CONFIG" || { echo "FAILED, nothing was changed: the new file is not the old one with the entry added"; exit 1; }
  if [ ! -e "$BACKUP" ]; then (umask 077; /bin/cat "$CODEX_CONFIG" > "$BACKUP") || { echo "FAILED, nothing was changed: no backup"; exit 1; }; made=1; fi
  chmod 600 "$BACKUP" && [ "$(stat -f %Lp "$BACKUP")" = 600 ] || { echo "FAILED, nothing was changed: the backup is not mode 600"; exit 1; }
  if [ "$(sha "$CODEX_CONFIG")" != "$was" ]; then echo "REFUSED, nothing was changed: $CODEX_CONFIG changed while the entry was added. Bring this to zeo-rescue."; exit 2; fi
  mv -f "$tmp" "$CODEX_CONFIG" || { echo "FAILED, nothing was changed"; exit 1; }
  made=""
  echo "ADDED: $TO is trusted in $CODEX_CONFIG, before the folder is there; backup at $BACKUP, mode 600. Tell zeo-rescue: done."; exit 0;;
first)
  # Once: after the move the seat reads as right, so only this mark tells a move done from one still to run.
  [ ! -f "$D/first.done" ] || { echo "ALREADY DONE: $seat moved to $TO and its note arrived ($(cat "$D/first.done")). Nothing was run."; exit 0; }
  v=$("$CODEX_BIN" --version 2>/dev/null | awk 'NR==1 {print $2}'); echo "the Codex that will run: ${v:-unknown}; rehearsed on $REHEARSED"
  [ "$v" = "$REHEARSED" ] || no "Codex is ${v:-unknown} and the rehearsal ran on $REHEARSED. Bring this to zeo-rescue."
  roll=$(db "select rollout_path from threads where id = '$SID';")
  [ -n "$roll" ] && [ -f "$roll" ] || { echo "NOT READY, nothing was run: no rollout for thread $SID"; exit 2; }
  [ "$(find "$SESSIONS" -name "*$SID*" 2>/dev/null | wc -l | tr -d ' ')" = 1 ] || no "more or fewer than one rollout carries thread $SID. Bring this to zeo-rescue."
  ! LC_ALL=C grep -qF -e "$PROOF" "$roll" || no "the note's words are already in $roll, so the proof could not tell this run's from an earlier one. Bring this to zeo-rescue."
  plan=$(./rescue.sh --reseat --relaunch --harness codex --seat "$seat" 2>&1)
  w=$(grep 'a turn is in progress' <<< "$plan")
  [ -z "$w" ] || { echo "BUSY, nothing was run. Try again when it is idle:"; echo "$w"; exit 2; }
  grep -q "^RESEAT $seat: codex $SID .* in $TSESS\$" <<< "$plan" && grep -qF "MOVE $seat: from $FROM to $TO" <<< "$plan" || { echo "REFUSED, nothing was run: the plan does not move $seat from $FROM to $TO:"; printf '%s\n' "$plan"; exit 2; }
  (umask 077; mkdir -p "$D") || { echo "FAILED, nothing was run: cannot make $D"; exit 1; }
  note=$D/note.txt
  { sed -e "s#{FROM}#$FROM#g" -e "s#{TO}#$TO#g" "$TEMPLATE" | tr -d "\n"
    if [ -n "$ADDSHA" ]; then printf " "; tr -d "\n" < "$ADD"; fi; echo; } > "$note" \
    && LC_ALL=C grep -qF -e "$PROOF" "$note" && ! grep -q '{[A-Z]*}' "$note" || { echo "FAILED, nothing was run: the note did not render"; exit 1; }
  echo "the note, from $(basename "$TEMPLATE")${ADDSHA:+ and $(basename "$ADD")}: $(sha "$note")"
  b=$(stat -f %z "$roll")
  { echo "codex $v"; make reseat ARGS="--relaunch --harness codex --seat $seat --note-file $note" && make check ARGS="--seat $seat"; }; rc=$?
  [ "$rc" -eq 0 ] || { echo "STOPPED: the move or its check failed; the note's delivery is not proved. Bring this to zeo-rescue."; exit 1; }
  # The proof is in the seat's own rollout, after this run's first byte: the note's words, and a turn whose folder is the new one.
  i=0; until [ "$(tail -c +$((b+1)) "$roll" 2>/dev/null | LC_ALL=C grep -cF -e "$PROOF")" -ge 1 ] && tail -c +$((b+1)) "$roll" 2>/dev/null | LC_ALL=C grep -F "\"cwd\":\"$TO\"" >/dev/null; do
    i=$((i+1)); [ $i -lt "$TRIES" ] || { echo "NOT DELIVERED: the note's words and the new folder are not both in $roll after the restart. Bring this to zeo-rescue."; exit 1; }; perl -e 'select(undef,undef,undef,1)'; done
  rec=$(db "select cwd from threads where id = '$SID';")
  date -u +%Y-%m-%dT%H:%M:%SZ > "$D/first.done"
  echo "NOTE DELIVERED $seat: its words and the folder $TO are in thread $SID's rollout after byte $b; Codex's thread record says ${rec:-nothing}; a second run says ALREADY DONE. Tell zeo-rescue: done.";;
clear)
  [ "$at" = after ] || { echo "OUT OF ORDER, nothing was deleted: $seat has not moved to $TO yet."; exit 2; }
  ./rescue.sh --check --seat "$seat" 2>&1 | grep "^OK $seat " >/dev/null || { echo "OUT OF ORDER, nothing was deleted: $seat is not right yet."; exit 2; }
  [ -e "$BACKUP" ] || { echo "NOTHING TO DELETE: there is no backup"; exit 0; }
  rm -f "$BACKUP" && [ ! -e "$BACKUP" ] || { echo "FAILED: $BACKUP is still there"; exit 1; }
  echo "DELETED: the backup of $CODEX_CONFIG is gone. Tell zeo-rescue: done."; exit 0;;
esac
