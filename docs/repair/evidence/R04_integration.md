# R04 integration boundary

The helper and independent geometric regression are implemented. This document
describes the main-controller integration; it is not a completed R04 acceptance.
Root owns changes to `main.gd` after R05 clock acceptance.

Load `res://scripts/skating_contacts.gd` once and keep one helper instance.
The helper caches five boxes shared by all twelve board/body contact proxies.
The dimensions match the existing ragdoll's physical boxes, in meters:
torso `.64 × .68 × .40`, pelvis `.52 × .28 × .38`, head `.44 × .48 × .42`,
board `.76 × .18 × 1.65`, each limb `.21 × .35 × .24`.
Transforms are the actual riding parts, so STARFISH's spread arms and board lean
change the obstruction envelope. Hats have no gameplay collision.

At the start of each RUN tick, retain `previous_root = skater.global_transform`
and `previous_proxies = skating_contacts.capture_proxies(skater)`. Apply the
existing speed, push, heading, lateral limits and proposed Z movement. Set the
authoritative root Y directly to
`SkatingContacts.grounded_height(Rules.LEVELS[level_index], skater.position.z)`;
remove the old 9 m/s vertical move-toward. The `.23 m` root-to-wheel support
reference matches the existing launch placement. This stateless placement
automatically resets at route/retry; cosmetic interpolation cannot feed back.

After `pose_ride`, retain `proposed_root` and `proposed_proxies`. Call
`find_obstruction(space, previous_root, proposed_root, previous_proxies,
world.props, proposed_proxies)`. The optional final argument covers within-tick
animation of the local parts as well as the root's translation and rotation.
The helper excludes broken and traffic RIDs before any sweep. It also filters
and searches past unlisted layer-2 colliders. It never arms, spawns or pays.

If it returns a hit, place `skater.global_transform = hit.transform` before
any activation or bail. Interpolate each actual riding part's local transform
between the captured prior/proposed poses by `hit.fraction` so `bail()` reads
the accepted physical pose, rather than the proposed end-of-tick pose. For a
prop hit retain the current mass/momentum activation formula, then call
`bail_out()` once. Remove the old nominal-radius loop entirely. Keep automatic
end-of-stairs and deliberate bail rules. R08 must see this corrected simulation
pose when `bail()` instantiates its real limbs.

The contact output is `{collider, fraction, at, normal, transform, proxy_id,
error_bound}`. `fraction` is clamped to `[0,1]`, and `at/normal` come from the
real eligible body's contact readback. Starting overlaps return fraction zero.
Root uses `transform` rather than the contact point as the riding root placement.

Translation and rotation are subdivided with `.10 m / 5°` ceilings. Midpoint
oriented casts use a conservative angular Minkowski margin to find candidates.
Only actual oriented, zero-margin overlaps can accept a refined leaf; the leaf
boundary travel is at most `.0008 m`, with total declared geometry/contact error
below `.002 m`. This avoids a discovered numerical sweep pitfall: a 0.1 mm
query margin on a tangential taxi pass shifted the claimed root contact 16 mm.
The independent test brackets first real overlap with finer actual physics
queries and rejects that earlier implementation. No speed or solver-step limit
was lowered to make it pass.

`tests/test_skating_contacts.gd` uses independent actual shape queries for clear
and inward/front taxi passes, thin high-speed hits/misses, tipped/rotated props,
excluded-first colliders, initial overlap, and both directions of a turning
grazing case whose endpoint and midpoint orientations are clear. Real route
tread raycasts separately verify the support profile. Integration still needs
the baseline near-miss's RUN/no-activation/no-limb-spawn assertions, every route
minimum/full/push descent, contact-to-bail pose placement, and existing skating,
skin, routes and traffic suites through the bounded runner. Native visual
validation remains R14's gate.
