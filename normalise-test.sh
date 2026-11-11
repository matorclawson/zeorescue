#!/bin/bash
# normalise-test.sh: normalise-clone.sh on local repositories in a temporary folder, with a stub lsof. It touches nothing outside that folder.
set -uo pipefail
HERE=$(cd "$(dirname "$0")" && pwd -P)
T=$(mktemp -d "${TMPDIR:-/tmp}/normalise-test.XXXXXX"); T=$(cd "$T" && pwd -P)
trap 'rm -rf "$T"' EXIT
pass=0 fail=0
ok() { pass=$((pass+1)); echo "ok   $1"; }
bad() { fail=$((fail+1)); echo "FAIL $1"; }
export GIT_CONFIG_GLOBAL=/dev/null GIT_AUTHOR_NAME=t GIT_AUTHOR_EMAIL=t@t GIT_COMMITTER_NAME=t GIT_COMMITTER_EMAIL=t@t
printf '#!/bin/bash\ncat "%s/lsof.out" 2>/dev/null; exit 0\n' "$T" > "$T/lsof"; chmod +x "$T/lsof"

setup() { # a gold and a fork with one commit, and the flat clone of the fork, as the Architect read it
  rm -rf "$T/root" "$T/gold.git" "$T/fork.git" "$T/seed" "$T/lsof.out"; mkdir -p "$T/root"
  git init -q -b main "$T/seed" && echo "# dt-clipping" > "$T/seed/README.md" && git -C "$T/seed" add README.md && git -C "$T/seed" commit -qm "Initial commit"
  git clone -q --bare "$T/seed" "$T/gold.git" && git clone -q --bare "$T/seed" "$T/fork.git"
  git clone -q "$T/fork.git" "$T/root/dt-clipping"
  SHA=$(git -C "$T/seed" rev-parse HEAD)
}
N() { (cd "${CWD:-$T}" && ZEO_NORMALISE_ROOT=$T/root ZEO_NORMALISE_HEAD=${SHA:0:7} ZEO_NORMALISE_FORK=$T/fork.git ZEO_NORMALISE_GOLD=$T/gold.git ZEO_NORMALISE_LSOF=$T/lsof /bin/bash "$HERE/normalise-clone.sh"); }
same() { [ -d "$T/root/dt-clipping/.git" ] && [ ! -e "$T/root/dt-clipping/main" ] && [ ! -e "$T/root/dt-clipping.normalise" ] && [ "$(git -C "$T/root/dt-clipping" remote)" = origin ]; }

setup; ino=$(stat -f %i "$T/root/dt-clipping"); out=$(N); rc=$?
M=$T/root/dt-clipping/main W=$T/root/dt-clipping/worktrees/dt-clipping-maintainer
[ $rc = 0 ] && grep -q '^NORMALISED dt-clipping' <<< "$out" && ok "normalises" || bad "normalise: $rc $out"
[ "$(stat -f %i "$M")" = "$ino" ] && ok "main is the same folder, renamed" || bad "inode"
[ "$(git -C "$M" config remote.upstream.url)" = "$T/gold.git" ] && [ "$(git -C "$M" config remote.upstream.pushurl)" = DISABLED ] && ok "upstream is gold, push disabled" || bad "upstream"
[ "$(git -C "$M" config remote.pushdefault)" = origin ] && [ "$(git -C "$M" config remote.origin.url)" = "$T/fork.git" ] && ok "pushes go to the fork" || bad "push"
[ "$(git -C "$M" config branch.main.remote)" = upstream ] && [ "$(git -C "$M" rev-parse upstream/main)" = "$SHA" ] && ok "main tracks upstream, fetched" || bad "tracking"
[ "$(git -C "$W" rev-parse --abbrev-ref HEAD)" = dt-clipping-maintainer/home ] && [ "$(git -C "$W" rev-parse HEAD)" = "$SHA" ] && ok "the seat's worktree on its own branch" || bad "worktree"
[ "$(git -C "$W" rev-parse --path-format=absolute --git-common-dir)" = "$M/.git" ] && ok "the worktree belongs to main" || bad "common dir"
out=$(N); [ $? = 0 ] && grep -q '^ALREADY DONE' <<< "$out" && ok "a second run is ALREADY DONE" || bad "rerun: $out"
git -C "$M" config remote.upstream.pushurl x; out=$(N); [ $? = 1 ] && grep -q 'not the normalised result' <<< "$out" && ok "a changed result is not called done" || bad "changed result: $out"

setup; out=$(CWD=$T/root/dt-clipping N); [ $? = 2 ] && grep -q 'your shell is inside' <<< "$out" && same && ok "refuses when the shell is inside the clone" || bad "inside: $out"
setup; mkdir "$T/root/dt-clipping/x"; out=$(CWD=$T/root/dt-clipping/x N); [ $? = 2 ] && grep -q 'your shell is inside' <<< "$out" && ok "refuses in a folder below it too" || bad "below: $out"
setup; echo "$$" > "$T/lsof.out"; out=$(N); [ $? = 2 ] && grep -q 'processes work inside' <<< "$out" && same && ok "refuses while a process works inside" || bad "lsof: $out"
setup; touch "$T/root/dt-clipping/.DS_Store"; out=$(N); [ $? = 2 ] && grep -q 'not only .git and README.md' <<< "$out" && same && ok "refuses another file" || bad "file: $out"
setup; echo x >> "$T/root/dt-clipping/README.md"; out=$(N); [ $? = 2 ] && grep -q 'changes or ignored' <<< "$out" && same && ok "refuses a change" || bad "dirty: $out"
setup; git -C "$T/root/dt-clipping" commit -q --allow-empty -m two; out=$(N); [ $? = 2 ] && grep -q ', not ' <<< "$out" && same && ok "refuses another commit" || bad "head: $out"
setup; git -C "$T/root/dt-clipping" remote add upstream "$T/gold.git"; out=$(N); [ $? = 2 ] && grep -q 'not origin alone' <<< "$out" && ok "refuses a second remote" || bad "remote: $out"
setup; git -C "$T/root/dt-clipping" remote set-url origin "$T/gold.git"; out=$(N); [ $? = 2 ] && grep -q '^REFUSED.*origin is' <<< "$out" && ok "refuses another origin" || bad "origin: $out"
setup; git -C "$T/seed" commit -q --allow-empty -m gold2 && git -C "$T/seed" push -q "$T/gold.git" main; out=$(N); [ $? = 2 ] && grep -q "gold's main is" <<< "$out" && same && ok "refuses when gold moved on" || bad "gold: $out"
setup; rm -rf "$T/gold.git"; out=$(N); [ $? = 2 ] && grep -q 'gold could not be read' <<< "$out" && same && ok "refuses when gold cannot be read" || bad "gold unreadable: $out"
setup; mkdir "$T/root/dt-clipping.normalise"; out=$(N); [ $? = 2 ] && grep -q 'in the way' <<< "$out" && ok "refuses when its rename path is taken" || bad "in the way: $out"
setup; git -C "$T/root/dt-clipping" worktree add -q "$T/wt" -b w 2>/dev/null; out=$(N); [ $? = 2 ] && grep -q 'linked worktree' <<< "$out" && ok "refuses a linked worktree" || bad "worktree: $out"

echo "normalise-test: $pass ok, $fail fail"; [ $fail = 0 ]
