# Task conversion checks

These are six focused conversion checks, not six model review rounds.
The four whole-plan review rounds are recorded separately.

1. Full-description conservation: every stored bead body equals its reviewed card byte-for-byte.
2. Graph conservation: all30 directed blocking edges match the manifest; no extra dependency exists.
3. Scheduling: only R01 is initially ready; the graph is acyclic and every task reaches R15.
4. Priority/identity: titles, keys and P0/P1/P2 priority values match the reviewed task registry.
5. Acceptance preservation: exact-body conservation retains reproduction, rationale, independent
   test cases, negative controls, rollback, and evidence handoffs; independent audit checks semantics.
6. Honest completion: all15 repairs remain open; package/native gates are required future work,
   and the tracker health/export checks pass without representing gameplay as fixed.

Evidence: bead_verification.json, review models/decisions, br-generated ready/cycle/flush results,
and the independent beads_conversion.md review. No SQLite/JSONL contents were edited by hand.
