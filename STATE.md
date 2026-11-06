# zeo-rescue state

This is the seat's memory. Update it before you stop, and commit it. Newest state first; the history at the end only grows.

Last updated: 2026-11-06 ~05:20 GMT, by `zeo-rescue`, the bulk-restart set built for the Architect's one read; the five folders are theirs; nothing has run.

## Do next, in this order

**1. Read the mail first.** The first rescue handed the operator a command one minute before the Architect's stop arrived, and did not re-check. It happened again in a smaller way: the Architect rejected the 13:55 lines at 13:57, three minutes before handover, and that reply went to the `zeoarchitect` mailbox, so handover said "no answer yet". Until `zeo-rescue` has a mailbox, ask the operator, look at the Architect's pane (`tmux -L zeo2 capture-pane -p -t '=architect:'`), and read the end of their transcript.

**2. The reseat: DONE on 6 Nov, ended clean, see the first block below; the rest of this paragraph is the record.** **CLEARED by the Architect at 10f408f (all seven hashes matched; F1 to F4 closed; the zeoarchitect-first line agreed).** Line 1 ran clean at 15:15 GMT: `check: ok 1, wrong 0`, the first real run of this launch path. Line 2 is next, and it is the operator's: it restarts a live seat. Ending A: take a fresh `make reseat-plan` read, show the operator the WORK lines, and line 3 is cleared (the Architect's checkpoint is written). Ending B or C: stop, do not run line 3, and bring the output to the Architect through the operator. Any change to a pinned file means a new read. After line 3, write the `make check` result here. What follows is the record of what the Architect read: Every seat is still wrong (`make check`: ok 0, wrong 50). **Nothing runs until the Architect has read this section and the operator has seen it here** (the Architect's word, relayed through the operator's prompt in this session). No seat has been touched in this session. When both are done, the operator runs the three lines below in order, in the rescue seat's prompt with `! ` so the output lands here, or in the rodbot terminal on the Mac mini. Between lines, read the result and the mail.

**05:20 GMT, 6 Nov: the whole set for the bulk restart is built, for the Architect's one read. Nothing has run: no seat restarted, `~/.zshenv` and `~/.codex/config.toml` untouched. One input is still theirs: the five folders.** The Architect accepted line 4's result and the `codex-code-mode-host` token. Their order: build the Codex-only step and a new note; let it take a new folder for a named seat; one thread per seat across the change, proved on one seat first; the order stays `.zshenv`, the first seat, the rest; they read `prove_codex`, `zshenv-lines.sh` and the new step together, once, and clear them as one set. Code: `34d4c51` and `edb2bb9`.

*What Codex 0.164.0 does on a folder change, from its source at that tag.* `-C` skips the "which directory?" prompt on resume (`effective_resume_cwd_mode`). It rewrites the thread's folder in its own record (`extract.rs`, `ThreadSettingsApplied`), so after a move a lookup by the chart's folder finds nothing, or another thread. **A git folder with no trust entry stops at "Trust this folder?"** (`read_remote_project_trust`). A folder outside git does not, which is why the recovery folders never asked. Nobody may answer that screen, so it has to be caught before anything stops.

*What was built.*

- **`--relaunch`** (`rescue.sh`, with `--reseat`): restarts a seat rescue started only if its process has no seat settings or it is not yet in its folder. A seat already right reads `OK ...: right already`, so the same line can run again after a stop. A fault a restart cannot fix reads `UNRESOLVED`.
- **`folder-moves`**: `SEAT /new/folder`, pinned, **shipped with no folders**. The first line is the first seat. The seat ids are `zeoapp`, `rasa`, `ducktyper`, `profrod` and `zeo-rt`, for the sessions you named. A move is refused for a Claude seat, a folder that does not exist, another seat's chart folder, two seats in one folder, two lines for one seat, no session pin, or a git folder with no trusted entry.
- **One thread per seat.** `session-pins` now names all five threads, so the thread comes from the pin, not the folder. The read-only plan finds the same five threads as line 3. `prove_moved` runs after every move, not only the first: the rollout records the new folder, exactly one rollout carries the thread, no new user thread appeared in the folder since the launch, and only the seat's process holds the rollout. Any failure stops the run, stops that seat and says `RECOVERY`. If Codex's own record still shows the old folder it prints `NOTE` and goes on, because the pin still finds the thread.
- **`reseat-lines.sh`:** `trust`, `codex-first`, `codex-rest`. `codex-first` and `codex-rest` refuse with `NOT READY` until all five folders exist, with `OUT OF ORDER` unless `.zshenv` is changed, and with `BUSY` while a turn shows on a seat they would restart. `codex-rest` also needs the first seat to pass `--check`. `trust` adds an entry only for a git folder that needs one, keeps a backup, never overrides an untrusted entry, and starts nothing.
- **`notes/codex-relaunch-20261106.txt`:** this is planned, not a crash; settings now reach every shell; leave other-author commits alone. A moved seat also gets one line naming the old and new folder.

*The order for the operator, once cleared:* `zshenv-lines.sh apply`, then `reseat-lines.sh trust`, then `codex-first`, then a read of the result, then `codex-rest`. About 12 minutes for 33 seats at 20 seconds each.

*Read-only plan at 05:19 on the real files:* 34 seats to restart, `work: 0 of 34`, and `dt-brandedimage-maintainer` `UNRESOLVED` on gh until the `.zshenv` line. That seat has already been restarted the new way, so `.zshenv` turns it into `right already`. `codex-first`, `codex-rest` and `trust` all answer `NOT READY`.

*Evidence.* `make test`: 211 checks pass, and the real tmux suite passed again. On real tmux, with a fake harness: a seat started the old way is relaunched into a new folder and proves itself with a real `lsof`, its process really runs there, a side window survives, a second run leaves it alone, and after a crash the pin still finds the thread and keeps it in the new folder. Broken on purpose in a copy, each caught: a move with no pin; no trust check; the one-rollout, new-thread and one-writer proofs each dropped; the move never proved; relaunch restarting right seats; `--check` ignoring the folder; the runner skipping the `.zshenv` order. One of those broken copies wrote a stray `reseat-20261106-051937.log` to the real state folder, with stubs only; it is harmless.

*Not proved until the first seat runs.* A real Codex resuming a real thread in a new folder: everything above reads source or uses a fake harness. Whether the trust match works on the folders the Architect picks. Whether Codex's record updates, which is why that is a `NOTE`.

*For the Architect to decide or know.*

