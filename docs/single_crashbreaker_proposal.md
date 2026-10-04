# One crashbreaker and physical traffic — planning proposal

This is a design and architecture proposal, not an implementation. It is based on the current Godot controller, rigid bodies, claim rules, replay, and tests. All proposed tuning values below are starting hypotheses requiring physical checks and native playtesting.

## Decision: one deliberate intervention, available at bail

Give every attempt **exactly one crashbreaker, available immediately after bail**. Do not require an injury score, destruction count, meter, or previous successful collision to earn it. A weak initial crash is precisely when a new player needs a way to reach another target. An earned meter would favor already-successful runs and could make the new moving traffic irrelevant to a stalled rider.

The player keeps the existing directional controls and Tab slow motion. A Shift press captures the current aim and commits the effect once; it does not introduce a second charge/release interaction. Prefer a clear direction marker over an exact landing/intercept prediction that chaotic ragdoll collisions cannot honor. Cars receive no target-lock teleport or invisible attraction.

Use attempt-local states `AVAILABLE` and `SPENT`, with a guarded pending activation if the input must wait for the next physics step. Mark the charge spent before applying effects. It resets only when a new attempt is created, never on another collision, a replay, pause, a route UI refresh within the same attempt, or a treatment payment. Invalid presses outside CRASH consume nothing. A valid press may still miss its target; it must never promise a guaranteed collision.

The existing 1.4-second recharge concept becomes unnecessary. Remove its recharge wording and three-dot UI rather than leaving a cooldown meter that implies another use is coming. Show one ready symbol, an aiming instruction, then a spent state. Results and replay already have separate passive HUD states; retain them.

## Rider first; any nearby shove must have a small, finite budget

The rider impulse is the primary effect. Start with the current **8.5 m/s horizontal velocity addition and 2.7 m/s upward addition**, applied consistently across the eleven body parts so the impulse does not tear the pose apart. Continue excluding the detached board. These are playable-unit parameters, not realistic human propulsion. Do not triple the strength because the count falls from three to one: the previous downward bail tuning deliberately restored stair impacts.

My lowest-risk prototype would test the rider impulse alone. If retaining the expected crashbreaker shockwave in the first shipped slice, use the following constrained hybrid rather than the present omnidirectional environmental launch:

| Parameter | Initial hypothesis | Intended behavior |
| --- | --- | --- |
| Rider horizontal addition | 8.5 m/s; explore 7–9.5 | Reach a nearby second impact without skipping the whole route. |
| Rider upward addition | 2.7 m/s; explore 2.2–3.0 | Clear a low obstruction while returning promptly to contacts. |
| Environmental radius | 2.2 units; explore 1.8–2.5 | Affect objects immediately around the body, not an entire lane cluster. |
| Environmental cone | 70 degrees total, centered on horizontal aim | A leftward attempt does not equally push the opposite lane. |
| Environmental impulse | Total budget 90 mass·m/s; at most 60 per object | Increasing nearby prop count cannot increase total delivered environmental momentum without bound. |
| Light-object velocity cap | At most 4 m/s added by this pulse | A cone or loose part cannot become a high-speed projectile because of low mass. |
| Falloff and obstruction | Smooth distance/angle falloff; blockers occlude the pulse | No force through the plaza wall or hidden targets beyond the chosen direction. |

Compute candidate impulses from the bounded weight, cap each by its velocity allowance, then scale them together if their sum exceeds the total budget. A mass-5 crate could receive up to 20 impulse units before the velocity cap; a mass-200 car could receive at most 60, or 0.3 m/s. Applying one common velocity addition to every object would make the car as easy to move as the crate again.

**Do not call the existing `CrashProp.activate()` for the new environmental pulse unchanged.** That method immediately ignites every explosive (`scripts/crash_prop.gd:74–78`). A small nudge would still become an instant drum trigger. Apply the physical impulse and record its causal source separately; ignition or damage must meet its own subsequent measured movement/contact or meaningful blast threshold. The button itself never awards property points or declares cars wrecked. A visually explosive pulse needs an honest small effect volume; avoid a huge visual blast that implies force everywhere.

The same mass-independent velocity problem exists in drum explosions (`scripts/main.gd:329–330`) and the RUN obstacle shortcut (`main.gd:265`), not only in the crashbreaker. Car-specific momentum handling must cover those paths too. Otherwise a carefully capped crashbreaker is irrelevant because the next nearby drum launches every heavy car at the same speed as cargo.

## Time, settlement, and replay

Apply the captured impulse once at a physics boundary. Do not multiply it by frame delta or divide it by time scale. Given the same starting state, the immediate velocity addition should be the same at normal, automatic-slow, manual-slow, and impact-pulse rates, subject to documented safety caps.

Physics, AI driving, contact resolution, and drum fuses use simulation time together. Camera movement, impact-emphasis duration, aim feedback, and presentation deadlines use the existing unpaused presentation clock. Pausing stops both gameplay advancement and the attempt deadline; neither a held key nor key repeat can spend the charge on resume. A retry clears a pending activation before the old actor graph is removed.

