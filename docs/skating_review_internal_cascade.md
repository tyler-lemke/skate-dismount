# Independent internal fallback: Domino Architect

**Reviewer: Codex, internal fallback. This is not a Claude response.** Claude first timed out, then returned an API connectivity error with DNS `ENOTFOUND` when retries were disabled. This review uses the supplied source-grounded packet and its exact I01–I20 proposals. Scores apply the packet's 30/25/20/15/10 weighted rubric; they are design judgments, not measured enjoyment. No implementation or human playtest was performed. The ranking was revised after challenging whether I09 supplies new behavior beyond the existing handoff.

## Diagnosis

The most immediate defect is that riding actions do not visibly explain movement. `pose_ride()` assigns bob and lean, then `apply_launch_pose()` replaces the anatomy with a static selected crash stance. W continuously adds speed, A/D translates sideways, and the body follows the stair-height function. More clothing detail will not repair that disconnect. Conversely, a comprehensive skateboard motor could spend the whole budget solving stair collisions and destabilize the existing cascade game.

Build a convincing short approach with observable effort, steerable intent, and a clean fall. The chosen crash pose should influence the moment of dismount, rather than freeze the character throughout the approach.

## Scores

| ID | Score / 100 | Verdict | Explicit dependency | Biggest concrete objection |
| --- | ---: | --- | --- | --- |
| I01 | 82 | Keep, constrain | Stable proportions, joint centers and eleven injury regions agreed with I11/I09 | A face and clothing folds may be invisible at the current chase framing; anatomy and silhouette deserve the art budget first. |
| I02 | 90 | Keep, staged | Consistent segment lengths, deck foot anchors and I11 push phases | Full IK is unnecessary before a convincing planted stance exists, and can add knee jitter without improving control. |
| I03 | 94 | Keep | Grounded gate, foot-contact phase and a push/coast animation slice | Removing automatic acceleration may turn every restart into several compulsory kicks unless launch speed and approach duration are calibrated together. |
| I04 | 72 | Defer full motor; prototype probes | Flat/lip/step fixtures and independent cascade baselines | The real stairs are a hostile wheel surface; a rewritten motor may repeatedly snag before the player reaches the useful crash. |
| I05 | 89 | Keep, arcade bounds | Heading state and I11 lean; target-approach fixtures | Realistic momentum lag can make three familiar lane targets harder to hit without creating a rewarding alternative. |
| I06 | 73 | Defer powerslide | I05 heading plus coherent friction/speed data | Braking is useful correction, but the slide adds another mechanic before push and steering are credible. |
| I07 | 70 | Defer | I04 airborne contact, new control teaching and I09 continuity | Reassigning Space destabilizes a proven interaction and lets hopping bypass the objects that currently make the crash interesting. |
| I08 | 57 | Defer | Contact/compression phases and optional route equivalent | A timing prompt on top of push cadence creates two rhythms competing for attention during a very short approach. |
| I09 | 79 | Rework into integration requirement; defer anticipation | I11 pose output, explicit measured velocity and I02 anchor contract | Global transform copying, inherited velocity and joint-anchor handoff already exist; counting their preservation as a new feature overstates marginal benefit. |
| I10 | 66 | Defer | Swept/contact-aware collision data, angle fixtures and existing prop impulse contract | Adding survival thresholds to the current approximate proximity trigger would make similar-looking impacts behave inconsistently. |
| I11 | 95 | Keep, staged | I03/I05 action signals, planted-foot anchors and stable segment proportions | Shipping every listed state plus a new skeletal character is a large animation project; the useful first slice is much smaller. |
| I12 | 86 | Keep as near miss | Agreed rider/target framing and settings | Speed-based camera motion can make the new push and carve feedback harder to inspect; more cinematography is not automatically more legibility. |
| I13 | 79 | Keep later | Board travel, heading and clearance signals | Correct spinning wheels on an otherwise sliding mannequin advertise the unresolved locomotion defect. |
| I14 | 83 | Keep later | Real push/contact events, I03 cadence and contact provenance | Extra clacks and skids may bury the cascade sounds; the proposal needs an audio mix budget, not just more event emitters. |
| I15 | 77 | Defer detailed garment damage | I01 material regions and current eleven-region/replay ledger | Small scuff textures may read worse than the existing simple injury markers at normal gameplay distance. |
| I16 | 48 | Defer | I01 face and a demonstrated camera view where expressions are legible | Expressions will usually be unseen; presenting relief after bodily injury also needs careful tone around Mom's treatment. |
| I17 | 60 | Defer | Stable model roots, clipping bounds and recorded visual state | Springy accessories draw attention to a stiff torso, and their replay state adds work before the main motion is solved. |
| I18 | 76 | Rework to contextual cues | Final I03/I05 controls and first-run persistence | A fifteen-second lesson can exceed the normal run-up; it must never become another stage on every retry. |
| I19 | 63 | Defer | Approach recording before bail, optical clutter limits and zero simulation participation | The current replay begins at the crash, so the apparent reuse omits recording the very approach this idea needs. |
| I20 | 75 | Defer geometry; plan target lines | Chosen movement mechanics and time-to-crash budget | A bank, gap and carve together create three movement obligations before any one is proven fun. |

