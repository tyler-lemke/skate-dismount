# Validation record — 3.0

The updated three-level game was checked with **Godot 4.7.2 on macOS**. Models and validation previews were generated through **Blender MCP in background mode**, using Blender 5.2.2 and CPU rendering. The universal macOS app includes the engine, so Godot and Blender are not required to play.

## Completed behavior and automated checks

**1,780 assertions across 13 suites passed, with zero failures.** [TEST_RESULTS.json](TEST_RESULTS.json) records the final suite counts. The total includes repeated checks across routes, limbs, input states and UI elements; it is not a count of independent scenarios. Run `GODOT_BIN=/opt/homebrew/bin/godot ./tools/test.sh` to reproduce locally.

| Suite | Assertions | Main evidence |
| --- | ---: | --- |
| Rules | 170 | Finite anatomical payouts, valid regions, unique property awards, combo/medal boundaries and geometry |
| Physical injuries | 36 | Real floor impacts, collider sources, resting-contact rejection, poses and localized damage |
| Input and persistence | 36 | Actual input dispatch, focused controls, hats, saved preferences and legacy migration |
| Gameplay | 85 | Three completed routes, connected ragdoll, pause/slow motion, single breaker and replay accounting |
| Route variations | 41 | Nine physical lane runs, chains, manual bail and retry |
| Playability proxies | 370 | Actual-tread injuries, different lane/pose outcomes, bounded pacing and attainable funding |
| Interface | 586 | Font metrics, wrapped hints, modal input, one payout, eleven-region anatomy and causal receipts |
| Audio resources | 77 | Fifteen streams, finite nonclipping traffic PCM, loop seams and headless pause policy |
| Skating | 12 | Actual W/A/D dispatch, kick speed gain, coast drag, planted feet, forward carving and outside line |
| Crashbreaker | 44 | One accepted Shift event, repeat/invalid-state rejection, impulse budget, cone/radius/occlusion and time-scale invariance |
| Rider skin | 210 | Connected weighted body, clean arm/hip mapping, all three bail transitions, eleven damage channels, replay and car morph/pivots |
| Traffic | 93 | Safe autonomous baselines, braking, real three-car chains, negative control, callback ordering and input-driven interception on all routes |
| Camera | 20 | Real collider occlusion, rider-layer exclusion, clear-view preservation and bounded alternatives |

The runner rejects script errors, failed assertions and reported resource leaks. Tests use isolated save paths. The sandboxed engine emits a macOS certificate-store diagnostic; there were no script failures in the completed runs. Headless audio allocates no playback players, so resource checks cannot establish how the mix sounds. Tree pause suspends rolling and engine loops through their existing players while music remains available.

## Physical traffic and the one-use contract

Each route has three preallocated cars: two drivers and one queued car. Launch starts their encounter. Drivers use bounded motor/braking, lane and heading forces; substantial collisions remove driver authority from the same rigid body. Passive skid friction then preserves existing collision momentum. There is no respawn, scripted secondary launch or direct crashbreaker payment. Autonomous driving, lineage, damage and payment are separate states.

The single crashbreaker relaunches the rider at the existing 8.5 impulse-per-mass scale. Nearby shoves have a 2.2-unit radius, a 35-degree horizontal half-cone, ray obstruction checks, quadratic distance falloff, a 60-per-object cap, a 4-unit/s mass-normalized cap and a total 90 impulse budget. It cannot directly ignite a drum. Consumption occurs once before impulses; held/repeated Shift, pause, help and replay cannot obtain another use.

[TRAFFIC_METRICS.json](TRAFFIC_METRICS.json) is an exact copy of the final physical traffic report. A fixture establishes A → B → C, with B and C outside the pulse. Moving B away leaves C healthy and unpaid. Simultaneous-contact fixtures exercise both insertion orders using only measured collider contacts retained for a bounded solver window. Three 1,800-frame autonomous baselines produce no uncontrolled wrecks or claims; headway cases at 4, 6 and 8 units/s brake safely.

The complete-game regression dispatches A to select the outside-left line, holds/releases Space for approximately 75% charge, dispatches Space near the last two steps and dispatches Shift after 0.5 simulated crash seconds. It verifies actual A → B → C contacts, all three cars damaged, one ledger award per car, C's cause equal to B, and finite settlement.

| Route | Observed payout | B → C strength | Layout |
| --- | ---: | ---: | --- |
| Civic Cascade | $46,895 | 2.43 | Staggered passing lanes |
| Night Market | $40,536 | 2.43 | Turning pickup lane and angled queued cab |
| Port Authority | $56,646 | 2.92 | Diagonal merge and terminal gate |

