#!/bin/bash
# zeo-rescue: the ducktyper-ops move rehearsed in its exact shape, without touching the seat. Usage: ops-move.sh [PORT]
# A copy of the seat's real transcript (session id and folder rewritten), its tool results and its real memory, under the key of an empty
# folder like its own; private folder, config and tmux socket; the API is a local listener. The seat starts there on the version it runs today,
# by the copy of rescue.sh. Then the operator's own steps run, on copies of the real scripts: ops-folder with the seat live, claude-trust,
# claude-first on the installed version, ops-old, claude-clear. The seat is named rdo in the copies, so nothing runs as ducktyper-ops, and the
# copies refuse to start if they could reach zeo2 or a real folder. Nothing leaves this machine. KEEP=1 keeps the working folder.
set -uo pipefail
port=${1:-39081}; HERE=$(cd "$(dirname "$0")" && pwd -P); R0=$(dirname "$HERE")
orig=ca076ba8-7fee-46f0-853b-8182adc3c975 sid=ffffffff-7fee-46f0-853b-8182adc3c975
RO=/Volumes/AIPEMedia1/code/zeroemployeeorg/ducktyper-ops RN=/Volumes/AIPEMedia1/code/ducktyper-ai/ducktyper-ops
key() { printf %s "$1" | LC_ALL=C sed 's/[^A-Za-z0-9]/-/g'; }
RP=$HOME/.claude/projects/$(key "$RO") TM=/opt/homebrew/bin/tmux S=rdo$$
INSTALLED=$("$HOME/.local/bin/claude" --version | awk 'NR==1 {print $1}'); RUNNING=${RUNNING:-2.1.318}
[ -x "$HOME/.local/share/claude/versions/$RUNNING" ] || { echo "NO BINARY for $RUNNING: this proves nothing"; exit 1; }
real() { # the real seat as this read it: it must read the same at the end
  "$TM" -L zeo2 list-panes -a -F '#{pane_pid}' 2>/dev/null | sort | /usr/bin/shasum | cut -c1-12
  stat -f '%i' "$RO"; ls -A "$RO" | wc -l; [ -e "$RN" ] && echo "new folder there" || echo "no new folder"
  find "$RP/memory" -type f -exec stat -f "%N %z %m" {} + | LC_ALL=C sort | shasum
  ls "$HOME/.claude/projects" | grep -c -e 'ducktyper-ai-ducktyper-ops'; ls "$HOME/.local/state/zeo-rescue" | grep -c ops-move
}
real_before=$(real)
P=$(mktemp -d "${TMPDIR:-/tmp}/rdo.XXXXXX"); P=$(cd "$P" && pwd -P); OLD=$P/w/org/ducktyper-ops NEW=$P/w/dt/ducktyper-ops
clean() { kill "$L" 2>/dev/null; "$TM" -L "$S" kill-server 2>/dev/null; if [ -z "${KEEP:-}" ]; then rm -rf "$P"; else echo "kept in $P: it holds a copy of the transcript, so delete it when you are done"; fi; }
L=""; trap clean EXIT
show() { sed -e "s#$(key "$P")#<P>#g" -e "s#$P#<P>#g" | cut -c1-150; }
echo "== the shape, copied read-only"
mkdir -p "$OLD" "$P/w/dt" "$P/cfg/projects" "$P/home" "$P/cap" "$P/state" "$P/run/notes"
[ -z "$(ls -A "$RO")" ] && ! git -C "$RO" rev-parse --git-dir >/dev/null 2>&1 || { echo "THE REAL FOLDER IS NOT EMPTY, OR IN GIT: this proves nothing"; exit 1; }
oe=$P/cfg/projects/$(key "$OLD"); ne=$P/cfg/projects/$(key "$NEW"); mkdir -p "$oe"
was=$(tail -n 2000 "$RP/$orig.jsonl" | jq -r 'select(.cwd) | .cwd' 2>/dev/null | tail -1); [ "$was" = "$RO" ] || { echo "THE TRANSCRIPT'S FOLDER IS ${was:-none}: this proves nothing"; exit 1; }
LC_ALL=C sed -e "s/$orig/$sid/g" -e "s#$RO#$OLD#g" "$RP/$orig.jsonl" > "$oe/$sid.jsonl"; [ ! -d "$RP/$orig" ] || cp -Rp "$RP/$orig" "$oe/$sid"
cp -Rp "$RP/memory" "$oe/memory"; nmem=$(find "$oe/memory" -type f | wc -l | tr -d ' ')
tok=ZEOTOKEN-MEMORY-SEEN-$$; printf -- '- [rehearsal marker](rehearsal-marker.md) — %s\n' "$tok" >> "$oe/memory/MEMORY.md"
words=$(awk -F'"' '/^CLAUDE_PROOF=/ {print $2}' "$R0/reseat-lines.sh")
LC_ALL=C grep -qF -e "$words" "$oe/$sid.jsonl" && { echo "THE TRANSCRIPT ALREADY HOLDS THE NOTE: this proves nothing"; exit 1; }
LC_ALL=C grep -qF -e "$tok" "$oe/$sid.jsonl" && { echo "THE TRANSCRIPT ALREADY HOLDS THE MARKER: this proves nothing"; exit 1; }
echo "transcript $(stat -f %z "$oe/$sid.jsonl") bytes; memory $nmem files; its saved prompt names: $(LC_ALL=C grep -ao 'file-based memory at `[^`]*`' "$oe/$sid.jsonl" | tail -1 | show)"
k=sk-ant-not-a-real-key
jq -n --arg o "$OLD" --arg k "${k: -20}" --arg v "$INSTALLED" '{hasCompletedOnboarding:true,lastOnboardingVersion:$v,customApiKeyResponses:{approved:[$k],rejected:[]},projects:{($o):{hasTrustDialogAccepted:true}}}' > "$P/cfg/.claude.json"; chmod 600 "$P/cfg/.claude.json"
echo "$HOME/.local/share/claude/versions/$RUNNING" > "$P/use"
cat > "$P/claude" <<W
#!/bin/sh
exec env HOME="$P/home" CLAUDE_CONFIG_DIR="$P/cfg" ANTHROPIC_API_KEY=$k ANTHROPIC_BASE_URL=http://127.0.0.1:$port DISABLE_TELEMETRY=1 DISABLE_ERROR_REPORTING=1 DISABLE_AUTOUPDATER=1 CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC=1 "\$(cat "$P/use")" "\$@"
W
chmod +x "$P/claude"
# The copies of the operator's scripts: the seat is rdo, the socket and folders private; checked before anything starts.
cp "$R0/seat-exec.sh" "$R0/Makefile" "$P/run/"; cp "$R0/notes/claude-move-ducktyper-ops-20261108.txt" "$P/run/notes/"
sed -e "s/^SOCKET=zeo2 HOST_NAME=matormini /SOCKET=$S HOST_NAME=h /" "$R0/rescue.sh" > "$P/run/rescue.sh"
sed -e '/^pin [0-9a-f]\{64\} /d' -e "s/-L zeo2/-L $S/g" -e 's/^CLAUDE_SEAT=.*/CLAUDE_SEAT=rdo/' -e "s#^CLAUDE_OLD=.*#CLAUDE_OLD=$OLD#" -e "s#^CLAUDE_NEW=.*#CLAUDE_NEW=$NEW#" "$R0/reseat-lines.sh" > "$P/run/reseat-lines.sh"
sed -e 's/^  ducktyper-ops) /  rdo) /' -e "s/^SOCKET=.*/SOCKET=$S/" -e 's/^    TSESS=.*/    TSESS=rdo-s/' -e "s/^    SESSION_ID=.*/    SESSION_ID=$sid/" -e "s#^    OLD=.*#    OLD=$OLD#" -e "s#^    NEW=.*#    NEW=$NEW#" \
  -e "s/^    OLD_INODE=.*/    OLD_INODE=$(stat -f %i "$OLD");;/" "$R0/ops-move.sh" > "$P/run/ops-move.sh"
