#!/bin/bash
# Real tmux, real ps, the real ~/.zshrc seat loader, on a private socket, with fake harnesses. No seat is touched: the fake programs
# only write down what they were given. rescue-test.sh proves the decisions with stubs; this proves tmux and the loader really do
# what those decisions assume. It needs /opt/homebrew/bin/tmux and the host's seat loader, so it runs here and not in CI.
set -uo pipefail
HERE=$(cd "$(dirname "$0")" && pwd -P)
T=$(cd "$(mktemp -d /tmp/zr.XXXXXX)" && pwd -P); SOCK=zrt$$
TM=/opt/homebrew/bin/tmux
trap '"$TM" -L "$SOCK" kill-server 2>/dev/null; rm -rf "$T"' EXIT
fails=0
ok()   { echo "ok   $1"; }
bad()  { echo "FAIL $1"; fails=$((fails+1)); }
mkdir -p "$T/w/cl" "$T/w/cx" "$T/projects" "$T/snap" "$T/sess" "$T/state" "$T/bin"
mkdir -p "$T/h"
for h in claude codex; do
  # a copy of a Homebrew binary, blocking on the terminal: macOS hides the environment of Apple-signed programs such as sleep from ps -E
  cp /opt/homebrew/bin/jq "$T/h/$h"
  cat > "$T/bin/$h" <<S
#!/bin/sh
env | sort > "$T/env.\$ZMAIL_INSTANCE"
printf '%s\n' "\$@" > "$T/args.\$ZMAIL_INSTANCE"
[ "$h" = codex ] && /bin/zsh -ic 'env' </dev/null 2>/dev/null | sed 's/^/export /' > "$T/snap/44444444-4444-4444-8444-444444444444.\$\$.sh"
[ -f "$T/badid" ] && [ "$h" = codex ] && sed -i "" -e "s/ZMAIL_INSTANCE=.*/ZMAIL_INSTANCE=other/" "$T/snap/44444444-4444-4444-8444-444444444444.\$\$.sh"
if [ "$h" = codex ]; then sleep 300; else exec "$T/h/$h" --arg a "\$*" .; fi
S
  chmod +x "$T/bin/$h"
done
cat > "$T/bin/sqlite3" <<S
#!/bin/sh
echo "$T/sess/full.jsonl"
S
chmod +x "$T/bin/sqlite3"
{ printf '{"type":"session_meta","payload":{"id":"44444444-4444-4444-8444-444444444444","cwd":"%s"}}\n' "$T/w/cx"
  echo '{"type":"turn_context","payload":{"approval_policy":"never","sandbox_policy":{"type":"danger-full-access"}}}'; } > "$T/sess/full.jsonl"
enc() { printf %s "$1" | LC_ALL=C sed 's/[^A-Za-z0-9]/-/g'; }
d=$T/projects/$(enc "$T/w/cl"); mkdir -p "$d"; printf '{"sessionId":"22222222-2222-4222-8222-222222222222","cwd":"%s","permissionMode":"auto"}\n' "$T/w/cl" > "$d/22222222-2222-4222-8222-222222222222.jsonl"
printf 'tc master 22222222-2222-4222-8222-222222222222\ntx master 44444444-4444-4444-8444-444444444444\n' > "$T/seed"
row() { printf '{"seat_id":"%s","mailbox":"%s","desired_agent":"%s","desired_host":"h","desired_tmux":{"session":"%s"},"desired_folder":"%s"}' "$1" "$1" "$2" "$3" "$4"; }
echo "{\"seats\":[$(row tc claude tc-s "$T/w/cl"),$(row tx codex tx-s "$T/w/cx")]}" > "$T/chart.json"
export ZEO_RESCUE_PINS=$T/none ZEO_RESCUE_STATE=$T/state ZEO_RESCUE_PROJECTS=$T/projects ZEO_RESCUE_CODEX_DB=$T/db ZEO_RESCUE_SNAPSHOTS=$T/snap \
  ZEO_RESCUE_SQLITE=$T/bin/sqlite3 ZEO_RESCUE_CLAUDE=$T/bin/claude ZEO_RESCUE_CODEX=$T/bin/codex ZEO_RESCUE_KILL=/usr/bin/true ZEO_RESCUE_PROOF_TRIES=20 ZEO_RESCUE_PROOF_PAUSE=0.5 ZEO_RESCUE_CLAUDE_SESSIONS=$T/none ZEO_RESCUE_ROLLOUT_TRIES=3
R() { "$HERE/rescue.sh" --host h --socket "$SOCK" --stagger 0 --chart "$T/chart.json" --seed "$T/seed" "$@"; }

