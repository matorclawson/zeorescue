#!/bin/bash
# normalise-clone.sh: the new flat dt-clipping clone becomes <org>/dt-clipping/main, with gold as upstream and the fork as the push remote, and
# gets worktrees/dt-clipping-maintainer for the seat (the Architect's ruling C, 11 Nov 2026). It moves no seat and starts nothing.
# Run once; a second run that finds the result reads ALREADY DONE and changes nothing.
#
#   1. Refuses, having changed nothing, unless the clone is exactly the one the Architect read: README.md and .git only, main at HEAD_SHA,
#      clean, no stash, no worktree, origin the fork and no other remote. It refuses while any process works inside it, the caller included.
#   2. Reads gold's main before anything changes: it must be HEAD_SHA.
#   3. Renames the folder to <name>/main (the same volume, so it is the same folder), then sets upstream = gold with push DISABLED,
#      remote.pushdefault = origin, main tracking upstream, and fetches upstream.
#   4. Adds worktrees/SEAT on a new branch SEAT/home from upstream/main.
# Exit: 0 done or already done; 1 a step failed (the output says what changed); 2 refused, nothing changed.
set -uo pipefail
ROOT=${ZEO_NORMALISE_ROOT:-/Volumes/AIPEMedia1/code/ducktyper-ai}
NAME=dt-clipping
SEAT=dt-clipping-maintainer
BRANCH=$SEAT/home
HEAD_SHA=${ZEO_NORMALISE_HEAD:-be40b69}
FORK=${ZEO_NORMALISE_FORK:-git@github.com:matorclawson/dt-clipping.git}
GOLD=${ZEO_NORMALISE_GOLD:-git@github.com:rodriveracom/dt-clipping.git}
LSOF=${ZEO_NORMALISE_LSOF:-/usr/sbin/lsof}
F=$ROOT/$NAME M=$ROOT/$NAME/main W=$ROOT/$NAME/worktrees/$SEAT
no() { echo "REFUSED, nothing was changed: $*"; exit 2; }
die() { echo "FAILED: $*"; exit 1; }
g() { git -C "$@"; }

inside() { case "$1/" in "$F"/*) return 0;; esac; return 1; }
here=$(pwd -P 2>/dev/null || echo /)
if inside "${PWD:-/}" || inside "$here"; then no "your shell is inside $F; cd out of it (cd ~) and run the line again"; fi

# Done already?
if [ -d "$M/.git" ] && [ -d "$W" ]; then
  [ "$(g "$M" config remote.upstream.url)" = "$GOLD" ] && [ "$(g "$M" config remote.upstream.pushurl)" = DISABLED ] \
    && [ "$(g "$M" config remote.origin.url)" = "$FORK" ] && [ "$(g "$M" config remote.pushdefault)" = origin ] \
    && [ "$(g "$W" rev-parse --abbrev-ref HEAD)" = "$BRANCH" ] \
    && [ "$(g "$W" rev-parse --path-format=absolute --git-common-dir)" = "$M/.git" ] \
    || die "$M and $W exist but are not the normalised result; nothing was changed, bring this to zeo-rescue"
  echo "ALREADY DONE: $M (upstream gold, push to the fork) and $W on $BRANCH; nothing was changed"; exit 0
fi

# 1. The clone as read.
[ -d "$F" ] && [ ! -L "$F" ] || no "$F is not a folder"
[ -d "$F/.git" ] && [ ! -L "$F/.git" ] || no "$F/.git is not a .git folder"
items=$(cd "$F" && ls -A | LC_ALL=C sort | tr '\n' ' ')
[ "$items" = ".git README.md " ] || no "$F holds ${items:-nothing}, not only .git and README.md"
full=$(g "$F" rev-parse --verify -q "$HEAD_SHA^{commit}") || no "$HEAD_SHA is not a commit in $F"
[ "$(g "$F" rev-parse HEAD)" = "$full" ] || no "$F is at $(g "$F" rev-parse --short HEAD), not $HEAD_SHA"
[ "$(g "$F" symbolic-ref -q --short HEAD)" = main ] || no "$F is not on main"
[ -z "$(g "$F" status --porcelain --ignored)" ] || no "$F has changes or ignored files"
[ -z "$(g "$F" stash list)" ] || no "$F has a stash"
[ "$(g "$F" worktree list --porcelain | grep -c '^worktree ')" = 1 ] || no "$F has a linked worktree"
[ "$(g "$F" remote | tr '\n' ' ')" = "origin " ] || no "$F has remotes '$(g "$F" remote | tr '\n' ' ')', not origin alone"
[ "$(g "$F" config remote.origin.url)" = "$FORK" ] || no "origin is $(g "$F" config remote.origin.url), not $FORK"
[ ! -e "$ROOT/$NAME.normalise" ] && [ ! -L "$ROOT/$NAME.normalise" ] || no "$ROOT/$NAME.normalise is in the way"
procs=$("$LSOF" -t +D "$F" 2>/dev/null | sort -u | tr '\n' ' ')
[ -z "$procs" ] || no "processes work inside $F (pids ${procs% }): close or cd them out first; ps -p ${procs% } -o pid,tty,command shows them"

# 2. Gold, read before anything changes.
gm=$(git ls-remote "$GOLD" refs/heads/main 2>&1) || no "gold could not be read: $gm"
[ "${gm%%[[:space:]]*}" = "$full" ] || no "gold's main is ${gm%%[[:space:]]*}, not $full"
echo "READ $NAME: main at ${full:0:7}, origin $FORK, gold main at ${full:0:7}"

# 3. The folder becomes <name>/main.
ino=$(stat -f %i "$F")
mv "$F" "$ROOT/$NAME.normalise" || die "the first rename failed; nothing was changed"
mkdir "$F" || { mv "$ROOT/$NAME.normalise" "$F"; die "could not make $F; the clone is back as it was"; }
mv "$ROOT/$NAME.normalise" "$M" || { rmdir "$F"; mv "$ROOT/$NAME.normalise" "$F"; die "could not rename into $M; the clone is back as it was"; }
[ "$(stat -f %i "$M")" = "$ino" ] || die "$M is not the same folder after the rename"
echo "MOVED $NAME: $F is now $M (the same folder)"
g "$M" remote add upstream "$GOLD" && g "$M" config remote.upstream.pushurl DISABLED && g "$M" config remote.pushdefault origin \
  && g "$M" config branch.main.remote upstream && g "$M" config branch.main.merge refs/heads/main \
  || die "setting the remotes failed in $M; the folder is moved, its remotes are part set"
g "$M" fetch -q --no-tags upstream || die "fetching upstream failed in $M; the folder is moved and its remotes are set"
[ "$(g "$M" rev-parse upstream/main)" = "$full" ] || die "upstream/main is not $full after the fetch"
echo "REMOTES $NAME: upstream $GOLD (push DISABLED), origin $FORK (push default), main tracks upstream/main"

# 4. The seat's worktree.
mkdir -p "$ROOT/$NAME/worktrees" || die "could not make $ROOT/$NAME/worktrees"
g "$M" worktree add -q -b "$BRANCH" "$W" upstream/main || die "git worktree add failed for $W"
[ "$(g "$W" rev-parse HEAD)" = "$full" ] && [ "$(g "$W" rev-parse --abbrev-ref HEAD)" = "$BRANCH" ] || die "$W is not on $BRANCH at $full"
echo "WORKTREE $SEAT: $W on $BRANCH at ${full:0:7}"
echo "NORMALISED $NAME: the seat is not moved; its move into $W comes by its own line"
