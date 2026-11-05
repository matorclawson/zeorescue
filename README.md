# zeorescue

The rescue seat of zeroemployeeorg: `zeo-rescue`. When the system collapses or there is an emergency, run this, and nothing else:

```
cd /Volumes/AIPEMedia1/code/zeroemployeeorg/zeorescue && claude
```

- `AGENTS.md`: who the seat is, its boot sequence and its rules.
- `STATE.md`: its memory. What happened last, what is open, what to do next.
- `RUNBOOK.md`: the same recovery by hand, with no agent.
- `rescue.sh`, `seat-exec.sh`: the mechanism. `make help` lists the commands.

It is on-demand on purpose, neither a daemon nor a service: anything resident would die in the same teardown.
