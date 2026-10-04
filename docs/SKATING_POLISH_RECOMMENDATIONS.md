# Character and skating: five recommended improvements

**Decision:** prioritize I11, I03, I05, I02, and I01. Together they make the existing short approach look and feel like skating, then preserve the injury-and-cascade payoff. Prototype motion on Civic's existing apron before replacing character art or changing courses.

**Review limitation:** the requested Claude, Antigravity, and Grok reviews could not be obtained. Actual CLI attempts returned connection/startup/session failures, not model opinions. These recommendations are a **provisional internal fallback**, developed through three separately scored reviews and a rebuttal round. They are design judgments, not evidence of measured enjoyment. No game code, assets, controls, or packaged build changed in this task.

## The underlying problem

The character is not simply missing detail. `pose_ride()` sets bob and lean, then calls `apply_launch_pose()`, which replaces much of that motion with the selected crash pose. W continuously increases speed; A/D moves the character sideways; the rider follows the computed stair height. Visible effort, contact, and directional intent are largely absent. See `scripts/rider.gd:76`, `scripts/rider.gd:112`, and `scripts/main.gd:252`.

The existing body-to-ragdoll handoff already copies visible global transforms and uses matching pose anchors (`scripts/rider.gd:188`). Its reduced forward carry is deliberate stair-tumble tuning (`scripts/main.gd:287`). A new rig must preserve those properties; a current mesh pop has not been established.

## The five

### 1. I11 — A character that visibly performs the skating actions

Give riding one authoritative motion driver. Begin with coast, push/contact/recovery, a small crouch, and carve lean. Stop overwriting the moving stance with the selected crash pose every frame. The chosen Tuck/Starfish/Torpedo remains a dismount target rather than a frozen riding posture.

**Player benefit:** the body shows weight and effort; a kick, coast, and turn look different. **First slice:** procedural motion on the current segmented character, designed around consistent pivots. A later simple Blender rig can replace that presentation after the timing is proven. **Main objection:** a seven-state animation set and full rig conversion would consume the budget before control feel is tested.

**Acceptance:** action changes drive visible state changes; kick propulsion matches the foot-contact phase; turning causes appropriate lean; the last visible stance and joint anchors feed the first physical frame without delaying a collision bail.

### 2. I03 — Push, coast, and useful momentum

Make W perform a complete kick instead of applying continuous acceleration. Tapping queues a stroke; holding repeats the same stroke at a relaxed cadence. Release produces a coast interval with gentle rolling resistance. Calibrate speed so a few readable strokes reach a useful impact promptly.

**Player benefit:** the player creates speed and understands why one approach hits harder. **First slice:** one grounded kick/contact/recovery cycle with a real speed impulse. **Main objection:** requiring repeated kicks after a charged launch adds two rituals before every crash.

**Decision to prototype:** use a short rolling start with hold-to-push as the primary flow. Compare it against an assisted charged launch that substitutes for repeated kicks, rather than stacking a second mandatory speed-building step. Keep a one-action accessible path and do not make frantic tapping optimal.

**Acceptance:** tap and hold obey the same maximum cadence; airborne feet cannot propel; input-to-push response is prompt; a deliberate additional kick materially changes lip speed; retry-to-first-crash duration is compared against the current build.

### 3. I05 — Forgiving carving instead of sideways sliding

A/D should turn the board's heading and produce a bounded curve, with body lean explaining the change. Begin with little extra lateral slip and generous steering correction. Judge the result by the ability to intentionally hit the existing left, center, and right starter lines.

**Player benefit:** aiming the crash becomes a satisfying skating action. **First slice:** shared heading/velocity data, speed-bounded turn authority, and a clear board/body orientation. **Main objection:** realistic turning radii or drift could make target selection frustrating.

**Acceptance:** newcomers can deliberately approach all three lanes; the response remains predictable at low and high speed; turn input explains the visible heading; broad arcs do not delay the crash or make narrow targets inaccessible.

### 4. I02 — Planted feet and a convincing board stance