The unchanged damage threshold is 2.0. Civic and Port also yielded the paid chain at 0.2 and 0.8 seconds; Market's useful window is narrower. These are observed fixed-step runs, not promises of identical scores or timing across machines. Gold, mint and cream paint distinguish the cars; glass and wheels retain their materials. Damage uses one authored front dent, rather than directional metal simulation.

## Agency, staircase impacts and campaign

[PLAYABILITY_METRICS.json](PLAYABILITY_METRICS.json) contains the final unassisted lane/pose runs. These are objective behavior proxies, **not proof of human enjoyment**.

| Route | Left / center / right payout | Payout spread | Distinct opening sequences |
| --- | --- | ---: | ---: |
| Civic Cascade | $222,337 / $98,710 / $43,185 | 80.6% | 3 |
| Night Market | $32,928 / $205,481 / $29,891 | 85.5% | 3 |
| Port Authority | $306,244 / $181,370 / $134,684 | 56.0% | 3 |

Spread is `(highest − lowest) / highest`. All nine lanes wreck at least three objects; Civic's right taxi line now has a physical domino bridge and wrecks ten. The best three unassisted claims total **$734,062**, exceeding the **$600,000 treatment goal**. Improved retries bank only the increase; replay and weaker claims add nothing. Existing version-two funds/preferences remain compatible, and version-one arcade records remain separately retained.

The Civic left-line reference records 15 actual-tread injury impacts across eight regions over 1.026 simulated seconds, with zero breaker uses. Named tread colliders establish a staircase tumble rather than damage from nearby props alone. Pose changes produce different injury distributions; opposite aimed relaunches change lateral velocity by approximately −7.10 and +7.07 units/s. Settlement considers causally moving bodies and pending fuses/contacts, bounded by 16 simulated or 34 presentation seconds, with Enter available to file early. Frame-clock measurements are not rendered FPS benchmarks.

## Visual evidence and limits

A native desktop display was unavailable. There was no human playtest, native GPU-renderer inspection, audio audition or rendered-FPS measurement. Automated input routing and physical outcomes do not establish those qualities.

Six final gameplay previews were regenerated and visually inspected. They export actual Godot geometry, CPU-evaluated skin poses and morphs, camera transforms, damage state and Control bounds into Blender. Shader injury colors are approximated at vertices; Blender substitutes lighting, fonts and color processing. The watermark identifies this method. These are **validation reconstructions, not native Godot screenshots**.

| Evidence | Preview |
| --- | --- |
| Route selection and treatment story | [Civic menu](screenshots/level_1_menu_validation.png) |
| New character and setup controls | [Night Market setup](screenshots/level_2_ready_validation.png) |
| Compact live anatomy and stair impacts | [Civic crash](screenshots/level_1_crash_validation.png) |
| Three-car damage and causal receipt | [Civic traffic](screenshots/level_1_traffic_validation.png) |
| Third-route environment/setup | [Port setup](screenshots/level_3_ready_validation.png) |
| Earned campaign ending and single payout | [Treatment funded](screenshots/level_3_results_validation.png) |

The funded capture completes all three earlier/current runs and waits for payout reveal; it does not invent a funded save. A [close character preview](screenshots/hero_asset_validation.png) is a Blender studio render using actual Godot pose transforms. Camera occlusion checks improve blocked views but do not guarantee every limb stays visible behind cargo. UI metric checks cover the 1440×900 design canvas; native scaling at other display sizes remains unverified.

The source includes 19 original GLB exports, 15 original synthesized audio streams and editable Blender studios. See [ASSET_PIPELINE.md](ASSET_PIPELINE.md) for regeneration and runtime contracts. Internal adversarial review found and corrected contact-order, sound-pause, wrapped-hint and skin-topology defects. Claude, AGY and Grok did not provide completed external reviews; no such validation is claimed.

## Packaged release

The **3.0** Intel / Apple Silicon application is `builds/StairWreck.app`, with the downloadable `builds/StairWreck-macOS.zip`. Packaging uses the full installed official Godot runtime and a game PCK, so the archive is larger than a release-template build.

`./tools/check_package.sh` runs the bundled executable/PCK from an empty project directory, completes all three routes, loads all 19 models and 15 audio resources, checks representative build/source exclusions, and verifies the ad-hoc signature. ZIP CRC, every archived app file, plist version and both executable architectures were checked separately. [PACKAGE_CHECK.txt](PACKAGE_CHECK.txt) records final payouts, sizes and SHA-256 hashes. These checks establish packaged execution and integrity, not native performance or enjoyment.
