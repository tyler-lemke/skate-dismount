# Validation record — 2.0

The game was checked with **Godot 4.7.2 on macOS**. Original assets and fallback previews use Blender 5.2.2 through Blender MCP's background executor. The results below establish physical behavior, accounting, input routing, and interface constraints. They do **not** establish that people find the game fun.

## Automated verification

The latest completed checks passed **1,426 assertions across eight suites**, with zero failures: the 1,298-assertion full-suite run followed by the final expanded interface suite, which passed 627 assertions in place of its earlier 499. Assertions include repeated checks across routes, limbs, controls, and interface elements, so this total is not a count of independent scenarios. Run the source checks with `./tools/test.sh`.

| Suite | Assertions | Evidence covered |
| --- | ---: | --- |
| Rules | 170 | Injury severity and capped payouts, valid body regions, unique property scoring, combo/medal boundaries, staircase geometry, money formatting |
| Physical injuries | 36 | Real flat and rotated floor drops with verified collider sources, no skateboard injury, no resting-contact payout, connected poses, local damage appearance and complete replay restoration |
| Input and persistence | 36 | Actual `Input.parse_input_event` dispatch through GUI focus, pose/launch controls, hat selection, fresh-instance persistence, version-one record migration |
| Gameplay | 82 | Three complete routes, launch and collisions, eleven-part ragdoll plus separate board, ten joints, finite boosts, pause/slow motion, replay, balanced claims and saved records |
| Route variations | 41 | Nine physical runs, lane-dependent outcomes, manual bail and retry |
| Playability proxies | 390 | Successive actual-tread impacts, event sequences and payout variation, pose-dependent injuries, directional boosts and cooldown, replay/banking invariants, attainable campaign funding |
| Interface | 627 | Godot font metrics, wrapped text and long receipt bounds, actual mouse dispatch through modal overlays, completed payout count-up, results/replay controls, nonoverlapping severity bars, all eleven anatomy regions and replay restoration |
| Audio resources | 44 | Eleven imported streams contain sample data and valid durations; music/rolling loops and one-shot settings |

The runner rejects script errors, failed assertions, and reported resource leaks. Tests use isolated save files. Headless audio playback is disabled; resource checks do not assess how the game sounds.

Version-one arcade records are retained as legacy scores while the new treatment fund starts at zero. Version-two campaign claims, legacy scores, selected hat, and sound preference round-trip independently. Replaying or filing a weaker result does not add treatment money again.

## Measured crash behavior

[PLAYABILITY_METRICS.json](PLAYABILITY_METRICS.json) is an exact copy of `builds/playability_report.json` from the completed full-suite run, including the revised trajectory and actual-tread contact measurements. These are observed runs, not promises of identical physics scores on every machine.

| Route | Left / center / right claim | Payout spread¹ | Distinct opening property sequences |
| --- | --- | ---: | ---: |
| Civic Cascade | $222,262 / $140,669 / $263,010 | 46.5% | 3 |
| Night Market | $60,321 / $260,073 / $101,200 | 76.8% | 3 |
| Port Authority | $231,541 / $338,108 / $446,572 | 48.2% | 3 |

¹ Spread is `(highest − lowest) / highest` across the three tested starting lanes. Opening sequences compare the first five property events, or all available events when fewer than five occur. Injury-inclusive opening sequences also differ for all three lanes on each route.

The best claim from each route totals **$969,655 without crashbreaker assistance**, exceeding the **$600,000 treatment goal**. This establishes an attainable tested path, not that new players will discover it. Civic now starts in the left domino lane so the default first launch demonstrates a sustained chain; its sparse center lane remains available for experimentation.

The revised bail carries 72% of forward riding speed with an initial net vertical velocity of −1.7 m/s, bringing the body down onto the stairs while the first struck prop retains its full-speed launch impulse. At 75% charge in the recommended Civic left lane, TUCK produced **11 injury contacts across nine anatomical regions on three actual treads**, spanning **0.587 simulation seconds**, and still wrecked **34 properties**. Contact sources identify `Tread_09`, `Tread_10`, and `Tread_11`; this evidence distinguishes a successive stair tumble from hitting props merely located above the staircase. All nine measured lanes produced actual-tread injuries across six to eleven regions.

