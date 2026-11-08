#!/bin/bash
# zeo-rescue: the two folder steps of the zbs move, on the Architect's order of 2026-11-07 20:45. reseat-lines.sh runs them; it pins this file.
#
#   zbs-move.sh repo    the seat's folder becomes the repository: the 10 dead worktree records are pruned, the git store moves into the seat's
#                       folder with the seat's own HEAD and index, its worktree record goes, wt-screensaver is repaired, and git status in both
#                       must read as before. Then the 24 Sep checkout, with no .git left in it, is set aside.
#   zbs-move.sh folder  the seat's folder moves whole to its new path, wt-screensaver is repaired again and read again, the seat's memory goes into
#                       its project, so the project's one rename at the restart takes it along, and the one Edit allow rule moves to the new path,
#                       and the 20 rules that guard .git, hooks and Makefiles are mirrored under it (order of 2026-11-08 03:09).
#   zbs-move.sh folder-abs  the same, with the mirrored rules written as absolute paths ("//"), the form that takes effect.
#
# Each step reads everything first and refuses with "nothing was changed" unless the state is exactly the one read on 7 Nov. It changes only
# what it names, moves and never copies, and stops at the first failure, saying what is where. A second run says ALREADY DONE.
# What it read, and the files it set aside, go to $STATE/zbs-move-20261107 (mode 700).
set -uo pipefail
SOCKET=zeo2
TSESS=dt-broadcastingstudio-maintainer
SESSION_ID=d7fc6540-05c6-43ec-94c5-520b66af4133
MAIN=/Volumes/AIPEMedia1/code/ducktyper-ai/dt-broadcastingstudio/main
SEAT=/Volumes/AIPEMedia1/code/zeroemployeeorg/zeobroacastingstudio-zbs
ASIDE=/Volumes/AIPEMedia1/code/ducktyper-ai/dt-broadcastingstudio/main-old-20260924
WT=/Volumes/ZeoWork/tmp/zbs/wt-screensaver
MEM_FROM_DIR=/Volumes/AIPEMedia1/code/zeroemployeeorg/zeobroacastingstudio
SEAT_INODE=10850475
SEAT_HEAD=e05c64b59fad43630b3191a456eeabe932214733
MAIN_HEAD=9593e649748894e7844e21405d41b1473c07954e
REC=zeobroacastingstudio-zbs
WT_REC=wt-screensaver
PRUNE="-engine r41-38 verify-main-3b16cf4 verify-pr-43b283e wt-dryrun wt-ecamm wt-jev wt-mcp2 wt-series wt-split"
RULE_FROM='Edit(/Volumes/AIPEMedia1/code/zeroemployeeorg/**)'
RULE_TO='Edit(/Volumes/AIPEMedia1/code/ducktyper-ai/dt-broadcastingstudio/main/**)'
# The Architect's order of 2026-11-08 03:09: each deny and ask rule that guards .git, hooks or Makefiles under the old prefix gets the same rule
# under the new folder, after it; the old rules stay. These are the 16 deny and 4 ask rules of that form, each as Edit and as Write.
# The step "folder" writes them as ordered, with one leading slash. Claude anchors such a rule at the seat's own folder, so neither those
# nor the seat's old ones match anything (tested on 2.1.318 and 2.1.319). "folder-abs" writes the same rules with "//", the form Claude reads
# as an absolute path: then the Edit rules take effect, and the seat is asked before it edits its own Makefile.
MIRROR_FROM=/Volumes/AIPEMedia1/code/zeroemployeeorg/
MIRROR_TO=/Volumes/AIPEMedia1/code/ducktyper-ai/dt-broadcastingstudio/main/
MIRROR_DENY='.git/** **/.git/** .git **/.git **/.githooks/** **/.husky/** *.git/hooks/** **/*.git/hooks/**'
MIRROR_ASK='**/Makefile **/*.mk'
# The files git keeps for each checkout. The store's own go aside; the seat's take their place.
PER_TREE="HEAD index ORIG_HEAD COMMIT_EDITMSG FETCH_HEAD"
STORE_TOP="COMMIT_EDITMSG config description FETCH_HEAD HEAD hooks index info logs objects ORIG_HEAD packed-refs refs worktrees"
REC_TOP="COMMIT_EDITMSG commondir FETCH_HEAD gitdir HEAD index logs ORIG_HEAD refs"
STATE=${STATE:-${ZEO_RESCUE_STATE:-$HOME/.local/state/zeo-rescue}}
PROJECTS=${ZEO_RESCUE_PROJECTS:-$HOME/.claude/projects}
TMUX_BIN=${ZEO_RESCUE_TMUX:-/opt/homebrew/bin/tmux}
LSOF=${ZEO_RESCUE_LSOF:-/usr/sbin/lsof}
D=$STATE/zbs-move-20261107
export GIT_OPTIONAL_LOCKS=0 # a read must not write an index the seat may be using
step=${1:-} form=${1:-}
case "$step" in repo|folder) MT=$MIRROR_TO;; folder-abs) MT=/$MIRROR_TO step=folder;; *) echo "usage: zbs-move.sh repo|folder|folder-abs; nothing was run"; exit 2;; esac

