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
| [R01](tasks/R01.md) | `swfix-r01-0gu` | P0 | None | Isolate regression startup and preserve failure evidence |
| [R02](tasks/R02.md) | `swfix-r02-dja` | P0 | R01 | Recover and commit records with truthful funding state |
| [R03](tasks/R03.md) | `swfix-r03-vjf` | P0 | R01 | Make modal focus and gameplay input authoritative |
| [R04](tasks/R04.md) | `swfix-r04-yy0` | P1 | R05 | Ground skating and sweep real obstacle geometry |
| [R05](tasks/R05.md) | `swfix-r05-nx9` | P1 | R01 | Separate clocks and simulation from render presentation |
| [R06](tasks/R06.md) | `swfix-r06-8kj` | P1 | R05, R07, R08, R09 | Replay timestamped immutable actor and camera state |
| [R07](tasks/R07.md) | `swfix-r07-d9x` | P1 | R05, R04 | Keep the actual camera outside geometry and correctly aimed |
| [R08](tasks/R08.md) | `swfix-r08-jxj` | P1 | R04, R05 | Verify bail transfer and stabilize body skin ownership |
| [R09](tasks/R09.md) | `swfix-r09-3or` | P1 | R05 | Wait for traffic rotation and preserve causal settlement |
| [R10](tasks/R10.md) | `swfix-r10-xms` | P1 | R02, R03 | Make claim, recovery, and viewport UI coherent |
| [R11](tasks/R11.md) | `swfix-r11-sov` | P2 | R03, R05, R06 | Verify audio transitions during pause and replay |
| [R12](tasks/R12.md) | `swfix-r12-epn` | P1 | R02, R03, R04, R06, R07, R08, R09, R10, R11 | Integrate and stress the complete three-route loop |
| [R13](tasks/R13.md) | `swfix-r13-4d8` | P1 | R12 | Build an identifiable extracted candidate package |
| [R14](tasks/R14.md) | `swfix-r14-9gk` | P1 | R13 | Validate native gameplay visuals input audio and saves |
| [R15](tasks/R15.md) | `swfix-r15-zra` | P1 | R14 | Promote the verified game and repair launcher provenance |

The exact mapping is [bead_mapping.json](bead_mapping.json).
[bead_verification.json](bead_verification.json) records description/edge/readiness/health checks.
[Review decisions](reviews/DECISIONS.md) identify actual review provenance and revision diffs.
The source inventory in `builds/repair_audit/source_baseline.json` confirms no gameplay or old package edits.

R02/R03 repair record safety and modal controls; R05 establishes clock ownership.
R04/R07/R08/R09 then repair movement, camera, body transfer, and causal settlement.
R06/R10/R11 make replay, funding UI, and audio coherent. R12 checks the whole three-route loop.
R13 creates an exact candidate, R14 validates native play, and R15 promotes only those verified bytes.
Native service unavailability cannot turn R14 into a pass or close R15 prematurely.
