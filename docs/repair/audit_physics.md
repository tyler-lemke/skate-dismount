# Physics repair audit — current 3.0 source

Date: 2026-10-04. Scope: `scripts/rider.gd`, `rider_skin.gd`, `ragdoll_limb.gd`, `crash_prop.gd`, `traffic_car.gd`, `world_builder.gd`, and the run/bail/settlement integration in `main.gd`.

This is an implementation-grounded planning audit. Gameplay code and models were not changed. No native display was available, so the findings establish source/physical behavior, not human visual playtesting. No project or ancestor `AGENTS.md`, and no project `.git`, existed at the paths checked. Godot was `4.7.2.stable.official.ed1daf0bf`, with the existing 90 Hz GodotPhysics3D settings.

All probes set `test_mode` and an isolated `save_path` **before** adding the game to the tree. They do not write `user://records.json` or production treatment funds. They write only under `builds/repair_audit/`. The run-up probes use the current imported models; there was no model regeneration. The existing entire test suite was not run in parallel.

Severity: P1 means a core play interaction is wrong; P2 means a visible/physical glitch requiring repair; P3 means a reproducibility investigation before committing a fix.

## 1. CONFIRMED — P1: clear taxi side passes trigger a crash and activate property

**Source:** `scripts/main.gd:300–309`, especially `:303`; `scripts/world_builder.gd:193`, `:196`, `:200–205`; `scripts/rider.gd:98–144`.

**Trigger:** Ride past a stationary taxi with lateral clearance. `nominal_radius` is the largest horizontal half-dimension, then `main.gd:303` uses it for both X and Z. A taxi's actual collider is 1.85 m wide and 3.3 m long, so its radius is 1.65 m. The ride trigger consequently accepts an X offset below 1.95 m although the taxi half-width is only 0.925 m. The check also ignores the prop's current orientation and uses only an absolute center-height interval.

**Measured evidence:** `builds/repair_audit/probe_physics.gd:39–55` places the actual Civic TUCK rider at X=1.40, beside the real taxi at X=3.30. Imported skin geometry reaches X=1.916818; the taxi hull begins at X=2.375. The skateboard is narrower. The rider therefore has **0.458182 m positive lateral clearance**, but one normal `main._physics_process(1/90)` update enters `CRASH` and arms the taxi. CPU skinning includes imported bind matrices and current skeleton poses; the clearance is not inferred from the faulty `nominal_radius` check. This fixture controls location and speed; it is not a claim of a full keyboard-only approach.

**Player consequence:** A near miss becomes an involuntary bail and a fabricated obstacle strike, so route aiming and narrow clearance feel unreliable.

**Why existing tests miss it:** `tests/test_routes.gd:14–24` and `tests/test_playability.gd:44–89` sample the three marked central lines and require destruction/score; they do not assert the absence of a strike in a geometrically clear pass. `tests/test_skating.gd:40–48` tests heading and displacement on the run-up, not hit envelopes. The assertions accept a false-positive crash as successful progress.

**Smallest repair direction:** Retain the current scripted riding controller. Replace the radius square with an explicit riding contact proxy and the actual oriented prop collision geometry. Use a swept test between the previous and next riding transforms so fixing false positives does not introduce high-speed misses. Keep broad-phase filtering if desired, but only a narrow-phase overlap/sweep may authorize `activate()` and `bail_out()`. Avoid rewriting the ragdoll or using rendered mesh triangles as the gameplay collision system.

**Independent acceptance:**

1. Reproduce the 0.458 m-clear taxi pass and assert `RUN`, no activation, no property claim, and no rider limb spawning.
2. Move the same rider progressively inward; a real proxy/hull strike must activate and bail once. The transition is checked against independently queried shape overlap, not the new trigger helper's return value.
3. Cover taxi front/side, narrow domino side/front, and a rotated/tipped prop. Exercise both steering directions and all three rider poses.
4. At maximum supported riding speed and a coarser frame budget, sweep through a thin domino: the true crossing must still hit once. Include an adjacent sweep that misses with positive clearance.

