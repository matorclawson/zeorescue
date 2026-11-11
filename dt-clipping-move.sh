#!/bin/bash
# dt-clipping-move.sh trust|first|clear: dt-clipping-maintainer moves from its tldw clone on ZeoWork into its worktree of dt-clipping, on the
# Architect's answer of 11 Nov 03:55Z. It is the plain Codex move: nothing is carried across the volumes. rescue.sh restarts the seat
# with -C the new folder, resumes the same thread (session-pins names it), and proves the move; the tldw clone is left as it is.
# It runs from its own checkout of this branch, with its own move and pin files (dt-clipping-move.moves, .pins) and note; bootstrap is not moved.
#
#   trust  adds trusted entries to ~/.codex/config.toml for the worktree and for dt-clipping/main, the repository Codex keys a linked worktree's
#          trust to, each only if it is missing, after a backup. It refuses an entry that is there and not trusted. Starts nothing.
#   first  restarts that one seat into the worktree, then checks it and waits for its model's answer. It refuses while the seat has a turn in
#          progress, before trust, or if the worktree is not the normalised one. A seat already there reads ALREADY DONE.
#   clear  deletes the trust step's backup, once the seat checks right.
set -uo pipefail
HERE=$(cd "$(dirname "$0")" && pwd -P)
cd "$HERE" || exit 1
STATE=${ZEO_RESCUE_STATE:-$HOME/.local/state/zeo-rescue}
CODEX_CONFIG=${ZEO_RESCUE_CODEX_CONFIG:-$HOME/.codex/config.toml}
SEAT=dt-clipping-maintainer
M=${ZEO_MOVE_MAIN:-/Volumes/AIPEMedia1/code/ducktyper-ai/dt-clipping/main}
W=${ZEO_MOVE_TO:-/Volumes/AIPEMedia1/code/ducktyper-ai/dt-clipping/worktrees/dt-clipping-maintainer}
BRANCH=$SEAT/home
NOTE=notes/dt-clipping-move-20261111.txt
BACKUP=$STATE/codex-config.before-dt-clipping-move
# The move and its pin are in their own files, so bootstrap's folder-moves and session-pins, and the pins on them, stay as they are.
export ZEO_RESCUE_MOVES=$HERE/dt-clipping-move.moves ZEO_RESCUE_PINS=$HERE/dt-clipping-move.pins
WAIT=${ZEO_RESCUE_ANSWER_WAIT:-600}
step=${1:-}
case "$step" in trust|first|clear) ;; *) echo "usage: dt-clipping-move.sh trust|first|clear; nothing was run"; exit 2;; esac
mkdir -p "$STATE" || exit 1
sha() { /usr/bin/shasum -a 256 "$1" | cut -d ' ' -f 1; }
has_entry() { /usr/bin/grep -qxF "[projects.\"$1\"]" "$CODEX_CONFIG"; }
trusted() { awk -v p="[projects.\"$1\"]" '$0==p {f=1; next} f && /^\[/ {exit} f && /^trust_level *= *"trusted"/ {t=1} END {exit !t}' "$CODEX_CONFIG"; }
the_worktree() { # the folder normalise-clone.sh made, and nothing else
  [ -d "$W" ] && [ ! -L "$W" ] || { WHY="$W is not a folder"; return 1; }
  [ "$(git -C "$W" rev-parse --show-toplevel 2>/dev/null)" = "$W" ] || { WHY="$W is not the top of a git worktree"; return 1; }
  [ "$(git -C "$W" rev-parse --path-format=absolute --git-common-dir 2>/dev/null)" = "$M/.git" ] || { WHY="$W is not a worktree of $M"; return 1; }
  [ "$(git -C "$W" symbolic-ref -q --short HEAD)" = "$BRANCH" ] || { WHY="$W is not on $BRANCH"; return 1; }
}

