#!/bin/bash
# Hermetic: every external tool is a stub in a temp directory, and nothing touches a real tmux server, transcript or database.
set -uo pipefail
HERE=$(cd "$(dirname "$0")" && pwd -P)
T=$(mktemp -d); trap 'rm -rf "$T"' EXIT
fails=0
ok()   { echo "ok   $1"; }
bad()  { echo "FAIL $1"; fails=$((fails+1)); }
GOOD='ZEO_TMUX_SEAT=master ZEO_TMUX_ACCOUNT=matorclawson GIT_ALLOW_PROTOCOL=ssh:https:file GH_CONFIG_DIR=/x/gh-master'
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
  show-options) cat "$T/seatmark" 2>/dev/null ;;
  capture-pane) cat "$T/screen" 2>/dev/null ;;
  respawn-pane) printf '%s\n' "\$*" >> "$T/launched"
    case "\$*" in *" --resume "*) sid=\$(printf "%s\n" "\$*" | sed -E "s/.* --resume ([^ ]+).*/\\1/"); if [ -f "$T/claudeadd" ]; then for f in "$T"/projects/*/\$sid.jsonl; do cat "$T/claudeadd" >> "\$f"; done; fi; printf "9 /x/claude --resume %s\n" "\$sid" >> "$T/ps.out"; [ ! -f "$T/secondclaude" ] || printf "77 /x/claude --resume %s\n" "\$sid" >> "$T/ps.out"; if [ -f "$T/forksession" ]; then for f in "$T"/projects/*/\$sid.jsonl; do : > "\${f%/*}/99999999-9999-4999-8999-999999999999.jsonl"; done; fi;; esac;
    case "\$*" in *" resume "*--no-daemon*) id=\${@: -1}; if [ -f "$T/snapwrite" ]; then cp "$T/snapwrite" "$T/snap/\$id.new.sh"; fi; [ ! -f "$T/heldafter" ] || cp "$T/heldafter" "$T/lsof.held"; [ ! -f "$T/latehold" ] || touch "$T/heldlate"; [ ! -f "$T/rolladd" ] || cat "$T/rolladd" >> "$T/sess/full.jsonl" ;; esac ;;
esac
exit \$?
S
cat > "$T/bin/ps" <<S
#!/bin/bash
case "\$1" in
  -Ewwp) if [ -s "$T/psE.out" ]; then cat "$T/psE.out"; else echo "$GOOD"; fi ;;
  *) cat "$T/ps.out" 2>/dev/null ;;
esac
exit 0
S
cat > "$T/bin/lsof" <<S
#!/bin/bash
case "\$1" in -t) echo "\$*" >> "$T/lsof.args"; if [ -f "$T/heldlate" ]; then rm -f "$T/heldlate"; else cat "$T/lsof.held" 2>/dev/null; fi ;; *) cat "$T/lsof.out" 2>/dev/null ;; esac
S
cat > "$T/bin/kill" <<S
#!/bin/bash
echo "\$*" >> "$T/kills"
S
cat > "$T/bin/sqlite3" <<S
#!/bin/bash
if [ -f "$T/nolog" ]; then case "\$1" in *immutable*) ;; *mode=ro) echo "Error: in prepare, unable to open database file (14)" >&2; exit 1;; esac; fi
case "\$2" in
  *"select count(*)"*) cat "$T/newthreads" ;;
  *"select cwd from"*) cat "$T/threadcwd" ;;
  *"$T/w/cx'"*|*"44444444-4444-4444-8444-444444444444"*)  printf '%s %s\n' 44444444-4444-4444-8444-444444444444 "$T/sess/full.jsonl" ;;
  *"$T/w/cxw'"*) printf '%s %s\n' 55555555-5555-4555-8555-555555555555 "$T/sess/write.jsonl" ;;
  *"$T/w/cxi'"*) printf '%s %s\n' 66666666-6666-4666-8666-666666666666 "$T/sess/full.jsonl" ;;
  *"$T/w/cxn'"*) printf '%s %s\n' 77777777-7777-4777-8777-777777777777 "$T/sess/full.jsonl" ;;
esac
S
# The probe shell stands in for zsh reading the host's .zshenv: it gives a master seat its author, and can reset gh as the real file does.
cat > "$T/bin/zsh-probe" <<S
#!/bin/bash
env | sort > "$T/probe.env"
[ ! -f "$T/zshenv-resets-gh" ] || GH_CONFIG_DIR=/x/gh-matorclawson
[ "\$1" != -c ] || [ ! -f "$T/plain-c-git-on" ] || GIT_ALLOW_PROTOCOL=ssh
[ "\$ZEO_TMUX_SEAT:\${ZEO_TMUX_ACCOUNT:-}" != master:matorclawson ] || GIT_AUTHOR_EMAIL=a@noreply
echo "gh=\${GH_CONFIG_DIR##*/} author=\${GIT_AUTHOR_EMAIL:-none}"
[ "\${GIT_ALLOW_PROTOCOL:-}" != file ] || echo "fatal: transport 'ssh' not allowed"
S
chmod +x "$T/bin/"*
echo master > "$T/seatmark"
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
export ZEO_RESCUE_ZSH="$T/bin/zsh-probe" ZEO_RESCUE_CLAUDE_JSON="$T/claude.json"
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
printf 'ZEO_TMUX_SEAT=master ZEO_TMUX_ACCOUNT=matorclawson ZMAIL_INSTANCE=cl GIT_ALLOW_PROTOCOL=ssh:https:file HOME=/x' > "$T/psE.out"
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
sed "s#/bin/zsh -lic 'exec \"\$@\"' zeo-rescue#$T/bin/zsh-out -lic#" "$HERE/seat-exec.sh" > "$T/seat-exec.sh"
SECRET_LEAK=1 TMUX=/t TMUX_PANE=%9 sh "$T/seat-exec.sh" sx codex "$T/p" /x/codex resume id
grep -q '^ZMAIL_INSTANCE=sx$' "$T/seatenv" && ok "the seat gets its own identity" || bad "identity"
grep -q '^TMUX_PANE=%9$' "$T/seatenv" && ok "the loader can find its pane" || bad "pane"
grep -q SECRET_LEAK "$T/seatenv" && bad "the environment leaked" || ok "the environment is clean"
grep -q '^-lic /x/codex resume id hello world$' "$T/seatargs" && ok "a codex seat gets an interactive shell, so .zshrc runs, and the prompt" || bad "seat args: $(cat "$T/seatargs")"
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

: > "$T/psE.out"
reset_live; printf 'export ZEO_TMUX_SEAT=master\nexport ZMAIL_INSTANCE=cx\nexport GIT_ALLOW_PROTOCOL=ssh:https:file\n' > "$T/snapwrite"; printf 'HOME=/x' > "$T/psE.out"
out=$(R --apply --seat cx 2>&1); rc=$?
[ $rc -eq 1 ] && echo "$out" | grep -q '^STOPPED: cx: process has no seat settings, so tools outside its folder miss them; no other seat was started' && ok "a right snapshot does not pass a first seat whose process lacks the settings" || bad "process gate: $rc $out"
printf 'ZEO_TMUX_SEAT=master ZEO_TMUX_ACCOUNT=matorclawson GIT_ALLOW_PROTOCOL=file' > "$T/psE.out"
grep -q '^STOPPED: cx: a shell outside its folder has git off' <<< "$(reset_live; R --apply --seat cx 2>&1)" && ok "nor one whose shells have git off" || bad "shell gate"
: > "$T/psE.out"; reset_live; rm -f "$T/snapwrite"

echo "-- the proof reads top-level exports only: a real snapshot also stores the loader's functions"
loader='zeo-seat-load () {\n\tif [ -z "$m" ]\n\tthen\n\t\texport GIT_ALLOW_PROTOCOL=file \n\t\texport ZEO_TMUX_SEAT=inactive \n\tfi\n}\n'
snap() { reset_live; printf "$loader$1" > "$T/snapwrite"; R --apply --seat cx 2>&1; }
out=$(snap 'export GIT_ALLOW_PROTOCOL=ssh:https:file\nexport ZEO_TMUX_SEAT=master\nexport ZMAIL_INSTANCE=cx\n')
echo "$out" | grep -q 'FIRST SEAT OK cx: own identity, marker master, git on' && ok "git on at top level passes, though the loader function says file" || bad "loader false stop: $out"
out=$(snap 'export GIT_ALLOW_PROTOCOL=file\nexport ZEO_TMUX_SEAT=master\nexport ZMAIL_INSTANCE=cx\n')
echo "$out" | grep -q 'STOPPED: cx still has network git off' && ok "git off at top level still stops" || bad "git off passed: $out"
loader='zeo-seat-load () {\n\t\texport ZEO_TMUX_SEAT=master \n\t\texport ZMAIL_INSTANCE=cx \n}\n'
out=$(snap 'export GIT_ALLOW_PROTOCOL=ssh:https:file\nexport ZEO_TMUX_SEAT=inactive\nexport ZMAIL_INSTANCE=cx\n')
echo "$out" | grep -q 'STOPPED: cx lacks marker master' && ok "a marker only inside a function does not pass" || bad "marker: $out"
out=$(snap 'export GIT_ALLOW_PROTOCOL=ssh:https:file\nexport ZEO_TMUX_SEAT=master\nexport ZMAIL_INSTANCE=dt-hud-editor\n')
echo "$out" | grep -q 'STOPPED: cx did not get its own identity' && ok "an identity only inside a function does not pass" || bad "identity: $out"
out=$(snap "export GIT_ALLOW_PROTOCOL='ssh:https:file'\nexport ZEO_TMUX_SEAT='master'\nexport ZMAIL_INSTANCE='cx'\n")
echo "$out" | grep -q 'FIRST SEAT OK cx' && ok "a quoted top-level value still passes" || bad "quoted: $out"
reset_live; rm -f "$T/snapwrite"

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
  -Ewwp) if [ -s "$T/psE.out" ]; then cat "$T/psE.out"; else echo "$GOOD"; fi; exit 0;;
  -axo) case "\$2" in *ppid*) cat "$T/ps.tree" 2>/dev/null; exit 0;; esac ;;
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

echo "-- two writers: a thread something still holds"
reset_live; echo cx-maintainer >> "$T/live"; { echo 'cx-maintainer|%8|800||codex'; } > "$T/panes"
echo 900 > "$T/lsof.held"
out=$(R --reseat --apply --seat cx 2>&1); rc=$?
echo "$out" | grep -q '^FAILED cx: pid 900 still holds its rollout, so it was not started' && ok "a live seat is not started while the daemon holds its thread" || bad "held: $out"
[ $rc -eq 1 ] && ok "that exits 1" || bad "held exit $rc"
grep -q 'seat-exec.sh' "$T/launched" && bad "started beside the daemon" || ok "and nothing was started beside it"
grep -q -- "-t -- $T/sess/full.jsonl" "$T/lsof.args" && ok "the question is asked of the seat's own rollout" || bad "lsof args: $(cat "$T/lsof.args" 2>/dev/null)"
rm -f "$T/ps.seen"; reset_live
out=$(R --apply --seat cx 2>&1)
echo "$out" | grep -q '^FAILED cx: pid 900 still holds' && ! grep -q new-session "$T/launched" && ok "a dead seat is held to the same test" || bad "held dead seat: $out"
rm -f "$T/lsof.held" "$T/ps.seen"

echo "-- a first seat that fails its proof"
reset_live; echo cx-maintainer >> "$T/live"; echo cxn-s >> "$T/live"
{ echo 'cx-maintainer|%8|800||codex'; echo 'cxn-s|%2|802||codex'; } > "$T/panes"
{ echo "800 /x/codex resume 44444444-4444-4444-8444-444444444444"; echo "802 /x/codex resume 77777777-7777-4777-8777-777777777777"; } > "$T/ps.out"; : > "$T/ps.after"
printf 'export ZEO_TMUX_SEAT=inactive\nexport ZMAIL_INSTANCE=dt-hud-editor\nexport GIT_ALLOW_PROTOCOL=file\n' > "$T/snapwrite"
out=$(R --reseat --apply --seat cx --seat cxn 2>&1); rc=$?
[ $rc -eq 1 ] && echo "$out" | grep -q 'STOPPED: cx did not get its own identity' && ok "the run stops at the failed seat" || bad "stop: $rc $out"
echo "$out" | grep -q '^RECOVERY: 2 seats are down, counting the one that failed' && ok "the output says what is down and what brings it back" || bad "recovery: $out"
[ "$(grep -c seat-exec "$T/launched")" = 1 ] && ok "the next seat stays on its sleep" || bad "others: $(cat "$T/launched")"
s=$(grep -n 'seat-exec' "$T/tmux.log" | head -1 | cut -d: -f1); u=$(grep -n 'respawn-pane -k -t %8 .* sleep 3600' "$T/tmux.log" | tail -1 | cut -d: -f1)
[ -n "$s" ] && [ -n "$u" ] && [ "$s" -lt "$u" ] && ok "the wrong seat is stopped again, not left up" || bad "unseat order: $s $u"
grep -q 'set-option -pu -t %8 @zeo_rescue' "$T/tmux.log" && ok "and loses the mark, so the next run plans it again" || bad "mark: $(cat "$T/tmux.log")"
rm -f "$T/ps.seen"; reset_live
out=$(R --apply --seat cx 2>&1)
grep -q 'kill-session -t =cx-maintainer' "$T/tmux.log" && echo "$out" | grep -q '^RECOVERY: 1 seats' && ok "a seat that was dead goes back to dead, so make rescue can take it" || bad "dead proof: $out"
rm -f "$T/ps.seen"; reset_live; printf 'ZMAIL_INSTANCE=architect HOME=/x' > "$T/psE.out"
out=$(R --apply --seat cl 2>&1)
echo "$out" | grep -q '^RECOVERY: 1 seats' && grep -q 'kill-session -t =cl-maintainer' "$T/tmux.log" && ok "the claude proof recovers the same way" || bad "claude recovery: $out"
rm -f "$T/ps.seen"

