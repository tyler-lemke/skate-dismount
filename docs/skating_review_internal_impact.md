# Internal fallback review — Codex, impact and motion

**Provenance:** internal Codex review after the actual Antigravity CLI failed to start. This is not an Antigravity review. No external provider model ID was returned. The reviewer previously contributed to the current ragdoll implementation, so this is a fresh adversarial assessment of the supplied ideas, not an independent audit of its own prior work. No gameplay changes were made for this review, and no human playtest is claimed.

## Diagnosis

The clearest current defect is that the character's actions do not explain its motion. The RUN motor accelerates continuously and translates sideways, while `pose_ride()` prepares movement poses and then `apply_launch_pose()` replaces most of them. A nicer face will still ride like a motionless prop until that ownership conflict is fixed. Conversely, rebuilding the entire board controller before seeing a convincing push and turn risks months of foundational work for a few seconds of approach.

The game needs a small number of understandable choices: produce speed, choose a line, choose how to leave the board. The existing staircase injuries and property cascades are the payoff. The skating package should make the player anticipate that payoff rather than delay it.

One claim in I09 needs correcting: `rider.gd:188` already copies each visible body part's global transform into its ragdoll body. A current mesh pop is not established by the excerpts. Handoff work becomes essential when animation and heading are introduced; it should preserve that continuity rather than sell an existing capability as new. Literal velocity continuity also conflicts with the intentional 0.72 forward carry and downward launch in `main.gd:287`. Preserve an explicit, understandable arcade transition instead of quietly undoing the stair fall.

## Scores for all twenty ideas

Scores are rounded design judgments using the packet's weights: immediate skating feel 30%, character/animation readability 25%, crash-loop fit 20%, implementation confidence relative to effort 15%, and ease of player validation 10%. They are neither measured enjoyment nor probabilities. A high individual score does not automatically make an idea part of the best five-item package.