Reset idle-settlement accumulation when the ability is activated, so an already-still rider receives a chance to move. Retain the hard presentation deadline; do not extend it indefinitely for traffic or a late activation. Only rider motion, physically disturbed causal actors, and relevant pending explosion events should postpone automatic settlement. Untouched cars cruising on their routes must not keep the run alive. The timer shown to players should describe the limiting remaining time consistently, rather than implying sixteen real seconds while using a different hard deadline.

Record the ability event and its captured aim for replay presentation. Replay reuses recorded actor states and never reapplies the impulse, AI drive, collision awards, or treatment payment. The current replay array is assembled at bail (`main.gd:290–292`), so a traffic system that spawns new physical cars later would require a larger actor-lifecycle recording change. The first traffic slice should use a fixed roster created before launch.

## Moving cars: keep the same finite-mass rigid body

Prefer one `RigidBody3D` per traffic vehicle for its entire lifetime. A small driver controller follows a short authored road path with bounded acceleration, steering torque, headway braking, and obstacle braking. Apply forces/torques through physics; do not assign a desired transform or overwrite the full velocity every frame. Normal driving must not call the prop's causal activation method.

On a meaningful collision, switch the driver to a persistent crashed/uncontrolled state and cut propulsion and steering correction. The same body keeps its current transform, velocity, angular velocity, collision shape, and score identity. Subsequent collisions can move it and carry the chain. Braking merely because it observed the rider does not make it claim-eligible.

Initial vehicle hypotheses:

- Mass around **180–240**, compared with the current eleven-part rider's total mass of **35**. The current taxi mass is only **40** (`world_builder.gd:180`), so it is barely heavier than the rider. Use consistent mass and damage rules for the same vehicle archetype whether parked or driven.
- Initial traffic speeds around **6–9 m/s**, bounded acceleration around **2 m/s²**, and braking around **4 m/s²**. Test whether the bottom intersection can be read before increasing speed.
- Begin with two cars in one Civic crossing, then a small fixed roster per route. Seed initial spacing and start driving from a defined launch-time event so retries are learnable. Do not make holding the READY screen quietly advance traffic into a different puzzle.
- Use generous braking/headway spacing in the no-player baseline. A car should be heavy but still capable of striking another car or cargo with its own carried momentum after the player disturbs it. Reduce thresholds only after observing the actual contact trace; do not make every touch a wreck to force impressive totals.

Avoid a kinematic-to-rigid swap for the first version. Before the swap, a velocity-driven kinematic car can behave like an infinite-mass mover. Swapping after contact may occur after the solver has already applied that response; duplicate shapes, overwritten momentum, changed actor IDs, and replay discontinuities are additional failure modes. It is viable only with a carefully tested pre-contact conversion and identity/lifecycle contract, which is more work than the bounded dynamic driver needed here.

A dynamic servo also has traps: it can inject unlimited energy when its commanded speed is blocked, fight collisions to return to a lane, or self-right an overturned wreck. Cap acceleration/torque, disable corrections on the crash transition, and never use a transform snap as a recovery action. Apply any mild upright assistance only while an intact car is grounded; keep it off once disturbed or airborne. Path endpoints should brake and park, or retire an actor safely outside play without reusing its claim identity. Do not loop a scored car through a teleporting respawn.

## Separate movement, cause, damage, and payment

The existing prop logic cannot be inherited unchanged by normal traffic. Once `armed`, it marks a prop broken after moving 0.55 units from its original position (`crash_prop.gd:48–53`). A car that has driven down the road would cross that distance before the player touched it. If a light causal graze then sets `armed`, routine transit could immediately become a full claim.

Vehicle damage must come from substantial measured contacts or a bounded, meaningful blast. Normal speed, distance traveled, path progress, lane changes, or braking are not damage evidence. Use contact-normal closing speed and measured impulse/observed normal momentum change, with mass-aware response and per-contact-episode debouncing. Do not treat total relative tangential speed against the road as a frontal impact. The existing first-contact zero-impulse behavior means a measured fallback remains necessary, but it must not mistake the vehicle's own bounded drive force for crash damage.

Keep these concepts distinct:

1. **Driver state:** healthy control versus crashed/uncontrolled.
2. **Causal eligibility:** a documented actual player/body, causal prop, or meaningful blast event may propagate responsibility through subsequent physical collisions.
3. **Damage state:** the vehicle has crossed its injury/deformation threshold.
4. **Paid identity:** this attempt has already awarded this actor's property claim.

An AI observation does not establish cause. An impulse may establish cause without enough severity to wreck the car. A previously paid wreck can remain physical and cause a new victim's damage without paying twice itself. Collect collision events from both participants and resolve/deduplicate pairs consistently; callback order must not decide whether the second car inherits an already-verified chain. Keep stable actor IDs and event sources so the result can explain rider → car A → car B.

## Lean build order and dependencies