no() { echo "REFUSED, nothing was changed: $*"; exit 2; }
fail() { echo "STOPPED at $1: $2. Nothing after it was done. Bring this to zeo-rescue."; exit 1; }
key() { printf %s "$1" | LC_ALL=C sed 's/[^A-Za-z0-9]/-/g'; }
ino() { stat -f %i "$1" 2>/dev/null; }
dev() { stat -f %d "$1" 2>/dev/null; }
names() { ls -A "$1" 2>/dev/null | LC_ALL=C sort | paste -sd' ' -; }
sorted() { printf '%s\n' $1 | LC_ALL=C sort | paste -sd' ' -; }
idle() { # a turn in progress shows "esc to interrupt"; moving its folder or its git store under it would cut that turn
  local s; s=$("$TMUX_BIN" -L "$SOCKET" capture-pane -p -t "=$TSESS:" 2>/dev/null) || no "cannot read the seat's pane in $TSESS"
  case "$s" in *"esc to interrupt"*) echo "BUSY, nothing was changed: the seat has a turn in progress. Try again when it is idle."; exit 2;; esac
}
nolocks() { local l; l=$(find "$1" -name '*.lock' 2>/dev/null | head -1); [ -z "$l" ] || no "git is at work: $l"; }
snap() { # snap DIR: what git status says there, the same way before and after
  git -C "$1" rev-parse HEAD && git -C "$1" status --porcelain=v2 --branch --ignored --untracked-files=normal
}
refs() { git -C "$1" for-each-ref --format='%(objectname) %(refname)' && git -C "$1" stash list; }
same() { # same WHAT DIR FILE: read again, and it must equal the before
  local now; now=$("$2" "$3" 2>&1) || fail "$1" "git could not read $3"
  [ "$now" = "$(cat "$4")" ] || { printf '%s\n' "$now" > "$4.after"; fail "$1" "it differs from before in $3: compare $4 with $4.after"; }
}
manifest() { (cd "$1" && find . -type f -print0 | LC_ALL=C sort -z | xargs -0 /usr/bin/shasum -a 256); }
mirrors() { # list, old rule, new rule: one line each, tab-separated
  local s t; set -f
  for s in $MIRROR_DENY; do for t in Edit Write; do printf 'deny\t%s(%s%s)\t%s(%s%s)\n' $t "$MIRROR_FROM" "$s" $t "$MT" "$s"; done; done
  for s in $MIRROR_ASK; do for t in Edit Write; do printf 'ask\t%s(%s%s)\t%s(%s%s)\n' $t "$MIRROR_FROM" "$s" $t "$MT" "$s"; done; done
  set +f; }
mkdir -p "$D" && chmod 700 "$D" || no "cannot make $D"

