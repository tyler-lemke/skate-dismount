# Research and competing designers

## What the reference games offer

Porrasturvat's original author describes spending significant development time stabilizing and tuning the ragdoll, using articulated body parts with spherical and hinge joints. He explicitly credits behavior over elaborate graphics. That supports prioritizing readable, stable falls here. [Jetro Lauha's development account](https://www.flipcode.com/archives/08-06-2003.shtml).

Secret Exit's own Stair Dismount description emphasizes acrobatics, bodily impacts, varied descent locations, crunchy sounds, and competing for damage records. The useful lesson is a short experiment with an immediately visible physical outcome. Our implementation adds persistent limb injuries, a body diagram, distinct contact sounds, and a quick replay. [Developer product description](https://apps.apple.com/us/app/stair-dismount/id326469137).

EA describes Burnout CRASH as a pinball/game-show mixture: traffic chaos, explosions, valuable targets, and junctions requiring different skills and strategies. This suggests that an excellent crash is a planned chain with a second opportunity to intervene, followed by a clear reward. Our three authored lane circuits and directional crashbreakers implement that interpretation. [EA announcement](https://news.ea.com/press-releases/press-releases-details/2011/EA-and-Criterion-Games-Announce-Burnout-CRASH/default.aspx).

These are design inferences from documented features, not controlled evidence that any one mechanic causes enjoyment. The MDA paper distinguishes mechanics, runtime dynamics, and the player's emotional response, and recommends iterative tuning. Our checks target measurable dynamics; a human playtest is still needed to judge the emotional response. [Hunicke, LeBlanc, and Zubek — MDA](https://users.cs.northwestern.edu/~hunicke/MDA.pdf).

## The competition

Three available model agents independently reviewed the actual code, proposed their strongest changes, cross-scored rival designs, and implemented the selected parts. The Dueling Idea Wizards process was adapted to the collaboration tools available in this session.

| Model | Creative designer hat | Specialism |
| --- | --- | --- |
| GPT-6.1-sol | Domino Architect in a Pinstripe Helmet | Branches, transfer targets, causal chains |
| GPT-6-astra | Ragdoll Choreographer in a Clockwork Top Hat | Impacts, body articulation, camera, pacing |
| GPT-6-sol | Claims Adjuster in a Paper-Crane Fedora | Payout feedback, narrative, campaign and interface |

| Proposal package | Cascade review | Impact review | Story review |
| --- | ---: | ---: | ---: |
| Persistent injuries, automatic slow crashes, selectable poses | 910 | Originator | 930 |
| Branching layouts, tighter blasts, longer fuses | Originator | 860 | 905 |
| Best-claim fund, receipts and warm treatment story | 825 | 800 | Originator |

Scores are subjective design judgements out of 1000, not player ratings or measured fun. Individual proposals, objections, and implementation evidence are preserved in [cascade](design_cascade.md), [impact](design_impact.md), and [story](design_story.md).

Additional model access was attempted. Further collaboration profiles hit the agent thread limit. Claude Opus could not reach its API server (DNS failure); Antigravity could not start its local server within this environment. Grok could not create its session because of filesystem permissions. No successful contribution is attributed to an unavailable model.

## Decisions produced by adversarial review

- Keep Mom's illness sincere. Make the insurer and physics absurd, with warm chapter notes and a concrete funded-treatment ending.
- Do not call model consensus objective fun. Validate causal handoffs, choice sensitivity, contact integrity, pacing bounds, and reachable funding separately.
- Preserve three boosts, but make their direction visible and consequential, and add a cooldown.
- Slow the crash automatically, while keeping camera response and receipts on the presentation clock. Bound the overall run to prevent a long inert tail.
- Exclude the skateboard and resting support impulses from injuries. Cap each anatomical settlement and restore damage snapshots during replay.
- Start Civic on its satisfying domino route. Keep the quieter cart line available as a deliberate alternate experiment.
- Retain old records separately: a prior damage score must not silently become treatment money.
- Route Space before GUI button acceptance, so selecting a pose cannot block launching.

## Objective acceptance measures

The physical simulation suite measures nine unassisted lane runs plus three pose experiments, with additional contact and boost probes. Each route must produce distinct initial property handoffs, at least a 15% payout spread between starting lines, a completed bounded run, real injuries, and a balanced ledger. Opposite boost directions must impart opposite lateral velocity. Pose choices must redistribute injury severity materially. The best demonstrated unassisted claims across three routes must cover the treatment goal.

The input suite dispatches real key events through Godot with a visible pose button focused. The contact suite drops actual rigid bodies onto a floor and verifies that resting bodies stop earning claims. UI checks use Godot font metrics and include non-overlapping severity bars. Replay and save tests prevent payout duplication.

These proxies guard agency, feedback integrity, attainable stakes, and retry speed. They do not measure whether people laugh, understand the cascade at a glance, or voluntarily retry. No human playtest was available in this headless session. A useful subsequent playtest would ask five first-time players to identify the worst injured limb, explain the final domino handoff, intentionally change a landing, and choose whether to retry without prompting.