## Exactly five recommendations

1. **I11 — Coherent skating animation.** First remove the static crash-pose overwrite. Start with procedural push, coast and carve transitions on the current separated parts; keep state data compatible with a later rig. The first milestone does not need an airborne clip or facial rig. Strongest objection: authored animation is wasted unless its timing corresponds to actual movement events.
2. **I03 — Push/coast speed management.** Give one kick a visible contact, bounded propulsion and recovery. Hold repeats the same action rather than bypassing it. Preserve a useful initial launch speed so a restart reaches its first decision quickly. Strongest objection: rhythmic effort becomes a chore if every attempt starts sluggishly.
3. **I02 — Feet that stay on the deck.** Begin with planted deck anchors, consistent limb lengths and explicit rear-foot release/replant during a push. Add only the small IK solution needed when heading or board lean would otherwise slide the feet. This turns the animation into a body supported by a skateboard. Strongest objection: a generic IK solver can introduce knee snapping and obscure the simple contact contract.
4. **I05 — Forgiving carving.** Add a modest heading response and body lean, with generous lane correction. Judge it by deliberate target approaches, not realistic tire friction. Strongest objection: turning arcs could remove the precise agency that the existing direct lane selection already supplies.
5. **I01 — A recognizable protagonist.** Build one coherent silhouette with shaped hands/shoes, clear anatomy and a deliberate jacket/pad palette. Agree pivots before detailed modeling. Keep the personal story detail small; postpone facial expressions and fine folds until they demonstrably read in the chase view. This selection scores below I02/I12 individually, but gives the package a character identity instead of five controller systems.

I09 becomes a necessary **unselected integration requirement**, not an optional omission: preserve visual transform copying, joint anchors, measured movement, the selected crash-pose agency and the tuned stair-focused fall whenever I11/I01 change the character. Do not quietly add anticipatory delay or extra launch lift. I04 contributes only contact/clearance probes sufficient to gate a kick and expose failures; do not take its full motor rewrite as a hidden dependency. I12 contributes a framing check, not a new cinematic camera system.

### Direct challenge: keep I09 or replace it with I02?

The strongest case for keeping I09 is that the dismount is the game's defining transition. New skating animation can break the relation between the visible pose and the chosen physical crash pose; an improved character can change pivots and introduce a pop. An explicit workstream with continuity acceptance would protect the game's payoff rather than just improve its prelude.

The decisive objection is marginal scope. `scripts/rider.gd:188` already copies each visual's global transform into its body; line 189 supplies launch velocity; lines 203–209 build joints at transformed pose anchors. Integrating new animation must preserve that existing contract whether I09 is selected or not. Its genuinely new anticipation/timing feature is less urgent and risks delayed response or reduced stair contact. I02 supplies missing support during every push and turn. **Replace I09 with I02; do not remove handoff validation.** Revised ranking: I11, I03, I02, I05, I01.

## Strongest disagreement and missing idea

The packet is too willing to treat a skeletal rig and collision-aware motor as foundations. They are implementation choices with substantial transition risk. A staged procedural character can establish timing and control feel first; a simple contact gate can validate pushing before four-wheel realism. Decide whether those larger investments are needed from observed defects in that slice.

The missing idea is an **explicit retry-to-first-crash budget**. Charge duration, push cadence, turns, tutorial cues, camera movement and new geometry each seem small alone; together they can triple the wait before the game's enjoyable event. Record this duration across first-time and repeated attempts, and preserve a quick route to a useful cascade.

## Minimal first-playable milestone and build order

1. Freeze current target approaches, cascade results, actual tread injury checks and dismount carry as comparison fixtures. Measure current first-crash durations; these are engineering comparisons, not human enjoyment scores.
2. Agree eleven-region anatomy and joint centers. Establish I02's planted-foot and release/replant contract, then implement the small I11 animation slice and I03 contact-synchronized kick on Civic's existing apron, keeping the downstream world unchanged.
3. Add I05 heading/lean with generous steering bounds. First-time players should deliberately approach left, center and right targets without needing perfect arcs.
4. Preserve the existing dismount handoff as integration work and validate both obstacle and manual bails: no visible pop, no delayed collision response, and repeated real stair contacts retained. Verify the selected crash pose still changes physical outcomes after separating it from the riding stance.
5. Fit I01's improved models to the tested anatomy; add only details that remain legible at the actual camera distance. Check all three routes, injury localization and replay restoration.

The first playable is **one visible kick, a coast interval, a controllable turn and a continuous fall into the existing Civic cascade**. It contains no ollie, powerslide, pumping minigame, facial acting or new course.

Player-centered acceptance: newcomers can explain which action changed their speed; hold-to-push users get the same basic opportunity as tap users; feet remain visibly planted except during the kick; three deliberate target approaches remain achievable; repeated attempts reach useful crashes without added compulsory waiting; and observers can follow the skating-to-tumble transition. Native play and viewing are required to judge these claims. Headless assertions alone cannot establish them.
