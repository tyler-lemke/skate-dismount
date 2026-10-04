# Repair plan review — round 2

Date: 2026-10-04. Independent internal adversarial review of the revised plan.
This review is the only file written; no plan, gameplay, graph, artifact, or bead changes.

Verdict: **a small structural closure correction and focused contract revisions are still needed**.
The changes are much smaller than round 1, but this is not yet a marginal-only steady-state round.
No engine, route, art, rig replacement, replay sound track, or new release framework is justified.

## Revisions validated rather than repeated

The R11 → R12 → R13 hidden candidate cycle was removed: R11 publishes a source inventory,
can close its source investigation with explicitly unobserved native cases, and R14/R15 retain
the native gate. Its music-only replay policy now agrees with R06; there is no undefined optional
event track or live cooldown reuse requirement. R06/R07 now give the camera caller ownership of
live versus historical query context and explicitly ignore frozen final hulls during replay.
R04 now requires contact-time root placement before activation/bail and searches past excluded
colliders. R02 now owns both protected fresh recovery and uncertain-commit reconciliation, and
defines recovered funding as a baseline rather than new earnings. R15 now finalizes the launcher
and source README before making the source archive, with a separate deliverable inventory.
Those round-1 findings should not remain open in their original form.

The remaining findings below concern residual closure/edge cases and missing distinguishing tests.

## 1. P1 — R04 still requests evidence from the R08 task it blocks

Evidence: `tasks/R04.md:116-118` requires "R05/R08 integration evidence" before completion;
`tasks/R08.md:3` and `task_graph.json` make completed R04 a prerequisite of R08. Read literally,
R04 cannot close until R08 integrates, and R08 cannot start until R04 closes. This is a semantic
closure cycle even though the declared 30-edge graph is acyclic. Reinterpreting the phrase as an
ordinary proof of the existing bail seam is reasonable, but the task should say that explicitly.

The existing seam is already executable without R08: `scripts/main.gd:308-309,331-336` activates
the struck object and calls bail, and `scripts/rider.gd:235-237` places each body from the riding
visual transform. R04 can prove its contact placement reaches that current code, then hand the
accepted pose to R08 for its separate transfer/skin investigation.

```diff
--- tasks/R04.md
+++ tasks/R04.md
@@
- documented proxy/support tolerances, no unexpected script errors, and R05/R08 integration evidence.
+ documented proxy/support tolerances, no unexpected script errors, R05 integration evidence,
+ and a passing contact-placement-to-existing-bail seam fixture. Publish its accepted pose,
+ transform/reset API, and evidence for R08; completed R08 evidence is not required to close R04.
```

Rationale: removes the only identified downstream closure requirement without changing the DAG
or letting a helper-only patch satisfy R04. Do not add R08 as an R04 prerequisite.

## 2. P1 — Focus loss inside HELP can bypass the explicit-Resume policy

Evidence: `tasks/R03.md:33-36` preserves HELP's return context and restores a running phase on
close. The new focus rule at `:46-49` enters PAUSE only when no modal already owns suspension,
while requiring Resume after focus gain. Consider RUN → HELP → focus loss → focus gain → close
HELP. HELP already owned suspension, so a plausible implementation preserves its original live
return context and resumes RUN without the required Resume action. The same issue applies to
READY, CRASH, and REPLAY. This is an unresolved nested-modal transition, not the round-1 absence
of a focus policy. Existing `scripts/main.gd:101-102` already resumes automatically on a help-close
callback, so leaving this exception implicit invites retaining that behavior.

```diff
--- tasks/R03.md
+++ tasks/R03.md
@@
- suspension. Focus gain does not auto-resume: the player chooses Resume. Preserve help/pause
- return context; MENU/RESULTS stay in their current phase. All held/polled gameplay keys require
+ suspension. Record a focus-suspension latch even when HELP already owns suspension.
+ Focus gain does not resume. If focus was lost from a live phase while HELP was open,
+ closing HELP returns to PAUSE for that phase; only Resume clears the suspension latch.
+ An existing PAUSE return remains PAUSE. MENU/RESULTS keep their phase and ordinary help return.
+ All held/polled gameplay keys require
@@
 Assert modal visibility, tree pause, game pause and returned phase agree after every action.
+ Dispatch focus loss/gain while HELP is open from each live phase, then close via H,
+ Escape and the help Button. Require PAUSE, unchanged clocks/actors, and no stale release
+ until explicit Resume plus fresh input. R14 repeats the OS-focus version of these cases.
--- tasks/R05.md
+++ tasks/R05.md
@@
 Physics, replay time, and action audio remain suspended until R03 Resume; fuses/idle/deadlines
+ stay suspended when HELP closes into focus-induced PAUSE as well.
```

