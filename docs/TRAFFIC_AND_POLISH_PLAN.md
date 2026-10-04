# STAIR//WRECK — traffic and presentation upgrade

The next version should have two connected acts: a readable skateboard stair tumble, followed by a player-caused traffic pile-up. **One crashbreaker is the player's one deliberate intervention between those acts.** Higher-quality character and vehicle art, an open camera composition, and a much quieter HUD make that decision understandable.

This blueprint was prepared against version 2.0. The implemented 3.0 release and remaining native-validation limits are recorded in [VALIDATION.md](VALIDATION.md). It synthesizes independent proposals and adversarial cross-review by the existing three design agents. Claude, AGY and Grok did not participate in this pass; their earlier access failures remain documented separately. Source findings are verified; tuning and player acceptance targets below are hypotheses. The former 2.0 source baseline is archived in `builds/baseline-2.0-source.zip`.

## Decisions

| Area | Chosen implementation | Reason |
| --- | --- | --- |
| Crashbreaker | Exactly one use per attempt, available at bail. Directional rider relaunch with a small, bounded nearby-object shove. | A stalled first crash still has a recovery choice. No refill or earned meter obscures the decision. |
| Traffic | One finite-mass `RigidBody3D` per car for its whole lifetime, with local bounded-force driving AI. | Impact withdraws motor control without changing bodies, score identity or momentum. |
| Cascade | Real collision ancestry: player/debris → car A → car B → car C. | The player can see and explain why the additional payout happened. |
| Character | One original continuous skinned hero, with riding animation and crash poses driven by the existing eleven-region physics. | Better anatomy and clothing require actual deformation, not just smoother rigid blocks. |
| Vehicles | A well-made compact taxi first, with separate wheels, material detail and one directional crumple treatment. | Readable motion and damage matter more than a large roster. |
| UI | One dominant payout, compact eleven-region anatomy, one READY/SPENT resource, contextual edge receipts. | The world and impending collision remain visible. |

## One crashbreaker: a commitment the player can read

Use `AVAILABLE → SPENT` attempt-local state. A valid Shift press during CRASH captures aim, consumes the token atomically, and applies the effect once at a physics boundary. Invalid presses consume nothing. Pause, help, key repeats, replay, banking and impacts never restore the charge; retry/new attempt does. Remove recharge language, three-pip displays and three-use automation/tests together.

Start by retaining the current rider relaunch strength: approximately +8.5 m/s horizontally and +2.7 m/s upward across the body, excluding the detached board. This preserves a known starting point while reducing uses. Do not multiply strength by three. Tab remains the slow-motion aiming aid. The arrow describes impulse direction, not a guaranteed landing or car interception.

Prototype the rider relaunch alone first; then add the intended small environmental pulse with **one effect owner and one budget**. Starting experiments: 2.2 m radius, a 70° forward cone, occlusion, smooth falloff, total environmental impulse budget 90, per-body impulse cap 60 and added-speed cap 4 m/s. These are internal physics units requiring tuning, not realistic blast claims. Heavier cars receive less velocity from equal impulse; their engines and incoming motion supply most pile-up energy. Never select one special car for an invisible extra shove, or leave a second uncapped prop-wave path running beside the bounded pulse.