| ID | Weighted score / 100 | Verdict | Biggest concrete objection | Explicit dependency |
| --- | ---: | --- | --- | --- |
| I01 | 80 | Rework | Detailed folds and a face consume art time before proving they read at chase distance; a skeleton conversion could also break the segmented ragdoll. Prioritize silhouette, hands, shoes, and proportions. | Freeze eleven-region proportions and attachment pivots; a minimal I11 motion prototype and gameplay-camera approval. |
| I02 | 84 | Rework | Full two-leg IK is an unnecessary source of knee snapping if the first slice needs only stable deck anchors and one authored kick. | Consistent limb lengths, explicit foot/deck anchors, and a single owner of pose transforms from I11. |
| I03 | 90 | Keep | Existing full-charge launch already supplies substantial speed; adding kick timing on top may become cosmetic or compulsory busywork. | Resolve charge versus pushing; grounded contact signal; I11 push/contact/recovery phases. |
| I04 | 72 | Rework | A physically credible board can catch stair noses and bail before the intended target; this foundation can consume the entire project. | Defined arcade step assistance, contact/velocity contract, and preserved actual-tread/cascade regressions. |
| I05 | 86 | Keep | Slower heading response can turn deliberate lane selection into fighting drift. The short apron leaves little space for realistic turning radii. | Shared heading/velocity data, strong steering limits, and I11 lean driven by actual turning. |
| I06 | 70 | Defer | A powerslide adds another recovery mechanic before it is known whether basic steering needs one; dramatic speed loss can remove the crash payoff. | Stable I03 speed economy and I05 steering; measured overshoot problems. |
| I07 | 61 | Defer | Remapping the established bail key and adding airborne skating can make avoiding the staircase more rewarding than hitting it. | I04 airborne/contact state, revised controls, landing animation, and a tested hop destination. |
| I08 | 48 | Reject for this pass | Optional timing bonuses can still become the optimal mandatory routine, splitting attention between a timing cue and the coming crash. | Stable I03 rhythm and authored transitions; accessibility validation. |
| I09 | 87 | Keep, tightly scoped | A new anticipation animation can make bail feel late; exact velocity preservation would undo the proven downward stair entry. | I11 authoritative pose/anchors, I05 heading, explicit arcade carry factors, and collision-bail immediacy. |
| I10 | 65 | Defer | Approximate radius checks cannot credibly distinguish grazing from a frontal hit; arbitrary thresholds would make outcomes seem unfair. | Reliable swept/contact normals from a limited I04 foundation; causal prop handoff. |
| I11 | 92 | Keep, reduce states | Seven states plus a full skinned rig is too much. Unbounded animation scope would delay the first improved attempt. | One authoritative pose driver, contact/push events, consistent limb pivots; only coast/push/crouch/carve first. |
| I12 | 79 | Rework | An elaborate look-ahead camera may visibly lag the chosen line or conceal it during automatic framing changes. | Stable heading from I05 and native observation of the current camera; obstruction cases before cosmetic FOV work. |
| I13 | 77 | Defer | Spinning wheels and articulated trucks will not fix a rider that glides sideways or pushes without contact. | Distance traveled, heading, and ground contact; separate exported wheel/truck pivots. |
| I14 | 83 | Keep later | More event sounds can bury the one important push or limb impact under receipts and repeated clacks. | Correct contact/push events and an audible mixing playtest; reduce competing sounds first. |
| I15 | 76 | Defer | Small authored damage zones may be less readable than the current exaggerated markers at gameplay distance. | I01 mesh/material contract and the eleven-region damage/replay ledger. |
| I16 | 52 | Defer | A tiny helmeted face is unlikely to communicate panic reliably from the chase view; emotional tone can become a cutscene problem. | I01 face topology plus evidence that expressions are visible in actual framing. |
| I17 | 66 | Defer | Hat and jacket springs can disguise stiffness in a promotional shot while the player's feet still float. | Stable rig/attachment transforms and an explicit replay strategy. |
| I18 | 78 | Rework | A lesson teaching mechanics that are still changing will teach yesterday's game; repeating fifteen seconds is costly in a retry loop. | Final controls and measured first-attempt confusion; make cues skippable and one-time. |
| I19 | 63 | Defer | Recording starts for the crash in the current flow, so an approach ghost is not simply reusing already-recorded approach frames. It also adds clutter before steering is trustworthy. | Approach recording, reset semantics, and stable I03/I05 input response. |
| I20 | 69 | Defer | A bank, curb, or gap creates pressure to ship new controller features merely to traverse the new scenery. | Proved push/carve feel, measured time to first crash, and existing downstream reachability. |

## Exactly five ranked recommendations

1. **I11 — One coherent animation driver.** Fix the overwritten riding state first, using the existing segmented character. Ship coast, push/contact/recovery, modest crouch, and carve lean. Do not build seven complete states or a new skinning pipeline before the first playtest. This beats secondary motion, facial expressions, and wheel polish because it repairs the main visual explanation of movement.
2. **I03 — Push, coast, and speed management.** Make the planted kick produce the speed change, with tap and hold sharing the same comfortable cadence. Keep the run-up short. I03 owns the motor event; I11 owns the visible body response, so these are complementary responsibilities rather than two independent animation systems. This beats pump timing and the ollie because it improves every approach without a new failure-prone move.
3. **I05 — Forgiving carving.** Introduce a bounded heading change and readable body lean while preserving generous lane correction. Start with almost no extra lateral slip. This beats powerslides and graze recovery because it makes the basic directional input understandable before adding ways to repair it.
4. **I09 — Intentional, continuous dismount.** Transfer the final visible pose and its matching joint anchors at the exact transition; collision bail remains immediate. Manual anticipation must begin from an input state that does not delay the existing bail command. Preserve the intentional downward stair entry. This is chosen over a broader camera rewrite because it connects all three new approach changes to the established payoff.
5. **I01 — One readable character art pass.** After the motion slice works, replace the box-man silhouette with deliberate proportions, shaped hands/shoes, and a simple recognizable face. Keep the eleven physical regions and existing hats. Stop at a gameplay-scale art pass; detailed cloth folds and facial animation are outside this slice. Although I02 and I14 score higher individually, a constrained protagonist pass directly addresses the requested character polish; their smallest contact and sound needs can be identified without committing to full standalone systems.