**Evidence:** `builds/repair_audit/physics_report.json` → `near_miss`; `builds/repair_audit/physics_probe.log`.

## 2. CONFIRMED — P2: the Port rider floats above the staircase at ordinary maximum charge

**Source:** `scripts/main.gd:284–292`, especially `:291–292`; `scripts/game_rules.gd:24–26`, `:128–132`; actual tread colliders in `scripts/world_builder.gd:41–45`.

**Trigger:** Choose the outside left approach, fully charge, then coast or hold push on the flat runway. Forward speed increases down the stairs, but the rider's Y correction is capped at 9 m/s. Port has a 0.42 m drop per 1.16 m run. Its mean required descent exceeds 9 m/s above about 24.86 m/s, so the visual/controller height cannot catch up; each next riser adds more lag. This is a cumulative support error in addition to the expected brief gap at an individual step edge.

**Measured evidence:** `builds/repair_audit/probe_physics.gd:57–75` runs the real game controller and compares its wheel-ground reference (`skater.y - 0.23`) against the authored stair height, on the unobstructed outside line. Each sample is a normal physics frame; the probe does not invoke a replacement movement implementation.

| Route | Full charge, coast: maximum extra wheel height | Full charge, push: maximum extra wheel height |
| --- | ---: | ---: |
| Civic | 0.260 m | 0.260 m |
| Night Market | 0.290 m | 0.380 m |
| Port Authority | **0.620 m** | **0.920 m** |

Port coast's maximum occurs near Z=42.928 at 27.162 m/s. The push case reaches the maximum near Z=43.021 at 28.642 m/s. Full charge without pushing already reproduces the defect. Pushing uses the existing `automate` branch solely to supply the normal held-push condition during this measurement; keyboard push dispatch should be included in the repair acceptance run.

**Player consequence:** The deck follows an elevated path above the lower treads; the late bail begins from this incorrect height. That changes what the character contacts and can make the approach look like hovering rather than skating.

**Why existing tests miss it:** `tests/test_skating.gd:23–48` ends its movement checks on the flat run-up. `tests/test_traffic.gd:46–51` checks that late bail begins at the correct Z, not the support height. `tests/test_routes.gd:22` checks only that the final ragdoll ends below Y=20. None tests maximum speed against the lower stair support.

**Smallest repair direction:** Define the intended grounded stair behavior explicitly and make the controller keep up with it. If the current deck is intended to stay grounded, use the authored surface/shape contact to place it at its correct support height each physics step, with any cosmetic body smoothing separate from the support transform. If brief controlled airtime is intended, track it as real motion and landing rather than silently capping descent while treating the rider as grounded. A wholesale engine/physics rewrite is not required to correct this support bug.

**Independent acceptance:**

1. Full-charge, minimum-charge, and full-charge-plus-real-W-input runs on all three clear outside approaches must not accumulate stair height error.
2. Prefer an actual downward query to the tread shapes as the test oracle rather than reproducing `surface_y()` in the test. The test must fail on a rider left 0.62–0.92 m above the Port treads.
3. Set a small grounded clearance tolerance; if a single-riser transition is allowed, state its maximum magnitude and duration. Consecutive transitions must not grow the error beyond one riser.
4. A deliberate late bail starts at the support height within the chosen tolerance; normal collision/injury/traffic outcomes remain causal and finite.
5. Test steering on the descending path and maximum frame-step budget. Do not “fix” the test by lowering top speed or excluding Port/full charge.

**Evidence:** `builds/repair_audit/physics_report.json` → `descents`; `builds/repair_audit/physics_probe.log`.

## 3. CONFIRMED — P2: idle settlement freezes a still-spinning wreck

**Source:** `scripts/main.gd:315–325`, `:464`, `:470–474`; traffic's existing angular rest condition in `scripts/traffic_car.gd:98–102`, `:224–225`; unused broader traffic motion query in `scripts/world_builder.gd:253–256`.