case "$step" in
  trust)
    WHY=""; the_worktree || { echo "REFUSED, nothing was changed: $WHY. Run the normalise line first."; exit 2; }
    add=""
    for d in "$W" "$M"; do
      if has_entry "$d"; then trusted "$d" || { echo "REFUSED, nothing was changed: $d has an entry that is not trusted. Bring this to zeo-rescue."; exit 2; }; echo "ALREADY TRUSTED: $d"; continue; fi
      add="$add$(printf '\n[projects."%s"]\ntrust_level = "trusted"\n.' "$d")"; add=${add%.}
      echo "TRUST $SEAT: $d"
    done
    [ -n "$add" ] || { echo "NOTHING TO ADD: both folders are trusted; nothing was changed"; exit 0; }
    was=$(sha "$CODEX_CONFIG") || { echo "FAILED, nothing was changed: $CODEX_CONFIG cannot be read"; exit 1; }
    [ -e "$BACKUP" ] || { cp -p "$CODEX_CONFIG" "$BACKUP" && chmod 600 "$BACKUP"; } || { echo "FAILED, nothing was changed: no backup"; exit 1; }
    tmp=$(mktemp "$CODEX_CONFIG.XXXXXX") && cp -p "$CODEX_CONFIG" "$tmp" && printf '%s' "$add" >> "$tmp" || { rm -f "${tmp:-}"; echo "FAILED, nothing was changed"; exit 1; }
    # Codex has no lock on its config: if a running Codex wrote it since it was read, nothing is replaced.
    [ "$(sha "$CODEX_CONFIG")" = "$was" ] || { rm -f "$tmp"; echo "FAILED, nothing was changed: $CODEX_CONFIG changed while this ran; run the line again"; exit 1; }
    mv -f "$tmp" "$CODEX_CONFIG" || { rm -f "$tmp"; echo "FAILED, nothing was changed"; exit 1; }
    for d in "$W" "$M"; do trusted "$d" || { echo "FAILED: $d is not trusted after the edit; the backup is $BACKUP. Bring this to zeo-rescue."; exit 1; }; done
    echo "ADDED: both trusted; backup at $BACKUP"; exit 0;;
  first)
    WHY=""; the_worktree || { echo "REFUSED, nothing was run: $WHY"; exit 2; }
    for d in "$W" "$M"; do trusted "$d" || { echo "REFUSED, nothing was run: $d has no trusted entry; run the trust step first"; exit 2; }; done
    plan=$(./rescue.sh --reseat --relaunch --harness codex --seat "$SEAT" 2>&1)
    if printf '%s\n' "$plan" | /usr/bin/grep -xF "OK $SEAT: started by rescue, right already" >/dev/null; then echo "ALREADY DONE: $SEAT works in $W"; exit 0; fi
    w=$(printf '%s\n' "$plan" | /usr/bin/grep "^WORK $SEAT: ")
    [ -z "$w" ] || { echo "BUSY, nothing was run. Run the line again when it is idle:"; echo "$w"; exit 2; }
    printf '%s\n' "$plan" | /usr/bin/grep "^RESEAT $SEAT: .* in " >/dev/null && printf '%s\n' "$plan" | /usr/bin/grep "^MOVE $SEAT: .* to $W" >/dev/null \
      || { echo "REFUSED, nothing was run: the plan is not this one move:"; printf '%s\n' "$plan" | /usr/bin/grep -E "^(RESEAT|MOVE|UNRESOLVED|OK|DOWN|WORK) "; exit 2; }
    log=$STATE/dt-clipping-move-$(date -u +%Y%m%d-%H%M%S).log
    { ./rescue.sh --reseat --relaunch --apply --harness codex --seat "$SEAT" --note-file "$NOTE" && ./rescue.sh --check --seat "$SEAT" && ./model-answered.sh "$log" "$WAIT"; } 2>&1 | tee "$log"
    exit "${PIPESTATUS[0]}";;
  clear)
    ./rescue.sh --check --seat "$SEAT" | /usr/bin/grep -xF "check: ok 1, wrong 0" >/dev/null || { echo "REFUSED, nothing was changed: $SEAT does not check right yet"; exit 2; }
    [ -e "$BACKUP" ] || { echo "NOTHING TO CLEAR: no backup"; exit 0; }
    rm -f "$BACKUP" && echo "CLEARED: $BACKUP deleted" || { echo "FAILED to delete $BACKUP"; exit 1; };;
esac
