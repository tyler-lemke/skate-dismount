# Traffic as the second act of the crash

Design proposal only. No gameplay, model, build or test changes were made. Source inspection supports the contracts below; human enjoyment and live rendering have not been validated. Numbers are initial experiment settings, not measured tuning.

## Choice

Use a small fixed fleet of **RigidBody3D cars with bounded force/torque driver control**. Cars remain the same physical bodies before and after impact. A driver follows an authored road lane, keeps headway, yields and brakes; an impact releases that control so existing momentum can carry the car into other vehicles. Keep each car's driver local; a tiny traffic director supplies spawn schedules and right-of-way, not global crash choreography.

| Alternative | Advantage | Main problem | Decision |
| --- | --- | --- | --- |
| Scripted transform animation | Fastest moving-road prototype | Motion can pass through bodies or override collision response; weak evidence of a physical cascade | Visual mockup only |
| AnimatableBody driving, swap to rigid body on impact | Predictable lanes while driving | Adds an exact first-impact handoff, velocity estimation, duplicate-contact and actor-identity problem | Reject for first implementation |
| Rigid body throughout, bounded motor forces | Same mass, contacts, velocity and replay actor throughout | Needs restrained lane control and reliable impact override | Choose |
| Four simulated wheels, suspension and a road network | Rich vehicle simulation | Much larger project than a readable plaza pile-up | Defer |

The first prototype is Civic with **two moving taxis and one queued third car**, one crashbreaker and no explosives beside the road. The observable goal is: **one player-seeded vehicle physically strikes a second, which physically strikes a third**. It is not enough for one shockwave to independently damage three cars, or for the third merely to be nearby. All three actors can initially remain visible and preallocated; prove this chain before implementing hidden entry/exit lifecycle details.

## Proven source constraints

- `scripts/crash_prop.gd:48–53` damages an armed prop after travel exceeds 0.55 metres or tilt passes a threshold. Driving must neither arm cars nor use travel from spawn as evidence of damage. A weak later touch must not cash out metres of earlier normal driving.
- `scripts/world_builder.gd:192–193` adds a prop to the tree before assigning its spawn position; `_ready()` captures `origin` first (`scripts/crash_prop.gd:23–24`). `main.gd:234` currently repairs that origin at launch. A scheduled traffic spawn needs an explicit final-transform initialization rather than relying on this ordering.
- `scripts/crash_prop.gd:62–71` uses any rider or armed prop as causal, and the maximum of relative velocity magnitude and normalized impulse as damage strength. Tangential traffic motion can therefore look like a severe hit. Cars need closing speed along a contact normal and/or normalized collision impulse, with an independently established threshold.
- The current bottom plaza is 34 by 18 metres with side curbs and an eight-metre end wall (`scripts/world_builder.gd:63–68`). It is not yet a traversable cross-road. Bottom taxis are stationary prop placements (`:133`, `:142`, `:156`); the stair taxi targets should remain separately classified props.
- Direct riding contact uses an axis-aligned radius approximation (`scripts/main.gd:261–266`). Rotating/moving cars would enlarge its false-contact cases. Use a swept relative-motion collision test for traffic, or keep its first hit after the ragdoll transition; do not silently reuse that approximation.
- Crash termination observes armed-prop speed and rider speed, then can finish when the rider drops below -8 (`scripts/main.gd:272–277`). A meaningful traffic chain may remain pending; conversely, counting every normally cruising car prevents idle completion forever.
- Property receipts do not record source vehicle/contact (`scripts/main.gd:312–316`). Rider receipts have source labels, but there is no property causal graph yet.
- Replay records actor transforms, boolean prop damage and limb severity at roughly 20 Hz, starting only in CRASH (`scripts/main.gd:380–387`). It does not capture an approach, wheel rotation, braking lights or future dent states. Dynamic spawning/despawning would also conflict with the fixed actor list assembled at bail (`:290–292`).
- Three charges remain hardcoded in initialization/reset/automation (`scripts/main.gd:22`, `:151`, `:276`) and tests/docs. The one-charge instruction needs one shared configuration contract across gameplay, help, HUD, automation and tests, not a single changed label.

## Driver state machine

| State | Behaviour | Exit |
| --- | --- | --- |
| WAITING | Preallocated, invisible, collision-disabled and frozen at a designated entry slot | Scheduled launch-relative activation in a clear spawn volume |
| DRIVE | Bounded longitudinal force, steering torque and modest lateral tire grip toward an authored lane | Leader/hazard/right-of-way requires YIELD; impact causes UNCONTROLLED; normal exit causes EXITED |
| YIELD | Brake to a safe target speed or stop; retain heading and observe a finite reaction time | Path clears, then DRIVE; impact causes UNCONTROLLED |
| UNCONTROLLED | Motor, lane correction, artificial yaw stabilization and AI braking disabled; retain real linear/angular velocities | Motion settles, then SETTLED |
| SETTLED | Remains a physical obstacle; can receive another physical impulse without restoring driver control | Can move again as UNCONTROLLED; never return to normal driving this attempt |
| EXITED | Only an uncredited, normally driven car may leave through its exit portal; disable presentation/collision without destroying its actor | Reset only |

