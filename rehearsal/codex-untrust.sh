#!/bin/bash
# zeo-rescue: codex-untrust, the real pinned step, on a private copy of the real ~/.codex/config.toml, read by the real Codex. Usage: codex-untrust.sh
# It prints only the lines that go. The copy is private and is deleted at the end. Touches no seat and not the real file.
set -uo pipefail
R0=$(cd "$(dirname "$0")/.." && pwd -P); P=$(mktemp -d "${TMPDIR:-/tmp}/ru.XXXXXX"); P=$(cd "$P" && pwd -P); trap 'rm -rf "$P"' EXIT; chmod 700 "$P"; mkdir "$P/home" "$P/state" "$P/bad"
REAL=$HOME/.codex/config.toml; C=$P/home/config.toml; cp -p "$REAL" "$C"; cp -p "$REAL" "$P/before"
sha() { /usr/bin/shasum -a 256 "$1" | cut -d ' ' -f 1; }
real_was=$(sha "$REAL"); parse() { (cd "$P" && CODEX_HOME=$1 "$HOME/.local/bin/codex" mcp list 2>&1); }
echo "codex $("$HOME/.local/bin/codex" --version | awk '{print $2}'); the file $(wc -c < "$C" | tr -d ' ') bytes, $(sha "$C" | cut -c1-12)"
one=$(parse "$P/home"); rc1=$?; printf 'before the edit, Codex reads it: exit %s\n' "$rc1"
ZEO_RESCUE_CODEX_CONFIG=$C ZEO_RESCUE_STATE=$P/state "$R0/reseat-lines.sh" codex-untrust 2>&1 | sed "s#$P#<P>#g" | cut -c1-140
echo "== what went"; /usr/bin/diff "$P/before" "$C" | sed 's/^/  /' | cut -c1-130
printf 'bytes %s to %s; mode %s; backup mode %s; backup is the old file: %s; copy left: %s\n' "$(wc -c < "$P/before" | tr -d ' ')" "$(wc -c < "$C" | tr -d ' ')" "$(stat -f %Lp "$C")" "$(stat -f %Lp "$P/state/codex-config.before-untrust-20261106")" "$(cmp -s "$P/before" "$P/state/codex-config.before-untrust-20261106" && echo yes || echo NO)" "$([ -e "$C.zeo" ] && echo YES || echo no)"
two=$(parse "$P/home"); rc2=$?; printf 'after the edit, Codex reads it: exit %s; same answer as before: %s\n' "$rc2" "$([ "$one" = "$two" ] && echo yes || echo NO)"
printf '[broken\n' > "$P/bad/config.toml"; parse "$P/bad" >/dev/null; printf 'a broken file, so this read can fail: exit %s\n' "$?"
ZEO_RESCUE_CODEX_CONFIG=$C ZEO_RESCUE_STATE=$P/state "$R0/reseat-lines.sh" codex-untrust 2>&1 | cut -c1-100
printf 'the real file unchanged: %s\n' "$([ "$(sha "$REAL")" = "$real_was" ] && echo yes || echo NO)"
