# State, input, replay, clock and camera audit

Audit date: 2026-10-04. Scope: `scripts/main.gd`, `game_hud.gd`, `crash_camera.gd`, `sound_director.gd` and their tests. No gameplay source was edited. The findings below distinguish observed engine behavior from source risks that still need an actual play or render reproduction.

Godot version: `/opt/homebrew/bin/godot --version` returned `4.7.2.stable.official.ed1daf0bf`. Two isolated headless probes were run sequentially. They use their own nonexistent save paths under `builds/repair_audit/`, set `test_mode` before adding the game to the tree, and never read or overwrite the player's `user://records.json`. The probes record observations rather than reporting a passing regression suite. Both exited 0 without script errors; the macOS certificate-store diagnostic appeared. A native display, renderer, keyboard/window focus behavior and audio audition were not available.

Reproduce from the repository root:

```sh
/opt/homebrew/bin/godot --headless --path /Users/tyler/Documents/GitHub/stair-dismount --fixed-fps 60 --script builds/repair_audit/state_ui_probe.gd --log-file /Users/tyler/Documents/GitHub/stair-dismount/builds/repair_audit/state_ui_probe.log
/opt/homebrew/bin/godot --headless --path /Users/tyler/Documents/GitHub/stair-dismount --fixed-fps 60 --script builds/repair_audit/camera_clock_probe.gd --log-file /Users/tyler/Documents/GitHub/stair-dismount/builds/repair_audit/camera_clock_probe.log
```

Evidence: `builds/repair_audit/state_ui_probe.json`, `state_ui_probe.log`, `camera_clock_probe.json`, `camera_clock_probe.log`; the corresponding `.gd` files contain the exact fixtures.

## Ranked confirmed findings

### 1. UI-01 — HIGH — CONFIRMED: help and pause do not isolate keyboard focus

**Source:** `scripts/game_hud.gd:108-116`, `:289-313` create keyboard-focusable Buttons and mouse-blocking backdrops without moving/trapping focus. `scripts/main.gd:220` only guards the unhandled-key path. Button signals invoke `start_ready()` (`main.gd:176-179`) and `set_pose()` (`:131-136`) directly; those functions have no modal/pause guard. Menu help opens directly at `game_hud.gd:134` and H opens it at `main.gd:228-231`.

**Actual trigger and evidence:** `Input.parse_input_event()`/`Input.flush_buffered_events()` were used; no direct `_unhandled_input()` call simulated this result. Focus the menu's FILE A CLAIM button, press H, then Enter. The focus remains FILE A CLAIM beneath help; Enter transitions MENU → READY and closes help. In READY, focus pose 3 while pose 1 is selected, open H help or Esc pause, then Enter. The pose changes 0 → 2 while the help/pause remains visible and the game remains paused. The mouse backdrop successfully blocks pointer clicks but does not establish a keyboard modal.

**Smallest fix:** centralize modal opening/closing so it remembers the old focus, transfers focus into the modal, prevents Tab/Shift-Tab from reaching hidden underlying controls, and restores valid prior focus on close. Add authoritative guards to gameplay choices such as `start_ready()` and `set_pose()` so a stale GUI callback cannot bypass a modal. Keep the explicit pause-menu resume/retry/route actions available.

**Meaningful acceptance:** real dispatched keys must leave MENU and the selected pose unchanged under help/pause; Enter may operate only the focused control inside the visible modal. Walk Tab and Shift-Tab through every visible modal control and assert the actual `gui_get_focus_owner()` belongs to that modal. Close help from MENU without launching; close help from READY/RUN/CRASH/REPLAY and preserve phase, run state and charge consumption. Assert the tree pause state and game flag agree throughout. Test the actual menu HOW TO WRECK button as well as H.

**Current blind spot:** `tests/test_ui.gd:43-67` tests pointer blocking only. `tests/test_inputs.gd:72-86` verifies Space cannot launch under pause/help but does not check focused Enter, hidden button activation, pose mutation or focus trapping.

### 2. UI-02 — MEDIUM — CONFIRMED: GUI focus consumes the held slow-motion control

**Source:** `scripts/main.gd:206-210` gives only Space precedence over GUI input; Tab slow motion is implemented in `_unhandled_input()` at `:241-242`. Every HUD Button remains keyboard focusable (`game_hud.gd:108-116`), including II at `:184`.

