# Repair plan review — round 3

Date: 2026-10-04. Independent internal adversarial review under the planning-workflow skill.
This review file is the sole output; no plan, gameplay, graph, package, or tracker changes.

Verdict: **no remaining structural defect found; one marginal contract correction remains**.
The plan now has a coherent dependency and closure order. The correction below preserves an
existing control needed by already-required acceptance cases; it adds no feature or new subsystem.
This round does not establish native correctness or turn an unobserved hypothesis into a defect.

## Previous revisions rechecked

Round 2's R04/R08 closure cycle is resolved: R04 closes against the existing contact-to-bail seam
and publishes its accepted pose/reset interface; it no longer requires completed downstream R08.
R03 records focus suspension inside HELP, and R05 preserves it when HELP closes into PAUSE.
Only explicit Resume clears that suspension. R04 now distinguishes angular subdivision ceilings
from the contact-error bound, refines conservative candidates, and pairs the grazing positive case
with an independent clear-turn negative control. R02 explicitly tests successful replacement with
failed readback and uses numeric recovery/inaccessible-profile fixtures to distinguish restoration
from new earnings. R01 defines an extensible script/summary/timeout registry and wrong-suite controls.

Round 1's source-audio/candidate cycle, historical camera geometry, contact-time bail placement,
protected fresh recovery, uncertain-commit ownership, replay audio ambiguity, and source-archive
ordering remain corrected. Those findings should not be reopened in their former form.

## 1. P2 — The input table omits mute in the phases where downstream gates require it

Classification: **marginal cross-task contract inconsistency**, not a structural dependency defect.

Evidence: `tasks/R03.md:55-61` requires an explicit phase/action policy and lists mute only in
MENU, RESULTS, and REPLAY. READY, RUN, and CRASH omit it. Yet `tasks/R11.md:43-44` requires
immediate mute of currently playing effects, and `tasks/R14.md:66` requires the player to mute
during a traffic loop and an impact sound. The existing dispatcher handles KEY_M before its
pause/help guard (`scripts/main.gd:219-220`), so global live mute is existing gameplay behavior.

Concrete failure: a fresh R03 implementer treats the table as an allowlist and denies M in RUN
and CRASH. Modal and slow-motion checks pass, but the R14 native traffic/impact mute case cannot
be performed. Calling `toggle_mute()` directly in an audio test would conceal the missing player
action and bypass the new authoritative policy. R11 cannot safely cure it by adding another input
path outside R03.

Smallest correction:

```diff
--- tasks/R03.md
+++ tasks/R03.md
@@
 Document an explicit phase/action table beside the centralized dispatch implementation.
+Mute is a global presentation/preference action in every phase, including PAUSE/HELP.
+The M press uses the same authoritative action policy; it cannot launch, resume, or
+change phase. Its preference write remains governed by R02's protected/pending state.
@@
 Test both help entry routes: H and the real HOW TO WRECK Button.
+Dispatch M in READY/RUN/CRASH with a live Button focused, and under PAUSE/HELP.
+Require exactly one mute change per fresh non-echo press, with phase/modal/charge/
+breaker/funding unchanged. R11/R14 retain actual player-state and listening checks.
```

Rationale: one common-action clause preserves the current control across the exhaustive phase
table without duplicating it into each row or adding a second dispatcher. Dispatched-input tests
verify accessibility of the action; they do not pretend headless sound state proves audible mute.
The existing modal GUI focus trap remains intact.

## Other reviewed seams

No JSON or textual closure cycle remains in the material reviewed. I independently parsed all
15 entries and 30 edges. One valid order is R01, R02, R03, R05, R10, R04, R09, R07, R08, R06,
R11, R12, R13, R14, R15. R01 is the sole initial-ready task and R15 is the sole intended sink.
Shared-file edits still need one writer, as the plan explicitly states; graph readiness is not
permission for conflicting edits.

R05 can establish its prescribed clock/presentation interface before R03's implementation;
R03 can implement the specified modal policy before R05. Their later integrated behavior belongs
to R12. Neither card requires the other to close, and neither requires downstream native evidence.
R08/R11 can close bounded source investigations while carrying precisely unobserved native cases
to R14; native failure reopens the responsible repair and invalidates the old candidate identity.

Replay query proxies have explicit masks, immutable hull metadata, caller-selected camera context,
and a disjoint early/final obstruction fixture. Query synchronization is an implementation proof
obligation, not evidence that the installed engine already supports a particular chosen update
mechanism. Replay visual adapters likewise must satisfy isolation and pre/during/post live-state
equality. Shared mutable material resources would violate that existing contract; prescribing a
particular resource duplication API is not an indispensable additional planning decision. Test
damage/fuse/lamp presentation when implementing the adapter rather than accepting dictionary
deep-copying alone as proof of isolation.

R13 builds and checks the extracted candidate; R14 observes those exact bytes; R15 promotes them
without another export. The separate finalized source-deliverable inventory permits launcher/docs
edits without changing validated runtime inputs. Any later runtime/asset change must return through
the candidate/native gates. No new release framework or source-history requirement is needed.

The three routes, supported speed, poses/hats, articulated injury display, finite causal traffic,
exactly one breaker, caps, and treatment goal remain explicit preservation requirements. The plan
does not authorize fallback awards, slower movement to pass contacts, a wholesale rig/controller
replacement, or an optional replay sound track. The native and gameplay-attainability gates may
still discover real failures; planning review cannot declare those cases passed.

No blocking human decision is needed for the marginal correction. I found no further indispensable
fresh-agent choice or unsupported engine assertion requiring a structural rewrite. Native rendering,
OS focus, listening, frame pacing, and extracted-candidate play remain required evidence gates.

## Full-read attestation and limits

Read complete `PLAN.md`, `task_graph.json`, all **15 task cards R01–R15**, `reviews/round_1.md`,
`reviews/round_2.md`, and `reviews/round_2.diff`. Re-read all text obscured by the initial aggregate
tool-output truncation in smaller calls. Read the planning-workflow skill. Inspected only the current
main input/replay/camera integration, HUD results/control copy, sound allocation/transitions, and
material/damage references to ground the specific control and replay-isolation seams. Parsed and
topologically sorted the graph read-only.

This is actual internal review **round 3 only**, not a claim of four completed rounds or an external
model invocation. I did not run gameplay/native Godot tests, listen to audio, verify external API
documentation, or establish a new observed runtime defect. The finding is an internal contract
mismatch; engine/presentation behavior remains subject to the plan's implementation evidence gates.
