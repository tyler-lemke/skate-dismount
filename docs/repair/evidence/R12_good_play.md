# R12 — Campaign reachability with ordinary player controls

## Final frozen production source

The final physical game reaches the unchanged **$600,000** campaign target
through ordinary keys. The unchanged search passes **GOOD_PLAY_KEYS 41 checks,
0 failures**, ending with fresh durable route bests of **$138,909 / $96,430 /
$423,588**, total **$658,927**. The saved `records.json` was independently read
back and contains exactly those three bests. This final run follows the source
freeze with the continuous plaza road, updated traffic fleet, Civic crate
clearance, Port step10 relay at x4.6/downstream relays at3.4 and Port left foot
barrel at x-4.8. No production, test, tool, scoring or goal change was made for
this verification.

`builds/repair_work/R12/good_play_search_keys.gd` starts with fresh isolated
records and uses real `InputEventKey` events after ordinary route/reset setup.
It writes no actor transform, velocity, impulse, payout or claim. Civic reaches
center through held D in READY, landing at x=.005558; Market and Port use their
authored center starts. Pose selection uses1/2, charging uses held SPACE until
the real meter reaches1, and W remains held throughout the skating approach.
Every crash settles through real physical activity. Each requested crashbreaker
uses one SHIFT press at most per attempt. An aimed attempt holds A or D for .35
simulation seconds, including ordinary aftertouch, then releases it.

| Attempt | Ordinary controls after route selection | Claim | Actual campaign bank |
|---|---|---:|---:|
| Civic | D to center; STARFISH; full SPACE; W |$61,484 |$61,484 |
| Market | TUCK; full SPACE; W |$33,134 |$94,618 |
| Port | TUCK; full SPACE; W |**$423,588** |$518,206 |
| Civic retry | Same line; forward SHIFT at .653889 simulation seconds after bail |**$138,909** |$595,631 |
| Market retry | Same line; forward SHIFT at .653889s |$37,107 |$599,604 |
| Port retry | Same line; forward SHIFT at .653000s |$251,155 |$599,604 |
| Civic retry | Same line; A aim and SHIFT at .653889s |$109,528 |$599,604 |
| Market retry | Same line; D aim and SHIFT at .653889s |**$96,430** |**$658,927** |

The winning Market breaker direction is the actual normalized
(.83205,0,.55470); Civic's winning direction is(0,0,1). Port's winning attempt
uses no crashbreaker and destroys51 props with16 explosions. The unsuccessful
retries remain in the report, rather than being discarded. The campaign banks
only each route's improvement, so lower repeat claims do not farm money.
Resource checks confirm one crashbreaker at most per attempt, and every payout
balances the real property/injury ledger. This is a measured reachable mastery
trace, not a guarantee that every attempt or physics arrangement earns the same
amount, nor a measurement of human enjoyment.

Final-source evidence:

- `builds/repair_work/R12/final-good-play.log.result.json`
- `builds/repair_work/R12/final-good-play.log`
- `builds/repair_work/R12/final-good-play-engine.log`
- `builds/repair_work/R12/final_good_play_fixture/good_play_search_keys.json`
- `builds/repair_work/R12/final_good_play_fixture/records.json`

The bounded command uses the unchanged search script, `--fixed-fps 60`, actual
production90Hz/32-pass physics, a180-second external deadline and new isolated
records paths. It has no experimental gameplay flags. The runner exempts only
the exact known macOS certificate signature; no script errors, leaks or
assertion failures were accepted. This headless control trace is not a native
screenshot or frame-presentation pass.

## Historical traces, before final layout and traffic repair

An earlier strict keys-only search passed **26 checks,0 failures**, with route
bests **$115,109 / $65,142 / $451,594**, total **$631,845** after five attempts.
It used the same actual READY steering/pose/charge/push/SHIFT controls. Those
historical results are retained under `good-play-keys.log` and
`good_play_keys_fixture`, and do not describe the final frozen source.

An even earlier separate search retained the original benchmark's trusted
center-lane fixture arrangement before real charge/pose/push/SHIFT events.
It passed17 checks and reached$619,967 after four attempts. Its artifacts remain
under `good-play-search.log` and `good_play_search_fixture`. The final41-check
run above removes that setup qualification and verifies fresh durable funding
on the final source.

The coast benchmark remains useful for lane variation, injury causes and chain
diagnostics. Root retains those cases and the unchanged600k assertion, then
evaluates the already-present Civic pose choices before checking campaign
reachability. The separate strict keys-only trace above also proves the
advertised pushing, aim and single-crashbreaker mechanics can fund treatment.
Native visual/fun review remains a separate gate.
