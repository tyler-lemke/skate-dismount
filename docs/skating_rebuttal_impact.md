# Internal rebuttal — impact and motion

This is an internal Codex follow-up to [the internal impact review](skating_review_internal_impact.md), not an Antigravity review. The failed external attempt remains unchanged. These rankings are design judgments; no new gameplay evidence or implementation is claimed.

## Concession: replace I09 with I02

The root challenge is correct. **I09 should leave the top five.** The current handoff already copies each visible part's global transform and creates joints from the matching pose anchors. My initial ranking overvalued the need to preserve those properties during a future animation change as if that preservation were a substantial new player benefit. Its genuinely new portion—manual weight-shift anticipation that changes first contact—is a separate mechanic, with input-latency and balance costs that this first pass does not need.

I revise I09's individual score from **87 to 76**: useful eventual crash choreography, but lower immediate incremental value and more scope than the initial score acknowledged. Preserve the existing handoff as a mandatory integration gate within I11; defer new anticipation mechanics. The gate still requires engineering and verification time. Removing its feature slot does not remove that work.

## Strongest case for the story review's foot choice

A planted front foot and a rear foot that visibly leaves, kicks, and returns are the defining visual evidence of a skateboard push. Players can see sliding feet during every approach. A better character model, sound, or a mathematically smooth torso animation cannot compensate when the body appears disconnected from the deck.

I02 also exposes the real prerequisite cost rather than burying it under I11. The existing models include shoes inside the shin mesh, so an ankle target cannot simply be equated with the sole contact point. The work includes deliberate foot/deck anchors, a stable limb-length and knee-bend convention, a planted-foot constraint, and a predictable transition to the kick. Those are concrete benefits and costs, even if the initial implementation uses an authored stance plus a small two-segment solve instead of broad terrain-adaptive IK.

The story reviewer is therefore right to select foot contact explicitly. I retain I11 over a standalone I09 because fixing the present pose overwrite is a demonstrated current need; preserving the existing bail continuity is a requirement of that fix.

## Revised top five, ranked

1. **I11 — Coherent animation ownership:** one driver for coast, push/contact/recovery, crouch, and carve. Remove the static launch-pose overwrite. Preserve matched visible transforms and joint anchors at bail.
2. **I03 — Useful push and coast:** physical speed gain follows the kick, tap and hold share cadence, and charged launch versus pushing has one understandable effort model.
3. **I02 — Stable planted feet and stance:** explicit deck and sole anchors, consistent knee bend, and bounded contact correction during the kick and turn.
4. **I05 — Forgiving heading and lean:** a readable arc with enough correction to choose the existing crash lanes; little additional slip initially.
5. **I01 — One readable protagonist:** a bounded silhouette/proportion/material pass built to the validated contact and animation contract, preserving eleven injury regions and fitted hats.

**I14 remains the nearest unselected addition.** Event sound offers excellent value once movement events are correct. However, a sound overhaul would currently communicate a kick whose foot may still miss the ground or slide on the board. Include the ordinary effort to trigger one existing or temporary kick sound when validating I03; do not pretend that delivers I14's surface layers, roll/skid mixing, receipt ducking, haptics, or audio audition. Estimate that fuller audio work separately and revisit it after the contact slice.

## Overlap boundaries and accounted work

| Boundary | Responsibility kept separate | Cost that still belongs in the plan |
| --- | --- | --- |
| I02 versus I11 | I11 chooses/blends the intended action and owns final pose composition. I02 constrains the planted foot and knee against defined contact targets. | Foot/sole pivot setup, small leg solve or authored correction, push-foot release/replant transitions, and integration tests. There cannot be two systems overwriting the final transforms. |
| I09 versus I11 | Existing transform/anchor handoff is an I11 integration gate. New manual anticipation and first-contact steering remain deferred I09 features. | Matching animated joint anchors, checking pose/velocity mapping at bail, immediate collision response, injury/replay regression. This is not a zero-cost deletion. |
| I07 versus I09 | I07 keeps rider and board together through a jump and returns to skating. I09 releases the rider into the existing ragdoll. | I07 would require airborne locomotion, landing, control remapping, and route validation. None is a prerequisite for the preserved I09 handoff. Do not smuggle an ollie into "better dismount." |
| Minimal I04 support versus a controller rewrite | The selected package needs trustworthy push eligibility and shared contact/velocity/heading data. It does not need a full skate simulator. | Ground/contact probes and a bounded collision query need explicit estimation. If those demand replacing the motor, prototype and price that work before committing to the art pass. |

## Smallest honest first playable

Use the current segmented character on Civic's existing apron. Establish sole/deck anchors and the contact signal; make I11 and I02 produce a stable coast stance. Add one complete I03 planted kick and recovery, then a restrained I05 turn. Transition immediately into the current ragdoll with the visible pose and matching anchors. Native observation must show that the foot contacts explain the speed gain, turning still permits deliberate lane choice, and the body retains the successive real-tread injury sequence after bail.

Only then apply I01 to the agreed pivots, proportions, and region contract. Keep the current control vocabulary and skip new airborne tricks, manual-bail windups, expressive face rigs, and a full audio layer for this first playable. This revised selection counts foot contact as product work and treats handoff preservation as the necessary integration cost it is.
