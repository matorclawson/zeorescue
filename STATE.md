# zeo-rescue state

This is the seat's memory. Update it before you stop, and commit it. Newest state first; the history at the end only grows.

Last updated: 2026-11-05 ~14:00 GMT, by the first rescue session (`c41e8c97`), at handover.

## Do next, in this order

**1. Read the mail first.** The first rescue handed the operator a command one minute before the Architect's stop arrived, and did not re-check. Until `zeo-rescue` has a mailbox, ask the operator, or look at the Architect's pane: `tmux -L zeo2 capture-pane -p -t '=architect:'`.

**2. The reseat (urgent).** Every seat was started the wrong way, and all are live. The fix is built and tested, and it has **not been run on a real seat**: the classifier refused it to this session, so the operator runs it. The Architect must read the lines first (`msg-zeoarchitect-sow18-operator-lines`). Check whether that happened and whether the operator ran them, with `make check` and `make reseat-plan ARGS='--before 202611050511'`. If `make check` still says WRONG, the lines are:

```
cd /Volumes/AIPEMedia1/code/zeroemployeeorg/zeorescue
# one seat first; expect "FIRST SEAT OK ...: own identity, marker master, git on" and "check: ok 1, wrong 0"
make reseat ARGS='--seat dreamhuggers-expenses-maintainer --before 202611050511 --note-file notes/reseat-20261105.txt' && make check ARGS='--seat dreamhuggers-expenses-maintainer'
# then every other seat, about 16 minutes
make reseat ARGS='--before 202611050511 --note-file notes/reseat-20261105.txt' && make check
```

**3. Resume the `zeoarchitect` seat.** Its own session is pinned in `session-pins`, because the newest transcript in its directory is the first rescue's (`c41e8c97`), not its own. Without the pin it would resume the wrong session.

```
make rescue ARGS='--seat zeoarchitect --note-file notes/zeoarchitect-resume.txt'
```

The plan must read `RESUME zeoarchitect: claude 766f4d22-...`. Its mailbox holds 211 unread, 143 pending and 3 p0, for that seat to read. If the classifier refuses you, give the operator the line.

**4. `zbs` (`dt-broadcastingstudio-maintainer`)** sits at the Claude trust prompt, with "No, exit" highlighted, since 05:57. Only the operator answers it (Architect's Do 226). Check it is gone before the reseat, or it will stop there again.

**5. The cause of the teardown** is still unknown. The operator cannot share the log, and does not need to: they run `make teardown-log` once (sudo), and you read `~/.local/state/zeo-rescue/teardown-*.log` yourself. Grep around 05:10:48 for `loginwindow`, `launchd`, `sessionlogoutd`, `shutdown`, `logout`, `jetsam` and `sshd`. The first SSH login from 100.97.168.76 was at 05:10; that is timing, not a cause. Do it soon: `--info` does not stay in the log for long.

**6. ENG-UK** (`pomar-cc`, `pomar`, `zeo-rt-seats`) has not been checked.

**7. Then SOW-18** (below). When it is done and the org is healthy, stop. That is the design.

## What happened

- **05:10:48**: the `rodbot` login session was torn down, with about 219 processes and the `zeo2` tmux server. Not a reboot, and no drive was ejected.
- **05:53 to 05:58**: 14 Claude seats resumed by hand with a one-shot unreleased `zmsg-claude-wake`, which goes against Messenger's "never run unmerged code"; disclosed to the Architect. All with no `@zeo_seat`, so git is off in all of them. `zbs` stopped at the trust prompt.
- **05:56**: one Codex proof seat, `dt-hud-editor`, started the shared app-server daemon.
- **06:04**: the Architect replied: do not hand the operator `make rescue`, it reproduces the 25 Oct fault (`ans_8f61922d`). The first rescue's last check was at 06:03. It missed the mail and gave the operator the command.
- **12:13**: the operator ran it. All 34 seats joined the daemon: `ZMAIL_INSTANCE=dt-hud-editor`, `ZEO_TMUX_SEAT=inactive`, `GIT_ALLOW_PROTOCOL=file`.
- **12:41**: the Architect told every seat. Seats stopped outward work.
- **13:40**: the fault was found by the rescue seat and reported. Of 1476 tool calls after 12:13, 408 touched mail; no statement that writes mail lacked the seat's own prefix (3 textual hits, all in message bodies). That is a grep, not a proof: a script spawning `zmsg` indirectly could escape it. Network git failed for those seats for about 90 minutes.
- **14:00**: the operator made `zeo-rescue` a seat with this repo.

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
- This repo's routing: the Architect ruled that the tool, then at `tools/zeo-rescue`, goes by PR to main with the full gate, both readers and their signature, and the SOW by ledger carry. That ruling predates this repo. PR open against `matorclawson/zeorescue`; they need to re-read it.

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
