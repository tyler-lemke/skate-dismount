# R07 camera helper preparation

This evidence covers `scripts/crash_camera.gd` and the independent geometry suite.
It does not close R07: production render integration, R04 support handoff, three-route
traces, and native framing/corner clipping remain separate acceptance work.

The previous helper is preserved at `builds/repair_work/R07/crash_camera.before.gd`.
The original `builds/repair_audit/camera_clock_probe.gd` and its logs remain baseline evidence.

## Caller contract

Create one `CrashCamera` instance per presentation camera. Call `reset()` on route
replacement, retry, bail discontinuity, or replay mode change. A changed view mode also
resets focus and safety history. The helper captures no camera, skater, world, or props.

`update(phase, view_mode, focus, desired, presentation_delta, query_context,
current_transform, current_fov=52.0, target_fov=52.0, shake=Vector3.ZERO)` returns:

- `transform`: final corrected lens and orientation, calculated in that order.
- `fov`: finite, bounded FOV, smoothed with active presentation wall seconds.
- `target`: the smoothed focus plus bounded target shake, or a finite forward fallback.
- `safe`: whether the final lens has a verified geometry and floor clearance.
- `diagnostic`: phase, view mode, lens radius, floor clearance/correction, initial overlap
  or floor violation, path clipping, reset, candidate index/count, fallback reason,
  final sight clearance, degenerate aim, and invalid input.

`query_context` provides `space` (`PhysicsDirectSpaceState3D`), `mask` (default 3),
`exclude` (RID array), and `floor_height` (Callable taking a Vector3 and returning the
support height at that position). `floor_y` is an explicit constant-height fallback.
The production caller must supply R04's accepted support query rather than treat this
flat-floor fallback as a substitute for that handoff. Replay can supply its own physics
space/proxies and focus, without consulting the frozen live rider or final hulls.

The .18 m sphere is a lens collision envelope. It does not establish that every camera
near-plane corner is clear. Interpolated movement uses a sphere sweep and a .002 m
margin before collision. Shake affects the target only, with maximum magnitude .6 m.
Same-side raises and shoulder adjustments precede a mirrored candidate. All candidates
are bounded near the intended composition. Saved safety is rechecked against current
geometry and support. If no clear sight line exists, a verified lens may return a
diagnosed occluded fallback. A completely enclosed candidate set returns `safe=false`
with `no_verified_position`; the caller must not publish that as a verified placement.

The old static `choose_position` and `clear_view` signatures remain available. Final
displayed-lens guarantees require the instance API, since a later independent lerp or
floor correction could invalidate the static endpoint answer.

## Actual validation

Godot 4.7.2 Compatibility headless, fixed FPS 60:

```sh
python3 tools/run_bounded.py --timeout-seconds 180 \
  --expected-summary CAMERA_GEOMETRY \
  --log builds/repair_work/R07/geometry_v1/output.log -- \
  /opt/homebrew/bin/godot --headless --path "$PWD" --fixed-fps 60 \
  --script res://tests/test_camera_geometry.gd \
  --log-file "$PWD/builds/repair_work/R07/geometry_v1/engine.log" -- \
  --test-mode --records-path="$PWD/builds/repair_work/R07/geometry_v1/records.json"
```

Result: `CAMERA_GEOMETRY: 122 checks, 0 failures`; bounded runner exit 0.
Original output, engine log, and structured result are retained in that directory.
The only ignored diagnostic was the exact adjacent macOS certificate condition/location
pair already classified by R01; no script error, unexpected engine error, or leak appeared.

The suite constructs independent point, .18 m shape, ray, swept-shape, and sampled-path
queries against real colliders. It independently measures final orientation from the
returned basis and corrected target, and floor height from a separate support ray.
It covers default chase, cart, tall tower, inside-origin solid, a blocked intermediate
path with two clear endpoints, a solid moving over saved safety, all three view styles,
caller-supplied traffic focus, bounded shake, steady-state movement, degenerate aim,
rider-layer exclusion, and a completely enclosed negative fixture.

Measured stationary aim errors were 0 degrees in these constructed fixtures. The
inside-origin lens moved to `(5.8,6,-6.8)`. The blocked path stopped at
`(-.688815,3,-7)` before the wall. These are helper geometry results, not measurements
of normal-play occurrence or evidence of native presentation quality.
