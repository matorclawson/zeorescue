#!/bin/bash
# The operator's steps for the reseat of 2026-11-05: one short hash-pinned line runs each. See STATE.md for the lines and what to expect.
# It refuses in plain words on the wrong machine or account, on any file that differs from what the Architect read, and out of order.
# Results go to ~/.local/state/zeo-rescue, which the rescue seat reads, so the operator only has to say done.
#
#   reseat-lines.sh verify        checks place and pins; starts nothing
#   reseat-lines.sh zeoarchitect  resumes that dead seat with its own note; cuts no live work
#   reseat-lines.sh proof         restarts one Codex seat beside the daemon
#   reseat-lines.sh all           restarts every other seat, about 18 minutes
#   reseat-lines.sh lic           restarts dt-brandedimage-maintainer alone, to test the -lic launcher; refuses while it is working
#   reseat-lines.sh trust        adds the trust entries the folders in folder-moves need; starts nothing
#   reseat-lines.sh codex-first  restarts the first seat in folder-moves alone, in its new folder; needs .zshenv changed first
#   reseat-lines.sh codex-rest   restarts every other Codex seat that needs it, about 12 minutes; needs the first seat right
#   reseat-lines.sh claude-trust adds the Claude trust entry for the seat moving, under Claude's own config lock; starts nothing
#   reseat-lines.sh claude-first restarts that one Claude seat in its new folder; refuses while it is working
#   reseat-lines.sh claude-back  puts its project back under the old folder; only with the seat stopped and its line out of folder-moves
set -uo pipefail
WANT=rodbot@Mac-mini
BEFORE=202611050511
NOTE=notes/reseat-20261105.txt
PROOF_SEAT=dreamhuggers-expenses-maintainer
LIC_SEAT=dt-brandedimage-maintainer
LIC_NOTE=notes/lic-test-20261106.txt
CODEX_NOTE=notes/codex-relaunch-20261106.txt
MOVE_SEATS="zeoapp rasa ducktyper profrod zeo-rt"
CLAUDE_SEAT=zeocreator
CLAUDE_OLD=/Volumes/AIPEMedia1/code/zeroemployeeorg/zeocreator
CLAUDE_NEW=/Volumes/AIPEMedia1/code/ducktyper-ai/dt-creator/main
CLAUDE_NOTE=notes/claude-move-20261106.txt
CLAUDE_JSON=${ZEO_RESCUE_CLAUDE_JSON:-$HOME/.claude.json}
PROJECTS=${ZEO_RESCUE_PROJECTS:-$HOME/.claude/projects}
CODEX_CONFIG=${ZEO_RESCUE_CODEX_CONFIG:-$HOME/.codex/config.toml}
HERE=$(cd "$(dirname "$0")" && pwd -P)
TMUX_BIN=${ZEO_RESCUE_TMUX:-/opt/homebrew/bin/tmux}
STATE=${ZEO_RESCUE_STATE:-$HOME/.local/state/zeo-rescue}
step=${1:-}
case "$step" in verify|zeoarchitect|proof|all|lic|trust|codex-first|codex-rest|claude-trust|claude-first|claude-back) ;; *) echo "usage: reseat-lines.sh verify|zeoarchitect|proof|all|lic|trust|codex-first|codex-rest|claude-trust|claude-first|claude-back; nothing was run"; exit 2;; esac
place="$(id -un)@$(hostname -s)"
[ "$place" = "$WANT" ] || { echo "WRONG PLACE, nothing was run: you are $place. Open the rodbot terminal on the Mac mini."; exit 2; }
cd "$HERE" || exit 2
bad=0
pin() { local h; h=$(/usr/bin/shasum -a 256 "$2" 2>/dev/null | /usr/bin/cut -d " " -f 1); if [ "$h" != "$1" ]; then echo "HASH MISMATCH, nothing was run: $2 is ${h:-missing}"; bad=1; fi; }
# PINS
pin 90161b7709acdda3bfc6388bebca4bfcd79f4b0453147ad462f64b92a249067c rescue.sh
pin 9350ecf29e596aa0c3e3c3cc0578780a954842d4f9020c0e351a3ac9cab51810 seat-exec.sh
pin 141ca64943f20b5991654b2f7f3f2301010737eaf5a280a71fde63e9bb80c871 Makefile
pin 889dcaf03b7e41aba917cb2b64dcbdb344d222d0e8b9ad1109e70fe24982eaaa session-pins
pin ead62f6999df0115aaf2d4e3b29595528bea57ad7f9972bab10a8f652a9e8029 notes/reseat-20261105.txt
pin 6d0b0155f9493f1e7909d03acec0133b0f11ea8aad2c35fd6c321e3d358c0c2b notes/zeoarchitect-resume.txt
pin be3c80bbd7d676af647df90b340eb973b3117b6146130eff954490edf379a4c2 notes/lic-test-20261106.txt
pin caee56c6aa567ca20d84679cb6ba969a66be37ba92b74472ed60e199cdb400de notes/codex-relaunch-20261106.txt
pin 2d1ecec3723664020891e0d5a6e3040f1ce6403d9fefc05c1b309ea1527150ee folder-moves
pin 13416446261a2d8ba553eee22762e9efa4fdadb879dba5acc3ad1f51a2d2336d zshenv-lines.sh
pin bcfaf71763f2184f40f09d7cf05b463366ceea40f547e094799df20a82bac0f0 notes/claude-move-20261106.txt
# END PINS
[ $bad -eq 0 ] || exit 2
moves_ready() { # every seat has its folder, and the folder exists; the folders are the Architect's to name
  local s n to
  for s in $MOVE_SEATS; do
    n=$(awk -v s="$s" '$1==s' folder-moves | wc -l | tr -d " "); to=$(awk -v s="$s" '$1==s {print $2}' folder-moves)
    [ "$n" = 1 ] && [ -d "$to" ] || { echo "NOT READY, nothing was run: folder-moves needs one existing folder for $s. The Architect names each one."; exit 2; }
  done
}
zshenv_first() { ./zshenv-lines.sh verify 2>/dev/null | /usr/bin/grep '^CHANGED' >/dev/null || { echo "OUT OF ORDER, nothing was run: the .zshenv line comes first."; exit 2; }; }
claude_ready() { # the seat has its line, and the folder is there: both are the Architect's
  [ "$(awk -v s="$CLAUDE_SEAT" '$1==s {print $2}' folder-moves)" = "$CLAUDE_NEW" ] && [ -d "$CLAUDE_NEW" ] || { echo "NOT READY, nothing was run: folder-moves needs $CLAUDE_SEAT $CLAUDE_NEW, and that folder must exist."; exit 2; }
}
not_busy() { # a restart cuts a turn in progress, so a turn on any seat this step would restart stops it; a quiet result is what can be seen
  local w; w=$(./rescue.sh --reseat --relaunch --harness codex --before $BEFORE "$@" 2>&1 | /usr/bin/grep 'a turn is in progress')
  [ -z "$w" ] || { echo "BUSY, nothing was run. Try again when these are idle:"; echo "$w"; exit 2; }
}
log=$STATE/reseat-lines-$step-$(date +%Y%m%d-%H%M%S).log
mkdir -p "$STATE"
case "$step" in
  verify) echo "verified: right place, every pin matches; nothing was run"; exit 0;;
  zeoarchitect)
    { make rescue ARGS="--seat zeoarchitect --note-file notes/zeoarchitect-resume.txt" && make check ARGS="--seat zeoarchitect"; } 2>&1 | tee "$log";;
  proof)
    { make reseat ARGS="--seat $PROOF_SEAT --before $BEFORE --note-file $NOTE" && make check ARGS="--seat $PROOF_SEAT"; } 2>&1 | tee "$log";;
  all)
    # A bulk reseat also resumes dead seats, so it would start zeoarchitect with the wrong note, without the one that says which mail is not its own.
    "$TMUX_BIN" -L zeo2 has-session -t "=zeoarchitect-maintainer" 2>/dev/null || { echo "OUT OF ORDER, nothing was run: zeoarchitect is not up. Run the zeoarchitect line first."; exit 2; }
    { make reseat ARGS="--before $BEFORE --note-file $NOTE" && make check; } 2>&1 | tee "$log";;
  lic)
    if "$TMUX_BIN" -L zeo2 capture-pane -p -t "=$LIC_SEAT:" 2>/dev/null | /usr/bin/grep 'esc to interrupt' >/dev/null; then echo "BUSY, nothing was run: $LIC_SEAT has a turn in progress. Try again when it is idle."; exit 2; fi
    # rescue started this seat, so a reseat would leave it alone while the pane keeps @zeo_rescue. The seat runs on until the reseat stops it.
    "$TMUX_BIN" -L zeo2 set-option -pu -t "=$LIC_SEAT:" @zeo_rescue || { echo "FAILED, nothing was run: could not clear the mark on $LIC_SEAT"; exit 1; }
    { make reseat ARGS="--seat $LIC_SEAT --before $BEFORE --note-file $LIC_NOTE" && make check ARGS="--seat $LIC_SEAT"; } 2>&1 | tee "$log";;
  trust)
    moves_ready; add=""
    while read -r seat to; do
      case "$seat" in ""|\#*) continue;; esac
      git -C "$to" rev-parse --git-dir >/dev/null 2>&1 || continue # a folder outside git never asks
      if /usr/bin/grep -qxF "[projects.\"$to\"]" "$CODEX_CONFIG"; then
        awk -v p="[projects.\"$to\"]" '$0==p {f=1; next} f && /^\[/ {exit} f && /^trust_level *= *"trusted"/ {t=1} END {exit !t}' "$CODEX_CONFIG" || { echo "REFUSED, nothing was changed: $to has an entry that is not trusted. Bring this to zeo-rescue."; exit 2; }
        continue
      fi
      add="$add$(printf '\n[projects."%s"]\ntrust_level = "trusted"\n.' "$to")"; add=${add%.}
      echo "TRUST $seat: $to"
    done < folder-moves
    [ -n "$add" ] || { echo "NOTHING TO ADD: every folder in git already has a trusted entry; nothing was changed"; exit 0; }
    [ -e "$STATE/codex-config.before-20261106" ] || cp -p "$CODEX_CONFIG" "$STATE/codex-config.before-20261106" || { echo "FAILED, nothing was changed: no backup"; exit 1; }
    tmp=$(mktemp "$CODEX_CONFIG.XXXXXX") && cp -p "$CODEX_CONFIG" "$tmp" && printf '%s' "$add" >> "$tmp" && mv -f "$tmp" "$CODEX_CONFIG" || { echo "FAILED, nothing was changed"; exit 1; }
    echo "ADDED: backup at $STATE/codex-config.before-20261106. Tell zeo-rescue: done."; exit 0;;
  claude-trust)
    claude_ready
    if [ "$(jq -r --arg d "$CLAUDE_NEW" '.projects[$d].hasTrustDialogAccepted // false' "$CLAUDE_JSON")" = true ]; then echo "NOTHING TO ADD: $CLAUDE_NEW is already trusted; nothing was changed"; exit 0; fi
    # Every Claude process rewrites this file, under this same lock, so the change goes in under it, and whole.
    i=0; until mkdir "$CLAUDE_JSON.lock" 2>/dev/null; do i=$((i+1)); [ $i -lt 40 ] || { echo "FAILED, nothing was changed: Claude's config lock stayed held"; exit 1; }; perl -e 'select(undef,undef,undef,0.25)'; done
    trap 'rmdir "$CLAUDE_JSON.lock" 2>/dev/null' EXIT
    [ -e "$STATE/claude-json.before-20261106" ] || cp -p "$CLAUDE_JSON" "$STATE/claude-json.before-20261106" || { echo "FAILED, nothing was changed: no backup"; exit 1; }
    tmp="$CLAUDE_JSON.zeo"; cp -p "$CLAUDE_JSON" "$tmp" && jq --arg d "$CLAUDE_NEW" '.projects[$d] = ((.projects[$d] // {}) + {hasTrustDialogAccepted: true})' "$CLAUDE_JSON" > "$tmp" && jq -e --arg d "$CLAUDE_NEW" '.projects[$d].hasTrustDialogAccepted == true' "$tmp" >/dev/null && mv -f "$tmp" "$CLAUDE_JSON" || { rm -f "$tmp"; echo "FAILED, nothing was changed"; exit 1; }
    echo "ADDED: $CLAUDE_NEW is trusted; backup at $STATE/claude-json.before-20261106. Tell zeo-rescue: done."; exit 0;;
  claude-first)
    claude_ready
    w=$(./rescue.sh --reseat --relaunch --harness claude --seat "$CLAUDE_SEAT" 2>&1 | /usr/bin/grep 'a turn is in progress')
    [ -z "$w" ] || { echo "BUSY, nothing was run. Try again when it is idle:"; echo "$w"; exit 2; }
    { make reseat ARGS="--relaunch --harness claude --seat $CLAUDE_SEAT --note-file $CLAUDE_NOTE" && make check ARGS="--seat $CLAUDE_SEAT"; } 2>&1 | tee "$log";;
  claude-back)
    [ -z "$(awk -v s="$CLAUDE_SEAT" '$1==s' folder-moves)" ] || { echo "REFUSED, nothing was changed: take $CLAUDE_SEAT out of folder-moves first."; exit 2; }
    sid=$(awk -v s="$CLAUDE_SEAT" '$1==s {print $2}' session-pins); from=$PROJECTS/$(printf %s "$CLAUDE_NEW" | LC_ALL=C sed 's/[^A-Za-z0-9]/-/g'); to=$PROJECTS/$(printf %s "$CLAUDE_OLD" | LC_ALL=C sed 's/[^A-Za-z0-9]/-/g')
    if ps -axo command= | /usr/bin/grep -F "$sid" | /usr/bin/grep -F -e "--resume" >/dev/null; then echo "REFUSED, nothing was changed: a process still holds session $sid."; exit 2; fi
    [ -f "$from/$sid.jsonl" ] && [ ! -e "$to" ] || { echo "REFUSED, nothing was changed: the project is not where a rollback expects it."; exit 2; }
    mv "$from" "$to" || { echo "FAILED: could not rename the project"; exit 1; }
    echo "PUT BACK: the project is under $CLAUDE_OLD again. Tell zeo-rescue: done."; exit 0;;
  codex-first)
    moves_ready; zshenv_first
    first=$(awk 'NF==2 && $1 !~ /^#/ {print $1; exit}' folder-moves); not_busy --seat "$first"
    { make reseat ARGS="--relaunch --harness codex --seat $first --before $BEFORE --note-file $CODEX_NOTE" && make check ARGS="--seat $first"; } 2>&1 | tee "$log";;
  codex-rest)
    moves_ready; zshenv_first
    first=$(awk 'NF==2 && $1 !~ /^#/ {print $1; exit}' folder-moves)
    ./rescue.sh --check --seat "$first" >/dev/null 2>&1 || { echo "OUT OF ORDER, nothing was run: $first is not right yet. Run the codex-first line first."; exit 2; }
    not_busy
    { make reseat ARGS="--relaunch --harness codex --before $BEFORE --note-file $CODEX_NOTE" && make check; } 2>&1 | tee "$log";;
esac
rc=${PIPESTATUS[0]}
echo "result kept in $log; exit $rc. Tell zeo-rescue: done."
exit "$rc"
