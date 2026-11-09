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
    case "\$*" in *" -- sleep 3600") [ ! -f "$T/onstop" ] || bash "$T/onstop";; esac
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
case "\$1" in -Ewwp) cat "$T/psE.out";; -axo) if [ "\$2" = "pid=,ppid=" ] && [ -f "$T/pstree" ]; then cat "$T/pstree"; else cat "$T/ps.out"; fi;; *) cat "$T/ps.out";; esac
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

echo "-- a seat's own clone is carried to <repo>/main while it is stopped (a carry line in folder-moves)"
# git reports real paths, so this part works under the real path of the temp folder
K=$(cd "$T" && pwd -P)/k KS=88888888-8888-4888-8888-888888888888 KX=44444444-4444-4444-8444-444444444444
KF=$K/org/ka KT=$K/org/ka/main KW=$K/ext/ka-wt KB=$K/org/kb
kgit() { git -c user.email=t@t -c user.name=t -c init.defaultBranch=main "$@"; }
mkdir -p "$K/org" "$K/ext" "$K/other"; kgit init -q "$KF"; echo a > "$KF/a"; kgit -C "$KF" add a; kgit -C "$KF" commit -qm a
kgit -C "$KF" worktree add -q "$KW" -b side 2>/dev/null; kgit -C "$KF" worktree add -q "$K/ext/gone" -b gone 2>/dev/null; rm -rf "$K/ext/gone"; echo u > "$KF/untracked"
kgit init -q "$KB"; kgit -C "$KB" commit -q --allow-empty -m b
cp -Rp "$K" "$T/k.orig"; KHEAD=$(git -C "$KF" rev-parse HEAD)
KP=$T/projects/$(enc "$KF") KPN=$T/projects/$(enc "$KT")
printf '{"seats":[%s,%s,%s]}' "$(row ka ka claude h ka-s "$KF")" "$(row kx kx codex h kx-s "$KB")" "$(row kd kd claude h kd-s "$KB")" > "$T/kchart.json"
printf 'ka %s\nkx %s\nkd %s\n' "$KS" "$KX" "$KS" > "$T/kpins"
KR() { ZEO_RESCUE_PINS="$T/kpins" ZEO_RESCUE_MOVES="$T/kmoves" ZEO_RESCUE_CLAUDE_JSON="$T/kj.json" ZEO_RESCUE_CODEX_CONFIG="$T/kc.toml" "$HERE/rescue.sh" --host h --stagger 0 --chart "$T/kchart.json" "$@" 2>&1; }
kmove() { printf 'ka %s %s\n' "$1" "${2:-carry}" > "$T/kmoves"; }
ktrust() { printf '{"projects":{"%s":{"hasTrustDialogAccepted":true}}}' "$1" > "$T/kj.json"; }
kreset() { # the seat is up in its clone, idle, a child of it in a subfolder; on the stop its process goes, as a real stop does
  reset_live; rm -rf "$K" "$KP" "$KPN"; cp -Rp "$T/k.orig" "$K"; mkdir -p "$KP/memory"; echo m > "$KP/memory/MEMORY.md"; echo '{"permissionMode":"auto"}' > "$KP/$KS.jsonl"
  echo ka-s >> "$T/live"; echo 'ka-s|%5|9|1|claude' > "$T/panes"; echo "9 /x/claude --resume $KS" > "$T/ps.out"; printf '9 1\n501 9\n' > "$T/pstree"
  printf 'p9\nn%s\np501\nn%s/sub\np600\nn%s\n' "$KF" "$KF" "$K/org" > "$T/lsof.out"; kmove "$KT"; ktrust "$KT"; : > "$T/kc.toml"
  printf ': > "%s"; : > "%s"; rm -f "%s"\n' "$T/ps.out" "$T/lsof.out" "$T/onstop" > "$T/onstop"
  printf '{"cwd":"%s"}\n' "$KT" > "$T/claudeadd"; printf 'ZEO_TMUX_SEAT=master ZEO_TMUX_ACCOUNT=matorclawson ZMAIL_INSTANCE=ka GIT_ALLOW_PROTOCOL=ssh:https:file HOME=/x' > "$T/psE.out"
}
KP1() { KR --reseat --relaunch --seat ka; }
kreset
out=$(KP1); grep -q "^RESEAT ka: claude $KS " <<< "$out" && grep -qxF "MOVE ka: from $KF to $KT, carrying the clone while the seat is stopped" <<< "$out" && ok "a ready carry is planned, and says so" || bad "carry plan: $out"
[ ! -e "$T/launched" ] || [ ! -s "$T/launched" ] && [ ! -e "$KT" ] && ok "the plan moves nothing" || bad "plan moved"
grep -qxF "WRONG ka (claude): not yet carried to $KT; the carry is ready" <<< "$(KR --check --seat ka)" && ok "--check names a carry still to run" || bad "carry check: $(KR --check --seat ka)"
echo '{"projects":{}}' > "$T/kj.json"; grep -q "^UNRESOLVED ka: $KT has no trusted entry in" <<< "$(KP1)" && ok "a carry with no trust entry for the new folder is refused" || bad "carry trust: $(KP1)"
kreset; kmove "$KT" kerry; grep -q "^UNRESOLVED ka: its line in .* ends in 'kerry', and only carry is known" <<< "$(KP1)" && ok "an unknown third word is refused" || bad "kerry: $(KP1)"
kreset; mv "$KF/.git" "$KF/.git.x"; grep -q "^UNRESOLVED ka: $KF is not the top of a git clone" <<< "$(KP1)" && ok "a folder that is not a clone is not carried" || bad "not git: $(KP1)"; mv "$KF/.git.x" "$KF/.git"
kreset; printf 'ka %s\n' "$KS" > "$T/kpins2"; printf 'ka %s carry\n' "$KW/main" > "$T/kmoves"; printf '{"seats":[%s]}' "$(row ka ka claude h ka-s "$KW")" > "$T/kchart2.json"; ktrust "$KW/main"
grep -q "^UNRESOLVED ka: $KW is not an ordinary clone with its own .git" <<< "$(KR --reseat --relaunch --seat ka --chart "$T/kchart2.json")" && ok "a linked worktree is not carried" || bad "worktree carry: $(KR --reseat --relaunch --seat ka --chart "$T/kchart2.json")"
kreset; kmove "$KF/x/main"; ktrust "$KF/x/main"; grep -q "^UNRESOLVED ka: $KF/x/main is more than one level inside $KF" <<< "$(KP1)" && ok "only one level down" || bad "deep: $(KP1)"
kreset; kmove "$KB/sub/main"; ktrust "$KB/sub/main"; grep -q "^UNRESOLVED ka: $KB is in git, so $KB/sub/main would be inside a repository" <<< "$(KP1)" && ok "never into another repository" || bad "into repo: $(KP1)"
kreset; kmove "$K/none/a/main"; ktrust "$K/none/a/main"; grep -q "^UNRESOLVED ka: neither $K/none/a nor its parent is a folder" <<< "$(KP1)" && ok "at most one new folder is made" || bad "two levels: $(KP1)"
kreset; kmove /dev/zeo-rescue-test/main; ktrust /dev/zeo-rescue-test/main; grep -q "^UNRESOLVED ka: /dev/zeo-rescue-test/main is on another volume, so the move would be a copy" <<< "$(KP1)" && ok "never across volumes" || bad "volume: $(KP1)"
kreset; kgit -C "$KF" worktree add -q "$KF/inner" -b inner 2>/dev/null; grep -q "^UNRESOLVED ka: its linked worktree $KF/inner is inside it" <<< "$(KP1)" && ok "a worktree inside the clone is refused" || bad "inner: $(KP1)"
kreset; git -C "$KF" config zeo.path "$KF/x"; grep -q "^UNRESOLVED ka: its git config names its own path" <<< "$(KP1)" && ok "a git config that names its own path is refused" || bad "config: $(KP1)"
kreset; mkdir -p "$KPN"; grep -q "^UNRESOLVED ka: $KPN already exists, and two projects are not merged here" <<< "$(KP1)" && ok "a project under the new key is refused" || bad "new key: $(KP1)"
kreset; mkdir "$KT"; grep -q "^UNRESOLVED ka: $KT is there, but it is not a carried clone with its own .git" <<< "$(KP1)" && ok "a new path that is there but is not the clone is refused" || bad "there: $(KP1)"
kreset; printf 'p700\nn%s/sub\n' "$KF" >> "$T/lsof.out"; grep -q "^UNRESOLVED ka: pid 700 works in $KF and is not the seat's own" <<< "$(KP1)" && ok "another process working in the clone stops the plan" || bad "holder: $(KP1)"
kreset; : > "$T/live"; grep -q "^UNRESOLVED ka: it is down, and a carry moves only a seat this run stops itself" <<< "$(KR --seat ka)" && ok "a seat that is down is not carried" || bad "down: $(KR --seat ka)"
kreset; printf 'kx %s carry\n' "$KB/main" > "$T/kmoves"; echo kx-s >> "$T/live"; echo 'kx-s|%6|9|1|codex' > "$T/panes"; echo "9 /x/codex resume -a never -s danger-full-access -C $KB --no-daemon $KX" > "$T/ps.out"
grep -q "^UNRESOLVED kx: $KB/main has no trusted entry in $T/kc.toml" <<< "$(KR --reseat --relaunch --seat kx)" && ok "a Codex carry needs its trust entry too, though the folder is not there yet" || bad "codex trust: $(KR --reseat --relaunch --seat kx)"
printf '[projects."%s"]\ntrust_level = "trusted"\n' "$KB/main" > "$T/kc.toml"
out=$(KR --reseat --relaunch --seat kx); grep -q "^RESEAT kx: codex $KX" <<< "$out" && grep -qxF "MOVE kx: from $KB to $KB/main, carrying the clone while the seat is stopped" <<< "$out" && ok "and with it, the Codex carry is planned" || bad "codex carry: $out"
kreset; rm -f "$T/launched"; out=$(KR --reseat --relaunch --apply --seat ka); rc=$?
[ $rc -eq 0 ] && grep -qxF "CARRIED ka: $KF to $KT, the same folder (inode $(stat -f %i "$T/k.orig/org/ka" >/dev/null; sed -n 's/.*(inode \([0-9]*\)).*/\1/p' <<< "$out" | head -1)) at $KHEAD; 1 linked worktrees elsewhere repaired" <<< "$out" && grep -q "^MOVED OK ka: session $KS, one transcript, one process, in $KT" <<< "$out" && ok "the carry runs: the clone moves, its worktree is repaired, the move is proved" || bad "carry apply: $rc $out"
ki=$(sed -n 's/.*(inode \([0-9]*\)).*/\1/p' <<< "$out" | head -1)
[ -n "$ki" ] && [ "$(stat -f %i "$KT")" = "$ki" ] && [ "$(git -C "$KT" rev-parse HEAD)" = "$KHEAD" ] && [ -f "$KT/untracked" ] && [ "$(ls -A "$KF")" = main ] && [ "$(stat -f %Lp "$KF")" = 755 ] && ok "the same folder, HEAD and untracked file are at main, and the old path holds only main" || bad "carried: $(ls -A "$KF") $(stat -f %i "$KT") $ki"
[ "$(git -C "$KW" rev-parse --path-format=absolute --git-common-dir)" = "$KT/.git" ] && git -C "$KW" status --porcelain >/dev/null && [ "$(git -C "$KT" worktree list --porcelain | grep -c '^prunable')" = 1 ] && ok "the linked worktree reaches the clone at its new place; the prunable one is left as it was" || bad "repair: $(git -C "$KW" rev-parse --git-common-dir 2>&1)"
[ -f "$KPN/$KS.jsonl" ] && [ -f "$KPN/memory/MEMORY.md" ] && [ ! -e "$KP" ] && ok "its project went with it, memory too" || bad "carry project: $(ls "$T/projects")"
grep -qF -- "-c $K/org -- sleep 3600" "$T/launched" && grep -qF -- "-c $KT -- $HERE/seat-exec.sh ka claude" "$T/launched" && ok "it is stopped outside the clone and started in main" || bad "carry launch: $(cat "$T/launched")"
grep -q "^OK ka (claude)" <<< "$(KR --check --seat ka)" && ok "after the carry it checks right" || bad "carry check after: $(KR --check --seat ka)"
grep -q '^OK ka: started by rescue, right already' <<< "$(KR --reseat --relaunch --seat ka)" && ok "a second run leaves it alone" || bad "carry twice: $(KR --reseat --relaunch --seat ka)"
kreset; printf ': > "%s"; printf "p800\\nn%s\\n" > "%s"; rm -f "%s"\n' "$T/ps.out" "$KF" "$T/lsof.out" "$T/onstop" > "$T/onstop"; ki0=$(stat -f %i "$KF"); rm -f "$T/launched"; out=$(KR --reseat --relaunch --apply --seat ka); rc=$?
[ $rc -eq 1 ] && grep -q "^FAILED ka: pid 800 still works in $KF after the stop; nothing was moved; it was not started" <<< "$out" && [ "$(stat -f %i "$KF")" = "$ki0" ] && [ ! -e "$KT" ] && [ -f "$KP/$KS.jsonl" ] && ok "a process still in the clone after the stop: nothing moves" || bad "carry holder: $rc $out"
kreset; printf ': > "%s"; : > "%s"; mv "%s" "%s.x"; cp -Rp "%s.x" "%s"; rm -f "%s"\n' "$T/ps.out" "$T/lsof.out" "$KF" "$KF" "$KF" "$KF" "$T/onstop" > "$T/onstop"; out=$(KR --reseat --relaunch --apply --seat ka); rc=$?
[ $rc -eq 1 ] && grep -q "^FAILED ka: $KF is not the folder the plan read" <<< "$out" && [ ! -e "$KT" ] && ok "a folder swapped after the plan is not carried" || bad "carry swap: $rc $out"; rm -rf "$KF.x"
kreset; printf ': > "%s"; : > "%s"; mkdir "%s"; rm -f "%s"\n' "$T/ps.out" "$T/lsof.out" "$KF.carry-ka" "$T/onstop" > "$T/onstop"; out=$(KR --reseat --relaunch --apply --seat ka); rc=$?
[ $rc -eq 1 ] && grep -q "^FAILED ka: $KF.carry-ka is in the way; nothing was moved" <<< "$out" && [ ! -e "$KT" ] && [ -d "$KF/.git" ] && ok "a name in the way stops the carry before anything moves" || bad "carry tmp: $rc $out"; rm -rf "$KF.carry-ka"
kreset; printf ': > "%s"; : > "%s"; chmod 444 "%s/.git"; chmod 555 "%s"; rm -f "%s"\n' "$T/ps.out" "$T/lsof.out" "$KW" "$KW" "$T/onstop" > "$T/onstop"; out=$(KR --reseat --relaunch --apply --seat ka); rc=$?; chmod 755 "$KW"; chmod 644 "$KW/.git"
[ $rc -eq 1 ] && grep -qF "but these still do not reach it: $KW" <<< "$out" && grep -q "^MOVED OK ka" <<< "$out" && grep -q "^FAILED: ka: the seat runs in its carried clone, but a linked worktree of it does not reach it" <<< "$out" && ok "a worktree that cannot be repaired fails the run out loud, and the seat still runs" || bad "carry repair: $rc $out"
kreset; kmove "$K/other/ka/main"; ktrust "$K/other/ka/main"; KPO=$T/projects/$(enc "$K/other/ka/main"); rm -rf "$KPO"; printf '{"cwd":"%s"}\n' "$K/other/ka/main" > "$T/claudeadd"; out=$(KR --reseat --relaunch --apply --seat ka); rc=$?
[ $rc -eq 0 ] && [ ! -e "$KF" ] && [ -d "$K/other/ka/main/.git" ] && [ "$(git -C "$KW" rev-parse --path-format=absolute --git-common-dir)" = "$K/other/ka/main/.git" ] && [ -f "$KPO/$KS.jsonl" ] && ok "a clone carried into another folder leaves nothing at its old path" || bad "carry elsewhere: $rc $out"
rm -rf "$KPO" "$K/other/ka"
kreset; reset_live; rm -f "$T/onstop" "$T/pstree" "$T/claudeadd"; : > "$T/ps.out"; : > "$T/lsof.out"; : > "$T/panes"; printf '' > "$T/psE.out"