**Actual trigger and evidence:** while RUN, focus the visible II HUD button and dispatch a held Tab. `slow_motion=false`, `time_rate=1.0`; release Tab, remove GUI focus, then dispatch the identical held Tab. `slow_motion=true`, `time_rate=0.25`. A control advertised by help (`game_hud.gd:312`) depends on whether a UI button has focus. This can arise from keyboard navigation or from using the HUD pause/resume controls.

**Smallest fix:** give the live Tab gameplay action an explicit input ownership rule, analogous to Space, handling both press and release before GUI focus navigation in RUN/CRASH. In a visible modal, retain Tab for modal navigation. Clear the held action on pause, transition and focus loss. Do not disable keyboard accessibility for all Buttons.

**Meaningful acceptance:** dispatch press, hold and release with each visible live HUD control focused and with no focus. Slow motion must engage once and return to the phase's base rate on release, including release after pause/help/phase transition. Assert no focus navigation steals the live press. Separately verify Tab navigation remains functional inside pause/help. A native focus-loss check remains necessary for OS-generated releases.

**Current blind spot:** `tests/test_game.gd:14-16` calls `_unhandled_input()` directly and bypasses GUI interception; its Tab checks at `:48-53` therefore cannot expose this. The real dispatcher suite never dispatches Tab while a control is focused.

### 3. UI-03 — MEDIUM — CONFIRMED: a camera candidate inside world geometry is accepted as clear

**Source:** `scripts/crash_camera.gd:8-14` uses a ray query with default `hit_from_inside=false`; `:20` accepts the candidate immediately when that ray reports no hit. `scripts/main.gd:573` applies this policy to the normal crash camera.

**Constructed physical reproduction:** a real `StaticBody3D` box with layer 1 was placed around the requested lens position `(5.8,3.4,-6.8)`, with the rider target outside the box. After physics frames, `choose_position()` returned that same position and production `clear_view()` returned true. An independently configured ray with `hit_from_inside=true` detected the solid at the ray origin. This proves the overlap case in Godot's real physics space; it does not establish how often a normal run enters that state.

**Actual gameplay trigger to check:** cargo or a wrecked prop contains the desired camera position. The lens can be selected inside the prop and render its interior or lose the rider view.

**Smallest fix:** treat initial lens overlap as obstruction using an inside-aware query or a small lens-volume overlap check before the line-of-sight test. Apply the same safety contract to the final interpolated/clamped lens, not just the desired endpoint.

**Meaningful acceptance:** use independent `intersect_point()` or shape-overlap queries to prove the final lens is outside solid world/prop geometry. Include an initial-overlap fixture, an ordinary cart in the sight line, a tall obstruction, a moving obstruction and an interpolation path crossing geometry. Check the actual camera position, rather than calling production `clear_view()` as the only oracle. Keep rider-layer exclusion.

**Current blind spot:** `tests/test_camera.gd:33-61` puts blockers between candidate and target but never around the candidate. It repeatedly validates the chosen point using the same `clear_view()` function, so a shared ray-policy defect passes both chooser and oracle. It also does not exercise `main.gd`'s smoothing/clamping.

### 4. UI-04 — MEDIUM — CONFIRMED: replay advertises a camera control that has no playback effect

**Source:** `scripts/main.gd:227` increments `camera_style` on C in every phase. During replay, `:522` restores the recorded camera transform each frame and `:526` returns before `update_camera()` at `:527`. `scripts/game_hud.gd:397-398` nevertheless advertises `R retry / C camera` in replay.

**Actual trigger and evidence:** record a short actual physics crash, file it, start replay, evaluate the same playback timestamp, dispatch C through the real event dispatcher, and evaluate that timestamp again. `camera_style` changes 0 → 1 but the camera transform remains identical. This is an input/transform observation, not a visual claim.

**Smallest fix:** define the replay contract explicitly. If replay supports view changes, select recorded-camera mode or an actual alternate view computed from playback actors, and do not overwrite the alternate view with the recorded transform. If only a recorded view is intended, remove the replay C hint and reject C during replay so it does not silently change a later run's view. The existing advertised behavior favors implementing a functioning view change.

**Meaningful acceptance:** at a fixed replay time, actual C dispatch must visibly alter the camera's projected rider/scene geometry or camera transform for supported alternate views, while actor transforms, score, fund, damage and boosts remain unchanged. Verify return to results restores the agreed camera state and that retry does not inherit an unintended replay-only selection.