echo "-- what a restart would cut"
reset_live; echo cx-maintainer >> "$T/live"; { echo 'cx-maintainer|%8|800||codex'; } > "$T/panes"
echo "800 /x/codex resume 44444444-4444-4444-8444-444444444444" > "$T/ps.out"; : > "$T/ps.after"
cat > "$T/ps.tree" <<'E'
  800     1 01:00:00 /x/codex resume 44444444-4444-4444-8444-444444444444
  811   800    02:00 /bin/zsh -c source /x/snap.sh 2>/dev/null || true && setopt X && eval 'make build' < /dev/null
  812   800    02:00 /u/.local/share/zeo/messenger/hooks/runtimes/abc watch
  813   800    02:00 caffeinate -i -t 300
  816   800    59:00 /u/.codex/packages/standalone/releases/0.164.0/bin/codex-code-mode-host
  900     1 03:00:00 /u/.codex/packages/app-server-daemon/releases/1/bin/codex app-server --listen unix://
  914   900    00:30 /bin/sh -c cargo test
  915   900    03:00 /u/.codex/packages/app-server-daemon/releases/1/bin/codex-code-mode-host
E
echo '  Working (9s, esc to interrupt)' > "$T/screen"
out=$(R --reseat --seat cx 2>&1)
echo "$out" | grep -q '^WORK cx: a turn is in progress on its screen' && ok "a turn on the screen is listed" || bad "screen: $out"
echo "$out" | grep -q "^WORK cx: 811 02:00 'make build'" && ok "a tool shell is listed by what it runs" || bad "tool: $out"
echo "$out" | grep -E -q 'WORK.*(hooks|caffeinate|code-mode)' && bad "noise in the list: $out" || ok "mail hooks, caffeinate and the daemon's helper are not work"
echo "$out" | grep -q '^WORK daemon, in .*: 914 00:30 /bin/sh -c cargo test' && ok "a Codex tool under the daemon is listed" || bad "daemon work: $out"
echo "$out" | grep -q '^work: 1 of 1 seats show running work' && ok "and counted" || bad "count: $out"
[ ! -s "$T/launched" ] && ok "listing stops nothing" || bad "the list touched a seat"
rm -f "$T/ps.seen"
out=$(R --reseat --apply --seat cx 2>&1)
w=$(echo "$out" | grep -n '^WORK' | head -1 | cut -d: -f1); r=$(echo "$out" | grep -n '^RESUMED\|^STOPPED\|^FAILED' | head -1 | cut -d: -f1)
[ -n "$w" ] && [ -n "$r" ] && [ "$w" -lt "$r" ] && ok "--apply lists it before it stops anything, so the log keeps what was cut" || bad "order: $w $r"
rm -f "$T/ps.seen" "$T/screen" "$T/ps.tree" "$T/snapwrite"

echo "-- check"
cat > "$T/bin/ps" <<S
#!/bin/bash
case "\$1" in -Ewwp) cat "$T/psE.out";; *) cat "$T/ps.out";; esac
exit 0
S
reset_live; echo cx-maintainer >> "$T/live"; echo cl-maintainer >> "$T/live"
{ echo 'cx-maintainer|%8|800|1|codex'; echo 'cl-maintainer|%3|300|1|claude'; } > "$T/panes"
echo "800 /x/codex resume -a never -s danger-full-access -C /w --no-daemon 44444444-4444-4444-8444-444444444444 p" > "$T/ps.out"
printf 'ZMAIL_INSTANCE=cl HOME=/x %s' "$GOOD" > "$T/psE.out"
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

echo "-- check reads the process and a shell outside the folder, not only the snapshot"
echo "800 /x/codex resume -a never -s danger-full-access -C /w --no-daemon 44444444-4444-4444-8444-444444444444 p" > "$T/ps.out"
C() { R --check --seat cx 2>&1; }
INACTIVE='ZEO_TMUX_SEAT=inactive ZEO_TMUX_ACCOUNT=none GIT_ALLOW_PROTOCOL=file GH_CONFIG_DIR=/x/disabled'
printf 'HOME=/x' > "$T/psE.out"
grep -q '^WRONG cx (codex): process has no seat settings' <<< "$(C)" && ok "a right snapshot does not hide a process without settings" || bad "no settings: $(C)"
: > "$T/seatmark"; printf '%s' "$GOOD" > "$T/psE.out"
grep -q '^WRONG cx (codex): process says master, pane says inactive' <<< "$(C)" && ok "a process that disagrees with its pane is named" || bad "disagree: $(C)"
printf 'ZEO_TMUX_SEAT=inactive ZEO_TMUX_ACCOUNT=none GIT_ALLOW_PROTOCOL=ssh:https:file GH_CONFIG_DIR=/x/disabled' > "$T/psE.out"
grep -q '^WRONG cx (codex): a shell outside its folder has git on' <<< "$(C)" && ok "an inactive seat with git on is named" || bad "git on: $(C)"
printf '%s' "$INACTIVE" > "$T/psE.out"
grep -q '^OK cx (codex)' <<< "$(C)" && ok "an inactive seat with everything off passes" || bad "inactive: $(C)"
touch "$T/plain-c-git-on"
grep -q '^WRONG cx (codex): a shell outside its folder has git on' <<< "$(C)" && ok "both kinds of tool shell are read: a fault only in zsh -c is named" || bad "plain -c: $(C)"
rm -f "$T/plain-c-git-on"
touch "$T/zshenv-resets-gh"
grep -q '^WRONG cx (codex): a shell outside its folder has gh on' <<< "$(C)" && ok "a startup file that turns gh back on is named" || bad "gh on: $(C)"
rm -f "$T/zshenv-resets-gh"
echo master > "$T/seatmark"; printf 'ZEO_TMUX_SEAT=master ZEO_TMUX_ACCOUNT=matorclawson GIT_ALLOW_PROTOCOL=file' > "$T/psE.out"
grep -q '^WRONG cx (codex): a shell outside its folder has git off' <<< "$(C)" && ok "a master seat with git off is named" || bad "git off: $(C)"
printf 'ZEO_TMUX_SEAT=master GIT_ALLOW_PROTOCOL=ssh:https:file' > "$T/psE.out"
grep -q '^WRONG cx (codex): a shell outside its folder has no seat author' <<< "$(C)" && ok "a seat that would commit under the wrong author is named" || bad "author: $(C)"
printf '/x/codex resume p You were told ZEO_TMUX_SEAT=inactive and GIT_ALLOW_PROTOCOL=file HOME=/x %s GH_TOKEN=do-not-copy' "$GOOD" > "$T/psE.out"
grep -q '^OK cx (codex)' <<< "$(C)" && ok "prompt text that looks like a setting does not count" || bad "decoy: $(C)"
grep -q 'GH_TOKEN' "$T/probe.env" && bad "a credential reached the probe" || ok "a credential in the process never reaches the probe"
: > "$T/ps.out"; : > "$T/seatmark"