**Trigger:** The rider and props have little translational motion, but an armed traffic car spins on the road. Main's settlement movement estimate considers only torso and armed-prop **linear** velocity. It does not consider angular velocity, all rider limbs, or `world.traffic_has_motion()`. Traffic itself correctly remains `UNCONTROLLED` while spinning; main can nevertheless finish and freeze it after the 1.25 s idle window.

**Measured evidence:** `builds/repair_audit/probe_settlement.gd:14–38` uses the real car, material, collision shape, road, and solver. It freezes unrelated actors, initializes an armed wreck on the road at 7 rad/s yaw, and starts the crash clock at 3.1 s. Physics then evolves the body naturally; its spin is not continually reassigned. At **RESULTS**, the car still has **2.930281 rad/s angular speed**, only **0.002851 m/s linear speed**, and driver state **UNCONTROLLED**. The main idle counter reaches 1.25 s and freezes the car. This is a controlled physical reproduction, not evidence that the same initial angular state has been reached through player input in this audit.

**Player consequence:** A visibly rotating wreck snaps to a frozen result even though the documented “action rests” condition has not occurred. The same source path also ignores a moving non-torso limb; that specific natural gameplay case is not claimed as separately reproduced here.

**Why existing tests miss it:** `tests/test_playability.gd:60–66` asserts eventual results and duration bounds; it does not assert rest at an idle-triggered result. `tests/test_traffic.gd:111–114` checks that affected cars have relinquished their motor, not whether main permits them to finish moving before settling. The general run completion tests accept premature freezing as success.

**Smallest repair direction:** Include angular motion of causally armed wrecks and motion of all live rider limbs in the idle decision, with a clearly documented threshold or angular-to-edge-speed metric. The existing traffic `has_causal_motion()` can provide its rest contract without counting healthy cruising cars. Preserve explicit Enter-to-file and the hard simulation/presentation time ceilings as separate completion reasons; a ceiling may end active motion, but idle completion may not.

**Independent acceptance:**

1. The controlled yaw-spin fixture must remain CRASH while the armed car is above its declared angular rest threshold, then settle after it actually becomes quiet or reaches an explicit hard ceiling.
2. A moving non-torso limb with a quiet torso must block idle settlement. An entirely quiet ragdoll must still settle promptly.
3. Healthy cruising traffic must not postpone a finished rider crash. Pending fuses and imminent causal contacts must still defer idle settlement.
4. Record the finish reason in test telemetry and assert rest only for `idle`; exercise Enter and each hard ceiling independently.

**Evidence:** `builds/repair_audit/settlement_report.json`; `builds/repair_audit/settlement_probe.log`.

## 4. NEEDS_REPRODUCTION — P2 candidate: sustained body interpenetration and extreme neck twist during normal bails

**Source:** `scripts/ragdoll_limb.gd:11–12`; `scripts/rider.gd:225–229`, `:253–259`, `:318–327`; visible skin following body transforms in `scripts/rider_skin.gd:44–58`.

**Trigger:** Civic's default left domino line, charge 0.75, no intervention, each of the three poses. All limbs are on collision layer 4 with mask 3, so none collides with another rider limb. Every anatomical connection is a pin joint, which constrains anchor location but supplies no angular anatomy limit. Thus the bodies remain connected while freely folding through other body regions.

**Confirmed physical evidence, not yet confirmed displayed defect:** `probe_ragdoll_overlap.gd` follows normal obstacle-triggered bails and independently checks oriented box overlap using the 15-axis separating-axis test. Adjacent joint pairs and the board are excluded. The report records both first-frame overlap and maximum overlap, so a preexisting launch-pose intersection is distinguishable from later penetration. Results include:

- TUCK: left forearm/torso minimum projection overlap reaches 0.360 m and exceeds 0.08 m for 1,692 solver frames; head/shin overlap also develops from zero initial overlap.
- STARFISH: head/pelvis overlap grows from zero to 0.215 m and exceeds 0.08 m for 1,577 solver frames.
- The head's up axis differs from the torso's by as much as 168.23°, 176.19°, and 178.94° for TUCK, STARFISH, and TORPEDO.

