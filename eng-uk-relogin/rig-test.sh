#!/bin/bash
# rig-test.sh: ENG-POMAR-RELOGIN-2026-11-11.sh in a disposable rig on this host: a private tmux socket, a fake rollout, fake old and new
# "codex" binaries (copies of /bin/bash that hold the rollout open) and a stub rescue.sh. Only the rig's header values are rewritten;
# the body runs as written. It touches no seat, no real socket and nothing outside its temporary folder.
set -uo pipefail
HERE=$(cd "$(dirname "$0")" && pwd -P)
L=$HERE/ENG-POMAR-RELOGIN-2026-11-11.sh
R=$(mktemp -d "${TMPDIR:-/tmp}/eurig.XXXXXX"); R=$(cd "$R" && pwd -P)
SOCK=eurig$$ T=/opt/homebrew/bin/tmux
trap '"$T" -L "$SOCK" kill-server 2>/dev/null; rm -rf "$R"' EXIT
pass=0 fail=0
ok() { pass=$((pass+1)); echo "ok   $1"; }
bad() { fail=$((fail+1)); echo "FAIL $1"; }
SID=01a101bc-0986-79e1-b3bd-b3bbc2a05da2
D=$R/runtime S=$R/state ROLL=$R/sessions/rollout-x-$SID.jsonl
mkdir -p "$D" "$R/sessions" "$R/old/bin" "$R/new/bin" "$R/bin"
for b in old new; do cp /bin/bash "$R/$b/bin/codex" && codesign -s - -f "$R/$b/bin/codex" 2>/dev/null; done; ln -s "$R/new/bin/codex" "$R/bin/codex"; mkfifo "$R/fifo"
for f in seat-exec.sh session-pins folder-moves ORG-CHART.json cleanup-note.txt; do echo "$f" > "$D/$f"; done; chmod +x "$D/seat-exec.sh"
# The stub rescue.sh: --apply starts the new binary on the thread and writes an answer to the rollout; --check reads right.
cat > "$D/rescue.sh" <<EOF
echo "ARGS \$*" >> "$R/calls"
case " \$* " in
  *" --apply "*) "$T" -L "$SOCK" new-session -d -s pomar-maintainer -- "$R/new/bin/codex" -c 'exec 3>>"\$0"; read x < "$R/fifo"' "$ROLL" resume -a never --no-daemon $SID
    sleep 1; echo "RESUMED pomar: codex $SID (-a never; no gate) in pomar-maintainer"
    [ -e "$R/no-answer" ] || printf '{"timestamp":"%s","type":"response_item","payload":{"role":"assistant"}}\n' "\$(TZ=UTC date +%Y-%m-%dT%H:%M:%S.000Z)" >> "$ROLL";;
  *" --check "*) echo "check: ok 1, wrong 0";;
