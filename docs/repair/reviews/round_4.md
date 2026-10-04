# Repair plan review — round 4

Date: 2026-10-04. Independent internal reasoning-model whole-plan review under the
planning-workflow skill. This file is the sole output of this review.

**Verdict: the plan is ready for dependency-preserving task conversion and implementation.**
No remaining structural revision or indispensable marginal correction was found. The latest
revision is marginal and the fourth review reaches steady state. No proposed diff is necessary.
This verdict concerns plan readiness only; no gameplay repair, native acceptance, release, or
tracker conversion is certified by this review.

## Previous marginal changes verified

R03 now explicitly permits mute in every phase and under PAUSE/HELP through the authoritative
action policy. Its dispatched-input checks preserve that control with a focused live Button.
R11/R14 retain separate allocated-player and audible checks, so a headless mute assertion cannot
substitute for listening. Persistence remains owned by R02, including protected and pending saves.

R06 now states that R01's fixture/runner infrastructure is available transitively through R05.
It defines camera sample origin, source age, increasing capture sequence, equal-time tie handling,
endpoint holding, and zero-duration behavior. Its independent cases exercise distinct equal-time
views and an older final render sample. Material/morph/wheel isolation is explicit, and checking
live shader/damage state during playback prevents a copied dictionary from concealing shared
mutable presentation resources. These changes add precision without new task or dependency scope.

## Structural and closure checks

Parsed all 15 graph entries and 30 dependency edges independently. The machine-readable graph
exactly matches the Mermaid edges in PLAN.md. All task paths exist. R01 is the only initial-ready
task; R15 is the sole intentional sink. A valid topological order is:

`R01, R02, R03, R05, R04, R09, R10, R07, R08, R06, R11, R12, R13, R14, R15`.

Textual completion conditions introduce no additional closure cycle in the reviewed plan:

- R04 closes against the existing contact-to-bail seam and publishes accepted pose/reset APIs.
  R08 consumes those APIs later; R04 does not need downstream R08 completion.
- R03 and R05 implement published input/clock contracts independently. Their combined state is
  checked in R12. Shared main.gd ownership remains explicitly serialized despite graph readiness.
- R07 publishes a caller-supplied camera query context without requiring R06's completed proxies.
  R06 later owns historical hull reconstruction, query synchronization, and disposal.
- R08 and R11 can finish bounded source investigations with precise unobserved native cases for
  R14. R11 does not require the candidate whose construction depends on its source handoff.
- R13 builds and verifies an extracted candidate; R14 observes that candidate; R15 promotes its
  exact bytes. Native failure reopens the responsible repair and requires a new candidate.
  R15's finalized source archive allows launcher/docs changes while runtime inputs stay matched.

No task requires an unimplemented downstream feature merely to demonstrate its own acceptance.
Evidence-driven reopening after integration/native failure is a repair loop, not a scheduling
deadlock or permission to skip a failing gate.

## Fresh-agent sufficiency and independent acceptance

The cards state the game context, relevant source/reproductions, ownership boundaries, required
interfaces, acceptance oracles, evidence locations, and completion conditions. Prerequisite
handoffs are explicit where implementation details will be learned during execution. Those
future evidence artifacts are legitimate task outputs rather than hidden present-day context.
No indispensable unresolved human product decision was found.

R01 supplies isolated startup, extensible suite registration, process deadlines, and negative
runner controls. R02 uses explicit arrays/bytes, restart observations, checked failure seams,
and post-replacement reconciliation rather than parser-generated expected values. R04 pairs
grazing/turning contacts with independently clear controls and actual tread support queries.
R05 uses controlled clock inputs; R07 separately measures final lens geometry and aim; R08
distinguishes simulation transfer, CPU skin continuity, and unobserved native appearance.
R09 checks solver motion and causal negative controls. R06 compares live state before, during,
and after replay while independently testing timing and projection. These are meaningful
outcome oracles rather than assertion-count targets or self-confirming production calls.

The integration and package gates preserve the original reproductions and require real contacts,
dispatched input, independently reopened records, negative archive controls, and exact candidate
identity. R14 cannot close on headless or Blender evidence. Platform limitations and unavailable
native services remain visible restrictions, not implicit passes.

Scope still preserves all three routes, supported speed, poses/hats, articulated injuries,
finite causal traffic, exactly one breaker, payout caps, and the treatment-fund story. The plan
does not authorize fallback awards, speed reduction to pass collisions, a wholesale controller
or rig replacement, or new release infrastructure. The good-play attainability gate may expose
real balance problems; it cannot be satisfied by changing accounting solely to pass a benchmark.

## Full-read attestation and review limits

Read complete PLAN.md, task_graph.json, all **15 task cards R01–R15**, reviews/round_3.md,
reviews/round_3.diff, and reviews/standalone_3.md. Read the planning-workflow SKILL.md and checked
for a root AGENTS.md; none existed. Re-read content obscured by aggregate output truncation in
smaller calls. The graph/edge/path verification ran read-only. No source inspection was needed
to resolve an uncertain load-bearing claim in this pass; earlier technical/runtime claims remain
attributed to their preserved audit evidence rather than newly verified here.

This is actual internal review **round 4**, not an external Gemini, Claude, Grok, or GPT Pro
invocation. It found no further required edits and certifies only the reviewed plan's readiness.
It did not run game tests, inspect native output, listen to audio, verify external API documents,
modify gameplay or plans, or inspect/alter beads. Mechanical bead conversion and its dependency
verification remain the orchestrator's separate completion work.