Define actual sole/deck targets, stable knee direction, and consistent limb lengths. The front foot stays planted while the rear foot releases, kicks, and returns. Start with authored anchors and a small leg correction; add a two-segment IK solve only where it visibly solves slipping. Shoes are currently embedded in shin assets, so correct sole offsets and ankle pivots are real work.

**Player benefit:** the rider is supported by the board; every push and turn looks connected rather than weightless. **First slice:** a bent-knee coast stance plus one stable release/replant sequence. **Main objection:** broad terrain-adaptive IK introduces jitter and knee snapping.

**Acceptance:** planted soles remain at their targets through coasting and carving, knees remain continuous, release/replant is clear, and character replacement preserves the same contact contract. I11 owns the final action pose; I02 supplies its contact constraints. They must not overwrite one another.

### 5. I01 — One polished, recognizable protagonist

Replace the box-man construction with one original stylized skater: coherent proportions, shaped hands and sneakers, a readable face, deliberate jacket/pad shapes, and a controlled material palette. Fit the three existing hats to the same character. Keep eleven identifiable injury regions and a small personal story detail.

**Player benefit:** players recognize and care about the character, and body movement/injuries read more clearly. **First slice:** approve silhouette and proportions at the actual gameplay camera before refining clothing. Match the proven foot, pivot, and joint contracts. **Main objection:** fine skin, folds, and expressions may be invisible from the chase view.

**Acceptance:** the figure reads at normal gameplay scale; hands/shoes do not clip the deck; hats fit; the eleven damage regions and replay remain correct. Art should be reviewed in motion as well as in Blender stills.

## What the adversarial round changed

Two initial packages treated **I09 dismount continuity** as a top-five feature. The source challenge exposed that its central transform-copy capability already exists. All three internal reviewers replaced that standalone slot with **I02 planted feet**. They retained handoff preservation as explicitly budgeted integration work under I11; new anticipation and first-contact steering stay deferred.

Another important objection was the hidden prerequisite cost. The five still require a trustworthy grounded/contact signal and shared heading/velocity data from a small I04 slice. They do not justify a full board-physics rewrite. If the minimal contact support cannot work reliably on the stairs, prototype and estimate that foundation separately before committing to final art.

I14 sound ranked slightly above I01 in generic scoring, but the coherent package selects I01 because the user specifically requested character polish. A skating audio pass is the next follow-up once real push/contact events exist. I12 camera readability is also a strong near miss. Ollies, powerslides, pumping, expressive faces, accessory springs, ghosts, and new approach obstacles are deferred until the basic kick and turn are convincing.

## All 20 candidates and post-rebuttal scores

These are subjective 0–100 internal scores using the same weighted rubric: skating feel 30%, character/animation readability 25%, crash-loop fit 20%, implementation confidence versus effort 15%, and ease of player validation 10%. They are not provider scores or player ratings. The average is shown for transparency; selection also considers complementary responsibilities, prerequisites, and the requested character focus.

| ID | Candidate | Cascade | Impact | Story | Mean | Decision |
| --- | --- | ---: | ---: | ---: | ---: | --- |
| I01 | One polished protagonist | 82 | 80 | 82 | 81.3 | **Selected** |
| I02 | Feet planted on the deck | 90 | 84 | 82 | 85.3 | **Selected** |
| I03 | Push, coast, speed management | 94 | 90 | 87 | 90.3 | **Selected** |
| I04 | Grounded arcade board controller | 72 | 72 | 63 | 69.0 | Minimal contact support; defer full rewrite |
| I05 | Forgiving carving and lean | 89 | 86 | 84 | 86.3 | **Selected** |
| I06 | Foot brake and powerslide | 73 | 70 | 59 | 67.3 | Defer |
| I07 | One ollie with explicit bail control | 70 | 61 | 56 | 62.3 | Defer |
| I08 | Pump the stair rhythm | 57 | 48 | 48 | 51.0 | Defer; meter-game risk |
| I09 | Intentional dismount handoff | 79 | 76 | 76 | 77.0 | Preserve existing continuity; defer new mechanic |
| I10 | Graze, wobble, recover | 66 | 65 | 68 | 66.3 | Defer |
| I11 | Coherent skating animation driver | 95 | 92 | 88 | 91.7 | **Selected, narrow first slice** |
| I12 | Camera reveals the next decision | 86 | 79 | 77 | 80.7 | Near miss; inspect framing now |
| I13 | Wheel, truck, deck motion | 79 | 77 | 72 | 76.0 | After meaningful motion data |
| I14 | Contact-driven skating sound | 83 | 83 | 80 | 82.0 | Next follow-up |
| I15 | Authored skin/clothing damage | 77 | 76 | 66 | 73.0 | After character art contract |
| I16 | Focus/panic/relief expressions | 48 | 52 | 52 | 50.7 | Defer until visible in gameplay |
| I17 | Hat/jacket follow-through | 60 | 66 | 58 | 61.3 | Defer |
| I18 | Short playable lesson on Civic apron | 76 | 78 | 74 | 76.0 | Once controls settle; optional |
| I19 | Approach ghost for experiments | 63 | 63 | 57 | 61.0 | Needs new approach recording |
| I20 | Compact authored skating run-ups | 75 | 69 | 70 | 71.3 | After feel; preserve crash timing |