**Current blind spot:** `tests/test_ui.gd:113` checks the replay hint text, not the offered action. Gameplay replay tests assert phase/accounting but not the C control.

### 5. UI-05 — LOW — CONFIRMED: the replay does not record or restore its lens FOV

**Source:** `scripts/main.gd:476-485` records the camera transform but no FOV. Replay applies only that transform at `:522`; live/result camera code changes FOV at `:580`.

**Actual trigger and evidence:** the final recorded crash frame in the focused probe had `camera.fov=52.367485`; after waiting on results the FOV reached `52.000137`. Replay retained the results FOV and every snapshot lacked a lens field. Earlier moving-run/crash frames can have a larger mismatch, but that magnitude was not measured in this probe. Identical camera transforms with different FOV produce different framing.

**Smallest fix:** record FOV (and any other mutable projection state introduced later), interpolate it with the recorded transform in recorded-camera mode, and restore the chosen results camera state on exit.

**Meaningful acceptance:** record frames with distinct nondefault FOV values; compare an independent known world point's screen projection during recorded-camera playback with its original capture at the same timestamp. Test repeated replay after a long results wait, not only immediate replay. Replay must preserve accounting and final injury/traffic states.

**Current blind spot:** no replay suite checks lens/projection state. `tests/test_camera.gd` only tests a position helper.

### 6. UI-06 — LOW — CONFIRMED: replay assumes a fixed spacing that differs from its captured times

**Source:** `scripts/main.gd:327-329` discards accumulator remainder (`record_clock=0`) whenever a sample is due. `:342` clears frames at bail without resetting that accumulator or capturing an explicit initial frame. Snapshots at `:485` have no timestamp. Playback at `:502-516` assigns them exactly 0.05 seconds apart. `finish_run()` also appends a final frame at `:453` even if it is less than 0.05 seconds after the prior sample.

**Controlled runtime reproduction:** the isolated probe froze actors and disabled automatic main processing, then advanced the production `_physics_process()` with the project's 90 Hz delta at several scales. This is a constructed clock test, not a full-run timing measurement. At 0.55 the first samples were `0.055,0.110,0.165,0.220,0.275` simulated seconds; at 0.25 they were `0.052778,0.105556,0.158333,0.211111,0.263889`; at 0.18 they were `0.050,0.100,0.150,0.200,0.250`. Playback assigns those samples `0,0.05,0.10,0.15,0.20`. Thus one recording can compress different portions by different amounts, and the final shortened interval is replayed as a full interval.

**Smallest fix:** store monotonic elapsed simulation time on every sample; reset the recorder at bail and capture the initial state. Retain accumulator remainder when scheduling subsequent captures. Locate/interpolate playback using stored sample times, including the exact final timestamp. Do not invent intermediate physics transforms solely to make timestamps appear regular.

**Meaningful acceptance:** use an independent elapsed simulation-time counter and a known moving actor. Cover 90 Hz at 0.55/0.25/0.18, transitions between those rates, irregular render rates, a final frame recorded between normal samples, and repeat attempts with different run-up lengths. At an independently selected timestamp, playback position and duration should match the recorded trajectory within a stated interpolation tolerance. Preserve bank and final state across two complete playbacks.

**Current blind spot:** `tests/test_playability.gd:106-107` calculates its expected frame using the production assumption `replay_clock/.05`, rather than a recorded-time oracle. `tests/test_game.gd:68-75` proves replay runs and preserves score but not duration or alignment.

## Risks requiring additional reproduction

### 7. UI-07 — MEDIUM — NEEDS_REPRODUCTION: the final floor clamp changes camera position after aiming

**Source:** `scripts/main.gd:579` calls `look_at()` before `:581-582` clamps the camera's height to the stair surface. A position mutation after aiming invalidates the computed target direction. A constructed case beginning below the floor confirmed a 71.643° direction error after `update_camera(0.0)`. That starting position was injected; this magnitude was not observed in a normal run.

**Likely trigger:** the interpolated camera crosses a higher stair surface while the target tumbles back behind a riser, or alternate camera styles have a desired point beneath terrain. The surface clamp can then shift the lens after orientation was calculated.