echo "-- a check reads all its input: under pipefail a reader that leaves early turns a match into a miss"
pad() { printf '%s\n' "$1"; head -c 1000000 /dev/zero | tr '\0' x; echo; }
hits=$(grep -nE '\| *(/usr/bin/)?grep +(-[a-zA-Z]+ +)*-[a-zA-Z]*q' "$HERE/rescue.sh" "$HERE/reseat-lines.sh" "$HERE/zshenv-lines.sh" "$HERE/structure-move.sh" "$HERE/structure-batch.sh")
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
fill() { for f in rescue.sh seat-exec.sh Makefile session-pins notes/reseat-20261105.txt notes/zeoarchitect-resume.txt notes/lic-test-20261106.txt notes/codex-relaunch-20261106.txt notes/claude-move-zbs-20261107.txt notes/zeocreator-memory-20261108.txt notes/claude-move-ducktyper-ops-20261108.txt zbs-move.sh ops-move.sh folder-moves zshenv-lines.sh structure-move.sh structure-moves notes/structure-move-claude.txt structure-batch.sh structure-batches; do cp "$HERE/$f" "$T/run/$f"; done; }
fill; sed "s/^WANT=.*/WANT=nobody@nowhere/" "$HERE/reseat-lines.sh" > "$T/run/reseat-lines.sh"; chmod +x "$T/run/reseat-lines.sh"
out=$(L verify 2>&1); rc=$?
[ $rc -eq 2 ] && echo "$out" | grep -q '^WRONG PLACE, nothing was run: you are ' && ok "the wrong place refuses in plain words" || bad "place: $rc $out"
sed "s/^WANT=.*/WANT=$pl/" "$HERE/reseat-lines.sh" > "$T/run/reseat-lines.sh"; chmod +x "$T/run/reseat-lines.sh"
L nonsense >/dev/null 2>&1; [ $? -eq 2 ] && ok "an unknown step runs nothing" || bad "step"
out=$(L verify 2>&1); [ $? -eq 0 ] && echo "$out" | grep -q '^verified:' && ok "the pins match the files in this checkout" || bad "pins are stale: $out"
for f in rescue.sh seat-exec.sh Makefile session-pins notes/reseat-20261105.txt notes/zeoarchitect-resume.txt notes/lic-test-20261106.txt notes/codex-relaunch-20261106.txt notes/claude-move-zbs-20261107.txt notes/zeocreator-memory-20261108.txt notes/claude-move-ducktyper-ops-20261108.txt zbs-move.sh ops-move.sh folder-moves zshenv-lines.sh structure-move.sh structure-moves notes/structure-move-claude.txt structure-batch.sh structure-batches; do
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
: > "$T/live"; mkdir -p "$T/d/creator"; sed -e "s/^WANT=.*/WANT=$pl/" -e '/ zshenv-lines\.sh$/d' -e "s#^CLAUDE_NEW=.*#CLAUDE_NEW=$T/d/creator#" -e "s#^CLAUDE_OLD=.*#CLAUDE_OLD=$T/d/oldc#" -e "s#^CLAUDE_READY_MARK=.*#CLAUDE_READY_MARK=$T/ready#" -e "s#^CLAUDE_FIRST_DONE=.*#CLAUDE_FIRST_DONE=$T/first.done#" "$HERE/reseat-lines.sh" > "$T/run/reseat-lines.sh"; chmod +x "$T/run/reseat-lines.sh"
echo "# none" > "$T/run/folder-moves"; repin
grep -q '^NOT READY, nothing was run: folder-moves needs ducktyper-ops' <<< "$(L claude-first 2>&1)" && ok "claude-first refuses until the Architect names the folder" || bad "claude ready: $(L claude-first 2>&1)"
echo "ducktyper-ops $T/d/creator" > "$T/run/folder-moves"; repin
printf '{"projects":{}}' > "$T/cj0.json"; out=$(ZEO_RESCUE_CLAUDE_JSON="$T/cj0.json" L claude-trust 2>&1); rc=$?
[ $rc -eq 2 ] && echo "$out" | grep -q '^OUT OF ORDER, nothing was run: the folder step has not finished' && [ "$(cat "$T/cj0.json")" = '{"projects":{}}' ] && ok "claude-trust waits for the folder step" || bad "ready mark: $rc $out"
grep -q '^OUT OF ORDER, nothing was run: the folder step' <<< "$(L claude-first 2>&1)" && ok "so does claude-first" || bad "ready mark first: $(L claude-first 2>&1)"
echo inode=1 > "$T/ready"; out=$(ZEO_RESCUE_CLAUDE_JSON="$T/cj0.json" L claude-trust 2>&1); rc=$?
[ $rc -eq 2 ] && echo "$out" | grep -q "^NOT READY, nothing was run: $T/d/creator is not the folder the folder step made (inode 1)" && [ "$(cat "$T/cj0.json")" = '{"projects":{}}' ] && ok "a folder at the new path that the folder step did not make is never trusted" || bad "inode: $rc $out"
grep -q "^NOT READY, nothing was run: .* is not the folder the folder step made" <<< "$(L claude-first 2>&1)" && ok "or started in" || bad "inode first: $(L claude-first 2>&1)"
: > "$T/ready"; grep -q "^NOT READY, nothing was run: .* is not the folder the folder step made (inode unknown)" <<< "$(L claude-first 2>&1)" && ok "and a mark that names no folder is no mark" || bad "inode none: $(L claude-first 2>&1)"
echo "inode=$(stat -f %i "$T/d/creator")" > "$T/ready"
printf '{"keep":1,"projects":{"/a":{"hasTrustDialogAccepted":true}}}' > "$T/cj.json"; chmod 640 "$T/cj.json"
out=$(ZEO_RESCUE_CLAUDE_JSON="$T/cj.json" L claude-trust 2>&1); rc=$?
[ $rc -eq 0 ] && echo "$out" | grep -q '^ADDED' && [ "$(jq -r --arg d "$T/d/creator" '.projects[$d].hasTrustDialogAccepted' "$T/cj.json")" = true ] && [ "$(jq -r '.keep,.projects["/a"].hasTrustDialogAccepted' "$T/cj.json" | tr '\n' ' ')" = "1 true " ] && ok "claude-trust adds one entry and keeps the rest" || bad "claude trust: $rc $out"
[ "$(stat -f %Lp "$T/cj.json")" = 640 ] && [ ! -e "$T/cj.json.lock" ] && ok "with the file's mode, and lets go of the lock" || bad "mode or lock"
B="$T/state/claude-json.before-ducktyper-ops"; [ "$(stat -f %Lp "$B")" = 600 ] && [ "$(jq -c . "$B")" = '{"keep":1,"projects":{"/a":{"hasTrustDialogAccepted":true}}}' ] && ok "the backup is the old file, mode 600, though the file is 640" || bad "backup: $(stat -f %Lp "$B")"
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
rv=$(awk -F= '/^CLAUDE_REHEARSED=/ {print $2}' "$T/run/reseat-lines.sh")
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
# claude-first on a stub rescue.sh: --apply renames the project to the new folder's key, as rescue.sh does, and writes the note's words if $T/cf/deliver exists.
rm -rf "$T/cf"; mkdir -p "$T/cf/proj"; for f in rescue.sh session-pins; do cp "$T/run/$f" "$T/cf/$f.keep"; done
csid=ca076ba8-7fee-46f0-853b-8182adc3c975; cko=$T/cf/proj/$(enc2 "$T/d/oldc"); ckn=$T/cf/proj/$(enc2 "$T/d/creator"); cw=$(awk -F'"' '/^CLAUDE_PROOF=/ {print $2}' "$T/run/reseat-lines.sh")
echo "ducktyper-ops $csid" > "$T/run/session-pins"
cat > "$T/run/rescue.sh" <<S
#!/bin/bash
echo "\$*" >> "$T/cf/calls"
case " \$* " in
  *" --check "*) echo "OK ducktyper-ops (claude)"; echo "check: ok 1, wrong 0";;
  *" --apply "*) [ ! -f "$T/cf/fail" ] || { echo "STOPPED: stub"; exit 1; }; [ ! -d "$cko" ] || mv "$cko" "$ckn"; echo "MOVED OK ducktyper-ops: stub"; [ ! -f "$T/cf/deliver" ] || printf '{"type":"user","message":{"content":"Correction. %s"}}\n' "$cw" >> "$ckn/$csid.jsonl";;
  *) cat "$T/cf/plan";;
