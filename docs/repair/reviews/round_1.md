# Repair plan review — round 1

Date: 2026-10-04. Independent adversarial planning review; no gameplay or plan edits.

Verdict: **structural revisions required before implementation/beads freeze**. The declared graph is acyclic and the incident evidence is carefully qualified. Its hidden dependencies and several cross-task contracts are not yet executable as written. Preserve the bounded repair scope; none of the findings justifies a new engine, rig, mixer framework, or scoring model.

## 1. P1 — R11 requires the candidate that it blocks

Evidence: `tasks/R11.md:90` requires checking the exported candidate asset list; `R11.md:4-5` makes R11 a prerequisite of R12; `R12.md:4-5` blocks R13; `R13.md:3` creates the candidate only after R12. Thus the semantic cycle is R11 → R12 → R13 → R11 despite the JSON passing DAG validation. R11 also requires a real audio-enabled process before editing (`:28,67-74`) while allowing hardware checks to remain for R14 (`:96-97,113`). A fresh agent cannot tell which missing native evidence prevents closing R11. Adding an R13 prerequisite would encode, rather than solve, the cycle.

Proposed revision:

```diff
--- tasks/R11.md
+++ tasks/R11.md
@@
- Verify the candidate exported app uses the same asset list as the source manifest.
+ Publish the source audio resource inventory for R13. R13 verifies exported resources;
+ R14 owns candidate listening and device observations. Candidate checks do not block R11.
@@
- First observe state transitions in a real audio-enabled process; edit only a failed behavior.
+ Attempt source-process playback using isolated storage. Separate actual player-state
+ observations from listening. If native allocation is unavailable, retain the existing
+ behavior unless independently reproduced evidence supports a change; publish the exact
+ unobserved cases as mandatory R14 gates. Never mark their sound quality verified.
@@
- Close only after actual transition evidence and required focused fixes are present.
+ Close the source investigation after resource/lifecycle checks and supported fixes,
+ with explicit pass/fail/unobserved cases. Unobserved native cases block R14/R15,
+ not candidate construction. R14 failure reopens R11 and rebuilds through R13.
```

Rationale: this permits a truthful candidate to exist for the observations while preserving the final native gate. A source native observation remains valuable when available.

## 2. P1 — Replay camera collision queries see the wrong historical world

Evidence: `R06.md:42,55-59,74-77` places replay actors in nonphysical presentation proxies while live bodies remain frozen at settlement. `R07.md:29,37,51-58` requires camera queries against real props and allows replay to reuse that query context. Supplying replay focus alone does not change the prop collision geometry. An early replay frame may show an upright taxi where the frozen collider is now on its roof elsewhere; an alternate camera can enter the visible taxi, or avoid an invisible final wreck. This follows from the proposed ownership model and needs no native claim.

```diff
--- tasks/R06.md
+++ tasks/R06.md
@@
- Actor catalog: ID, visual resource/kind, spawn transform and presentation reconstruction metadata.
+ Actor catalog also includes immutable camera-query shape geometry/local transforms.
@@
 Replay owns presentation proxies or equivalent isolated visual state, with physics disabled.
+ Alternate replay views query static route geometry plus query-only prop geometry at
+ the replay timestamp, excluding all frozen live dynamic RIDs. Use a bounded isolated
+ query representation or explicit geometry adapter; it has no simulation/contact callbacks.
+ Update this geometry synchronously before solving the replay camera. Destroy it on exit.
+ Test a prop whose early and final transforms do not overlap: camera safety must follow
+ the visible replay prop, and an invisible final collider must not obstruct it.
--- tasks/R07.md
+++ tasks/R07.md
@@
 Expose a camera update API taking phase/view mode, focus, presentation delta and world-query context.
+ The context is supplied by the caller and selects live or replay-time obstruction
+ geometry. Do not capture main's live physics space as an unavoidable private dependency.
```

Rationale: defines the missing seam without prescribing a second simulator. Recorded-camera playback remains unchanged; alternate view geometry is the issue.

## 3. P1 — Sweeping detects a contact but does not specify contact-time placement

Evidence: `R04.md:44-53,60-65` returns a hit fraction and transfers a corrected pose to R08 but never states that the root stops at that fraction before bail. Existing `scripts/main.gd:286-307` advances the root before testing and bailing. An implementer can add a correct sweep yet leave the ragdoll spawned on the far side of a thin obstruction. The contract also filters to eligible props after a mask-2 query without specifying what happens when the nearest result is an excluded traffic/broken prop. Discarding that first result can hide a later eligible obstruction.

