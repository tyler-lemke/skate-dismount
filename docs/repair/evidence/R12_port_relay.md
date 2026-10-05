# R12 — Port right-line physical relay

The full runtime gate exposed a real authored gap on the Port right coast line.
Its180kg taxi at x=3.4,z=10.18 has a downstream box end at z=11.83. The next
existing right barrel is at z=16.74 and the first cargo tower at z=19.06. Correct
finite-mass skate momentum no longer carries the taxi across that gap by itself.
The control arrangement produces one real wreck, rather than the required three.

An isolated diagnostic retained the production rig, score values and600k goal,
then added ordinary `World.spawn` dominos during READY. The .75-charge, x=3.3,
TUCK coast uses the same controller as ROUTES. Source production was not edited
for the diagnostic; each new relay's actual shape was independently queried
against layer2 and had **zero initial overlap** with any other prop.

`PORT_RELAY12 checks,0 failures` compares:

| Physical layout | Wrecks | Payout | Explosions | Taxi furthest Z |
|---|---:|---:|---:|---:|
| Original control |1 |$20,375 |0 |14.304m |
| Dominos at steps10–13, x=3.4 |54 |$461,003 |17 |13.248m |
| Dominos at steps11–13, x=3.4 |48 |$407,780 |17 |13.921m |

The four-relay arrangement is the recommended robust bridge. Its exact centers
are z=12.10,13.26,14.42,15.58 using `step*1.16+.5`; the first domino's upstream
face is z=11.97, leaving **.14m** initial clearance after the taxi. The narrower
three-relay alternative leaves1.30m from taxi to first relay and also succeeds.
Every domino retains its existing .92×2.12×.26m box,4kg mass,$600 base value and
physical injury/property/combination accounting.

The first four-relay prop becomes armed at .158 simulation seconds with actual
`taxi_031` contact; subsequent first-armed solver contact snapshots include the
previous domino. The last prop arms at .3597s and the downstream crash reaches the
existing barrel row. The three-relay alternative begins with actual taxi
contact at .2986s and sequential domino contacts at .5124s and .8791s. This is a
causal physical chain; no rewards, activation, impulses or velocities were
injected by the diagnostic.

Evidence:

- `builds/repair_work/R12/port_relay_probe.gd`
- `builds/repair_work/R12/port-relay-probe2.log.result.json`
- `builds/repair_work/R12/port-relay-probe2.log`
- `builds/repair_work/R12/port-relay-probe2-engine.log`
- `builds/repair_work/R12/port_relay_probe2_fixture/port_relay_probe.json`

The original diagnostic log is retained as rejected evidence: its report used
a nonexistent `cause_edges` field and the bounded runner correctly rejected
the script errors. The corrected second run records real first-armed contact
colliders, completes without script errors and passes all12 assertions.

Root applied the measured four-relay edit in `scripts/world_builder.gd` immediately after all existing Port-specific barrels and before common cones/barriers. The exact production loop is `for step in range(10,14): spawn("domino",3.4,step*level.run+.5)`. Every existing Port-specific prop retains its original stable identity; production relay IDs are `DOMINO_067` through `DOMINO_070`, while the additive diagnostic used later available slots `DOMINO_074` through `DOMINO_077`. Root is running unchanged strict ROUTES and the affected full suite; this document does not claim those runs complete. No additional world, rig or mandatory-test edits were made by this agent. The native visual gate remains separate.
