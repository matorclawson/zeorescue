#!/bin/sh
# The first program in a seat's pane. rescue.sh starts it with respawn-pane, AFTER it has set @zeo_seat on the pane, so the seat
# loader in ~/.zshrc reads the right label the first time it runs.
#
# The clean environment is the point. A tmux server keeps the environment of whoever started it, so without env -i a seat inherits
# the rescuer's, and a Codex seat without --no-daemon joins a shared app-server that runs every seat's tools under the first seat's
# ZMAIL_INSTANCE and git settings (25 Oct and 5 Nov 2026).
#
#   seat-exec.sh SEAT HARNESS PROMPT_FILE ARGV...
seat=$1 harness=$2 prompt_file=$3
shift 3
prompt=$(cat "$prompt_file") || exit 1
# Codex builds its own login shell for tools. Claude's tools inherit from this shell, so the seat loader in .zshrc must run here.
case "$harness" in codex) flags=-lc;; *) flags=-lic;; esac
exec env -i HOME="$HOME" USER="$(id -un)" LOGNAME="$(id -un)" SHELL=/bin/zsh TERM="${TERM:-xterm-256color}" LANG="${LANG:-en_US.UTF-8}" \
  TMUX="$TMUX" TMUX_PANE="$TMUX_PANE" ZMAIL_INSTANCE="$seat" /bin/zsh "$flags" 'exec "$@"' zeo-rescue "$@" "$prompt"
