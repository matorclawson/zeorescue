#!/bin/bash
# Hermetic: every external tool is a stub in a temp directory, and nothing touches a real tmux server, transcript or database.
set -uo pipefail
HERE=$(cd "$(dirname "$0")" && pwd -P)
T=$(mktemp -d); trap 'rm -rf "$T"' EXIT
fails=0
ok()   { echo "ok   $1"; }
bad()  { echo "FAIL $1"; fails=$((fails+1)); }
mkdir -p "$T/bin" "$T/projects" "$T/state" "$T/w/cl" "$T/w/cl2" "$T/w/cx" "$T/w/cxw" "$T/w/cxi" "$T/w/cxn" "$T/w/none" "$T/sess" "$T/snap"
# The tmux stub keeps a list of live sessions, and a pane per session in $T/panes (session|id|pid|opt|cmd) when a test wants one.
cat > "$T/bin/tmux" <<S
#!/bin/bash
echo "\$*" >> "$T/tmux.log"
case "\$3" in
  has-session) grep -qxF "\${5#=}" "$T/live" 2>/dev/null ;;
  new-session) printf '%s\n' "\$*" >> "$T/launched"; echo "\$6" >> "$T/live" ;;
  list-panes)  s=\${6#=}; if grep -q "^\$s|" "$T/panes" 2>/dev/null; then grep "^\$s|" "$T/panes" | cut -d'|' -f2-; else echo "%\$s|9|1|sleep"; fi ;;
  set-option)  printf '%s\n' "\$*" >> "$T/opts" ;;
  capture-pane) cat "$T/screen" 2>/dev/null ;;
  respawn-pane) printf '%s\n' "\$*" >> "$T/launched"
    case "\$*" in *" resume "*--no-daemon*) id=\${@: -1}; if [ -f "$T/snapwrite" ]; then cp "$T/snapwrite" "$T/snap/\$id.new.sh"; fi ;; esac ;;
esac
exit \$?
S
cat > "$T/bin/ps" <<S
#!/bin/bash
case "\$1" in
  -Ewwp) cat "$T/psE.out" 2>/dev/null ;;
  *) cat "$T/ps.out" 2>/dev/null ;;
esac
exit 0
S
cat > "$T/bin/lsof" <<S
#!/bin/bash
cat "$T/lsof.out" 2>/dev/null
S
cat > "$T/bin/kill" <<S
#!/bin/bash
echo "\$*" >> "$T/kills"
S
cat > "$T/bin/sqlite3" <<S
#!/bin/bash
case "\$2" in
  *"$T/w/cx'"*|*"44444444-4444-4444-8444-444444444444"*)  printf '%s %s\n' 44444444-4444-4444-8444-444444444444 "$T/sess/full.jsonl" ;;
  *"$T/w/cxw'"*) printf '%s %s\n' 55555555-5555-4555-8555-555555555555 "$T/sess/write.jsonl" ;;
  *"$T/w/cxi'"*) printf '%s %s\n' 66666666-6666-4666-8666-666666666666 "$T/sess/full.jsonl" ;;
  *"$T/w/cxn'"*) printf '%s %s\n' 77777777-7777-4777-8777-777777777777 "$T/sess/full.jsonl" ;;
