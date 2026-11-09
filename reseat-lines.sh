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
#   reseat-lines.sh claude-trust adds the Claude trust entry for the seat moving (ducktyper-ops; zbs moved on 8 Nov), under Claude's own config lock; starts nothing
#   reseat-lines.sh codex-untrust removes the two Codex trust entries for folders that left rodriveracom, only from the exact file the Architect read; starts nothing
#   reseat-lines.sh zbs-repo     makes the zbs seat's folder its own repository and sets the 24 Sep checkout aside; refuses while the seat is working
#   reseat-lines.sh zbs-folder   moves that folder whole to its new path, with its memory, its one allow rule and the 20 guard rules mirrored; after zbs-repo
#   reseat-lines.sh zbs-folder-abs  the same, with the 20 mirrored rules as absolute paths, the form that takes effect; the Architect picks one of the two
#   reseat-lines.sh ops-folder   makes the ops seat's new folder, empty; the seat is not touched and keeps working in its old one
#   reseat-lines.sh claude-first restarts that one Claude seat in its new folder; says which Claude will run; proves its note reached its transcript, and runs once;
#                                refuses while it is working, or on a Claude nobody rehearsed
#   reseat-lines.sh ops-old      removes the ops seat's old folder, which is empty, once the seat runs in the new one
#   reseat-lines.sh zeocreator-note  restarts zeocreator in place with a note naming its real memory folder; restarts even when it reads as right, proves the note reached its transcript, and runs once; refuses while it is working, or on a Claude nobody rehearsed
#   reseat-lines.sh claude-clear deletes the backup of ~/.claude.json, which holds account data; only once the seat checks right
#   reseat-lines.sh claude-back  puts its project back under the old folder; only with the seat stopped, its line out of folder-moves and that folder back
#   reseat-lines.sh structure-trust SEAT  adds the trust entry for that seat's new folder in the one code structure (structure-moves); starts nothing
#                                        (a Codex row goes to structure-move-codex.sh: Codex's config, its rollout as the proof)
#   reseat-lines.sh structure-first SEAT  restarts that one seat, which carries its clone to the new folder while it is stopped; proves its note
#                                arrived, and runs once; refuses while it is working, or on a Claude nobody rehearsed (structure-move.sh)
#   reseat-lines.sh structure-clear SEAT  deletes the backup its trust step made; only once the seat checks right
set -uo pipefail
WANT=rodbot@Mac-mini
BEFORE=202611050511
NOTE=notes/reseat-20261105.txt
PROOF_SEAT=dreamhuggers-expenses-maintainer
LIC_SEAT=dt-brandedimage-maintainer
LIC_NOTE=notes/lic-test-20261106.txt
CODEX_NOTE=notes/codex-relaunch-20261106.txt
MOVE_SEATS="zeoapp rasa ducktyper profrod zeo-rt"
# The Claude seat moving now: ducktyper-ops, the first ops seat, on the Architect's order of 2026-11-07 21:12 (zbs moved on 8 Nov; its steps
# above are kept, and say ALREADY DONE). Its folder steps are ops-move.sh.
CLAUDE_SEAT=ducktyper-ops
CLAUDE_OLD=/Volumes/AIPEMedia1/code/zeroemployeeorg/ducktyper-ops
CLAUDE_NEW=/Volumes/AIPEMedia1/code/ducktyper-ai/ducktyper-ops
CLAUDE_NOTE=notes/claude-move-ducktyper-ops-20261108.txt
CLAUDE_PROOF="Read and write memories only in the new memory folder, never in the old one, and never create the old one."
# zeocreator, on the Architect's word of 2026-11-08 03:09: its saved prompt names a memory folder that went on 6 Nov.
ZEOCREATOR_NOTE=notes/zeocreator-memory-20261108.txt
ZEOCREATOR_PROOF="Read and write memories only there, never in the old folder, and never create it."
ZEOCREATOR_TRIES=${ZEO_RESCUE_PROOF_TRIES:-60}
CLAUDE_REHEARSED=2.1.319
CLAUDE_BIN=${ZEO_RESCUE_CLAUDE:-$HOME/.local/bin/claude}
CLAUDE_JSON=${ZEO_RESCUE_CLAUDE_JSON:-$HOME/.claude.json}
PROJECTS=${ZEO_RESCUE_PROJECTS:-$HOME/.claude/projects}
CODEX_CONFIG=${ZEO_RESCUE_CODEX_CONFIG:-$HOME/.codex/config.toml}
UNTRUST="/Volumes/AIPEMedia1/code/rodriveracom/org-ducktyper-ai/main /Volumes/AIPEMedia1/code/rodriveracom/profrod-site/worktrees/profrod--author-public-gate-20261104"
UNTRUST_FROM=41abedf3cde0a10cf52f16e3bd3eb6ecbad0c032c5ed13fbcb84e53447df7f1a
HERE=$(cd "$(dirname "$0")" && pwd -P)
TMUX_BIN=${ZEO_RESCUE_TMUX:-/opt/homebrew/bin/tmux}
STATE=${ZEO_RESCUE_STATE:-$HOME/.local/state/zeo-rescue}
CLAUDE_BACKUP=$STATE/claude-json.before-$CLAUDE_SEAT
# The folder step's mark names the inode of the folder it made: only that folder is trusted or started in.
CLAUDE_READY_MARK=$STATE/ops-move-$CLAUDE_SEAT/folder.done
CLAUDE_FIRST_DONE=$STATE/ops-move-$CLAUDE_SEAT/first.done
CLAUDE_TRIES=${ZEO_RESCUE_PROOF_TRIES:-60}
ZEOCREATOR_DONE=$STATE/zeocreator-note-20261108.done
step=${1:-}
case "$step" in verify|zeoarchitect|proof|all|lic|trust|codex-first|codex-rest|codex-untrust|zbs-repo|zbs-folder|zbs-folder-abs|ops-folder|claude-trust|claude-first|ops-old|zeocreator-note|claude-clear|claude-back|structure-trust|structure-first|structure-clear) ;; *) echo "usage: reseat-lines.sh verify|zeoarchitect|proof|all|lic|trust|codex-first|codex-rest|codex-untrust|zbs-repo|zbs-folder|zbs-folder-abs|ops-folder|claude-trust|claude-first|ops-old|zeocreator-note|claude-clear|claude-back|structure-trust SEAT|structure-first SEAT|structure-clear SEAT; nothing was run"; exit 2;; esac
place="$(id -un)@$(hostname -s)"
[ "$place" = "$WANT" ] || { echo "WRONG PLACE, nothing was run: you are $place. Open the rodbot terminal on the Mac mini."; exit 2; }
cd "$HERE" || exit 2
bad=0
pin() { local h; h=$(/usr/bin/shasum -a 256 "$2" 2>/dev/null | /usr/bin/cut -d " " -f 1); if [ "$h" != "$1" ]; then echo "HASH MISMATCH, nothing was run: $2 is ${h:-missing}"; bad=1; fi; }
# PINS
pin 633424ca575f43b1f6cca99234fe135af307ccb3554ca7b5a62e2f26858dc236 rescue.sh
pin 9350ecf29e596aa0c3e3c3cc0578780a954842d4f9020c0e351a3ac9cab51810 seat-exec.sh
pin 141ca64943f20b5991654b2f7f3f2301010737eaf5a280a71fde63e9bb80c871 Makefile
pin f2b46e84be7fd8f7518de997e0fbdbc9d540a9761b65a83bb5ec186293dea257 session-pins
pin ead62f6999df0115aaf2d4e3b29595528bea57ad7f9972bab10a8f652a9e8029 notes/reseat-20261105.txt
pin 6d0b0155f9493f1e7909d03acec0133b0f11ea8aad2c35fd6c321e3d358c0c2b notes/zeoarchitect-resume.txt
pin be3c80bbd7d676af647df90b340eb973b3117b6146130eff954490edf379a4c2 notes/lic-test-20261106.txt
pin caee56c6aa567ca20d84679cb6ba969a66be37ba92b74472ed60e199cdb400de notes/codex-relaunch-20261106.txt
pin 513e9cd776d1df5897c277e5aef34cdf9bdd745273f3877e4291c910d8129ebf folder-moves
pin 13416446261a2d8ba553eee22762e9efa4fdadb879dba5acc3ad1f51a2d2336d zshenv-lines.sh
pin c8cae72eb76d4376a682d9425486d0e47c48e7f7c1c5ee046b51b34532ef7afb notes/claude-move-zbs-20261107.txt
pin 6a147cb60ea844dd1f8047746fde29aeb2c942e7b861074454fdd73eab11f659 zbs-move.sh
pin 4730fece0bc70f05e4abcae5428866a7831f45f4e98eb31351df0e9de52df0f1 notes/zeocreator-memory-20261108.txt
pin 710302729c54dffab39ab4809813b6d8bb87516706862fa4f67a22367cb7cbe0 ops-move.sh
pin 3a18e0a2edae23907b0307dfa842cd645379a300146282ad25e4bc47730e2d1f notes/claude-move-ducktyper-ops-20261108.txt
pin b52a31f788ebaf588e9fe038db57251d109fe9def5b52c5d82ba1a8467998568 structure-move.sh
pin 8f4084d98524c01190d39dc95f8a0744a8dc8bdc585a1ab4aa268b8b9f840c7a structure-moves
pin 6bd9457575544ab5ffda80bdf305807009356cbee7f528b4d56fb1b1e3d720c0 notes/structure-move-claude.txt
pin 938e46d82f0a73ee1b4dc94200937b01c65be7eb24a8c299b6c890c502128fe7 structure-move-codex.sh
pin f2c752cf45aad5d24dcd48c20b53475131447be4d719fe9f8c80e125cca5ad6f notes/structure-move-codex.txt
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
  [ -f "$CLAUDE_READY_MARK" ] || { echo "OUT OF ORDER, nothing was run: the folder step has not finished ($CLAUDE_READY_MARK)."; exit 2; }
  local i; i=$(/usr/bin/sed -n 's/^inode=//p' "$CLAUDE_READY_MARK")
  [ -n "$i" ] && [ "$(stat -f %i "$CLAUDE_NEW")" = "$i" ] || { echo "NOT READY, nothing was run: $CLAUDE_NEW is not the folder the folder step made (inode ${i:-unknown}). Bring this to zeo-rescue."; exit 2; }
}
key() { printf %s "$1" | LC_ALL=C /usr/bin/sed 's/[^A-Za-z0-9]/-/g'; }
sha() { /usr/bin/shasum -a 256 "$1" 2>/dev/null | /usr/bin/cut -d " " -f 1; }
not_busy() { # a restart cuts a turn in progress, so a turn on any seat this step would restart stops it; a quiet result is what can be seen
  local w; w=$(./rescue.sh --reseat --relaunch --harness codex --before $BEFORE "$@" 2>&1 | /usr/bin/grep 'a turn is in progress')
  [ -z "$w" ] || { echo "BUSY, nothing was run. Try again when these are idle:"; echo "$w"; exit 2; }
}
log=$STATE/reseat-lines-$step-$(date +%Y%m%d-%H%M%S).log
case "$step" in structure-*)
  [[ "${2:-}" =~ ^[a-z0-9][a-z0-9-]{0,63}$ ]] || { echo "usage: reseat-lines.sh $step SEAT; nothing was run"; exit 2; }
  log=$STATE/reseat-lines-$step-$2-$(date +%Y%m%d-%H%M%S).log;; esac
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
    while read -r seat to _; do
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
  codex-untrust)
    b=$STATE/codex-config.before-untrust-20261106; tmp="$CODEX_CONFIG.zeo"; made=""; n=0; c=0; procs=$(ps -axo command=) # read first, or a grep would find itself
    for p in $UNTRUST; do
      c=$((c+1)); if /usr/bin/grep -qxF "[projects.\"$p\"]" "$CODEX_CONFIG"; then n=$((n+1)); fi
      [ ! -e "$p" ] || { echo "REFUSED, nothing was changed: $p exists again."; exit 2; }
      case "$procs" in *"-C $p "*) echo "REFUSED, nothing was changed: a Codex process is in $p."; exit 2;; esac
    done
    [ "$n" != 0 ] || { echo "NOTHING TO REMOVE: neither entry is there; nothing was changed"; exit 0; }
    [ "$n" = "$c" ] || { echo "REFUSED, nothing was changed: only $n of $c entries are there."; exit 2; }
    was=$(sha "$CODEX_CONFIG"); [ "$was" = "$UNTRUST_FROM" ] || { echo "HASH MISMATCH, nothing was changed: $CODEX_CONFIG is ${was:-missing}, not the file the Architect read"; exit 2; }
    drop() { rm -f "$tmp"; [ -z "$made" ] || rm -f "$b"; }
    trap drop EXIT
    cp -p "$CODEX_CONFIG" "$tmp" && UNTRUST=$UNTRUST awk 'BEGIN {n = split(ENVIRON["UNTRUST"], d, " "); for (i = 1; i <= n; i++) h["[projects.\"" d[i] "\"]"] = 1}
      s == 1 {s = ($0 == "trust_level = \"trusted\"") ? 2 : 0; if (s) next; bad = 1}
      s == 2 {s = 0; if ($0 == "") next}
      $0 in h {s = 1; next}
      {print} END {exit bad}' "$CODEX_CONFIG" > "$tmp" || { echo "REFUSED, nothing was changed: an entry is not a plain trusted one."; exit 2; }
    # Six lines go, three for each entry, and nothing else changes.
    [ "$(/usr/bin/diff "$CODEX_CONFIG" "$tmp" | /usr/bin/grep -c '^<')" = $((c*3)) ] && [ "$(/usr/bin/diff "$CODEX_CONFIG" "$tmp" | /usr/bin/grep -c '^>')" = 0 ] || { echo "REFUSED, nothing was changed: the edit is not exactly those entries."; exit 2; }
    if [ ! -e "$b" ]; then (umask 077; /bin/cat "$CODEX_CONFIG" > "$b") || { echo "FAILED, nothing was changed: no backup"; exit 1; }; made=1; fi
    [ "$(sha "$b")" = "$was" ] || { echo "FAILED, nothing was changed: the backup is not the file the Architect read"; exit 1; }
    if [ "$(sha "$CODEX_CONFIG")" != "$was" ]; then echo "REFUSED, nothing was changed: $CODEX_CONFIG changed during the edit. Bring this to zeo-rescue."; exit 2; fi
    mv -f "$tmp" "$CODEX_CONFIG" || { echo "FAILED, nothing was changed"; exit 1; }
    made=""
    echo "REMOVED: $c entries are gone from $CODEX_CONFIG, now $(sha "$CODEX_CONFIG"); backup at $b. Tell zeo-rescue: done."; exit 0;;
  zbs-repo) STATE="$STATE" ./zbs-move.sh repo 2>&1 | tee "$log";;
  zbs-folder) STATE="$STATE" ./zbs-move.sh folder 2>&1 | tee "$log";;
  zbs-folder-abs) STATE="$STATE" ./zbs-move.sh folder-abs 2>&1 | tee "$log";;
  ops-folder) STATE="$STATE" ./ops-move.sh "$CLAUDE_SEAT" folder 2>&1 | tee "$log";;
  ops-old) STATE="$STATE" ./ops-move.sh "$CLAUDE_SEAT" old 2>&1 | tee "$log";;
  structure-trust|structure-first|structure-clear) STATE="$STATE" ./structure-move.sh "${2:-}" "${step#structure-}" 2>&1 | tee "$log";;
  claude-trust)
    claude_ready
    if [ "$(jq -r --arg d "$CLAUDE_NEW" '.projects[$d].hasTrustDialogAccepted // false' "$CLAUDE_JSON")" = true ]; then echo "NOTHING TO ADD: $CLAUDE_NEW is already trusted; nothing was changed"; exit 0; fi
    # Every Claude process rewrites this file. Claude's lock is taken, but rehearsal/claude-lock.sh shows Claude writing through it, so the hash below is what guards the change.
    i=0; until mkdir "$CLAUDE_JSON.lock" 2>/dev/null; do i=$((i+1)); [ $i -lt 40 ] || { echo "FAILED, nothing was changed: Claude's config lock stayed held"; exit 1; }; perl -e 'select(undef,undef,undef,0.25)'; done
    tmp="$CLAUDE_JSON.zeo"; made=""
    drop() { rm -f "$tmp"; [ -z "$made" ] || rm -f "$CLAUDE_BACKUP"; }
    trap 'drop; rmdir "$CLAUDE_JSON.lock" 2>/dev/null' EXIT
    # A writer that ignores the lock would be overwritten without a trace, so the file must be the same bytes at the end as at the start.
    was=$(sha "$CLAUDE_JSON"); [ -n "$was" ] || { echo "FAILED, nothing was changed: cannot read $CLAUDE_JSON"; exit 1; }
    cp -p "$CLAUDE_JSON" "$tmp" && jq --arg d "$CLAUDE_NEW" '.projects[$d] = ((.projects[$d] // {}) + {hasTrustDialogAccepted: true})' "$CLAUDE_JSON" > "$tmp" && jq -e --arg d "$CLAUDE_NEW" '.projects[$d].hasTrustDialogAccepted == true' "$tmp" >/dev/null || { echo "FAILED, nothing was changed"; exit 1; }
    # It holds account data, so it is 600 from its first byte, whatever the file's own mode is.
    if [ ! -e "$CLAUDE_BACKUP" ]; then (umask 077; /bin/cat "$CLAUDE_JSON" > "$CLAUDE_BACKUP") || { echo "FAILED, nothing was changed: no backup"; exit 1; }; made=1; fi
    chmod 600 "$CLAUDE_BACKUP" && [ "$(stat -f %Lp "$CLAUDE_BACKUP")" = 600 ] || { echo "FAILED, nothing was changed: the backup is not mode 600"; exit 1; }
    if [ "$(sha "$CLAUDE_JSON")" != "$was" ]; then echo "REFUSED, nothing was changed: $CLAUDE_JSON changed while the lock was held, so a writer does not honour it. Bring this to zeo-rescue."; exit 2; fi
    mv -f "$tmp" "$CLAUDE_JSON" || { echo "FAILED, nothing was changed"; exit 1; }
    made=""
    echo "ADDED: $CLAUDE_NEW is trusted; backup at $CLAUDE_BACKUP, mode 600. Tell zeo-rescue: done."; exit 0;;
  claude-first)
    claude_ready
    # Once: after the move the seat reads as right, so only this mark tells a move done from one still to run.
    [ ! -f "$CLAUDE_FIRST_DONE" ] || { echo "ALREADY DONE: $CLAUDE_SEAT moved and its note arrived ($(cat "$CLAUDE_FIRST_DONE")). Nothing was run."; exit 0; }
    v=$("$CLAUDE_BIN" --version 2>/dev/null | /usr/bin/awk 'NR==1 {print $1}'); echo "the Claude that will run: ${v:-unknown}; rehearsed on $CLAUDE_REHEARSED"
    [ "$v" = "$CLAUDE_REHEARSED" ] || { echo "VERSION CHANGED, nothing was run: Claude is ${v:-unknown} and the rehearsal ran on $CLAUDE_REHEARSED. Bring this to zeo-rescue."; exit 2; }
    sid=$(awk -v s="$CLAUDE_SEAT" '$1==s {print $2}' session-pins); t=$PROJECTS/$(key "$CLAUDE_OLD")/$sid.jsonl; tn=$PROJECTS/$(key "$CLAUDE_NEW")/$sid.jsonl
    [ -f "$t" ] || t=$tn # a run stopped after the project's rename
    [ -n "$sid" ] && [ -f "$t" ] || { echo "NOT READY, nothing was run: no transcript for $CLAUDE_SEAT under either folder"; exit 2; }
    LC_ALL=C /usr/bin/grep -qF -e "$CLAUDE_PROOF" "$t" && { echo "REFUSED, nothing was run: the note's words are already in $t, so the proof could not tell this run's from an earlier one. Bring this to zeo-rescue."; exit 2; }
    w=$(./rescue.sh --reseat --relaunch --harness claude --seat "$CLAUDE_SEAT" 2>&1 | /usr/bin/grep 'a turn is in progress')
    [ -z "$w" ] || { echo "BUSY, nothing was run. Try again when it is idle:"; echo "$w"; exit 2; }
    b=$(stat -f %z "$t")
    { echo "claude $v"; make reseat ARGS="--relaunch --harness claude --seat $CLAUDE_SEAT --note-file $CLAUDE_NOTE" && make check ARGS="--seat $CLAUDE_SEAT"; } 2>&1 | tee "$log"
    [ "${PIPESTATUS[0]}" -eq 0 ] || { echo "STOPPED: the move or its check failed; the note's delivery is not proved. Bring this to zeo-rescue." | tee -a "$log"; exit 1; }
    i=0; until [ "$(tail -c +$((b+1)) "$tn" 2>/dev/null | LC_ALL=C /usr/bin/grep -cF -e "$CLAUDE_PROOF")" -ge 1 ]; do
      i=$((i+1)); [ $i -lt "$CLAUDE_TRIES" ] || { echo "NOT DELIVERED: the note's words are not in $tn after the restart. Bring this to zeo-rescue." | tee -a "$log"; exit 1; }; perl -e 'select(undef,undef,undef,1)'; done
    date -u +%Y-%m-%dT%H:%M:%SZ > "$CLAUDE_FIRST_DONE"
    echo "NOTE DELIVERED $CLAUDE_SEAT: its words are in session $sid under $CLAUDE_NEW, after byte $b; a second run says ALREADY DONE. Tell zeo-rescue: done." | tee -a "$log";;
  zeocreator-note)
    # Once: the seat reads as right before and after, so only this mark tells a delivered note from one still to send.
    [ ! -f "$ZEOCREATOR_DONE" ] || { echo "ALREADY DONE: the note reached zeocreator ($(cat "$ZEOCREATOR_DONE")). Nothing was run."; exit 0; }
    v=$("$CLAUDE_BIN" --version 2>/dev/null | /usr/bin/awk 'NR==1 {print $1}'); echo "the Claude that will run: ${v:-unknown}; rehearsed on $CLAUDE_REHEARSED"
    [ "$v" = "$CLAUDE_REHEARSED" ] || { echo "VERSION CHANGED, nothing was run: Claude is ${v:-unknown} and the rehearsal ran on $CLAUDE_REHEARSED. Bring this to zeo-rescue."; exit 2; }
    sid=$(awk '$1=="zeocreator" {print $2}' session-pins); dir=$(awk '$1=="zeocreator" {print $2}' folder-moves)
    t=$PROJECTS/$(printf %s "$dir" | LC_ALL=C sed 's/[^A-Za-z0-9]/-/g')/$sid.jsonl
    [ -n "$sid" ] && [ -n "$dir" ] && [ -f "$t" ] || { echo "NOT READY, nothing was run: no transcript for zeocreator at $t"; exit 2; }
    LC_ALL=C /usr/bin/grep -qF -e "$ZEOCREATOR_PROOF" "$t" && { echo "REFUSED, nothing was run: the note's words are already in $t, so the proof could not tell this run's from an earlier one. Bring this to zeo-rescue."; exit 2; }
    plan=$(./rescue.sh --reseat --relaunch --restart --harness claude --seat zeocreator --note-file "$ZEOCREATOR_NOTE" 2>&1)
    w=$(/usr/bin/grep 'a turn is in progress' <<< "$plan")
    [ -z "$w" ] || { echo "BUSY, nothing was run. Try again when it is idle:"; echo "$w"; exit 2; }
    /usr/bin/grep -q '^RESEAT zeocreator: ' <<< "$plan" || { echo "REFUSED, nothing was run: the plan does not restart zeocreator:"; printf '%s\n' "$plan"; exit 2; }
    b=$(stat -f %z "$t")
    { echo "claude $v"; make reseat ARGS="--relaunch --restart --harness claude --seat zeocreator --note-file $ZEOCREATOR_NOTE" && make check ARGS="--seat zeocreator"; } 2>&1 | tee "$log"
    [ "${PIPESTATUS[0]}" -eq 0 ] || { echo "STOPPED: the restart or its check failed; the note's delivery is not proved. Bring this to zeo-rescue." | tee -a "$log"; exit 1; }
    i=0; until [ "$(tail -c +$((b+1)) "$t" | LC_ALL=C /usr/bin/grep -cF -e "$ZEOCREATOR_PROOF")" -ge 1 ]; do
      i=$((i+1)); [ $i -lt "$ZEOCREATOR_TRIES" ] || { echo "NOT DELIVERED: the note's words are not in $t after the restart. Bring this to zeo-rescue." | tee -a "$log"; exit 1; }; perl -e 'select(undef,undef,undef,1)'; done
    date -u +%Y-%m-%dT%H:%M:%SZ > "$ZEOCREATOR_DONE"
    echo "NOTE DELIVERED zeocreator: its words are in session $sid, after byte $b; a second run says ALREADY DONE. Tell zeo-rescue: done." | tee -a "$log";;
  claude-clear)
    claude_ready
    ./rescue.sh --check --seat "$CLAUDE_SEAT" 2>&1 | /usr/bin/grep "^OK $CLAUDE_SEAT " >/dev/null || { echo "OUT OF ORDER, nothing was deleted: $CLAUDE_SEAT is not right yet."; exit 2; }
    [ -e "$CLAUDE_BACKUP" ] || { echo "NOTHING TO DELETE: there is no backup"; exit 0; }
    rm -f "$CLAUDE_BACKUP" && [ ! -e "$CLAUDE_BACKUP" ] || { echo "FAILED: $CLAUDE_BACKUP is still there"; exit 1; }
    echo "DELETED: the backup of $CLAUDE_JSON is gone. Tell zeo-rescue: done."; exit 0;;
  claude-back)
    [ -z "$(awk -v s="$CLAUDE_SEAT" '$1==s' folder-moves)" ] || { echo "REFUSED, nothing was changed: take $CLAUDE_SEAT out of folder-moves first."; exit 2; }
    [ -d "$CLAUDE_OLD" ] || { echo "REFUSED, nothing was changed: $CLAUDE_OLD is gone, so the project would have no folder. The folder goes back first, and that is the Architect's. Going forward needs no rollback: the claude-first line can run again."; exit 2; }
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
