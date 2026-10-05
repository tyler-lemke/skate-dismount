# R12 — physical traffic cascade and road support

Status: full 93-check diagnostic passes with the Port foot barrel at x=-4.8; final unchanged production confirmation remains pending. The first published fleet passed Civic and Market but failed one Port A→B assertion. These diagnostics used the real `TrafficCar` and controller, with proposed positions changed only while frozen in READY. Initial fleet diagnostics preceded publication. Do not rerun their mutating scripts unchanged against the published world: the Civic adjustment would apply a second time. Native presentation validation remains pending.

## Defects and physical correction

The original traffic fleet put A and faster B in parallel rows separated by 3.3–4.5 m. A could receive rider damage but could not reliably transfer its momentum through B to C. Equal-mass cars arranged as a following queue established contacts but attenuated the final impact below the unchanged 2.0 damage threshold. The accepted arrangement places B between two moving, opposing traffic lanes: a physically struck B slides into C's approaching hull.

The opposing-lane diagnostic exposed a separate support defect. With the original overlapping `Crash plaza` and `Traffic cross road` slabs, all three healthy C drivers became unarmed `UNCONTROLLED` and stopped at x≈18.718 as their noses entered the plaza's x=17 edge. No rider or payable prop caused those stops. The failed, explicitly logged [original-floor diagnostic](../../../builds/repair_work/R12/traffic/queue-v6.log.result.json) retains the observations; its transcript and `queue-v6_fixture/traffic_diagnostic.json` show C stopped before the player's encounter on every route.

Production now has one continuous `Traffic cross road` support box, size `(76, .5, 18)`, centered at `(0, -.25, length+9)`. The overlapping `Crash plaza` static body is removed. Two thin concrete apron meshes sit above the support surface and have no collision shape. This removes the internal slab edge rather than filtering or ignoring physical contacts in `TrafficCar`.

Civic's outside approach also struck `CRATE_020` with `fore_r` at `(-4.19086, 5.347574, 15.38436)`, run clock 1.71111, rider root x=-4.7/z=14.8093. Moving the left crate stacks at steps 14 and 20 inward by 0.30 m leaves the fitted forearm collision active and clears the approach until the deliberate late bail.

## Published fleet

`z` below is measured from `length = steps × run`; every car starts at y=.755, has mass 180, and retains its original hull and stable identity.

| Route | A: x / z / cruise / direction | B: x / z / cruise / direction | C: x / z / cruise / direction |
| --- | --- | --- | --- |
| Civic | -21 / +3.7 / 6.5 / +X | 2 / +6.0 / 0 / +X | 25 / +8.3 / 4.0 / -X |
| Market | -23 / +3.7 / 6.0 / +X | 2 / +6.0 / 0 / +X | 25 / +8.3 / 4.0 / -X |
| Port | -27 / +4.3 / 6.5 / +X | 2 / +6.0 / 0 / +X | 25 / +8.3 / 4.0 / -X |

B uses the existing queued braking state. A and C use the existing force-driven AI; Market keeps A's authored turn and Port keeps A's diagonal merge. C faces -PI/2 and travels left. Road labels now identify the forward lane, taxi queue, and oncoming lane.

## Actual-input evidence

[Single-floor actual-input diagnostic](../../../builds/repair_work/R12/traffic/queue-v6-single-floor.log.result.json): **33 checks, 0 failures**, accepted by the strict bounded runner. The existing recipe uses A steering to the outside approach, a .75 Space charge and release, a deliberate Space bail on the last treads, then one Shift intervention after .5 crash seconds. No actor transform or velocity is written after READY.

| Route | A→B measured strength | B→C measured strength | Physical payout |
| --- | ---: | ---: | ---: |
| Civic | 2.968 | 2.184 | 37,042 |
| Market | 2.329 | 2.275 | 45,657 |
| Port | 2.212 | 2.870 | 47,455 |

All three cars become damaged and enter the score-once ledger on every route. B and C begin outside the direct 2.2 m pulse radius, and C's cause label is exactly B's stable ID. Both actual contact edges exist and each encounter settles to RESULTS. Port's barrel can arm B before A's later contact; the evidence proves the A→B physical edge and B→C transfer, not that A is B's first source on Port. The diagnostic's complete contact arrays remain in `queue-v6-single-floor_fixture/traffic_diagnostic.json`.

