#!/bin/bash
# zeo-rescue: the zbs move rehearsed in its exact shape, without touching the seat. Usage: zbs-move.sh [PORT]
# The shape is copied from the real folders, read-only: the git store with all 12 worktree records, the seat's worktree and wt-screensaver with
# their tracked files, untracked files and small ignored entries, the seat's settings, its real transcript (session id and folder rewritten), its
# subagent files and its real memory, under the key of the folder that no longer exists. Ignored folders over 20 MB (data, dist, node_modules,
# previews) stand in as small folders: a rename on one volume never reads them, and git status shows them the same way.
# The seat starts in the worktree on the version it runs today. Then the operator's own steps run, on copies of the real scripts: zbs-repo and
# zbs-folder with the seat live, claude-trust, claude-first on the installed version. The copies differ only in socket, seat and folders, and they
# refuse to start if they could reach zeo2 or a real folder. Private tmux socket and config; the API is a local listener. Nothing leaves this machine.
# KEEP=1 keeps the working folder, which holds a copy of the transcript.
set -uo pipefail
FOLDER=${FOLDER:-zbs-folder}; case "$FOLDER" in zbs-folder|zbs-folder-abs) ;; *) echo "FOLDER is zbs-folder or zbs-folder-abs"; exit 2;; esac
port=${1:-39032}; HERE=$(cd "$(dirname "$0")" && pwd -P); R0=$(dirname "$HERE")
orig=d7fc6540-05c6-43ec-94c5-520b66af4133 sid=ffffffff-05c6-43ec-94c5-520b66af4133
RS=/Volumes/AIPEMedia1/code/zeroemployeeorg/zeobroacastingstudio-zbs RM=/Volumes/AIPEMedia1/code/ducktyper-ai/dt-broadcastingstudio/main RW=/Volumes/ZeoWork/tmp/zbs/wt-screensaver
RP=$HOME/.claude/projects/-Volumes-AIPEMedia1-code-zeroemployeeorg-zeobroacastingstudio-zbs RMEM=$HOME/.claude/projects/-Volumes-AIPEMedia1-code-zeroemployeeorg-zeobroacastingstudio/memory
INSTALLED=$("$HOME/.local/bin/claude" --version | awk 'NR==1 {print $1}'); RUNNING=${RUNNING:-2.1.318}; TM=/opt/homebrew/bin/tmux; S=rz$$
export GIT_OPTIONAL_LOCKS=0
[ -x "$HOME/.local/share/claude/versions/$RUNNING" ] || { echo "NO BINARY for $RUNNING: this proves nothing"; exit 1; }
key() { printf %s "$1" | LC_ALL=C sed 's/[^A-Za-z0-9]/-/g'; }
real() { # the real folders as this read them: they must read the same at the end
  "$TM" -L zeo2 list-panes -a -F '#{pane_pid}' 2>/dev/null | sort | /usr/bin/shasum | cut -c1-12
  stat -f '%i' "$RS" "$RM"; cat "$RS/.git" "$RW/.git"; ls "$RM/.git/worktrees" | paste -sd' ' -; ls "$RMEM" | wc -l
  for m in "$RMEM" "$HOME/.claude/projects/-Volumes-AIPEMedia1-code-rodriveracom-dt-broadcastingstudio-main/memory"; do find "$m" -type f -exec stat -f "%N %z %m" {} + | LC_ALL=C sort | shasum; done
}
real_before=$(real)
P=$(mktemp -d "${TMPDIR:-/tmp}/rz.XXXXXX"); P=$(cd "$P" && pwd -P)
MAIN=$P/w/dt/main SEAT=$P/w/org/zeobroacastingstudio-zbs WT=$P/w/tmpz/wt-screensaver MEMDIR=$P/w/org/zeobroacastingstudio
mkdir -p "$MAIN" "$SEAT" "$WT" "$P/cfg/projects" "$P/home" "$P/cap" "$P/state" "$P/run/notes"
clean() { kill "$L" 2>/dev/null; "$TM" -L "$S" kill-server 2>/dev/null; if [ -z "${KEEP:-}" ]; then rm -rf "$P"; else echo "kept in $P: it holds a copy of the transcript, so delete it when you are done"; fi; }
L=""; trap clean EXIT
show() { sed "s#$P#<P>#g" | cut -c1-150; }
echo "== the shape, copied read-only"
# Tracked files from each checkout's own index; untracked files; ignored entries up to 20 MB, and a stand-in for each bigger one.
copytree() { # copytree FROM TO [tracked]: an ignored .env, or anything over 20 MB, is a stand-in of the same kind, never a copy
  local from=$1 to=$2 p s
  git -C "$from" ls-files -z | rsync -a --from0 --files-from=- "$from/" "$to/" || return 1
  git -C "$from" status --porcelain -z --untracked-files=all | tr '\0' '\n' | sed -n 's/^?? //p' | rsync -a --files-from=- "$from/" "$to/" || return 1
  [ -z "${3:-}" ] || return 0
  git -C "$from" status --porcelain --ignored | sed -n 's/^!! //p' | while read -r p; do
    s=$(du -sk "$from/$p" 2>/dev/null | cut -f1); mkdir -p "$to/$(dirname "${p%/}")"
    case "$(basename "${p%/}")" in .env*) s=999999;; esac
    if [ "${s:-0}" -le 20480 ]; then rsync -a "$from/${p%/}" "$to/$(dirname "${p%/}")/"
    elif [ -d "$from/$p" ]; then mkdir -p "$to/$p"; echo stand-in > "$to/$p/STAND-IN"; echo "  stand-in folder: $p (${s} KB)"
    else echo stand-in > "$to/$p"; echo "  stand-in file: $p"; fi
  done
}
cp -Rp "$RM/.git" "$MAIN/.git" || exit 1
# Every record names a real folder. Each is pointed into the copy before any git command runs in it.
for r in "$MAIN"/.git/worktrees/*; do n=$(basename "$r"); case "$n" in zeobroacastingstudio-zbs) to=$SEAT;; wt-screensaver) to=$WT;; *) to=$P/w/tmpz/$n;; esac; echo "$to/.git" > "$r/gitdir"; done
[ -z "$(cat "$MAIN"/.git/worktrees/*/gitdir | grep -v "^$P/")" ] && [ -z "$(git config -f "$MAIN/.git/config" --get core.worktree)" ] || { echo "THE COPY NAMES A REAL FOLDER: stopped before anything started"; exit 1; }
printf 'gitdir: %s\n' "$MAIN/.git/worktrees/zeobroacastingstudio-zbs" > "$SEAT/.git"; printf 'gitdir: %s\n' "$MAIN/.git/worktrees/wt-screensaver" > "$WT/.git"
copytree "$RM" "$MAIN" tracked && copytree "$RS" "$SEAT" && copytree "$RW" "$WT" || { echo "COPY FAILED: this proves nothing"; exit 1; }
snap() { git -C "$1" rev-parse HEAD && git -C "$1" status --porcelain=v2 --branch --ignored --untracked-files=normal; }
for pair in "$RS $SEAT seat" "$RW $WT wt-screensaver"; do set -- $pair
  if [ "$(snap "$1" | sed 's#/STAND-IN##')" = "$(snap "$2")" ]; then echo "the copy of the $3 reads as the real one: $(snap "$2" | wc -l | tr -d ' ') lines of status"; else echo "THE COPY OF THE $3 DIFFERS from the real one: this proves nothing"; diff <(snap "$1") <(snap "$2") | head; exit 1; fi