esac
S
chmod +x "$T/bin/"*
: > "$T/ps.out"; : > "$T/lsof.out"; : > "$T/psE.out"
echo '{"type":"turn_context","approval_policy":"never","sandbox_policy":{"type":"danger-full-access"}}' > "$T/sess/full.jsonl"
echo '{"type":"turn_context","approval_policy":"never","sandbox_policy":{"type":"workspace-write"}}' > "$T/sess/write.jsonl"
printf 'export ZEO_TMUX_SEAT=master\nexport ZMAIL_INSTANCE=cx\nexport GIT_ALLOW_PROTOCOL=ssh:https:file\n' > "$T/snap/44444444-4444-4444-8444-444444444444.1.sh"
printf 'export ZEO_TMUX_SEAT=inactive\nexport ZMAIL_INSTANCE=cxi\nexport GIT_ALLOW_PROTOCOL=file\n' > "$T/snap/66666666-6666-4666-8666-666666666666.1.sh"
touch -t 202601010000 "$T/snap/44444444-4444-4444-8444-444444444444.1.sh"
enc() { printf %s "$1" | LC_ALL=C sed 's/[^A-Za-z0-9]/-/g'; }
d=$T/projects/$(enc "$T/w/cl"); mkdir -p "$d"
echo '{"permissionMode":"plan"}'  > "$d/11111111-1111-4111-8111-111111111111.jsonl"
echo '{"permissionMode":"auto"}'  > "$d/22222222-2222-4222-8222-222222222222.jsonl"
touch -t 202601010000 "$d/11111111-1111-4111-8111-111111111111.jsonl"
d2=$T/projects/$(enc "$T/w/cl2"); mkdir -p "$d2"
echo '{"nothing":"here"}' > "$d2/33333333-3333-4333-8333-333333333333.jsonl"
row() { printf '{"seat_id":"%s","mailbox":"%s","desired_agent":"%s","desired_host":"%s","desired_tmux":{"session":"%s"},"desired_folder":"%s"}' "$@"; }
cat > "$T/chart.json" <<J
{"seats":[
 $(row cl cl claude h cl-maintainer "$T/w/cl"),
 $(row nomode nomode claude h nomode-s "$T/w/cl2"),
 $(row cx cx codex h cx-maintainer "$T/w/cx"),
 $(row cxw cxw codex h cxw-s "$T/w/cxw"),
 $(row cxi cxi codex h cxi-s "$T/w/cxi"),
 $(row cxn cxn codex h cxn-s "$T/w/cxn"),
 $(row alias other codex h alias-s "$T/w/cx"),
 $(row nothread nothread codex h nothread-s "$T/w/none"),
 $(row elsewhere elsewhere claude ENG-UK e-s "$T/w/cl"),
 $(row zeo-rescue zeo-rescue claude h zeo-rescue "$T/w/cl"),
 {"seat_id":"disposable","mailbox":"x","desired_agent":null,"desired_host":null,"desired_tmux":null,"desired_folder":""}
]}
J
export ZEO_RESCUE_PINS="$T/no-pins" ZEO_RESCUE_STATE="$T/state" ZEO_RESCUE_PROJECTS="$T/projects" ZEO_RESCUE_CODEX_DB="$T/db" ZEO_RESCUE_TMUX="$T/bin/tmux" ZEO_RESCUE_SNAPSHOTS="$T/snap" \
  ZEO_RESCUE_SQLITE="$T/bin/sqlite3" ZEO_RESCUE_PS="$T/bin/ps" ZEO_RESCUE_LSOF="$T/bin/lsof" ZEO_RESCUE_KILL="$T/bin/kill" ZEO_RESCUE_CLAUDE=/x/claude ZEO_RESCUE_CODEX=/x/codex \
  ZEO_RESCUE_PROOF_TRIES=2 ZEO_RESCUE_PROOF_PAUSE=0 ZEO_RESCUE_STOP_TRIES=2 ZEO_RESCUE_DAEMON_WAIT=0
R() { "$HERE/rescue.sh" --host h --stagger 0 --chart "$T/chart.json" "$@"; }

echo "-- the plan"
out=$(R 2>&1); rc=$?
[ ! -e "$T/launched" ] && ok "a plan starts nothing" || bad "a plan started something"
[ $rc -eq 3 ] && ok "UNRESOLVED seats exit 3" || bad "exit $rc, want 3"
echo "$out" | grep -q '^RESUME cl: claude 22222222-2222-4222-8222-222222222222 (--permission-mode auto; marker master, no record, default) in cl-maintainer' && ok "newest transcript, its recorded mode, the chart's session label" || bad "claude plan: $out"
echo "$out" | grep -q '^RESUME cx: codex 44444444-4444-4444-8444-444444444444 (-a never -s danger-full-access; marker master, recorded)' && ok "a codex seat gets its own recorded mode and marker" || bad "codex plan: $out"
echo "$out" | grep -q '^RESUME cxw: codex 55555555-5555-4555-8555-555555555555 (-a never -s workspace-write; no marker, no record, workspace-write)' && ok "a workspace-write seat with no record gets no marker" || bad "workspace-write: $out"
echo "$out" | grep -q '^RESUME cxi: .*no marker, recorded inactive' && ok "a seat recorded inactive stays inactive" || bad "inactive: $out"
echo "$out" | grep -q '^RESUME cxn: .*marker master, no record, default' && ok "a full-access seat with no record gets the default" || bad "default: $out"
echo "$out" | grep -q '^UNRESOLVED nomode: transcript records no permission mode' && ok "no recorded mode is UNRESOLVED, never a default" || bad "no-mode seat"
echo "$out" | grep -q '^UNRESOLVED alias: mailbox is other' && ok "a mailbox that is not the seat id is not guessed" || bad "alias"
echo "$out" | grep -q '^UNRESOLVED nothread: no Codex thread' && ok "no thread is UNRESOLVED" || bad "no thread"
echo "$out" | grep -q 'elsewhere' && bad "another host's seat was planned" || ok "another host's seat is left out"
echo "$out" | grep -q 'disposable' && bad "a seat with no agent was planned" || ok "a seat with no agent is left out"
echo "$out" | grep -q 'zeo-rescue' && bad "the rescue seat planned itself" || ok "the rescue seat never starts itself"
[ -f "$T/state/ORG-CHART.last-good.json" ] && ok "the last good chart is kept" || bad "no last good chart"