echo "-- a seat moves folder and keeps its thread"
SID=44444444-4444-4444-8444-444444444444
mkdir -p "$T/w/new" "$T/w/newgit" "$T/sessions"; : > "$T/sessions/rollout-$SID.jsonl"; git -C "$T/w/newgit" init -q
cp "$T/sess/full.jsonl" "$T/sess/full.orig"; printf 'cx %s\ncl 22222222-2222-4222-8222-222222222222\n' "$SID" > "$T/pins"
export ZEO_RESCUE_MOVES="$T/moves" ZEO_RESCUE_SESSIONS="$T/sessions" ZEO_RESCUE_CODEX_CONFIG="$T/config.toml"
export ZEO_RESCUE_PINS="$T/pins"
echo master > "$T/seatmark"; printf '%s' "$GOOD" > "$T/psE.out"; : > "$T/ps.out"
printf 'export ZEO_TMUX_SEAT=master\nexport ZMAIL_INSTANCE=cx\nexport GIT_ALLOW_PROTOCOL=ssh:https:file\n' > "$T/snapwrite"
printf '{"cwd":"%s"}\n' "$T/w/new" > "$T/rolladd"; echo 9 > "$T/heldafter"; echo "$T/w/new" > "$T/threadcwd"; echo 0 > "$T/newthreads"
fresh() { reset_live; rm -f "$T/lsof.held"; cp "$T/sess/full.orig" "$T/sess/full.jsonl"; }
printf 'cx %s\n' "$T/w/gone" > "$T/moves"; fresh
grep -q "^UNRESOLVED cx: new folder $T/w/gone does not exist" <<< "$(R --seat cx 2>&1)" && ok "a folder that is not there is refused" || bad "gone: $(R --seat cx 2>&1)"
printf 'cx %s\n' "$T/w/cl" > "$T/moves"
grep -q "^UNRESOLVED cx: new folder $T/w/cl is already a seat's folder" <<< "$(R --seat cx 2>&1)" && ok "another seat's folder is refused" || bad "taken: $(R --seat cx 2>&1)"
printf 'cx %s\ncxi %s\n' "$T/w/new" "$T/w/new" > "$T/moves"
grep -q "^UNRESOLVED cx: two seats would move to" <<< "$(R --seat cx 2>&1)" && ok "two seats in one folder are refused" || bad "two: $(R --seat cx 2>&1)"
printf 'cx %s\ncx %s\n' "$T/w/new" "$T/w/newgit" > "$T/moves"
grep -q "^UNRESOLVED cx: more than one line" <<< "$(R --seat cx 2>&1)" && ok "two lines for one seat are refused" || bad "two lines: $(R --seat cx 2>&1)"
printf 'cx %s\n' "$T/w/new" > "$T/moves"
grep -q '^UNRESOLVED cx: it moves folder, so .* must name its thread' <<< "$(ZEO_RESCUE_PINS=$T/no-pins R --seat cx 2>&1)" && ok "a seat with no pinned thread cannot move" || bad "no pin"
printf 'cx %s\n' "$T/w/newgit" > "$T/moves"; : > "$T/config.toml"
grep -q 'stop at a question nobody may answer' <<< "$(R --seat cx 2>&1)" && ok "a git folder with no trust entry is refused before anything stops" || bad "trust: $(R --seat cx 2>&1)"
printf '[projects."%s"]\ntrust_level = "untrusted"\n' "$T/w/newgit" > "$T/config.toml"
grep -q 'stop at a question' <<< "$(R --seat cx 2>&1)" && ok "and so is an untrusted entry" || bad "untrusted"
printf '[projects."%s"]\ntrust_level = "trusted"\n' "$T/w/newgit" > "$T/config.toml"
grep -q '^RESUME cx:' <<< "$(R --seat cx 2>&1)" && ok "a trusted git folder passes" || bad "trusted: $(R --seat cx 2>&1)"
printf 'cx %s\n' "$T/w/new" > "$T/moves"; fresh
out=$(R --apply --seat cx 2>&1); rc=$?
[ $rc -eq 0 ] && echo "$out" | grep -q "^MOVED OK cx: thread $SID, one rollout, one writer, in $T/w/new" && ok "a move proves one thread, one rollout, one writer" || bad "move: $rc $out"
echo "$out" | grep -q "^MOVE cx: from $T/w/cx to $T/w/new" && ok "the plan says where from and to" || bad "move line: $out"
grep -q -- "resume -a never -s danger-full-access -C $T/w/new --no-daemon $SID" "$T/launched" && ok "it resumes the pinned thread in the new folder" || bad "argv: $(cat "$T/launched")"
grep -q "moved from $T/w/cx to $T/w/new" "$T/state/prompts/cx.txt" && ok "the seat is told" || bad "note"
touch "$T/nolog"; fresh; out=$(R --apply --seat cx 2>&1); rc=$?; rm -f "$T/nolog"
[ $rc -eq 0 ] && echo "$out" | grep -q '^MOVED OK cx' && ok "a database nothing has open, so mode=ro fails, does not stop a good seat" || bad "no log: $rc $out"
{ printf '{"cwd":"%s"}\n' "$T/w/new"; head -c 1000000 /dev/zero | tr '\0' x; echo; } > "$T/rolladd"; fresh; out=$(R --apply --seat cx 2>&1); rc=$?
[ $rc -eq 0 ] && echo "$out" | grep -q '^MOVED OK cx' && ok "a rollout larger than the pipe does not stop a good seat" || bad "big rollout: $rc $out"
printf '{"cwd":"%s"}\n' "$T/w/new" > "$T/rolladd"
touch "$T/latehold"; fresh; out=$(R --apply --seat cx 2>&1); rc=$?; rm -f "$T/latehold" "$T/heldlate"
[ $rc -eq 0 ] && echo "$out" | grep -q '^MOVED OK cx' && ok "a rollout that opens a moment late does not stop a good seat" || bad "late hold: $rc $out"
echo "$T/w/cx" > "$T/threadcwd"; fresh; out=$(R --apply --seat cx 2>&1); rc=$?
[ $rc -eq 0 ] && echo "$out" | grep -q '^NOTE cx: Codex.s thread record still says' && ok "an old thread record is named, and does not stop a seat the pin still finds" || bad "record: $rc $out"
echo "$T/w/new" > "$T/threadcwd"
: > "$T/sessions/rollout-copy-$SID.jsonl"; fresh; out=$(R --apply --seat cx 2>&1); rc=$?
[ $rc -eq 1 ] && echo "$out" | grep -q "^STOPPED: cx: 2 rollouts carry thread $SID" && ok "a second rollout stops the run" || bad "rollouts: $rc $out"
rm -f "$T/sessions/rollout-copy-$SID.jsonl"
echo 1 > "$T/newthreads"; fresh; out=$(R --apply --seat cx 2>&1); rc=$?
[ $rc -eq 1 ] && echo "$out" | grep -q '^STOPPED: cx: 1 new threads appeared' && ok "a new thread in the folder stops the run" || bad "new thread: $rc $out"
echo 0 > "$T/newthreads"; printf '9\n77\n' > "$T/heldafter"; fresh; out=$(R --apply --seat cx 2>&1); rc=$?
[ $rc -eq 1 ] && echo "$out" | grep -q "^STOPPED: cx: its rollout is held by pids '9 77'" && ok "a second writer stops the run" || bad "writer: $rc $out"
echo 9 > "$T/heldafter"; rm -f "$T/rolladd"; fresh; out=$(R --apply --seat cx 2>&1); rc=$?
[ $rc -eq 1 ] && echo "$out" | grep -q "^STOPPED: cx: its thread never recorded $T/w/new" && ok "a thread that never reached the folder stops the run" || bad "never: $rc $out"
echo "$out" | grep -q '^RECOVERY: 1 seats' && ok "and says what is down" || bad "move recovery"
printf '{"cwd":"%s"}\n' "$T/w/new" > "$T/rolladd"
echo "-- --relaunch restarts only the seats that need it"
fresh; echo cx-maintainer >> "$T/live"; echo 'cx-maintainer|%8|800|1|codex' > "$T/panes"
echo "800 /x/codex resume -a never -s danger-full-access -C $T/w/cx --no-daemon $SID p" > "$T/ps.out"; printf 'HOME=/x' > "$T/psE.out"
: > "$T/moves"
grep -q '^OK cx: started by rescue' <<< "$(R --reseat --seat cx 2>&1)" && ok "without --relaunch a seat rescue started is left alone" || bad "plain reseat"
grep -q '^RESEAT cx:' <<< "$(R --reseat --relaunch --seat cx 2>&1)" && ok "with it, a process without settings is restarted" || bad "relaunch: $(R --reseat --relaunch --seat cx 2>&1)"
printf '%s' "$GOOD" > "$T/psE.out"
grep -q '^OK cx: started by rescue, right already' <<< "$(R --reseat --relaunch --seat cx 2>&1)" && ok "a seat with everything right is left alone, so the line can run again" || bad "right: $(R --reseat --relaunch --seat cx 2>&1)"
echo "a note" > "$T/rnote"; out=$(R --reseat --relaunch --restart --seat cx --note-file "$T/rnote" 2>&1)
echo "$out" | grep -q '^RESEAT cx:' && ! echo "$out" | grep -q 'right already' && ok "--restart restarts a seat that reads as right, so its note reaches it" || bad "restart: $out"
out=$(R --reseat --relaunch --restart --seat cx 2>&1); [ $? -eq 2 ] && ! echo "$out" | grep -q '^RESEAT' && ok "but only with a note" || bad "restart no note: $out"
out=$(R --reseat --restart --seat cx --note-file "$T/rnote" 2>&1); [ $? -eq 2 ] && ! echo "$out" | grep -q '^RESEAT' && ok "and only with --relaunch" || bad "restart no relaunch: $out"
out=$(R --reseat --relaunch --restart --seat cx --seat cl --note-file "$T/rnote" 2>&1); [ $? -eq 2 ] && echo "$out" | grep -q 'needs exactly one --seat' && ok "and for exactly one seat" || bad "restart two: $out"
out=$(R --reseat --relaunch --restart --note-file "$T/rnote" 2>&1); [ $? -eq 2 ] && echo "$out" | grep -q 'needs exactly one --seat' && ok "never for every seat" || bad "restart all: $out"
printf 'cx %s\n' "$T/w/new" > "$T/moves"
out=$(R --reseat --relaunch --seat cx 2>&1)
echo "$out" | grep -q '^RESEAT cx:' && echo "$out" | grep -q '^MOVE cx' && ok "a right seat in the old folder is restarted to move" || bad "to move: $out"
grep -q "^WRONG cx (codex): not yet in its new folder $T/w/new" <<< "$(R --check --seat cx 2>&1)" && ok "--check names a seat not yet moved" || bad "check move: $(R --check --seat cx 2>&1)"
echo "800 /x/codex resume -a never -s danger-full-access -C $T/w/new --no-daemon $SID p" > "$T/ps.out"
grep -q '^OK cx: started by rescue, right already' <<< "$(R --reseat --relaunch --seat cx 2>&1)" && ok "a moved seat is left alone" || bad "moved: $(R --reseat --relaunch --seat cx 2>&1)"
grep -q '^OK cx (codex)' <<< "$(R --check --seat cx 2>&1)" && ok "and passes --check" || bad "check moved: $(R --check --seat cx 2>&1)"
printf 'ZEO_TMUX_SEAT=master ZEO_TMUX_ACCOUNT=matorclawson GIT_ALLOW_PROTOCOL=file' > "$T/psE.out"
grep -q '^UNRESOLVED cx: a shell outside its folder has git off; a restart would not change that' <<< "$(R --reseat --relaunch --seat cx 2>&1)" && ok "a fault a restart cannot fix stops short of a restart" || bad "unfixable: $(R --reseat --relaunch --seat cx 2>&1)"
echo "900 /x/codex resume -a never -s danger-full-access -C /x --no-daemon 99999999-9999-4999-8999-999999999999 p" > "$T/ps.out"
sed -i '' 's/^cx-maintainer|%8|800|1|codex$/cx-maintainer|%8|900|1|codex/' "$T/panes"
grep -q "^UNRESOLVED cx: its pane does not hold $SID" <<< "$(R --reseat --relaunch --seat cx 2>&1)" && ok "a pane holding another thread is not touched" || bad "other thread: $(R --reseat --relaunch --seat cx 2>&1)"
"$HERE/rescue.sh" --relaunch >/dev/null 2>&1; [ $? -eq 2 ] && ok "--relaunch needs --reseat" || bad "relaunch alone"
printf '' > "$T/psE.out"; : > "$T/moves"; : > "$T/ps.out"; : > "$T/panes"; rm -f "$T/heldafter" "$T/rolladd" "$T/snapwrite"; export ZEO_RESCUE_PINS="$T/no-pins"; reset_live

echo "-- a Claude seat moves folder and keeps its session, memory and transcript"
CS=22222222-2222-4222-8222-222222222222; enc2() { printf %s "$1" | LC_ALL=C sed 's/[^A-Za-z0-9]/-/g'; }
CO=$T/projects/$(enc2 "$T/w/cl"); CN=$T/projects/$(enc2 "$T/w/cnew"); mkdir -p "$T/w/cnew" "$CO/memory"; echo m > "$CO/memory/MEMORY.md"
cp -R "$CO" "$T/cproj"
printf 'cl %s\n' "$CS" > "$T/cpins"; export ZEO_RESCUE_PINS="$T/cpins" ZEO_RESCUE_MOVES="$T/moves" ZEO_RESCUE_CLAUDE_JSON="$T/claude.json"
printf 'cl %s\n' "$T/w/cnew" > "$T/moves"; echo master > "$T/seatmark"
printf 'ZEO_TMUX_SEAT=master ZEO_TMUX_ACCOUNT=matorclawson ZMAIL_INSTANCE=cl GIT_ALLOW_PROTOCOL=ssh:https:file HOME=/x' > "$T/psE.out"; : > "$T/ps.out"; : > "$T/lsof.out"
cfresh() { reset_live; rm -rf "$CO" "$CN"; cp -R "$T/cproj" "$CO"; printf '{"cwd":"%s"}\n' "$T/w/cnew" > "$T/claudeadd"; : > "$T/ps.out"; }
trustnew() { printf '{"projects":{"%s":{"hasTrustDialogAccepted":true}}}' "$T/w/cnew" > "$T/claude.json"; }
echo '{"projects":{}}' > "$T/claude.json"; cfresh
grep -q 'has no trusted entry in .* so Claude would stop at a question nobody may answer' <<< "$(R --seat cl 2>&1)" && ok "a folder with no trust entry is refused, git or not" || bad "claude trust: $(R --seat cl 2>&1)"
trustnew
git -C "$T/w/newgit" -c user.email=t@t -c user.name=t commit -q --allow-empty -m x; git -C "$T/w/newgit" worktree add -q "$T/w/cwt" 2>/dev/null
printf '{"projects":{"%s":{"hasTrustDialogAccepted":true}}}' "$T/w/cwt" > "$T/claude.json"; printf 'cl %s\n' "$T/w/cwt" > "$T/moves"
grep -q 'is a git worktree, and no Claude move into one is proved' <<< "$(R --seat cl 2>&1)" && ok "a worktree target is refused" || bad "worktree: $(R --seat cl 2>&1)"
trustnew; printf 'cl %s\n' "$T/w/cnew" > "$T/moves"; mkdir -p "$CN"
grep -q 'it has projects under both folders' <<< "$(R --seat cl 2>&1)" && ok "two projects are never merged" || bad "both: $(R --seat cl 2>&1)"
cfresh; out=$(R --apply --seat cl 2>&1); rc=$?
[ $rc -eq 0 ] && echo "$out" | grep -q "^MOVED OK cl: session $CS, one transcript, one process, in $T/w/cnew" && ok "a move proves one transcript, one process" || bad "claude move: $rc $out"
[ -f "$CN/memory/MEMORY.md" ] && [ -f "$CN/$CS.jsonl" ] && [ ! -e "$CO" ] && ok "the whole project goes by one rename, memory too" || bad "project: $(ls "$T/projects")"
grep -q -- "-c $T/w/cnew -- $HERE/seat-exec.sh cl claude" "$T/launched" && ok "it starts in the new folder" || bad "launch: $(cat "$T/launched")"
cp "$CN/$CS.jsonl" "$T/keep.jsonl"
cfresh; cp "$T/keep.jsonl" "$CO/$CS.jsonl"; rm -f "$T/claudeadd"; out=$(R --apply --seat cl 2>&1); rc=$?
[ $rc -eq 1 ] && echo "$out" | grep -q "^STOPPED: cl: its transcript took no line from" && ok "an old record of the folder does not pass: only new bytes count" || bad "vacuous: $rc $out"
cfresh; mkdir -p "$T/projects/x"; : > "$T/projects/x/$CS.jsonl"; out=$(R --apply --seat cl 2>&1); rc=$?; rm -rf "$T/projects/x"
[ $rc -eq 1 ] && echo "$out" | grep -q 'STOPPED: cl: 2 transcripts carry session' && ok "a second transcript stops the run" || bad "two transcripts: $rc $out"
cfresh; touch "$T/forksession"; out=$(R --apply --seat cl 2>&1); rc=$?; rm -f "$T/forksession"
[ $rc -eq 1 ] && echo "$out" | grep -q 'STOPPED: cl: 1 new sessions appeared' && ok "a forked session stops the run" || bad "fork: $rc $out"
cfresh; touch "$T/secondclaude"; out=$(R --apply --seat cl 2>&1); rc=$?; rm -f "$T/secondclaude"
[ $rc -eq 1 ] && echo "$out" | grep -q "^STOPPED: cl: session $CS is held by pids '9 77'" && ok "a second process stops the run" || bad "second process: $rc $out"
cfresh; echo "800 /x/claude --resume $CS" > "$T/ps.out"; echo cl-maintainer >> "$T/live"; echo 'cl-maintainer|%3|800|1|claude' > "$T/panes"
out=$(R --reseat --relaunch --seat cl 2>&1); echo "$out" | grep -q '^RESEAT cl:' && echo "$out" | grep -q '^MOVE cl' && ok "a right seat still under its old folder is restarted to move" || bad "relaunch claude: $out"
grep -q 'not yet in its new folder' <<< "$(R --check --seat cl 2>&1)" && ok "--check names it" || bad "check claude: $(R --check --seat cl 2>&1)"
mv "$CO" "$CN"
grep -q '^OK cl: started by rescue, right already' <<< "$(R --reseat --relaunch --seat cl 2>&1)" && ok "once its project has moved it is left alone" || bad "claude right: $(R --reseat --relaunch --seat cl 2>&1)"
grep -q '^OK cl (claude)' <<< "$(R --check --seat cl 2>&1)" && ok "and passes --check" || bad "check moved: $(R --check --seat cl 2>&1)"
: > "$T/moves"; mv "$CN" "$CO"; mv "$T/w/cl" "$T/w/cl.gone"; rm -f "$T/launched"; out=$(R --reseat --relaunch --apply --seat cl 2>&1); rc=$?; mv "$T/w/cl.gone" "$T/w/cl"
[ $rc -eq 3 ] && echo "$out" | grep -q "^UNRESOLVED cl: no directory $T/w/cl" && [ ! -e "$T/launched" ] && ok "a live seat whose folder is gone, with no line, is named and left alone" || bad "gone folder: $rc $out"
rm -rf "$CO"; mkdir -p "$CN"
: > "$T/moves"; : > "$T/ps.out"; : > "$T/panes"; printf '' > "$T/psE.out"; rm -f "$T/claudeadd"; rm -rf "$CN"; cp -R "$T/cproj" "$CO"; export ZEO_RESCUE_PINS="$T/no-pins"; reset_live