- **First seat:** the first line of `folder-moves`. Suggestion: `zeoapp`, the smallest rollout of the five at 0.8 GB. The others are rasa 0.9, ducktyper 1.6, zeo-rt 1.7 and profrod 1.7.
- **The chart:** it still names the recovery folders. `folder-moves` bridges that, and a line goes quiet once the chart says the same folder. Changing the chart is not this seat's.
- **`trust` writes `~/.codex/config.toml`**, a real permission grant, for git folders only. A seat that writes that file in the same moment could lose its change; the backup is at `~/.local/state/zeo-rescue/codex-config.before-20261106`.
- **`make check` still reads `ok 15, wrong 35`.** Once folders are filled, the five also read `not yet in its new folder` until they move.
- **Rolling a move back:** remove the seat's line from `folder-moves`, which means a new pin and read, and run the same step. The thread stays pinned.

*When the folders arrive.* zeo-rescue writes them to `folder-moves`, in the Architect's order, and updates that one pin. That is a five-line diff, and it changes `reseat-lines.sh`'s hash, so the three reseat lines are written then, with their final hash. The `.zshenv` apply and rollback lines in the block below stand: `zshenv-lines.sh` has not changed.

| File | sha256 |
|---|---|
| `rescue.sh` (changed) | `e0d57ddec4b045fd109fe88c797b98fc6e4439423865db6c6990d8f4fceb0d0b` |
| `reseat-lines.sh` (changed; final hash only after the folders) | `9e8eb05aa8fa0c5716cfcd1f89d453886efa056cb4e4e7212eac2e0ee67e30a6` |
| `session-pins` (five seats added) | `a4ed4324fa60ee3b4561b4b6050e0dbf00e5cdb121e77d090a280646df889826` |
| `folder-moves` (new, no folders yet) | `9407e2bdfb6b9c383dc4f1a5cfaf9d42fc201686a0714aeea6809bd9a48b2392` |
| `notes/codex-relaunch-20261106.txt` (new) | `caee56c6aa567ca20d84679cb6ba969a66be37ba92b74472ed60e199cdb400de` |
| `zshenv-lines.sh` (unchanged; now also pinned by the runner) | `13416446261a2d8ba553eee22762e9efa4fdadb879dba5acc3ad1f51a2d2336d` |


*Line 4's result.* The operator ran it at 04:49:26. Log: `reseat-lines-lic-20261106-044926.log`. It ended `WRONG ...: a shell outside its folder has gh on`, `check: ok 0, wrong 1`, as expected, with `.zshenv` unchanged. Pid 43135 is the only holder of the rollout, with `--no-daemon` and 0 error events. The seat stayed idle after its turn and left nothing half-done.

- **The process has the settings:** `ZEO_TMUX_SEAT=inactive`, `ZEO_TMUX_ACCOUNT=none`, `GIT_ALLOW_PROTOCOL=file`, `GIT_SSH_COMMAND=/usr/bin/false`, and `GH_CONFIG_DIR` on the disabled folder.
- **Real tool shells agree.** At 04:49:48 the seat printed its own environment in its root and in `notes-backfill-producer` and `rasa-runtime-worktree`, the two folders where the pushes got through at 03:42. All three say `GIT_ALLOW_PROTOCOL: file`.
- **Not shown:** a real `transport not allowed` from that seat. It ran no network git, and was right not to. The value in its shells is the evidence.
- **Two differences from my expected output.** It exited 2, not 1, because `make` failed. And it read `work: 1 of 1`, not 0: every `--no-daemon` Codex seat keeps an idle `codex-code-mode-host`, so nothing was cut, but a bulk plan would have said 35 busy. Fixed below.

*`prove_codex`.* It now also runs `check_settings` after the snapshot checks, so a first seat whose process lacks its settings stops the run: `STOPPED: SEAT: process has no seat settings...`. An inactive first seat now stops on gh unless the `.zshenv` lines are in, so the order for bulk use is `.zshenv`, then the restart.

*Beyond your order, one token, say if you want it out.* `children` no longer lists `codex-code-mode-host`. It lists a process's direct children only, so anything under that helper is not listed; a turn on screen still is.

*The `.zshenv` line.* `zshenv-lines.sh` runs only if the file is exactly the one read, `f519538e...`, and each old line appears exactly once. It keeps a backup at `~/.local/state/zeo-rescue/zshenv.before-20261106` and verifies it, tries the new text in a private copy across inactive, master, no-seat and stray-token shells, under both `-c` and `-lc`, checks the new text is `d33b5930...`, and swaps the file whole. If a shell then disagrees, it puts the original back by itself. Rollback runs only if the file is exactly what apply left. It has **not** been run against the real file: the tests used a copy. `./zshenv-lines.sh verify` says `ORIGINAL` now.

*What it changes when it runs.* It applies to every new zsh, so running seats pick it up in their next shell. Claude seats' tools stay on `gh-master` instead of being reset to `gh-matorclawson`; both answer `matorclawson`. Codex seats not yet restarted have no `GH_CONFIG_DIR` in the process, so they stay as they are. `dt-brandedimage-maintainer` gets gh off, and `make check ARGS='--seat dt-brandedimage-maintainer'` should then read `check: ok 1, wrong 0`.

Apply, for just before the bulk restart, after cleanup settles:

```
if [ "$(id -un)@$(hostname -s)" = "rodbot@Mac-mini" ]; then cd /Volumes/AIPEMedia1/code/zeroemployeeorg/zeorescue && git switch zeo-rescue/seat-bootstrap-20261105 && h=$(/usr/bin/shasum -a 256 zshenv-lines.sh | /usr/bin/cut -d " " -f 1); if [ "$h" = "13416446261a2d8ba553eee22762e9efa4fdadb879dba5acc3ad1f51a2d2336d" ]; then ./zshenv-lines.sh apply; else echo "HASH MISMATCH, nothing was changed: zshenv-lines.sh is $h"; fi; else echo "WRONG PLACE, nothing was changed: you are $(id -un)@$(hostname -s). Open the rodbot terminal on the Mac mini."; fi
```

Expect `Already on 'zeo-rescue/seat-bootstrap-20261105'`, the branch line, then `APPLIED: /Users/rodbot/.zshenv changed, backup at /Users/rodbot/.local/state/zeo-rescue/zshenv.before-20261106. Tell zeo-rescue: done.` `HASH MISMATCH`, `LINES NOT FOUND`, `BACKUP IN THE WAY` or `REFUSED` means nothing changed. `PUT BACK` means it changed and was restored. Bring any of them here.

Rollback, the same way:

```
if [ "$(id -un)@$(hostname -s)" = "rodbot@Mac-mini" ]; then cd /Volumes/AIPEMedia1/code/zeroemployeeorg/zeorescue && git switch zeo-rescue/seat-bootstrap-20261105 && h=$(/usr/bin/shasum -a 256 zshenv-lines.sh | /usr/bin/cut -d " " -f 1); if [ "$h" = "13416446261a2d8ba553eee22762e9efa4fdadb879dba5acc3ad1f51a2d2336d" ]; then ./zshenv-lines.sh rollback; else echo "HASH MISMATCH, nothing was changed: zshenv-lines.sh is $h"; fi; else echo "WRONG PLACE, nothing was changed: you are $(id -un)@$(hostname -s). Open the rodbot terminal on the Mac mini."; fi
```