The complete proposals, objections, dependencies, and validation ideas are in [the 20-candidate packet](skating_ideas_20.md).

## First playable and build order

Use Civic's current apron, current character, and current cascade. Establish sole/deck anchors and the small contact/heading contract. Build the authoritative motion driver and one useful push/coast cycle together. Add a restrained carving arc. Verify the existing pose/anchor transfer and downward stair entry. Fit the improved protagonist to that working contract, then validate the other two routes.

The milestone is **one believable kick, a readable coast, a controllable turn, and an immediate fall into the existing cascade**. It contains no new level, trick catalogue, airborne motor, or long tutorial. Foot-contact and handoff work must be estimated explicitly; they are not free dependencies.

Use a small formative native playtest to observe whether first-time players can explain what their last kick changed, intentionally choose another lane, read the body/board relationship, and voluntarily retry. Compare approach duration, unintended bails, and correction effort with the current build. Report the observations as a small sample, not statistical proof of enjoyment. Automated gates protect contact timing, finite motion, immediate collision bail, successive actual-tread injuries, attainable cascades, and non-duplicating replay/insurance funding.

If a skeletal rig is adopted after the prototype, Godot 4.7 documents modifiers for IK/constraints that run after animation playback. That supports a deliberate animation-then-contact composition order; it does not mandate a new rig as the first step. [Official SkeletonModifier3D documentation](https://docs.godotengine.org/en/4.7/classes/class_skeletonmodifier3d.html).

## Requested external reviewers: actual results

| Requested reviewer | Actual outcome | Authentic design review? |
| --- | --- | --- |
| Claude | First call timed out at 90 seconds. Retry with supported retries disabled returned API DNS `ENOTFOUND` in 3.6 seconds; no tokens or model usage. | No |
| Antigravity / agy | Startup failed: `listen tcp 127.0.0.1:0: bind: operation not permitted`, even with supported temporary data/log paths. | No |
| Grok | Isolated session home lost normal auth lookup. A second call preserved normal auth lookup but failed creating a session with `FS_PERMISSION_DENIED`. | No |

Native/browser model-app fallback was unavailable: computer-use inventory returned no apps or browsers and a service-startup error. No credentials were inspected or copied and no sandbox escalation was attempted.

Exact attempts and output references: [Claude](skating_review_claude.md), [agy](skating_review_agy.md), [Grok](skating_review_grok.md). The shared source-grounded prompt remains in [skating_review_prompt.txt](skating_review_prompt.txt) for the requested services when access is available.

Internal review provenance: [cascade](skating_review_internal_cascade.md), [impact](skating_review_internal_impact.md), [story](skating_review_internal_story.md), with explicit rebuttals from [impact](skating_rebuttal_impact.md) and [story](skating_rebuttal_story.md). The cascade review records its own revision. These reviewers previously worked on the game, so their independent proposal scoring is not a fresh external audit of the implementation.