esac
S
chmod +x "$T/run/rescue.sh"; pinf rescue.sh session-pins; rm -f "$T/first.done"
CF() { ZEO_RESCUE_PROJECTS="$T/cf/proj" ZEO_RESCUE_CLAUDE="$T/bin/claudev" ZEO_RESCUE_PROOF_TRIES=2 L claude-first 2>&1; }
[ -n "$cw" ] && grep -qF "$cw" "$HERE/notes/claude-move-ducktyper-ops-20261108.txt" && ok "claude-first's proof words are in the seat's note" || bad "cf words: $cw"
out=$(CF); rc=$?; [ $rc -eq 2 ] && echo "$out" | grep -q '^NOT READY, nothing was run: no transcript for ducktyper-ops under either folder' && [ ! -e "$T/cf/calls" ] && ok "claude-first needs the seat's transcript" || bad "cf transcript: $rc $out"
mkdir -p "$cko"; echo '{"type":"user","message":{"content":"before"}}' > "$cko/$csid.jsonl"; cp "$cko/$csid.jsonl" "$T/cf/tr.keep"
printf '{"type":"user","message":{"content":"%s"}}\n' "$cw" >> "$cko/$csid.jsonl"; out=$(CF); rc=$?; cp "$T/cf/tr.keep" "$cko/$csid.jsonl"
[ $rc -eq 2 ] && echo "$out" | grep -q "^REFUSED, nothing was run: the note's words are already in" && [ ! -e "$T/cf/calls" ] && ok "it refuses when the note's words are already there" || bad "cf words before: $rc $out"
printf 'RESEAT ducktyper-ops: claude %s\nWORK ducktyper-ops: a turn is in progress on its screen\n' "$csid" > "$T/cf/plan"; out=$(CF); rc=$?
[ $rc -eq 2 ] && echo "$out" | grep -q '^BUSY, nothing was run' && ! grep -q -- '--apply' "$T/cf/calls" && ok "it refuses while the seat is working" || bad "cf busy: $rc $out"
printf 'RESEAT ducktyper-ops: claude %s\n' "$csid" > "$T/cf/plan"; : > "$T/cf/fail"; out=$(CF); rc=$?; rm -f "$T/cf/fail"
[ $rc -eq 1 ] && echo "$out" | grep -q '^STOPPED: the move or its check failed' && ! echo "$out" | grep -q '^NOT DELIVERED' && [ ! -e "$T/first.done" ] && ok "a move that fails stops there, says so and marks nothing" || bad "cf stopped: $rc $out"
printf 'RESEAT ducktyper-ops: claude %s\n' "$csid" > "$T/cf/plan"; out=$(CF); rc=$?
[ $rc -eq 1 ] && echo "$out" | grep -q '^NOT DELIVERED: ' && [ ! -e "$T/first.done" ] && ok "a move whose transcript never shows the note says NOT DELIVERED and marks nothing" || bad "cf undelivered: $rc $out"
: > "$T/cf/calls"; : > "$T/cf/deliver"; out=$(CF); rc=$?
[ $rc -eq 0 ] && echo "$out" | grep -q "^the Claude that will run: $rv; rehearsed on $rv" && echo "$out" | grep -qx "claude $rv" && echo "$out" | grep -q "^NOTE DELIVERED ducktyper-ops: its words are in session $csid under $T/d/creator" && [ -s "$T/first.done" ] && ok "a run stopped after the rename runs again from the new folder's transcript, proves the note and marks itself done" || bad "cf deliver: $rc $out"
grep -q -- '--reseat --apply --relaunch --harness claude --seat ducktyper-ops --note-file notes/claude-move-ducktyper-ops-20261108.txt' "$T/cf/calls" && ok "the move carries the seat's note" || bad "cf apply args: $(cat "$T/cf/calls")"
: > "$T/cf/calls"; out=$(CF); rc=$?; [ $rc -eq 0 ] && echo "$out" | grep -q '^ALREADY DONE: ducktyper-ops moved' && [ ! -s "$T/cf/calls" ] && ok "a second claude-first restarts nothing" || bad "cf twice: $rc $out"
for f in rescue.sh session-pins; do cp "$T/cf/$f.keep" "$T/run/$f"; done; pinf rescue.sh session-pins; rm -f "$T/first.done"
# structure-move.sh, through the runner, on a stub rescue.sh: --apply carries the folder and renames the project as rescue.sh does, and writes the note's words if $T/sm/deliver exists.
rm -rf "$T/sm"; mkdir -p "$T/sm/proj" "$T/sm/w/org"; cp "$T/run/rescue.sh" "$T/sm/rescue.sh.keep"
SMF=$T/sm/w/org/sa SMT=$T/sm/w/org/sa/main ssid=12121212-1212-4212-8212-121212121212; mkdir -p "$SMF"; echo x > "$SMF/f"
smo=$T/sm/proj/$(enc2 "$SMF"); smn=$T/sm/proj/$(enc2 "$SMT"); sw=$(awk -F'"' '/^PROOF=/ {print $2}' "$HERE/structure-move.sh")
smrow() { printf '%s claude sa-s %s %s %s %s\n' "${1:-sa}" "$ssid" "$SMF" "$SMT" "${2:-$(stat -f %i "$SMF")}" > "$T/sm/table"; }
smrow; echo "sa $SMT carry" > "$T/sm/moves"; echo "sa $ssid" > "$T/sm/pins"; echo '{"projects":{}}' > "$T/sm/cj.json"
cat > "$T/run/rescue.sh" <<S
#!/bin/bash
echo "\$*" >> "$T/sm/calls"
case " \$* " in
  *" --check "*) if [ -f "$T/sm/wrong" ]; then echo "WRONG sa (claude): stub"; exit 1; fi; echo "OK sa (claude)"; echo "check: ok 1, wrong 0";;
  *" --apply "*) [ ! -f "$T/sm/fail" ] || { echo "STOPPED: stub"; exit 1; }
    if [ ! -e "$SMT" ]; then mv "$SMF" "$SMF.c" && mkdir "$SMF" && mv "$SMF.c" "$SMT"; fi; [ ! -d "$smo" ] || mv "$smo" "$smn"; echo "MOVED OK sa: stub"
    [ ! -f "$T/sm/deliver" ] || printf '{"type":"user","message":{"content":"Correction. %s"}}\n' "$sw" >> "$smn/$ssid.jsonl";;
  *) cat "$T/sm/plan";;
