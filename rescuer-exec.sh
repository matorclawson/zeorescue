#!/bin/bash -p
# No shell startup files before the rescuer CLI. HOME is retained for normal CLI-managed login/configuration.
set -euo pipefail
HERE=$(cd "$(dirname "$0")" && pwd -P)
[ $# -eq 4 ] || exit 2
action=$1 harness=$2 binary=$3 marker=$4
case "$action" in --launch|--help-check) ;; *) exit 2;; esac
case "$harness" in codex|claude) ;; *) exit 2;; esac
case "$marker" in master|sparring|principal|inactive) ;; *) exit 2;; esac
[[ "$binary" = /* ]] && [ -x "$binary" ] || exit 2
config=()
for name in ZEO_RESCUE_RECORDS ZEO_RESCUE_HOST ZEO_RESCUE_SOCKET ZEO_RESCUE_STATE ZEO_RESCUE_CHART ZEO_RESCUE_PROJECTS ZEO_RESCUE_CODEX_DB ZEO_RESCUE_SNAPSHOTS ZEO_RESCUE_TMUX ZEO_RESCUE_JQ ZEO_RESCUE_SQLITE ZEO_RESCUE_PS ZEO_RESCUE_LSOF ZEO_RESCUE_KILL ZEO_RESCUE_CLAUDE ZEO_RESCUE_CODEX ZEO_RESCUE_PINS; do
  [ -z "${!name:-}" ] || config+=("$name=${!name}")
done
clean=(/usr/bin/env -i "HOME=$HOME" "USER=$(id -un)" "LOGNAME=$(id -un)" "SHELL=/bin/zsh"
  "PATH=$HOME/.local/bin:/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin"
  "TERM=${TERM:-xterm-256color}" "LANG=${LANG:-en_US.UTF-8}" "TMUX=${TMUX:-}" "TMUX_PANE=${TMUX_PANE:-}"
  'ZMAIL_INSTANCE=zeo-rescue' "ZEO_TMUX_SEAT=$marker" "ZEO_RESCUER_HARNESS=$harness" ${config[@]+"${config[@]}"}) # bash 3.2, the host's: an empty array is unbound under set -u
if [ "$marker" = inactive ]; then clean+=('GIT_ALLOW_PROTOCOL=file'); fi
cd "$HERE"
if [ "$action" = --help-check ]; then exec "${clean[@]}" "$binary" --help; fi
prompt='You are zeo-rescue, regardless of whether you run in Codex or Claude Code. Read AGENTS.md, STATE.md, RESCUER.md and RUNBOOK.md first. Run make doctor, make check and make plan as applicable; report missing capabilities. STATE.md and the saved evidence are the cross-harness handoff. Do not use another seat identity or mailbox. Do not restart live seats or run bulk recovery; prepare reviewed operator commands. Start with inspection, not outward actions. Never bypass a harness permission refusal.'
case "$harness" in
  codex) exec "${clean[@]}" "$binary" --no-daemon -C "$HERE" "$prompt";;
  claude) exec "${clean[@]}" "$binary" "$prompt";;
esac