Separate physical shove, causal eligibility, measured damage and ignition. Current `CrashProp.activate()` immediately ignites drums ([source](../scripts/crash_prop.gd#L74)); using it unchanged would make even a tiny pulse bypass the intended limits. The RUN collision shortcut and drum blasts also multiply impulse by victim mass ([source](../scripts/main.gd#L265), [source](../scripts/main.gd#L329)); traffic handling must cover these paths too. Pressing Shift alone earns no payout. Godot documents impulses as one-time events and force integration as the place for controlled body-state work; the effect must not depend on rendering rate or slow-motion scale. [RigidBody3D documentation](https://docs.godotengine.org/en/4.7/classes/class_rigidbody3d.html)

## Moving traffic: local drivers, physical wrecks

Each driver follows a short authored lane, maintains headway, observes right-of-way and reacts to an obstruction after a finite simulation-time delay. Small fixed differences in reaction time and following distance can give drivers personality after the base layout works. Brake lights, wheel motion and an occasional horn communicate decisions. Drivers respond to the road, rather than steering toward the player or deliberately choosing collisions.

The state machine is `DRIVE ↔ BRAKE/YIELD → UNCONTROLLED → SETTLED`. Apply bounded acceleration, steering torque and grounded grip in physics. On a substantial collision, disable motor, lane correction and artificial stabilization before the next motor update. The same body retains its actual linear/angular velocity; it can yaw across a lane, obstruct following traffic, and become the next collision source. It never snaps back onto its path or automatically self-rights.

This is a deliberately small custom traffic controller. `AnimatableBody3D` cannot be moved by contact, so swapping it into a rigid body creates a delicate first-impact handoff. `VehicleBody3D` brings wheel/suspension machinery and documented limitations that do not solve this game's specific requirement. The same-body approach is our engineering choice, supported by those documented tradeoffs. [AnimatableBody3D](https://docs.godotengine.org/en/4.7/classes/class_animatablebody3d.html), [VehicleBody3D](https://docs.godotengine.org/en/4.7/classes/class_vehiclebody3d.html)

Separate four facts per car: driver state, player-cause ancestry, physical damage and whether its unique property claim has paid. Normal driving or braking never establishes player cause. A causal car may hit a previously untouched victim and propagate responsibility through that actual contact. An already-paid wreck can cause another claim without paying itself again. Resolve paired contacts consistently so callback order cannot change eligibility; record source/destination actor IDs, simulation time, position and qualifying normal impact.

Cars cannot inherit the current armed-prop distance test: ordinary driving already exceeds its 0.55 m wreck threshold ([source](../scripts/crash_prop.gd#L48)). Qualify damage using contact-normal closing speed and collision impulse with support/resting/graze filters. Give moving and parked cars the same archetype mass and damage rules. Explore vehicle mass 180–240 against the existing rider's combined 35, with initial traffic speed 5–9 m/s; validate collision transfer before fixing these values.

Choose spacing from braking distance, not from a desire for more wrecks. At 6–9 m/s, a 0.4 s reaction delay and 4 m/s² braking need about 6.9–13.7 m of stopping distance before hull length and clearance. Extend the crossing and test swept vehicle envelopes/right-of-way accordingly. Normal traffic must safely complete an attempt; a sudden player-created cross-lane obstruction creates the exceptional conflict. The downward stair bail plus small pulse does not yet prove that a heavy car is reachable: require a late-tread intercept window with earlier real stair hits preserved, and use the struck car's incoming momentum for the subsequent transfer.

The first milestone is **two moving taxis plus one queued third car on Civic**, created before launch and retained for the attempt. No nearby explosive drums, late spawning, vehicle replacement or portal recycling is needed to prove it. Place the second victim outside direct crashbreaker reach. Require physical A → B → C contact; then move B out of reach and require the chain to fail. That negative control distinguishes a cascade from three independently triggered payouts.

Start traffic schedules at launch in simulation time, with stable initial spacing on retry. Waiting in READY does not silently change the puzzle. Launch speed, lane, bail and breaker timing change the intercept. Slow motion and pause affect vehicles and rider together. Once the sparse prototype works, introduce a small preallocated roster with clear entry volumes, bounded schedules, offscreen exits and no reuse of paid identities.

| Level | Traffic situation | Player's opportunity |
| --- | --- | --- |
| Civic Cascade | Broad two-way taxi crossing and a short queue | Deflect a taxi into the opposing lane, then let following traffic reach the obstruction. |
| Night Market | Staggered delivery traffic making a yielding turn | Strike the rear quarter during the committed turn to redirect it into the next arrival. |
| Port Authority | Convoy through a narrow terminal gate | Knock the lead vehicle off line and bridge the blockage into the outbound lane. |

Open actual road gaps and extend the bottom plazas; the existing curbs/end wall are not a traffic road. Preserve stair contacts and the three authored stair lanes. Each route needs a useful unboosted outcome as well as a worthwhile one-charge intercept.

## Higher fidelity art: construction, deformation and motion

Use an illustrated, tactile city with a memorable skater: shaped anatomy and helmet, a readable face, jacket panels/cuffs, distinct hands, shoes and safety pads. Author a curved layered deck, real trucks and separate wheel pivots. Keep ordinary scenery quieter than the player, traffic and hazards. Model one hero character and one hero taxi well before spreading work across variants.

The current seven reusable anatomical GLBs instantiate eleven body regions. A seamless human cannot be promised by replacing these rigid parts alone. Build a Blender guide rig against the existing physics anchors, prove push/coast/carve and foot placement on simple geometry, then skin the final mesh. At bail, initialize the same eleven physics bodies from the evaluated visual pose with explicit bind offsets; thereafter drive the visual bones from those body transforms. Extra hand/foot visual bones need a defined relationship to forearm/shin bodies, without inventing additional scored regions. Preserve the intentional downward stair-entry velocity. Physics-to-skeleton coordinate mapping, joint limits, extreme-pose deformation, and first-frame continuity are real integration work.

Godot's `SkeletonModifier3D` provides post-animation bone modification, while skeleton global poses are skeleton-relative rather than world transforms. That supports a custom physics-to-bone visual adapter, but does not make this a drop-in asset replacement. [SkeletonModifier3D](https://docs.godotengine.org/en/4.7/classes/class_skeletonmodifier3d.html), [Skeleton3D](https://docs.godotengine.org/en/4.7/classes/class_skeleton3d.html)

Use eleven localized injury masks for scuffed cloth/pads and visible limb damage; retain named diagnosis and severity in the HUD. Preserve original materials instead of replacing every surface with the current grey damaged override. For the taxi, use a shaped hood/cabin/trunk, wheel wells, inset windows, lamps and paint/metal/rubber roughness. Start with one visible impact-region crumple preset or morph and cracked glazing; extend front/rear/side treatments only after they read at the actual camera. Keep convex collision proxies simple and close to the visual envelope. Cosmetic fragments can be pooled and non-scoring.

Produce editable Blender sources and GLB exports through Blender MCP, with controlled pivots, UVs, triangulation and reusable materials. Validate the exported assets in Godot, including hats, three poses, damaged limbs and replay. Godot's export guidance explicitly treats scene conventions and native lighting as part of the pipeline; a Blender beauty render cannot approve the game's final appearance. [Model export considerations](https://docs.godotengine.org/en/4.7/tutorials/assets_pipeline/importing_3d_scenes/model_export_considerations.html)

## UI and camera: fewer competing panels

The 2.0 source layout crowded live play with eleven injury rows and separate payout, fund, aim, speed and resource cards. The [updated crash preview](screenshots/level_1_crash_validation.png) shows the implemented compact injury display and single resource card; it remains a Blender reconstruction, with substituted fonts and lighting.

The [layout concept](concepts/crash_hud_concept.svg) explores a protected central action window. Final live HUD: one large insurance payout; a compact eleven-region body silhouette with the latest/severest hit; one conspicuous `CRASHBREAKER READY → SPENT` token; a small speed readout; one brief edge receipt such as `TAXI A → TAXI B +$…`. The concept is diagrammatic and does not establish final character/model quality. Fund progress and Mom's message get emphasis in setup and settlement. Full injury/item ledgers live in the results; the live scene keeps localized limb feedback visible.

Reveal traffic direction and arrival opportunity before the player spends the token. Use lane markings, lights and a restrained look-ahead camera. Once a causal car becomes the meaningful action, camera focus can follow its handoff while retaining an offscreen rider marker and anatomy view. Do not cut to arbitrary cruising cars. Results hide the live HUD and present the payout once, the property/injury split, genuinely new banked money and the treatment fund. Replay shows recorded states rather than live controls.

Move reusable presentation into Godot scenes and a shared Theme, using anchors for edge placement and containers for variable text. Bundle a properly licensed readable font. Keep keyboard focus, modal input blocking, reduced-motion/flash options, and textual damage states. Recheck actual layouts at 1280×800, 1440×900 and 1920×1080 rather than relying on a single fixed coordinate set. [Godot container layout](https://docs.godotengine.org/en/4.7/tutorials/ui/gui_containers.html)

## Finish, replay, progression and validation

Normally cruising cars must not keep an attempt alive forever. Watch the rider, causally disturbed actors, pending causal fuses and a short bounded imminent-arrival window. If the rider leaves the arena while a real chain remains pending, transfer focus instead of immediately filing the claim. Hard simulation/presentation ceilings still bound the attempt.

Keep stable actor IDs and record car visibility, transforms, wheel phases, lights and damage treatment alongside the existing limb snapshots. Record causal events at their actual times. Replay freezes AI/scoring and restores snapshots, including the final state afterward; it never drives cars again or awards money. Introduce approach recording after the core chain works, rather than quietly making it a prerequisite for the first prototype.

Preserve earned treatment funds and historical records. Keep the $600,000 goal provisionally, then remeasure fresh and partially funded saves with no breaker, early use, deliberate intercept and a miss. Current zero-breaker results show that reducing the use count alone does not prove a lower goal is necessary; heavier moving traffic changes that evidence. Test whether new achievable claims can exceed prior records before choosing any explicit save migration.

Implement in five slices:

1. Separate impulse/cause/damage/ignition; implement one-use state, truthful UI and regression tests.
2. Prove the sparse Civic physical chain and negative control; fix bounded settlement and stable replay identity.
3. Fix riding animation ownership and foot/deck contact; prove a simple skinned rig's bail/physics/injury adapter before finishing hero meshes. Build the polished taxi against validated vehicle dimensions.
4. Expand the three traffic scenarios; remeasure outcomes/progression and add recorded vehicle presentation.
5. Finish every screen, camera/audio feedback, native performance and playtests; package the new three-level build.

Appropriate automated tests target behavior: one real activation and no second impulse; invalid/pause/replay inputs; identical immediate impulse across time scales; zero payout for autonomous traffic; below-threshold touch after long transit; meaningful A → B → C contacts and broken-chain control; motor stays off after impact; no floor/graze awards; blocked entry cannot overlap; score-once and bank-on-improvement; bounded settlement; faithful recorded deformation/limbs with no replay payout. Retain the existing actual-tread and finite-injury gates. Avoid tests that merely bless whichever score the new implementation happens to produce.

Native validation should include all three levels, a busy pile-up, hero assets at gameplay distance, UI at the three target sizes, and frame-time measurements on an identified machine. Initial player-study targets: at least four of five new players can explain the single-use control and identify traffic direction after one run; at least three can intentionally change a subsequent collision chain; record voluntary retries and time to the first crash against 2.0. These are proposed acceptance signals, **not proof that fun has been achieved**. Current headless physics tests and Blender previews cannot measure that experience.

Supporting independent proposals: [traffic](traffic_cascade_proposal.md), [crashbreaker](single_crashbreaker_proposal.md), [art/UI](art_ui_upgrade_proposal.md). This synthesis resolves their differences in favor of one bounded pulse, a three-car first prototype, and explicit skinning work for the final character.