esac
S
chmod +x "$T/run/rescue.sh"; pinf rescue.sh; rm -f "$T/sm/calls"
SM() { ZEO_RESCUE_USER_SETTINGS="$T/sm/user.json" ZEO_RESCUE_TABLE="$T/sm/table" ZEO_RESCUE_MOVES="$T/sm/moves" ZEO_RESCUE_PINS="$T/sm/pins" ZEO_RESCUE_PROJECTS="$T/sm/proj" ZEO_RESCUE_CLAUDE_JSON="$T/sm/cj.json" ZEO_RESCUE_CLAUDE="$T/bin/claudev" ZEO_RESCUE_PROOF_TRIES=2 L "$@" 2>&1; }
smplan() { printf 'RESEAT sa: claude %s (--permission-mode auto; marker master, no record, default) in sa-s\nMOVE sa: from %s to %s, carrying the clone while the seat is stopped\n' "$ssid" "$SMF" "$SMT" > "$T/sm/plan"; }
smplan; echo "$rv (Claude Code)" > "$T/ver"
out=$(SM structure-first); rc=$?; [ $rc -eq 2 ] && grep -q '^usage: reseat-lines.sh structure-first SEAT; nothing was run' <<< "$out" && ok "a structure step needs its seat" || bad "sm usage: $rc $out"
out=$(SM structure-first 'sa;x'); rc=$?; [ $rc -eq 2 ] && grep -q '^usage: reseat-lines.sh structure-first SEAT' <<< "$out" && ok "and a seat id that is only a seat id" || bad "sm bad seat: $rc $out"
grep -q '^REFUSED, nothing was changed: nobody needs exactly one row in structure-moves' <<< "$(SM structure-first nobody)" && ok "a seat with no row runs nothing" || bad "sm no row: $(SM structure-first nobody)"
echo "sa $SMT" > "$T/sm/moves"; grep -q '^REFUSED, nothing was changed: folder-moves needs exactly one line: sa .* carry' <<< "$(SM structure-first sa)" && ok "the move must be a carry line in folder-moves" || bad "sm moves: $(SM structure-first sa)"
printf 'sa %s carry\nsa %s carry\n' "$SMT" "$SMT" > "$T/sm/moves"; grep -q '^REFUSED, nothing was changed: folder-moves needs exactly one line' <<< "$(SM structure-first sa)" && ok "and only one" || bad "sm two moves"
echo "sa $SMT carry" > "$T/sm/moves"; echo "sa 34343434-3434-4434-8434-343434343434" > "$T/sm/pins"; grep -q '^REFUSED, nothing was changed: session-pins needs sa' <<< "$(SM structure-first sa)" && ok "its thread must be pinned, the same one" || bad "sm pin"
echo "sa $ssid" > "$T/sm/pins"; sed -i '' 's/ claude / codex /' "$T/sm/table"; grep -q '^REFUSED, nothing was changed: sa is a codex seat, and only a Claude carry is rehearsed' <<< "$(SM structure-first sa)" && ok "a Codex seat is refused until its own rehearsal" || bad "sm codex"
smrow sa 1; grep -q '^REFUSED, nothing was changed: neither .* nor .* is the folder read for sa (inode 1): an unknown state' <<< "$(SM structure-trust sa)" && ok "any state but the two it knows is refused, by every step" || bad "sm state: $(SM structure-trust sa)"
smrow; printf 'sa claude sa-s %s %s %s %s extra\n' "$ssid" "$SMF" "$SMT" "$(stat -f %i "$SMF")" > "$T/sm/table"; grep -q '^REFUSED, nothing was changed: the row for sa in structure-moves is not' <<< "$(SM structure-first sa)" && ok "a row of the wrong shape is refused" || bad "sm shape"
smrow
# the seat's guards: each ask or deny rule on the old folder is added again for the new one; nothing else changes
smsl=$SMF/.claude/settings.local.json smgb=$T/state/settings-local.before-sa; mkdir -p "$SMF/.claude"
jq -n --arg f "$SMF" --arg t "$SMT" '{env: {X: "1"}, permissions: {allow: ["Edit(/\($f)/**)"], ask: ["Edit(/\($f)/.github/**)", "Read(\($f)/a)", "Bash(ls)", "Edit(/\($f)-wt/**)", "Edit(/\($t)/b)"], deny: ["Write(/\($f)/.git/**)"]}}' > "$smsl"; chmod 640 "$smsl"; cp "$smsl" "$T/sm/sl.keep"
jq -n --arg f "$SMF" '{permissions: {deny: ["Write(/\($f)/x)"]}}' > "$SMF/.claude/settings.json"; out=$(SM structure-trust sa); rc=$?; rm -f "$SMF/.claude/settings.json"
[ $rc -eq 2 ] && grep -q "^REFUSED, nothing was changed: $SMF/.claude/settings.json has an allow, ask or deny rule on $SMF/" <<< "$out" && [ "$(jq -r --arg d "$SMT" '.projects[$d] // "none"' "$T/sm/cj.json")" = none ] && cmp -s "$smsl" "$T/sm/sl.keep" && ok "a guard on the old folder in the tracked settings is refused before anything is written" || bad "sm guard tracked: $rc $out"
jq -n --arg f "$SMF" '{permissions: {ask: ["Edit(//\($f)/y)"]}}' > "$T/sm/user.json"; out=$(SM structure-trust sa); rc=$?; rm -f "$T/sm/user.json"
[ $rc -eq 2 ] && grep -q "^REFUSED, nothing was changed: $T/sm/user.json has an allow, ask or deny rule on $SMF/" <<< "$out" && [ "$(jq -r --arg d "$SMT" '.projects[$d] // "none"' "$T/sm/cj.json")" = none ] && ok "and so is one in the shared user settings" || bad "sm guard user: $rc $out"
jq -n --arg f "$SMF" '{permissions: {allow: ["Read(//\($f)/z)"]}}' > "$T/sm/user.json"; out=$(SM structure-trust sa); rc=$?; rm -f "$T/sm/user.json"
[ $rc -eq 2 ] && grep -q "^REFUSED, nothing was changed: $T/sm/user.json has an allow, ask or deny rule on $SMF/" <<< "$out" && ok "an allow rule there too, which a carry could not give the new folder" || bad "sm guard user allow: $rc $out"
mv "$smsl" "$T/sm/sl.real"; ln -s "$T/sm/sl.real" "$smsl"; out=$(SM structure-trust sa); rc=$?; rm -f "$smsl"; mv "$T/sm/sl.real" "$smsl"
[ $rc -eq 2 ] && grep -q "^REFUSED, nothing was changed: $smsl is a link" <<< "$out" && ok "a settings.local.json that is a link is not changed" || bad "sm guard link: $rc $out"
echo '[1]' > "$smsl"; out=$(SM structure-trust sa); rc=$?; cp "$T/sm/sl.keep" "$smsl"
[ $rc -eq 2 ] && grep -q "^REFUSED, nothing was changed: $smsl is not a JSON object" <<< "$out" && ok "nor one that is not a JSON object" || bad "sm guard json: $rc $out"
out=$(SM structure-trust sa); rc=$?
[ $rc -eq 0 ] && grep -q "^ADDED: $SMT is trusted, before the folder is there" <<< "$out" && [ "$(jq -r --arg d "$SMT" '.projects[$d].hasTrustDialogAccepted' "$T/sm/cj.json")" = true ] && [ "$(stat -f %Lp "$T/state/claude-json.before-sa")" = 600 ] && ok "structure-trust trusts the new folder before it exists, with a backup of mode 600" || bad "sm trust: $rc $out"
want=$(jq -n --arg f "$SMF" --arg t "$SMT" '{env: {X: "1"}, permissions: {allow: ["Edit(/\($f)/**)", "Edit(/\($t)/**)"], ask: ["Edit(/\($f)/.github/**)", "Read(\($f)/a)", "Bash(ls)", "Edit(/\($f)-wt/**)", "Edit(/\($t)/b)", "Edit(/\($t)/.github/**)", "Read(\($t)/a)"], deny: ["Write(/\($f)/.git/**)", "Write(/\($t)/.git/**)"]}}')
grep -q "^GUARDS ADDED: 4 allow, ask or deny rules on $SMF/ now stand for $SMT/ too, in $smsl; backup at $smgb, mode 600" <<< "$out" && [ "$(jq -S . "$smsl")" = "$(jq -S . <<< "$want")" ] && [ "$(jq -c '.permissions.ask' "$smsl")" = "$(jq -c '.permissions.ask' <<< "$want")" ] && ok "and adds each allow, ask or deny rule on the old folder for the new one, in order, after the old ones; a sibling folder and rules already on the new one are left" || bad "sm guards: $out $(cat "$smsl")"
[ "$(stat -f %Lp "$smsl")" = 640 ] && [ "$(stat -f %Lp "$smgb")" = 600 ] && cmp -s "$smgb" "$T/sm/sl.keep" && [ ! -e "$smsl.zeo" ] && ok "the file keeps its mode, its backup is the old bytes at mode 600, and no copy is left" || bad "sm guard modes"
out=$(SM structure-trust sa); grep -q '^NOTHING TO ADD' <<< "$out" && grep -q "^GUARDS: none to add" <<< "$out" && [ "$(jq -S . "$smsl")" = "$(jq -S . <<< "$want")" ] && ok "a second trust run changes nothing" || bad "sm trust twice: $out"
# a writer during the carry: its write stands, and nothing is added
cp "$T/sm/sl.keep" "$smsl"; rm -f "$smgb"; mkdir -p "$T/smbin"
printf '#!/bin/bash\n"%s" "$@"; rc=$?\ncase "$*" in *"reduce ("*) case "$*" in *--slurpfile*) ;; *) echo " " >> "%s";; esac;; esac\nexit $rc\n' "$realjq" "$smsl" > "$T/smbin/jq"; chmod +x "$T/smbin/jq"
out=$(PATH="$T/smbin:$PATH" SM structure-trust sa); rc=$?
[ $rc -eq 2 ] && grep -q "^REFUSED, the guards were not added: $smsl changed while they were carried" <<< "$out" && [ "$(tail -c 2 "$smsl")" = " " ] && [ "$(jq -c '.permissions.ask' "$smsl")" = "$(jq -c '.permissions.ask' "$T/sm/sl.keep")" ] && [ ! -e "$smgb" ] && [ ! -e "$smsl.zeo" ] && ok "a write to the settings while the guards are carried is refused, its write stands, and no backup or copy is left" || bad "sm guard race: $rc $out"
cp "$T/sm/sl.keep" "$smsl"
printf '#!/bin/bash\ncase "$*" in *"reduce ("*) case "$*" in *--slurpfile*) ;; *) "%s" "$@" | "%s" ".permissions.allow = [] | .permissions.ask += [\\"Bash(x)\\"]"; exit;; esac;; esac\nexec "%s" "$@"\n' "$realjq" "$realjq" "$realjq" > "$T/smbin/jq"; chmod +x "$T/smbin/jq"
out=$(PATH="$T/smbin:$PATH" SM structure-trust sa); rc=$?
[ $rc -eq 1 ] && grep -q "^FAILED, the guards were not added: the carried file is not the old one with rules only added" <<< "$out" && cmp -s "$smsl" "$T/sm/sl.keep" && [ ! -e "$smgb" ] && [ ! -e "$smsl.zeo" ] && ok "a carried file that drops a rule or adds one not carried is refused, and the old file stands" || bad "sm guard verify: $rc $out"
printf 'older\n' > "$smgb"; chmod 644 "$smgb"; out=$(SM structure-trust sa)
grep -q "^GUARDS ADDED: 4 " <<< "$out" && [ "$(stat -f %Lp "$smgb")" = 600 ] && [ "$(cat "$smgb")" = older ] && ok "an earlier backup is kept, not overwritten, and made mode 600" || bad "sm guard re-add: $out $(stat -f %Lp "$smgb")"
echo "2.1.999 (Claude Code)" > "$T/ver"; out=$(SM structure-first sa); rc=$?; echo "$rv (Claude Code)" > "$T/ver"
[ $rc -eq 2 ] && grep -q "^REFUSED, nothing was changed: Claude is 2.1.999 and the rehearsal ran on $rv" <<< "$out" && [ ! -e "$T/sm/calls" ] && ok "structure-first refuses a Claude nobody rehearsed" || bad "sm version: $rc $out"
out=$(SM structure-first sa); rc=$?; [ $rc -eq 2 ] && grep -q '^NOT READY, nothing was run: no transcript for sa' <<< "$out" && ok "it needs the seat's transcript" || bad "sm transcript: $rc $out"
mkdir -p "$smo/memory"; echo '{"type":"user","message":{"content":"before"}}' > "$smo/$ssid.jsonl"; cp "$smo/$ssid.jsonl" "$T/sm/tr.keep"
printf '{"type":"user","message":{"content":"%s"}}\n' "$sw" >> "$smo/$ssid.jsonl"; out=$(SM structure-first sa); rc=$?; cp "$T/sm/tr.keep" "$smo/$ssid.jsonl"
[ $rc -eq 2 ] && grep -q "^REFUSED, nothing was changed: the note's words are already in" <<< "$out" && ok "it refuses when the note's words are already there" || bad "sm words: $rc $out"
printf 'WORK sa: a turn is in progress on its screen\n' >> "$T/sm/plan"; out=$(SM structure-first sa); rc=$?; smplan
[ $rc -eq 2 ] && grep -q '^BUSY, nothing was run' <<< "$out" && ! grep -q -- '--apply' "$T/sm/calls" && ok "it refuses while the seat is working" || bad "sm busy: $rc $out"
printf 'UNRESOLVED sa: it is down, and a carry moves only a seat this run stops itself\n' > "$T/sm/plan"; out=$(SM structure-first sa); rc=$?; smplan
[ $rc -eq 2 ] && grep -q '^DOWN, nothing was run: sa is not running' <<< "$out" && ! grep -q -- '--apply' "$T/sm/calls" && ok "it says DOWN for a seat that is not running, and runs nothing" || bad "sm down: $rc $out"
printf 'UNRESOLVED sa: stub\n' > "$T/sm/plan"; out=$(SM structure-first sa); rc=$?; smplan
[ $rc -eq 2 ] && grep -q "^REFUSED, nothing was run: the plan does not move sa from $SMF to $SMT" <<< "$out" && ! grep -q -- '--apply' "$T/sm/calls" && ok "it refuses a plan that does not move this seat from its row's folder" || bad "sm plan: $rc $out"
sed -i '' 's/ in sa-s$/ in other-s/' "$T/sm/plan"; out=$(SM structure-first sa); rc=$?; smplan
[ $rc -eq 2 ] && grep -q '^REFUSED, nothing was run: the plan does not move' <<< "$out" && ok "or one in another tmux session" || bad "sm sess: $rc $out"
cp "$T/run/notes/structure-move-claude.txt" "$T/sm/tpl.keep"; echo "{NOPE}" >> "$T/run/notes/structure-move-claude.txt"; pinf notes/structure-move-claude.txt; : > "$T/sm/calls"; out=$(SM structure-first sa); rc=$?; cp "$T/sm/tpl.keep" "$T/run/notes/structure-move-claude.txt"; pinf notes/structure-move-claude.txt
[ $rc -eq 1 ] && grep -q "^FAILED, nothing was run: the note did not render" <<< "$out" && ! grep -q -- "--apply" "$T/sm/calls" && ok "a note with a placeholder left in it runs nothing" || bad "sm placeholder: $rc $out"
# the seat's own addition to its note, pinned by its hash in the row
sma=$T/run/notes/structure-move-sa.txt; smrowa() { printf 'sa claude sa-s %s %s %s %s %s\n' "$ssid" "$SMF" "$SMT" "$(stat -f %i "$SMF")" "$1" > "$T/sm/table"; }
echo "Rebuild your .venv with uv sync --frozen." > "$sma"; smah=$(/usr/bin/shasum -a 256 "$sma" | cut -d " " -f 1)
out=$(SM structure-trust sa); rc=$?; [ $rc -eq 2 ] && grep -q '^REFUSED, nothing was changed: notes/structure-move-sa.txt is there, but its row pins no addition' <<< "$out" && ok "an addition its row does not pin is refused" || bad "sm add unpinned: $rc $out"
smrowa "$(printf %064d 0)"; out=$(SM structure-trust sa); rc=$?; [ $rc -eq 2 ] && grep -q '^REFUSED, nothing was changed: notes/structure-move-sa.txt is not the addition its row pins' <<< "$out" && ok "an addition with another hash is refused" || bad "sm add hash: $rc $out"
smrowa "${smah}x"; grep -q '^REFUSED, nothing was changed: the row for sa in structure-moves is not' <<< "$(SM structure-trust sa)" && ok "a row's addition hash must be a sha256" || bad "sm add shape"
f=0; for bodyd in 'Use {TO} here.' 'Use C:\venv here.' "$(printf 'one\ntwo')"; do printf '%s\n' "$bodyd" > "$sma"; smrowa "$(/usr/bin/shasum -a 256 "$sma" | cut -d " " -f 1)"; out=$(SM structure-trust sa); rc=$?
  [ $rc -eq 2 ] && grep -q '^REFUSED, nothing was changed: notes/structure-move-sa.txt must be one line, with no brace or backslash' <<< "$out" || { f=1; bad "sm add body: $bodyd: $rc $out"; }; done; [ $f = 0 ] && ok "an addition of two lines, or with a brace or a backslash, is refused"