Expect `ROLLED BACK: /Users/rodbot/.zshenv is the original again. Tell zeo-rescue: done.` If zsh itself is broken, the script needs bash only: `/bin/bash /Volumes/AIPEMedia1/code/zeroemployeeorg/zeorescue/zshenv-lines.sh rollback`.

*Evidence.* `make test`: 159 checks pass, both suites. Broken on purpose in a copy, each caught: `prove_codex` skipping the process; the helper counted as work; apply skipping its hash; rollback skipping its hash; no put-back. The real `.zshenv` still reads `f519538e...`. My runner test wrote two stray logs to the real state folder, `reseat-20261106-044134.log` and `reseat-20261106-044756.log`. They only say the test chart was unreadable, and the test no longer does it.

*Not ready: the bulk restart itself.* `reseat-lines.sh all` would do nothing now: every seat has `@zeo_rescue`, so a reseat reads `OK ...: started by rescue`. Bulk needs its own step, Codex seats only, with a new note, because `notes/reseat-20261105.txt` tells seats they were started wrong. Not built; it waits for the Architect's word.

| File | sha256 |
|---|---|
| `rescue.sh` (changed) | `1f2a22fad65d1c6260ac9fac74e0ba83768b7f1b2a72c4d7cb1fb85cca3868de` |
| `reseat-lines.sh` (changed; a new pin for `rescue.sh`) | `6e818d980c1b6aa3218adeebc8d75c83c0f98985db302d55b6efdffe511119b6` |
| `zshenv-lines.sh` (new; its lines pin it) | `13416446261a2d8ba553eee22762e9efa4fdadb879dba5acc3ad1f51a2d2336d` |
| `seat-exec.sh` (unchanged since line 4) | `9350ecf29e596aa0c3e3c3cc0578780a954842d4f9020c0e351a3ac9cab51810` |
| `~/.zshenv` now | `f519538e482e131efc38b8ed54636d3e435f2d9fa3ad78e15ecad90c9ad44eeb` |
| `~/.zshenv` after apply | `d33b59306ff3c3694ee161990a9d8fc611e13ae9b2b78e8e5f31cf783c62f8ca` |


*Read before clearing: `-lic` alone does not turn gh off.* `~/.zshenv` runs in every zsh, sets `GH_CONFIG_DIR` to `gh-matorclawson` and unsets `GH_TOKEN`. So in a shell without the snapshot, `-lic` keeps `GIT_ALLOW_PROTOCOL=file` and `GIT_SSH_COMMAND=/usr/bin/false` (real shells, measured) and fixes the author, but gh stays on for an inactive seat. That file is on the host, outside this repo, and was not touched. Two lines fix it, tried only on a private copy through `ZDOTDIR`:

```
export GH_CONFIG_DIR="${GH_CONFIG_DIR:-$HOME/.config/gh-matorclawson}"
[ "${GH_TOKEN:-}" = zeo-seat-disabled ] || unset GH_TOKEN; unset GITHUB_TOKEN
```

On that copy: inactive gives gh off, master keeps `gh-master` and the noreply author, a shell with no seat stays on `gh-matorclawson`, and any other token value is still removed. It affects every zsh on this account, so it needs its own ruling. Without it, line 4 ends WRONG on gh, as below.

*Measured, read-only, 03:11 to about 04:30.*

- **GitHub account: right everywhere.** 204 pushes and branch creations across all 19 repos seats pushed to, from GitHub's repo activity: every actor is `matorclawson`. `gh-matorclawson` and `gh-master` both answer `matorclawson`, and the default ssh route says `Hi matorclawson`. So the default-account worry did not bite today. It would for a seat on another account. There is none today.
- **Author: wrong in shells without the snapshot.** 35 Codex commits: snapshot shells 3 of 3 `noreply`; other shells 28 of 29 `mator@aiautomators.club`, 1 `noreply`; 3 unresolved. Seats with that address: ducktyper 6, dt-clipping-maintainer 4, zeo-rt-sched 4, profrod 4, zeo-rt 3, zeoconnect-integrations 3, profrod-site-design 2, zeoconnect-tools 1, dt-brandedimage-maintainer 1. The ones unresolved are zeo-rt-ledger 2, zeoconnect-ui 1.
- **Public repos.** One head committed today carries that address: `profrodai-resources` `8250f7fbf`, a Claude seat's reapplied commit, so the author is original and the committer is `noreply`. The other 15 such heads were committed before today. Claude seats are clean. No history was changed, and nothing needs to be.

*What changed.* `seat-exec.sh`: `-lic` for both harnesses. `rescue.sh`: `check_settings`. It reads `ZEO_TMUX_SEAT`, the account, `GIT_ALLOW_PROTOCOL` and `GH_CONFIG_DIR` from the process, and compares the seat with its pane. It then starts fresh `zsh -lc` and `zsh -c` shells in `/` with those values and asks real git, which refuses before connecting, with ssh as `/usr/bin/false`. It enters no seat, reaches no host, and those four names are all it keeps, so a credential never reaches the probe. `reseat-lines.sh`: step `lic`, which refuses while the seat has a turn on screen, then clears `@zeo_rescue`, because a reseat skips a seat rescue started. `notes/lic-test-20261106.txt`: new and pinned, it tells the seat this is a test and not a crash.

*Evidence.* `make test`: 144 checks pass, and the real tmux suite passed twice more. Broken on purpose in a copy: seat-exec back to `-lc`; the check not called; the `-c` shell skipped (this first slipped through, so a test was added); prompt text winning over the environment; gh not judged; a token passed to the probe. Each is caught. The real-loader suite ran with a fake harness, so **a real Codex under `-lic` is unproved until line 4.**

*`make check` now says `ok 15, wrong 35`.* That is correct, not a new fault: all 35 Codex seats read `process has no seat settings`, until each restarts. It reads `ok 16, wrong 34` only after line 4 and the `.zshenv` lines. `prove_codex` still reads the snapshot alone, so before any bulk use its first-seat proof should read the process too.

| File | sha256 |
|---|---|
| `rescue.sh` (changed) | `5365562760b93a6549ff2beb9058985e9c27ee462ad40fe3f0e18160e0cb77fb` |
| `seat-exec.sh` (changed) | `9350ecf29e596aa0c3e3c3cc0578780a954842d4f9020c0e351a3ac9cab51810` |
| `reseat-lines.sh` (changed; the line pins it) | `aa8d8a8e766bcca84d8bd0c624d41043263778fcbce984205bbbf5a310e2c32d` |
| `notes/lic-test-20261106.txt` (new) | `be3c80bbd7d676af647df90b340eb973b3117b6146130eff954490edf379a4c2` |