echo "-- a check reads all its input: under pipefail a reader that leaves early turns a match into a miss"
pad() { printf '%s\n' "$1"; head -c 1000000 /dev/zero | tr '\0' x; echo; }
hits=$(grep -nE '\| *(/usr/bin/)?grep +(-[a-zA-Z]+ +)*-[a-zA-Z]*q' "$HERE/rescue.sh" "$HERE/reseat-lines.sh" "$HERE/zshenv-lines.sh")
[ -z "$hits" ] && ok "no script pipes into grep -q" || bad "pipes into grep -q: $hits"
reset_live; echo cx-maintainer >> "$T/live"; echo 'cx-maintainer|%8|800||codex' > "$T/panes"
echo "800 /x/codex resume -a never -s danger-full-access -C $T/w/cx --no-daemon 44444444-4444-4444-8444-444444444444 p" > "$T/ps.out"
pad '  Working (9s, esc to interrupt)' > "$T/screen"
grep -q '^WORK cx: a turn is in progress' <<< "$(R --reseat --seat cx 2>&1)" && ok "a turn is found on a screen larger than the pipe" || bad "big screen"
pad '  Trust this folder? Codex can read, edit, and run files here' > "$T/screen"
echo 'cx-maintainer|%8|800|1|codex' > "$T/panes"
grep -q 'waiting at the trust prompt' <<< "$(R --check --seat cx 2>&1)" && ok "a seat at the trust screen is found the same way" || bad "big trust"
rm -f "$T/screen"; reset_live
echo "700 /x/codex resume 44444444-4444-4444-8444-444444444444" > "$T/ps.out"; pad "n$T/w/cx" > "$T/lsof.out"
grep -q '^RUNNING cx:' <<< "$(R --seat cx 2>&1)" && ok "a process in the folder is found in a long lsof answer, so no second writer starts" || bad "big lsof"
: > "$T/lsof.out"; : > "$T/ps.out"; reset_live

echo "-- the chart and usage"
grep -q 'WARNING.*last good' <<< "$(R --chart "$T/gone.json" 2>&1)" && ok "an unreadable chart falls back to the last good one, out loud" || bad "fallback"
rm -f "$T/state/ORG-CHART.last-good.json"; R --chart "$T/gone.json" >/dev/null 2>&1; [ $? -eq 1 ] && ok "no chart at all is a failure" || bad "no chart"
"$HERE/rescue.sh" --socket '../x' >/dev/null 2>&1; [ $? -eq 2 ] && ok "a bad socket name is usage" || bad "bad socket"
"$HERE/rescue.sh" --check --apply >/dev/null 2>&1; [ $? -eq 2 ] && ok "--check never combines with --apply" || bad "check apply"

echo "-- the operator's runner"
pl="$(id -un)@$(hostname -s)"
mkdir -p "$T/run/notes"
L() { "$T/run/reseat-lines.sh" "$@"; }
fill() { for f in rescue.sh seat-exec.sh Makefile session-pins notes/reseat-20261105.txt notes/zeoarchitect-resume.txt notes/lic-test-20261106.txt notes/codex-relaunch-20261106.txt notes/claude-move-zbs-20261107.txt notes/zeocreator-memory-20261108.txt zbs-move.sh folder-moves zshenv-lines.sh; do cp "$HERE/$f" "$T/run/$f"; done; }
fill; sed "s/^WANT=.*/WANT=nobody@nowhere/" "$HERE/reseat-lines.sh" > "$T/run/reseat-lines.sh"; chmod +x "$T/run/reseat-lines.sh"
out=$(L verify 2>&1); rc=$?
[ $rc -eq 2 ] && echo "$out" | grep -q '^WRONG PLACE, nothing was run: you are ' && ok "the wrong place refuses in plain words" || bad "place: $rc $out"
sed "s/^WANT=.*/WANT=$pl/" "$HERE/reseat-lines.sh" > "$T/run/reseat-lines.sh"; chmod +x "$T/run/reseat-lines.sh"
L nonsense >/dev/null 2>&1; [ $? -eq 2 ] && ok "an unknown step runs nothing" || bad "step"
out=$(L verify 2>&1); [ $? -eq 0 ] && echo "$out" | grep -q '^verified:' && ok "the pins match the files in this checkout" || bad "pins are stale: $out"
for f in rescue.sh seat-exec.sh Makefile session-pins notes/reseat-20261105.txt notes/zeoarchitect-resume.txt notes/lic-test-20261106.txt notes/codex-relaunch-20261106.txt notes/claude-move-zbs-20261107.txt notes/zeocreator-memory-20261108.txt zbs-move.sh folder-moves zshenv-lines.sh; do
  echo >> "$T/run/$f"; out=$(L proof 2>&1); rc=$?
  [ $rc -eq 2 ] && echo "$out" | grep -q "^HASH MISMATCH, nothing was run: $f is" && ok "a change to $f refuses" || bad "pin $f: $rc $out"
  cp "$HERE/$f" "$T/run/$f"
done
: > "$T/live"
out=$(L all 2>&1); rc=$?
[ $rc -eq 2 ] && echo "$out" | grep -q '^OUT OF ORDER, nothing was run: zeoarchitect is not up' && ok "all refuses until zeoarchitect has its own note" || bad "order: $rc $out"
: > "$T/tmux.log"; echo '  Working (3s • esc to interrupt)' > "$T/screen"
out=$(L lic 2>&1); rc=$?
[ $rc -eq 2 ] && echo "$out" | grep -q '^BUSY, nothing was run: dt-brandedimage-maintainer' && ok "lic refuses while the seat is working" || bad "busy: $rc $out"
grep -q 'set-option -pu' "$T/tmux.log" && bad "lic cleared the mark on a working seat" || ok "and leaves its mark alone"
rm -f "$T/screen"; : > "$T/tmux.log"
STATE="$T/state" ZEO_RESCUE_CHART="$T/chart.json" L lic >/dev/null 2>&1
grep -q 'set-option -pu -t =dt-brandedimage-maintainer: @zeo_rescue' "$T/tmux.log" && ok "lic clears the mark, or a reseat would skip the seat" || bad "lic mark: $(cat "$T/tmux.log")"

echo "-- the Codex steps refuse out of order"
sed -e "s/^WANT=.*/WANT=$pl/" -e '/ zshenv-lines\.sh$/d' "$HERE/reseat-lines.sh" > "$T/run/reseat-lines.sh"; chmod +x "$T/run/reseat-lines.sh"
printf '#!/bin/bash\nif [ -f "%s/zshenv-changed" ]; then echo CHANGED; else echo ORIGINAL; fi\n' "$T" > "$T/run/zshenv-lines.sh"; chmod +x "$T/run/zshenv-lines.sh"
repin() { h=$(/usr/bin/shasum -a 256 "$T/run/folder-moves" | cut -d' ' -f1); perl -i -pe "s/^pin [0-9a-f]+ folder-moves\$/pin $h folder-moves/" "$T/run/reseat-lines.sh"; }
echo "# no folders yet" > "$T/run/folder-moves"; repin
grep -q '^NOT READY, nothing was run: folder-moves needs one existing folder for zeoapp' <<< "$(L codex-first 2>&1)" && ok "codex-first refuses until every folder is named" || bad "ready: $(L codex-first 2>&1)"
grep -q '^NOT READY' <<< "$(L trust 2>&1)" && ok "so does trust" || bad "trust ready"
mkdir -p "$T/d"; for s in zeoapp rasa ducktyper profrod zeo-rt; do mkdir -p "$T/d/$s"; echo "$s $T/d/$s"; done > "$T/run/folder-moves"; repin
grep -q '^OUT OF ORDER, nothing was run: the .zshenv line comes first' <<< "$(L codex-first 2>&1)" && ok "codex-first needs .zshenv first" || bad "zshenv first: $(L codex-first 2>&1)"
grep -q '^OUT OF ORDER, nothing was run: the .zshenv line comes first' <<< "$(L codex-rest 2>&1)" && ok "so does codex-rest" || bad "zshenv rest"
touch "$T/zshenv-changed"
grep -q '^OUT OF ORDER, nothing was run: zeoapp is not right yet' <<< "$(ZEO_RESCUE_CHART="$T/chart.json" L codex-rest 2>&1)" && ok "codex-rest needs the first seat right" || bad "first first: $(ZEO_RESCUE_CHART="$T/chart.json" L codex-rest 2>&1)"
out=$(ZEO_RESCUE_CODEX_CONFIG="$T/cfg.toml" sh -c ': > "$ZEO_RESCUE_CODEX_CONFIG"; '"$T/run/reseat-lines.sh trust" 2>&1); rc=$?
[ $rc -eq 0 ] && echo "$out" | grep -q '^NOTHING TO ADD' && ok "trust adds nothing for folders outside git" || bad "trust none: $rc $out"
git -C "$T/d/zeoapp" init -q
printf '[projects."/kept"]\ntrust_level = "trusted"' > "$T/cfg.toml"; chmod 640 "$T/cfg.toml"
out=$(ZEO_RESCUE_CODEX_CONFIG="$T/cfg.toml" L trust 2>&1); rc=$?
[ $rc -eq 0 ] && echo "$out" | grep -q "^TRUST zeoapp: $T/d/zeoapp" && grep -qxF "[projects.\"$T/d/zeoapp\"]" "$T/cfg.toml" && grep -qxF '[projects."/kept"]' "$T/cfg.toml" && ok "trust adds the one git folder and keeps the rest" || bad "trust add: $rc $out"
[ "$(stat -f %Lp "$T/cfg.toml")" = 640 ] && ok "and the file's mode" || bad "cfg mode"
[ -e "$T/state/codex-config.before-20261106" ] && ok "and keeps a backup" || bad "cfg backup"
grep -q '^NOTHING TO ADD' <<< "$(ZEO_RESCUE_CODEX_CONFIG="$T/cfg.toml" L trust 2>&1)" && ok "a second trust adds nothing" || bad "trust twice"
printf '[projects."%s"]\ntrust_level = "untrusted"\n' "$T/d/zeoapp" > "$T/cfg.toml"
out=$(ZEO_RESCUE_CODEX_CONFIG="$T/cfg.toml" L trust 2>&1); rc=$?
[ $rc -eq 2 ] && echo "$out" | grep -q '^REFUSED, nothing was changed' && ok "trust never overrides an untrusted entry" || bad "trust untrusted: $rc $out"
row() { printf '{"seat_id":"%s","mailbox":"%s","desired_agent":"codex","desired_host":"matormini","desired_tmux":{"session":"%s"},"desired_folder":"%s"}' "$1" "$1" "$1" "$T/w/$1"; }
mkdir -p "$T/w/zeoapp"; echo "{\"seats\":[$(row zeoapp)]}" > "$T/chart2.json"
echo zeoapp >> "$T/live"; echo "zeoapp|%8|800||codex" > "$T/panes"
echo "800 /x/codex resume -a never -s danger-full-access -C $T/w/zeoapp --no-daemon 01a101c3-4a96-7933-b7b7-7914d9da286d p" > "$T/ps.out"
sed -i '' "s#^case \"\\\$2\" in\$#case \"\$2\" in *01a101c3*) printf '%s %s\\\\n' 01a101c3-4a96-7933-b7b7-7914d9da286d \"$T/sess/full.jsonl\" ;; esac; case \"\$2\" in#" "$T/bin/sqlite3" 2>/dev/null
echo '  Working (3s • esc to interrupt)' > "$T/screen"
out=$(ZEO_RESCUE_PINS="$HERE/session-pins" ZEO_RESCUE_MOVES="$T/run/folder-moves" ZEO_RESCUE_CHART="$T/chart2.json" ZEO_RESCUE_CODEX_CONFIG="$T/cfg-ok.toml" sh -c "printf '[projects.\"$T/d/zeoapp\"]\ntrust_level = \"trusted\"\n' > '$T/cfg-ok.toml'; '$T/run/reseat-lines.sh' codex-first" 2>&1); rc=$?
[ $rc -eq 2 ] && echo "$out" | grep -q '^BUSY, nothing was run' && echo "$out" | grep -q 'WORK zeoapp: a turn is in progress' && ok "codex-first refuses while the seat is working, and names it" || bad "busy first: $rc $out"
rm -f "$T/screen"