Damage state and player causality are separate from driver state. A baseline traffic accident can release driver control and show a dent without earning a claim. In the intended layouts, no-input traffic should not produce such accidents; the distinction is still needed so a defect cannot pay the player.

Cars are already rigid bodies: the **handoff is withdrawing driver authority, not changing bodies**. Latch the impact state in the physics contact step before the next motor update. Do not wait for a deferred UI/wreck signal, zero velocity, snap back to the road, or set a new target velocity after a collision. Tire grip can oppose ordinary controlled side slip; it must cease at release so it does not erase the side impulse needed for the pile-up. Keep driving forces bounded relative to mass. Emergency finite-state guards are justified; repeated speed clamps that erase an earned crash are not normal steering.

## Contact, momentum and claims

1. A car's AI motion is uncredited. Player rider contact, a credited wreck's contact, or an explicitly sourced blast may seed its `cause_id`; moving through a trigger volume alone cannot.
2. Qualify a traffic collision using contact-point velocities and normal expressed in a common frame. Ignore floor support, resting contact and separating/tangential grazing. Validate the normal sign/frame with isolated front and side fixtures rather than assuming the existing subtraction is correct. `ragdoll_limb.gd:35–53` already preserves incoming velocity/spin and measures resolved normal velocity change when a first-contact solver impulse is zero. Traffic needs the same tested first-contact robustness, accounting for known bounded driver forces rather than crediting acceleration as a collision.
3. AI releases on a substantial collision or player impulse. Damage qualification is independent: a push can displace a car without immediately paying its full value. Use a meaningful collision threshold based on closing speed/impulse, not origin travel.
4. Record immutable edges: source actor/cause, destination stable vehicle ID, simulation time, contact position, normal strength and whether damage was newly awarded. Resolve simultaneous contacts consistently by strongest qualifying normal impact, with a stable-ID tie-break; do not let iteration order choose causality.
5. A credited car hitting a new car can propagate the cause and claim only through an actual qualifying contact. The existing score-once ledger remains the authority (`game_rules.gd:75–88`). AI travel, braking, repeated contacts and already-wrecked cars cannot mint new property claims.
6. Keep wrecked car bodies and momentum physical, as the current props already do. Do not add a magic secondary-car launch just because a first car scores. A stopped credited car can still cause a rear impact from following traffic: the relative closing contact supplies the energy, not a new launch impulse.
7. A unique causal edge and a unique payout are different. A dented car might strike two cars after its own one-time claim; preserve the graph without paying it again.
8. Keep the property multiplier's 3.5-second window and maximum ×8 initially. Build the intersection distances/speeds so its physical second and third contacts can fit that window. A traffic-specific multiplier is unnecessary before that layout is proven.

**Single-breaker interaction:** exactly one successful activation per attempt, available at bail, retained across pause/help/replay and reset only by a new attempt. The rider relaunch is the primary effect: start with the existing 8.5 m/s horizontal and 2.7 m/s upward additions, consistently across the eleven body parts, excluding the board. An optional tight directional debris pulse shares one environmental budget across every affected prop; start with the companion proposal's 2.2-metre radius, 70-degree cone, total impulse budget 90, per-actor cap 60 and light-prop velocity cap 4 m/s. These are hypotheses, not proven settings. No nearest-car targeting exception, unchanged radial wave, mass-scaled car launch or `activate()` auto-ignition. A gentle sourced nudge establishes provenance without awarding damage. The rider must physically reach A; A's existing momentum then powers its contact with B. Place B outside the pulse and record that it receives zero direct breaker impulse.

Reachability must be proved from the actual `.72` forward-carry/net `−1.7` vertical bail (`main.gd:287`), not a staged rider at the road. With a proposed mass of 180–240, the environmental per-car cap adds only 0.25–0.33 m/s. It is not a substitute for a reachable moving target. Record multiple prior stair contacts and a useful interception window from at least two launch/pose configurations. Adjust road proximity, phase, headway and collision mass together before raising relaunch strength; immediate boost should not become the universal way to fly over the staircase.

The first demonstration excludes nearby explosive drums so success proves car-to-car propagation. Later layouts may combine drums and traffic, but receipts should distinguish blast-seeded vehicles from contact descendants.

## Geometry, timing and reset