esac
EOF
hash_of() { shasum -a 256 "$1" | cut -d ' ' -f 1; }
make_line() { # the rig's copy: only the header values and the six expected hashes change
  perl -pe "
    s{^D=.*}{D=$D}; s{^S=.*}{S=$S}; s{^PLACE=.*}{PLACE=\"$(id -un) $(id -u) $(hostname -s)\"}; s{^SOCK=.*}{SOCK=$SOCK};
    s{^CODEX=.*}{CODEX=$R/bin/codex}; s{^NEW_VERSION=.*}{NEW_VERSION=\"\\\$(\"$R/new/bin/codex\" --version)\"}; s{^NEW_BIN=.*}{NEW_BIN=$R/new/bin/codex};
    s{^ROLL=.*}{ROLL=$ROLL}; s{^AUTH=.*}{AUTH=$R/auth.json}; s{^WAIT=.*}{WAIT=5};
  " "$L" > "$R/line.sh"
  for f in rescue.sh seat-exec.sh session-pins folder-moves ORG-CHART.json cleanup-note.txt; do
    perl -pi -e "s{ck [0-9a-f]{64} \Q$f\E}{ck $(hash_of "$D/$f") $f}" "$R/line.sh"
  done
}
start_old() { "$T" -L "$SOCK" new-session -d -s pomar-maintainer -- "$R/${1:-new}/bin/codex" -c 'exec 3>>"$0"; read x < "$1"' "$ROLL" "$R/fifo" resume -a never --no-daemon $SID; sleep 2; touch "$R/auth.json"; }
idle_roll() { printf '{"timestamp":"2026-11-11T13:31:50.966Z","type":"event_msg","payload":{"type":"task_complete","error":{"message":"x"}}}\n' > "$ROLL"; touch -t 202611111331 "$ROLL"; }
run() { (cd "$R" && ZEO_RESCUE_CODEX_SESSIONS=$R/sessions ZEO_RESCUE_ANSWER_PAUSE=1 /bin/bash -s < "$R/line.sh") 2>&1; }

make_line
# The real line, unrewritten, refuses here on its place check.
out=$(cd "$R" && /bin/bash -s < "$L" 2>&1); [ $? = 2 ] && grep -q '^WRONG PLACE' <<< "$out" && ok "the real line refuses any other place" || bad "place: $out"
grep -q 'ck af7405e29faaaeb0fa4bf2a6a1846f6ae93a3c6f17356e3d45dbcabecbc30987 rescue.sh' "$L" && ok "the line pins the staged rescue.sh af7405e2" || bad "pin"
awk '/^@@/ {f=1} END {exit f}' "$L" && ok "no placeholder is left in the line" || bad "placeholder"

echo x >> "$D/folder-moves"; out=$(run); [ $? = 2 ] && grep -q 'HASH MISMATCH.*folder-moves' <<< "$out" && ok "a changed staged file is a HASH MISMATCH" || bad "hash: $out"
echo folder-moves > "$D/folder-moves"
idle_roll
out=$(run); [ $? = 2 ] && grep -q '^DOWN' <<< "$out" && ok "a down seat is refused" || bad "down: $out"
start_old; old=$("$T" -L "$SOCK" list-panes -t =pomar-maintainer -F '#{pane_pid}')
printf '{"timestamp":"2026-11-11T16:00:00Z","type":"response_item"}\n' >> "$ROLL"; touch -t 202611111331 "$ROLL"
out=$(run); [ $? = 2 ] && grep -q '^BUSY.*not the end of a turn' <<< "$out" && ok "a turn in progress is BUSY" || bad "busy: $out"
idle_roll; touch "$ROLL"; out=$(run); [ $? = 2 ] && grep -q '^BUSY.*written' <<< "$out" && ok "a rollout written just now is BUSY" || bad "busy2: $out"
idle_roll; (exec 3>>"$ROLL"; sleep 4) & other=$!; sleep 1
out=$(run); [ $? = 2 ] && grep -q 'not pid .* alone' <<< "$out" && ok "a second holder of the rollout is refused" || bad "holder: $out"
wait $other
mv "$R/bin/codex" "$R/bin/x"; ln -s "$R/old/bin/codex" "$R/bin/codex"; out=$(run); [ $? = 2 ] && grep -q '^REFUSED.*not' <<< "$out" && ok "an installed Codex other than the expected one is refused" || bad "version: $out"
rm "$R/bin/codex"; mv "$R/bin/x" "$R/bin/codex"
alive_old=$(kill -0 "$old" 2>/dev/null && echo yes); [ "$alive_old" = yes ] && [ ! -e "$R/calls" ] && ok "every refusal left the seat running and ran nothing" || bad "refusals touched it"

idle_roll; touch -t 202611110000 "$R/auth.json"; out=$(run); [ $? = 0 ] && grep -q "^ALREADY DONE" <<< "$out" && [ ! -e "$R/calls" ] && ok "a process started after the login is ALREADY DONE" || bad "after login: $out"
"$T" -L "$SOCK" kill-server; sleep 1; start_old old; old=$("$T" -L "$SOCK" list-panes -t =pomar-maintainer -F "#{pane_pid}"); out=$(run); [ $? = 2 ] && grep -q "not $R/new/bin/codex" <<< "$out" && ok "a seat still on the old binary is refused" || bad "old bin: $out"
"$T" -L "$SOCK" kill-server; sleep 1; start_old; old=$("$T" -L "$SOCK" list-panes -t =pomar-maintainer -F "#{pane_pid}")
idle_roll; touch "$R/auth.json"; sleep 1; out=$(run); rc=$?
[ $rc = 0 ] && grep -q '^RELOGIN pomar' <<< "$out" && grep -q '^IDLE pomar' <<< "$out" && grep -q '^STOPPED pomar' <<< "$out" && grep -q '^ANSWERED pomar (codex)' <<< "$out" && ok "upgrade: stops, resumes, checks and sees the answer" || bad "upgrade: $rc $out"
! kill -0 "$old" 2>/dev/null && ok "the old process is gone" || bad "old alive"
grep -qxF "ARGS --host ENG-UK --chart $D/ORG-CHART.json --note-file $S/relogin-note.txt --no-loader --apply --seat pomar" "$R/calls" && grep -q -- '--no-loader --check --seat pomar' "$R/calls" && ok "rescue.sh runs as 7 Nov line 2, with the upgrade note" || bad "args: $(cat "$R/calls")"
[ "$(hash_of "$S/relogin-note.txt")" = de90ae394013498f3d61a15a75e443522d8a46c7f41acf0d2e1fad94f8f711c2 ] && [ "$(hash_of "$S/model-answered.sh")" = ec8a6f65e245aac98a2c34ef84ecd2f8926b041b150bbdaac83f32fdc5d925d1 ] && [ "$(stat -f %Lp "$S")" = 700 ] && ok "the note and model-answered.sh are written byte for byte, folder mode 700" || bad "files"
ls "$S"/relogin-*.log >/dev/null 2>&1 && ok "the run keeps its log" || bad "log"

: > "$R/calls"; idle_roll; out=$(run); [ $? = 0 ] && grep -q '^ALREADY DONE' <<< "$out" && [ ! -s "$R/calls" ] && ok "run again: ALREADY DONE, nothing run" || bad "again: $out"

"$T" -L "$SOCK" kill-server 2>/dev/null; sleep 1; start_old; idle_roll; touch "$R/no-answer"; out=$(run); rc=$?
[ $rc = 2 ] && grep -q '^WAITING pomar' <<< "$out" && grep -q '^NOT FINISHED' <<< "$out" && ok "no answer within the wait is WAITING, exit 2, and says so" || bad "waiting: $rc $out"
echo "rig-test: $pass ok, $fail fail"; [ $fail = 0 ]