echo "-- the Claude steps"
: > "$T/live"; mkdir -p "$T/d/creator"; sed -e "s/^WANT=.*/WANT=$pl/" -e '/ zshenv-lines\.sh$/d' -e "s#^CLAUDE_NEW=.*#CLAUDE_NEW=$T/d/creator#" -e "s#^CLAUDE_OLD=.*#CLAUDE_OLD=$T/d/oldc#" -e "s#^CLAUDE_INODE=.*#CLAUDE_INODE=$(stat -f %i "$T/d/creator")#" -e "s#^CLAUDE_READY_MARK=.*#CLAUDE_READY_MARK=$T/ready#" "$HERE/reseat-lines.sh" > "$T/run/reseat-lines.sh"; chmod +x "$T/run/reseat-lines.sh"
echo "# none" > "$T/run/folder-moves"; repin
grep -q '^NOT READY, nothing was run: folder-moves needs zbs' <<< "$(L claude-first 2>&1)" && ok "claude-first refuses until the Architect names the folder" || bad "claude ready: $(L claude-first 2>&1)"
echo "zbs $T/d/creator" > "$T/run/folder-moves"; repin
printf '{"projects":{}}' > "$T/cj0.json"; out=$(ZEO_RESCUE_CLAUDE_JSON="$T/cj0.json" L claude-trust 2>&1); rc=$?
[ $rc -eq 2 ] && echo "$out" | grep -q '^OUT OF ORDER, nothing was run: the folder step has not finished' && [ "$(cat "$T/cj0.json")" = '{"projects":{}}' ] && ok "claude-trust waits for the folder step" || bad "ready mark: $rc $out"
grep -q '^OUT OF ORDER, nothing was run: the folder step' <<< "$(L claude-first 2>&1)" && ok "so does claude-first" || bad "ready mark first: $(L claude-first 2>&1)"
touch "$T/ready"; perl -i -pe 's/^CLAUDE_INODE=.*/CLAUDE_INODE=1/' "$T/run/reseat-lines.sh"; out=$(ZEO_RESCUE_CLAUDE_JSON="$T/cj0.json" L claude-trust 2>&1); rc=$?
[ $rc -eq 2 ] && echo "$out" | grep -q "^NOT READY, nothing was run: $T/d/creator is not the seat's own folder (inode 1)" && [ "$(cat "$T/cj0.json")" = '{"projects":{}}' ] && ok "another folder at the new path, such as the 24 Sep checkout, is never trusted" || bad "inode: $rc $out"
grep -q "^NOT READY, nothing was run: .* is not the seat's own folder" <<< "$(L claude-first 2>&1)" && ok "or started in" || bad "inode first: $(L claude-first 2>&1)"
perl -i -pe "s/^CLAUDE_INODE=.*/CLAUDE_INODE=$(stat -f %i "$T/d/creator")/" "$T/run/reseat-lines.sh"
printf '{"keep":1,"projects":{"/a":{"hasTrustDialogAccepted":true}}}' > "$T/cj.json"; chmod 640 "$T/cj.json"
out=$(ZEO_RESCUE_CLAUDE_JSON="$T/cj.json" L claude-trust 2>&1); rc=$?
[ $rc -eq 0 ] && echo "$out" | grep -q '^ADDED' && [ "$(jq -r --arg d "$T/d/creator" '.projects[$d].hasTrustDialogAccepted' "$T/cj.json")" = true ] && [ "$(jq -r '.keep,.projects["/a"].hasTrustDialogAccepted' "$T/cj.json" | tr '\n' ' ')" = "1 true " ] && ok "claude-trust adds one entry and keeps the rest" || bad "claude trust: $rc $out"
[ "$(stat -f %Lp "$T/cj.json")" = 640 ] && [ ! -e "$T/cj.json.lock" ] && ok "with the file's mode, and lets go of the lock" || bad "mode or lock"
B="$T/state/claude-json.before-20261107"; [ "$(stat -f %Lp "$B")" = 600 ] && [ "$(jq -c . "$B")" = '{"keep":1,"projects":{"/a":{"hasTrustDialogAccepted":true}}}' ] && ok "the backup is the old file, mode 600, though the file is 640" || bad "backup: $(stat -f %Lp "$B")"
chmod 644 "$B"; printf '{"projects":{}}' > "$T/cj4.json"; ZEO_RESCUE_CLAUDE_JSON="$T/cj4.json" L claude-trust >/dev/null 2>&1; [ "$(stat -f %Lp "$B")" = 600 ] && ok "a backup already there is brought to 600" || bad "old backup mode: $(stat -f %Lp "$B")"
rm -f "$B"; mkdir -p "$T/bin3"; realjq=$(command -v jq)
cat > "$T/bin3/jq" <<S
#!/bin/bash
"$realjq" "\$@"; rc=\$?
case "\$*" in *"+ {hasTrustDialogAccepted: true}"*) printf '{"projects":{},"writer":1}' > "$T/cj3.json";; esac
exit \$rc
S
chmod +x "$T/bin3/jq"; printf '{"projects":{}}' > "$T/cj3.json"
out=$(PATH="$T/bin3:$PATH" ZEO_RESCUE_CLAUDE_JSON="$T/cj3.json" L claude-trust 2>&1); rc=$?
[ $rc -eq 2 ] && echo "$out" | grep -q '^REFUSED, nothing was changed: .* changed while the lock was held' && [ "$(cat "$T/cj3.json")" = '{"projects":{},"writer":1}' ] && ok "a writer that ignores the lock is refused, and its write stands" || bad "writer: $rc $out $(cat "$T/cj3.json")"
[ ! -e "$T/cj3.json.zeo" ] && [ ! -e "$T/cj3.json.lock" ] && [ ! -e "$B" ] && ok "and the refusal leaves no copy, no lock and no backup behind" || bad "refusal left: $(ls "$T" | grep cj3) $(ls "$B" 2>/dev/null)"
printf '#!/bin/sh\ncat "%s" 2>/dev/null\n' "$T/ver" > "$T/bin/claudev"; chmod +x "$T/bin/claudev"; rm -f "$T/launched"
echo "2.1.999 (Claude Code)" > "$T/ver"; out=$(ZEO_RESCUE_CLAUDE="$T/bin/claudev" ZEO_RESCUE_CHART="$T/chart.json" L claude-first 2>&1); rc=$?
[ $rc -eq 2 ] && echo "$out" | grep -q '^VERSION CHANGED, nothing was run: Claude is 2.1.999' && [ ! -e "$T/launched" ] && ok "claude-first refuses a Claude nobody rehearsed" || bad "version: $rc $out"
rm -f "$T/ver"; out=$(ZEO_RESCUE_CLAUDE="$T/bin/claudev" ZEO_RESCUE_CHART="$T/chart.json" L claude-first 2>&1); rc=$?
[ $rc -eq 2 ] && echo "$out" | grep -q '^VERSION CHANGED, nothing was run: Claude is unknown' && ok "and one it cannot read" || bad "no version: $rc $out"
rv=$(awk -F= '/^CLAUDE_REHEARSED=/ {print $2}' "$T/run/reseat-lines.sh"); echo "$rv (Claude Code)" > "$T/ver"; out=$(STATE="$T/state" ZEO_RESCUE_CLAUDE="$T/bin/claudev" ZEO_RESCUE_CHART="$T/chart.json" L claude-first 2>&1)
echo "$out" | grep -q "^the Claude that will run: $rv; rehearsed on $rv" && echo "$out" | grep -qx "claude $rv" && ok "the version is read just before the line and printed, in the kept log too" || bad "version print: $out"
echo "2.1.999 (Claude Code)" > "$T/ver"; rm -f "$T/launched"; out=$(ZEO_RESCUE_CLAUDE="$T/bin/claudev" ZEO_RESCUE_CHART="$T/chart.json" L zeocreator-note 2>&1); rc=$?
[ $rc -eq 2 ] && echo "$out" | grep -q '^VERSION CHANGED, nothing was run: Claude is 2.1.999' && [ ! -e "$T/launched" ] && ok "zeocreator-note refuses a Claude nobody rehearsed too" || bad "zc version: $rc $out"
# zeocreator-note on a stub rescue.sh: the plan it prints is $T/zn/plan; with --apply it writes the note's words into the transcript if $T/zn/deliver exists.
echo "$rv (Claude Code)" > "$T/ver"; rm -rf "$T/zn"; mkdir -p "$T/zn/proj" "$T/zn/state"; for f in rescue.sh folder-moves session-pins; do cp "$T/run/$f" "$T/zn/$f.keep"; done
pinf() { local f h; for f in "$@"; do h=$(/usr/bin/shasum -a 256 "$T/run/$f" | cut -d' ' -f1); F=$f H=$h perl -i -pe 's/^pin [0-9a-f]{64} \Q$ENV{F}\E$/pin $ENV{H} $ENV{F}/' "$T/run/reseat-lines.sh"; done; }
zsid=84bd8e22-bfe4-4e9e-85e4-bbcc3959c34c; zdir=$T/zn/creator; ztr=$T/zn/proj/$(enc2 "$zdir")/$zsid.jsonl; zw=$(awk -F'"' '/^ZEOCREATOR_PROOF=/ {print $2}' "$T/run/reseat-lines.sh")
echo "zeocreator $zdir" > "$T/run/folder-moves"; echo "zeocreator $zsid" > "$T/run/session-pins"
cat > "$T/run/rescue.sh" <<S
#!/bin/bash
echo "\$*" >> "$T/zn/calls"
case " \$* " in
  *" --check "*) echo "OK zeocreator (claude)"; echo "check: ok 1, wrong 0";;
  *" --apply "*) echo "RESUMED zeocreator: stub"; [ ! -f "$T/zn/deliver" ] || printf '{"type":"user","message":{"content":"Correction. %s"}}\n' "$zw" >> "$ztr";;
  *) cat "$T/zn/plan";;
