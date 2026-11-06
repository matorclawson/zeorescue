#!/bin/bash
# zeo-rescue: does a real Claude wait for its config lock? Usage: claude-lock.sh [PORT]
# Claude starts in a private tmux socket and config, with the API a local listener, while this script holds ~/.claude.json.lock the way claude-trust does.
# If the file changes while the lock is held, a Claude writer does not honour it. The lock is kept fresh, so it cannot be taken as stale. Touches no seat.
set -uo pipefail
port=${1:-39041}; HERE=$(cd "$(dirname "$0")" && pwd -P); TM=/opt/homebrew/bin/tmux
P=$(mktemp -d "${TMPDIR:-/tmp}/rl.XXXXXX"); P=$(cd "$P" && pwd -P); mkdir -p "$P/w" "$P/cfg/projects" "$P/home" "$P/cap"
ver=$("$HOME/.local/bin/claude" --version | awk 'NR==1 {print $1}'); k=sk-ant-not-a-real-key; J=$P/cfg/.claude.json
jq -n --arg d "$P/w" --arg k "${k: -20}" --arg v "$ver" '{hasCompletedOnboarding:true,lastOnboardingVersion:$v,customApiKeyResponses:{approved:[$k],rejected:[]},projects:{($d):{hasTrustDialogAccepted:true}}}' > "$J"
S=rl$$; perl "$HERE/capture.pl" "$port" "$P/cap" & L=$!
trap 'kill $L 2>/dev/null; "$TM" -L "$S" kill-server 2>/dev/null; rm -rf "$P"' EXIT
sha() { /usr/bin/shasum -a 256 "$1" | cut -d ' ' -f 1 | cut -c1-12; }
echo "claude $ver"
echo "== the lock is held for 25 s, kept fresh, while Claude starts and answers a prompt"
mkdir "$J.lock"; was=$(sha "$J"); n=0
"$TM" -L "$S" new-session -d -s l -c "$P/w" -x 120 -y 30 -- env HOME="$P/home" CLAUDE_CONFIG_DIR="$P/cfg" ANTHROPIC_API_KEY=$k ANTHROPIC_BASE_URL=http://127.0.0.1:$port DISABLE_TELEMETRY=1 DISABLE_ERROR_REPORTING=1 DISABLE_AUTOUPDATER=1 CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC=1 "$HOME/.local/bin/claude" "say hello"
for i in $(seq 1 25); do
  sleep 1; touch "$J.lock"; now=$(sha "$J")
  if [ "$now" != "$was" ]; then n=$((n+1)); printf '  t=%ss: the file changed while the lock was held (%s to %s)\n' "$i" "$was" "$now"; was=$now; fi
done
printf 'writes while held: %s; lock still ours: %s\n' "$n" "$([ -d "$J.lock" ] && echo yes || echo NO)"
ls -a "$P/cfg" | grep -v '^\.\.*$' | tr '\n' ' '; echo
echo "== the lock is let go, 10 s more"
rmdir "$J.lock" 2>/dev/null; m=0
for i in $(seq 1 10); do sleep 1; now=$(sha "$J"); if [ "$now" != "$was" ]; then m=$((m+1)); was=$now; fi; done
printf 'writes after release: %s\n' "$m"
printf 'requests that reached the listener: %s\n' "$(ls "$P"/cap/req.* 2>/dev/null | wc -l | tr -d ' ')"
