#!/bin/bash
# dt-clipping-move-test.sh: dt-clipping-move.sh in a temporary copy, with a stub rescue.sh and model-answered.sh and local repositories.
# It touches no seat, no real config and nothing outside its temporary folder.
set -uo pipefail
HERE=$(cd "$(dirname "$0")" && pwd -P)
T=$(mktemp -d "${TMPDIR:-/tmp}/mvtest.XXXXXX"); T=$(cd "$T" && pwd -P); trap 'rm -rf "$T"' EXIT
pass=0 fail=0
ok() { pass=$((pass+1)); echo "ok   $1"; }
bad() { fail=$((fail+1)); echo "FAIL $1"; }
export GIT_CONFIG_GLOBAL=/dev/null GIT_AUTHOR_NAME=t GIT_AUTHOR_EMAIL=t@t GIT_COMMITTER_NAME=t GIT_COMMITTER_EMAIL=t@t
mkdir -p "$T/run/notes" "$T/state"
cp "$HERE/dt-clipping-move.sh" "$T/run/"; cp "$HERE/notes/dt-clipping-move-20261111.txt" "$T/run/notes/"
cat > "$T/run/rescue.sh" <<EOF
#!/bin/bash
echo "ARGS \$*" >> "$T/calls"; echo "ENV \$ZEO_RESCUE_MOVES \$ZEO_RESCUE_PINS" >> "$T/calls"
case " \$* " in *" --apply "*) echo "RESUMED dt-clipping-maintainer: codex x in y"; exit 0;; *" --check "*) cat "$T/check.out"; exit 0;; esac
cat "$T/plan.out"
EOF
printf '#!/bin/bash\necho "ANSWERED dt-clipping-maintainer (codex)"; echo "MA $*" >> "%s/calls"\n' "$T" > "$T/run/model-answered.sh"
chmod +x "$T/run/"*.sh
M=$T/c/dt-clipping/main W=$T/c/dt-clipping/worktrees/dt-clipping-maintainer
git init -q -b main "$M" && echo x > "$M/README.md" && git -C "$M" add README.md && git -C "$M" commit -qm init
mkdir -p "$T/c/dt-clipping/worktrees" && git -C "$M" worktree add -q -b dt-clipping-maintainer/home "$W" main
printf '[projects."/elsewhere"]\ntrust_level = "trusted"\n' > "$T/config.toml"
X() { (ZEO_RESCUE_STATE=$T/state ZEO_RESCUE_CODEX_CONFIG=$T/config.toml ZEO_MOVE_MAIN=$M ZEO_MOVE_TO=$W ZEO_RESCUE_ANSWER_WAIT=7 "$T/run/dt-clipping-move.sh" "$@"); }
PLAN_OK="RESEAT dt-clipping-maintainer: codex 01a16ed4 (-a never; marker master, recorded) in dt-clipping-maintainer
MOVE dt-clipping-maintainer: from /old/tldw to $W
rescue: to reseat 1"