rm -f "$sma"; smrowa "$smah"; out=$(SM structure-trust sa); rc=$?; [ $rc -eq 2 ] && grep -q '^REFUSED, nothing was changed: notes/structure-move-sa.txt is not the addition its row pins' <<< "$out" && ok "a pinned addition that is missing is refused" || bad "sm add missing: $rc $out"
echo "Rebuild your .venv with uv sync --frozen." > "$sma"; : > "$T/sm/fail"; : > "$T/sm/calls"; out=$(SM structure-first sa); rc=$?; rm -f "$T/sm/fail"
[ $rc -eq 1 ] && grep -q "^the note, from structure-move-claude.txt and structure-move-sa.txt: " <<< "$out" && [ "$(wc -l < "$T/state/structure-move-sa/note.txt" | tr -d ' ')" = 1 ] && grep -qF "$sw" "$T/state/structure-move-sa/note.txt" && grep -qF "then continue. Rebuild your .venv with uv sync --frozen." "$T/state/structure-move-sa/note.txt" && ok "the pinned addition ends the note, on its one line" || bad "sm add note: $rc $out $(cat "$T/state/structure-move-sa/note.txt")"
rm -f "$sma"; smrow
: > "$T/sm/fail"; out=$(SM structure-first sa); rc=$?; rm -f "$T/sm/fail"
[ $rc -eq 1 ] && grep -q '^STOPPED: the move or its check failed' <<< "$out" && [ ! -e "$T/state/structure-move-sa/first.done" ] && ok "a move that fails stops there and marks nothing" || bad "sm stopped: $rc $out"
[ "$(/usr/bin/shasum -a 256 < "$T/state/structure-move-sa/note.txt" | cut -d " " -f 1)" = "$(sed -e "s#{FROM}#$SMF#g" -e "s#{TO}#$SMT#g" -e "s#{OLDMEM}#$T/sm/proj/$(enc2 "$SMF")/memory/#g" -e "s#{NEWMEM}#$T/sm/proj/$(enc2 "$SMT")/memory/#g" "$T/run/notes/structure-move-claude.txt" | /usr/bin/shasum -a 256 | cut -d " " -f 1)" ] && ok "with no addition the note is the template's own bytes, as on the first seat" || bad "sm note bytes"
note=$T/state/structure-move-sa/note.txt
grep -qF "from $SMF to $SMT." "$note" && grep -qF "$T/sm/proj/$(enc2 "$SMT")/memory/:" "$note" && grep -qF "$T/sm/proj/$(enc2 "$SMF")/memory/, no longer exists" "$note" && grep -qF "$sw" "$note" && ! grep -q '[{}`*]' "$note" && [ "$(stat -f %Lp "$T/state/structure-move-sa")" = 700 ] && ok "the note names both folders and both memory folders, carries the proof, and keeps no placeholder" || bad "sm note: $(cat "$note")"
mv "$SMT" "$SMF.back"; rmdir "$SMF"; mv "$SMF.back" "$SMF"; [ ! -d "$smn" ] || mv "$smn" "$smo"
out=$(SM structure-first sa); rc=$?
[ $rc -eq 1 ] && grep -q '^NOT DELIVERED: ' <<< "$out" && [ ! -e "$T/state/structure-move-sa/first.done" ] && ok "a transcript that never shows the note says NOT DELIVERED and marks nothing" || bad "sm undelivered: $rc $out"
grep -qF "MOVE sa: from $SMF to $SMT" <<< "$(cat "$T/sm/plan")" && : > "$T/sm/calls"; : > "$T/sm/deliver"; sed -i '' 's/, carrying the clone while the seat is stopped$//' "$T/sm/plan"
out=$(SM structure-first sa); rc=$?
[ $rc -eq 0 ] && grep -q "^NOTE DELIVERED sa: its words are in session $ssid under $SMT" <<< "$out" && [ -s "$T/state/structure-move-sa/first.done" ] && ok "after a carry whose start failed, a rerun starts it in the new folder, proves the note and marks itself done" || bad "sm deliver: $rc $out"
grep -qF -- "--reseat --apply --relaunch --harness claude --seat sa --note-file $note" "$T/sm/calls" && ok "the move carries the rendered note" || bad "sm args: $(cat "$T/sm/calls")"
: > "$T/sm/calls"; out=$(SM structure-first sa); rc=$?; [ $rc -eq 0 ] && grep -q '^ALREADY DONE: sa moved' <<< "$out" && [ ! -s "$T/sm/calls" ] && ok "a second structure-first restarts nothing" || bad "sm twice: $rc $out"
out=$(SM structure-trust sa); rc=$?; [ $rc -eq 0 ] && grep -q '^NOTHING TO ADD' <<< "$out" && grep -q '^GUARDS: none to add' <<< "$out" && [ -f "$SMT/.claude/settings.local.json" ] && [ ! -e "$smsl" ] && ok "after the move, trust reads the guards in the new folder and adds nothing" || bad "sm guard after: $rc $out"
: > "$T/sm/wrong"; out=$(SM structure-clear sa); rc=$?; rm -f "$T/sm/wrong"
[ $rc -eq 2 ] && grep -q '^OUT OF ORDER, nothing was deleted: sa is not right yet' <<< "$out" && [ -e "$T/state/claude-json.before-sa" ] && ok "structure-clear keeps the backup while the seat is wrong" || bad "sm clear wrong: $rc $out"
out=$(SM structure-clear sa); rc=$?; [ $rc -eq 0 ] && grep -q '^DELETED' <<< "$out" && [ ! -e "$T/state/claude-json.before-sa" ] && [ ! -e "$smgb" ] && ok "and deletes it, and the settings backup, once the seat checks right" || bad "sm clear: $rc $out"
grep -q '^NOTHING TO DELETE' <<< "$(SM structure-clear sa)" && ok "a second clear has nothing to do" || bad "sm clear twice"
mv "$SMT" "$SMF.back"; rmdir "$SMF"; mv "$SMF.back" "$SMF"; grep -q '^OUT OF ORDER, nothing was deleted: sa has not moved' <<< "$(SM structure-clear sa)" && ok "clear never runs before the move" || bad "sm clear before"
cp "$T/sm/rescue.sh.keep" "$T/run/rescue.sh"; pinf rescue.sh
# structure-batch.sh, through the runner, on a stub structure-move.sh: $T/sb/SEAT.STEP holds the exit code a step gives, .out its words.
rm -rf "$T/sb"; mkdir -p "$T/sb"; cp "$T/run/structure-move.sh" "$T/sb/keep-structure-move"
cat > "$T/run/structure-move.sh" <<S
#!/bin/bash
echo "\$1 \$2" >> "$T/sb/calls"
f="$T/sb/\$1.\$2"; [ ! -f "\$f.out" ] || cat "\$f.out"; [ -f "\$f" ] && exit "\$(cat "\$f")"; echo "stub \$1 \$2"; exit 0
S
chmod +x "$T/run/structure-move.sh"; pinf structure-move.sh
printf 'sa x\nsb x\nsc x\n' > "$T/sb/table"
SB() { ZEO_RESCUE_BATCHES="$T/sb/batches" ZEO_RESCUE_TABLE="$T/sb/table" L structure-batch "$@" 2>&1; }
sbreset() { rm -f "$T/sb/calls" "$T/sb"/s?.*; }
printf '# a comment\nb1 sa\nb1 sb\nb1 sc\nb2 sa\nb2 sa\nb3 sa\nb3 sz\nb4 sa x\n' > "$T/sb/batches"
out=$(SB); rc=$?; [ $rc -eq 2 ] && grep -q '^usage: reseat-lines.sh structure-batch BATCH; nothing was run' <<< "$out" && ok "a batch step needs its batch" || bad "sb usage: $rc $out"
sbreset; out=$(SB nope); rc=$?; [ $rc -eq 2 ] && grep -q '^REFUSED, nothing was run: there is no batch nope' <<< "$out" && [ ! -e "$T/sb/calls" ] && ok "an unknown batch runs nothing" || bad "sb unknown: $rc $out"
out=$(SB b2); rc=$?; [ $rc -eq 2 ] && grep -q '^REFUSED, nothing was run: sa is in batch b2 twice' <<< "$out" && [ ! -e "$T/sb/calls" ] && ok "a seat twice in a batch runs nothing" || bad "sb twice: $rc $out"
out=$(SB b3); rc=$?; [ $rc -eq 2 ] && grep -q '^REFUSED, nothing was run: sz needs exactly one row in structure-moves' <<< "$out" && [ ! -e "$T/sb/calls" ] && ok "every seat is read before any moves: one with no row runs nothing, not even the seats before it" || bad "sb row: $rc $out"
out=$(SB b4); rc=$?; [ $rc -eq 2 ] && grep -q '^REFUSED, nothing was run: a line of batch b4 in structure-batches is not BATCH SEAT' <<< "$out" && [ ! -e "$T/sb/calls" ] && ok "a line of the wrong shape runs nothing" || bad "sb shape: $rc $out"
sbreset; out=$(SB b1); rc=$?
[ $rc -eq 0 ] && [ "$(grep -c '^RESULT s[abc]: MOVED: note delivered, its own check OK, its backup gone$' <<< "$out")" = 3 ] && grep -q '^batch b1: moved 3, already moved 0, skipped 0, stopped at none, not reached 0, of 3\.' <<< "$out" && ok "a batch moves each seat: one RESULT line each, then the total" || bad "sb all: $rc $out"
[ "$(tr '\n' ' ' < "$T/sb/calls")" = "sa trust sa first sa clear sb trust sb first sb clear sc trust sc first sc clear " ] && ok "each seat in the table's order: trust, first, clear, and only then the next" || bad "sb order: $(cat "$T/sb/calls")"
sbreset; echo 2 > "$T/sb/sb.first"; printf 'BUSY, nothing was run. Try again when it is idle:\nWORK sb: a turn is in progress on its screen\n' > "$T/sb/sb.first.out"; out=$(SB b1); rc=$?
[ $rc -eq 0 ] && grep -q '^RESULT sb: SKIPPED, it is busy: WORK sb: a turn is in progress' <<< "$out" && grep -q '^RESULT sc: MOVED' <<< "$out" && ! grep -q '^sb clear' "$T/sb/calls" && grep -q 'skipped 1, stopped at none' <<< "$out" && ok "a busy seat is SKIPPED with the reason, nothing more is run for it, and the batch goes on" || bad "sb busy: $rc $out"
sbreset; echo 2 > "$T/sb/sb.first"; echo 'DOWN, nothing was run: sb is not running' > "$T/sb/sb.first.out"; out=$(SB b1); rc=$?
[ $rc -eq 0 ] && grep -q '^RESULT sb: SKIPPED, it is down' <<< "$out" && grep -q '^RESULT sc: MOVED' <<< "$out" && ok "and so is a seat that is down" || bad "sb down: $rc $out"
for case_ in "first 1 STOPPED: the move or its check failed" "first 2 REFUSED, nothing was run: the plan does not move sb" "trust 2 REFUSED, nothing was changed: an unknown state" "clear 2 OUT OF ORDER, nothing was deleted: sb is not right yet"; do
  set -- $case_; st=$1 code=$2; shift 2; sbreset; echo "$code" > "$T/sb/sb.$st"; echo "$*" > "$T/sb/sb.$st.out"; out=$(SB b1); rc=$?
  [ $rc -eq 1 ] && grep -q "^RESULT sb: STOPPED at $st (exit $code)" <<< "$out" && grep -q '^RESULT sc: NOT REACHED; nothing was run for it' <<< "$out" && ! grep -q '^sc ' "$T/sb/calls" && grep -q 'stopped at sb, not reached 1, of 3' <<< "$out" || { bad "sb stop $st $code: $rc $out"; continue; }
  case $st in trust) ! grep -q '^sb first' "$T/sb/calls" || bad "sb stop trust ran first";; first) ! grep -q '^sb clear' "$T/sb/calls" || bad "sb stop first ran clear";; esac