echo "-- naming the session"
grep -q '^RESUME cl: claude 11111111-1111-4111-8111-111111111111 (--permission-mode plan' <<< "$(R --seat cl --session 11111111-1111-4111-8111-111111111111 2>&1)" && ok "--session beats the newest transcript, with that session's own mode" || bad "--session"
R --seat cl --seat cx --session 11111111-1111-4111-8111-111111111111 >/dev/null 2>&1; [ $? -eq 2 ] && ok "--session needs exactly one seat" || bad "--session with two seats"
grep -q '^UNRESOLVED cl: no transcript' <<< "$(R --seat cl --session 99999999-9999-4999-8999-999999999999 2>&1)" && ok "a --session with no transcript is UNRESOLVED" || bad "--session missing"

printf "cl 11111111-1111-4111-8111-111111111111\n" > "$T/pins"
grep -q '^RESUME cl: claude 11111111-1111-4111-8111-111111111111' <<< "$(ZEO_RESCUE_PINS=$T/pins R --seat cl 2>&1)" && ok "a pin beats the newest transcript" || bad "pin"
printf "cl not-an-id\n" > "$T/pins"
grep -q '^UNRESOLVED cl: bad pin' <<< "$(ZEO_RESCUE_PINS=$T/pins R --seat cl 2>&1)" && ok "a bad pin is UNRESOLVED" || bad "bad pin"

echo "-- a recorded marker older than a fault"
printf 'export ZEO_TMUX_SEAT=inactive\nexport ZMAIL_INSTANCE=other\n' > "$T/snap/44444444-4444-4444-8444-444444444444.2.sh"
grep -q '^RESUME cx: .*no marker, recorded inactive' <<< "$(R --seat cx 2>&1)" && ok "without --before the newest snapshot speaks" || bad "newest"
grep -q '^RESUME cx: .*marker master, recorded' <<< "$(R --seat cx --before 202601020000 2>&1)" && ok "--before ignores snapshots written during the fault" || bad "--before"
rm -f "$T/snap/44444444-4444-4444-8444-444444444444.2.sh"

echo "-- not running twice"
echo "4242 claude" > "$T/ps.out"; printf 'p4242\nfcwd\nn%s\n' "$T/w/cl" > "$T/lsof.out"
grep -q '^RUNNING cl:' <<< "$(R 2>&1)" && ok "a process in the seat's directory is left alone" || bad "RUNNING"
echo "4242 /u/.local/share/claude/versions/2.1.318 --resume x" > "$T/ps.out"
grep -q '^RUNNING cl:' <<< "$(R 2>&1)" && ok "the versioned binary path counts as claude" || bad "versioned path"
: > "$T/ps.out"; : > "$T/lsof.out"