out=$(X); [ $? = 2 ] && grep -q usage <<< "$out" && ok "no step is usage" || bad "usage: $out"
echo "$PLAN_OK" > "$T/plan.out"; out=$(X first); [ $? = 2 ] && grep -q 'no trusted entry' <<< "$out" && [ ! -e "$T/calls" ] && ok "first refuses before trust" || bad "first before trust: $out"
cp "$T/config.toml" "$T/orig"; out=$(X trust); rc=$?
[ $rc = 0 ] && grep -q '^ADDED' <<< "$out" && grep -qxF "[projects.\"$W\"]" "$T/config.toml" && grep -qxF "[projects.\"$M\"]" "$T/config.toml" && ok "trust adds the worktree and its repository" || bad "trust: $rc $out"
cmp -s "$T/orig" "$T/state/codex-config.before-dt-clipping-move" && [ "$(stat -f %Lp "$T/state/codex-config.before-dt-clipping-move")" = 600 ] && ok "backup is the old file, mode 600" || bad "backup"
head -2 "$T/config.toml" | grep -q elsewhere && ok "the rest of the file is kept" || bad "kept"
out=$(X trust); [ $? = 0 ] && grep -q 'NOTHING TO ADD' <<< "$out" && ok "trust again changes nothing" || bad "trust again: $out"
printf '[projects."%s"]\ntrust_level = "untrusted"\n' "$M" > "$T/config.toml"; out=$(X trust); [ $? = 2 ] && grep -q 'not trusted' <<< "$out" && ok "trust refuses an untrusted entry" || bad "untrusted: $out"
cp "$T/orig" "$T/config.toml"; rm -f "$T/state/"*; X trust >/dev/null
git -C "$W" switch -q -c other; out=$(X first); [ $? = 2 ] && grep -q "is not on dt-clipping-maintainer/home" <<< "$out" && ok "first refuses another branch" || bad "branch: $out"
out=$(X trust); [ $? = 2 ] && grep -q 'Run the normalise line first' <<< "$out" && ok "trust refuses a worktree not as normalised" || bad "trust branch: $out"
git -C "$W" switch -q dt-clipping-maintainer/home
echo "OK dt-clipping-maintainer: started by rescue, right already" > "$T/plan.out"; out=$(X first); [ $? = 0 ] && grep -q 'ALREADY DONE' <<< "$out" && ! grep -q -- --apply "$T/calls" && ok "a moved seat is ALREADY DONE" || bad "done: $out"
printf '%s\nWORK dt-clipping-maintainer: a turn is in progress on its screen\n' "$PLAN_OK" > "$T/plan.out"; out=$(X first); [ $? = 2 ] && grep -q '^BUSY' <<< "$out" && ! grep -q -- --apply "$T/calls" && ok "first refuses a busy seat" || bad "busy: $out"
printf 'RESEAT dt-clipping-maintainer: codex x in y\n' > "$T/plan.out"; out=$(X first); [ $? = 2 ] && grep -q 'not this one move' <<< "$out" && ! grep -q -- --apply "$T/calls" && ok "first refuses a restart without the move" || bad "no move: $out"
printf 'UNRESOLVED dt-clipping-maintainer: x\n' > "$T/plan.out"; out=$(X first); [ $? = 2 ] && ! grep -q -- --apply "$T/calls" && ok "first refuses an unresolved plan" || bad "unresolved: $out"
echo "$PLAN_OK" > "$T/plan.out"; printf 'OK dt-clipping-maintainer (codex)\ncheck: ok 1, wrong 0\n' > "$T/check.out"; : > "$T/calls"; out=$(X first); rc=$?
[ $rc = 0 ] && grep -q '^ANSWERED' <<< "$out" && ok "first moves, checks and waits for the answer" || bad "first: $rc $out"
grep -qxF "ARGS --reseat --relaunch --apply --harness codex --seat dt-clipping-maintainer --note-file notes/dt-clipping-move-20261111.txt" "$T/calls" && ok "one seat, with its note" || bad "args: $(cat "$T/calls")"
grep -qxF "ENV $T/run/dt-clipping-move.moves $T/run/dt-clipping-move.pins" "$T/calls" && ok "rescue.sh reads the move's own line and pin" || bad "env: $(cat "$T/calls")"
grep -q "^MA $T/state/dt-clipping-move-.*\.log 7$" "$T/calls" && ls "$T/state"/dt-clipping-move-*.log >/dev/null && ok "the answer check reads the move's own log" || bad "ma: $(cat "$T/calls")"
printf 'WRONG dt-clipping-maintainer (codex): x\ncheck: ok 0, wrong 1\n' > "$T/check.out"; out=$(X clear); [ $? = 2 ] && [ -e "$T/state/codex-config.before-dt-clipping-move" ] && ok "clear waits for a right check" || bad "clear early: $out"
printf 'check: ok 1, wrong 0\n' > "$T/check.out"; out=$(X clear); [ $? = 0 ] && [ ! -e "$T/state/codex-config.before-dt-clipping-move" ] && ok "clear deletes the backup" || bad "clear: $out"
echo "dt-clipping-move-test: $pass ok, $fail fail"; [ $fail = 0 ]