done; ok "a failure, a refusal that is not busy or down, or a check not OK, stops the batch at that seat, and nothing runs for the seats after it"
sbreset; echo 'ALREADY DONE: sa moved to x and its note arrived (t). Nothing was run.' > "$T/sb/sa.first.out"; out=$(SB b1); rc=$?
[ $rc -eq 0 ] && grep -q '^RESULT sa: ALREADY MOVED; its backup is gone' <<< "$out" && grep -q '^sa clear' "$T/sb/calls" && grep -q 'moved 2, already moved 1' <<< "$out" && ok "a second run finds a moved seat ALREADY MOVED and still clears its backup" || bad "sb again: $rc $out"
ls "$T/state"/reseat-lines-structure-batch-b1-* >/dev/null 2>&1 && ok "the batch's output is kept in the state folder, under its name" || bad "sb log"
cp "$T/sb/keep-structure-move" "$T/run/structure-move.sh"; pinf structure-move.sh
# the real batches: every seat has its row, and is in one batch only
sbbad=$(awk '$1 !~ /^#/ && NF' "$HERE/structure-batches" | while read -r bb ss x; do [ -z "$x" ] && [ "$(awk -v s="$ss" '$1==s' "$HERE/structure-moves" | wc -l | tr -d ' ')" = 1 ] || echo "$ss"; done; awk '$1 !~ /^#/ && NF {print $2}' "$HERE/structure-batches" | sort | uniq -d)
[ -z "$sbbad" ] && ok "each seat in structure-batches has its one row in structure-moves, and is in one batch only" || bad "batches: $sbbad"
# the real table: every row agrees with folder-moves and session-pins, and the note has no backtick or star
bad_rows=$(awk '$1 !~ /^#/ && NF' "$HERE/structure-moves" | while read -r s h ts sid f t i a; do
  [ "$(awk -v s="$s" '$1==s {print $2 " " $3}' "$HERE/folder-moves")" = "$t carry" ] && [ "$(awk -v s="$s" '$1==s {print $2}' "$HERE/session-pins")" = "$sid" ] || echo "$s"
  if [ -n "$a" ]; then [ "$(/usr/bin/shasum -a 256 "$HERE/notes/structure-move-$s.txt" 2>/dev/null | cut -d " " -f 1)" = "$a" ] && [ "$(grep -c '[`*{}]' "$HERE/notes/structure-move-$s.txt")" = 0 ] || echo "$s addition"; else [ ! -e "$HERE/notes/structure-move-$s.txt" ] || echo "$s unpinned addition"; fi; done)