case "$step" in
repo)
  if [ -d "$SEAT/.git" ] && [ -d "$ASIDE" ] && [ ! -e "$MAIN" ]; then echo "ALREADY DONE: $SEAT is the repository and the 24 Sep checkout is at $ASIDE. Nothing was changed."; exit 0; fi
  if [ -d "$MAIN/.git" ] && [ ! -e "$SEAT" ] && [ "$(ino "$MAIN")" = "$SEAT_INODE" ]; then echo "ALREADY DONE: the seat's folder is already at $MAIN. Nothing was changed."; exit 0; fi
  G=$MAIN/.git R=$MAIN/.git/worktrees/$REC
  # Read everything first.
  [ ! -e "$ASIDE" ] || no "$ASIDE is already there"
  [ -d "$SEAT" ] && [ "$(ino "$SEAT")" = "$SEAT_INODE" ] || no "$SEAT is not the folder read on 7 Nov (inode $SEAT_INODE)"
  [ "$(dev "$SEAT")" = "$(dev "$MAIN")" ] || no "$SEAT and $MAIN are on different volumes, so a move would be a copy"
  [ -f "$SEAT/.git" ] && [ "$(cat "$SEAT/.git")" = "gitdir: $R" ] || no "$SEAT/.git is not the link to $R"
  [ -d "$G" ] && [ ! -L "$G" ] || no "$G is not the git store"
  [ "$(names "$G" | tr ' ' '\n' | grep -vxF -f <(printf '%s\n' $STORE_TOP) | head -1)" = "" ] || no "$G holds something not read on 7 Nov: $(names "$G")"
  [ "$(cat "$G/HEAD")" = "ref: refs/heads/main" ] && [ "$(git -C "$MAIN" rev-parse refs/heads/main)" = "$MAIN_HEAD" ] || no "the 24 Sep checkout is not on main at $MAIN_HEAD"
  git -C "$MAIN" merge-base --is-ancestor "$MAIN_HEAD" refs/remotes/origin/main || no "$MAIN_HEAD is not on origin/main"
  [ -z "$(git -C "$MAIN" status --porcelain --untracked-files=all)" ] || no "the 24 Sep checkout is not clean"
  for k in core.worktree core.bare extensions.worktreeConfig; do v=$(git config -f "$G/config" --get "$k"); [ -z "$v" ] || [ "$k:$v" = core.bare:false ] || no "$G/config sets $k=$v"; done
  [ "$(names "$G/worktrees")" = "$(sorted "$PRUNE $REC $WT_REC")" ] || no "the worktree records are not the 12 read on 7 Nov: $(names "$G/worktrees")"
  would=$(git -C "$MAIN" worktree prune -n -v 2>&1 | sed -n 's#^Removing worktrees/\([^:]*\): gitdir file points to non-existent location$#\1#p' | LC_ALL=C sort | paste -sd' ' -)
  [ "$would" = "$(sorted "$PRUNE")" ] || no "a prune would remove '$would', not the 10 read on 7 Nov"
  [ "$(names "$R")" = "$(sorted "$REC_TOP")" ] && [ "$(names "$R/logs")" = HEAD ] && [ -z "$(names "$R/refs")" ] || no "the seat's record holds something not read on 7 Nov: $(names "$R")"
  [ "$(cat "$R/HEAD")" = "$SEAT_HEAD" ] && [ "$(cat "$R/gitdir")" = "$SEAT/.git" ] && [ "$(cat "$R/commondir")" = "../.." ] || no "the seat's record is not detached at $SEAT_HEAD, linked to $SEAT"
  [ -f "$WT/.git" ] && [ "$(cat "$WT/.git")" = "gitdir: $G/worktrees/$WT_REC" ] && [ "$(cat "$G/worktrees/$WT_REC/gitdir")" = "$WT/.git" ] || no "$WT is not linked to $G/worktrees/$WT_REC"
  for f in $PER_TREE; do [ -f "$G/$f" ] && [ -f "$R/$f" ] || no "$f is missing from the store or from the seat's record"; done
  [ -f "$G/logs/HEAD" ] && [ -f "$R/logs/HEAD" ] || no "a HEAD log is missing"
  nolocks "$G"
  w=$("$LSOF" -a -d cwd -Fn 2>/dev/null | grep -E "^n$MAIN(/|\$)" | head -1); [ -z "$w" ] || no "a process works in the 24 Sep checkout: ${w#n}"
  idle
  snap "$SEAT" > "$D/before-seat.txt" 2>&1 && snap "$WT" > "$D/before-wt.txt" 2>&1 && refs "$SEAT" > "$D/before-refs.txt" 2>&1 || no "git could not read the seat's folder or wt-screensaver"
  echo "READ: the seat at $(head -1 "$D/before-seat.txt"), $(wc -l < "$D/before-seat.txt" | tr -d " ") lines of status; wt-screensaver $(wc -l < "$D/before-wt.txt" | tr -d " "); $(wc -l < "$D/before-refs.txt" | tr -d ' ') refs"
  # Change.
  git -C "$MAIN" worktree prune -v || fail "the prune" "git failed"
  [ "$(names "$G/worktrees")" = "$(sorted "$REC $WT_REC")" ] || fail "the prune" "records left: $(names "$G/worktrees")"
  echo "PRUNED: $PRUNE"
  # Per-checkout files are moved, one by one. The seat's git is down from here to the move of the store, a few milliseconds.
  mkdir -m 700 "$D/store-checkout-files" || fail "setting aside the 24 Sep checkout's own git files" "cannot make $D/store-checkout-files"
  for f in $PER_TREE; do mv "$G/$f" "$D/store-checkout-files/$f" || fail "setting aside $G/$f" "mv failed"; done
  mv "$G/logs/HEAD" "$D/store-checkout-files/logs-HEAD" || fail "setting aside $G/logs/HEAD" "mv failed"
  for f in $PER_TREE; do mv "$R/$f" "$G/$f" || fail "moving the seat's $f into the store" "mv failed; $G lacks $f"; done
  mv "$R/logs/HEAD" "$G/logs/HEAD" || fail "moving the seat's HEAD log" "mv failed"
  rm "$R/commondir" "$R/gitdir" && rmdir "$R/logs" "$R/refs" "$R" || fail "removing the seat's record" "$R is not empty: $(names "$R")"
  cp "$SEAT/.git" "$D/seat-gitfile" && rm "$SEAT/.git" || fail "replacing $SEAT/.git" "could not remove the link"
  mv "$G" "$SEAT/.git" || fail "moving the store" "mv $G $SEAT/.git failed: the seat's folder has no .git"
  echo "MOVED: the store is $SEAT/.git, at the seat's HEAD with its own index; the 24 Sep checkout's own files are in $D/store-checkout-files"
  git -C "$SEAT" worktree repair "$WT" || fail "repairing $WT" "git failed"
  [ "$(cat "$WT/.git")" = "gitdir: $SEAT/.git/worktrees/$WT_REC" ] || fail "repairing $WT" "its link reads $(cat "$WT/.git")"
  # Prove it.
  [ "$(git -C "$SEAT" rev-parse --absolute-git-dir)" = "$SEAT/.git" ] && [ "$(git -C "$SEAT" rev-parse --path-format=absolute --git-common-dir)" = "$SEAT/.git" ] || fail "the proof" "$SEAT is still a worktree"
  ! git -C "$SEAT" symbolic-ref -q HEAD >/dev/null && [ "$(git -C "$SEAT" rev-parse HEAD)" = "$SEAT_HEAD" ] || fail "the proof" "HEAD is not detached at $SEAT_HEAD"
  [ "$(git -C "$SEAT" worktree list --porcelain | sed -n 's/^worktree //p' | paste -sd' ' -)" = "$SEAT $WT" ] || fail "the proof" "the worktrees are not exactly the seat and $WT"
  same "the proof" snap "$SEAT" "$D/before-seat.txt"; same "the proof" snap "$WT" "$D/before-wt.txt"; same "the proof" refs "$SEAT" "$D/before-refs.txt"
  echo "PROVED: git status in the seat's folder and in wt-screensaver, and every ref, read as before"
  [ ! -e "$MAIN/.git" ] || fail "setting aside" "$MAIN/.git is there again"
  mv "$MAIN" "$ASIDE" || fail "setting aside" "mv $MAIN $ASIDE failed"
  echo "REPO DONE: $SEAT is the repository; the 24 Sep checkout is at $ASIDE with no .git. Tell zeo-rescue: done."; exit 0;;