1. **Define the impact contract and vehicle damage boundary.** Separate normal locomotion from causal activation and destruction. Add a stable actor roster/event identity suitable for existing replay. Prove the normal-driving and parked-contact cases before adding visual polish.
2. **Change the attempt budget to one.** Implement atomic spending and the rider impulse on the existing static routes. Add the capped local pulse only with its separate impulse/ignition contract. Update HUD, instructions, automation, and replay state in the same slice.
3. **Prototype one dynamically driven bottom car.** Keep one body and cut its driver on a meaningful collision. Validate no-input transit, contact mass response, pause/slow time, and result freeze.
4. **Add the second car and prove physical causality.** Place the second victim outside direct pulse range. It must receive momentum and damage through a recorded car-to-car contact. A missed pulse must not award it anything.
5. **Expand authored traffic to all three routes and recalibrate.** Rerun lane/pose/stair, timing, progression, and populated-save scenarios. Only then freeze vehicle collision envelopes/pivots for the higher-quality models and bind the polished HUD to final ability/traffic/claim states.

The smallest complete playable is Civic with one available ability, two physically driven cars, readable aim, one possible car-to-car cascade, and an unchanged honest claim ledger. It does not require general navigation, a car roster, respawning traffic, deformable collision meshes, or a full vehicle simulator.

## Required behavioral cases and existing tests

| Case | Required evidence and affected tests |
| --- | --- |
| Exactly one charge | New attempt starts available; one valid press spends it; repeated/reentrant calls and held-key echoes cannot create another impulse. Invalid READY/RUN/RESULTS/REPLAY presses do nothing. Replace the three-boost loops in `tests/test_game.gd:54–60` and `test_playability.gd:139–157`; this is a requested contract change, not a weakened physics assertion. |
| Same effect across clocks | Compare the immediate captured impulse at the same state under rates 1.0, 0.55, 0.25, and 0.18. Pause prevents activation/advance; retry clears pending work. Observe motion separately from time-scaled presentation. |
| Direction matters | Opposite aims produce materially different rider velocity and subsequent target opportunity. Preserve the existing directional-impulse test intent; do not require the previous exact approximately ±7.16 readings if the selected effect changes. |
| Bounded local pulse | A near light prop moves within its cap; a heavy car responds less to equal delivered impulse; distant, behind-cone, and occluded actors receive none. Increasing candidate count cannot exceed the total budget. No payment is awarded merely by pressing the key. |
| No passive traffic money | Complete a normal traffic cycle without player interference: no causal eligibility, score, or combo; normal path distance never triggers a car wreck. Incidental autonomous accidents must not earn a player claim either. |
| Physical second victim | Car B outside blast range is damaged only after actual contact with player-caused car A. Inspect contact source, normal closing speed, and transferred momentum. B scores once; repeated contacts with A do not repay A. |
| Drive cannot overpower impact | After meaningful collision, propulsion/yaw correction stay off. The car does not snap back, gain energy against a wall, or magically self-right. Subthreshold brushing has a deliberately defined, repeatable response. |
| Mass and contact fidelity | A glancing low-energy rider contact does not fling a car like a crate; a moving car can deliver a strong body impact. Thin obstacles and car pairs do not tunnel at the maximum permitted speed. |
| Finite attempt/replay | Untouched moving cars do not prevent idle settlement. Pending causal fuses are handled consistently. Results freeze every car. Replay reproduces actor and damage states without driving, new impulses, new claims, or additional treatment money. |
| Keep the core crash | Preserve the representative actual-tread gate: multiple anatomical regions and successive real stair surfaces, not only hits on props above the stairs. Existing bounded severity, no resting/board injury, and ledger balance checks remain. |

Update assertions and UI copy that explicitly say three charges or recharge; retain physical causal tests and banking invariants. Add a zero-input traffic control to distinguish a real improved cascade from an autonomous crash that would have happened anyway. Human observation is still needed to judge whether one attempt contains an understandable timing choice and a satisfying second impact.

## Treatment progression and prior records

Keep the **$600,000 treatment goal provisionally unchanged**. The current report reaches **$969,655 from the best zero-crashbreaker route claims**, so reducing three charges to one does not alone prove a lower goal is necessary. That is evidence from the old stationary-car layouts, not a guarantee for the proposed moving traffic or heavier cars.

Re-measure all three routes with no boost, early boost, a deliberate traffic-intercept boost, and a miss. Record both final claim and genuinely new banked money. Verify a plausible path to the goal without requiring perfect traffic timing. If the one useful choice becomes pressing immediately every time, or saving forever because missed attempts are punishing, adjust lane opportunity, traffic timing, or bounded impulse before adding a refill meter.

The existing best-only bank awards only improvement over each prior route record. A physics rebalance can make a previously earned record harder to beat; test both fresh and populated saves. Preserve earned treatment funds and historical records. Do not silently reset money or declare that old scores were never earned. If measured new scoring makes progress inaccessible for partial old saves, propose an explicit record-version migration that retains earned funds rather than hiding a wipe in the traffic update. No persistence redesign is assumed until that concrete compatibility check is performed.
