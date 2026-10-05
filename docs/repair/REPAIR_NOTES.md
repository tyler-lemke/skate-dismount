# 3.1 repair candidate

The three original routes, poses, hats, limb damage, $600,000 treatment fund and
one crashbreaker per attempt are retained. These repairs address measured bugs
in the existing game.

- Skating follows the actual tread tops. Obstacle detection sweeps the same
  oriented shapes used by the physical rider and rewinds to the first contact.
- Bail preserves the complete weighted character pose. Fitted torso and forearm
  collision shapes, selective self-contact, neck limits and consistent assembly
  energy limits reduce measured stretching and limb crossings.
- Traffic uses two moving, opposing drivers and a waiting middle car. Real
  collisions can transfer damage through all three cars. A continuous road hull
  removes the false floor-edge contacts that stopped healthy drivers.
- Port's heavy taxi has a four-domino relay into the existing cargo and drums.
  The first relay catches a glancing strike so lane choice changes the handoff.
- Slow motion, impact effects and cameras use explicit simulation/presentation
  clocks. Cameras test their near-lens clearance against actual geometry.
- Replay presents an immutable timestamped copy of the crash, historical limb
  damage and receipts. Playback cannot alter live actors, causes or funding.
- Pause, help and focus loss own input consistently. Held charge and steering
  cannot leak through a modal window or accidentally relaunch after a reset.
- Claim records use checked writes, explicit retry and protected recovery.
  Pending claims remain distinct from secured money; a failed save cannot show
  a newly funded ending. Legacy scores do not pre-fund treatment.
- UI layout and long claim/recovery messages have automated bounds checks across
  supported window sizes. Pause/replay sound policies retain music and suspend
  or stop gameplay sounds as appropriate.

The source regression gate contains 31 suites. Its current result and the exact
packaged candidate are recorded in the repair evidence. Tests exercise real
Godot bodies, input dispatch, records, replay ownership and resource teardown;
they do not measure human enjoyment.

Native screenshots, motion, shader appearance, audibility and display scaling
remain unverified because the desktop automation service fails to start. Blender
renders are explicitly supplementary reconstructions or geometry diagnostics,
not native game screenshots. The candidate uses checked existing import-cache
bytes; the sandbox's failed fresh editor import is retained separately.