echo "-- the launch"
cp "$T/snap/44444444-4444-4444-8444-444444444444.1.sh" "$T/snapwrite"
printf 'ZEO_TMUX_SEAT=master ZMAIL_INSTANCE=cl GIT_ALLOW_PROTOCOL=ssh:https:file HOME=/x' > "$T/psE.out"
printf 'the note' > "$T/note"
out=$(R --apply --seat cl --seat cx --note-file "$T/note" 2>&1)
[ "$(grep -c 'new-session' "$T/launched")" = 2 ] && ok "--seat limits --apply" || bad "launched: $(cat "$T/launched")"
grep -q -- "new-session -d -s cl-maintainer -c $T/w/cl -- sleep" "$T/launched" && ok "a session starts on a sleep, so no shell runs before the marker" || bad "launch line: $(cat "$T/launched")"
first=$(grep -n 'set-option -p -t %cl-maintainer @zeo_seat master' "$T/tmux.log" | head -1 | cut -d: -f1); spawn=$(grep -n 'respawn-pane -k -t %cl-maintainer' "$T/tmux.log" | head -1 | cut -d: -f1)
[ -n "$first" ] && [ -n "$spawn" ] && [ "$first" -lt "$spawn" ] && ok "the marker is set before the seat starts" || bad "marker order: $first $spawn"
grep -q -- "seat-exec.sh cl claude $T/state/prompts/cl.txt /x/claude --resume 22222222-2222-4222-8222-222222222222 --permission-mode auto" "$T/launched" && ok "claude argv" || bad "claude argv: $(cat "$T/launched")"
grep -q -- "seat-exec.sh cx codex $T/state/prompts/cx.txt /x/codex resume -a never -s danger-full-access -C $T/w/cx --no-daemon 44444444-4444-4444-8444-444444444444" "$T/launched" && ok "codex argv has --no-daemon and -C" || bad "codex argv: $(cat "$T/launched")"
grep -q 'the note$' "$T/state/prompts/cx.txt" && ok "the note joins the prompt" || bad "note"
echo "$out" | grep -q 'FIRST SEAT OK cx: own identity, marker master, git on' && ok "the first codex seat is proved" || bad "codex proof: $out"
echo "$out" | grep -q 'FIRST SEAT OK cl: own identity, marker master, git on' && ok "the first claude seat is proved" || bad "claude proof: $out"
grep -q '^LIVE cl ' <<< "$(R --seat cl --seat cx 2>&1)" && ok "a later run leaves a live seat alone" || bad "second run"
rm -f "$T/snap/44444444-4444-4444-8444-444444444444.new.sh"

echo "-- the seat-exec environment"
cat > "$T/bin/zsh-out" <<S
#!/bin/sh
env | sort > "$T/seatenv"
echo "\$@" > "$T/seatargs"
S
chmod +x "$T/bin/zsh-out"
printf 'hello world' > "$T/p"
sed "s#/bin/zsh \"\$flags\" 'exec \"\$@\"' zeo-rescue#$T/bin/zsh-out \"\$flags\"#" "$HERE/seat-exec.sh" > "$T/seat-exec.sh"
SECRET_LEAK=1 TMUX=/t TMUX_PANE=%9 sh "$T/seat-exec.sh" sx codex "$T/p" /x/codex resume id
grep -q '^ZMAIL_INSTANCE=sx$' "$T/seatenv" && ok "the seat gets its own identity" || bad "identity"
grep -q '^TMUX_PANE=%9$' "$T/seatenv" && ok "the loader can find its pane" || bad "pane"
grep -q SECRET_LEAK "$T/seatenv" && bad "the environment leaked" || ok "the environment is clean"
grep -q '^-lc /x/codex resume id hello world$' "$T/seatargs" && ok "a codex seat gets a login shell and the prompt" || bad "seat args: $(cat "$T/seatargs")"
sh "$T/seat-exec.sh" sy claude "$T/p" /x/claude; grep -q '^-lic ' "$T/seatargs" && ok "a claude seat gets an interactive shell, so .zshrc runs" || bad "claude flags"

echo "-- the first seat gate"
reset_live() { : > "$T/live"; : > "$T/launched"; : > "$T/opts"; : > "$T/tmux.log"; : > "$T/panes"; rm -f "$T/kills" "$T/snap/"*.new.sh; }
reset_live
printf 'export ZEO_TMUX_SEAT=inactive\nexport ZMAIL_INSTANCE=dt-hud-editor\nexport GIT_ALLOW_PROTOCOL=file\n' > "$T/snapwrite"
out=$(R --apply --seat cx --seat cxn 2>&1); rc=$?
[ $rc -eq 1 ] && ok "a wrong first seat exits 1" || bad "exit $rc"
echo "$out" | grep -q 'STOPPED: cx did not get its own identity' && ok "another seat's identity stops the run" || bad "gate: $out"
[ "$(grep -c new-session "$T/launched")" = 1 ] && ok "no other seat was started" || bad "gate started others"
reset_live
printf 'export ZEO_TMUX_SEAT=inactive\nexport ZMAIL_INSTANCE=cx\nexport GIT_ALLOW_PROTOCOL=file\n' > "$T/snapwrite"
grep -q 'STOPPED: cx lacks marker master' <<< "$(R --apply --seat cx 2>&1)" && ok "a missing marker stops the run" || bad "marker gate"
reset_live; rm -f "$T/snapwrite"
grep -q 'STOPPED: no shell snapshot for cx' <<< "$(R --apply --seat cx 2>&1)" && ok "no snapshot stops the run" || bad "no snapshot gate"
reset_live; printf 'ZMAIL_INSTANCE=architect HOME=/x' > "$T/psE.out"
grep -q 'STOPPED: cl did not get its own identity' <<< "$(R --apply --seat cl 2>&1)" && ok "a claude seat with another identity stops the run" || bad "claude gate"
reset_live; printf 'ZEO_TMUX_SEAT=inactive ZMAIL_INSTANCE=cl GIT_ALLOW_PROTOCOL=file HOME=/x' > "$T/psE.out"
grep -q 'STOPPED: cl lacks marker master' <<< "$(R --apply --seat cl 2>&1)" && ok "a claude seat without its marker stops the run" || bad "claude marker gate"

