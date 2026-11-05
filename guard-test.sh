#!/bin/bash
# Guard regressions, ported from the council's Python suite: this host's charter forbids python3. Functions are extracted from the real
# scripts and run with stub tools, except the WAL case, which uses the real sqlite3 CLI and so tests what the scripts really call.
set -uo pipefail
HERE=$(cd "$(dirname "$0")" && pwd -P)
T=$(mktemp -d); trap 'rm -rf "$T"' EXIT
JQ=$(command -v jq); SQL=/usr/bin/sqlite3
n=0; fails=0
ok()  { n=$((n+1)); echo "ok $n - $1"; }
bad() { echo "FAIL: $1"; fails=$((fails+1)); }
fn()  { sed -n "/^$1()/,/^}/p" "$2"; }
R=$HERE/rescue.sh
run() { bash -c "set -uo pipefail
$1"; }
tail_block=$(sed -n '/^stopped=1/,$p' "$R")

# 1. a live WAL: the row exists only in the WAL while a writer stays open, which is the state of Codex's database in use
id=44444444-4444-4444-8444-444444444444
printf '{"type":"session_meta","payload":{"id":"%s","cwd":"/seat"}}\n{"type":"turn_context","payload":{"approval_policy":"never","sandbox_policy":{"type":"workspace-write"}}}\n' "$id" > "$T/roll"
$SQL "$T/db" "create table threads(id text, rollout_path text, cwd text, archived int, thread_source text, updated_at int); pragma journal_mode=wal;" >/dev/null
mkfifo "$T/in"; $SQL "$T/db" < "$T/in" >/dev/null & w=$!
exec 3> "$T/in"
echo "pragma wal_autocheckpoint=0; insert into threads values ('$id','$T/roll','/seat',0,'user',1);" >&3
for _ in 1 2 3 4 5 6 7 8 9 10 11 12 13 14 15 16 17 18 19 20; do [ -s "$T/db-wal" ] && break; perl -e 'select(undef,undef,undef,0.1)'; done
out=$(run "$(fn history "$HERE/records.sh")
DB='$T/db'; SQL=$SQL; JQ=$JQ; UUID='^[0-9a-f-]{36}\$'; fail() { echo \"\$*\" >&2; return 1; }
history codex $id /seat") ; rc=$?
imm=$($SQL "file:$T/db?mode=ro&immutable=1" "select count(*) from threads;" 2>/dev/null)
exec 3>&-; wait "$w" 2>/dev/null
if [ $rc -eq 0 ] && [ "$($JQ -r .path <<< "$out")" = "$T/roll" ] && [ "$imm" != 1 ]; then ok "a row only in a live WAL is read with mode=ro, and immutable=1 would have missed it (real sqlite3)"; else bad "wal: rc=$rc imm=$imm $out"; fi

# 2-7. lsof outcomes
lsof_case() { # NAME BODY WANT [nofile]
  printf '#!/bin/sh\n%s\n' "$2" > "$T/lsof"; chmod +x "$T/lsof"
  local f=$T/target; rm -f "$f"; [ -n "${4:-}" ] || touch "$f"
  run "$(fn rollout_free "$R")
LSOF='$T/lsof'; STATE='$T'; ROLLOUT_TRIES=1; pause() { :; }; rollout_free '$f'" >/dev/null 2>&1
  local got=$?
  if { [ "$3" = free ] && [ $got -eq 0 ]; } || { [ "$3" = held ] && [ $got -ne 0 ]; }; then ok "$1"; else bad "$1: rc $got"; fi
}
lsof_case 'lsof that fails silently is not "free"' 'exit 2' held
lsof_case 'lsof with a diagnostic is not "free"' 'echo permission-denied >&2; exit 1' held
lsof_case 'no holder is free' 'exit 1' free
lsof_case 'a holder is held' 'echo 234; exit 0' held
lsof_case 'a missing rollout is not free' 'exit 1' held nofile
lsof_case 'success with no pid is unknown, not free' 'exit 0' held

# 8. check does not hide unresolved
block=$(sed -n '/^if \[ \$CHECK -eq 1 \]; then/,/^fi/p' "$R")
run "CHECK=1; ok=0; wrong=0; unresolved=1
$block" >/dev/null; [ $? -ne 0 ] && ok "check does not hide unresolved seats" || bad "check hid unresolved"

# 9. an unresolved reseat stops before anything is touched
out=$(run "APPLY=1; RESEAT=1; unresolved=1; failed=0; resumed=0; STAGGER=0; live=0; ok=0; running=0; resume=0; reseat=1; HERE=/x
P_SEAT=(seat); P_PANE=(%1); P_CWD=(/seat); P_SID=(thread); P_HARNESS=(codex); P_ROLL=(roll)
work_list() { :; }; stop_seat() { echo MUTATION; return 1; }; stop_daemon() { echo MUTATION; }
$tail_block"); rc=$?
[ $rc -ne 0 ] && ! grep -q MUTATION <<< "$out" && ok "an unresolved reseat plan stops before any seat is stopped" || bad "unresolved: $out"

# 10. the recovery text promises nothing it cannot prove. A wording check, and only that.
fn recovery "$R" | grep -q 'nothing is lost' && bad "lossless claim" || ok "recovery text makes no lossless claim (wording only)"

# 11. a failed process listing is not "no process"
printf '#!/bin/sh\nexit 2\n' > "$T/ps"; chmod +x "$T/ps"
run "$(fn holds "$R")
PS_BIN='$T/ps'; CLAUDE_SESSIONS='$T/none'; holds thread"; [ $? -eq 2 ] && ok "a failed process listing is reported, not read as no process" || bad "holds rc"

# 12. stop refuses an unknown state
run "$(fn stop_seat "$R")
TMUX_BIN=true; SOCKET=test; STOP_TRIES=1; holds() { return 2; }; pause() { :; }; stop_seat %1 /tmp thread" >/dev/null; [ $? -ne 0 ] && ok "stop refuses an unknown process state" || bad "stop"

# 13. no SIGKILL. A wording check, and only that.
fn stop_daemon "$R" | grep -q '"\$KILL_BIN" -9' && bad "sigkill" || ok "no automatic SIGKILL (wording only)"

# 14. daemon failure blocks launch
out=$(run "APPLY=1; RESEAT=1; unresolved=0; failed=0; resumed=0; STAGGER=0; live=0; ok=0; running=0; resume=1; reseat=0; STATE=/tmp; HERE=/x
P_SEAT=(seat); P_PANE=(''); P_CWD=(/seat); P_SID=(thread); P_HARNESS=(codex); P_ROLL=(roll); P_SESS=(seat); P_MODE=(''); P_WHY=(''); P_MARK=('')
work_list() { :; }; stop_daemon() { return 1; }; rollout_free() { return 0; }; holds() { return 1; }
launch() { echo LAUNCHED; return 0; }; prove_codex() { return 0; }; recovery() { :; }
$tail_block"); rc=$?
[ $rc -ne 0 ] && ! grep -q LAUNCHED <<< "$out" && ok "a daemon that fails to stop blocks every launch" || bad "daemon block: $out"

# 15-18. how the daemon goes
daemon='900 /h/.codex/packages/app-server-daemon/releases/1/bin/codex app-server --listen unix://s'
daemon_case() { # NAME AFTER KILL_EXIT WANT
  rm -f "$T/seen" "$T/kills"; echo "$daemon" > "$T/before"; echo "$2" > "$T/after"
  printf '#!/bin/sh\nif [ -f "%s/seen" ]; then cat "%s/after"; else touch "%s/seen"; cat "%s/before"; fi\n' "$T" "$T" "$T" "$T" > "$T/ps"
  printf '#!/bin/sh\necho "$*" >> "%s/kills"\nexit %s\n' "$T" "$3" > "$T/kill"; chmod +x "$T/ps" "$T/kill"
  run "$(fn stop_daemon "$R")
PS_BIN='$T/ps'; KILL_BIN='$T/kill'; ZEO_RESCUE_DAEMON_WAIT=2; pause() { :; }; stop_daemon" >/dev/null 2>&1
  local got=$?
  if { [ "$4" = allow ] && [ $got -eq 0 ]; } || { [ "$4" = refuse ] && [ $got -ne 0 ]; } && ! grep -q -- -9 "$T/kills"; then ok "$1"; else bad "$1: rc $got"; fi
}
daemon_case 'a daemon that survives SIGTERM refuses, without SIGKILL' '900 daemon' 0 refuse
daemon_case 'a failed signal refuses' '' 1 refuse
daemon_case 'a replacement daemon refuses' '901 /h/.codex/packages/app-server-daemon/releases/1/bin/codex app-server' 0 refuse
daemon_case 'a daemon that exits allows the run' '' 0 allow

# 19. a slow daemon is waited for: gone on the third look, not the first
rm -f "$T/seen" "$T/n" "$T/kills"
cat > "$T/ps" <<S
#!/bin/sh
c=\$(cat "$T/n" 2>/dev/null || echo 0); c=\$((c+1)); echo \$c > "$T/n"
[ \$c -le 3 ] && echo "$daemon"
exit 0
S
printf '#!/bin/sh\nexit 0\n' > "$T/kill"; chmod +x "$T/ps" "$T/kill"
run "$(fn stop_daemon "$R")
PS_BIN='$T/ps'; KILL_BIN='$T/kill'; ZEO_RESCUE_DAEMON_WAIT=10; pause() { :; }; stop_daemon" >/dev/null 2>&1
[ $? -eq 0 ] && ok "a daemon that takes a while to exit is waited for" || bad "slow daemon"
echo; if [ $fails -eq 0 ]; then echo "PASS: $n guard checks"; else echo "$fails FAILED"; exit 1; fi
