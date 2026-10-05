# R12 — Distinguishing the Port relay branch

The straight four-relay repair restored a chain but, in the exact PLAYABILITY
sequence, produced only8.72% lane payout variation against the unchanged15%
requirement. Temporary diagnostics therefore changed only the positions of the
four added relay actors during READY; actor identities, shapes, masses, scoring,
goal and the accepted90Hz/32-pass rig remained fixed. Every new position was
queried against actual layer2 geometry and had zero initial prop overlap.

The full lateral-offset probe passed **PORT_BALANCE85 checks,0 failures**:

| Four relay X positions | Left/center/right coast claims | Coast variation | Center full charge + W |
|---|---|---:|---:|
|3.4 /3.4 /3.4 /3.4 control |$208,119 /$275,812 /$354,365 |41.3% |$479,822 |
|4.3 /4.3 /4.3 /4.3 |$205,919 /$425,012 /$265,330 |51.5% |$175,776 |
|4.6 /4.6 /4.6 /4.6 |$336,438 /$301,712 /$24,497 |92.7% |$326,574 |

Every coast line retained at least three wrecks and three distinct initial
causal event signatures. All-outward4.6 produced a structural small right
branch of five wrecks instead of a whole drum avalanche, but also reduced the
measured center mastery payout. The control already differs from the prior
full-suite sequence, demonstrating that exact chaotic totals depend on the
physical fixture/order; an isolated high payout cannot itself justify tuning.

After root changed the plaza floor to a single continuous road, the mixed
branch probe passed **PORT_BRANCH57 checks,0 failures**:

| Step10/11/12/13 relay X positions | Left/center/right coast claims | Wreck counts | Coast variation | Center full charge + W |
|---|---|---|---:|---:|
|4.6 /3.4 /3.4 /3.4 |$199,619 /$401,421 /$414,761 |33 /50 /50 |51.9% |$499,974 |
|4.6 /4.6 /3.4 /3.4 |$283,919 /$279,212 /$266,137 |43 /41 /37 |6.26% |$326,574 |

The two-front arrangement fails the lane-choice requirement and is rejected.
The one-front arrangement is the smallest promising production candidate: its
first relay catches a glancing taxi contact at x4.6 while all three downstream
relay bodies preserve the existing inner transfer line. It passes the measured
variation and chain checks, but still permits large cascades. Root should
validate its exact ordinary ROUTES/PLAYABILITY sequence before acceptance;
this diagnostic does not claim the full mandatory gate passes.

Artifacts are retained under `builds/repair_work/R12`:

- `port-balance-probe.log.result.json` and corresponding engine/runner logs
- `port_balance_probe_fixture/port_lane_balance.json`
- `port-branch-probe.log.result.json` and corresponding engine/runner logs
- `port_branch_probe_fixture/port_lane_branch.json`
- `port_lane_balance_probe.gd` and `port_lane_branch_probe.gd`

No production source or mandatory test was changed by this diagnostic agent.
The campaign assertion still uses the same600k threshold, with root evaluating
the already-present Civic pose choices before checking legitimate campaign
mastery. Native visual acceptance remains separate.
