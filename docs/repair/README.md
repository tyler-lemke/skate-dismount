# Repair planning deliverable

The user invoked planning-workflow for the game's glitches on 2026-10-04.
This directory contains the investigated repair plan; game fixes are not implemented yet.

Start with [PLAN.md](PLAN.md) for scope, observed failures, shared contracts, and the graph.
The fifteen standalone task cards are in [tasks](tasks/).
The first implementation task is [R01 — isolated startup and regression evidence](tasks/R01.md).

Evidence from real isolated Godot probes:

- [Physics audit](audit_physics.md): phantom taxi strikes, Port hovering, spinning-wreck settlement.
- [Input/replay/camera audit](audit_state_ui.md): keyboard modal bypass, Tab focus, replay and camera contracts.
- [Records/release audit](audit_validation.md): malformed records, failed-save funding, test contamination, launch provenance.

Logs, JSON observations and probe scripts live in `builds/repair_audit/`.
A source-baseline digest records that the audit did not alter gameplay or packaged artifacts.
Existing package integrity passed; this is not a report of a corrupted current ZIP.

[Review decisions](reviews/DECISIONS.md) record actual reviewers, revisions, and limitations.
Four actual adversarial passes reached steady state and task conversion is complete.
[QUEUE.md](QUEUE.md) identifies the executable local queue and verified mapping.
No external Gemini/Claude/Grok participation or native screenshots are implied by internal reviews.

Future implementation agents must inspect their prerequisite handoffs, reserve shared files,
use isolated record fixtures, and attach actual acceptance evidence before closing a task.
Candidate construction, native gameplay validation, and exact-byte release promotion are separate gates.