```diff
--- tasks/R04.md
+++ tasks/R04.md
@@
 Resolve only the earliest qualifying obstruction, preserving one activation and one bail transition.
+ Before activation/bail, place the authoritative riding root at the accepted earliest
+ contact transform, with a documented separation tolerance; never leave it at the
+ unobstructed end-of-step pose. Derive the bail pose from that contact placement.
+ Exclude ineligible RIDs before a sweep or continue a bounded search past them.
+ Define heading-change handling: substep translation/rotation with a measured bound
+ or a conservative envelope; previous/next transforms alone do not define the sweep.
+ Test an excluded first collider followed by an eligible thin prop, and a turn that
+ contacts at mid-step. Independently inspect the first ragdoll pose, not just hit count.
```

Rationale: preserves momentum and fast skating while preventing a detected hit from still tunneling. No suspension conversion is needed.

## 4. P1 — Corrupt-save recovery requested by R10 is absent from R02

Evidence: `R02.md:54-58` exports only `recover_backup()` and rejects unresolved corruption writes at `:71`; `R10.md:43-44` requires a no-backup choice that preserves damaged bytes and creates a fresh save. R10 explicitly does not own the records service. The service also leaves post-replacement verification failure and recovery funding events ambiguous (`R02.md:62-87`). A successful filesystem replacement followed by a verification/read failure can leave disk ahead of the reported durable snapshot; retry must reconcile that state. Restoring an already-funded backup should not announce all recovered funds as new earnings merely because session durable defaults started at zero.

```diff
--- tasks/R02.md
+++ tasks/R02.md
@@
 Expose `recover_backup()` as an explicit operation for R10; do not invent an automatic destructive reset.
+ Also expose `recover_fresh()` for an explicit player choice when the required-score
+ primary is corrupt and no valid backup exists. Preserve the original under a unique
+ quarantine name first; failure leaves all protected bytes and session progress intact.
+ This operation does not apply to unsupported future profiles.
+ Recovery uses the same checked commit machinery and merges current session maxima.
+ Treat validated recovered scores as the recovery baseline: only increases above it
+ are newly earned contributions. Recovery alone does not emit a newly-funded ending.
@@
 Inspect every copy/rename/replacement result and keep old recoverable data until the commit is verified.
+ Define the commit point and return `uncertain` separately when replacement may have
+ succeeded but verification failed. Keep the pending candidate and withhold secured
+ wording until reconciliation. Retry/reload rereads and validates primary/backup before
+ another write; compare complete snapshots and emit a contribution at most once.
+ Test failures after primary replacement, recovery with no backup, v1 backup migration,
+ already-funded backup recovery, and recovery plus an earned session improvement.
```

Rationale: closes an actual ownership gap and the one meaningful untested commit boundary. This can remain a small synchronous service. It does not require a journal or a new serialized schema.

## 5. P1 — R11 cannot consume the nonexistent focus-loss pause policy

Evidence: `R11.md:43` says focus loss follows R03's pause policy. `R03.md:39-43` only clears/gates inputs; it does not say whether simulation pauses or when it resumes. `R05.md:46` resets the clock baseline on focus loss. With one plausible interpretation, physics keeps running while audio pauses and presentation deadlines lose wall time. Another implementer may auto-resume and launch stale held input. Neither existing `main.gd` nor these cards supplies the promised contract.

```diff
--- tasks/R03.md
+++ tasks/R03.md
@@
 Window focus loss clears all held action latches; return requires a fresh gameplay press.
+ In READY/RUN/CRASH/REPLAY, focus loss enters the existing pause state unless a modal
+ already owns suspension. Regaining focus does not resume; the player selects Resume.
+ Preserve HELP/PAUSE return context and leave MENU/RESULTS phase unchanged.
+ All held movement keys require release/repress after focus loss, including polled keys.
--- tasks/R05.md
+++ tasks/R05.md
@@
 Handle first sample, route replacement, focus loss, and replay as explicit resets.
+ Focus suspension refreshes the presentation baseline without resetting accumulated
+ run/crash elapsed time. Simulation, replay time, and action audio remain suspended
+ together until R03's Resume transition; no idle/deadline/fuse time accrues during it.
```

Rationale: chooses a conventional deterministic policy rather than leaving three owners to invent incompatible meanings. If continued unfocused play is preferred, specify that consistently instead; this is a planning choice, not a required human decision.

## 6. P2 — R11's optional replay event track introduces undefined behavior