Rationale: makes one owner choose the return state while clocks/audio consume that decision.
It requires no new modal framework and does not change MENU/RESULTS navigation.

## 3. P1 — R04's rotation approximation has no contact error tolerance or distinguishing oracle

Evidence: the new `tasks/R04.md:65-67` prescribes translation sweeps at sampled orientations and
end overlaps, with limits of .10 m boundary travel and 5 degrees. These bound subdivision size,
but do not bound missed contacts against the intervening rotating hull. A corner may enter a
near-tangent obstacle during a translating turn and leave before the end overlap; a fixed-orientation
translation cast does not represent the entire corner arc. `:83` asks for one mid-step turning hit,
but that case can pass even if all hits between orientation samples remain omitted. Conversely,
inflating every hull by .10 m to cover the arc would reintroduce phantom collisions near a boundary.

This is an algorithm-contract gap, not a claim of a newly reproduced runtime defect. Actual heading
changes are bounded by `scripts/main.gd:286`, and current prop geometry includes .26 m-thick dominos
(`scripts/world_builder.gd:189`) and rotated/tipped boxes. The remedy should stay proportionate to
those supported motions and real query precision; it need not demand an unavailable rotational API.

```diff
--- tasks/R04.md
+++ tasks/R04.md
@@
- within each substep sweep translation at the sampled orientation and test end overlap.
- Log the approximation bound and independently verify turns at supported speed without reducing speed.
+ within each substep use a conservative bound for the intermediate angular hull as well.
+ A bound may select candidate contacts, but refine them against the actual oriented proxy
+ before accepting a hit or contact pose. Document a contact-position/error tolerance no
+ greater than .002 m; .10 m and 5 degrees are subdivision ceilings, not accepted error.
+ If those ceilings cannot meet the error bound, subdivide further. Preserve supported speed.
@@
 Test an excluded first collider followed by a thin eligible obstruction, plus a mid-step turning hit.
+ Include a grazing turn whose endpoints and sampled-orientation translational casts are clear
+ while a finer independently sampled actual hull penetrates by more than .002 m. Its contact
+ must be found. A paired turn with clearance greater than .002 m must remain a miss.
+ Verify earliest contact placement with a finer independent pose/geometry bracket; the oracle
+ may not call the production subdivision/refinement helper.
```

Rationale: retains bounded arcade queries while making the approximation measurable, and couples
a positive rotational case with a false-positive negative control. Refine near candidates rather
than padding all riders or converting to a new movement architecture.

## 4. P2 — The new uncertain-commit path is not explicitly exercised at its unique boundary

Evidence: `tasks/R02.md:73-78` now distinguishes replacement that may have succeeded from an
acknowledged durable commit. Its failure injection list at `:119` still names failures before temp
creation, during write, after verification, during backup, and during replacement. In context,
verification first means the temp-byte verification (`:70`); a failed replacement is also different
from a successful replacement followed by failed readback. The acceptance list does not explicitly
require the latter, nor preservation of recovery's funding baseline across that uncertain result.
Without these cases, ordinary open/rename failure tests can all pass while the newly added branch
loses an earned contribution or reports the entire recovered balance as new earnings.

```diff
--- tasks/R02.md
+++ tasks/R02.md
@@
 Inject/check failure before temp creation, during write, after verification, during backup, and during replacement.
+ Separately inject successful primary replacement followed by failed readback/validation.
+ Require uncertain status, unchanged acknowledged funding, and retained pending candidate/baseline.
+ After reads recover, reconciliation recognizes the already-written candidate before another
+ replacement, emits exactly one earned contribution, and a second retry emits none.
+ Concrete recovery fixture: backup [500000,0,0], earned session [550000,0,0], corrupt primary.
+ Let the recovery write replace primary but fail readback; after reconciliation contribution is
+ 50000, fund is 550000, and no goal-crossing event occurs. Restored 500000 is never new earnings.
+ Concrete inaccessible fixture: previously unreadable v2 primary [100000,500000,0], session
+ [200000,0,0]. Once readable, use that validated existing funding as the baseline; commit
+ [200000,500000,0], emit only 100000, and emit no newly-funded event since baseline was funded.
```

Rationale: tests the actual distinction added in round 1 with independent numeric expectations.
The service can remain synchronous and small. These process/readback tests do not establish
power-loss durability or require a serialized journal.