done
[ -z "$(git -C "$MAIN" status --porcelain --untracked-files=all)" ] && echo "the copy of the 24 Sep checkout is clean" || { echo "THE COPY OF THE 24 Sep CHECKOUT IS NOT CLEAN"; exit 1; }
oe=$P/cfg/projects/$(key "$SEAT"); ne=$P/cfg/projects/$(key "$MAIN"); me=$P/cfg/projects/$(key "$MEMDIR")
mkdir -p "$oe" "$me"; was=$(tail -n 2000 "$RP/$orig.jsonl" | jq -r 'select(.cwd) | .cwd' 2>/dev/null | tail -1); [ "$was" = "$RS" ] || { echo "THE TRANSCRIPT'S FOLDER IS ${was:-none}: this proves nothing"; exit 1; }
LC_ALL=C sed -e "s/$orig/$sid/g" -e "s#$RS#$SEAT#g" "$RP/$orig.jsonl" > "$oe/$sid.jsonl"; b=$(stat -f %z "$oe/$sid.jsonl"); cp -Rp "$RP/$orig" "$oe/$sid"
cp -Rp "$RMEM" "$me/memory"; nmem=$(find "$me/memory" -type f | wc -l | tr -d ' ')
# Every line of the real MEMORY.md is already quoted in the transcript, so finding one proves nothing. The copy gets one marker line;
# finding it in a request shows the index was read from where the memory now is.
tok=ZEOTOKEN-MEMORY-SEEN-$$; printf -- '- [rehearsal marker](rehearsal-marker.md) — %s\n' "$tok" >> "$me/memory/MEMORY.md"
LC_ALL=C grep -qF -e "$tok" "$oe/$sid.jsonl" && { echo "THE TRANSCRIPT ALREADY HOLDS THE MARKER: this proves nothing"; exit 1; }
echo "transcript $b bytes; $(find "$oe/$sid" -type f | wc -l | tr -d ' ') subagent and tool files; memory $nmem files, under the key of a folder that does not exist"
k=sk-ant-not-a-real-key
jq -n --arg o "$SEAT" --arg k "${k: -20}" --arg v "$INSTALLED" '{hasCompletedOnboarding:true,lastOnboardingVersion:$v,customApiKeyResponses:{approved:[$k],rejected:[]},projects:{($o):{hasTrustDialogAccepted:true}}}' > "$P/cfg/.claude.json"; chmod 600 "$P/cfg/.claude.json"
echo "$HOME/.local/share/claude/versions/$RUNNING" > "$P/use"
cat > "$P/claude" <<W
#!/bin/sh
exec env HOME="$P/home" CLAUDE_CONFIG_DIR="$P/cfg" ANTHROPIC_API_KEY=$k ANTHROPIC_BASE_URL=http://127.0.0.1:$port DISABLE_TELEMETRY=1 DISABLE_ERROR_REPORTING=1 DISABLE_AUTOUPDATER=1 CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC=1 "\$(cat "$P/use")" "\$@"
W
chmod +x "$P/claude"
# The copies of the operator's scripts. They must not be able to reach the org's socket or a real folder, so that is checked before anything starts.
cp "$R0/seat-exec.sh" "$R0/Makefile" "$P/run/"; cp "$R0/notes/claude-move-zbs-20261107.txt" "$P/run/notes/"
sed -e "s/^SOCKET=zeo2 HOST_NAME=matormini /SOCKET=$S HOST_NAME=h /" "$R0/rescue.sh" > "$P/run/rescue.sh"
sed -e '/^pin [0-9a-f]\{64\} /d' -e "s/-L zeo2/-L $S/g" -e 's/^CLAUDE_SEAT=.*/CLAUDE_SEAT=rz/' -e "s#^CLAUDE_OLD=.*#CLAUDE_OLD=$SEAT#" -e "s#^CLAUDE_NEW=.*#CLAUDE_NEW=$MAIN#" -e "s#^CLAUDE_INODE=.*#CLAUDE_INODE=$(stat -f %i "$SEAT")#" "$R0/reseat-lines.sh" > "$P/run/reseat-lines.sh"
sed -e "s/^SOCKET=.*/SOCKET=$S/" -e 's/^TSESS=.*/TSESS=rz-s/' -e "s/^SESSION_ID=.*/SESSION_ID=$sid/" -e "s#^MAIN=.*#MAIN=$MAIN#" -e "s#^SEAT=.*#SEAT=$SEAT#" -e "s#^ASIDE=.*#ASIDE=$P/w/dt/main-old-20260924#" \
  -e "s#^WT=.*#WT=$WT#" -e "s#^MEM_FROM_DIR=.*#MEM_FROM_DIR=$MEMDIR#" -e "s#^SEAT_INODE=.*#SEAT_INODE=$(stat -f %i "$SEAT")#" "$R0/zbs-move.sh" > "$P/run/zbs-move.sh"