Use a cross-road beyond the stairs rather than placing traffic on stair treads. Initially try two lateral lanes centred near `z = stair_length + 7` and `+10.6`, with a queue/transfer zone farther back. Orient the existing taxi hull along its route. Opening side-curb gaps and extending a flat road to occluded portals is necessary: do not wrap visible cars through the current curbs. Keep the end-wall buffer large enough for rotated hulls; dimensions follow a VehicleSpec, not the current `nominal_radius` shortcut.

Start at the lower end of roughly 5–8 m/s, with two movers and one queued car. These are tunable arcade speeds. Derive minimum bumper headway from `v * reaction_time + v² / (2 * brake_acceleration) + safety_margin`, not an attractive-looking fixed gap. For example, the companion proposal's 6–9 m/s and 4 m/s² brake settings need 6.9–13.7 metres at a hypothetical 0.4-second reaction, before safety margins. The existing plaza is not automatically large enough. Same-lane following uses safe headway; crossing conflicts use authored right-of-way and a swept-hull clearance check. A player suddenly pushing A across an otherwise clear route creates the late hazard; ordinary fleet scheduling must not create it. Do not make omniscient drivers dodge every wreck, or deliberately make them crash without the player. Drivers do not target the rider.

Preallocate every car once per attempt and assign stable fleet-slot IDs. Reset schedules, motor state, poses, velocities, damage, cause graph, wheel phases and lights together. WAITING vehicles activate only in a verified clear spawn volume. If a portal is blocked, keep its next car waiting; never spawn inside a wreck. Do not recycle a scored actor as a fresh payable car or spawn an infinite reinforcement stream. Credited wrecks never disappear at a normal portal just to clean the screen.

Traffic schedules and reactions use simulation time starting at launch, so waiting in READY does not advance the puzzle. Each route repeats a stable initial phase; launch speed, line and breaker timing change interception. Freeze in MENU/READY/RESULTS, and pause all drivers/schedules with the game. Traffic slows with the same global time scale as the rider; do not drive cars using `_process`'s unscaled `real_delta`. UI/camera can retain their current unscaled timing.

Settlement watches only rider motion, credited uncontrolled vehicles, pending credited impacts/fuses and a short bounded opportunity for traffic to reach a new credited obstruction. An uncredited DRIVE car is not cascade activity. Use an initial 1.5-simulation-second imminent-arrival horizon: a currently active car's swept path must intersect the credited obstacle's hull within that interval. A merely scheduled future spawn is insufficient. Maintain a fixed deadline for that quiet-chain grace episode rather than refreshing it every tick; actual new credited contacts may restart normal motion/idle tracking. The rider leaving the arena should switch focus to a pending traffic chain rather than immediately cut it off, but the existing out-of-bounds shortcut stays valid when there is no bounded causal work. Retain explicit 16-simulation/34-frame-clock ceilings unless testing justifies a change.

## Replay and readable presentation

Record the approach plus crash, with a single stable actor list and a bounded frame buffer. At each snapshot include car transforms, visibility, damage preset/region, driver state for display, cumulative wheel angle and brake-light state; record causal edges separately at full event timing. Results preserve the final snapshot. Replay disables AI, collision scoring and schedule advancement, and restores recorded presentation rather than resimulating traffic. Restore the final frozen state afterward. Do not use transform interpolation to move an invisible WAITING car through the scene between activation frames.

The camera must reveal the road before the player spends the only charge, then follow the active car handoff when the rider is separated. Keep an offscreen rider marker and anatomy display. Select the most recent meaningful cause edge rather than an arbitrary normally cruising car. Avoid zooming out until detailed new models become tiny. New mesh fidelity needs cheaper compound/convex hulls and separate wheel visuals; visual dent presets are adequate for the first traffic prototype. Replacing one whole-car material with grey, as current damage does, will not satisfy a later fidelity pass.

## Three scenarios

| Existing level | Traffic second act | Meaningful choice | Cascade payoff |
| --- | --- | --- | --- |
| Civic Cascade | Two-way taxi cross-road with a short queue | Intercept a broadside taxi or displace it into the opposing lane; save the one charge for the road | Moving taxi crosses the other lane and obstructs the queue, producing a readable three-car pile-up |
| Night Market | Slow delivery/taxi traffic at a crossing, with staggered yielding turns | Hit the turning vehicle's rear quarter during its committed crossing instead of simply pushing straight | Deflected vehicle enters the lane of a second arrival, which pushes into the small waiting delivery queue |
| Port Authority | A paced convoy exiting a narrow terminal gate; prototype with existing taxi hulls first | Break the lead vehicle's line near the bottleneck instead of using the charge early on cargo | The obstruction redirects a follower toward the adjacent outbound lane and a third vehicle; heavy vehicle art/mass variants come only after the base chain works |

Differentiate timing and spatial transfer first, not just vehicle skins or more traffic. Preserve the three existing staircase counts and downstream stairs/cargo routes while changing the bottom plazas. Each scenario must retain a useful no-breaker route; the single charge creates one stronger commitment rather than becoming a compulsory rescue after every bail.