esac
S
chmod +x "$T/run/rescue.sh"; pinf rescue.sh folder-moves session-pins
ZN() { ZEO_RESCUE_STATE="$T/zn/state" ZEO_RESCUE_PROJECTS="$T/zn/proj" ZEO_RESCUE_CLAUDE="$T/bin/claudev" ZEO_RESCUE_PROOF_TRIES=2 L zeocreator-note 2>&1; }
out=$(ZN); rc=$?; [ $rc -eq 2 ] && echo "$out" | grep -q '^NOT READY, nothing was run: no transcript for zeocreator' && [ ! -e "$T/zn/calls" ] && ok "zeocreator-note needs the seat's transcript where its folder says" || bad "zn transcript: $rc $out"
mkdir -p "$(dirname "$ztr")"; echo '{"type":"user","message":{"content":"before"}}' > "$ztr"
echo "OK zeocreator: started by rescue, right already" > "$T/zn/plan"; out=$(ZN); rc=$?
[ $rc -eq 2 ] && echo "$out" | grep -q '^REFUSED, nothing was run: the plan does not restart zeocreator' && ! grep -q -- '--apply' "$T/zn/calls" && ok "it refuses a plan that would not restart the seat: the 04:27 fault" || bad "zn no plan: $rc $out"
grep -q -- '--reseat --relaunch --restart --harness claude --seat zeocreator --note-file notes/zeocreator-memory-20261108.txt' "$T/zn/calls" && ok "and it plans with --restart and the note" || bad "zn plan args: $(cat "$T/zn/calls")"
printf 'RESEAT zeocreator: claude %s\nWORK zeocreator: a turn is in progress on its screen\n' "$zsid" > "$T/zn/plan"; out=$(ZN); rc=$?
[ $rc -eq 2 ] && echo "$out" | grep -q '^BUSY, nothing was run' && ! grep -q -- '--apply' "$T/zn/calls" && ok "it refuses while the seat is working" || bad "zn busy: $rc $out"
printf 'RESEAT zeocreator: claude %s\n' "$zsid" > "$T/zn/plan"; out=$(ZN); rc=$?
[ $rc -eq 1 ] && echo "$out" | grep -q '^NOT DELIVERED: ' && [ ! -e "$T/zn/state/zeocreator-note-20261108.done" ] && ok "a restart whose transcript never shows the note says NOT DELIVERED and marks nothing" || bad "zn undelivered: $rc $out"
cp "$ztr" "$T/zn/tr.keep"; printf '{"type":"user","message":{"content":"%s"}}\n' "$zw" >> "$ztr"; out=$(ZN); rc=$?; cp "$T/zn/tr.keep" "$ztr"
[ $rc -eq 2 ] && echo "$out" | grep -q "^REFUSED, nothing was run: the note's words are already in" && ok "it refuses when the words are already there, since the proof could not tell runs apart" || bad "zn words before: $rc $out"
: > "$T/zn/calls"; : > "$T/zn/deliver"; out=$(ZN); rc=$?
[ $rc -eq 0 ] && echo "$out" | grep -q "^the Claude that will run: $rv; rehearsed on $rv" && echo "$out" | grep -qx "claude $rv" && echo "$out" | grep -q "^NOTE DELIVERED zeocreator: its words are in session $zsid" && [ -s "$T/zn/state/zeocreator-note-20261108.done" ] && ok "with the seat idle it restarts, proves the note reached the transcript, and marks itself done" || bad "zn deliver: $rc $out"
grep -q -- '--reseat --apply --relaunch --restart --harness claude --seat zeocreator --note-file notes/zeocreator-memory-20261108.txt' "$T/zn/calls" && ok "the restart itself carries --restart and the note" || bad "zn apply args: $(cat "$T/zn/calls")"
: > "$T/zn/calls"; out=$(ZN); rc=$?; [ $rc -eq 0 ] && echo "$out" | grep -q '^ALREADY DONE: the note reached zeocreator' && [ ! -s "$T/zn/calls" ] && ok "a second run restarts nothing" || bad "zn twice: $rc $out"
for f in rescue.sh folder-moves session-pins; do cp "$T/zn/$f.keep" "$T/run/$f"; done; pinf rescue.sh folder-moves session-pins
grep -q 'zeroemployeeorg-zeocreator/memory/' "$HERE/notes/zeocreator-memory-20261108.txt" && grep -q "never in the old folder" "$HERE/notes/zeocreator-memory-20261108.txt" && grep -qF "$(printf %s /Volumes/AIPEMedia1/code/ducktyper-ai/dt-creator/main | LC_ALL=C sed 's/[^A-Za-z0-9]/-/g')/memory/" "$HERE/notes/zeocreator-memory-20261108.txt" && ok "its note names the old memory folder as gone, and the real one by the key of its folder" || bad "zc note"
SIDC=d7fc6540-05c6-43ec-94c5-520b66af4133; kc=$(printf %s "$T/d/creator" | LC_ALL=C sed 's/[^A-Za-z0-9]/-/g'); printf '{"seats":[{"seat_id":"zbs","mailbox":"zbs","desired_agent":"claude","desired_host":"matormini","desired_tmux":{"session":"zc"},"desired_folder":"%s"}]}' "$T/d/oldc" > "$T/zc.json"
C() { ZEO_RESCUE_CHART="$T/zc.json" ZEO_RESCUE_PINS="$T/run/session-pins" ZEO_RESCUE_MOVES="$T/run/folder-moves" ZEO_RESCUE_PROJECTS="$T/pc" ZEO_RESCUE_CLAUDE_JSON="$T/cj.json" L "$@" 2>&1; }
mkdir -p "$T/pc/$kc"; : > "$T/pc/$kc/$SIDC.jsonl"; echo x > "$B"; echo zc >> "$T/live"; echo "zc|%9|900|1|claude" > "$T/panes"; echo "900 /x/claude --resume $SIDC" > "$T/ps.out"
echo "$GOOD ZMAIL_INSTANCE=other" > "$T/psE.out"; out=$(C claude-clear); rc=$?
[ $rc -eq 2 ] && echo "$out" | grep -q '^OUT OF ORDER, nothing was deleted: zbs is not right yet' && [ -e "$B" ] && ok "claude-clear keeps the backup while the seat is wrong" || bad "clear wrong: $rc $out"
echo "$GOOD ZMAIL_INSTANCE=zbs" > "$T/psE.out"; out=$(C claude-clear); rc=$?
[ $rc -eq 0 ] && echo "$out" | grep -q '^DELETED' && [ ! -e "$B" ] && ok "claude-clear deletes it once the seat checks right" || bad "clear: $rc $out"
grep -q '^NOTHING TO DELETE' <<< "$(C claude-clear)" && ok "and a second run has nothing to do" || bad "clear twice"
: > "$T/live"; : > "$T/panes"; : > "$T/ps.out"; : > "$T/psE.out"
grep -q '^NOTHING TO ADD' <<< "$(ZEO_RESCUE_CLAUDE_JSON="$T/cj.json" L claude-trust 2>&1)" && ok "a second run changes nothing" || bad "trust twice"
printf '{"projects":{}}' > "$T/cj2.json"; mkdir "$T/cj2.json.lock"
out=$(ZEO_RESCUE_CLAUDE_JSON="$T/cj2.json" L claude-trust 2>&1); rc=$?; rmdir "$T/cj2.json.lock"
[ $rc -eq 1 ] && echo "$out" | grep -q "Claude's config lock stayed held" && [ "$(cat "$T/cj2.json")" = '{"projects":{}}' ] && ok "it waits for Claude's own lock and changes nothing if it stays held" || bad "lock: $rc $out"
out=$(ZEO_RESCUE_PROJECTS="$T/pj" L claude-back 2>&1); rc=$?
[ $rc -eq 2 ] && echo "$out" | grep -q 'take zbs out of folder-moves first' && ok "claude-back refuses while the seat's line stands" || bad "back: $rc $out"
echo "# none" > "$T/run/folder-moves"; repin; SIDC=d7fc6540-05c6-43ec-94c5-520b66af4133; kn=$(printf %s "$T/d/creator" | LC_ALL=C sed 's/[^A-Za-z0-9]/-/g'); ko=$(printf %s "$T/d/oldc" | LC_ALL=C sed 's/[^A-Za-z0-9]/-/g'); mkdir -p "$T/pj/$kn/memory"; : > "$T/pj/$kn/$SIDC.jsonl"
rmdir "$T/d/oldc" 2>/dev/null; out=$(ZEO_RESCUE_PROJECTS="$T/pj" L claude-back 2>&1); rc=$?
[ $rc -eq 2 ] && echo "$out" | grep -q 'is gone, so the project would have no folder' && [ -f "$T/pj/$kn/$SIDC.jsonl" ] && ok "claude-back refuses while the old folder is gone" || bad "back gone: $rc $out"
mkdir -p "$T/d/oldc"; out=$(ZEO_RESCUE_PROJECTS="$T/pj" L claude-back 2>&1); rc=$?
if ps -axo command= | grep -F "$SIDC" | grep -F -e '--resume' >/dev/null; then [ $rc -eq 2 ] && echo "$out" | grep -q 'a process still holds session' && ok "claude-back refuses while the seat runs" || bad "back held: $rc $out"
else [ $rc -eq 0 ] && [ -f "$T/pj/$ko/$SIDC.jsonl" ] && ok "claude-back puts the project back" || bad "back: $rc $out"; fi


echo "-- the zbs move: the seat's folder becomes the repository, then moves whole (zbs-move.sh, on a copy in the same shape)"
# Never the real script: a copy with every path rewritten into $T. The real one would act on the real folders.
Z=$(cd "$T" && pwd -P)/z; ZG() { git -c user.email=t@t -c user.name=t -c init.defaultBranch=main "$@"; }
printf '#!/bin/bash\ncat "%s/lsofz.out" 2>/dev/null\n' "$T" > "$T/bin/lsofz"; chmod +x "$T/bin/lsofz"
ZPRUNE="-engine r41-38 verify-main-3b16cf4 verify-pr-43b283e wt-dryrun wt-ecamm wt-jev wt-mcp2 wt-series wt-split"
zsettings() { # the seat's settings in the shape read on 8 Nov: the allow rule, the 16 deny and 4 ask rules to mirror, others around them
  jq -n --arg p /Volumes/AIPEMedia1/code/zeroemployeeorg/ '{permissions: {allow: ["Bash(ls)", "Edit(\($p)**)"],
    deny: (["Bash(rm -rf:*)"] + ([".git/**", "**/.git/**", ".git", "**/.git", "**/.githooks/**", "**/.husky/**", "*.git/hooks/**", "**/*.git/hooks/**"] | map("Edit(\($p)\(.))", "Write(\($p)\(.))")) + ["Read(**/*.pem)"]),
    ask: ((["**/Makefile", "**/*.mk"] | map("Edit(\($p)\(.))", "Write(\($p)\(.))")) + ["Edit(~/code/x/**/Makefile)"])}}'; }
