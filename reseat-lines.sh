#!/bin/bash
# The operator's steps for the reseat of 2026-11-05: one short hash-pinned line runs each. See STATE.md for the lines and what to expect.
# It refuses in plain words on the wrong machine or account, on any file that differs from what the Architect read, and out of order.
# Results go to ~/.local/state/zeo-rescue, which the rescue seat reads, so the operator only has to say done.
#
#   reseat-lines.sh verify        checks place and pins; starts nothing
#   reseat-lines.sh zeoarchitect  resumes that dead seat with its own note; cuts no live work
#   reseat-lines.sh proof         restarts one Codex seat beside the daemon
#   reseat-lines.sh all           restarts every other seat, about 18 minutes
set -uo pipefail
WANT=rodbot@Mac-mini
BEFORE=202611050511
NOTE=notes/reseat-20261105.txt
PROOF_SEAT=dreamhuggers-expenses-maintainer
HERE=$(cd "$(dirname "$0")" && pwd -P)
TMUX_BIN=${ZEO_RESCUE_TMUX:-/opt/homebrew/bin/tmux}
STATE=${ZEO_RESCUE_STATE:-$HOME/.local/state/zeo-rescue}
step=${1:-}
case "$step" in verify|zeoarchitect|proof|all) ;; *) echo "usage: reseat-lines.sh verify|zeoarchitect|proof|all; nothing was run"; exit 2;; esac
place="$(id -un)@$(hostname -s)"
[ "$place" = "$WANT" ] || { echo "WRONG PLACE, nothing was run: you are $place. Open the rodbot terminal on the Mac mini."; exit 2; }
cd "$HERE" || exit 2
bad=0
pin() { local h; h=$(/usr/bin/shasum -a 256 "$2" 2>/dev/null | /usr/bin/cut -d " " -f 1); if [ "$h" != "$1" ]; then echo "HASH MISMATCH, nothing was run: $2 is ${h:-missing}"; bad=1; fi; }
# PINS
pin f4a3639a1d210624eb0a6d241e562ca04d1688b55f49d4fd1bc87b60a09cbe0f rescue.sh
pin 004d9255cd6475a3d252855ed00a46bdb5c3ee5fd8d79c64f7d03d2f1a48e159 seat-exec.sh
pin 141ca64943f20b5991654b2f7f3f2301010737eaf5a280a71fde63e9bb80c871 Makefile
pin 6d2ea61a03a67aa954709939aa6cd5e4e71d1286e72116114eb5c37b5967fda2 session-pins
pin ead62f6999df0115aaf2d4e3b29595528bea57ad7f9972bab10a8f652a9e8029 notes/reseat-20261105.txt
pin 6d0b0155f9493f1e7909d03acec0133b0f11ea8aad2c35fd6c321e3d358c0c2b notes/zeoarchitect-resume.txt
# END PINS
[ $bad -eq 0 ] || exit 2
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
esac
rc=${PIPESTATUS[0]}
echo "result kept in $log; exit $rc. Tell zeo-rescue: done."
exit "$rc"