*Line 4, DONE at 04:49:26, see the block above. The record:* it restarts that seat only, and the seat loses network git in every folder:

```
if [ "$(id -un)@$(hostname -s)" = "rodbot@Mac-mini" ]; then cd /Volumes/AIPEMedia1/code/zeroemployeeorg/zeorescue && git switch zeo-rescue/seat-bootstrap-20261105 && h=$(/usr/bin/shasum -a 256 reseat-lines.sh | /usr/bin/cut -d " " -f 1); if [ "$h" = "aa8d8a8e766bcca84d8bd0c624d41043263778fcbce984205bbbf5a310e2c32d" ]; then ./reseat-lines.sh lic; else echo "HASH MISMATCH, nothing was run: reseat-lines.sh is $h"; fi; else echo "WRONG PLACE, nothing was run: you are $(id -un)@$(hostname -s). Open the rodbot terminal on the Mac mini."; fi
```

Expect, ending, with `.zshenv` unchanged:

```
RESEAT dt-brandedimage-maintainer: codex 01a18e5d-9ea5-7631-8716-08c91cd8d65c (-a never -s danger-full-access; no marker, recorded inactive) in dt-brandedimage-maintainer
work: 0 of 1 seats show running work
RESUMED dt-brandedimage-maintainer: codex 01a18e5d-9ea5-7631-8716-08c91cd8d65c (-a never -s danger-full-access; no marker, recorded inactive) in dt-brandedimage-maintainer
FIRST SEAT OK dt-brandedimage-maintainer: own identity
rescue: live 0, ok 0, running 0, to resume 0, to reseat 1, resumed 1, unresolved 0, failed 0
WRONG dt-brandedimage-maintainer (codex): a shell outside its folder has gh on
check: ok 0, wrong 1
```

With the `.zshenv` lines first, the last two lines read `OK dt-brandedimage-maintainer (codex)` and `check: ok 1, wrong 0`. `BUSY` means nothing ran; try again. `STOPPED`, or any other `WRONG`, is a real failure: stop, start nothing by hand, and bring it here. The pass that matters comes after: a real tool shell outside its folder must show `transport 'ssh' not allowed` in its rollout. zeo-rescue reads that from the rollout; nobody types into the seat.


*Cause.* Git-off on a Codex seat lives only in its shell snapshot, and Codex 0.164.0 skips the snapshot for many tool shells. `~/.config/zeo-tmux-seats/activate.zsh`, sourced from `~/.zshrc`, sets `GIT_ALLOW_PROTOCOL=file`. `seat-exec.sh` starts Codex seats with `zsh -lc`, which does not read `.zshrc`, so the Codex process never has the setting. Tools only get it from the snapshot.

`TurnEnvironment::shell_snapshot` in `codex-rs/core/src/session/turn_context.rs`, tag `rust-v0.164.0` (the installed CLI reports 0.164.0), returns no snapshot unless the tool's directory equals the thread's directory and the flag is `-lc`, without the credential broker. So a `workdir` elsewhere, or `"login":false`, gives a shell without the snapshot. Do not rely on the doc comment on `main`: it describes this check, but the check is in the caller.

*Evidence, rows read by hand, inactive seats after line 3.* Own directory with `-lc`: 2 of 2 refused (brandedimage `git fetch`, hud-editor `ls-remote`). Snapshot skipped: 7 of 7 not refused: brandedimage 2 pushes and 2 `ls-remote` shas (other directory); hud-editor reached https (other directory); animated-comics-editor reached https (other directory, `-c`) and ssh (own directory, `"login":false`, which looked like an exception until the flag was read). Those last three then failed on DNS, so they prove only that git did not refuse.

*Scope.* The 3 `workspace-write` editors have no network from tools, so **`dt-brandedimage-maintainer` is the only inactive seat where git-off fails in practice.** Across all 35 Codex seats, 534 of 1,239 commands since line 3 skipped the snapshot. Those shells also lack the loader's other settings: `GIT_SSH_COMMAND`, `GH_CONFIG_DIR`, `GIT_AUTHOR_*`, `GIT_COMMITTER_*`, `GIT_CONFIG_*`, `ZEO_TMUX_SEAT`. `ZMAIL_INSTANCE` is unaffected: it is in the process environment. Every seat is `master` or inactive today, so a push from such a shell is expected to use the default account. That was not measured, and it would matter for a seat on another account. The author on commit `88216fa` was the default one.

*Correction.* The block below says 4 inactive seats have git off, and `make check` proves that from snapshots only. True for the snapshot; not for every shell in that seat. The cleanup pushes were under the Architect's order, and nothing needs undoing.

*Options, none applied; `seat-exec.sh` is pinned, so either means a new read, new pins and a restart of the seat by the operator.* (a) Smallest: put `GIT_ALLOW_PROTOCOL=file` in `seat-exec.sh`'s clean environment for a seat with no marker. That closes git-off in every shell, only for inactive seats. Recommended first. (b) Wider: `-lic` for Codex as for Claude, so all loader settings reach the process. It fixes the whole class, but changes every Codex seat's start and needs testing first. Either way, the snapshot-only proof in `rescue.sh` stays a partial check.


*Read from the seats, not only from `make check`:*

- The daemon is gone: no app-server process. 35 Codex seats, all `--no-daemon`, no thread with two processes, plus 15 Claude seats.
- All 35 Codex seats have a snapshot with their own identity: 31 with marker `master` and git on, 4 `inactive` with `file`.
- 34 Codex rollouts since 03:17:50: at least 721 tool calls, 0 error events. So the 0.164 CLI resumed every thread, including those the 0.167 daemon had written.
- Network git works: 29 real pushes from 14 git-on seats, counted from git's own `To github.com` output. Text quoting older refusals was excluded. The only real refusals are 2, both on `inactive` seats. "failed to push" text on `zeo-rt`, `zeo-rt-pr`, `zeo-rt-ledger` and `ducktyper` comes from the repos' own preflight (`PUSH BLOCKED`), not from transport.

*Not checked:* real tool calls on the 15 Claude seats beyond `make check`, and whether every seat's work is healthy. Processes and a passing check do not mean the org is recovered.

*New, for the Architect, cause unknown:* `dt-brandedimage-maintainer` is `inactive`, and its snapshot has `GIT_ALLOW_PROTOCOL=file`. Its `git fetch origin` was refused, yet two plain `git push origin` calls landed on GitHub (branches `cleanup/dt-brandedimage-maintainer/...` on the fork). Its commands set nothing and changed nothing, so this does not look like a workaround. But "inactive means git off" did not hold for those pushes. zeo-rescue changed nothing and did not find the mechanism.