[ -z "$bad_rows" ] && ok "each row of structure-moves agrees with folder-moves and session-pins, and each addition is the one its row pins, with no mark" || bad "rows: $bad_rows"
[ "$(grep -c '[`*]' "$HERE/notes/structure-move-claude.txt")" = 0 ] && ok "the structure note has no backtick or star" || bad "sm note marks"
n=$HERE/notes/claude-move-ducktyper-ops-20261108.txt; grep -qF "$(enc2 /Volumes/AIPEMedia1/code/zeroemployeeorg/ducktyper-ops)/memory/, which no longer exists" "$n" && grep -qF "$(enc2 /Volumes/AIPEMedia1/code/ducktyper-ai/ducktyper-ops)/memory/" "$n" && [ "$(grep -c '[`*]' "$n")" = 0 ] && ok "the seat's note names its old memory folder as gone and the new one by its key, with no backtick or star" || bad "cf note"
grep -q 'zeroemployeeorg-zeocreator/memory/' "$HERE/notes/zeocreator-memory-20261108.txt" && grep -q "never in the old folder" "$HERE/notes/zeocreator-memory-20261108.txt" && grep -qF "$(printf %s /Volumes/AIPEMedia1/code/ducktyper-ai/dt-creator/main | LC_ALL=C sed 's/[^A-Za-z0-9]/-/g')/memory/" "$HERE/notes/zeocreator-memory-20261108.txt" && ok "its note names the old memory folder as gone, and the real one by the key of its folder" || bad "zc note"
SIDC=ca076ba8-7fee-46f0-853b-8182adc3c975; kc=$(printf %s "$T/d/creator" | LC_ALL=C sed 's/[^A-Za-z0-9]/-/g'); printf '{"seats":[{"seat_id":"ducktyper-ops","mailbox":"ducktyper-ops","desired_agent":"claude","desired_host":"matormini","desired_tmux":{"session":"zc"},"desired_folder":"%s"}]}' "$T/d/oldc" > "$T/zc.json"
C() { ZEO_RESCUE_CHART="$T/zc.json" ZEO_RESCUE_PINS="$T/run/session-pins" ZEO_RESCUE_MOVES="$T/run/folder-moves" ZEO_RESCUE_PROJECTS="$T/pc" ZEO_RESCUE_CLAUDE_JSON="$T/cj.json" L "$@" 2>&1; }
mkdir -p "$T/pc/$kc"; : > "$T/pc/$kc/$SIDC.jsonl"; echo x > "$B"; echo zc >> "$T/live"; echo "zc|%9|900|1|claude" > "$T/panes"; echo "900 /x/claude --resume $SIDC" > "$T/ps.out"
echo "$GOOD ZMAIL_INSTANCE=other" > "$T/psE.out"; out=$(C claude-clear); rc=$?
[ $rc -eq 2 ] && echo "$out" | grep -q '^OUT OF ORDER, nothing was deleted: ducktyper-ops is not right yet' && [ -e "$B" ] && ok "claude-clear keeps the backup while the seat is wrong" || bad "clear wrong: $rc $out"
echo "$GOOD ZMAIL_INSTANCE=ducktyper-ops" > "$T/psE.out"; out=$(C claude-clear); rc=$?
[ $rc -eq 0 ] && echo "$out" | grep -q '^DELETED' && [ ! -e "$B" ] && ok "claude-clear deletes it once the seat checks right" || bad "clear: $rc $out"
grep -q '^NOTHING TO DELETE' <<< "$(C claude-clear)" && ok "and a second run has nothing to do" || bad "clear twice"
: > "$T/live"; : > "$T/panes"; : > "$T/ps.out"; : > "$T/psE.out"
grep -q '^NOTHING TO ADD' <<< "$(ZEO_RESCUE_CLAUDE_JSON="$T/cj.json" L claude-trust 2>&1)" && ok "a second run changes nothing" || bad "trust twice"
printf '{"projects":{}}' > "$T/cj2.json"; mkdir "$T/cj2.json.lock"
out=$(ZEO_RESCUE_CLAUDE_JSON="$T/cj2.json" L claude-trust 2>&1); rc=$?; rmdir "$T/cj2.json.lock"
[ $rc -eq 1 ] && echo "$out" | grep -q "Claude's config lock stayed held" && [ "$(cat "$T/cj2.json")" = '{"projects":{}}' ] && ok "it waits for Claude's own lock and changes nothing if it stays held" || bad "lock: $rc $out"
out=$(ZEO_RESCUE_PROJECTS="$T/pj" L claude-back 2>&1); rc=$?
[ $rc -eq 2 ] && echo "$out" | grep -q 'take ducktyper-ops out of folder-moves first' && ok "claude-back refuses while the seat's line stands" || bad "back: $rc $out"
echo "# none" > "$T/run/folder-moves"; repin; SIDC=ca076ba8-7fee-46f0-853b-8182adc3c975; kn=$(printf %s "$T/d/creator" | LC_ALL=C sed 's/[^A-Za-z0-9]/-/g'); ko=$(printf %s "$T/d/oldc" | LC_ALL=C sed 's/[^A-Za-z0-9]/-/g'); mkdir -p "$T/pj/$kn/memory"; : > "$T/pj/$kn/$SIDC.jsonl"
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

