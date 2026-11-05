# zeo-rescue runbook

The org's recovery path, as a recovery console is to an operating system: needed only when the system is down, and asleep the rest of the time.

## When the system collapses

```
cd /Volumes/AIPEMedia1/code/zeroemployeeorg/zeorescue && claude
```

That is all the operator has to remember. The seat boots from `AGENTS.md` and `STATE.md`. Over a connection that may drop, use `make agent` instead: it starts the seat detached on its own tmux socket, and `tmux -L zeo-rescue attach` reaches it.

Without an agent, the steps below work by hand.

## Seats are gone

`tmux -L zeo2 ls` says no server, or far fewer sessions than the org chart has.

1. `make plan`. It starts nothing. Every seat on this host gets one line: `LIVE`, `RUNNING`, `RESUME` or `UNRESOLVED`, with its session, mode and git marker.
2. Check that each `RESUME` line names the seat's own session. The newest transcript in a directory is assumed to be the seat's. If someone ran another session there, pin the right one in `session-pins`.
3. Prove one seat first: `make rescue ARGS='--seat SOME-SEAT'`, then `make check ARGS='--seat SOME-SEAT'`. Pick a seat recorded as `master` whose id is not in any fault.
4. `make rescue`. Seats start 20 seconds apart. The first of each harness must prove its identity, marker and git, or the run stops.
5. `make check`. It must end `check: ok N, wrong 0`. Run `make rescue` again at any time: a seat that is up is left alone.
6. For `UNRESOLVED`, ask the rescue seat, or fix the named cause.

## Seats are up, but wrong

`make check` says `WRONG`, or seats report that git fails, or `zmsg whoami` names another seat.

1. `make reseat-plan`. Add `--before YYYYMMDDHHMM` to `ARGS` if the fault wrote shell snapshots, so markers come from before it.
2. Prove one seat: `make reseat ARGS='--seat SOME-SEAT ...'`, then `make check ARGS='--seat SOME-SEAT'`.
3. `make reseat`, then `make check`. All harnesses stop first, then the shared Codex daemon by exact pid, and only then does any seat start, so no thread ever has two writers. Seats started by rescue carry `@zeo_rescue` and are left alone, so it can be run again.

A reseat interrupts every seat it touches, so give each one a `--note-file` saying why.

## Finding the cause

`make teardown-log ARGS="'START' 'END'"` writes the system log to `~/.local/state/zeo-rescue/` (it asks for the sudo password). Nobody needs to read it or paste it: the rescue seat reads the file. Run it soon after a crash, because the log does not keep `--info` for long.

## Stuck seats

`make check` names a seat at the Claude trust prompt. Only the operator answers it, by attaching: `tmux -L zeo2 attach -t =SESSION`.
