# R12 lifecycle and authored taxi regression

This is targeted headless integration evidence, not completion of R12 or native
audio/play acceptance. The full source gate remains with root after the R08 rig
repair and source freeze.

The pre-R08 version of `tests/test_lifecycle.gd` passed its first actual strict bounded run:
`LIFECYCLE: 207 checks, 0 failures`, engine 4.7.2 official `ed1daf0bf`, at
`builds/repair/R12/lifecycle-v1/output.log.result.json`. The actual telemetry is
`builds/repair/R12/lifecycle-v1/lifecycle.json`. The only engine diagnostic was the
runner's exact known adjacent macOS certificate pair.

Twenty cases alternate the three actual routes and exit either with Retry during
replay or natural short-tape completion followed by the supported route action.
Each case creates an actual rider body tape and private replay query scene.
Independent scene traversal measures tree nodes, rigid bodies, joints, all three
AudioStreamPlayer classes, replay roots, query bodies, and orphan nodes. After
queued frees settle, all counts exactly return to the corresponding route's
construction baseline; replay queries and physical joints return to zero. The
three baselines were respectively 1367/1432/1699 tree nodes and 55/52/74 rigid
bodies. Headless audio player counts remained zero and establish only absence of
extra allocations, not native playback state.

Six cases use the authored parked premium taxi, actual main controller, complete
static route geometry, real physics frames, charge 1, and explicit supported
maximum-speed construction control of 31 m/s. Other payable actors are removed
only to isolate this obstacle. Seeds `1`, `90210`, and `777` apply deterministic
initial x/z placement jitter in ±0.002 m; this is explicitly placement variation,
not randomized solver state or a global gameplay seed.

The independent clearance oracle transforms all corners of literal physical
rider part sizes and the actual taxi hull. Each near miss retained minimum x-axis
hull separation 0.42039 m through the pass, remained RUN, and left the taxi
unarmed/unbroken with score zero. Each matching strike caused an actual accepted
taxi contact at the declared ≤0.002 m spatial tolerance, entered CRASH, created
twelve rider bodies, armed the taxi, and transferred measurable physical momentum.
The measured speed was 31 m/s in all six cases. Scores varied across the three
strikes (3061, 3078, 3066); no exact score is asserted.

`LIFECYCLE` is registered as the thirty-first mandatory suite with a 180-second
deadline. Full-suite source/engine/cache identities will be recorded by the
bounded public entry after source freeze. This target does not close R12.

## Final rig oracle and actual target

Root published the final collider contract: torso `ConvexPolygonShape3D` has
sixteen vertices in two eight-point rings. For `i=0..7`, the lower ring is
`(0.24*cos(i*TAU/8), -0.35, 0.18*sin(i*TAU/8))` and the upper ring is
`(0.34*cos(i*TAU/8), 0.35, 0.22*sin(i*TAU/8))`, with collider local offset
`(0,0.04,0)`. The near-miss oracle uses the containing conservative torso box
`(0.68,0.70,0.44)` with that offset. Both forearms are physical boxes of size
`(0.28,0.44,0.30)` with local offset
`(0,-0.03,0)`; all other physical boxes unchanged. The independent corner oracle
now applies those literal offsets after each actual riding part transform. The
first replacement also compares all sixteen literal torso vertices and every
other literal box dimension/offset transform to each actual spawned
`CollisionShape3D`, recording the geometry in telemetry. No production contact
helper supplies the oracle.

After root published the production collision factory and rig, the updated test
passed `LIFECYCLE: 271 checks, 0 failures` with the strict bounded runner at
`builds/repair/R12/lifecycle-final/output.log.result.json`. It verified all twelve
actual physical shapes, including the sixteen convex torso vertices and all
local collider offsets. All twenty replacement cases returned to their original
route baselines with zero settled orphan nodes, replay queries, or joints. The
six actual taxi cases again measured 31 m/s; the conservative near-miss hull gap
was 0.37512 m and each near miss stayed RUN with an unarmed taxi and zero score.
All three strikes accepted the taxi contact, armed it, and transferred momentum;
their actual scores were 4994, 4994, and 4995, without an exact-score assertion.
Telemetry is `builds/repair/R12/lifecycle-final/lifecycle.json`. The only diagnostic
was the exact allowed adjacent macOS certificate pair. The test is frozen.
The historical 207-check result above remains pre-R08 evidence.

Actual target command:

```sh
python3 tools/run_bounded.py --timeout-seconds 180 --expected-summary LIFECYCLE --log builds/repair/R12/lifecycle-final/output.log -- /opt/homebrew/bin/godot --headless --path /Users/tyler/Documents/GitHub/stair-dismount --fixed-fps 60 --script res://tests/test_lifecycle.gd --log-file /Users/tyler/Documents/GitHub/stair-dismount/builds/repair/R12/lifecycle-final/engine.log -- --test-mode --records-path=/Users/tyler/Documents/GitHub/stair-dismount/builds/repair/R12/lifecycle-final/records.json
```

After that passes and root freezes all source, the public entry is
`GODOT_BIN=/opt/homebrew/bin/godot tools/test.sh --runtime-only`. The failed strict
import result remains separate and unchanged; runtime-only never claims an
import-plus-suite pass.