echo "-- an ops seat's folder steps: a new empty folder first, the old one removed after the restart (ops-move.sh, on a copy)"
# Never the real script: a copy with every path rewritten into $T. The real one would act on the real folders.
O=$(cd "$T" && pwd -P)/o osid=ca076ba8-7fee-46f0-853b-8182adc3c975; OO=$O/org/ducktyper-ops ON=$O/dt/ducktyper-ops
rm -rf "$O"; mkdir -p "$OO" "$O/dt" "$O/state" "$O/proj/$(enc2 "$OO")"; echo '{}' > "$O/proj/$(enc2 "$OO")/$osid.jsonl"
echo "ducktyper-ops $ON" > "$O/moves"; echo "ducktyper-ops $osid" > "$O/pins"
sed -e "s#^    OLD=.*#    OLD=$OO#" -e "s#^    NEW=.*#    NEW=$ON#" -e "s#^    OLD_INODE=.*#    OLD_INODE=$(stat -f %i "$OO");;#" "$HERE/ops-move.sh" > "$O/ops-move.sh"
printf '#!/bin/bash\ncat "%s/opsp" 2>/dev/null\n' "$T" > "$T/bin/tmuxo"; printf '#!/bin/bash\ncat "%s/opsps" 2>/dev/null\n' "$T" > "$T/bin/pso"; chmod +x "$T/bin/tmuxo" "$T/bin/pso"
OM() { STATE="$O/state" ZEO_RESCUE_PROJECTS="$O/proj" ZEO_RESCUE_MOVES="$O/moves" ZEO_RESCUE_PINS="$O/pins" ZEO_RESCUE_TMUX="$T/bin/tmuxo" ZEO_RESCUE_LSOF="$T/bin/lsofz" ZEO_RESCUE_PS="$T/bin/pso" bash "$O/ops-move.sh" "$@" 2>&1; }
grep -E '^    (OLD|NEW)=/Volumes' "$O/ops-move.sh" >/dev/null && bad "the copy still names a real folder" || ok "the copy names no real folder"
out=$(OM rasa-ops folder); [ $? -eq 2 ] && grep -q '^usage: ops-move.sh ducktyper-ops folder|old; nothing was run' <<< "$out" && ok "a seat it was not written for runs nothing" || bad "ops usage seat: $out"
out=$(OM ducktyper-ops fold); [ $? -eq 2 ] && grep -q '^usage:' <<< "$out" && ok "nor does an unknown step" || bad "ops usage step: $out"
orefuse() { # orefuse WHAT PATTERN: the folder step refuses, and makes nothing
  local out rc; out=$(OM ducktyper-ops folder); rc=$?
  [ $rc -eq 2 ] && grep -q "^REFUSED, nothing was changed: .*$2" <<< "$out" && [ ! -e "$ON" ] && [ ! -e "$O/state/ops-move-ducktyper-ops/folder.done" ] && ok "$1" || bad "$1: $rc $out"; }
echo "ducktyper-ops $O/dt/other" > "$O/moves"; orefuse "a folder-moves line naming another folder is refused" 'folder-moves needs exactly one line'
printf 'ducktyper-ops %s\nducktyper-ops %s\n' "$ON" "$ON" > "$O/moves"; orefuse "so are two lines" 'folder-moves needs exactly one line'; echo "ducktyper-ops $ON" > "$O/moves"
echo "ducktyper-ops 11111111-1111-4111-8111-111111111111" > "$O/pins"; orefuse "a session pin naming another session is refused" 'session-pins needs'; echo "ducktyper-ops $osid" > "$O/pins"
: > "$OO/new-file"; orefuse "an old folder that is no longer empty is refused" 'is not the empty folder read on 8 Nov'; rm "$OO/new-file"
cp "$O/ops-move.sh" "$T/om"; perl -i -pe 's/^    OLD_INODE=.*/    OLD_INODE=1;;/' "$O/ops-move.sh"; orefuse "so is another folder at the old path" 'is not the empty folder read on 8 Nov'; cp "$T/om" "$O/ops-move.sh"
ZG init -q "$O/dt"; orefuse "a new folder inside a repository is refused" 'is in git, so the new folder would be inside a repository'; rm -rf "$O/dt/.git"
mkdir "$ON"; out=$(OM ducktyper-ops folder); [ $? -eq 2 ] && grep -q "^REFUSED, nothing was changed: $ON already exists" <<< "$out" && [ ! -e "$O/state/ops-move-ducktyper-ops/folder.done" ] && ok "a new folder already there is refused" || bad "ops new there: $out"; rmdir "$ON"
mkdir "$O/proj/$(enc2 "$ON")"; orefuse "so is a project already under the new folder's key" "already exists, and the restart's rename needs the name free"; rmdir "$O/proj/$(enc2 "$ON")"
mv "$O/proj/$(enc2 "$OO")" "$T/oproj"; orefuse "so is a seat whose transcript is not where its folder says" "the seat's transcript is not at"; mv "$T/oproj" "$O/proj/$(enc2 "$OO")"
out=$(OM ducktyper-ops folder); rc=$?
[ $rc -eq 0 ] && grep -q "^MADE: $ON, empty, mode 755" <<< "$out" && grep -q '^FOLDER DONE' <<< "$out" && [ -d "$ON" ] && [ -z "$(ls -A "$ON")" ] && [ "$(stat -f %Lp "$ON")" = 755 ] && [ -d "$OO" ] && ok "the folder step makes the new folder, empty, and leaves the old one and the seat alone" || bad "ops folder: $rc $out"
[ "$(sed -n 's/^inode=//p' "$O/state/ops-move-ducktyper-ops/folder.done")" = "$(stat -f %i "$ON")" ] && [ "$(stat -f %Lp "$O/state/ops-move-ducktyper-ops")" = 700 ] && ok "its mark names the folder it made, in a state folder of mode 700" || bad "ops mark"
grep -q '^ALREADY DONE: .* made by this step' <<< "$(OM ducktyper-ops folder)" && ok "a second folder step changes nothing" || bad "ops folder twice"
out=$(OM ducktyper-ops old); [ $? -eq 2 ] && grep -q '^OUT OF ORDER, nothing was changed: the restart in .* has not been proved' <<< "$out" && [ -d "$OO" ] && ok "the old folder stays until the restart is proved" || bad "ops old order: $out"
date > "$O/state/ops-move-ducktyper-ops/first.done"; echo 4242 > "$T/opsp"; echo "/x/claude --resume $osid --permission-mode auto" > "$T/opsps"; printf 'p4242\nfcwd\nn%s\n' "$ON" > "$T/lsofz.out"
orefuse2() { local out rc; out=$(OM ducktyper-ops old); rc=$?; [ $rc -eq 2 ] && grep -q "^REFUSED, nothing was changed: .*$2" <<< "$out" && [ -d "$OO" ] && ok "$1" || bad "$1: $rc $out"; }
orefuse2 "the old folder stays while the project is still under it" "the seat's project is not under"
mv "$O/proj/$(enc2 "$OO")" "$O/proj/$(enc2 "$ON")"
printf 'p4242\nfcwd\nn%s\np5555\nfcwd\nn%s\n' "$ON" "$OO" > "$T/lsofz.out"; orefuse2 "or while another process works in it" 'a process still works in'
printf 'p4242\nfcwd\nn%s\n' "$OO" > "$T/lsofz.out"; orefuse2 "or while the seat itself still works there" 'is not working in'; printf 'p4242\nfcwd\nn%s\n' "$ON" > "$T/lsofz.out"
echo "/x/claude --resume 11111111-1111-4111-8111-111111111111" > "$T/opsps"; orefuse2 "or when the seat's pane runs another session" 'does not resume'; echo "/x/claude --resume $osid --permission-mode auto" > "$T/opsps"
: > "$T/opsp"; orefuse2 "or when the seat's pane cannot be read" "cannot read the seat's pane"; echo 4242 > "$T/opsp"
: > "$OO/late"; orefuse2 "or when something was put in it" 'is not the empty folder read on 8 Nov'; rm "$OO/late"
printf 'p4243\nfcwd\nn%s\np4242\nfcwd\nn%s\n' "$ON" "$ON" > "$T/lsofz.out"; out=$(OM ducktyper-ops old); rc=$?
[ $rc -eq 0 ] && grep -q "^REMOVED: $OO, which was empty" <<< "$out" && [ ! -e "$OO" ] && [ -d "$ON" ] && [ -s "$O/state/ops-move-ducktyper-ops/old.done" ] && ok "with the seat in the new folder, a child of it there too, and nothing in the old one, the old empty folder goes" || bad "ops old: $rc $out"
grep -q '^ALREADY DONE: .* was removed' <<< "$(OM ducktyper-ops old)" && ok "a second old step changes nothing" || bad "ops old twice"
: > "$T/lsofz.out"; : > "$T/opsp"; : > "$T/opsps"
sed "s/^WANT=.*/WANT=$pl/" "$HERE/reseat-lines.sh" > "$T/run/reseat-lines.sh"; chmod +x "$T/run/reseat-lines.sh"; fill
printf '#!/bin/bash\necho "STUB $* STATE=$STATE"\n' > "$T/run/ops-move.sh"; chmod +x "$T/run/ops-move.sh"; pinf ops-move.sh
grep -q '^STUB ducktyper-ops folder STATE' <<< "$(L ops-folder 2>&1)" && grep -q '^STUB ducktyper-ops old STATE' <<< "$(L ops-old 2>&1)" && ok "ops-folder and ops-old run ops-move.sh for the seat moving" || bad "ops wire: $(L ops-folder 2>&1)"
cp "$HERE/ops-move.sh" "$T/run/ops-move.sh"

echo; [ $fails -eq 0 ] && echo "PASS" || { echo "$fails FAILED"; exit 1; }