On the same Civic center line, TUCK, STARFISH, and TORPEDO produced different injury distributions. TUCK versus STARFISH differed by approximately **191.17 summed absolute severity points across eleven regions**. Aimed boosts changed lateral velocity by approximately **−7.16 m/s** and **+7.16 m/s**. Real floor-drop tests produced injury from incoming contact and no additional payment after settling. Across the tested poses, the maximum distance between joined body centers was **0.716 units**; this is a connected-body stability measure, not a measurement of joint-anchor error.

The nine lane runs lasted approximately **14.8–29.5 frame-clock seconds** after bail. This clock is derived from fixed-step headless execution and time-scale handling; it is **not a wall-clock performance benchmark or an FPS measurement**. The game also has a 34-second presentation-time crash limit and a manual claim-filing action. Native pacing and responsiveness still require observation during play.

## Visual evidence and limits

A native WindowServer was unavailable in this session. There was no human playtest, native mouse playthrough, GPU-renderer inspection, audio audition, or rendered-FPS measurement. Automated input dispatch verifies application routing, including focused controls, but is not a substitute for those checks.

Fallback previews export actual instantiated Godot geometry, camera transforms, per-object damage state, and UI bounds/visibility into Blender CPU renders. Static MultiMesh transforms are retained for this exporter because the dummy headless renderer cannot return GPU instance transforms. Blender substitutes its font, lighting, and color processing. These artifacts are **validation previews, not native Godot screenshots**.

Six final previews were regenerated through Blender MCP and visually inspected. They cover the menus, unobstructed rider setup, localized injury feedback, balanced settled payouts, and the funded-treatment ending. Results captures wait for the payout count-up to finish. The Civic crash capture uses the measured 75%-charge, unassisted TUCK launch and displays receipts identifying actual stair impacts.

| Route | Inspected previews |
| --- | --- |
| Civic Cascade | [Menu](screenshots/level_1_menu_validation.png), [stair impact](screenshots/level_1_crash_validation.png), [settled claim](screenshots/level_1_results_validation.png) |
| Night Market | [Pose and hat setup](screenshots/level_2_ready_validation.png) |
| Port Authority | [Menu](screenshots/level_3_menu_validation.png), [treatment funded](screenshots/level_3_results_validation.png) |

The source contains 18 original model exports, including three wearable hats, and eleven generated audio streams. The editable Blender studio and asset/audio generators remain available for iteration.

## Packaged application and review scope

The 2.0 release targets a universal Intel / Apple Silicon `builds/StairWreck.app` and `builds/StairWreck-macOS.zip`. Packaging uses the full installed Godot runtime with the game PCK and licensing notices, so it is larger than a dedicated release-template export. The package verifier runs the **bundled executable and PCK**, completes all three autoplay routes, and checks the sealed ad-hoc signature with `codesign --verify --deep --strict`:

```sh
./tools/build_macos.sh
./tools/check_package.sh
```

The final **2.0** app and archive were rebuilt after the modal-input and results-label fixes. All three routes completed through the bundled executable and PCK. An isolated PCK probe loaded and instantiated all 18 models, including all three hats. Strict deep signature verification, plist validation, ZIP CRC checks, and SHA comparisons of every archived app file against the signed app passed. The executable contains both Intel and Apple Silicon architectures.

| Packaged autoplay route | Payout | Wrecks | Explosions | Recorded replay frames |
| --- | ---: | ---: | ---: | ---: |
| Civic Cascade | $317,220 | 35 | 6 | 188 |
| Night Market | $422,095 | 35 | 8 | 203 |
| Port Authority | $738,839 | 60 | 16 | 224 |

Packaged autoplay uses a full-power, assisted control sequence, so these payouts differ from the unassisted lane experiments above. The final archive is **170,136,248 bytes**. Its SHA-256 is `8457dc5a834bf3cd3d5464c63c52766e51b3f045c7469b75680bb16c6fa3b43b`. [PACKAGE_CHECK.txt](PACKAGE_CHECK.txt) records the checks, component sizes, and PCK hash.

Design review combined independently developed internal proposals and adversarial source review. Additional external-model review attempts did not yield completed reviews: Claude API access failed at DNS resolution, the Antigravity local service failed on filesystem/bind access, and Grok lacked project filesystem access. No independent external-model validation is claimed.