## Prerequisites are work, not free extras

**I02 contributes a bounded prerequisite:** specify front/rear foot anchors and an authored planted-foot stance with a consistent knee bend. Permit a simple two-segment solve only where needed for the planted leg. Do not turn this into a general terrain-adaptive full-body IK framework. Failure to keep the foot on the board blocks the push slice even though the complete I02 proposal is not selected.

**I04 contributes a bounded prerequisite:** expose reliable grounded/contact information for push eligibility, a shared velocity/heading value, and a swept approach check sufficient to avoid obvious tunneling. Retain assisted step traversal and the current stair-focused ragdoll transition. If even this requires a wholesale motor rewrite, pause the five-item package and prototype the controller separately; do not hide that cost inside animation. These prerequisites must be estimated and validated alongside the five selections.

## Strongest disagreement and missing idea

The packet treats a comprehensive grounded controller and a skeletal animation rig as natural foundations. Neither is justified as the first deliverable by the observed defect. There is already enough segmented geometry to demonstrate a coherent planted kick, a lean, and a matched dismount. First prove that those moments feel better. A rig or controller replacement should solve a demonstrated remaining limitation.

**Missing idea: unify launch charge and pushing into one understandable source of effort.** The current charged start can provide 18.5 m/s before the first kick. If the new push matters little, it is ornamental; if pushing is required anyway, the player must perform two speed-building rituals. Test a short rolling start with optional hold-to-push against an accessible charged-launch option that substitutes for, rather than stacks with, repeated kicks. Keep a one-action path to a satisfying first crash. This is a product decision inside I03, not a sixth selected feature.

## Build order and first playable

1. Agree on forward-speed ownership and the animation/contact/heading contract. Measure current approach duration as a comparison point. Establish foot anchors and the minimal contact prerequisite.
2. Implement the procedural I11 coast/push cycle and I03 kick timing together on the unchanged Civic apron, using the current character meshes. The planted leg stays on the board while the kick leg contacts and recovers. Avoid spending time on character detail yet.
3. Add limited I05 heading and lean. Revalidate that the player can intentionally reach all three entries without hunting for the right steering angle.
4. Complete I09 pose/anchor transfer for an immediate collision bail and responsive manual bail; preserve the actual-tread impact sequence and physically propagated property claims.
5. Apply the bounded I01 art pass to that working contract. Recheck feet, silhouettes, injury regions, hats, and replay before touching the other approaches.

The **minimal first playable** is Civic's current apron and staircase with the existing character: hold or tap W produces visible, useful kicks; release coasts; A/D makes a clear, forgiving turn; Space still bails immediately into a matched pose and successive stair impacts. The run remains short and can be retried immediately. No ollie, powerslide, pump meter, facial rig, new level geometry, or accessory springs are needed to evaluate that slice.

## Acceptance that can change the decision

- **Observed play:** in a small formative session, ask each player to choose a different lane on the next attempt and explain what their last kick and turn changed. Record unintended bails, steering corrections, and whether they voluntarily retry. Report observations directly; a tiny sample is not statistical proof of fun.
- **Timing:** speed change coincides with planted kick contact; hold-to-push does not lose ground to equally timed tapping; charge plus pushing does not add a second mandatory wait. Compare median time to first crash with the existing build rather than accepting a prettier, slower approach.
- **Body readability:** inspect native frames at normal chase distance, not just close-up renders. Check planted-foot drift, knee continuity, readable lean, and whether the selected crash body shape appears without a last-frame pop. If the face is unreadable, spend art time on silhouette instead of expression detail.
- **Handoff:** compare visible part transforms and joint anchors immediately across bail; collision bail incurs no added frame of animation delay. Verify the existing deliberate velocity mapping rather than requiring physically exact conservation. Retain successive verified tread injuries and meaningful property cascades across representative lanes.
- **Regression:** replay restores every appearance state and does not add money; versioned funding behavior remains intact; contact and movement stay finite. These are release gates, not evidence that the skating is enjoyable.