These are physical hull metrics, not rendered-mesh intersection metrics. Some hulls are intentionally coarse. Native playback at the logged input conditions must establish whether the sustained folding/twist explains the reported visual glitches before implementing a physics restriction. This finding does **not** assert joint disconnection or exploding solver constraints.

**Why existing tests miss it:** `tests/test_injuries.gd:104–109` accepts finite motion and center separation under 2 m. Interpenetrating, flipped limbs easily satisfy both checks. `tests/test_rider_skin.gd:129–140`, `:163–176` asserts immediate bail continuity, not the shape after hundreds of solver frames.

**Smallest repair direction, conditional on visual reproduction:** Reproduce and capture the exact normal-bail cases first. If the anatomy visibly folds through itself, add bounded anatomical joint limits and/or selectively allow nonadjacent self-collision, retaining joint-neighbor exclusions. Verify initial launch-pose hull overlap before enabling self-collision: blanket changing mask 3 to mask 7 can create fresh solver explosions. Keep the imported mesh and its immediate bail continuity unchanged unless a separate mesh defect is proven.

**Independent acceptance:**

1. Capture matched native normal-bail frames/replay in all three poses, confirming or dismissing displayed body/neck interpenetration. Record the timestep and input sequence with the images.
2. If confirmed, assert physically declared joint-angle ranges and inspect the same captured poses after the repair. A test that only repeats the new joint constants does not establish visual correctness.
3. Track actual world joint-anchor agreement, velocities, and mesh continuity so the repair cannot trade clipping for disconnected or unstable limbs.
4. Preserve valid tucked/starfish/torpedo launch silhouettes and obstacle/traffic collision causality. Run the existing injury and immediate skin-continuity tests after any articulation change.

**Evidence:** `builds/repair_audit/ragdoll_overlap_report.json`; `builds/repair_audit/ragdoll_overlap_probe.log`. No visual fix is authorized solely by this audit result.

## Reproduction commands

Run these sequentially from any directory. Logs use absolute paths. The macOS engine emits a system-CA-certificate warning in this environment; it did not produce a script error or prevent either probe from completing.

```sh
/opt/homebrew/bin/godot --headless --path /Users/tyler/Documents/GitHub/stair-dismount --log-file /Users/tyler/Documents/GitHub/stair-dismount/builds/repair_audit/physics_probe.log --script res://builds/repair_audit/probe_physics.gd
/opt/homebrew/bin/godot --headless --path /Users/tyler/Documents/GitHub/stair-dismount --log-file /Users/tyler/Documents/GitHub/stair-dismount/builds/repair_audit/settlement_probe.log --script res://builds/repair_audit/probe_settlement.gd
/opt/homebrew/bin/godot --headless --path /Users/tyler/Documents/GitHub/stair-dismount --log-file /Users/tyler/Documents/GitHub/stair-dismount/builds/repair_audit/ragdoll_overlap_probe.log --script res://builds/repair_audit/probe_ragdoll_overlap.gd
```

## Ragdoll checks and limits

The three simple manual run-up bails in `probe_physics.gd:77–112` measured maximum actual joint-anchor disagreement of 0.0198 m, 0.0147 m, and 0.0242 m. There were no head-center-inside-torso frames in those runs. These results **do not support a claim that the pin joints explode or disconnect** in that case. The existing `tests/test_injuries.gd:104–109` checks body-center separation below 2 m; a future joint regression test should instead compare the two independently transformed joint anchors.

The normal-obstacle-bail overlap measurement in finding 4 establishes sustained physical interpenetration; native playback is still needed before prescribing angular limits or self-collision changes. Such changes can destabilize the currently connected, weighted skin and must not be bundled into the confirmed collision/support/settlement repairs without evidence.

Skin import/setup and immediately continuous bail geometry are covered by `tests/test_rider_skin.gd:63–178`. This audit does not overturn those tests or infer cosmetic quality from headless geometry. Full crash skin twisting, hat clipping, and camera visibility require native reproduction at matched input/time points.