[Healthy traffic diagnostic](../../../builds/repair_work/R12/traffic/healthy-v6-single-floor-v2.log.result.json): **12 checks, 0 failures**. Each route runs 1,800 actual 90 Hz physics frames (20 simulation seconds), sampling all three cars on every frame. No car ever becomes armed, broken, UNCONTROLLED, or SETTLED; no claims or cause edges occur. Both moving drivers cross the former x=±17 floor edges and leave naturally at x≈±32. Healthy traffic does not postpone settlement. Full observations are in `healthy-v6-single-floor-v2_fixture/traffic_healthy.json`.

## Scope and rejected evidence

The first [published-world production run](../../../builds/repair_work/R12/branch-traffic-actual/output.log.result.json) reported **93 checks, 1 failure**: Port's barrel armed B before the car encounter and no A→B contact edge was recorded. All three Port cars were damaged and C inherited B's cause, but those facts alone do not prove A→B→C. The production failure supersedes the earlier proposed-layout success; scene construction and callback order can affect a marginal physical collision.

A narrower follow-up changes only Port A's initial z offset from +4.3 to **+4.5**, retaining its +3.7 merge waypoint, speed 6.5, x=-27, and every prop. The [Port actual-input diagnostic](../../../builds/repair_work/R12/traffic/port-a45.log.result.json) passes **11 checks, 0 failures**: A→B strength 2.090 at 4.502 seconds precedes B→C strength 3.115 at 5.034 seconds, all cars enter the once-only ledger, and C's cause is B. The [healthy follow-up](../../../builds/repair_work/R12/traffic/healthy-port-a45.log.result.json) passes **21 checks, 0 failures** across all three routes. It adds exact initial hull shape queries (margin zero, prop/car layer) for all nine cars; no hull overlaps another car or prop. It retains the 20-second every-frame healthy-driver checks and both road-edge crossings. This is a measured proposal; the unchanged full production suite remains the acceptance authority.

That isolated Port success did **not** survive the [full-copy diagnostic](../../../builds/repair_work/R12/traffic/full-a45.log.result.json), which retained every original healthy, synthetic chain, simultaneous-contact, braking, gentle-shove, and three-route actual-input case in the original order and changed only Port's READY position. It reported **93 checks, 1 failure**, again the missing Port A→B edge. The full-copy failure supersedes the isolated pass; +4.5 alone is not an accepted solution.

The subsequent [full-copy foot-barrel diagnostic](../../../builds/repair_work/R12/traffic/full-barrel04.log.result.json) passes **93 checks, 0 failures** in the complete original suite's construction and case order. It resets Port A to the original +4.3 offset and changes only foot-left `BARREL_062` from x=-5.2 to **x=-4.8**, while READY. All other four foot barrels keep their coordinates. Port establishes A→B strength **2.474 at 4.372 seconds**, followed by B→C strength **2.697 at 4.965 seconds**, all three damage claims enter the score-once ledger, and C inherits B's cause. The shifted barrel remains a physical, explosive participant rather than being removed or excluded. The matching [healthy diagnostic](../../../builds/repair_work/R12/traffic/healthy-port-barrel_04.log.result.json) passes **21 checks, 0 failures**, including exact initial no-overlap queries for nine car hulls and the 20-second every-frame driver observations on all routes. This +0.4 m foot-barrel shift is the selected proposal; production confirmation remains required.

Port foot-barrel shifts of +0.2, +0.6, and +1.0 m were rejected for gameplay failures. Moving Port B to x=.5 was also rejected by the full-copy suite (93 checks, 4 failures). All variant logs remain under `builds/repair_work/R12/traffic/`.

This traffic correction changes authored world geometry and encounter placement. It does not tune `TrafficCar`, suppress contacts, change damage thresholds, award automatic cascade claims, alter insurance scoring, change car/rider shapes or masses, or modify the accepted rig. Root's separate Port taxi-to-domino relay adjustment is outside this evidence's scope.

The first `baseline.log.result.json` diagnostic omitted an explicit `--log-file` and was rejected for user:// log errors as well as gameplay failures. It is not passing evidence. The original-floor **v6** diagnostic did provide an explicit log destination; it was rejected for its 12 gameplay failures. The first healthy diagnostic had a missing helper parse error and was rejected; only the corrected **v2** healthy result above is passing evidence. No rejected log was cleaned or treated as a successful run.

Production suite results and the eventual full-suite identity supersede these proposed-layout diagnostics. These headless physics checks establish causal contact, attainable outcomes, and healthy-driver behavior; they do not establish native rendering, audio quality, or human enjoyment.
