# Executable repair queue

All fifteen repair tasks are open. The completed deliverable is the reviewed plan, not game fixes.
Four strong internal reasoning reviews reached steady state; no additional product decision is needed.
All thirty blocking dependencies and full task descriptions were copied with the br CLI.
The only initial-ready task is R01, `swfix-r01-0gu`.

From the project directory:

```sh
br --db "$PWD/.beads/beads.db" ready --json
br --db "$PWD/.beads/beads.db" show swfix-r01-0gu --json
```

Claim a task only when starting implementation. Close it only after its actual evidence passes.
The table below lists prerequisite task keys; the database contains their correctly directed blocking IDs.

| Task | Bead | Priority | Prerequisites | Repair |
|---|---|---|---|---|

The exact mapping is [bead_mapping.json](bead_mapping.json).
[bead_verification.json](bead_verification.json) records description/edge/readiness/health checks.
[Review decisions](reviews/DECISIONS.md) identify actual review provenance and revision diffs.
The source inventory in `builds/repair_audit/source_baseline.json` confirms no gameplay or old package edits.

R02/R03 repair record safety and modal controls; R05 establishes clock ownership.
R04/R07/R08/R09 then repair movement, camera, body transfer, and causal settlement.
R06/R10/R11 make replay, funding UI, and audio coherent. R12 checks the whole three-route loop.
R13 creates an exact candidate, R14 validates native play, and R15 promotes only those verified bytes.
Native service unavailability cannot turn R14 into a pass or close R15 prematurely.