chmod +x "$P/run/rescue.sh" "$P/run/reseat-lines.sh" "$P/run/zbs-move.sh"
[ "$(cat "$P/run/rescue.sh" "$P/run/reseat-lines.sh" "$P/run/zbs-move.sh" | grep -c zeo2)" = 0 ] && ! grep -E '^(MAIN|SEAT|ASIDE|WT|MEM_FROM_DIR)=/Volumes' "$P/run/zbs-move.sh" >/dev/null || { echo "THE COPY CAN REACH THE ORG: stopped before anything started"; exit 1; }
printf '{"seats":[{"seat_id":"rz","mailbox":"rz","desired_agent":"claude","desired_host":"h","desired_tmux":{"session":"rz-s"},"desired_folder":"%s"}]}' "$SEAT" > "$P/chart.json"
echo "rz $sid" > "$P/run/session-pins"; : > "$P/run/folder-moves"
# The kill that stops a shared Codex daemon is a stub that only writes down what it was asked (the Architect, 9 Nov 11:28Z): a rehearsal stops no real daemon.
printf '#!/bin/sh\necho "$*" >> "%s/kills"\n' "$P" > "$P/nokill"; chmod +x "$P/nokill"
export ZEO_RESCUE_KILL=$P/nokill ZEO_RESCUE_CHART=$P/chart.json ZEO_RESCUE_STATE=$P/state STATE=$P/state ZEO_RESCUE_PROJECTS=$P/cfg/projects ZEO_RESCUE_CLAUDE=$P/claude ZEO_RESCUE_CLAUDE_JSON=$P/cfg/.claude.json ZEO_RESCUE_PROOF_TRIES=60 ZEO_RESCUE_PROOF_PAUSE=1
R() { "$P/run/rescue.sh" "$@"; }; Ln() { "$P/run/reseat-lines.sh" "$@"; }
perl "$HERE/capture.pl" "$port" "$P/cap" & L=$!; perl -e 'select(undef,undef,undef,0.4)'
tail -n 4000 "$oe/$sid.jsonl" | jq -r 'select(.type=="assistant") | .message.content[]? | select(.type=="text") | .text' 2>/dev/null | grep -v '^$' | tail -1 | cut -c1-48 > "$P/lastwords"
[ -s "$P/lastwords" ] || { echo "NO LAST WORDS: this proves nothing"; exit 1; }
newest() { ls "$P/cap" | sed -n 's/^req\.//p' | sort -n | tail -1; }
pane() { "$TM" -L "$S" list-panes -t '=rz-s' -F "$1"; }
turn() { "$TM" -L "$S" send-keys -t '=rz-s:' -l "$1"; "$TM" -L "$S" send-keys -t '=rz-s:' Enter; perl -e 'select(undef,undef,undef,10)'; }
memseen() { local f; f=$P/cap/req.$(newest); [ -f "$f" ] && LC_ALL=C grep -cF -e "$tok" "$f" || echo 0; }
mempath() { local f; f=$P/cap/req.$(newest); [ -f "$f" ] && jq -r '.system | if type=="array" then map(.text)|join("\n") else . end' "$f" | grep -o 'file-based memory at `[^`]*`' | sed "s#$P#<P>#; s#$(key "$P")#<P>#" | head -1; }
projs() { echo "  projects $1: $(ls "$P/cfg/projects" | sed "s#$(key "$P")##g" | paste -sd" " -)"; [ ! -d "$ne" ] || { echo "  under the new folder:"; (cd "$ne" && find . | head -20 | sed "s/^/    /"); }; }
echo "== the seat starts in its worktree on $RUNNING"
R --apply 2>&1 | grep -E '^(FIRST SEAT OK|STOPPED|FAILED|rescue:)' | show
perl -e 'select(undef,undef,undef,8)'; pid=$(pane '#{pane_pid}'); printf 'running %s, pid %s\n' "$(pane '#{pane_current_command}')" "$pid"
projs "at launch"
turn 'a wake before the move'; echo "in the worktree, the seat's memory reached the model: $(memseen)"; echo "  the memory path its prompt names: $(mempath)"
projs "after the wake"
echo "== the line goes in; zbs-repo with the seat live"
echo "rz $MAIN" > "$P/run/folder-moves"
Ln zbs-repo 2>&1 | grep -E '^(READ|PRUNED|MOVED|PROVED|REPO DONE|REFUSED|BUSY|STOPPED|OUT OF ORDER)' | show
projs "after zbs-repo"
turn 'a wake after the repo step'; [ "$(pane '#{pane_pid}')" = "$pid" ] && echo "the same process is still up" || echo "IT DIED in the repo step"; projs "after its wake"
echo "== $FOLDER with the seat live"
Ln "$FOLDER" 2>&1 | grep -E '^(CLEARED|MOVED|PROVED|MEMORY|SETTINGS|FOLDER DONE|REFUSED|BUSY|STOPPED|OUT OF ORDER)' | show
turn 'a wake after the rename'; [ "$(pane '#{pane_pid}')" = "$pid" ] && echo "the same process is still up" || echo "IT DIED under the rename"
printf 'old folder there: %s; a project made under the new folder: %s\n' "$([ -e "$SEAT" ] && echo YES || echo no)" "$([ -e "$ne" ] && echo YES || echo no)"
echo "== claude-trust, then claude-first on $INSTALLED"
Ln claude-trust 2>&1 | grep -E '^(NOTHING|ADDED|REFUSED|NOT READY|OUT OF ORDER)' | show
echo "$HOME/.local/bin/claude" > "$P/use"; before=$(newest); b2=$(stat -f %z "$oe/$sid.jsonl")
s=$(perl -MTime::HiRes -e 'print Time::HiRes::time()')
Ln claude-first 2>&1 | grep -E '^(the Claude|claude |VERSION|RESEAT|MOVE|RESUMED|FIRST SEAT OK|MOVED OK|NOTE|STOPPED|FAILED|UNRESOLVED|RECOVERY|OK|WRONG|check:|rescue:|NOT READY|OUT OF ORDER)' | show
e=$(perl -MTime::HiRes -e 'print Time::HiRes::time()'); perl -e 'printf "seconds through the restart: %.1f\n", $ARGV[1]-$ARGV[0]' "$s" "$e"
perl -e 'select(undef,undef,undef,8)'
printf 'running %s, pid %s\n' "$(pane '#{pane_current_command}')" "$(pane '#{pane_pid}')"
R --check 2>&1 | grep -E '^(OK|WRONG|check:)' | show
echo "== what the model would receive after the move"
last=""; for f in "$P"/cap/req.*; do n=${f##*.}; [ "$n" -gt "${before:-0}" ] || continue; if [ -z "$last" ] || [ "$(stat -f %z "$f")" -gt "$(stat -f %z "$last")" ]; then last=$f; fi; done
[ -n "$last" ] || { echo "NO REQUEST AFTER THE MOVE: this proves nothing"; exit 1; }
jq -r '"messages=\(.messages|length)"' "$last"; printf 'memory line reached it: '; LC_ALL=C grep -cF -e "$tok" "$last"
printf 'the memory path its prompt names: %s\n' "$(jq -r '.system | if type=="array" then map(.text)|join("\n") else . end' "$last" | grep -o 'file-based memory at `[^`]*`' | sed "s#$(key "$P")#<P>#; s#$P#<P>#" | head -1)"
jq -r '[.messages[]|.content|if type=="array" then map(.text//"")|join(" ") else . end]|join(" ")' "$last" > "$P/all.txt"; printf 'last words [%s] found: ' "$(cat "$P/lastwords")"; LC_ALL=C grep -oF -f "$P/lastwords" "$P/all.txt" | wc -l | tr -d ' '
printf 'the note reached it: '; LC_ALL=C grep -c 'the broadcasting studio now belongs to ducktyper-ai' "$P/all.txt"
printf 'and its word on the memory path: '; LC_ALL=C grep -c 'The memory path in your system prompt is an old saved copy' "$P/all.txt"
printf 'and its word on the rules: '; LC_ALL=C grep -c 'a copy of each deny and ask rule that guards' "$P/all.txt"
printf 'the turns before and after the steps reached it: '; for w in 'a wake before the move' 'a wake after the repo step' 'a wake after the rename'; do printf '%s ' "$(LC_ALL=C grep -c "$w" "$P/all.txt")"; done; echo
echo "== on disk"
printf 'old project gone: %s; memory in the new project: %s files, the same bytes as the real memory (its MEMORY.md without the marker): %s; its old place empty: %s\n' "$([ -e "$oe" ] && echo NO || echo yes)" "$(find "$ne/memory" -type f | wc -l | tr -d ' ')" \
  "$([ "$(cd "$ne/memory" && find . -type f ! -name MEMORY.md | LC_ALL=C sort | xargs shasum; grep -vF -e "$tok" "$ne/memory/MEMORY.md" | shasum)" = "$(cd "$RMEM" && find . -type f ! -name MEMORY.md | LC_ALL=C sort | xargs shasum; shasum < "$RMEM/MEMORY.md")" ] && echo yes || echo NO)" "$([ -e "$me/memory" ] && echo NO || echo yes)"
printf 'transcripts for the session: %s; new project grew by %s; subagent files: %s\n' "$(find "$P/cfg/projects" -maxdepth 2 -name "$sid.jsonl" | wc -l | tr -d ' ')" "$(( $(stat -f %z "$ne/$sid.jsonl") - b2 ))" "$(find "$ne/$sid" -type f | wc -l | tr -d ' ')"
tail -c +$((b2+1)) "$ne/$sid.jsonl" | jq -r 'select(.cwd) | [.sessionId,.cwd]|@tsv' 2>/dev/null | show | sort | uniq -c | head -4
printf 'the repository: own git dir %s; HEAD %s; worktrees: %s\n' "$([ "$(git -C "$MAIN" rev-parse --absolute-git-dir)" = "$MAIN/.git" ] && echo yes || echo NO)" "$(git -C "$MAIN" rev-parse --short HEAD)" "$(git -C "$MAIN" worktree list --porcelain | sed -n 's/^worktree //p' | show | paste -sd' ' -)"
printf 'git status as the real seat and wt-screensaver read it: %s %s\n' "$([ "$(snap "$RS" | sed 's#/STAND-IN##')" = "$(snap "$MAIN")" ] && echo yes || echo NO)" "$([ "$(snap "$RW")" = "$(snap "$WT")" ] && echo yes || echo NO)"
printf 'the 24 Sep checkout set aside without .git: %s; allow rule: %s\n' "$([ -d "$P/w/dt/main-old-20260924" ] && [ ! -e "$P/w/dt/main-old-20260924/.git" ] && echo yes || echo NO)" "$(jq -r '.permissions.allow[] | select(test("dt-broadcastingstudio|^Edit\\(/Volumes/AIPEMedia1/code/zeroemployeeorg/\\*\\*\\)$"))' "$MAIN/.claude/settings.local.json" | paste -sd' ' -)"
sl=$MAIN/.claude/settings.local.json rl=$RS/.claude/settings.local.json
printf 'the settings against the real seat'"'"'s: deny %s then %s, ask %s then %s; every old rule kept, in order: %s; changed lines: %s out, %s in\n' "$(jq '.permissions.deny | length' "$rl")" "$(jq '.permissions.deny | length' "$sl")" "$(jq '.permissions.ask | length' "$rl")" "$(jq '.permissions.ask | length' "$sl")" \
  "$([ "$(jq -c '[.permissions.deny[], .permissions.ask[]] | map(select(test("dt-broadcastingstudio/main/") | not))' "$sl")" = "$(jq -c '[.permissions.deny[], .permissions.ask[]]' "$rl")" ] && echo yes || echo NO)" \
  "$(/usr/bin/diff "$rl" "$sl" | grep -c '^<')" "$(/usr/bin/diff "$rl" "$sl" | grep -c '^>')"
echo "  mirrored: $(jq -r '[.permissions.deny[], .permissions.ask[]] | map(select(test("dt-broadcastingstudio/main/")) | sub("Volumes/AIPEMedia1/code/ducktyper-ai/dt-broadcastingstudio/main/.*"; "…")) | group_by(.) | map("\(length) \(.[0])") | join(", ")' "$sl")"
echo "== second runs, then a crash"
Ln zbs-repo 2>&1 | grep -E '^(ALREADY|REFUSED)' | show; Ln zbs-folder 2>&1 | grep -E '^(ALREADY|REFUSED)' | show; Ln zbs-folder-abs 2>&1 | grep -E '^(ALREADY|REFUSED)' | show
R --reseat --relaunch 2>&1 | grep -E '^(OK|RESEAT)' | show
"$TM" -L "$S" kill-session -t '=rz-s'; perl -e 'select(undef,undef,undef,1)'
R 2>&1 | grep -E '^(RESUME|MOVE|UNRESOLVED)' | show
[ "$real_before" = "$(real)" ] && echo "the real seat, its folders, its memory and the org's panes are the same as before this ran" || echo "THE REAL SIDE CHANGED while this ran: read why"
