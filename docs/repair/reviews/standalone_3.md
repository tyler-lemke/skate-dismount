# Standalone review — round 3

**Verdict: implementable with one prerequisite clarification.** R06 supplies a coherent immutable replay contract: stable actor IDs, actual simulation timestamps, separate render-camera samples with FOV and boundary provenance/age, historical query geometry, isolated presentation, authoritative-state preservation, and disposal on every exit. R11/R12 consume its outputs; R14's native acceptance is explicitly pending, so those cards do not create a completion dependency.

**Amendment:** R06 requires R01's isolated fixture, fixture argument, and bounded runner in both implementation and acceptance, but R01 is absent from the prerequisite line. Add R01 explicitly, or state that the listed prerequisites guarantee its completed infrastructure. Reading only this card cannot establish that transitive guarantee.

**Small contract clarification:** Define deterministic ordering for distinct samples sharing a timestamp, especially multiple render updates or boundary samples, and state the recorded-camera endpoint policy when its last completed render sample precedes settlement. Holding the earliest/latest applicable camera sample outside its timestamp range, while preserving its original time/age, would satisfy the existing provenance requirement. Add an acceptance case with distinct camera transforms at the same timestamp and a final render sample older than settlement. This closes an ambiguity without requiring another feature card.

**Single-card attestation:** Read only `docs/repair/tasks/R06.md`. No other documents, handoffs, source, or evidence were inspected. This is a planning review; it makes no implementation, runtime, or prerequisite-completion claims.
