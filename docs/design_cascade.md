# Domino Architect in a Pinstripe Helmet

Read-only design competition, followed by implementation of the injury rules. Scores estimate design value and feasibility; they are not player-test results.

## Current fun killers

- Parallel repeated lanes offer similar outcomes (`scripts/world_builder.gd:121`).
- Drum fuses of 0.16–0.41 seconds and a 5.2-unit blast radius compress several handoffs into one burst (`scripts/crash_prop.gd:69`, `scripts/main.gd:262`).
- The camera follows the torso instead of the next causal event (`scripts/main.gd:350`).
- Rider hits create particles and aggregate points, with no persistent injury state (`scripts/main.gd:273`, `scripts/game_rules.gd:59`).
- Crashbreakers launch forward regardless of the player's intended target (`scripts/rider.gd:129`).

## Top five proposals

| Proposal | Score / 1000 | Concrete change | Acceptance proxy | Failure condition |
| --- | ---: | --- | --- | --- |
| Distinct cascade routes | 950 | Left domino chain, center stair injuries, right premium targets; each has entry, transfer, and payoff. Add a deliberate bridge requiring a choice. | Different first five events per route; two viable finales; optional bridge adds at least 20% payout. | All routes immediately merge into one automatic drum blast. |
| Readable rhythm and camera | 945 | Crash baseline near 0.55 speed, brief impact pulses with a global cooldown; experiment with 0.65–1.1-second fuses and 3.4-unit blasts. Frame rider and next handoff; retain a rider marker when following a distant cascade. | Typical crash lasts 20–35 wall-clock seconds; four of five first-time observers identify the final explosion's cause. | Repeated pulses stall playback, or everything becomes microscopic. |
| Visible persistent injuries | 920 | Named body regions retain severity colors; body diagram and latest diagnosis show exactly what struck. Exclude the skateboard; replay severity changes. | Worst injury is identifiable during play; harder impacts change severity visibly. | Scraping reports constant fractures or the rider is too small to read. |
| Aimed crashbreakers | 900 | Preview direction and nearby target, then commit one of three charges; direction changes horizontal impulse. | Left/right aim reach different targets; a saved charge enables a valuable late bridge. | A broad shockwave destroys both branches regardless of aim. |
| Attainable treatment fund | 860 | Transparent injury settlement plus cascade bonus; bank route-best claim improvements toward treatment. Reserve Mom's messages for milestones. | Player can explain the payout; weaker retries preserve savings; three solid silver-equivalent claims can finish treatment. | Arbitrary target traps novices behind an emotional obligation. |

## Cross-scores

- **Impact: 910/1000.** Persistent per-limb severity is the strongest immediate fidelity improvement. Frequent 0.18-speed pulses require a global cooldown; selectable poses need different trajectories or injury opportunities, not just silhouettes.
- **Story: 825/1000.** Best-claim improvement banking supports mastery. A proposed $750,000 target needs measured reachability; warm messages should not become guilt spam.
- **Root candidate: 930/1000.** Directional boosts and hand-authored branches reinforce each other when players can see the next connection before spending a charge. Radius and fuse values remain experiments until physically verified.

## Narrative tone

Let insurers and bureaucracy carry the absurdity. Cancer remains the sincere motivation between runs. Establish the fictional policy once, give the mother a few restrained lines, and make reaching treatment a concrete ending. Do not mock illness or punish a harmless retry with another guilt message.

## Implemented rules contract

`WreckRules.TREATMENT_GOAL` starts at 600,000 and needs recalibration against measured claims. `POSES` exposes TUCK, STARFISH, and TORPEDO names and tips. These rules provide descriptions; the rider implementation owns physical differences.

`limb_damage` and `limb_payout` contain eleven body-region keys, excluding the board. Valid impacts require finite force of at least 3. Severity increases by `force * 1.8`, capped at 100 per region. Payout values cumulative severity at 70 per point with region weights, then pays only the unpaid difference. This preserves the cap and prevents exploiting rounding by subdividing contacts. Property and injury settlements sum to the run score. Retries reset injury ledgers.

Diagnosis boundaries are OK at zero, BRUISED above zero, STRAINED at 30, and FRACTURED at 60. `last_limb` identifies the latest region that gained severity. The optional third argument to `hit_rider` supplies a region explicitly; otherwise the penultimate segment of a colon-delimited collision id supplies it.
