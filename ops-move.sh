#!/bin/bash
# zeo-rescue: the folder steps of an ops seat's move, on the Architect's order of 2026-11-07 21:12 (Do 322). reseat-lines.sh runs them; it pins this file.
#
#   ops-move.sh SEAT folder  makes the seat's new folder, empty, beside nothing else. The seat is not touched: it keeps working in its old folder.
#   ops-move.sh SEAT old     removes the old folder, once the seat runs in the new one. rmdir removes only an empty folder.
#
# Why not a rename: the old folder is empty, so there is nothing to move, and a rename under the live seat breaks its Bash tool until it restarts
# (2.1.318, rehearsed 8 Nov: 'Working directory ... was deleted; shell cwd recovered to' the home folder). So the seat is stopped and started
# in the new folder by claude-first, and only then does the old one go. Its project, with its memory, goes by rescue.sh's one rename at that restart.
#
# Each step reads everything first and refuses with "nothing was changed" unless the state is exactly the one read on 8 Nov. A second run says
# ALREADY DONE. Its marks go to $STATE/ops-move-SEAT (mode 700).
set -uo pipefail
case "${1:-}" in
  ducktyper-ops) # read 8 Nov 15:30: empty, not in git, no settings; its work is in /Volumes/ZeoWork/ducktyper-ops
    TSESS=dt-animationstudio-ops
    SESSION_ID=ca076ba8-7fee-46f0-853b-8182adc3c975
    OLD=/Volumes/AIPEMedia1/code/zeroemployeeorg/ducktyper-ops
    NEW=/Volumes/AIPEMedia1/code/ducktyper-ai/ducktyper-ops
    OLD_INODE=75427963;;
  *) echo "usage: ops-move.sh ducktyper-ops folder|old; nothing was run"; exit 2;;
esac
SEAT_ID=$1 step=${2:-}
case "$step" in folder|old) ;; *) echo "usage: ops-move.sh ducktyper-ops folder|old; nothing was run"; exit 2;; esac
SOCKET=zeo2
STATE=${STATE:-${ZEO_RESCUE_STATE:-$HOME/.local/state/zeo-rescue}}
PROJECTS=${ZEO_RESCUE_PROJECTS:-$HOME/.claude/projects}
TMUX_BIN=${ZEO_RESCUE_TMUX:-/opt/homebrew/bin/tmux}
LSOF=${ZEO_RESCUE_LSOF:-/usr/sbin/lsof}
PS_BIN=${ZEO_RESCUE_PS:-/bin/ps}
HERE=$(cd "$(dirname "$0")" && pwd -P)
MOVES=${ZEO_RESCUE_MOVES:-$HERE/folder-moves}
PINS=${ZEO_RESCUE_PINS:-$HERE/session-pins}
D=$STATE/ops-move-$SEAT_ID

no() { echo "REFUSED, nothing was changed: $*"; exit 2; }
fail() { echo "STOPPED at $1: $2. Nothing after it was done. Bring this to zeo-rescue."; exit 1; }
key() { printf %s "$1" | LC_ALL=C sed 's/[^A-Za-z0-9]/-/g'; }
ino() { stat -f %i "$1" 2>/dev/null; }
dev() { stat -f %d "$1" 2>/dev/null; }
empty() { [ -d "$1" ] && [ ! -L "$1" ] && [ -z "$(ls -A "$1" 2>/dev/null)" ]; }
in_git() { git -C "$1" rev-parse --git-dir >/dev/null 2>&1; }
cwds() { "$LSOF" -a -d cwd -Fpn 2>/dev/null | awk -v d="$1" '/^p/ {p=substr($0,2)} /^n/ && substr($0,2)==d {print p}' | sort -u | paste -sd' ' -; }
pane_pid() { "$TMUX_BIN" -L "$SOCKET" list-panes -t "=$TSESS" -F '#{pane_pid}' 2>/dev/null | head -1; }
P_OLD=$PROJECTS/$(key "$OLD") P_NEW=$PROJECTS/$(key "$NEW")

