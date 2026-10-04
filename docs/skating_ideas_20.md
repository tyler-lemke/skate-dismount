# Character and skating: 20 candidates

This is a design proposal, not authorization to implement changes. Focus: make the existing three-level skateboard crash game feel better before and during the dismount. Keep localized injuries, physical cascades, slow crashes, replay, insurance payouts, and Mom's treatment story.

## Source-grounded diagnosis

- `scripts/main.gd`, RUN branch: movement directly changes X/Z, then follows `Rules.surface_y()` with `move_toward`; the riding skater is a Node3D, not a grounded collision body. Prop contact is an approximate distance check. There is no actual wheel contact or airborne skating state.
- Holding W applies continuous acceleration (5.2 rather than 1.5 units/s²); downhill adds more acceleration, capped at 31. There is no push stroke, coasting drag, braking, or carving heading.
- `scripts/rider.gd`, `pose_ride()` calls `apply_launch_pose()` after assigning bob/lean/limb transforms. The latter replaces torso/head/pelvis/limb transforms from static selected-pose anchors, overwriting much of the riding animation. Board lean remains. Thus the three bail poses largely serve as frozen riding stances.
- Character assets in `blender/build_assets.py` are separate beveled boxes and a simple helmet/head assembly. There is no imported skeleton, weight-painted skin, facial rig, or authored push animation. Shoes are part of shin meshes.
- RUN Space immediately bails. READY Space charges/launches. A/D translates sideways; three poses and three hats already exist. Any ollie proposal must solve this control conflict.
- Bail spawns eleven physical body parts and a board with ten PinJoint3D connections. Current stair-focused velocity tuning intentionally reduces rider forward speed while the first prop retains full approach impulse. Do not casually replace this with a complete skate simulator or undo the stair tumble.
- Existing automated checks cover actual tread injuries, pose/lane outcomes, finite payouts, replay, input, and UI. They do not establish human enjoyment or native rendering quality. Suggestions below are hypotheses needing playtests.

## Candidates

### I01 — A recognizable, professionally modeled protagonist
Create one original stylized skater in Blender: coherent proportions, readable face, shaped hands/shoes, jacket and clothing folds, deliberate material palette, and hats fitted to the same head. A small personal detail connects to Mom without turning the outfit into exposition. Preserve eleven identifiable injury regions. **Benefit:** immediate character appeal and readable motion. **Scope:** medium art work; no realistic skin or character roster. **Failure mode:** spending weeks on detail invisible from the chase camera. **Test:** silhouette and face reads at actual gameplay framing, plus limb localization after crash.

### I02 — Feet that stay on the deck
Define foot attachment points, bent-knee stance, and a modest two-leg IK solution driven by the board transform. The rear foot releases only during a push; feet never slide through the deck while leaning. Keep this as contact/stance support rather than a whole animation system. **Benefit:** removes floating mannequin appearance. **Scope:** medium; needs consistent limb lengths and pivots. **Failure mode:** IK jitter or knees snapping at stair lips. **Test:** bound planted-foot error and knee continuity during turns, speed changes, and transitions.

### I03 — Real push, coast, and speed management
Replace continuous W acceleration with visible push strokes: a press queues one bounded kick, holding repeats at a comfortable cadence, and the recovery creates a coast interval. Forward speed comes from push impulses, gentle rolling resistance, and slope rather than automatic acceleration everywhere. **Benefit:** immediately makes skating an action with rhythm and purpose. **Scope:** medium. **Failure mode:** compulsory frantic tapping or waiting through a long run-up. **Test:** tap/hold accessibility parity, impulse only during grounded push contact, speed changes tied to strokes, and a short approach.

### I04 — A forgiving grounded skateboard controller
Use a modest collision-aware arcade motor with front/rear truck ground probes and a swept collision shape. Track grounded/airborne state, slope, pitch, and board clearance; integrate velocity instead of directly snapping the rider to the step-height formula. Keep controlled stair assistance and explicit bail limits. **Benefit:** terrain and contact become believable and support later moves. **Scope:** large foundation; prototype before committing. **Failure mode:** stair noses catch the board, unwanted jitter, or a full-physics rewrite destroys reliable cascades. **Test:** flat/slope/lip/step probes, no tunneling, and existing cascade/tread-injury gates still pass.

