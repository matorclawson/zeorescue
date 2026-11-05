#!/bin/bash
# No real tmux, harness, model, mailbox or host process is used.
set -euo pipefail
HERE=$(cd "$(dirname "$0")" && pwd -P)
T=$(mktemp -d); trap 'rm -rf "$T"' EXIT
mkdir -p "$T/bin" "$T/state" "$T/cx" "$T/cl" "$T/projects" "$T/snapshots"
export HOME="$T" ZEO_RESCUE_STATE="$T/state" ZEO_RESCUE_CHART="$T/chart.json" ZEO_RESCUE_HOST=h ZEO_RESCUE_SOCKET=test
export ZEO_RESCUE_JQ="$(command -v jq)" ZEO_RESCUE_TMUX="$T/bin/tmux" ZEO_RESCUE_PS="$T/bin/ps" ZEO_RESCUE_SQLITE="$T/bin/sqlite" ZEO_RESCUE_LSOF="$T/bin/lsof"
export ZEO_RESCUE_PROJECTS="$T/projects" ZEO_RESCUE_CODEX_DB="$T/db" ZEO_RESCUE_SNAPSHOTS="$T/snapshots"
export ZEO_RESCUE_CODEX=/must-not-execute/codex ZEO_RESCUE_CLAUDE=/must-not-execute/claude ZEO_RESCUE_KILL="$T/bin/kill"
export ZEO_RESCUE_PROOF_TRIES=1 ZEO_RESCUE_PROOF_PAUSE=0 ZEO_RESCUE_STOP_TRIES=1 ZEO_RESCUE_ROLLOUT_TRIES=1
CX=11111111-1111-4111-8111-111111111111
CL=22222222-2222-4222-8222-222222222222
NEW=33333333-3333-4333-8333-333333333333
q=$ZEO_RESCUE_JQ
"$q" -n --arg cx "$T/cx" --arg cl "$T/cl" '{seats:[{seat_id:"cx",mailbox:"cx",desired_host:"h",desired_agent:"codex",desired_folder:$cx,desired_tmux:{session:"cx-s"}},{seat_id:"cl",mailbox:"cl",desired_host:"h",desired_agent:"claude",desired_folder:$cl,desired_tmux:{session:"cl-s"}}]}' > "$T/chart.json"
printf '%s\n' "{\"type\":\"session_meta\",\"payload\":{\"id\":\"$CX\",\"cwd\":\"$T/cx\"}}" '{"type":"turn_context","payload":{"approval_policy":"never","sandbox_policy":{"type":"danger-full-access"}}}' > "$T/rollout-$CX.jsonl"
enc=$(printf %s "$T/cl" | sed 's/[^A-Za-z0-9]/-/g'); mkdir -p "$T/projects/$enc"
printf '{"sessionId":"%s","cwd":"%s","permissionMode":"auto"}\n' "$CL" "$T/cl" > "$T/projects/$enc/$CL.jsonl"
printf '{"sessionId":"%s","cwd":"%s","permissionMode":"plan"}\n' "$NEW" "$T/cl" > "$T/projects/$enc/$NEW.jsonl"
cat > "$T/bin/sqlite" <<S
#!/bin/bash
printf '%s\n' "\$*" >> '$T/sql.log'
case "\$2" in *"id = '$CX' and cwd = '$T/cx'"*) echo '$T/rollout-$CX.jsonl';; *) exit 1;; esac
S
cat > "$T/bin/ps" <<S
#!/bin/bash
[ ! -e '$T/ps-fail' ] || exit 2
case "\$1" in
 -Ewwp)
  if [ -e '$T/wrong-id' ]; then echo 'codex ZMAIL_INSTANCE=wrong'; exit 0; fi
  case "\$2" in 11) echo 'codex ZMAIL_INSTANCE=cx ZEO_TMUX_SEAT=master GIT_ALLOW_PROTOCOL=ssh:https:file';; 22) echo 'claude ZMAIL_INSTANCE=cl ZEO_TMUX_SEAT=master GIT_ALLOW_PROTOCOL=ssh:https:file';; esac;;
 *) cat '$T/processes';;