**Smallest correction and gate:** finalize all lens-position safety adjustments before `look_at()`. Trace real runs, backwards/uphill relaunches and every camera style. When a clamp occurs, independently compare the camera forward vector with the selected target direction and check the resulting screen projection. Promote to a normal-play confirmed defect only when this path is recorded in gameplay. This belongs with UI-03's final-position camera safety work.

### 8. UI-08 — MEDIUM — NEEDS_REPRODUCTION: physics-recorded camera transforms and render-driven impact clocks share no explicit boundary

**Source:** actor/camera snapshots are taken in `_physics_process()` (`main.gd:327-329`, `:483-485`), but the camera is moved in `_process()` (`:527`, `:540-582`). Impact expiry and the 34-second presentation deadline are also advanced from render callbacks (`:496-500`) and read by physics settlement (`:325`). There is no captured frame time or explicit camera sampling time. A physics sample may pair new actor state with a camera transform from an earlier render update; impact changes in physics can also alter `Engine.time_scale` before render computes `real_delta`.

**Gate before proposing a larger redesign:** run the same independent action schedule at multiple actual render rates and physics/render ratios, record simulation time, monotonic wall time, scale transitions, camera sample age and settlement reason. Fixed-fps frame-clock tests alone are not native wall-time/FPS evidence. A repair should assign explicit clocks and sampling times only where a measurable mismatch is found; do not replace all timing systems speculatively. UI-06's timestamps should be designed to accommodate this gate.

### 9. UI-09 — MEDIUM — NEEDS_REPRODUCTION: replay can lose actors or carry nonrecorded effects

**Source:** props can `queue_free()` below y=-12 (`scripts/crash_prop.gd:56-57`); recording substitutes identity transforms for invalid actors (`main.gd:483-484`) and replay skips those actors (`:517-519`), so historical frames cannot reconstruct a deleted prop. Particle updates are skipped by the replay early return (`:526`, `:529`), particles are not part of snapshots, and replay start does not hide/reset them (`:487-492`). Headless/test mode suppresses particle creation (`:601-602`), so this boundary is absent from existing automated runs.

**Gate and smallest conditional fix:** reproduce a real crash where a credited prop exits below the cleanup bound; check early playback against that actor's initial recorded presence. For particles, inspect native replay of a recent explosive finish and a long-wait finish. If deletion is reachable, retain frozen replay actors until the replay is discarded or reconstruct them from stable IDs and recorded visibility; do not silently substitute identity. If residual effects are visible, hide/reset nonrecorded particles at replay entry and restore the final presentation contract on exit. Preserve final score, traffic and injury state through complete, paused and repeated replay.

### 10. UI-10 — MEDIUM — NEEDS_REPRODUCTION: scaled-window layout, native focus loss and live audio remain unverified

**Source and limits:** `project.godot:13-18` defines a 1440×900 canvas with a 1280×800 default window and keep-aspect canvas stretching. `tests/test_ui.gd:8-17` injects viewport-local pointer coordinates; `:33` checks literal 1440×900 bounds. This does not prove physical-window coordinate mapping, display scaling, letterboxing, minimal readable text or focus behavior. There is no focus-loss handling in main; native release behavior for held Space/Tab/W/A/D remains unobserved. `sound_director.gd:18` skips player allocation headlessly; `tests/test_audio.gd:45-52` therefore cannot validate real loop pause/resume or pooled one-shots.

**Acceptance gate:** native checks at 1280×800, 1920×1080, a smaller supported size and a nonmatching aspect ratio must inspect MENU/READY/CRASH/RESULTS/help/pause, keyboard focus, physical pointer hits and clipped/overlapping labels. Test held gameplay keys while the window loses/regains focus, including a release while inactive. Audition rolling/traffic loops through pause/help/results/replay and mute/unmute with an actual output device. Record native screenshots/video and runtime facts separately from Blender reconstructions. No scaled-layout or audible defect is claimed before those observations.

## What should remain intact

The existing replay finalization explicitly restores final actor transforms, traffic snapshots and limb injuries (`main.gd:507-514`). This audit did not demonstrate a new payout or final-damage restoration failure. Repair acceptance should continue to compare the entire final state with an independent pre-replay capture: score/fund, each valid actor transform and freeze state, traffic damage/visibility/driver/wheel/light state, all eleven limb severities, one-use breaker count, phase and pause flags. Repeated playback, pause/help during replay, completion and retry must not introduce gameplay impulses or a second bank operation. Avoid weakening those protections while adding timestamps, camera modes or focus ownership.
