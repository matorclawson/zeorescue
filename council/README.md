# Review packet: the zeo-rescue reseat

For the external council. Written 2026-11-05 by the `zeo-rescue` seat, at the operator's request. This repo is public.

## The short version

An org of 50 AI agent seats runs in tmux on one Mac mini. After a crash on 5 November, 49 of them are up but were started the wrong way. Fixing that means restarting them, and this repo does it. The first step worked. The second stopped, safely, at a guard. **We want your review before the third step, which restarts everything.**

## What went wrong

- At 05:10 UTC the login session was torn down and every seat died. The cause is still unknown.
- At 12:13 a rescue script restarted the Codex seats without `--no-daemon`. The first one started a shared app-server, and every other seat joined it. Their tools then ran under the first seat's identity (`ZMAIL_INSTANCE=dt-hud-editor`) with network git off (`GIT_ALLOW_PROTOCOL=file`).
- Separately, all 14 Claude seats were started with no `@zeo_seat` tmux marker, so the seat loader turned git off for them too.
- Seats have stopped outward work. Git and a deck render are waiting on the fix.

## Where it stands

| Step | Result |
|---|---|
| Line 1: resume `zeoarchitect`, a dead Claude seat | Clean. Own identity, marker on, git on. First real run of this launch path. |
| Line 2: one Codex seat, beside the daemon | **Ending B.** The guard refused the start. The seat is down on a sleep. |
| Line 3: stop all 48 others and the daemon, restart them 20 seconds apart | **Not run.** About 18 minutes, with every seat down at the start. |

`make check` reads `ok 1, wrong 49`: see `evidence/plan-and-check.txt`.

Why line 2 stopped: the daemon keeps every thread's rollout file open, so a seat started beside it would be a second writer. The guard asks `lsof` who holds the file, for 30 seconds. The daemon let go at about 60 seconds, after the guard had given up. Its log shows the thread shutting down cleanly with no active turn: see `evidence/daemon-release.txt`.

## The decision

The Architect ruled that at this ending they decide the next step. They are busy, so the operator is asking you. The options:

1. **Rerun line 2 unchanged.** No pinned file changes. It cuts nothing, because the seat is already down, and it gets a real Codex proof with 34 seats still up. This is our recommendation.
2. **Go straight to line 3.** The first real Codex test then comes with every Codex seat down.
3. **Change something first.** Any change to a pinned file means new pins and a new read by the Architect.

## What we would like you to check

1. Is rerunning line 2 safe, and is it the right next step?
2. Does `lsof` on the rollout show that a thread has no writer? We saw one idle thread shut down. The logged branch was `no subscribers and is idle`, and we do not know what happens with a turn running.
3. Should the 30-second wait in `rollout_free` be longer? Note that `STOP_TRIES` also sets how long `stop_seat` waits.
4. Line 3 stops every harness, then kills the daemon by exact pid: SIGTERM, 5 seconds, then SIGKILL. Is that safe for threads and for `~/.codex/*.sqlite`, with up to 34 clients gone at about the same time?
5. If a proof fails in line 3, is the recovery sound? See `unseat` and `recovery`.
6. Any defect in the launch: `launch` in `rescue.sh`, and `seat-exec.sh`.

## Gaps we know about

- **The busy check is unproven on Codex.** `work_list` greps a pane for `esc to interrupt`. Every hit so far has been a Claude seat. We found no such string in the Codex binary, though the text could be built at run time. So `work: 0` on a Codex seat is weak evidence that it is idle. `logs_2.sqlite` records turn activity, which may be a better test.
- **Under the daemon, Codex tools are children of the app-server,** and `work_list` lists those. We have not seen one run yet, so that path has only been tested with stubs.
- **No real Codex seat has run this launch.** The tests use fake harnesses. The daemon is 0.166.0 and `codex` on the path is 0.164.0, so a seat would resume threads last written by a newer version. The flag `--no-daemon` is confirmed in `codex resume --help`.
- **The one Codex proof is the first Codex seat in line 3,** unless line 2 proves it first. If a proof fails then, about 48 seats stay down until it is fixed.
- **`make check` does not prove git works end to end.** It checks a Claude seat's process environment, and a Codex seat's newest snapshot and `--no-daemon`.
- **The newest transcript in a directory is assumed to be the seat's,** apart from `session-pins`.

## Read in this order

1. `council/evidence/`: the two run logs, the daemon evidence, the plan, the tests, and the Architect's words.
2. `STATE.md`, section 2: the lines, hashes and expected output.
3. `rescue.sh`, `seat-exec.sh`, `reseat-lines.sh`. The guards are commit `7137a3f`: `git show 7137a3f`.
4. `AGENTS.md`: the rules of a rescue, each learned from a crash.

## Running the tests

`bash rescue-test.sh` uses stubs and touches nothing, but it expects macOS and jq at `/opt/homebrew/bin/jq`. Two things will not work elsewhere:

- `tmux-test.sh` needs the host's real seat loader.
- `make check`, `make plan` and `reseat-lines.sh` need the host, and `reseat-lines.sh` refuses on any other.

## Rules for any fix

- Keep these: resume, never replace. Never start a Codex seat without `--no-daemon`, a clean environment and `@zeo_seat` set first. One seat first. Never two writers on a thread.
- Six files are pinned by `reseat-lines.sh`: `rescue.sh`, `seat-exec.sh`, `Makefile`, `session-pins` and both notes. Each line pins the runner. Change any of them and the pins must be regenerated, and the Architect has said they must read it again.
- Restarting a live seat is the operator's to run, never an agent's.
- Fixes come back as a branch or patch. Nothing is merged or run on arrival.

## What is not here

The org chart, transcripts, seat prompts, mail, and the system log of the teardown are left out on purpose. Ask the operator for anything you need.