## Meaningful verification

- Run traffic alone for longer than a full attempt: zero claims, no spontaneous player cause, no scheduled overlaps, no baseline pile-up. Vary starting phase/headway fixtures, not just the happy seed. Test maximum supported speed against the actual braking/headway rule; count contacts and minimum separation rather than accepting zero payout alone.
- Drive well beyond 0.55 metres, then apply a below-threshold touch: no origin-travel payout. A genuine hard later contact can claim once.
- Physically intercept A from an actual stair bail, then observe A→B→C contact edges with measured closing strength. B receives zero direct pulse impulse and begins outside pulse reach. Repeat with B displaced out of reach: C must stay uncredited. This proves contact propagation rather than proximity or a scoring callback. Record the input-time interval that permits the chain, the prior distinct tread contacts and the rider's state at activation; a single scripted point solution is not an accessible opportunity.
- Compare front, side, separating, resting and floor contacts; verify finite velocities, normal conventions and no duplicate claim after multiple collider contacts in one tick.
- Verify that a struck car's next physics step receives no motor/steering correction and retains incoming linear/angular motion. Do not assert perfect momentum conservation across ground friction or an engine-powered baseline; compare controlled forces before release and physical collision transfer afterward.
- Single charge: one real input succeeds; repeated/held/released input, cooldown expiry, pause/help, replay and file persistence cannot restore it. A new attempt restores exactly one. Direction changes actual car interception, not only the preview arrow.
- Spawn blocked by a settled wreck: next vehicle waits, never overlaps or pops in; credited vehicles remain present; fleet/IDs stay bounded.
- Pause and .55/.18/.25 speeds: equal simulation-time schedules produce equivalent arrival windows; quiet uncredited traffic cannot keep results away; a credited pending chain survives rider out-of-bounds until it settles or reaches the explicit cap.
- Replay car visibility, wheel phases, lights and dent states match recorded frames; no new causes, claims or fund changes. Reset restores the identical traffic schedule and healthy fleet.
- Across all three layouts, use actual physical runs to show a reachable three-car contact chain with at most one charge, useful unboosted outcomes, and multiple distinct intercept timings. Keep those fixtures separate from medal/claim tuning.
- Native playtests and captures must establish that players see the road opportunity, distinguish their one direct seed from later contacts, and can explain the chain. Higher polygon counts and headless passes are not evidence of that.

## Smallest implementation slice

First fix the single-charge contract and isolate contact-based traffic scoring. Then build Civic's finite rigid-body fleet, bounded DRIVE/YIELD logic and clear road portals. Prove one physical three-car chain and its negative control before adding Market/Port configurations. Add replay/presentation state alongside the fleet, then fit higher-fidelity car models to the validated VehicleSpec. The large attraction to avoid is realistic wheel/suspension simulation plus autonomous city navigation; it expands the project before proving the crash's second act.

## Cross-review: three implementation risks

1. **The sole relaunch may not intercept traffic from a real stair tumble.** The single-breaker proposal is right to preserve the current rider impulse rather than multiplying three charges into one. However, its heavier car masses and limited debris pulse do not establish that A can transfer into B's lane. Position/timing must supply a broadside contact using A's own energy. The smallest fix is the actual-tread Civic 2+1 experiment, measuring a nontrivial input window and stair contacts before adding all three traffic scenarios. Do not substitute a car placed beside a motionless rider for that gate.
2. **Plausible-looking headway can cause passive pile-ups.** The suggested speed/brake ranges span more than a twofold stopping-distance difference. Safe bumper gaps, turn reservations and portal clearances must be computed from the physical hull, not nominal radius or visuals. The smallest fix is a low-speed traffic-only fixture with two movers, one waiting actor and varied schedule phases; introduce player-generated crossing hazards only after it remains collision-free for longer than an attempt. A zero-payout passive pile-up is still a gameplay failure.
3. **Art and HUD may harden incompatible rules before the collision contract works.** The art proposal's vehicle table correctly allows a caused car to strike a fresh victim, but its implementation-order text still says traffic cannot earn claims from collisions with inactive props. Its request for three bottom lanes also exceeds the first proof's necessary geometry. The smallest fix is a shared VehicleSpec and explicit driver/cause/damage/paid fields, removing that blanket scoring prohibition and postponing final traffic layout/model envelopes until Civic's physical chain and camera are observed. High-fidelity meshes can then fit proven pivots and collision geometry. Native views must show the interception opportunity and second contact; a turntable and headless contact graph alone cannot establish that.

The impact reviewer correctly rejected this document's initial nearest-car breaker exception and six-car opening slice. Both have been removed in favour of the shared rider-primary, budgeted pulse and three-car proof. These are source-grounded design judgments; no new physics test, native render or human playtest was performed for this proposal.