echo "-- a dead seat comes up through real tmux and the real loader"
out=$(R --apply 2>&1); rc=$?
echo "$out" | sed 's/^/     /' | cut -c1-140
[ $rc -eq 0 ] && ok "rescue exits 0" || bad "exit $rc"
echo "$out" | grep -q 'SEAT OK tc: own identity, marker master, git on' && ok "the claude path proves itself from the live process" || bad "claude proof"
echo "$out" | grep -q 'SEAT OK tx: own identity, marker master, git on' && ok "the codex path proves itself from a snapshot" || bad "codex proof"
grep -q '^ZEO_TMUX_SEAT=master$' "$T/env.tc" && ok "the seat loader saw the pane marker on its first run" || bad "loader: $(grep ZEO_TMUX "$T/env.tc")"
grep -q '^GIT_ALLOW_PROTOCOL=file$' "$T/env.tc" && bad "git is off" || ok "git is on"
grep -q '^CLAUDECODE=' "$T/env.tc" && bad "the rescuer's environment leaked into the seat" || ok "the rescuer's environment did not leak"
grep -qx -- '--no-daemon' "$T/args.tx" && ok "codex got --no-daemon" || bad "no --no-daemon"
[ "$("$TM" -L "$SOCK" list-panes -s -t '=tc-s' -F '#{@zeo_seat} #{@zeo_rescue}')" = "master 1" ] && ok "the pane carries both options" || bad "pane options"
tail -1 "$T/args.tc" | grep -q 'You were restarted' && ok "the prompt arrives as one argument" || bad "prompt"
out=$(R --check 2>&1); rc=$?
[ $rc -eq 0 ] && ok "--check passes them" || bad "check: $out"

echo "-- a live seat started the wrong way is reseated"
"$TM" -L "$SOCK" kill-session -t '=tc-s'
"$TM" -L "$SOCK" new-session -d -s tc-s -c "$T/w/cl" -- "$T/bin/claude" --resume 22222222-2222-4222-8222-222222222222
"$TM" -L "$SOCK" new-window -d -t '=tc-s' -- sleep 300
perl -e 'select(undef,undef,undef,0.5)'
rm -f "$T/env.tc"
out=$(R --reseat --apply --seat tc 2>&1); rc=$?
echo "$out" | sed 's/^/     /' | cut -c1-140
[ $rc -eq 0 ] && ok "reseat exits 0" || bad "reseat exit $rc"
[ "$(pgrep -f -- "$T/h/claude .*22222222-2222-4222-8222-222222222222" | wc -l | tr -d ' ')" = 1 ] && ok "only one process holds the session" || bad "two holders"
grep -q '^ZEO_TMUX_SEAT=master$' "$T/env.tc" && ok "the reseated seat has its marker" || bad "reseat marker"
[ "$("$TM" -L "$SOCK" list-panes -s -t '=tc-s' | wc -l | tr -d ' ')" = 2 ] && ok "the side window survived" || bad "side window"
grep -q '^OK tc: started by rescue' <<< "$(R --reseat --seat tc 2>&1)" && ok "a second reseat leaves it alone" || bad "second reseat"

echo "-- a seat that fails its proof goes back to sleep, and the next run takes it"
pane=$("$TM" -L "$SOCK" list-panes -s -t '=tx-s' -F '#{pane_id}' | head -1)
"$TM" -L "$SOCK" set-option -pu -t "$pane" @zeo_rescue
touch "$T/badid"
out=$(R --reseat --apply --seat tx 2>&1); rc=$?
echo "$out" | sed 's/^/     /' | cut -c1-140
[ $rc -eq 1 ] && echo "$out" | grep -q 'STOPPED: tx did not get its own identity' && ok "a wrong identity stops the run" || bad "proof: $rc"
echo "$out" | grep -q '^RECOVERY: 1 planned seats' && ok "and says what is down" || bad "recovery"
perl -e 'select(undef,undef,undef,0.3)'
[ "$("$TM" -L "$SOCK" list-panes -s -t '=tx-s' -F '#{pane_current_command}|#{@zeo_rescue}' | head -1)" = "sleep|" ] && ok "the wrong seat is back on a sleep, with no rescue mark" || bad "pane: $("$TM" -L "$SOCK" list-panes -s -t '=tx-s' -F '#{pane_current_command}|#{@zeo_rescue}')"
grep -q '^RESEAT tx:' <<< "$(R --reseat --seat tx 2>&1)" && ok "the next plan takes it, not skips it" || bad "replan"
grep -q '^WRONG tx' <<< "$(R --check --seat tx 2>&1)" && ok "--check names it wrong meanwhile" || bad "check while down"

echo "-- real lsof sees what holds a rollout"
rm -f "$T/badid"
sleep 60 < "$T/sess/full.jsonl" & holder=$!
perl -e 'select(undef,undef,undef,0.3)'
out=$(ZEO_RESCUE_ROLLOUT_TRIES=2 R --reseat --apply --seat tx 2>&1); rc=$?
echo "$out" | sed 's/^/     /' | cut -c1-140
echo "$out" | grep -q "^FAILED tx: rollout release is not proved (holder: $holder)" && ok "a real holder refuses the start" || bad "holder $holder"
kill "$holder" 2>/dev/null; wait "$holder" 2>/dev/null
out=$(R --reseat --apply --seat tx 2>&1); rc=$?
echo "$out" | sed 's/^/     /' | cut -c1-140
[ $rc -eq 0 ] && echo "$out" | grep -q 'SEAT OK tx' && ok "with nothing holding it the same line brings the seat back" || bad "recovered: $rc"
out=$(R --check --seat tx 2>&1); [ $? -eq 0 ] && ok "and --check passes it" || bad "check after: $out"
echo; [ $fails -eq 0 ] && echo "PASS" || { echo "$fails FAILED"; exit 1; }
