#!/bin/bash
# zeo-rescue: a Claude seat moving folder, as it really happens, without touching a seat. Usage: claude-move.sh SESSION TRANSCRIPT [PORT]
# The seat runs in its old folder on the version seats run today. Its folder is renamed under it, so the old path is gone, and it takes a turn there.
# Then the operator's own steps run, on a copy of the real scripts: claude-trust with the seat still live, claude-first on the installed version, claude-clear.
# The copy differs in its socket, host, seat and folders. It has no pins, because it is a copy. It uses the real seat loader and Claude binaries, on a clone of a
# real transcript with its session id and folder rewritten. Private tmux socket and config; the API is a local listener. Nothing leaves this machine.
# KEEP=1 keeps the working folder, which holds a copy of the transcript. RUNNING=x.y.z names the version the seat starts on.
set -uo pipefail
orig=$1 src0=$2 port=${3:-39031} sid=ffffffff${orig:8}; HERE=$(cd "$(dirname "$0")" && pwd -P); R0=$(dirname "$HERE")
INSTALLED=$("$HOME/.local/bin/claude" --version | awk 'NR==1 {print $1}'); RUNNING=${RUNNING:-2.1.318}; TM=/opt/homebrew/bin/tmux; S=rf$$
[ -x "$HOME/.local/share/claude/versions/$RUNNING" ] || { echo "NO BINARY for $RUNNING: this proves nothing"; exit 1; }
real_before=$("$TM" -L zeo2 list-panes -a -F '#{pane_pid}' 2>/dev/null | sort | /usr/bin/shasum | cut -c1-12)
P=$(mktemp -d "${TMPDIR:-/tmp}/rf.XXXXXX"); P=$(cd "$P" && pwd -P); OLD=$P/w/old; NEW=$P/w/repo/main
mkdir -p "$OLD" "$(dirname "$NEW")" "$P/cfg/projects" "$P/home" "$P/cap" "$P/state" "$P/run/notes"; git -C "$OLD" init -q
key() { printf %s "$1" | LC_ALL=C sed 's/[^A-Za-z0-9]/-/g'; }
oe=$P/cfg/projects/$(key "$OLD"); ne=$P/cfg/projects/$(key "$NEW"); mkdir -p "$oe/memory" "$oe/$sid/subagents"
was=$(tail -n 2000 "$src0" | jq -r 'select(.cwd) | .cwd' 2>/dev/null | tail -1); [ -n "$was" ] || { echo "NO FOLDER in the transcript: this proves nothing"; exit 1; }
LC_ALL=C sed -e "s/$orig/$sid/g" -e "s#$was#$OLD#g" "$src0" > "$oe/$sid.jsonl"; b=$(stat -f %z "$oe/$sid.jsonl"); echo x > "$oe/$sid/subagents/keep.txt"
printf -- '- [marker](marker.md) — ZEOTOKEN-MEMORY-SEEN\n' > "$oe/memory/MEMORY.md"; echo x > "$oe/memory/marker.md"; printf '{"sessionId":"other"}\n' > "$oe/11111111-2222-4333-8444-555555555555.jsonl"
k=sk-ant-not-a-real-key
jq -n --arg o "$OLD" --arg k "${k: -20}" --arg v "$INSTALLED" '{hasCompletedOnboarding:true,lastOnboardingVersion:$v,customApiKeyResponses:{approved:[$k],rejected:[]},projects:{($o):{hasTrustDialogAccepted:true}}}' > "$P/cfg/.claude.json"; chmod 600 "$P/cfg/.claude.json"
echo "$HOME/.local/share/claude/versions/$RUNNING" > "$P/use"
cat > "$P/claude" <<W
#!/bin/sh
exec env HOME="$P/home" CLAUDE_CONFIG_DIR="$P/cfg" ANTHROPIC_API_KEY=$k ANTHROPIC_BASE_URL=http://127.0.0.1:$port DISABLE_TELEMETRY=1 DISABLE_ERROR_REPORTING=1 DISABLE_AUTOUPDATER=1 CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC=1 "\$(cat "$P/use")" "\$@"
W
chmod +x "$P/claude"
# The copy of the operator's scripts. It must not be able to reach the org's socket, so that is checked before anything starts.
cp "$R0/seat-exec.sh" "$R0/Makefile" "$P/run/"; cp "$R0/notes/claude-move-20261106.txt" "$P/run/notes/"
sed -e "s/^SOCKET=zeo2 HOST_NAME=matormini /SOCKET=$S HOST_NAME=h /" "$R0/rescue.sh" > "$P/run/rescue.sh"
sed -e '/^pin [0-9a-f]\{64\} /d' -e "s/-L zeo2/-L $S/g" -e 's/^CLAUDE_SEAT=.*/CLAUDE_SEAT=rc/' -e "s#^CLAUDE_OLD=.*#CLAUDE_OLD=$OLD#" -e "s#^CLAUDE_NEW=.*#CLAUDE_NEW=$NEW#" "$R0/reseat-lines.sh" > "$P/run/reseat-lines.sh"
chmod +x "$P/run/rescue.sh" "$P/run/reseat-lines.sh"
[ "$(cat "$P/run/rescue.sh" "$P/run/reseat-lines.sh" | /usr/bin/grep -c zeo2)" = 0 ] || { echo "THE COPY CAN REACH THE ORG: stopped before anything started"; exit 1; }
printf '{"seats":[{"seat_id":"rc","mailbox":"rc","desired_agent":"claude","desired_host":"h","desired_tmux":{"session":"rc-s"},"desired_folder":"%s"}]}' "$OLD" > "$P/chart.json"
echo "rc $sid" > "$P/run/session-pins"; : > "$P/run/folder-moves"
# The kill that stops a shared Codex daemon is a stub that only writes down what it was asked (the Architect, 9 Nov 11:28Z): a rehearsal stops no real daemon.
printf '#!/bin/sh\necho "$*" >> "%s/kills"\n' "$P" > "$P/nokill"; chmod +x "$P/nokill"
export ZEO_RESCUE_KILL=$P/nokill ZEO_RESCUE_CHART=$P/chart.json ZEO_RESCUE_STATE=$P/state STATE=$P/state ZEO_RESCUE_PROJECTS=$P/cfg/projects ZEO_RESCUE_CLAUDE=$P/claude ZEO_RESCUE_CLAUDE_JSON=$P/cfg/.claude.json ZEO_RESCUE_PROOF_TRIES=40 ZEO_RESCUE_PROOF_PAUSE=1
R() { "$P/run/rescue.sh" "$@"; }; L() { "$P/run/reseat-lines.sh" "$@"; }
clean() { kill "$L" 2>/dev/null; "$TM" -L "$S" kill-server 2>/dev/null; if [ -z "${KEEP:-}" ]; then rm -rf "$P"; else echo "kept in $P: it holds a copy of the transcript, so delete it when you are done"; fi; }
perl "$HERE/capture.pl" "$port" "$P/cap" & L=$!; trap clean EXIT; perl -e 'select(undef,undef,undef,0.4)'
tail -n 4000 "$oe/$sid.jsonl" | jq -r 'select(.type=="assistant") | .message.content[]? | select(.type=="text") | .text' 2>/dev/null | /usr/bin/grep -v '^$' | tail -1 | cut -c1-48 > "$P/lastwords"
[ -s "$P/lastwords" ] || { echo "NO LAST WORDS: this proves nothing"; exit 1; }
show() { sed "s#$P#<P>#g" | cut -c1-140; }
newest() { ls "$P/cap" | sed -n 's/^req\.//p' | sort -n | tail -1; }
pane() { "$TM" -L "$S" list-panes -t '=rc-s' -F "$1"; }
echo "== transcript $b bytes; the seat starts in its old folder on $RUNNING"
R --apply 2>&1 | /usr/bin/grep -E '^(FIRST SEAT OK|STOPPED|FAILED|rescue:)' | show
perl -e 'select(undef,undef,undef,6)'; pid=$(pane '#{pane_pid}'); printf 'running %s, pid %s\n' "$(pane '#{pane_current_command}')" "$pid"
echo "== its folder is renamed under it, and it takes a turn there, as a mail wake would"
mv "$OLD" "$NEW"; printf 'old folder there: %s; the pane reads: %s\n' "$([ -e "$OLD" ] && echo YES || echo no)" "$(pane '#{pane_current_path}' | show)"
"$TM" -L "$S" send-keys -t '=rc-s:' -l 'a wake arrives after the rename'; "$TM" -L "$S" send-keys -t '=rc-s:' Enter; perl -e 'select(undef,undef,undef,8)'
[ "$(pane '#{pane_pid}')" = "$pid" ] && echo "the same process is still up" || echo "IT DIED under the rename"
printf 'old project there: %s; a new project made by it: %s\n' "$([ -d "$oe" ] && echo yes || echo NO)" "$([ -e "$ne" ] && echo YES || echo no)"
echo "== the line goes in; the seat is still live and not trusted there"
echo "rc $NEW" > "$P/run/folder-moves"; echo "$HOME/.local/bin/claude" > "$P/use"
R --check 2>&1 | /usr/bin/grep -E '^(OK|WRONG)' | show
L claude-first 2>&1 | /usr/bin/grep -E '^(the Claude|VERSION|UNRESOLVED|RESUMED|MOVED OK)' | show
[ "$(pane '#{pane_pid}')" = "$pid" ] && echo "without trust it refuses, and the seat is left alone" || echo "IT WAS STOPPED WITHOUT TRUST"
echo "== claude-trust, with the seat live"
L claude-trust 2>&1 | show
printf 'backup mode %s; config mode %s\n' "$(stat -f %Lp "$P/state/claude-json.before-20261106")" "$(stat -f %Lp "$P/cfg/.claude.json")"
L claude-trust 2>&1 | /usr/bin/grep -E '^(NOTHING|ADDED|REFUSED)' | show
c0=$(/usr/bin/shasum -a 256 "$P/cfg/.claude.json"); "$TM" -L "$S" send-keys -t '=rc-s:' -l 'a second wake, after the trust entry'; "$TM" -L "$S" send-keys -t '=rc-s:' Enter; perl -e 'select(undef,undef,undef,8)'
printf 'the live process, started before the entry, rewrote the file in a turn: %s; entry still there: %s\n' "$([ "$c0" = "$(/usr/bin/shasum -a 256 "$P/cfg/.claude.json")" ] && echo no || echo yes)" "$(jq -r --arg d "$NEW" '.projects[$d].hasTrustDialogAccepted' "$P/cfg/.claude.json")"
b2=$(stat -f %z "$oe/$sid.jsonl"); before=$(newest)
echo "== claude-first: the old process exits, the project moves, the installed version resumes"
s=$(perl -MTime::HiRes -e 'print Time::HiRes::time()')
L claude-first 2>&1 | /usr/bin/grep -E '^(the Claude|claude |VERSION|RESEAT|MOVE|RESUMED|FIRST SEAT OK|MOVED OK|NOTE|STOPPED|FAILED|UNRESOLVED|RECOVERY|OK|WRONG|check:|rescue:)' | show
e=$(perl -MTime::HiRes -e 'print Time::HiRes::time()'); perl -e 'printf "seconds through the move: %.1f\n", $ARGV[1]-$ARGV[0]' "$s" "$e"
perl -e 'select(undef,undef,undef,6)'
printf 'running %s, pid %s; trust entry after the old process wrote its last: %s\n' "$(pane '#{pane_current_command}')" "$(pane '#{pane_pid}')" "$(jq -r --arg d "$NEW" '.projects[$d].hasTrustDialogAccepted' "$P/cfg/.claude.json")"
R --check 2>&1 | /usr/bin/grep -E '^(OK|WRONG|check:)' | show
echo "== what the model would receive after the move"
last=""; for f in "$P"/cap/req.*; do n=${f##*.}; [ "$n" -gt "${before:-0}" ] || continue; if [ -z "$last" ] || [ "$(stat -f %z "$f")" -gt "$(stat -f %z "$last")" ]; then last=$f; fi; done
[ -n "$last" ] || { echo "NO REQUEST AFTER THE MOVE: this proves nothing"; exit 1; }
jq -r '"messages=\(.messages|length)"' "$last"; printf 'memory token: '; LC_ALL=C /usr/bin/fgrep -c ZEOTOKEN-MEMORY-SEEN "$last"
jq -r '[.messages[]|.content|if type=="array" then map(.text//"")|join(" ") else . end]|join(" ")' "$last" > "$P/all.txt"; printf 'last words [%s] found: ' "$(cat "$P/lastwords")"; LC_ALL=C /usr/bin/grep -oF -f "$P/lastwords" "$P/all.txt" | wc -l | tr -d ' '
printf 'the note reached it: '; LC_ALL=C /usr/bin/grep -c 'planned move of your working folder' "$P/all.txt"
printf 'the turn after the rename reached it: '; LC_ALL=C /usr/bin/grep -c 'a wake arrives after the rename' "$P/all.txt"
echo "== on disk"
printf 'old project gone: '; [ -e "$oe" ] && echo NO || echo yes
printf 'transcripts for the session: %s; new project grew by %s\n' "$(find "$P/cfg/projects" -maxdepth 2 -name "$sid.jsonl" | wc -l | tr -d ' ')" "$(( $(stat -f %z "$ne/$sid.jsonl") - b2 ))"
printf 'came with it: memory=%s subagent=%s other session=%s\n' "$(ls "$ne/memory" | wc -l | tr -d ' ')" "$(ls "$ne/$sid/subagents" | wc -l | tr -d ' ')" "$(ls "$ne" | /usr/bin/grep -c '^11111111')"
printf 'top-level sessions in the new project: '; ls "$ne"/*.jsonl | wc -l | tr -d ' '
tail -c +$((b2+1)) "$ne/$sid.jsonl" | jq -r 'select(.cwd) | [.sessionId,.cwd]|@tsv' 2>/dev/null | show | sort | uniq -c | head -4
echo "== a proof that stopped leaves the seat like this: the same line brings it back, forward, with the old folder gone"
id=$(pane '#{pane_id}'); "$TM" -L "$S" respawn-pane -k -t "$id" -c "$NEW" -- sleep 3600; "$TM" -L "$S" set-option -pu -t "$id" @zeo_rescue; perl -e 'select(undef,undef,undef,2)'
L claude-first 2>&1 | /usr/bin/grep -E '^(MOVED OK|STOPPED|FAILED|UNRESOLVED|check:)' | show
perl -e 'select(undef,undef,undef,4)'
echo "== claude-clear, a second run, then a crash"
L claude-clear 2>&1 | show; printf 'backup there: %s\n' "$([ -e "$P/state/claude-json.before-20261106" ] && echo YES || echo no)"
R --reseat --relaunch 2>&1 | /usr/bin/grep -E '^(OK|RESEAT)' | show
"$TM" -L "$S" kill-session -t '=rc-s'; perl -e 'select(undef,undef,undef,1)'
R 2>&1 | /usr/bin/grep -E '^(RESUME|MOVE|UNRESOLVED)' | show
real_after=$("$TM" -L zeo2 list-panes -a -F '#{pane_pid}' 2>/dev/null | sort | /usr/bin/shasum | cut -c1-12)
[ "$real_before" = "$real_after" ] && echo "the org's panes are the same as before this ran" || echo "THE ORG'S PANES CHANGED while this ran: read why"