## 5. P2 — Runner summary identities need an explicit extension contract

Evidence: `tasks/R01.md:69-71` names thirteen permitted suite markers, matching the current fixed
suite loop in `tools/test.sh:11-17`. Downstream tasks require registering new suites, including
`test_skating_contacts` (`R04.md:99`), `test_replay` (`R06.md:91`), `test_bail_transfer`
(`R08.md:91`), and `test_settlement_activity` (`R09.md:103`). If R01's list becomes a hardcoded
allowlist, later agents must silently reuse unrelated names or alter a supposedly finished runner
without a documented registration seam. Broadly accepting any success marker would weaken R01's
wrong-name negative control.

```diff
--- tasks/R01.md
+++ tasks/R01.md
@@
- Names are RULES, INJURIES, INPUTS, GAME, ROUTES, PLAYABILITY, UI, AUDIO, SKATING,
- CRASHBREAKER, RIDER_SKIN, TRAFFIC, and CAMERA; existing suffix telemetry is permitted.
+ The initial suite registry maps the existing thirteen scripts to RULES, INJURIES,
+ INPUTS, GAME, ROUTES, PLAYABILITY, UI, AUDIO, SKATING, CRASHBREAKER, RIDER_SKIN,
+ TRAFFIC, and CAMERA. Existing suffix telemetry is permitted.
+ Expose one explicit registry entry per suite: script, expected summary name, timeout.
+ Downstream tasks own adding their new regression suite entry and publishing its name.
+ Every registered suite remains mandatory; unknown, duplicate or wrong-name output
+ cannot satisfy another suite's expected completion. Fixture-test registration of a
+ fourteenth suite, its missing marker, and a valid marker from the wrong suite.
```

Rationale: supports the planned tests without inventing a general plugin runner or weakening its
completion/error parser. The thirteen historical suites remain required.

## Other reviewed seams and limits

Historical camera geometry ownership is now adequate at the plan level: R06 records immutable
query shape/local transforms and R07 accepts caller-selected space/mask/exclusions. The historical
disjoint-transform case must use actual updated query geometry before the camera solve, as written;
testing only proxy Node3D transforms would not satisfy it. Layer-mask terminology should be recorded
unambiguously in implementation evidence. The statement that existing live masks are 3 is not
literally universal: `crash_prop.gd:33` and world static bodies use 7. Both masks still ignore the
proposed separate layer, so this imprecision does not invalidate the isolation approach.

R04's earliest-contact placement and excluded-first-collider requirements now address the original
tunneling-after-detection concern; finding 3 is only about the remaining angular approximation.
R02's protected future versions, explicit quarantine-first recovery, session maxima, and consumable
funding events have coherent ownership. Finding 4 is a focused negative-control gap in the revised
semantics. R15's post-launcher source archive ordering is consistent with R13's unchanged runtime
inputs; output hashes should remain outside the inventory they hash, following R13's existing rule.

I parsed all 15 graph entries and topologically sorted all 30 declared edges. One valid order is
R01, R02, R03, R05, R10, R04, R09, R07, R08, R06, R11, R12, R13, R14, R15. No declared cycle
or new initial-ready task was introduced. Finding 1 is a textual closure cycle, not a JSON-edge cycle.
R03 and R05 can retain independent readiness: R03 owns the suspension decision, R05 implements the
specified clock interface, and R12 checks the integrated behavior. Neither needs completed R11
audio evidence to close its own source repair.

No blocking human decision is necessary for these corrections. Native rendering/audio/focus and
actual extracted-candidate play remain mandatory evidence gates; availability limitations cannot
be converted into passes. Preserve the intended three-route loop, caps, one breaker, imported art,
and existing engine/solver rate.

## Full-read attestation

Read complete `PLAN.md`, `task_graph.json`, **all 15 task cards R01–R15**, `reviews/round_1.md`,
and `reviews/round_1.diff`. Re-read sections obscured by aggregate tool-output truncation in smaller
calls. Inspected existing main movement/bail/help/settlement/replay code, rider bail body placement,
prop callback/layer ownership, authored collider dimensions, and test/export/package/launcher code
only to ground load-bearing review claims. Independently parsed the graph without writing it.

This is actual internal review **round 2 only**, not four rounds or final steady-state certification.
I did not run native Godot, listen to audio, rerun gameplay tests, verify external API documentation,
invoke an external model, or establish a new observed gameplay defect. Findings distinguish internal
planning contradictions and missing oracles from runtime risks needing implementation validation.
