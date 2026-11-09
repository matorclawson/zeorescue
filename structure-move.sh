#!/bin/bash
# zeo-rescue: one seat's move into the one code structure, on the Architect's order of 8 Nov 22:10Z. reseat-lines.sh runs it, and pins it.
#
#   structure-move.sh SEAT trust   adds the Claude trust entry for the seat's new folder, under Claude's own config lock; starts nothing
#                                  and adds each allow, ask or deny rule on the old folder in its settings.local.json again for the new one
#   structure-move.sh SEAT first   restarts that one seat; rescue.sh carries its clone to the new folder while it is stopped, and moves its
#                                  project with its memory. Then it proves the note reached the transcript. It runs once, and refuses while
#                                  the seat is working, or on a Claude nobody rehearsed
#   structure-move.sh SEAT clear   deletes the backup of ~/.claude.json the trust step made, which holds account data; only once the seat checks right
#
# Each run moves exactly one seat: the one named, which must have exactly one row in structure-moves, the same move in folder-moves and its
# thread in session-pins. Every step reads first, and refuses unless the state is one of the two it knows: before (the clone at FROM with the
# inode the row records, nothing at TO) or after (that same folder at TO). Claude seats only: a Codex carry comes with its own rehearsal.
# A row may end in the sha256 of notes/structure-move-SEAT.txt: one line the seat's note adds, such as the rebuild of its own .venv after
# the carry. The file must be there with that hash, and with no row hash it must not be there at all.
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
USER_SETTINGS=${ZEO_RESCUE_USER_SETTINGS:-$HOME/.claude/settings.json}
# A guard names the old folder when its path, with its leading slashes made one, starts with FROM/, and does not already start with TO/.
GDEF='def names($f): type == "string" and ((capture("^[^()]+\\((?<a>.*)\\)$").a | sub("^/+"; "/") | startswith($f)) // false);
def guards($f; $t): [(.permissions.allow // [])[], (.permissions.ask // [])[], (.permissions.deny // [])[]] | map(select(names($f) and (names($t) | not)));
def carried($f; $t): (index($f)) as $i | .[:$i] + $t + .[$i + ($f | length):];'
GADD=' reduce ("allow", "ask", "deny") as $k (.; if (.permissions[$k] | type) == "array" then reduce (.permissions[$k][] | select(names($f) and (names($t) | not)) | carried($f; $t)) as $r (.; if (.permissions[$k] | index([$r])) != null then . else .permissions[$k] += [$r] end) else . end)'
GCOUNT='[(.permissions.allow // [])[], (.permissions.ask // [])[], (.permissions.deny // [])[]] | length'
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
read -r _ HARNESS TSESS SID FROM TO FINO ADDSHA EXTRA <<< "$row"
[ -n "$FINO" ] && [ -z "${EXTRA:-}" ] && [[ "$FINO" =~ ^[0-9]+$ ]] && [[ "$FROM" = /* ]] && [[ "$TO" = /* ]] && [[ -z "$ADDSHA" || "$ADDSHA" =~ ^[0-9a-f]{64}$ ]] || no "the row for $seat in structure-moves is not SEAT HARNESS TMUX-SESSION SESSION-ID FROM TO FROM-INODE [ADDITION-SHA256]"
# The seat's own addition to the note (a rebuild its folder needs, say) is pinned by its hash in the row, so the table pins it too.
ADD=$HERE/notes/structure-move-$seat.txt
if [ -n "$ADDSHA" ]; then
  [ "$(sha "$ADD")" = "$ADDSHA" ] || no "notes/structure-move-$seat.txt is not the addition its row pins ($ADDSHA)"
  [ "$(wc -l < "$ADD" | tr -d " ")" = 1 ] && ! LC_ALL=C grep -q "[{}\\]" "$ADD" || no "notes/structure-move-$seat.txt must be one line, with no brace or backslash"
elif [ -e "$ADD" ] || [ -L "$ADD" ]; then no "notes/structure-move-$seat.txt is there, but its row pins no addition"; fi
# A Codex row goes to its own step, which reads the row again; any other harness is refused.
[ "$HARNESS" != codex ] || exec ./structure-move-codex.sh "$seat" "$step"
[ "$HARNESS" = claude ] || no "$seat is a $HARNESS seat, and only Claude and Codex carries are rehearsed"
[ "$(awk -v s="$seat" '$1==s {print $2 " " $3 " " $4}' "$MOVES")" = "$TO carry " ] || no "folder-moves needs exactly one line: $seat $TO carry"
[ "$(awk -v s="$seat" '$1==s {print $2}' "$PINS")" = "$SID" ] || no "session-pins needs $seat $SID"
if [ "$(ino "$FROM")" = "$FINO" ] && [ ! -e "$TO" ] && [ ! -L "$TO" ]; then at=before
elif [ -d "$TO" ] && [ ! -L "$TO" ] && [ "$(ino "$TO")" = "$FINO" ]; then at=after
else no "neither $FROM nor $TO is the folder read for $seat (inode $FINO): an unknown state. Bring this to zeo-rescue."; fi
D=$STATE/structure-move-$seat BACKUP=$STATE/claude-json.before-$seat GBACKUP=$STATE/settings-local.before-$seat
t=$PROJECTS/$(key "$FROM")/$SID.jsonl tn=$PROJECTS/$(key "$TO")/$SID.jsonl

case "$step" in
trust)
  # The guards, read first: an allow, ask or deny rule on the old folder is added again for the new one, before the stop, so the move neither widens
  # nor drops a guard (rulings of 9 Nov 03:44Z, and Q5 of 04:19Z: allow, ask and deny alike, path for path). Rules are only added. Only the seat's own settings.local.json is changed, so a
  # guard on the old folder in its tracked settings.json or in the shared user settings is refused before anything is written.
  if [ "$at" = before ]; then own=$FROM/.claude; else own=$TO/.claude; fi
  sl=$own/settings.local.json
  for o in "$own/settings.json" "$USER_SETTINGS"; do
    [ ! -e "$o" ] || [ "$(jq --arg f "$FROM/" --arg t "$TO/" "$GDEF"' guards($f;$t) | length' "$o" 2>/dev/null)" = 0 ] || no "$o has an allow, ask or deny rule on $FROM/ (or cannot be read), and only the seat's settings.local.json is carried. Bring this to zeo-rescue."
  done
  [ ! -L "$sl" ] || no "$sl is a link, so it is not changed"
  [ ! -e "$sl" ] || jq -e 'type == "object"' "$sl" >/dev/null 2>&1 || no "$sl is not a JSON object"
  if [ "$(jq -r --arg d "$TO" '.projects[$d].hasTrustDialogAccepted // false' "$CLAUDE_JSON")" = true ]; then echo "NOTHING TO ADD: $TO is already trusted; nothing was changed"
  else ( # the trust entry, in its own shell, so its lock and its trap end with it
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
  echo "ADDED: $TO is trusted, before the folder is there; backup at $BACKUP, mode 600. Tell zeo-rescue: done."; exit 0 ) || exit $?
  fi
  [ -f "$sl" ] || { echo "GUARDS: there is no $sl, so no allow, ask or deny rule to carry"; exit 0; }
  gtmp=$sl.zeo; gmade=""
  trap 'rm -f "$gtmp"; [ -z "$gmade" ] || rm -f "$GBACKUP"' EXIT
  was=$(sha "$sl"); [ -n "$was" ] || { echo "FAILED, the guards were not added: cannot read $sl"; exit 1; }
  cp -p "$sl" "$gtmp" && jq --arg f "$FROM/" --arg t "$TO/" "$GDEF$GADD" "$sl" > "$gtmp" || { echo "FAILED, the guards were not added"; exit 1; }
  n=$(( $(jq "$GCOUNT" "$gtmp") - $(jq "$GCOUNT" "$sl") ))
  [ "$n" -gt 0 ] || { echo "GUARDS: none to add; every allow, ask or deny rule on $FROM/ in $sl stands for $TO/ too"; exit 0; }
  # Only added: everything else is as it was, each old list is the start of the new one, and carrying again would add nothing.
  jq -e --slurpfile o "$sl" --arg f "$FROM/" --arg t "$TO/" "$GDEF$GADD"' as $n | . as $d | $o[0] as $o | ($o | del(.permissions.allow, .permissions.ask, .permissions.deny)) == ($d | del(.permissions.allow, .permissions.ask, .permissions.deny))
    and all("allow", "ask", "deny"; . as $k | ($o.permissions[$k] // []) as $a | (($d.permissions[$k] // [])[:($a | length)]) == $a) and $n == $d' "$gtmp" >/dev/null 2>&1 \
    || { echo "FAILED, the guards were not added: the carried file is not the old one with rules only added"; exit 1; }
  if [ ! -e "$GBACKUP" ]; then (umask 077; /bin/cat "$sl" > "$GBACKUP") || { echo "FAILED, the guards were not added: no backup"; exit 1; }; gmade=1; fi
  chmod 600 "$GBACKUP" && [ "$(stat -f %Lp "$GBACKUP")" = 600 ] || { echo "FAILED, the guards were not added: the backup is not mode 600"; exit 1; }
  [ "$(sha "$sl")" = "$was" ] || { echo "REFUSED, the guards were not added: $sl changed while they were carried. Bring this to zeo-rescue."; exit 2; }
  mv -f "$gtmp" "$sl" || { echo "FAILED, the guards were not added"; exit 1; }
  gmade=""
  echo "GUARDS ADDED: $n allow, ask or deny rules on $FROM/ now stand for $TO/ too, in $sl; backup at $GBACKUP, mode 600. Tell zeo-rescue: done."; exit 0;;
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
  ! grep -q "^UNRESOLVED $seat: it is down, and a carry moves only a seat this run stops itself\$" <<< "$plan" || { echo "DOWN, nothing was run: $seat is not running, and a carry moves only a seat it stops itself. Bring this to zeo-rescue."; exit 2; }
  grep -q "^RESEAT $seat: claude $SID .* in $TSESS\$" <<< "$plan" && grep -qF "MOVE $seat: from $FROM to $TO" <<< "$plan" || { echo "REFUSED, nothing was run: the plan does not move $seat from $FROM to $TO:"; printf '%s\n' "$plan"; exit 2; }
  (umask 077; mkdir -p "$D") || { echo "FAILED, nothing was run: cannot make $D"; exit 1; }
  note=$D/note.txt
  { sed -e "s#{FROM}#$FROM#g" -e "s#{TO}#$TO#g" -e "s#{OLDMEM}#$PROJECTS/$(key "$FROM")/memory/#g" -e "s#{NEWMEM}#$PROJECTS/$(key "$TO")/memory/#g" "$TEMPLATE" | tr -d "\n"
    if [ -n "$ADDSHA" ]; then printf " "; tr -d "\n" < "$ADD"; fi; echo; } > "$note" \
    && LC_ALL=C grep -qF -e "$PROOF" "$note" && ! grep -q '{[A-Z]*}' "$note" || { echo "FAILED, nothing was run: the note did not render"; exit 1; }
  echo "the note, from $(basename "$TEMPLATE")${ADDSHA:+ and $(basename "$ADD")}: $(sha "$note")"
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
  [ -e "$BACKUP" ] || [ -e "$GBACKUP" ] || { echo "NOTHING TO DELETE: there is no backup"; exit 0; }
  rm -f "$BACKUP" "$GBACKUP" && [ ! -e "$BACKUP" ] && [ ! -e "$GBACKUP" ] || { echo "FAILED: a backup is still there"; exit 1; }
  echo "DELETED: the backup of $CLAUDE_JSON is gone, and any of the seat's settings.local.json. Tell zeo-rescue: done."; exit 0;;
esac