Evidence: `R11.md:44-50,103` requires timestamp crossings but offers music-only replay only if native evidence favors it. `R06.md:51,63` records receipts/event visibility and promises audible hooks without defining audio event kinds, payloads, or timestamp-zero behavior. Existing `sound_director.gd:34-59` suppresses events with wall-clock cooldowns and randomizes pitch. Feeding a tape through `play()` can suppress the opening events on the second playback, despite a correctly reset replay cursor. A stable event ID is not an audio playback contract.

Smallest revision for this repair:

```diff
--- tasks/R11.md
+++ tasks/R11.md
@@
- Replay initially uses music plus a restrained presentation event track from R06's tape.
+ Default replay is music-only; stop live action audio at entry. No new event track is
+ required to repair the confirmed bugs. An event track is optional follow-up work.
+ If retained in scope, define an immutable `{id, sim_time, sound_key, gain, pitch}`
+ schema, event-zero and duplicate-time ordering, and a replay-specific cooldown state
+ before implementation. Reset that state on replay entry and never consume live cooldowns.
```

Rationale: avoids adding a new feature to resolve an unobserved stale-loop hypothesis. If an event track is desired, the alternative addition is small and precise.

## 7. P2 — Source archive is constructed before its launcher and instructions are repaired

Evidence: `R15.md:56-60` creates/promotes the source ZIP, then changes Play.command, then updates README. The source ZIP can ship the old launcher and stale instructions while the workspace advertises repaired launch provenance. `R13.md:35-47` rightly separates runtime input identity from output hashes, but no source-deliverable inventory captures these subsequent edits.

```diff
--- tasks/R15.md
+++ tasks/R15.md
@@
- 6. Create or promote a source archive from the identical validated source manifest.
- 7. Apply the launcher contract and validate its dispatch with matching/mismatching fixture identities.
+ 6. Apply and validate the workspace launcher contract; finalize source README and commands.
+ 7. Build the source archive after those edits. Its runtime inputs must match the
+ validated candidate inventory exactly; record a separate full source-deliverable
+ inventory for launchers/docs/tools, excluding generated evidence and recursive archives.
+ Re-extract it and exercise launcher dry-run dispatch with matching/stale/missing app cases.
```

Rationale: promotes the exact tested application without forcing an unnecessary export for documentation changes, and ensures the source product contains its claimed fixes.

## R11 standalone implementability assessment

Reading R11 alone is insufficient to implement and close it safely. It names upstream artifacts appropriately, but even reading those artifacts' planned contracts does not resolve: (a) the future candidate prerequisite; (b) which native evidence may remain deferred at closure; (c) the claimed focus-loss pause policy; (d) the optional event payload/cooldown semantics. Findings 1, 5, and 6 fix those absent contracts. Exact method names may reasonably be chosen by the implementing owner and published in evidence; they are not themselves a defect. R01's fixture and R05/R06 lifecycle interfaces can remain prerequisite handoffs.

## Graph, preservation, and decisions

I parsed all 15 entries in `task_graph.json` and topologically sorted them. One valid order is R01, R02, R03, R05, R04, R09, R10, R07, R08, R06, R11, R12, R13, R14, R15. No declared edge cycle exists; finding 1 is the hidden acceptance cycle. R15 is the intentional sink. Do not add an R13→R11 dependency.

Blocking plan corrections: findings 1–5. Resolve 6–7 before their tasks run. No blocking human decision is necessary: focus suspension, music-only replay, protected recovery, and source archive ordering have reasonable scope-preserving defaults. Native execution/audio availability is an eventual external evidence gate, not an invitation to manufacture a pass. Alternative replay audio and anatomical limits remain optional/conditional; keep the existing route, caps, timing rates, one breaker, and articulation unless their specific evidence warrants a change.

Clock/interpolation review: the one-owner/read-only presentation contract is appropriate. Do not equate the stated 1/90 tolerance with measured variable-rate delta; compare against the actual sampled tick. Bail should preserve the authoritative pose while interpolation resets prevent stale previous-attempt samples. No additional solver-rate change is justified by this review.

## Whole-plan read attestation and limits

Read the complete `PLAN.md`, `task_graph.json`, every task R01–R15, and all three `audit_*.md` files. Re-read any text obscured by tool-output truncation. Inspected existing movement/bail/settlement/replay code, camera query implementation, sound allocation/cooldowns, exporter, and export filters only to validate load-bearing assumptions. No gameplay, plan, graph, artifact, or tracker edits were made; this review file is the sole output.

This is one independent internal review round under the planning-workflow skill, not four rounds, steady-state acceptance, or an external-model review claim. I did not run native Godot, listen to audio, rerun the gameplay suite, verify external API documentation, or establish new runtime defects. Proposed changes address internal contradictions and concrete failure paths; the source audits retain their original evidence limits.