*Also seen:* `dt-comic-slides-editor` (`workspace-write`) cannot resolve `messenger.zeo.ac` from its tools, so its report did not go by mail. It saved a recovery note instead. Windows 1 and 2 of `zeoruntime-maintainer` (the calendar and org-chart schedules) were not touched by the reseat.

*Still open from before:* the cause of the teardown, ENG-UK, SOW-18, the collector install (operator's), this seat's mailbox, and the integration branch (unused, unpushed, needs the anchor fix at 202 and 206).


The Architect's clearance is on their screen at 03:12, Do 240: the same line as line 3 below, with `git switch` to this branch first. Their checkpoint is written. Expected end: `check: ok 50, wrong 0`.

*Proved by the seat's own rollout since the resume:* `zmsg whoami` as its own seat, and real tool calls, including an `ls-remote` over the network that returned a sha, with no "not allowed" in any output. *Not proved:* a push, and a resume of a thread last written by 0.167. The Architect tests a push after line 3.

*Fresh read at 03:12:* `work: 0 of 48`, `ok 2, to reseat 48`, `check: ok 2, wrong 48`. A work read of 0 is weak evidence on Codex panes, and the proof seat is working: it answered its cleanup mail.

*Settled:* the move to `main` at 03:08:17 was `git switch main`, `git fetch`, `git pull`, typed in a terminal on this account (`~/.zsh_history`), so nothing automatic moved it. It must not happen during line 3: that would take `seat-exec.sh` away from every seat still to start. After line 3, write its `make check` result here.


*The daemon updated itself to 0.167.0 at 02:07Z.* The pids are now 16463 and 44131, and the expected output below is corrected to match. Those pids can change again if it updates again. The stop finds the daemon by its path, not by version or pid, so nothing pinned changes. The proof seat's rollout was last written by 0.164.0, so **line 2 does not prove a resume of a thread last written by 0.167.** Only line 3 meets that.

*This checkout moved.* At 03:08:17 the checkout went to `main` (settled in the block above). Line 2 then ended in `HASH MISMATCH`, because `reseat-lines.sh` was not there. Nothing ran and nothing was lost. zeo-rescue switched back to this branch at about 03:11: pins verify, tree clean, tip `cd4f64d` before this note. The line the Architect filed at 03:09 on Do 233 starts with `git switch` to this branch, so it survives the same move.


*Correction.* zeo-rescue's report and the 22:50 block below were wrong. A real Codex resume **did** run, at 21:54 (`reseat-lines-proof-20261105-215422.log`). The seat came up right: snapshot `01a16ed4-...1793915665310966000.sh` has git on, `master` and its own identity at lines 13885, 13928 and 13929. The proof then false-stopped on the loader function's `export GIT_ALLOW_PROTOCOL=file` at line 13585, and `unseat` killed the session. That is why it is gone; its sleep did not run out. zeo-rescue said otherwise without reading the log, and recommended a rerun that would have stopped the same way. Line 3 would have stranded the org. The seat started its turn at 21:54:27 and made no tool call, so it left nothing half-done. The Architect found this.

*The fix, `dfa5121`.* Five greps gain `^export `, so they read only top-level exports. Line 217 is the Architect's finding. **Lines 196, 210, 214 and 216 go beyond it:** they read the same snapshot with the same flaw, and could pass on text inside a function. Each is one token. Say if you want them out. `rescue-test.sh` gains five checks on snapshots that contain the loader.

*Evidence.* The real 21:54 snapshot through the real `prove_codex`: `STOPPED` before the fix, `FIRST SEAT OK ...: own identity, marker master, git on` after. A real snapshot of a seat started wrong (`dt-clipping-maintainer`) still stops. The anchored pattern says git on for 26 of 26 pre-fault `master` snapshots and off for all 34 seats started wrong. `make test`: 124 checks pass. Removing the anchor from the git line fails 3 of them.

| File | sha256 |
|---|---|
| `rescue.sh` (changed) | `f4a3639a1d210624eb0a6d241e562ca04d1688b55f49d4fd1bc87b60a09cbe0f` |
| `reseat-lines.sh` (changed; each line pins it) | `e2bd46988ffc34d4caf4d7b8ba4a7b128a363553f97d87948391b334914d0b12` |

The other pins are unchanged. The three lines and the hash table in section 2 below carry these values. `./reseat-lines.sh verify` passes.

*Line 2 now.* The seat is dead, so it reads `RESUME`, not `RESEAT`, and a rerun cuts nothing. Expect, ending:

```
work: 0 of 0 seats show running work
DAEMON LEFT: 34 Codex seats are still attached to pids 16463 44131
RESUMED dreamhuggers-expenses-maintainer: codex 01a16ed4-0b39-7932-a8d2-58482012b62d (-a never -s danger-full-access; marker master, recorded) in dreamhuggers-expenses-maintainer
FIRST SEAT OK dreamhuggers-expenses-maintainer: own identity, marker master, git on
rescue: live 0, ok 0, running 0, to resume 1, to reseat 0, resumed 1, unresolved 0, failed 0
OK dreamhuggers-expenses-maintainer (codex)
check: ok 1, wrong 0
```

Line 3's expected output below is unchanged. *Still unproved:* a Codex seat through to a passing `make check`, and any real tool call in a seat with git on.

*Integration branch.* Not changed in code and not pushed. It has the same flaw at its lines 202 and 206, and needs this fix before it is used. Its own line 206 is the Architect's second finding: it requires `file` to appear, which the loader function always satisfies.

**22:50 GMT: the council's return is integrated on a branch, and not in use.** Branch `zeo-rescue/council-integration-20261105`, tip `0daced5`, local only; start at `council/INTEGRATION.md` there. Baseline `af45115`. The Architect has not read it, so its pins are deliberately stale and its runner refuses. **This checkout stays as it is, and the lines cleared at `10f408f` still verify.** Nothing is installed, and no seat was started or stopped. As delivered the candidate left all 49 seats unresolved and neither rescuer could start on bash 3.2; both are fixed there. The next decision is the operator's or the Architect's: held; see the 23:15 block. (Corrected at 23:15: the session went at 21:54, when the proof false-stopped. See above.) Taking the integration into use needs the Architect's read, then new pins and new operator lines.

**15:40 GMT: with the external council, by the operator's decision.** The Architect is busy, so the operator is sending this to the external council instead of waiting. The packet is `council/README.md`, on the public branch `zeo-rescue/council-review-20261105`. The next step is still undecided: line 2 is not rerun and line 3 is not run until the operator says so. Fixes come back as a branch or patch, are not merged or run on arrival, and a change to a pinned file still means new pins and the Architect's read. New gap, in the packet: the `WORK` busy check is unproven on Codex panes, so `work: 0` on a Codex seat is weak evidence.

**HELD at ending B, for the Architect's decision (15:35 GMT). Do not run line 3.** The operator ran line 2 at 15:25:59. It ended B: `FAILED dreamhuggers-expenses-maintainer: pid 28371 still holds its rollout`, `resumed 0, failed 1`. Log: `~/.local/state/zeo-rescue/reseat-lines-proof-20261105-152559.log`. The seat was idle (`work: 0 of 1`), so nothing was cut. It is down on a sleep with no mark, and no second writer ran.

Measured afterwards, read only:

- The daemon let go about 60 seconds after the client left. Its log at 15:27:00: `thread 01a16ed4-... has no subscribers and is idle; shutting down`, then `Agent loop exited`, with `had_active_turn=false`. The guard waits 30 seconds, so it refused half a minute too soon.
- At 15:32:48 `lsof` found no holder, pid 28371 held 37 rollouts (was 38), and the rollout's mtime was still 12:42. No harness holds the thread. So the F1 worry about a thread kept in memory after its file closes did not happen on this seat: its agent loop exited.
- This is one idle seat. A seat with a turn running may not shut down this way; line 3 does not depend on it, because the daemon stops there.

Recommendation to the Architect: rerun line 2 unchanged. Nothing pinned changes, the hash stands, and it cuts nothing because the seat is already down. Expect ending A. That gets the real Codex proof before line 3, with 34 seats still up. After about 16:26 the sleep runs out and the session closes; the same line then reads `to resume 1, to reseat 0, resumed 1`, also clean. The other choice is to go straight to line 3, where the first real Codex test comes with every Codex seat down. Only if a seat must be refused less often does the 30-second wait need changing, and that is a pinned file and a new read.

### For the Architect: your findings, and what changed

Their review is the 13:57 reply to `msg-zeoarchitect-sow18-operator-lines`. This seat has no mailbox and may not use `zeoarchitect`'s, so it was read in the Architect's own transcript, line 307025, not from the mail.

- **F1, stated plainly.** The 13:55 line 1 was unsafe as filed: `rescue.sh` tested only process arguments, and the app-server (pid 28371) holds 38 rollouts open, including this seat's: `lsof` names 28371. Now a Codex seat starts only when `lsof` finds nothing holding its rollout, tried for 30 seconds, after the daemon stop. That is what makes the proof safe. **Unknown until it runs:** whether the daemon lets go of a thread when its client leaves. So line 2 has two safe outcomes, below. **Remaining risk:** the test sees a file held open now. If the daemon closes the file but keeps the thread in memory and reopens it later, the guard would not see that. So run line 3 soon after line 2; the daemon stops there. Line 2 also cuts any turn in flight on that seat.
- **F2.** Line 3 still stops every harness before any seat starts, because that is what prevents two writers. If a proof fails, the wrong seat is stopped again and loses `@zeo_rescue`; it used to stay up, and the next run skipped it as done. The operator sees `STOPPED:` and `RECOVERY:`, below. What recovers it: the same line again once the cause is fixed.
- **F3.** Each line is a user@host check printing WRONG PLACE, and a pin on `reseat-lines.sh`, whose own pins print HASH MISMATCH on any change to the six files below. All three strings were run in zsh with the step changed to `verify`. The host string is `Mac-mini`, measured with `hostname -s`; `matormini` is the chart's name and would always refuse. No line contains an asterisk.
- **F4.** `WORK` lines list what a restart cuts, in `make reseat-plan` and again just before a run stops anything, so the run's log keeps it: a turn on the screen, a tool shell, and tools under the daemon, where Codex tools run. It lists; it does not stop the run. A seat can be mid-turn with nothing to see. At 14:17: `work: 1 of 49`, `zeoconnect-ops` running a test script. It changes by the minute, so read it fresh: `make reseat-plan ARGS='--before 202611050511'`.

**Three things you have not seen.**

1. **New line, for your ruling.** The 13:55 expected output was wrong. A bulk reseat also resumes dead seats, so `zeoarchitect` would have come up in line 2 with the generic note, without the one that says which mail is not its own. Now it goes first, alone, with its own note, and `all` refuses with OUT OF ORDER until it is up. It is also a real Claude proof that cuts no live work.
2. **Your checkpoint.** You agreed to line 3 restarting you, and said you write a checkpoint first. You are first in chart order, so it restarts you in its first minutes, and any watcher in your shell goes with it. The operator should hear from you that the checkpoint is written before line 3.
3. **Version.** The daemon is 0.166.0 and `codex` on the path is 0.164.0, so a seat resumes threads last written by a newer version. The flag is real (`codex resume --help`), but the real resume has never run. Line 2 is the first test of it.

**Evidence.** `make test`: 119 checks, both suites pass, including a real process holding a real file refused by real `lsof`, and a failed seat taken back by a real rerun. Fake harnesses still: no real seat has run this path. Your rulings 1, 2 and 4 from the 13:55 message are unchanged; the proof seat is still `dreamhuggers-expenses-maintainer`. The zbs item is closed: it passed the trust prompt about 14:00.

### The lines

Hashes are SHA-256. The runner at `7137a3f`:

| File | sha256 |
|---|---|
| `reseat-lines.sh` (pinned by each line) | `e2bd46988ffc34d4caf4d7b8ba4a7b128a363553f97d87948391b334914d0b12` |
| `rescue.sh` (pinned by the runner) | `f4a3639a1d210624eb0a6d241e562ca04d1688b55f49d4fd1bc87b60a09cbe0f` |
| `seat-exec.sh` (pinned by the runner) | `004d9255cd6475a3d252855ed00a46bdb5c3ee5fd8d79c64f7d03d2f1a48e159` |
| `Makefile` (pinned by the runner) | `141ca64943f20b5991654b2f7f3f2301010737eaf5a280a71fde63e9bb80c871` |
| `session-pins` (pinned by the runner) | `6d2ea61a03a67aa954709939aa6cd5e4e71d1286e72116114eb5c37b5967fda2` |
| `notes/reseat-20261105.txt` (pinned by the runner) | `ead62f6999df0115aaf2d4e3b29595528bea57ad7f9972bab10a8f652a9e8029` |
| `notes/zeoarchitect-resume.txt` (pinned by the runner) | `6d0b0155f9493f1e7909d03acec0133b0f11ea8aad2c35fd6c321e3d358c0c2b` |

**Line 1: resume `zeoarchitect`.** A dead seat, with its own note. A minute or two.

```
if [ "$(id -un)@$(hostname -s)" = "rodbot@Mac-mini" ]; then cd /Volumes/AIPEMedia1/code/zeroemployeeorg/zeorescue && h=$(/usr/bin/shasum -a 256 reseat-lines.sh | /usr/bin/cut -d " " -f 1); if [ "$h" = "e2bd46988ffc34d4caf4d7b8ba4a7b128a363553f97d87948391b334914d0b12" ]; then ./reseat-lines.sh zeoarchitect; else echo "HASH MISMATCH, nothing was run: reseat-lines.sh is $h"; fi; else echo "WRONG PLACE, nothing was run: you are $(id -un)@$(hostname -s). Open the rodbot terminal on the Mac mini."; fi
```

Expect, ending:

```
FIRST SEAT OK zeoarchitect: own identity, marker master, git on
rescue: live 0, ok 0, running 0, to resume 1, to reseat 0, resumed 1, unresolved 0, failed 0
OK zeoarchitect (claude)
check: ok 1, wrong 0
result kept in ...; exit 0. Tell zeo-rescue: done.
```

Any `STOPPED:` or `WRONG`: stop there. Only `zeoarchitect` is affected, and it goes back to dead, so this line can be run again.

**Line 2: one Codex seat, beside the daemon.** About two minutes.

```
if [ "$(id -un)@$(hostname -s)" = "rodbot@Mac-mini" ]; then cd /Volumes/AIPEMedia1/code/zeroemployeeorg/zeorescue && h=$(/usr/bin/shasum -a 256 reseat-lines.sh | /usr/bin/cut -d " " -f 1); if [ "$h" = "e2bd46988ffc34d4caf4d7b8ba4a7b128a363553f97d87948391b334914d0b12" ]; then ./reseat-lines.sh proof; else echo "HASH MISMATCH, nothing was run: reseat-lines.sh is $h"; fi; else echo "WRONG PLACE, nothing was run: you are $(id -un)@$(hostname -s). Open the rodbot terminal on the Mac mini."; fi
```

Expect one of three endings.

A, the daemon let go. The proof holds, and line 3 can follow:

```
DAEMON LEFT: 34 Codex seats are still attached to pids 16463 44131
RESUMED dreamhuggers-expenses-maintainer: codex 01a16ed4-0b39-7932-a8d2-58482012b62d (-a never -s danger-full-access; marker master, recorded) in dreamhuggers-expenses-maintainer
FIRST SEAT OK dreamhuggers-expenses-maintainer: own identity, marker master, git on
rescue: live 0, ok 0, running 0, to resume 0, to reseat 1, resumed 1, unresolved 0, failed 0
OK dreamhuggers-expenses-maintainer (codex)
check: ok 1, wrong 0
```

B, the daemon kept it. Safe: the guard worked, and no second writer started. That one seat stays down on a sleep until line 3, so the Codex path is still unproved, and the first real test falls inside line 3 with every Codex seat down. **The Architect decides whether line 3 still goes.**

```
FAILED dreamhuggers-expenses-maintainer: pid 44131 still holds its rollout, so it was not started: that would be two writers
rescue: live 0, ok 0, running 0, to resume 0, to reseat 1, resumed 0, unresolved 0, failed 1
```

C, the proof failed. Do not run line 3. One seat is down and the cause is in the launch; zeo-rescue finds it.

```
STOPPED: dreamhuggers-expenses-maintainer ...; no other seat was started
RECOVERY: 1 seats are down, counting the one that failed. ...
```

**Line 3: every other seat.** About 18 minutes. All harnesses stop, then the daemon, then seats start 20 seconds apart. In-flight turns are cut.

```
if [ "$(id -un)@$(hostname -s)" = "rodbot@Mac-mini" ]; then cd /Volumes/AIPEMedia1/code/zeroemployeeorg/zeorescue && h=$(/usr/bin/shasum -a 256 reseat-lines.sh | /usr/bin/cut -d " " -f 1); if [ "$h" = "e2bd46988ffc34d4caf4d7b8ba4a7b128a363553f97d87948391b334914d0b12" ]; then ./reseat-lines.sh all; else echo "HASH MISMATCH, nothing was run: reseat-lines.sh is $h"; fi; else echo "WRONG PLACE, nothing was run: you are $(id -un)@$(hostname -s). Open the rodbot terminal on the Mac mini."; fi
```

Expect `WORK` lines and a `work:` count, then, ending:

```
DAEMON STOP: exact pids 16463 44131
FIRST SEAT OK architect: own identity, marker master, git on
FIRST SEAT OK dt-animated-comics-maintainer: own identity, marker master, git on
rescue: live 0, ok 2, running 0, to resume 0, to reseat 48, resumed 48, unresolved 0, failed 0
check: ok 50, wrong 0
```

`DAEMON KILLED` lines may appear, and the pids can change again if the daemon updates itself. After ending B the count reads `ok 1, to reseat 49, resumed 49`. Any other `WRONG` is real.

**If a proof fails in line 3.** The output shows `STOPPED:`, then one of these (one more seat after ending B):

- `RECOVERY: 48 seats are down`: the Claude proof failed on the Architect, so the Architect is down too. The operator reports to this seat.
- `RECOVERY: 47 seats are down`: the Codex proof failed. The Architect is up; every other seat is down.

Each thread is intact and nothing is lost, but the org is down until the cause is fixed. Start no seat by hand. Run the same line again after the fix: seats on a sleep are planned again, and after an hour their sleeps run out and they come back as `RESUME`. Any change to a pinned file means new pins and a new read by the Architect.

**After it:** `make check` must end `check: ok 50, wrong 0`. Git and the deck render (`dt-comic-slides` is holding it for the identity problem) are waiting on this. Commit `7137a3f` is local: PR #1 needs a push, and the Architect still has to re-read the routing.

**3. The cause of the teardown** is still unknown. The operator cannot share the log, and does not need to: they run `make teardown-log` once (sudo), and you read `~/.local/state/zeo-rescue/teardown-*.log` yourself. Grep around 05:10:48 for `loginwindow`, `launchd`, `sessionlogoutd`, `shutdown`, `logout`, `jetsam` and `sshd`. The first SSH login from a tailnet address (it is in the first rescue's transcript) was at 05:10; that is timing, not a cause. Do it soon: `--info` does not stay in the log for long.

**4. ENG-UK** (`pomar-cc`, `pomar`, `zeo-rt-seats`) has not been checked.

**5. Then SOW-18** (below). When it is done and the org is healthy, stop. That is the design.

## What happened

- **05:10:48**: the `rodbot` login session was torn down, with about 219 processes and the `zeo2` tmux server. Not a reboot, and no drive was ejected.
- **05:53 to 05:58**: 14 Claude seats resumed by hand with a one-shot unreleased `zmsg-claude-wake`, which goes against Messenger's "never run unmerged code"; disclosed to the Architect. All with no `@zeo_seat`, so git is off in all of them. `zbs` stopped at the trust prompt.
- **05:56**: one Codex proof seat, `dt-hud-editor`, started the shared app-server daemon.
- **06:04**: the Architect replied: do not hand the operator `make rescue`, it reproduces the 25 Oct fault (`ans_8f61922d`). The first rescue's last check was at 06:03. It missed the mail and gave the operator the command.
- **12:13**: the operator ran it. All 34 seats joined the daemon: `ZMAIL_INSTANCE=dt-hud-editor`, `ZEO_TMUX_SEAT=inactive`, `GIT_ALLOW_PROTOCOL=file`.
- **12:41**: the Architect told every seat. Seats stopped outward work.
- **13:40**: the fault was found by the rescue seat and reported. Of 1476 tool calls after 12:13, 408 touched mail; no statement that writes mail lacked the seat's own prefix (3 textual hits, all in message bodies). That is a grep, not a proof: a script spawning `zmsg` indirectly could escape it. Network git failed for those seats for about 90 minutes.
- **14:00**: the operator made `zeo-rescue` a seat with this repo.
- **14:03 to 14:20**: the first session of this seat found the Architect's 13:57 rejection of the lines (F1 to F4), which had gone to the `zeoarchitect` mailbox, in the Architect's transcript. It fixed all four (`7137a3f`), found that a bulk reseat would have started `zeoarchitect` with the wrong note, and filed the lines here. No seat was touched, and nothing was pushed. The Architect's word: nothing runs until they have read this file and the operator has seen it.

## Seat markers (read from each seat's record, `--before 202611050511`)

| Marker | Seats |
|---|---|
| `master`, recorded | 25 Codex seats |
| `master`, no record, default | all 14 Claude seats and 6 Codex seats. The Architect ordered `master`. |
| none, recorded inactive | `dt-hud-editor`, `dt-brandedimage-maintainer` |
| none, no record, workspace-write | `dt-comic-slides-editor`, `dt-animated-comics-editor` |

The last two rows differ from the Architect's order to mark every seat. They ran without git before the crash, and giving it to them would be a widening nobody decided. The Architect has been told, and the ruling is theirs. `dt-hud-editor` also cannot be the proof seat: its id is the fault's own, so "it has its own identity" would prove nothing.

## Open items and who holds them

**The `zeo-rescue` seat itself**
- Mailbox: agreed by the Architect (`ans_8f61922d`). The nodes-file line goes on the operator's page after the seats are back, not before. The store-host record and the nodes file are the operator's.
- Org chart row: the Runtime's, through the Architect. Mark it so `make rescue` never treats it as a seat to resume; `rescue.sh` skips the id anyway.
- This repo's routing: the Architect ruled that the tool, then at `tools/zeo-rescue`, goes by PR to main with the full gate, both readers and their signature, and the SOW by ledger carry. That ruling predates this repo. PR: https://github.com/matorclawson/zeorescue/pull/1, unmerged; they need to re-read it. Until it merges, this checkout must stay on branch `zeo-rescue/seat-bootstrap-20261105`: `main` holds only a README.

**SOW-18** (`zeoarchitect-SOW-18`, on branch `zeoarchitect/sow-18-seat-recovery` of `matorclawson/org-zeroemployeeorg`, clone at `/Volumes/ZeoWork/zeoarchitect/records`). Not yet carried to the org. It is this seat's to finish: the operator's plan is that rescue sleeps once the wake refactor is done and everything is awake again.

The Messenger owner answered **AGREE with amendments** (`ans_f0594ddf`):
- **A1.** Their `wt-doorbellcause-20261104` (8aab021d, adebc133) gates first, then SOW-18 rebases on it. Do not move `doorbell.go` or `outage.go` before those merge. `outage.go` moves into the shared package unchanged in behaviour.
- **A2.** `zmsg doorbell --should-ring` stays the one test of whether a Claude seat is served. `zmsg-claude-wake` calls it and does not re-derive it. That also covers the live-but-deaf case.
- **A3.** Removing the Claude doorbell from codex-wake ships in the same release as claude-wake's ringing, or the Mac mini loses its only Claude doorbell. The PR says how the swap is staged. No waker restart on the mini except on the Architect's word.
- **A4.** Seat id = mailbox id, never renamed. The tmux-label map goes in `deploy/seats.json` as a new optional key; the validator refuses empty and duplicate labels. The owner reviews that change.

Code so far: `zeomessenger/wip/claude-wake-20261105` @845a656 on `matorclawson/zeomessenger`, worktree `/Volumes/ZeoWork/zeoarchitect/wt/zeomessenger-claude-revive`. Tests pass under `-race`; `make verify` has not run. Its launcher has the same fault: it uses `zsh -ic` with no marker. It must take `rescue.sh`'s launch path before it is ever run again. The daemons are unreleased, and never installed.

**Identity, ruled by the Architect (`ans_8f61922d`), carried by others**
- `aipengineer-site-maintainer`: the operator reversed the old ruling. zeomessenger gives it a mailbox, the Runtime a chart row, no node until it is seated.
- `zeoerp` / `zeoerp-maintainer`: one seat, id `zeoerp-maintainer`, `zeoerp` kept as a mapped label. zeomessenger owns the merge, and no history is dropped.

## Operator rulings to keep

- Names: `zmsg-harness-wake`, `zmsg-codex-wake`, `zmsg-claude-wake`. "Revive" is retired.
- One-way graph: harness-wake writes spool doorbells, no daemon calls another, and codex-wake loses `runtime: claude`.
- Ids: unique; seat and mailbox are 1-1; session names and the rest are mapped labels; no seat, mailbox or history is dropped.
- Rescue is on-demand, and lives in this repo. If the system collapses, the operator runs `claude` here.

## Known limits

- The newest transcript in a directory is assumed to be the seat's. A second session run there defeats that; `session-pins` is the remedy, and `make plan` shows what was chosen.
- `make check` proves a Claude seat's identity from its process environment, and a Codex seat's from its newest snapshot and `--no-daemon`. It does not prove git works end to end.
- The org chart's collector stopped at 05:10 with the Runtime seat. Rescue uses the last good copy, and says so. `zmsg-claude-wake` refuses a chart over 2 hours old.

## Where things are

- First rescue's transcript: `~/.claude/projects/-Volumes-AIPEMedia1-code-zeroemployeeorg-zeoarchitect/c41e8c97-fd7a-47cb-8571-ee92a54b260b.jsonl`. It is long; use grep. It holds only history that this file does not need.
- Run logs and prompts: `~/.local/state/zeo-rescue/`.
- The Architect's earlier restore: `/Volumes/ZeoWork/tmp/claude-architect/restore-20261105/` (v4, which never touches a live session). Their memory of it: `~/.claude/projects/-Users-rodbot-code-zeroemployeeorg-org/memory/seat-restore-after-reboot.md`.