### I05 — Carving with heading, grip, and body lean
A/D changes board heading and turn radius rather than simply strafing. Momentum lags heading slightly, body lean explains the turn, and speed bounds turning authority. Retain generous low-speed correction and make intended landing line readable. **Benefit:** steering feels like skating and creates speed-versus-line choices. **Scope:** medium; can start on the existing arcade motor. **Failure mode:** realism makes lining up dominoes harder without making it enjoyable. **Test:** repeatable arcs, controllable target approach, and first-time players can intentionally choose all three lanes.

### I06 — Foot brake and a small powerslide
S brakes with a readable foot drag; stronger braking while turning produces a short controllable slide. Use it to trade speed for angle before the lip, without a balance minigame. **Benefit:** adds an actual way to correct a bad approach. **Scope:** medium. **Failure mode:** stopping becomes the dominant safe strategy in a game about crashing, or braking is needed constantly. **Test:** recover an overshot line while retaining enough momentum for a useful cascade.

### I07 — One expressive ollie, with explicit bail control
Allow a forgiving charged ollie on the run-up or lip; charge affects a bounded hop height. Give bail its own clearly taught control (for example B), and provide input buffering/coyote time where appropriate. Allow skipping one obstacle to hit a more valuable bridge; avoid a large trick catalogue. **Benefit:** a memorable skillful skating action and new route choices. **Scope:** large because airborne movement, controls, animation, and tests must change. **Failure mode:** new controls confuse existing players or skilled jumps avoid the core injury/cascade game. **Test:** usable short hop plus alternate first impact, without bypassing the whole staircase.

### I08 — Pump the stair rhythm
A well-timed crouch/release around a small set of marked transitions gains a modest speed benefit and expressive board/body compression. It must remain optional; holding a relaxed rhythm still launches a good crash. **Benefit:** turns approach timing into a physical rhythm. **Scope:** medium-large. **Failure mode:** a timing-meter minigame obscures the skater and punishes accessibility. **Test:** optional meaningful benefit and equivalent non-rhythmic route, not mandatory perfect timing.

### I09 — Continuous, intentional dismount handoff
Carry the visible pose, body transforms, board heading, and measured velocities into the existing ragdoll without a mesh pop. Add a short anticipatory weight shift for manual bail; its timing/lean changes the first body contact, while obstacle bail remains immediate. Preserve the proven stair-focused fall and impulse ledger. **Benefit:** skating flows into the game's main spectacle and the player authors the first tumble. **Scope:** medium-large. **Failure mode:** exaggerated launch lift skips the stairs, or animation delays impact response. **Test:** transform continuity, bounded velocity discontinuity, zero added input delay on collision bail, and successive actual tread injuries.

### I10 — Graze, wobble, recover, then commit
Distinguish a light side graze from a substantial frontal collision. A graze reduces speed and briefly destabilizes stance but permits recovery; a heavy hit still bails. Use angle/speed thresholds with generous hysteresis, not random survival. **Benefit:** skating lasts long enough for corrections and collisions feel less binary. **Scope:** medium-large. **Failure mode:** unpredictable bail thresholds or accidental removal of chain starters. **Test:** repeatable graze/recovery versus deliberate heavy strike, and consistent contact handoff to props.

### I11 — A coherent skating animation state machine
Replace the overwritten static riding transforms with distinct idle, push, coast, crouch, carve, airborne, and bail-anticipation states, blended from actual speed/contact/input. Build a minimal Blender skeletal rig and authored clips, or a staged procedural rig before asset replacement; do not invent independent character physics. The existing chosen crash pose becomes a target for the handoff rather than the entire riding animation. **Benefit:** actions visibly have effort and intent. **Scope:** large if every clip ships; first slice is push/coast/crouch/carve only. **Failure mode:** expensive animations disconnected from gameplay, or foot sliding without I02. **Test:** each action drives the right state, no static-pose overwrite, and animation timing matches push/contact events.

### I12 — A skating camera that reveals the next decision
Use restrained speed-dependent trailing distance/FOV and a look-ahead toward the approach line. Smoothly hand off to the crash camera, with obstruction handling and optional camera shake. Preserve the existing camera selector. **Benefit:** players can read the lip and next target while the skater stays visible. **Scope:** medium. **Failure mode:** cinematic motion hides control feedback or makes people nauseous. **Test:** first-time target identification, rider visibility, reduced occlusion, and shake/FOV settings.

### I13 — An expressive board, trucks, and wheels
Animate wheel rotation from traveled distance, trucks from carving, small suspension compression on landing, and deck pitch from ground contacts. Make wheel/deck contact believable without simulating four independent wheel bodies. **Benefit:** the prop under the character finally looks like a skateboard. **Scope:** small-medium; depends on meaningful motion/contact data. **Failure mode:** ornamental motion masks bad locomotion. **Test:** correct spin direction/rate, continuous pitch and clearance, with no score or collision changes.