esac
S
cat > "$T/bin/tmux" <<S
#!/bin/bash
printf '%s\n' "\$*" >> '$T/tmux.log'
case "\$3" in
 list-panes)
  if [ -e '$T/down' ] && [ -e '$T/launch' ]; then
    case "\$6" in '=cx-s') echo '%11|11||codex'; exit 0;; '=cl-s') echo '%22|22||claude'; exit 0;; esac
  fi
  [ ! -e '$T/down' ] || exit 1
  case "\$6" in '=cx-s') cat '$T/cx-pane';; '=cl-s') echo '%22|22|master';; *) exit 1;; esac;;
 has-session) [ ! -e '$T/down' ];;
 new-session) echo "\$6" > '$T/started'; touch '$T/launch';;
 set-option) exit 0;;
 respawn-pane)
  # Execute no harness. Only write the snapshot the proof observes.
  printf 'export ZMAIL_INSTANCE=cx\nexport ZEO_TMUX_SEAT=master\nexport GIT_ALLOW_PROTOCOL=ssh:https:file\n' > '$T/snapshots/$CX.new.sh';;
 *) exit 1;;
esac
S
# New-session path needs a pane even when every original seat is down.
cat > "$T/bin/lsof" <<S
#!/bin/bash
if [ -e '$T/fd-mode' ] && [ "\${2:-}" = -p ]; then echo 'n$T/rollout-$CX.jsonl'; exit 0; fi
case "\$1" in
 -t) [ -e '$T/holder' ] && { echo 777; exit 0; }; exit 1;;
 *) case "\${@: -1}" in 11) echo 'n$T/cx';; 22) echo 'n$T/cl';; esac;;
