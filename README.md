# zeorescue

An on-demand recovery console for zeroemployeeorg. The rescuer can run in Codex
or Claude Code; either can inspect and recover seats using either harness.

First provision the rescuer's own marker record as described in [RESCUER.md](RESCUER.md).
Then, from the reviewed checkout:

```sh
make agent RESCUER=codex
# or: make agent RESCUER=claude
tmux -L zeo-rescue attach
```

- `AGENTS.md` / `CLAUDE.md`: one shared policy, with a Claude import.
- `STATE.md`: narrative handoff; generated recovery mappings live separately.
- `RECORDS.md`: automatic local capture and outage recovery.
- `make records-install`: install the finite collector after review/qualification.
- `make records-status`: generated mappings and capture problems.
- `RESCUER.md`: setup, tools, permissions and switching harnesses.
- `RUNBOOK.md`: recovery by hand without an agent.
- `make doctor ARGS=--json`: structured capability diagnostics, no restarts.
- `make test-rescuer`: offline dual-harness bootstrap and environment tests.

Both use the same `rescue.sh` and `seat-exec.sh`. Target sessions are resumed in
their original harness; they are not converted. This candidate includes the first
council guard patch, but does not clear the outstanding bulk-recovery blockers.
Nothing is merged, installed or run on arrival.
