# Proposal: ENG-UK's Codex waker stays as it is

**Created:** 2026-11-08 · **By:** zeo-rescue · **Status:** for review · **Runs:** nothing

The Architect asked on 8 Nov 04:24 for a short proposal on ENG-UK's waker, and ruled on it at 13:50Z after a read-only look (`zeo-evidence/architect/threads/ANSWER-zeo-rescue-zeocreator-note-and-eng-uk-waker-2026-11-08.md`). This file records that ruling and the facts behind it, and asks one question. **There is no operator line, so there is no hash to read.**

## The facts (the Architect's read, 13:45Z, nothing changed)

- **The process.** PID 15291 runs under launchd `ac.zeo.messenger.codex-wake` (KeepAlive, RunAtLoad, ThrottleInterval 30). It has run since 5 Nov 16:56:57. The binary is `zmsg-codex-wake`, sha256 `4d358cf3…`, dated 29 Oct.
- **Its arguments.** `-host eng-uk-0006`, `-config deploy/codex-seats.json`, `-zmsg ~/.local/bin/zmsg`, `-codex ~/.local/bin/codex`, a `-root` with no local store, and `-call-log` naming `calls.tsv`.
- **Its config.** The config is version-stamped and names one seat: `pomar`, in `/Users/rodbot/zeo/code/pomar-recovery-20261003/continuation`.
- **It matches the live seat.** On tmux `zeo2`, `pomar-maintainer` runs `codex resume -C` on that folder (PID 25890, since 7 Nov 17:55). The waker wakes thread `01a101bc`, which is the thread that seat holds.
- **It is working.** The log has 12,740 lines. Its last "pomar: woke thread 01a101bc" is at 08:04:31Z today, and its last line at 09:04. Its wait (`zmsg-remote wake --timeout 3600`) was re-armed at 13:04.
- **pomar-cc does not depend on it.** pomar-cc (pomar-contributor, Claude, PID 34519 in `/Users/rodbot/zeo/code/pomar`) has its own wake hook, PID 5866.

## The proposal: no change

1. **Leave the waker exactly as it is.** No restart, no config edit and no binary change. It is ENG-UK's only Codex doorbell, and it is correct for the seat that is live there. This is the Architect's ruling, and I agree with it. Nothing in the read points to a fault.
2. **Change it only when it is replaced.** Any change ships in the same release as its replacement, so ENG-UK is never without a Codex doorbell. That is the same rule as A3 for the Mac mini's Claude doorbell. The change runs only as an operator line, on the Architect's word, with its hash read first.
3. **What the replacement has to carry over:**
   - `-host eng-uk-0006`;
   - the one-seat map (`pomar` in that folder);
   - waking thread `01a101bc`;
   - the single-owner lock, so the old and new wakers never both serve the seat (`-owner-lock` and `-handover-wait` in `cmd/zmsg-codex-wake/main.go`).
4. **To see that it is still well, read only:**
   - the last "woke thread" line in its log;
   - that `launchctl print` still shows PID 15291, or a KeepAlive restart with the same arguments.

   Neither one touches it.

## The question: why is there no `calls.tsv`?

`-call-log` names `calls.tsv`, but the file does not exist. Per the ruling, this is a question and not a fix.

What the source says. This is zeomessenger `main` at `baf87a4`; the last change to these files was `4c40920` on 27 Oct. The binary is dated 29 Oct, so it may be later than this source.

- **The waker never writes the call log itself.** It hands the path to each `zmsg` child as `ZMAIL_LOG` (`cmd/zmsg-codex-wake/main.go:251`).
- **`zmsg` writes it best-effort and says nothing when it fails** (`bin/zmsg`, `log()`, line 334): "a call log must never break the call it logs".
- **A relative name is resolved against the child's working directory.** launchd's default working directory is `/` unless the plist sets `WorkingDirectory`. `deploy/install-v5.sh` passes an absolute path (`$MB/zmail-calls.tsv`) and sets no working directory. So if ENG-UK's plist passes the bare name `calls.tsv`, each write would go to `/calls.tsv`, fail because rodbot cannot write there, and be dropped without a word.
- **The other possible cause:** `~/.local/bin/zmsg` on ENG-UK may be a remote client that never reads `ZMAIL_LOG`. In that case no call log would be written at all.

What I am asking the owner, for whoever reviews this:

1. Does ENG-UK's plist pass the relative `calls.tsv`, and does it set `WorkingDirectory`?
2. Is ENG-UK meant to have a call log at all, given it has no local store?
3. If it is, where should the log go? Any fix ships with the replacement (point 2 of the proposal), not before.

## What this does not do

It runs nothing, and nothing reaches ENG-UK from zeo-rescue. Every fact above is the Architect's own read. The source was read on this host only.