esac
S
cat > "$T/bin/kill" <<S
#!/bin/bash
echo 'FORBIDDEN KILL' >> '$T/kills'; exit 2
S
chmod +x "$T/bin/"*
printf '11 /fake/codex resume --no-daemon %s\n22 /fake/claude --resume %s\n' "$CX" "$CL" > "$T/processes"
echo '%11|11|master' > "$T/cx-pane"
n=0
ok() { n=$((n+1)); echo "ok $n - $1"; }
fail() { echo "FAIL: $1"; exit 1; }
R() { "$HERE/records.sh" "$@"; }
R capture > "$T/out" || { cat "$T/out"; fail capture; }
"$q" -e '.records|length==2' "$T/state/recovery-records.json" >/dev/null || fail 'record count'; ok 'both harness records captured without executing either harness'
"$q" -e --arg id "$CL" '.records[]|select(.seat=="cl")|.session_id==$id and .mode_args==["--permission-mode","auto"]' "$T/state/recovery-records.json" >/dev/null || fail 'newest used'; ok 'live exact Claude session wins over newer unrelated transcript'
grep -q 'order by\|immutable=1' "$T/sql.log" && fail 'unsafe SQLite query'; ok 'Codex lookup is exact id plus cwd, with live read-only WAL semantics'
[ -r "$T/state/ORG-CHART.last-good.json" ] || fail 'no cached chart'; ok 'chart cached automatically before first outage'
R get cx codex cx-s "$T/cx" > "$T/get" || fail get
"$q" -e --arg id "$CX" '.session_id==$id and .marker=="master"' "$T/get" >/dev/null || fail 'get fields'; ok 'recovery consumes exact saved identity, history and marker'
touch "$T/down"; : > "$T/processes"
R capture > "$T/out" || fail 'capture after crash'
R get cl claude cl-s "$T/cl" > "$T/get" || fail 'lost stopped seat'; ok 'records survive with all harnesses and tmux gone'
mv "$T/chart.json" "$T/chart.saved"
R capture > "$T/out" || fail 'cached chart'; ok 'collector survives loss of upstream org chart'
"$HERE/rescue.sh" --host h --socket test --stagger 0 > "$T/plan" 2>&1 || { cat "$T/plan"; fail 'record-based plan'; }
grep -q "RESUME cx: codex $CX" "$T/plan" && grep -q "RESUME cl: claude $CL" "$T/plan" || fail 'planned ids'; ok 'ordinary recovery plans both saved native sessions after crash'
cp "$T/chart.saved" "$T/chart.json"
# Current native permission changes are read from the SAME saved session, not another transcript.
printf '{"sessionId":"%s","cwd":"%s","permissionMode":"plan"}\n' "$CL" "$T/cl" >> "$T/projects/$enc/$CL.jsonl"
R get cl claude cl-s "$T/cl" > "$T/get" || fail 'current policy'
"$q" -e '.mode_args==["--permission-mode","plan"]' "$T/get" >/dev/null || fail 'stale mode'; ok 'current permissions come from exact native history'
# Prompt text is not native permission metadata.
printf '{"sessionId":"%s","cwd":"%s","message":{"permissionMode":"auto"}}\n' "$CL" "$T/cl" >> "$T/projects/$enc/$CL.jsonl"
R get cl claude cl-s "$T/cl" > "$T/get" || fail 'message text'
"$q" -e '.mode_args==["--permission-mode","plan"]' "$T/get" >/dev/null || fail 'parsed content'; ok 'embedded message fields cannot change recorded mode'
if R get cx codex cx-s "$T/cl" >/dev/null 2>&1; then fail 'cwd mismatch accepted'; fi; ok 'changed chart mapping is refused'
cp "$T/state/recovery-records.json" "$T/good.json"
rm "$T/down"; printf '11 /fake/codex resume --no-daemon %s\n22 /fake/claude --resume %s\n' "$CX" "$CL" > "$T/processes"
touch "$T/wrong-id"
if R capture > "$T/out"; then fail 'bad identity accepted'; fi
if R get cx codex cx-s "$T/cx" >/dev/null 2>&1; then fail 'poisoned mapping usable'; fi
ok 'wrong live identity blocks old records instead of blessing contamination'
touch "$T/down"; : > "$T/processes"
if R capture > "$T/out"; then fail 'prior conflict disappeared'; fi
ok 'an outage cannot silently clear an earlier identity conflict'
rm "$T/wrong-id" "$T/down"; printf '11 /fake/codex resume --no-daemon %s\n22 /fake/claude --resume %s\n' "$CX" "$CL" > "$T/processes"
R capture > "$T/out" || fail 'healthy recapture'; ok 'fresh valid evidence clears a prior conflict'
echo '%11|11|' > "$T/cx-pane"
if R capture > "$T/out"; then fail 'missing marker defaulted'; fi
ok 'missing marker never defaults to master'
echo '%11|11|inactive' > "$T/cx-pane"
R capture > "$T/out" || fail inactive
R get cx codex cx-s "$T/cx" > "$T/get"
"$q" -e '.marker=="inactive"' "$T/get" >/dev/null || fail 'inactive lost'; ok 'inactive marker is retained exactly'
printf '11 /fake/codex resume %s\n22 /fake/claude --resume %s\n' "$CX" "$CL" > "$T/processes"
if R capture > "$T/out"; then fail 'shared daemon accepted'; fi; ok 'known shared-daemon launch is not recorded as healthy'
cp "$T/good.json" "$T/state/recovery-records.json"
touch "$T/ps-fail"; cp "$T/state/recovery-records.json" "$T/before"
if R capture >/dev/null 2>&1; then fail 'ps failure accepted'; fi
cmp "$T/before" "$T/state/recovery-records.json" || fail 'modified on error'; ok 'failed system inspection preserves last committed records'
rm "$T/ps-fail"
mkdir "$T/state/recovery-records.json.lock"
if R capture >/dev/null 2>&1; then fail 'concurrent capture accepted'; fi
cmp "$T/before" "$T/state/recovery-records.json" || fail 'lock mutation'; ok 'concurrent/stale capture lock refuses without overwriting records'
rmdir "$T/state/recovery-records.json.lock"
echo '{broken' > "$T/state/recovery-records.json"
if R get cx codex cx-s "$T/cx" >/dev/null 2>&1; then fail 'corrupt accepted'; fi
if R capture >/dev/null 2>&1; then fail 'corrupt overwritten'; fi
ok 'corrupt records are not replaced or silently rolled back to an older session'
cp "$T/good.json" "$T/state/recovery-records.json"
"$q" '.records[1].session_id=.records[0].session_id' "$T/good.json" > "$T/state/recovery-records.json"
if R status >/dev/null 2>&1; then fail 'duplicate session accepted'; fi; ok 'duplicate native sessions are refused'
cp "$T/good.json" "$T/state/recovery-records.json"
R service > "$T/service"
grep -q '<key>StartInterval</key><integer>30</integer>' "$(cat "$T/service")" || fail 'no interval'
grep -q '<string>capture</string>' "$(cat "$T/service")" || fail 'no collector'
ok 'launchd job generated for automatic finite captures without installing or starting it'
# Unknown seats remain unresolved: no fallback to newest history or guessed marker.
"$q" '.records |= map(select(.seat!="cl"))' "$T/good.json" > "$T/state/recovery-records.json"
touch "$T/down"; : > "$T/processes"
if "$HERE/rescue.sh" --host h --socket test > "$T/plan" 2>&1; then fail 'missing record accepted'; fi
grep -q '^UNRESOLVED cl:' "$T/plan" && grep -q '^RESUME cx:' "$T/plan" || fail 'missing record reporting'; ok 'missing record is named while other dead seats remain independently resumable'
# Inspect the apply branch with stubbed launch/proof functions to establish no stop operations.
# The actual records-based plan above is exercised separately; no host scripts are sourced.
block=$(sed -n '/^stopped=1/,/^if \[ \$APPLY -eq 1 \] \&\& \[ \$resumed -gt 0 \]; then/{ /^if \[ \$APPLY -eq 1 \] \&\& \[ \$resumed -gt 0 \]; then/!p; }' "$HERE/rescue.sh")
setup='APPLY=1; RESEAT=0; unresolved=0; failed=0; resumed=0; STAGGER=0; live=0; ok=0; running=0; resume=1; reseat=0; STATE=/tmp; TMUX_BIN=true; SOCKET=test; LAUNCHED_PANE=%11
P_SEAT=(cx); P_PANE=(%11); P_CWD=(/tmp); P_SID=(id); P_HARNESS=(codex); P_ROLL=(file); P_MODE=(mode); P_WHY=(why); P_SESS=(session); P_MARK=(master)
stop_seat() { echo BAD_STOP; }; stop_daemon() { echo BAD_DAEMON; }; holds() { return 1; }; rollout_free() { return 0; }; launch() { echo LAUNCH; }; prove_codex() { return 0; }'
result=$(bash -c "set -uo pipefail; $setup
$block") || fail 'apply branch'
grep -q 'BAD_STOP\|BAD_DAEMON' <<< "$result" && fail 'crash recovery stops live work'
grep -q LAUNCH <<< "$result" || fail 'no launch'; ok 'ordinary crash recovery has no stop-seat or stop-daemon phase'
cp "$T/good.json" "$T/state/recovery-records.json"
rm -f "$T/launch" "$T/kills"; : > "$T/tmux.log"
for seat in cx cl; do
  cp "$T/good.json" "$T/state/recovery-records.json"
  rm -f "$T/launch"
  "$HERE/rescue.sh" --apply --host h --socket test --seat "$seat" --stagger 0 > "$T/apply-$seat" 2>&1 || { cat "$T/apply-$seat"; fail "$seat apply"; }
  grep -q "RESUMED $seat:" "$T/apply-$seat" || fail 'not resumed'
  [ ! -e "$T/kills" ] || fail 'recovery called kill'
  ok "actual recovery entrypoint resumes saved $seat history with fake harness proof and no daemon stop"
done
cp "$T/good.json" "$T/state/recovery-records.json"
rm -f "$T/launch"; touch "$T/holder"; : > "$T/tmux.log"
if "$HERE/rescue.sh" --apply --host h --socket test --seat cl > "$T/held" 2>&1; then fail 'held Claude transcript accepted'; fi
grep -q 'new-session' "$T/tmux.log" && fail 'started alongside history holder'
ok 'Claude transcript holder blocks launch just like Codex rollout holder'
rm "$T/holder"
rm "$T/down"; printf '11 /fake/codex --no-daemon\n22 /fake/claude --resume %s\n' "$CL" > "$T/processes"
echo '%11|11|master' > "$T/cx-pane"; touch "$T/fd-mode"
R capture > "$T/out" || { cat "$T/out"; fail 'descriptor mapping'; }
R get cx codex cx-s "$T/cx" > "$T/get"
"$q" -e '.source=="native-history-file-descriptor"' "$T/get" >/dev/null || fail 'descriptor source'
ok 'new CLI without a session in argv can be mapped by its exact open native history'
setup2='APPLY=1; RESEAT=0; unresolved=0; failed=0; resumed=0; STAGGER=0; live=0; ok=0; running=0; resume=2; reseat=0; STATE=/tmp; TMUX_BIN=tm; SOCKET=test; LAUNCHED_PANE=%11
P_SEAT=(one two); P_PANE=("" ""); P_CWD=(/tmp /tmp); P_SID=(id1 id2); P_HARNESS=(codex codex); P_ROLL=(f1 f2); P_MODE=(mode mode); P_WHY=(why why); P_SESS=(s1 s2); P_MARK=(master master)
holds() { return 1; }; rollout_free() { return 0; }; launch() { echo "LAUNCH $1"; }; prove_codex() { echo "PROOF $1"; }; tm() { echo VERIFIED; }'
result=$(bash -c "set -uo pipefail; $setup2
$block") || fail 'every-seat proof loop'
[ "$(grep -c '^PROOF ' <<< "$result")" = 2 ] && [ "$(grep -c '^VERIFIED$' <<< "$result")" = 2 ] || fail 'only first seat proved'
ok 'every resumed seat is proved before receiving its verified rescue mark'
rm -f "$T/fd-mode"
printf '11 /fake/claude --resume %s\n22 /fake/claude --resume %s\n' "$CX" "$CL" > "$T/processes"
if R capture > "$T/out"; then fail 'wrong live harness treated as down'; fi
if R get cx codex cx-s "$T/cx" >/dev/null 2>&1; then fail 'stale mapping after harness conflict'; fi
ok 'an existing pane with the wrong or unverifiable harness blocks the saved mapping'

# Added at integration, from what the real host showed.
mkdir -p "$T/.claude/sessions"
LOCK=$T/state/recovery-records.json.lock
normal() { printf '11 /fake/codex resume --no-daemon %s\n22 /fake/claude --resume %s\n' "$CX" "$CL" > "$T/processes"; }
reset_fixture() { rm -f "$T/down" "$T/wrong-id" "$T/fd-mode" "$T/launch" "$T/holder" "$T/ps-fail" "$T/.claude/sessions/"*.json; rm -rf "$LOCK"; normal; echo '%11|11|master' > "$T/cx-pane"; cp "$T/good.json" "$T/state/recovery-records.json"; cp "$T/chart.saved" "$T/chart.json"; }
reset_fixture
mkdir "$LOCK"; echo 999999 > "$LOCK/pid"
R capture > "$T/out" 2>"$T/err" || fail 'dead lock'; [ ! -d "$LOCK" ] && grep -q 'took over' "$T/err" || fail 'dead lock left'; ok 'a capture killed by a teardown does not stop every later capture'
mkdir "$LOCK"; echo $$ > "$LOCK/pid"
if R capture >/dev/null 2>&1; then fail 'live lock ignored'; fi; [ -d "$LOCK" ] || fail 'live lock removed'; ok 'a running capture keeps its lock'
rm -rf "$LOCK"; mkdir "$LOCK"; touch -t 202601010000 "$LOCK"
R capture >/dev/null 2>&1 || fail 'old pidless lock'; ok 'an old lock with no owner is taken over'
reset_fixture
printf '{"pid":22,"sessionId":"%s","cwd":"%s"}' "$NEW" "$T/cl" > "$T/.claude/sessions/22.json"
printf '11 /fake/codex resume --no-daemon %s\n22 /fake/claude\n' "$CX" > "$T/processes"
R capture > "$T/out" || fail 'native map'
"$q" -e --arg id "$NEW" '.records[]|select(.seat=="cl")|.session_id==$id and .source=="native-pid-session"' "$T/state/recovery-records.json" >/dev/null || fail 'native id'; ok 'a Claude session with nothing in argv is named by its pid file'
normal; R capture > "$T/out" || fail 'native over argv'
"$q" -e --arg id "$NEW" '.records[]|select(.seat=="cl")|.session_id==$id' "$T/state/recovery-records.json" >/dev/null || fail 'stale argv won'; ok 'the pid file beats a stale --resume in argv'
reset_fixture
"$q" '.seats += [{seat_id:"bad",mailbox:"bad",desired_host:"h",desired_agent:"codex",desired_folder:"/x",desired_tmux:null}]' "$T/chart.saved" > "$T/chart.json"
if R capture > "$T/out" 2>&1; then fail 'bad row hidden'; fi
"$q" -e '(.records|length)==2 and any(.issues[]; .seat=="bad" and .blocking)' "$T/state/recovery-records.json" >/dev/null || fail 'bad row'; ok 'one bad chart row blocks only its own seat'
reset_fixture
"$q" '.seats |= map(select(.seat_id=="cl"))' "$T/chart.saved" > "$T/chart.json"
R capture > "$T/out" || fail 'shrunken chart'; R capture > "$T/out" || fail 'shrunken chart 2'
R get cx codex cx-s "$T/cx" > "$T/get" || fail 'mapping lost'
"$q" -e 'any(.issues[]; .seat=="cx" and (.blocking|not))' "$T/state/recovery-records.json" >/dev/null || fail 'no note'; ok 'a chart that loses a seat does not erase its mapping'
reset_fixture
"$q" --arg id "$CX" '.records |= (map(select(.seat=="cl")) + [{seat:"zz",mailbox:"zz",harness:"codex",tmux_session:"zz-s",cwd:"/z",session_id:$id,marker:"master"}])' "$T/good.json" > "$T/state/recovery-records.json"
if R capture > "$T/out" 2>/dev/null; then fail 'duplicate hidden'; fi
"$q" -e '(.records|map(.seat))==["cl"] and ([.issues[]|select(.blocking)|.seat]|sort)==["cx","zz"]' "$T/state/recovery-records.json" >/dev/null || fail 'duplicate scope'
R get cl claude cl-s "$T/cl" > "$T/get" || fail 'bystander blocked'; ok 'a duplicate session blocks the two seats that share it, not the org'
reset_fixture; R capture > "$T/out"
R health > "$T/out" || fail 'fresh'; grep -q '^records: fresh' "$T/out" || fail 'fresh words'; ok 'health passes a fresh, clear cache'
"$q" '.generated_at="2020-01-01T00:00:00Z"' "$T/state/recovery-records.json" > "$T/stale"; cp "$T/stale" "$T/state/recovery-records.json"
rc=0; R health > "$T/out" || rc=$?; [ $rc -eq 1 ] && grep -q '^records: STALE' "$T/out" || fail 'stale'; ok 'health fails a collector that stopped'
reset_fixture; R capture > "$T/out"; "$q" '.issues=[{seat:"cx",blocking:true,reason:"r"}]' "$T/state/recovery-records.json" > "$T/blocked"; cp "$T/blocked" "$T/state/recovery-records.json"
rc=0; R health > "$T/out" || rc=$?; [ $rc -eq 3 ] && grep -q '^BLOCKED 1 seats: r' "$T/out" || fail 'blocked'; ok 'health names blocked seats'
echo '{broken' > "$T/state/recovery-records.json"; rc=0; R health > "$T/out" || rc=$?; [ $rc -eq 1 ] && grep -q UNUSABLE "$T/out" || fail 'unusable'; ok 'health fails a corrupt cache'
reset_fixture
"$q" '.records |= map(select(.seat!="cl")) | .issues=[{seat:"cl",blocking:true,reason:"pane has no recorded marker"}]' "$T/good.json" > "$T/state/recovery-records.json"
touch "$T/down"; : > "$T/processes"
printf 'cl master %s\n' "$CL" > "$T/seed"
if "$HERE/rescue.sh" --host h --socket test > "$T/plan" 2>&1; then fail 'no seed resolved'; fi; grep -q '^UNRESOLVED cl:' "$T/plan" || fail 'no seed'
"$HERE/rescue.sh" --host h --socket test --seed "$T/seed" > "$T/plan" 2>&1 || { cat "$T/plan"; fail 'seed plan'; }
grep -q "^RESUME cl: claude $CL (--permission-mode .*marker master, seed file)" "$T/plan" || { cat "$T/plan"; fail 'seed plan line'; }; ok 'a reviewed seed plans a seat with no record, in that seat own recorded mode'
printf 'cl master %s\n' 99999999-9999-4999-8999-999999999999 > "$T/seed"
if "$HERE/rescue.sh" --host h --socket test --seed "$T/seed" > "$T/plan" 2>&1; then fail 'bad seed'; fi; grep -q '^UNRESOLVED cl: seed does not match' "$T/plan" || fail 'bad seed words'; ok 'a seed that native history does not back is refused'
printf 'cl owner %s\n' "$CL" > "$T/seed"
if "$HERE/rescue.sh" --host h --socket test --seed "$T/seed" > "$T/plan" 2>&1; then fail 'bad marker'; fi; ok 'a seed cannot invent a marker'
reset_fixture; touch "$T/down"; : > "$T/processes"; printf 'cl master %s\n' "$NEW" > "$T/seed"
if "$HERE/rescue.sh" --host h --socket test --seed "$T/seed" > "$T/plan" 2>&1; then fail 'conflict'; fi; grep -q '^UNRESOLVED cl: seed session conflicts' "$T/plan" || { cat "$T/plan"; fail 'conflict words'; }; ok 'a seed that disagrees with a captured record is refused, and the record stands'
reset_fixture
holds_fn=$(sed -n '/^holds()/,/^}/p' "$HERE/rescue.sh")
printf '{"pid":22,"sessionId":"%s"}' "$NEW" > "$T/.claude/sessions/22.json"
printf '22 /fake/claude\n' > "$T/processes"
hold() { rc=0; bash -c "set -uo pipefail
$holds_fn
PS_BIN='$T/bin/ps'; CLAUDE_SESSIONS='$T/.claude/sessions'; holds $NEW" || rc=$?; echo $rc; }
[ "$(hold)" = 0 ] || fail 'file holder missed'; printf '22 /bin/sleep 100\n' > "$T/processes"; [ "$(hold)" = 1 ] || fail 'reused pid held'; : > "$T/processes"; [ "$(hold)" = 1 ] || fail 'dead pid held'
ok 'a Claude session open only in the pid file counts as held, and a dead or reused pid does not'
reset_fixture
touch "$T/hot"; touch -t 202601010000 "$T/cold"
work=$(bash -c "set -uo pipefail
$(sed -n '/^children()/,/^}/p;/^work_list()/,/^}/p' "$HERE/rescue.sh")
PS_BIN='$T/bin/ps'; TMUX_BIN=true; SOCKET=t; LSOF=true; WORK_WINDOW=60
P_SEAT=(hot cold); P_PANE=(%1 %2); P_PID=(1 2); P_ROLL=('$T/hot' '$T/cold')
work_list")
grep -q '^WORK hot: its history was written' <<< "$work" && ! grep -q '^WORK cold' <<< "$work" && grep -q '^work: 1 of 2' <<< "$work" || { echo "$work"; fail 'history age'; }; ok 'running work is seen from history being written, whatever the harness prints'
echo "PASS: $n record/recovery checks"