folder)
  P_OLD=$PROJECTS/$(key "$SEAT") P_NEW=$PROJECTS/$(key "$MAIN") M=$PROJECTS/$(key "$MEM_FROM_DIR")/memory S=$MAIN/.claude/settings.local.json
  if [ -d "$MAIN/.git" ] && [ ! -e "$SEAT" ] && [ "$(ino "$MAIN")" = "$SEAT_INODE" ] && [ -f "$D/folder.done" ]; then echo "ALREADY DONE: the seat's folder is at $MAIN, by the step $(cat "$D/folder.done"). Nothing was changed."; exit 0; fi
  [ -d "$SEAT/.git" ] && [ -d "$ASIDE" ] && [ ! -e "$MAIN" ] || { echo "OUT OF ORDER, nothing was changed: the repo step comes first, and it is not done."; exit 2; }
  [ "$(ino "$SEAT")" = "$SEAT_INODE" ] || no "$SEAT is not the folder read on 7 Nov"
  [ "$(dev "$SEAT")" = "$(dev "$ASIDE")" ] || no "the new path is on another volume, so a move would be a copy"
  [ "$(cat "$WT/.git")" = "gitdir: $SEAT/.git/worktrees/$WT_REC" ] || no "$WT is not linked to the seat's store"
  [ -f "$D/before-seat.txt" ] && [ -f "$D/before-wt.txt" ] && [ -f "$D/before-refs.txt" ] || no "the repo step's record is missing from $D"
  [ -f "$P_OLD/$SESSION_ID.jsonl" ] || no "the seat's transcript is not in $P_OLD"
  [ -d "$M" ] && [ ! -L "$M" ] || no "the seat's memory is not at $M"
  [ ! -e "$P_OLD/memory" ] || no "$P_OLD/memory is already there, and two memories are not merged here"
  # Claude, started in a worktree, makes an empty memory folder under the key of the store's checkout, which is this path. Only that may be there.
  if [ -e "$P_NEW" ]; then [ "$(cd "$P_NEW" 2>/dev/null && find . | LC_ALL=C sort | paste -sd' ' -)" = ". ./memory" ] && [ -d "$P_NEW/memory" ] || no "$P_NEW is already there, and holds more than an empty memory folder"; fi
  [ "$(jq --arg f "$RULE_FROM" '[.permissions.allow[] | select(. == $f)] | length' "$SEAT/.claude/settings.local.json" 2>/dev/null)" = 1 ] || no "the seat's settings do not hold the allow rule $RULE_FROM exactly once"
  [ "$(jq --arg t "$RULE_TO" '[.. | strings | select(. == $t)] | length' "$SEAT/.claude/settings.local.json")" = 0 ] || no "the seat's settings already name $RULE_TO"
  [ "$(LC_ALL=C grep -cF "\"$RULE_FROM\"" "$SEAT/.claude/settings.local.json")" = 1 ] || no "the rule's text is not on exactly one line"
  mirrors > "$D/mirror.tsv" && [ "$(wc -l < "$D/mirror.tsv" | tr -d ' ')" = 20 ] || no "cannot list the 20 rules to mirror in $D/mirror.tsv"
  while IFS=$'\t' read -r l o n; do
    [ "$(jq --arg l "$l" --arg o "$o" '[.permissions[$l][] | select(. == $o)] | length' "$SEAT/.claude/settings.local.json")" = 1 ] || no "the seat's $l rules do not hold $o exactly once"
    [ "$(LC_ALL=C grep -cF "\"$o\"" "$SEAT/.claude/settings.local.json")" = 1 ] && [ "$(awk -v s="\"$o\"," '{sub(/^[ \t]+/, "")} $0 == s {n++} END {print n+0}' "$SEAT/.claude/settings.local.json")" = 1 ] || no "$o is not alone on one line, followed by a comma"
    [ "$(jq --arg n "$n" '[.. | strings | select(. == $n)] | length' "$SEAT/.claude/settings.local.json")" = 0 ] || no "the seat's settings already hold $n"
  done < "$D/mirror.tsv"
  nolocks "$SEAT/.git"
  idle
  manifest "$M" > "$D/memory-before.txt" || no "cannot read the memory"
  # Change.
  if [ -e "$P_NEW" ]; then rmdir "$P_NEW/memory" "$P_NEW" || fail "clearing $P_NEW" "it is no longer empty"; echo "CLEARED: the empty $P_NEW that Claude made, so the restart's rename has a free name"; fi
  mv "$SEAT" "$MAIN" || fail "the folder move" "mv $SEAT $MAIN failed"
  [ "$(ino "$MAIN")" = "$SEAT_INODE" ] && [ ! -e "$SEAT" ] || fail "the folder move" "$MAIN is not the seat's folder"
  echo "MOVED: the seat's folder is $MAIN, the same folder by inode"
  git -C "$MAIN" worktree repair "$WT" || fail "repairing $WT" "git failed"
  [ "$(cat "$WT/.git")" = "gitdir: $MAIN/.git/worktrees/$WT_REC" ] || fail "repairing $WT" "its link reads $(cat "$WT/.git")"
  [ "$(git -C "$MAIN" rev-parse --absolute-git-dir)" = "$MAIN/.git" ] && [ "$(git -C "$MAIN" rev-parse --path-format=absolute --git-common-dir)" = "$MAIN/.git" ] || fail "the proof" "$MAIN is a worktree"
  [ "$(git -C "$MAIN" worktree list --porcelain | sed -n 's/^worktree //p' | paste -sd' ' -)" = "$MAIN $WT" ] || fail "the proof" "the worktrees are not exactly the seat and $WT"
  same "the proof" snap "$MAIN" "$D/before-seat.txt"; same "the proof" snap "$WT" "$D/before-wt.txt"; same "the proof" refs "$MAIN" "$D/before-refs.txt"
  echo "PROVED: git status in both, and every ref, read as before the repo step"
  mv "$M" "$P_OLD/memory" || fail "moving the memory" "mv $M $P_OLD/memory failed"
  [ "$(manifest "$P_OLD/memory")" = "$(cat "$D/memory-before.txt")" ] || fail "moving the memory" "its files differ from before"
  echo "MEMORY: $(wc -l < "$D/memory-before.txt" | tr -d ' ') files moved from $M into the seat's project, unchanged; the restart's rename takes them to $P_NEW"
  (umask 077; cat "$S" > "$D/settings.local.json.before") || fail "the settings" "no backup"
  RF=$RULE_FROM RT=$RULE_TO perl -i -pe 's/\Q"$ENV{RF}"\E/"$ENV{RT}"/' "$S" || fail "the settings" "perl failed; the backup is $D/settings.local.json.before"
  MF=$D/mirror.tsv perl -i -ne 'BEGIN { open F, "<", $ENV{MF} or die; while (<F>) { chomp; my (undef, $o, $n) = split /\t/; $M{$o} = $n } close F }
    print; print "$1\"$M{$2}\",\n" if /^(\s*)"(.*)",\n\z/ && exists $M{$2}' "$S" || fail "the settings" "perl failed adding the mirrored rules; the backup is $D/settings.local.json.before"
  m=$(jq -Rn '[inputs | split("\t")] | reduce .[] as $r ({deny: {}, ask: {}}; .[$r[0]][$r[1]] = $r[2])' < "$D/mirror.tsv")
  jq -e --arg f "$RULE_FROM" --arg t "$RULE_TO" --argjson m "$m" --slurpfile b "$D/settings.local.json.before" \
    '. == ($b[0] | .permissions.allow |= map(if . == $f then $t else . end) | .permissions.deny |= [.[] | ., ($m.deny[.] // empty)] | .permissions.ask |= [.[] | ., ($m.ask[.] // empty)])' "$S" >/dev/null \
    || fail "the settings" "the file is not the old one with that rule moved and the 20 rules mirrored; the backup is $D/settings.local.json.before"
  [ "$(/usr/bin/diff "$D/settings.local.json.before" "$S" | grep -c '^<')" = 1 ] && [ "$(/usr/bin/diff "$D/settings.local.json.before" "$S" | grep -c '^>')" = 21 ] || fail "the settings" "the lines changed are not the one allow rule and the 20 added; the backup is $D/settings.local.json.before"
  echo "SETTINGS: allow $RULE_FROM is now $RULE_TO; 16 deny and 4 ask rules mirrored under ${MT%/}, each after its old one, which stays; nothing else changed"
  echo "$form" > "$D/folder.done"
  echo "FOLDER DONE: the seat's folder, its git and its memory are ready for the restart. Tell zeo-rescue: done."; exit 0;;
esac