echo "-- reseating a live seat"
reset_live
printf 'export ZEO_TMUX_SEAT=master\nexport ZMAIL_INSTANCE=cx\nexport GIT_ALLOW_PROTOCOL=ssh:https:file\n' > "$T/snapwrite"
echo cx-maintainer >> "$T/live"; echo cxn-s >> "$T/live"
# cx-maintainer has a side window with another program; only the pane that holds the thread is touched
{ echo 'cx-maintainer|%7|700||Python'; echo 'cx-maintainer|%8|800||codex'; echo 'cxn-s|%2|200|1|codex'; } > "$T/panes"
{ echo "700 /usr/bin/python3 collector"; echo "800 /x/codex resume -a never -s danger-full-access 44444444-4444-4444-8444-444444444444 prompt"; echo "900 /u/.codex/packages/app-server-daemon/releases/1/bin/codex app-server"; } > "$T/ps.out"
out=$(R --reseat --seat cx --seat cxn 2>&1)
echo "$out" | grep -q '^RESEAT cx: codex 44444444-4444-4444-8444-444444444444 (-a never -s danger-full-access; marker master, recorded) in cx-maintainer' && ok "a live seat is planned for a reseat, with the pane that holds it" || bad "reseat plan: $out"
echo "$out" | grep -q '^OK cxn: started by rescue' && ok "a seat rescue started is left alone, so a reseat can be run again" || bad "reseat twice: $out"
[ ! -s "$T/launched" ] && ok "a reseat plan starts nothing" || bad "reseat plan started something"
{ echo "800 x"; echo "900 /u/.codex/packages/app-server-daemon/releases/1/bin/codex app-server"; } > "$T/ps.out"
sed -i '' 's/^800 x$/801 x/' "$T/ps.out"
out=$(R --reseat --seat cx --stagger 0 2>&1); echo "$out" | grep -q '^UNRESOLVED cx: no pane in cx-maintainer holds' && ok "a seat whose pane does not hold its thread is not touched" || bad "no holder: $out"
{ echo "800 /x/codex resume 44444444-4444-4444-8444-444444444444"; } > "$T/ps.out"
echo "-- a stuck process and the daemon"
reset_live; echo cx-maintainer >> "$T/live"; { echo 'cx-maintainer|%8|800||codex'; } > "$T/panes"
out=$(R --reseat --apply --seat cx 2>&1); rc=$?
echo "$out" | grep -q '^FAILED cx: its old process would not stop' && ok "a process that will not stop is not joined by a second one" || bad "stuck: $out"
[ $rc -eq 1 ] && ok "that exits 1" || bad "stuck exit $rc"
grep -q 'seat-exec.sh' "$T/launched" && bad "started over a live process" || ok "nothing started over it"
cat > "$T/bin/ps" <<S
#!/bin/bash
case "\$1" in
  -Ewwp) cat "$T/psE.out" 2>/dev/null; exit 0;;