case "$step" in
folder)
  if [ -f "$D/folder.done" ] && empty "$NEW" && [ "$(ino "$NEW")" = "$(sed -n 's/^inode=//p' "$D/folder.done")" ]; then echo "ALREADY DONE: $NEW is there, empty, made by this step. Nothing was changed."; exit 0; fi
  # Read.
  [ "$(awk -v s="$SEAT_ID" '$1==s' "$MOVES" | wc -l | tr -d ' ')" = 1 ] && [ "$(awk -v s="$SEAT_ID" '$1==s {print $2}' "$MOVES")" = "$NEW" ] || no "folder-moves needs exactly one line $SEAT_ID $NEW; the Architect names the folder"
  [ "$(awk -v s="$SEAT_ID" '$1==s {print $2}' "$PINS")" = "$SESSION_ID" ] || no "session-pins needs $SEAT_ID $SESSION_ID"
  empty "$OLD" && [ "$(ino "$OLD")" = "$OLD_INODE" ] || no "$OLD is not the empty folder read on 8 Nov (inode $OLD_INODE)"
  ! in_git "$OLD" || no "$OLD is in git now"
  [ ! -e "$NEW" ] && [ ! -L "$NEW" ] || no "$NEW already exists"
  [ -d "$(dirname "$NEW")" ] && [ "$(dev "$(dirname "$NEW")")" = "$(dev "$OLD")" ] || no "$(dirname "$NEW") is missing or on another volume"
  ! in_git "$(dirname "$NEW")" || no "$(dirname "$NEW") is in git, so the new folder would be inside a repository"
  [ -f "$P_OLD/$SESSION_ID.jsonl" ] || no "the seat's transcript is not at $P_OLD"
  [ ! -e "$P_NEW" ] || no "$P_NEW already exists, and the restart's rename needs the name free"
  # Change.
  (umask 077; mkdir -p "$D") || fail "the state folder" "cannot make $D"
  mkdir -m 755 "$NEW" || fail "making $NEW" "mkdir failed"
  empty "$NEW" && [ "$(stat -f %Lp "$NEW")" = 755 ] || fail "making $NEW" "it is not an empty folder of mode 755"
  printf 'inode=%s\nmade=%s\n' "$(ino "$NEW")" "$(date -u +%Y-%m-%dT%H:%M:%SZ)" > "$D/folder.done" || fail "the mark" "cannot write $D/folder.done"
  echo "MADE: $NEW, empty, mode 755, on the same volume as $OLD. The seat was not touched and still works in $OLD."
  echo "FOLDER DONE: the new folder is ready for the trust entry and the restart. Tell zeo-rescue: done."; exit 0;;
old)
  if [ ! -e "$OLD" ] && [ -f "$D/old.done" ]; then echo "ALREADY DONE: $OLD was removed ($(cat "$D/old.done")). Nothing was changed."; exit 0; fi
  # Read: the seat runs in the new folder, and nothing else is in the old one.
  [ -f "$D/first.done" ] || { echo "OUT OF ORDER, nothing was changed: the restart in $NEW has not been proved ($D/first.done)."; exit 2; }
  p=$(pane_pid); [ -n "$p" ] || no "cannot read the seat's pane in $TSESS"
  case "$("$PS_BIN" -o command= -p "$p" 2>/dev/null)" in *"--resume $SESSION_ID"*) ;; *) no "the process in $TSESS (pid $p) does not resume $SESSION_ID";; esac
  case " $(cwds "$NEW") " in *" $p "*) ;; *) no "the seat (pid $p) is not working in $NEW";; esac
  [ -z "$(cwds "$OLD")" ] || no "a process still works in $OLD: pid $(cwds "$OLD")"
  [ -f "$P_NEW/$SESSION_ID.jsonl" ] && [ ! -e "$P_OLD" ] || no "the seat's project is not under $NEW alone"
  empty "$OLD" && [ "$(ino "$OLD")" = "$OLD_INODE" ] || no "$OLD is not the empty folder read on 8 Nov"
  # Change.
  rmdir "$OLD" || fail "removing $OLD" "rmdir failed"
  [ ! -e "$OLD" ] || fail "removing $OLD" "it is still there"
  date -u +%Y-%m-%dT%H:%M:%SZ > "$D/old.done"
  echo "REMOVED: $OLD, which was empty. The seat runs in $NEW. Tell zeo-rescue: done."; exit 0;;
esac