zwant() { # what the folder step must leave: the allow rule moved, each of the 20 followed by its mirror under the prefix $1, nothing else
  zsettings | jq --arg q "$1" '.permissions.allow |= map(sub("^Edit\\(/Volumes/AIPEMedia1/code/zeroemployeeorg/"; "Edit(/Volumes/AIPEMedia1/code/ducktyper-ai/dt-broadcastingstudio/main/"))
    | (.permissions.deny, .permissions.ask) |= [.[] | ., (select(test("^(Edit|Write)\\(/Volumes/AIPEMedia1/code/zeroemployeeorg/")) | sub("\\(/Volumes/AIPEMedia1/code/zeroemployeeorg/"; "(\($q)"))]'; }
mkz() { # the shape read on 7 Nov: a store with its own clean checkout, the seat's worktree, wt-screensaver, 10 dead records
  rm -rf "$Z"; mkdir -p "$Z/dt" "$Z/org" "$Z/tmpz" "$Z/proj" "$Z/state"; : > "$T/lsofz.out"; : > "$T/screen"
  ZM_MAIN=$Z/dt/main ZM_SEAT=$Z/org/zeobroacastingstudio-zbs ZM_WT=$Z/tmpz/wt-screensaver
  ZG init -q "$ZM_MAIN"; printf 'data/\n.claude/settings.local.json\n' > "$ZM_MAIN/.gitignore"; echo a > "$ZM_MAIN/a.txt"; ZG -C "$ZM_MAIN" add -A; ZG -C "$ZM_MAIN" commit -qm A
  ZG -C "$ZM_MAIN" update-ref refs/remotes/origin/main HEAD; ZM_MH=$(git -C "$ZM_MAIN" rev-parse HEAD)
  ZG -C "$ZM_MAIN" worktree add -q --detach "$ZM_SEAT"; echo b > "$ZM_SEAT/b.txt"; ZG -C "$ZM_SEAT" add b.txt; ZG -C "$ZM_SEAT" commit -qm B; ZM_SH=$(git -C "$ZM_SEAT" rev-parse HEAD)
  mkdir -p "$ZM_SEAT/data" "$ZM_SEAT/.claude"; echo class > "$ZM_SEAT/data/CLASS-ITAM.md"; ln -s data/CLASS-ITAM.md "$ZM_SEAT/CLASS-LINK.md"; echo u > "$ZM_SEAT/untracked.txt"
  zsettings > "$ZM_SEAT/.claude/settings.local.json"
  ZG -C "$ZM_MAIN" worktree add -q -b zbs/set-screensaver "$ZM_WT"; echo w > "$ZM_WT/w-untracked.txt"
  for n in $ZPRUNE; do ZG -C "$ZM_MAIN" worktree add -q --detach "$Z/tmpz/$n" && rm -rf "$Z/tmpz/$n"; done
  for d in "$ZM_MAIN/.git" "$ZM_MAIN/.git/worktrees/zeobroacastingstudio-zbs"; do for f in ORIG_HEAD FETCH_HEAD COMMIT_EDITMSG; do [ -f "$d/$f" ] || echo x > "$d/$f"; done; mkdir -p "$d/refs"; done
  ZM_KEY=$(enc2 "$ZM_SEAT"); mkdir -p "$Z/proj/$ZM_KEY" "$Z/proj/$(enc2 "$Z/org/zeobroacastingstudio")/memory/sub"; : > "$Z/proj/$ZM_KEY/d7fc6540-05c6-43ec-94c5-520b66af4133.jsonl"
  echo '- [a](a.md)' > "$Z/proj/$(enc2 "$Z/org/zeobroacastingstudio")/memory/MEMORY.md"; echo s > "$Z/proj/$(enc2 "$Z/org/zeobroacastingstudio")/memory/sub/s.md"
  sed -e "s#^MAIN=.*#MAIN=$ZM_MAIN#" -e "s#^SEAT=.*#SEAT=$ZM_SEAT#" -e "s#^ASIDE=.*#ASIDE=$Z/dt/main-old-20260924#" -e "s#^WT=.*#WT=$ZM_WT#" -e "s#^MEM_FROM_DIR=.*#MEM_FROM_DIR=$Z/org/zeobroacastingstudio#" \
    -e "s#^SEAT_INODE=.*#SEAT_INODE=$(stat -f %i "$ZM_SEAT")#" -e "s#^SEAT_HEAD=.*#SEAT_HEAD=$ZM_SH#" -e "s#^MAIN_HEAD=.*#MAIN_HEAD=$ZM_MH#" "$HERE/zbs-move.sh" > "$Z/zbs-move.sh"
}
ZM() { STATE="$Z/state" ZEO_RESCUE_PROJECTS="$Z/proj" ZEO_RESCUE_TMUX="$T/bin/tmux" ZEO_RESCUE_LSOF="$T/bin/lsofz" bash "$Z/zbs-move.sh" "$@" 2>&1; }
zfp() { find "$Z/dt" "$Z/org" "$Z/tmpz" "$Z/proj" -exec stat -f '%N %i %z' {} + | LC_ALL=C sort | shasum; cat "$ZM_SEAT/.git" "$ZM_WT/.git" 2>/dev/null; }
zrefuse() { # zrefuse WHAT PATTERN: the step refuses in those words, and nothing in the shape changed
  local f0 out rc; f0=$(zfp); out=$(ZM "${3:-repo}"); rc=$?
  [ $rc -eq 2 ] && echo "$out" | grep -q "$2" && [ "$(zfp)" = "$f0" ] && ok "$1" || bad "$1: $rc $out"
}
mkz
grep -E '^(MAIN|SEAT|ASIDE|WT|MEM_FROM_DIR)=/Volumes' "$Z/zbs-move.sh" >/dev/null && bad "the copy still names a real folder" || ok "the copy names no real folder"
echo '  Working (3s • esc to interrupt)' > "$T/screen"; zrefuse "the repo step refuses while the seat has a turn in progress" '^BUSY, nothing was changed'; : > "$T/screen"
mkdir "$Z/dt/main-old-20260924"; zrefuse "it refuses if the set-aside name is taken" 'main-old-20260924 is already there'; rmdir "$Z/dt/main-old-20260924"
cp "$ZM_SEAT/.git" "$T/gf"; echo "gitdir: /elsewhere" > "$ZM_SEAT/.git"; zrefuse "a seat folder not linked to that store is refused" 'is not the link to'; cp "$T/gf" "$ZM_SEAT/.git"
echo dirt > "$ZM_MAIN/dirt.txt"; zrefuse "a 24 Sep checkout that is not clean is refused" 'the 24 Sep checkout is not clean'; rm "$ZM_MAIN/dirt.txt"
git -C "$ZM_MAIN" update-ref -d refs/remotes/origin/main; zrefuse "its commit must be on origin/main" 'is not on origin/main'; ZG -C "$ZM_MAIN" update-ref refs/remotes/origin/main "$ZM_MH"
ZG -C "$ZM_MAIN" worktree add -q --detach "$Z/tmpz/extra" && rm -rf "$Z/tmpz/extra"; zrefuse "a worktree record not read on 7 Nov is refused" 'are not the 12 read on 7 Nov'; rm -rf "$ZM_MAIN/.git/worktrees/extra"
mkdir -p "$Z/tmpz/wt-jev"; cp "$ZM_SEAT/.git" "$Z/tmpz/wt-jev/.git"; perl -i -pe 's/zeobroacastingstudio-zbs/wt-jev/' "$Z/tmpz/wt-jev/.git"; echo "$Z/tmpz/wt-jev/.git" > "$ZM_MAIN/.git/worktrees/wt-jev/gitdir"
zrefuse "a dead record that came back to life is not pruned" "a prune would remove '-engine r41-38 verify-main-3b16cf4 verify-pr-43b283e wt-dryrun wt-ecamm wt-mcp2 wt-series wt-split'"; rm -rf "$Z/tmpz/wt-jev"
echo x > "$ZM_MAIN/.git/worktrees/zeobroacastingstudio-zbs/MERGE_HEAD"; zrefuse "a seat record mid-merge is refused" "the seat's record holds something not read"; rm "$ZM_MAIN/.git/worktrees/zeobroacastingstudio-zbs/MERGE_HEAD"
echo x > "$ZM_MAIN/.git/MERGE_HEAD"; zrefuse "a store holding anything not read is refused" 'holds something not read on 7 Nov'; rm "$ZM_MAIN/.git/MERGE_HEAD"
: > "$ZM_MAIN/.git/refs/heads/main.lock"; zrefuse "git at work is refused" 'git is at work'; rm "$ZM_MAIN/.git/refs/heads/main.lock"
printf 'p1\nfcwd\nn%s/sub\n' "$ZM_MAIN" > "$T/lsofz.out"; zrefuse "a process working in the 24 Sep checkout is refused" 'a process works in the 24 Sep checkout'; : > "$T/lsofz.out"
cp "$ZM_WT/.git" "$T/wf"; echo "gitdir: /elsewhere" > "$ZM_WT/.git"; zrefuse "wt-screensaver must be linked to the store" 'is not linked to'; cp "$T/wf" "$ZM_WT/.git"
zrefuse "the folder step waits for the repo step" '^OUT OF ORDER, nothing was changed: the repo step comes first' folder
sb=$(git -C "$ZM_SEAT" status --porcelain=v2 --branch --ignored); wb=$(git -C "$ZM_WT" status --porcelain=v2 --branch --ignored); nb=$(git -C "$ZM_MAIN" for-each-ref | wc -l)
out=$(ZM repo); rc=$?
[ $rc -eq 0 ] && echo "$out" | grep -q '^PRUNED: ' && echo "$out" | grep -q '^PROVED: ' && echo "$out" | grep -q '^REPO DONE: ' && ok "the repo step runs and proves itself" || bad "repo: $rc $out"
[ -d "$ZM_SEAT/.git" ] && [ "$(git -C "$ZM_SEAT" rev-parse --absolute-git-dir)" = "$(git -C "$ZM_SEAT" rev-parse --path-format=absolute --git-common-dir)" ] && ok "the seat's folder is the repository, not a worktree" || bad "still a worktree"
[ "$(git -C "$ZM_SEAT" rev-parse HEAD)" = "$ZM_SH" ] && ! git -C "$ZM_SEAT" symbolic-ref -q HEAD >/dev/null && ok "at the seat's own detached HEAD" || bad "head: $(git -C "$ZM_SEAT" rev-parse HEAD)"
[ "$(git -C "$ZM_SEAT" status --porcelain=v2 --branch --ignored)" = "$sb" ] && [ "$(git -C "$ZM_WT" status --porcelain=v2 --branch --ignored)" = "$wb" ] && [ "$(git -C "$ZM_SEAT" for-each-ref | wc -l)" = "$nb" ] && ok "git status in both, and the refs, read as before, by a reader outside the step" || bad "status changed"
[ "$(git -C "$ZM_SEAT" worktree list --porcelain | sed -n 's/^worktree //p' | paste -sd' ' -)" = "$ZM_SEAT $ZM_WT" ] && [ "$(cat "$ZM_WT/.git")" = "gitdir: $ZM_SEAT/.git/worktrees/wt-screensaver" ] && ok "the 10 dead records are gone, and wt-screensaver points at the seat's store" || bad "worktrees: $(git -C "$ZM_SEAT" worktree list)"
[ ! -e "$ZM_MAIN" ] && [ -f "$Z/dt/main-old-20260924/a.txt" ] && [ ! -e "$Z/dt/main-old-20260924/.git" ] && ok "the 24 Sep checkout is set aside, with no .git" || bad "aside: $(ls -a "$Z/dt")"
[ "$(cat "$Z/state/zbs-move-20261107/store-checkout-files/HEAD")" = "ref: refs/heads/main" ] && [ "$(stat -f %Lp "$Z/state/zbs-move-20261107")" = 700 ] && ok "its own git files are kept in the state folder, mode 700" || bad "kept: $(ls "$Z/state/zbs-move-20261107")"
grep -q '^ALREADY DONE' <<< "$(ZM repo)" && ok "a second repo step changes nothing" || bad "repo twice: $(ZM repo)"
mo=$Z/proj/$(enc2 "$Z/org/zeobroacastingstudio")/memory
mkdir "$Z/proj/$ZM_KEY/memory"; zrefuse "two memories are never merged" 'memory is already there, and two memories are not merged' folder; rmdir "$Z/proj/$ZM_KEY/memory"
mkdir "$Z/proj/$(enc2 "$ZM_MAIN")"; zrefuse "a project already under the new folder is refused" "holds more than an empty memory folder" folder; mkdir "$Z/proj/$(enc2 "$ZM_MAIN")/memory"; : > "$Z/proj/$(enc2 "$ZM_MAIN")/memory/x.md"; zrefuse "so is one whose memory folder holds anything" "holds more than an empty memory folder" folder; rm -rf "$Z/proj/$(enc2 "$ZM_MAIN")"
cp "$ZM_SEAT/.claude/settings.local.json" "$T/sl"; perl -i -pe 's#"Bash\(ls\)"#"Edit(/Volumes/AIPEMedia1/code/zeroemployeeorg/**)"#' "$ZM_SEAT/.claude/settings.local.json"; zrefuse "the allow rule must be there exactly once" 'exactly once' folder; cp "$T/sl" "$ZM_SEAT/.claude/settings.local.json"
perl -i -pe 's#"Edit\(/Volumes/AIPEMedia1/code/zeroemployeeorg/\*\*/\.git/\*\*\)"#"Edit(/Volumes/AIPEMedia1/code/zeroemployeeorg/**)"#' "$ZM_SEAT/.claude/settings.local.json"; zrefuse "and its text only once, or a deny of the same text would move too" "the rule.s text is not on exactly one line" folder; cp "$T/sl" "$ZM_SEAT/.claude/settings.local.json"
zset() { jq "$1" "$T/sl" > "$ZM_SEAT/.claude/settings.local.json"; }
zset '.permissions.ask |= map(select(. != "Write(/Volumes/AIPEMedia1/code/zeroemployeeorg/**/*.mk)"))'; zrefuse "each rule to mirror must be there" 'ask rules do not hold Write(/Volumes/AIPEMedia1/code/zeroemployeeorg/\*\*/\*\.mk) exactly once' folder
zset '.permissions.deny[0] = "Edit(/Volumes/AIPEMedia1/code/ducktyper-ai/dt-broadcastingstudio/main/.git)"'; zrefuse "a mirror already there is refused" 'already hold Edit(/Volumes/AIPEMedia1/code/ducktyper-ai/dt-broadcastingstudio/main/.git)' folder
zset '.permissions.ask |= (.[1:] + .[:1])'; zrefuse "a rule last in its list, with no comma after it, is refused" 'is not alone on one line, followed by a comma' folder
zset '.permissions.allow += ["Edit(/Volumes/AIPEMedia1/code/zeroemployeeorg/.git)"]'; zrefuse "so is a rule also named in another list" 'Edit(/Volumes/AIPEMedia1/code/zeroemployeeorg/.git) is not alone' folder
cp "$T/sl" "$ZM_SEAT/.claude/settings.local.json"
cp "$Z/zbs-move.sh" "$T/zm"; perl -i -pe "s/^MIRROR_ASK=.*/MIRROR_ASK='**\/Makefile'/" "$Z/zbs-move.sh"; zrefuse "a list of rules to mirror that is not the 20 read is refused" 'cannot list the 20 rules to mirror' folder; cp "$T/zm" "$Z/zbs-move.sh"
echo '  Working (3s • esc to interrupt)' > "$T/screen"; zrefuse "the folder step refuses while the seat has a turn in progress" '^BUSY' folder; : > "$T/screen"
cp "$Z/state/zbs-move-20261107/before-wt.txt" "$T/bw"; echo changed >> "$Z/state/zbs-move-20261107/before-wt.txt"; ino0=$(stat -f %i "$ZM_SEAT"); out=$(ZM folder); rc=$?
[ $rc -eq 1 ] && echo "$out" | grep -q '^STOPPED at the proof: it differs from before' && [ -d "$mo" ] && [ ! -e "$ZM_MAIN/.claude/settings.local.json.zeo" ] && grep -q 'zeroemployeeorg/\*\*)"' "$ZM_MAIN/.claude/settings.local.json" && ok "a git status that differs stops it before the memory and the settings" || bad "proof stop: $rc $out"
mv "$ZM_MAIN" "$ZM_SEAT"; git -C "$ZM_SEAT" worktree repair "$ZM_WT" 2>/dev/null; cp "$T/bw" "$Z/state/zbs-move-20261107/before-wt.txt"; mf=$(cd "$mo" && find . -type f | LC_ALL=C sort | xargs shasum)
mkdir -p "$Z/proj/$(enc2 "$ZM_MAIN")/memory"
out=$(ZM folder); rc=$?
[ $rc -eq 0 ] && echo "$out" | grep -q '^MOVED: ' && echo "$out" | grep -q '^MEMORY: 2 files' && echo "$out" | grep -q '^SETTINGS: ' && echo "$out" | grep -q "^CLEARED: the empty $Z/proj/$(enc2 "$ZM_MAIN")" && [ ! -e "$Z/proj/$(enc2 "$ZM_MAIN")" ] && echo "$out" | grep -q '^FOLDER DONE' && ok "the folder step runs and proves itself, clearing only the empty memory folder Claude makes under the new key" || bad "folder: $rc $out"
[ "$(stat -f %i "$ZM_MAIN")" = "$ino0" ] && [ ! -e "$ZM_SEAT" ] && [ -f "$ZM_MAIN/data/CLASS-ITAM.md" ] && [ "$(cat "$ZM_MAIN/CLASS-LINK.md")" = class ] && [ -f "$ZM_MAIN/untracked.txt" ] && ok "the folder moved whole: the same folder, ignored files, links and untracked files with it" || bad "moved: $(ls -a "$ZM_MAIN")"
[ "$(cat "$ZM_WT/.git")" = "gitdir: $ZM_MAIN/.git/worktrees/wt-screensaver" ] && [ "$(git -C "$ZM_WT" status --porcelain=v2 --branch --ignored)" = "$wb" ] && [ "$(git -C "$ZM_MAIN" status --porcelain=v2 --branch --ignored)" = "$sb" ] && ok "wt-screensaver is repaired again, and both read as before" || bad "wt after: $(cat "$ZM_WT/.git")"
[ ! -e "$mo" ] && [ "$(cd "$Z/proj/$ZM_KEY/memory" && find . -type f | LC_ALL=C sort | xargs shasum)" = "$mf" ] && ok "the memory moved into the seat's project, unchanged, for the restart's rename" || bad "memory: $(ls "$Z/proj/$ZM_KEY")"
sj=$ZM_MAIN/.claude/settings.local.json
[ "$(jq -S . "$sj")" = "$(zwant /Volumes/AIPEMedia1/code/ducktyper-ai/dt-broadcastingstudio/main/ | jq -S .)" ] && [ "$(jq '.permissions.deny | length' "$sj") $(jq '.permissions.ask | length' "$sj")" = "34 9" ] && ok "the one allow rule moved, the 20 rules are mirrored after their old ones, which stay, and nothing else changed" || bad "settings: $(jq -c . "$sj")"
echo "$out" | grep -q '^SETTINGS: .*; 16 deny and 4 ask rules mirrored under /Volumes/AIPEMedia1/code/ducktyper-ai/dt-broadcastingstudio/main, each after' && ok "and it says so" || bad "settings line: $out"
[ "$(stat -f %Lp "$Z/state/zbs-move-20261107/settings.local.json.before")" = 600 ] && [ -f "$Z/state/zbs-move-20261107/folder.done" ] && ok "the old settings are kept, mode 600, and the step marks itself done" || bad "settings backup"
grep -q '^ALREADY DONE: .*, by the step folder\. Nothing' <<< "$(ZM folder)" && ok "a second folder step changes nothing, and says which ran" || bad "folder twice: $(ZM folder)"
grep -q '^ALREADY DONE: .*, by the step folder\. Nothing' <<< "$(ZM folder-abs)" && ok "nor does folder-abs after it" || bad "abs after: $(ZM folder-abs)"
out=$(ZM fold); [ $? -eq 2 ] && grep -q '^usage: zbs-move.sh repo|folder|folder-abs; nothing was run' <<< "$out" && ok "an unknown step runs nothing" || bad "usage: $out"
mkz; ZM repo > /dev/null; out=$(ZM folder-abs); rc=$?; sj=$ZM_MAIN/.claude/settings.local.json
[ $rc -eq 0 ] && echo "$out" | grep -q '^FOLDER DONE' && echo "$out" | grep -q '^SETTINGS: .*; 16 deny and 4 ask rules mirrored under //Volumes/AIPEMedia1/code/ducktyper-ai/dt-broadcastingstudio/main, each after' && [ "$(jq -S . "$sj")" = "$(zwant //Volumes/AIPEMedia1/code/ducktyper-ai/dt-broadcastingstudio/main/ | jq -S .)" ] && ok "folder-abs does the same, with the 20 mirrored rules as absolute paths" || bad "abs: $rc $out $(jq -c . "$sj")"
[ "$(/usr/bin/diff "$Z/state/zbs-move-20261107/settings.local.json.before" "$sj" | grep -c '^>')" = 21 ] && grep -q '^ALREADY DONE: .*, by the step folder-abs\. Nothing' <<< "$(ZM folder)" && ok "21 lines added and 1 taken away; a second run says which step ran" || bad "abs diff"
echo '#!/bin/bash
echo "STUB $* STATE=$STATE"' > "$T/run/zbs-move.sh"; chmod +x "$T/run/zbs-move.sh"; zh=$(/usr/bin/shasum -a 256 "$T/run/zbs-move.sh" | cut -d' ' -f1); perl -i -pe "s/^pin [0-9a-f]+ zbs-move.sh\$/pin $zh zbs-move.sh/" "$T/run/reseat-lines.sh"
out=$(STATE="$T/st2" L zbs-repo 2>&1); echo "$out" | grep -q "^STUB repo STATE=$T/state" && echo "$out" | grep -q '^result kept in' && ok "zbs-repo runs the pinned step with the state folder" || bad "wire: $out"
grep -q '^STUB folder STATE' <<< "$(L zbs-folder 2>&1)" && ok "and so does zbs-folder" || bad "wire folder"; grep -q '^STUB folder-abs STATE' <<< "$(L zbs-folder-abs 2>&1)" && ok "and zbs-folder-abs" || bad "wire folder-abs"; rm -f "$T/screen"; cp "$HERE/zbs-move.sh" "$T/run/zbs-move.sh"
echo "-- the two old Codex trust entries"
ua="$T/d/goneA" ub="$T/d/goneB"; uc="$T/u.toml"; ubk="$T/state/codex-config.before-untrust-20261106"
mku() { printf 'model = "x"\n\n[projects."/keep1"]\ntrust_level = "trusted"\n\n[projects."%s"]\ntrust_level = "trusted"\n\n[projects."%s"]\ntrust_level = "trusted"\n\n[projects."/keep2"]\ntrust_level = "trusted"\n' "$ua" "$ub" > "$uc"; chmod 640 "$uc"; rm -f "$ubk"; }
upin() { sed -e "s#^UNTRUST=.*#UNTRUST=\"$ua $ub\"#" -e "s#^UNTRUST_FROM=.*#UNTRUST_FROM=$(/usr/bin/shasum -a 256 "$uc" | cut -d' ' -f1)#" "$HERE/reseat-lines.sh" | sed -e "s/^WANT=.*/WANT=$pl/" -e '/ zshenv-lines\.sh$/d' -e "s#^CLAUDE_NEW=.*#CLAUDE_NEW=$T/d/creator#" -e "s#^CLAUDE_OLD=.*#CLAUDE_OLD=$T/d/oldc#" -e "s#^CLAUDE_INODE=.*#CLAUDE_INODE=$(stat -f %i "$T/d/creator")#" -e "s#^CLAUDE_READY_MARK=.*#CLAUDE_READY_MARK=$T/ready#" > "$T/run/reseat-lines.sh"; repin; }
U() { ZEO_RESCUE_CODEX_CONFIG="$uc" L codex-untrust 2>&1; }
mku; upin; cp "$uc" "$T/u.before"; out=$(U); rc=$?
want='model = "x"

[projects."/keep1"]
trust_level = "trusted"

[projects."/keep2"]
trust_level = "trusted"'
[ $rc -eq 0 ] && echo "$out" | grep -q '^REMOVED: 2 entries are gone' && [ "$(cat "$uc")" = "$want" ] && ok "codex-untrust removes the two entries and nothing else" || bad "untrust: $rc $out $(cat "$uc")"
[ "$(stat -f %Lp "$uc")" = 640 ] && [ "$(stat -f %Lp "$ubk")" = 600 ] && cmp -s "$ubk" "$T/u.before" && [ ! -e "$uc.zeo" ] && ok "the file keeps its mode, the backup is the old file at 600, no copy is left" || bad "untrust files"
grep -q '^NOTHING TO REMOVE' <<< "$(U)" && ok "a second run changes nothing" || bad "untrust twice: $(U)"
mku; upin; echo '# later' >> "$uc"; cp "$uc" "$T/u.before"; out=$(U); rc=$?
[ $rc -eq 2 ] && echo "$out" | grep -q '^HASH MISMATCH, nothing was changed' && cmp -s "$uc" "$T/u.before" && [ ! -e "$ubk" ] && ok "any other file is refused" || bad "untrust hash: $rc $out"
mku; upin; mkdir -p "$ub"; out=$(U); rc=$?; rmdir "$ub"
[ $rc -eq 2 ] && echo "$out" | grep -q 'exists again' && ok "a folder that came back is refused" || bad "untrust folder: $rc $out"
mku; upin; mkdir -p "$T/bin5"; printf '#!/bin/bash\necho "/x/codex resume -a never -C %s --no-daemon id p"\n' "$ub" > "$T/bin5/ps"; chmod +x "$T/bin5/ps"; out=$(PATH="$T/bin5:$PATH" U); rc=$?
[ $rc -eq 2 ] && echo "$out" | grep -q 'a Codex process is in' && ok "a Codex process in an old folder is refused" || bad "untrust process: $rc $out"
mku; sed -i '' "/gone[A]/,+1d" "$uc"; upin; out=$(U); rc=$?
[ $rc -eq 2 ] && echo "$out" | grep -q 'only 1 of 2 entries' && ok "one entry alone is refused" || bad "untrust one: $rc $out"
mku; sed -i '' '/goneB/{n;s/"trusted"/"untrusted"/;}' "$uc"; upin; cp "$uc" "$T/u.before"; out=$(U); rc=$?
[ $rc -eq 2 ] && echo "$out" | grep -q 'not a plain trusted one' && cmp -s "$uc" "$T/u.before" && [ ! -e "$uc.zeo" ] && ok "an entry that is not plainly trusted is refused" || bad "untrust level: $rc $out"
mku; sed -i '' '/goneB/{n;a\
extra = 1
}' "$uc"; upin; cp "$uc" "$T/u.before"; out=$(U); rc=$?
[ $rc -eq 2 ] && echo "$out" | grep -q 'not exactly those entries' && cmp -s "$uc" "$T/u.before" && ok "an entry with more in it is refused" || bad "untrust extra: $rc $out"
mku; upin
perl -i -pe 's/^(\s+if \[ "\$\(sha "\$CODEX_CONFIG"\)" != "\$was" \]; then echo "REFUSED, nothing was changed: \$CODEX_CONFIG changed)/    echo "# a writer" >> "\$CODEX_CONFIG"\n$1/' "$T/run/reseat-lines.sh"
out=$(U); rc=$?
[ $rc -eq 2 ] && echo "$out" | grep -q 'changed during the edit' && grep -q '^# a writer$' "$uc" && grep -q 'goneA' "$uc" && [ ! -e "$ubk" ] && ok "a writer during the edit is refused, and its write stands" || bad "untrust writer: $rc $out"

echo; [ $fails -eq 0 ] && echo "PASS" || { echo "$fails FAILED"; exit 1; }