esac
if [ -f "$T/ps.seen" ]; then cat "$T/ps.after"; else touch "$T/ps.seen"; cat "$T/ps.out"; fi
exit 0
S
reset_live; echo cx-maintainer >> "$T/live"; { echo 'cx-maintainer|%8|800||codex'; } > "$T/panes"
echo "900 /u/.codex/packages/app-server-daemon/releases/1/bin/codex app-server" >> "$T/ps.out"
echo "900 /u/.codex/packages/app-server-daemon/releases/1/bin/codex app-server" > "$T/ps.after"
out=$(R --reseat --apply --seat cx 2>&1)
echo "$out" | grep -q 'DAEMON STOP: exact pids 900' && ok "the daemon stops when no seat is attached" || bad "daemon: $out"
grep -qx '900' "$T/kills" && ok "by exact pid" || bad "kills: $(cat "$T/kills" 2>/dev/null)"
grep -qx -- '-9 900' "$T/kills" && ok "and by SIGKILL when it ignores SIGTERM" || bad "kill -9: $(cat "$T/kills" 2>/dev/null)"
d=$(grep -n 'seat-exec' "$T/tmux.log" | head -1 | cut -d: -f1); [ -n "$d" ] && ok "the seat restarts after the daemon stops" || bad "no restart: $out"
rm -f "$T/ps.seen"; reset_live; echo cx-maintainer >> "$T/live"; { echo 'cx-maintainer|%8|800||codex'; } > "$T/panes"
echo "901 /x/codex resume -a never -s danger-full-access 01010101-0101-4101-8101-010101010101 x" >> "$T/ps.after"
out=$(R --reseat --apply --seat cx 2>&1)
echo "$out" | grep -q 'DAEMON LEFT: 1 Codex seats' && ok "the daemon stays while another seat is attached" || bad "daemon left: $out"
[ ! -e "$T/kills" ] && ok "and nothing is killed" || bad "killed: $(cat "$T/kills")"
rm -f "$T/ps.seen"

echo "-- check"
cat > "$T/bin/ps" <<S
#!/bin/bash
case "\$1" in -Ewwp) cat "$T/psE.out";; *) cat "$T/ps.out";; esac
exit 0
S
reset_live; echo cx-maintainer >> "$T/live"; echo cl-maintainer >> "$T/live"
{ echo 'cx-maintainer|%8|800|1|codex'; echo 'cl-maintainer|%3|300|1|claude'; } > "$T/panes"
echo "800 /x/codex resume -a never -s danger-full-access -C /w --no-daemon 44444444-4444-4444-8444-444444444444 p" > "$T/ps.out"
printf 'ZMAIL_INSTANCE=cl HOME=/x' > "$T/psE.out"
out=$(R --check --seat cx --seat cl 2>&1); rc=$?
[ $rc -eq 0 ] && echo "$out" | grep -q '^OK cx (codex)' && echo "$out" | grep -q '^OK cl (claude)' && ok "seats started right pass" || bad "check: $rc $out"
echo '  Yes, I trust this folder' > "$T/screen"
grep -q '^WRONG cl (claude): waiting at the trust prompt' <<< "$(R --check --seat cl 2>&1)" && ok "a seat at the trust prompt is named, not counted as back" || bad "trust prompt"
rm -f "$T/screen"
printf 'ZMAIL_INSTANCE=cx ' > "$T/psE.out"
echo "800 /x/codex resume 44444444-4444-4444-8444-444444444444 p" > "$T/ps.out"
out=$(R --check --seat cx --seat cl 2>&1); rc=$?
[ $rc -eq 1 ] && ok "a wrong seat exits 1" || bad "check exit $rc"
echo "$out" | grep -q '^WRONG cx (codex): no --no-daemon' && ok "a seat on the daemon is named" || bad "check daemon: $out"
echo "$out" | grep -q '^WRONG cl (claude): environment has another identity' && ok "a seat with another identity is named" || bad "check id: $out"
grep -q '^WRONG cxn (codex): no session' <<< "$(R --check --seat cxn 2>&1)" && ok "a missing seat is named" || bad "check missing"
: > "$T/ps.out"

echo "-- the chart and usage"
grep -q 'WARNING.*last good' <<< "$(R --chart "$T/gone.json" 2>&1)" && ok "an unreadable chart falls back to the last good one, out loud" || bad "fallback"
rm -f "$T/state/ORG-CHART.last-good.json"; R --chart "$T/gone.json" >/dev/null 2>&1; [ $? -eq 1 ] && ok "no chart at all is a failure" || bad "no chart"
"$HERE/rescue.sh" --socket '../x' >/dev/null 2>&1; [ $? -eq 2 ] && ok "a bad socket name is usage" || bad "bad socket"
"$HERE/rescue.sh" --check --apply >/dev/null 2>&1; [ $? -eq 2 ] && ok "--check never combines with --apply" || bad "check apply"
echo; [ $fails -eq 0 ] && echo "PASS" || { echo "$fails FAILED"; exit 1; }