chmod +x "$P/run/rescue.sh" "$P/run/reseat-lines.sh" "$P/run/ops-move.sh"
[ "$(cat "$P/run/rescue.sh" "$P/run/reseat-lines.sh" "$P/run/ops-move.sh" | grep -c zeo2)" = 0 ] && ! grep -E '^ *(OLD|NEW|CLAUDE_OLD|CLAUDE_NEW)=/Volumes' "$P/run/ops-move.sh" "$P/run/reseat-lines.sh" >/dev/null \
  && [ "$(grep -c '^  rdo) ' "$P/run/ops-move.sh")" = 1 ] && [ "$(grep -c '^CLAUDE_SEAT=rdo$' "$P/run/reseat-lines.sh")" = 1 ] || { echo "THE COPY CAN REACH THE ORG OR A REAL FOLDER: stopped before anything started"; exit 1; }
printf '{"seats":[{"seat_id":"rdo","mailbox":"rdo","desired_agent":"claude","desired_host":"h","desired_tmux":{"session":"rdo-s"},"desired_folder":"%s"}]}' "$OLD" > "$P/chart.json"
echo "rdo $sid" > "$P/run/session-pins"; : > "$P/run/folder-moves"
# The kill that stops a shared Codex daemon is a stub that only writes down what it was asked (the Architect, 9 Nov 11:28Z): a rehearsal stops no real daemon.
printf '#!/bin/sh\necho "$*" >> "%s/kills"\n' "$P" > "$P/nokill"; chmod +x "$P/nokill"
export ZEO_RESCUE_KILL=$P/nokill ZEO_RESCUE_CHART=$P/chart.json ZEO_RESCUE_STATE=$P/state STATE=$P/state ZEO_RESCUE_PROJECTS=$P/cfg/projects ZEO_RESCUE_CLAUDE=$P/claude ZEO_RESCUE_CLAUDE_JSON=$P/cfg/.claude.json ZEO_RESCUE_PROOF_TRIES=60 ZEO_RESCUE_PROOF_PAUSE=1
R() { "$P/run/rescue.sh" "$@"; }; Ln() { "$P/run/reseat-lines.sh" "$@"; }
perl "$HERE/capture.pl" "$port" "$P/cap" & L=$!; perl -e 'select(undef,undef,undef,0.4)'
newest() { ls "$P/cap" | sed -n 's/^req\.//p' | sort -n | tail -1; }
pane() { "$TM" -L "$S" list-panes -t '=rdo-s' -F "$1"; }
turn() { "$TM" -L "$S" send-keys -t '=rdo-s:' -l "$1"; "$TM" -L "$S" send-keys -t '=rdo-s:' Enter; perl -e 'select(undef,undef,undef,10)'; }
projs() { echo "  projects $1: $(ls "$P/cfg/projects" | show | paste -sd' ' -)"; }
echo "== the seat starts in its empty folder on $RUNNING"
R --apply 2>&1 | grep -E '^(FIRST SEAT OK|STOPPED|FAILED|rescue:)' | show
perl -e 'select(undef,undef,undef,8)'; pid=$(pane '#{pane_pid}'); printf 'running %s, pid %s\n' "$(pane '#{pane_current_command}')" "$pid"
turn 'a wake before the move'; projs "after a wake"
echo "== the line goes in; ops-folder with the seat live"
echo "rdo $NEW" > "$P/run/folder-moves"
Ln ops-folder 2>&1 | grep -E '^(MADE|FOLDER DONE|REFUSED|STOPPED|OUT OF ORDER|ALREADY)' | show
turn 'a wake after the folder step'; [ "$(pane '#{pane_pid}')" = "$pid" ] && echo "the same process is still up, in $(pane '#{pane_current_path}' | show)" || echo "IT DIED in the folder step"; projs "after its wake"
echo "== claude-trust, then claude-first on $INSTALLED"
Ln claude-trust 2>&1 | grep -E '^(NOTHING|ADDED|REFUSED|NOT READY|OUT OF ORDER)' | show
echo "$HOME/.local/bin/claude" > "$P/use"; before=$(newest); b2=$(stat -f %z "$oe/$sid.jsonl")
s=$(perl -MTime::HiRes -e 'print Time::HiRes::time()')
Ln claude-first 2>&1 | grep -E '^(the Claude|claude |VERSION|RESEAT|MOVE|RESUMED|FIRST SEAT OK|MOVED OK|NOTE|STOPPED|FAILED|UNRESOLVED|RECOVERY|OK|WRONG|check:|rescue:|NOT|REFUSED|BUSY|ALREADY)' | show
e=$(perl -MTime::HiRes -e 'print Time::HiRes::time()'); perl -e 'printf "seconds through the restart: %.1f\n", $ARGV[1]-$ARGV[0]' "$s" "$e"
perl -e 'select(undef,undef,undef,4)'
printf 'running %s, pid %s, a new process: %s, in %s\n' "$(pane '#{pane_current_command}')" "$(pane '#{pane_pid}')" "$([ "$(pane '#{pane_pid}')" != "$pid" ] && echo yes || echo NO)" "$(pane '#{pane_current_path}' | show)"
echo "processes naming the session:"; ps -axo pid=,command= | grep -F -e "$sid" | grep -v -e grep -e "ps -axo" | cut -c1-110 | show
echo "== what the model would receive after the move"
last=""; for f in "$P"/cap/req.*; do n=${f##*.}; [ "$n" -gt "${before:-0}" ] || continue; if [ -z "$last" ] || [ "$(stat -f %z "$f")" -gt "$(stat -f %z "$last")" ]; then last=$f; fi; done
[ -n "$last" ] || { echo "NO REQUEST AFTER THE MOVE: this proves nothing"; exit 1; }
jq -r '[.messages[]|.content|if type=="array" then map(.text//"")|join(" ") else . end]|join(" ")' "$last" > "$P/all.txt"
printf 'the note reached it: %s; its words on the memory folder: %s; the memory index read from the new key: %s\n' "$(LC_ALL=C grep -c 'because ducktyper-ops belongs to ducktyper-ai' "$P/all.txt")" "$(LC_ALL=C grep -cF -e "$words" "$P/all.txt")" "$(LC_ALL=C grep -cF -e "$tok" "$last")"
printf 'the memory path its saved prompt names: %s\n' "$(jq -r '.system | if type=="array" then map(.text)|join("\n") else . end' "$last" | grep -o 'file-based memory at `[^`]*`' | head -1 | show)"
printf 'the turns before and after the folder step reached it: '; for w in 'a wake before the move' 'a wake after the folder step'; do printf '%s ' "$(LC_ALL=C grep -c "$w" "$P/all.txt")"; done; echo
echo "== ops-old, then claude-clear"
Ln ops-old 2>&1 | grep -E '^(REMOVED|REFUSED|STOPPED|OUT OF ORDER|ALREADY)' | show
Ln claude-clear 2>&1 | grep -E '^(DELETED|NOTHING|OUT OF ORDER|FAILED)' | show
turn 'a wake after the old folder went'; [ "$(pane '#{pane_pid}')" != "$pid" ] && echo "the moved seat is still up" || echo "THE SEAT IS GONE"
echo "== on disk"
printf 'old folder there: %s; new folder empty: %s; old project gone: %s; transcripts for the session: %s; an old-key folder made again: %s\n' "$([ -e "$OLD" ] && echo YES || echo no)" "$([ -z "$(ls -A "$NEW")" ] && echo yes || echo NO)" \
  "$([ -e "$oe" ] && echo NO || echo yes)" "$(find "$P/cfg/projects" -name "$sid.jsonl" | wc -l | tr -d ' ')" "$([ -e "$oe" ] && echo YES || echo no)"
printf 'memory in the new project: %s files, the same bytes as the real memory (its MEMORY.md without the marker): %s\n' "$(find "$ne/memory" -type f | wc -l | tr -d ' ')" \
  "$([ "$(cd "$ne/memory" && find . -type f ! -name MEMORY.md | LC_ALL=C sort | xargs shasum; grep -vF -e "$tok" "$ne/memory/MEMORY.md" | shasum)" = "$(cd "$RP/memory" && find . -type f ! -name MEMORY.md | LC_ALL=C sort | xargs shasum; shasum < "$RP/memory/MEMORY.md")" ] && echo yes || echo NO)"
printf "the note's words in the transcript after the restart: %s; trust for the new folder: %s; the backup gone: %s\n" "$(tail -c +$((b2+1)) "$ne/$sid.jsonl" | LC_ALL=C grep -cF -e "$words")" "$(jq -r --arg d "$NEW" '.projects[$d].hasTrustDialogAccepted' "$P/cfg/.claude.json")" "$([ -e "$P/state/claude-json.before-rdo" ] && echo NO || echo yes)"
tail -c +$((b2+1)) "$ne/$sid.jsonl" | jq -r 'select(.cwd) | [.sessionId,.cwd]|@tsv' 2>/dev/null | show | sort | uniq -c | head -4
R --check 2>&1 | grep -E '^(OK|WRONG|check:)' | show
echo "== second runs"
p2=$(pane '#{pane_pid}'); for st in ops-folder claude-first ops-old; do Ln "$st" 2>&1 | grep -E '^(ALREADY|REFUSED|NOT READY|OUT OF ORDER|RESEAT|NOTE)' | show; done
[ "$(pane '#{pane_pid}')" = "$p2" ] && echo "the same process is still up" || echo "IT WAS RESTARTED AGAIN"
[ "$real_before" = "$(real)" ] && echo "the real seat, its folder, its memory and the org's panes are the same as before this ran" || echo "THE REAL SIDE CHANGED while this ran: read why"