### I14 — Skating sound and impact texture
Connect push-foot contact, wheel roll, small landing thumps, stair clacks, grip skid, and board scrape to actual events. Pitch/surface mixing follows speed/contact; add restrained haptics if a controller is used. Avoid constant loud receipt noises covering the board. **Benefit:** speed and surface have tactile identity. **Scope:** small-medium. **Failure mode:** too much noise and fake events unrelated to contact. **Test:** audiovisual sync and a listening playtest; headless resource tests alone cannot judge this.

### I15 — Damage that belongs to the character's clothing and anatomy
Replace a whole-part burgundy tint with authored bruise zones on exposed skin, scuffed pads, and small garment damage states; keep the clear anatomy diagram. Match these states to the same eleven-region ledger and replay snapshots. **Benefit:** closer, more legible Porrasturvat-style consequence on a polished character. **Scope:** medium art/shader work. **Failure mode:** excessive detail or gore distracts from readable arcade chaos. **Test:** players can identify the worst injured region from the character and HUD, and replay restores every state.

### I16 — Focus, panic, relief: restrained facial expression
Give the character a small set of expressions and eye direction: concentration during approach, a brief panic reaction at bail, and relief when a claim helps Mom. No voiced cinematic dialogue. **Benefit:** makes crashes happen to a person with comic personality. **Scope:** medium and dependent on I01. **Failure mode:** expressions are invisible in gameplay or trivialize Mom's illness. **Test:** expression recognition at normal framing, with story tone kept sincere.

### I17 — Hat and jacket follow-through
Add constrained visual spring motion to hat, jacket hem, and a small accessory; settle quickly, retain a stable collision/rig root, and use simple authored motion during replay. **Benefit:** inexpensive life around a stiff character. **Scope:** small-medium. **Failure mode:** distracting jitter, clipping, or extra simulation costs with no gameplay gain. **Test:** bounded motion, no clipping through face/limbs, deterministic replay presentation.

### I18 — A 15-second playable skating lesson on the existing apron
Teach one push, one carve, and a deliberate bail into a starter target on Civic's existing launch deck. Each cue responds to an actual action and disappears after mastery; offer skip and hold-to-push. This is part of level one, not a fourth level or long tutorial. **Benefit:** players learn the new feel by doing it. **Scope:** small-medium after controls settle. **Failure mode:** compulsory repetition delays the crash on every retry. **Test:** first-time comprehension and optional lesson completion under 15 seconds; retries bypass it.

### I19 — A useful approach ghost for experimentation
On request, show the player's own prior approach line and speed at the lip while they skate a new attempt. Ghost covers the approach only and never collides or pays; reuse recorded transforms instead of promising perfectly deterministic physics. **Benefit:** makes changing speed and angle understandable during retries. **Scope:** medium. **Failure mode:** visual clutter or copying becomes more rewarding than discovery. **Test:** players can intentionally alter their first contact; ghost cannot affect simulation or money.

### I20 — Short run-ups authored for skating decisions
Give each existing route a compact, distinct approach: a gentle Civic carve, a Market gap between stalls, and a Port bank or low curb. Add only the geometry needed to give pushing/steering/one hop a reason to exist; preserve staircase counts and downstream domino layouts. **Benefit:** approach mechanics have meaningful places to use them. **Scope:** medium-large and dependent on chosen movement mechanics. **Failure mode:** lengthens setup or changes three good crash puzzles into obstacle courses. **Test:** time to first crash stays short, approach decisions change the first impact, and all three cascade routes remain attainable.

## Review rubric

Evaluate the actual proposal, including dependencies and a credible minimal slice. Score 0–100 for immediate skating feel (30%), character/animation readability (25%), fit with the crash/cascade loop (20%), implementation confidence relative to effort (15%), and ease of player validation (10%). Give one weighted score, the strongest objection, an explicit dependency, and keep/rework/defer/reject for each ID. Scores are reviewer judgement, not measured fun.

Pick exactly five IDs as a coherent package, considering overlapping ideas and prerequisite work. Include a build order and a minimal first-playable milestone. Identify ideas that sound impressive but would harm this game or consume time before testing the basics. Do not reward complexity or just prettier screenshots.

No feature is implemented by this document. No new human playtest evidence is available.
