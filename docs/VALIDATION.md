# Validation record

The source and bundled game were tested with the installed official **Godot 4.7.2** on macOS. Original models and validation renders were produced through **Blender MCP's background executor**, using Blender 5.2.2 and Cycles on the CPU.

## Automated checks

`./tools/test.sh` passes **491 checks** across five suites:

| Suite | Checks | Coverage |
| --- | ---: | --- |
| Rules | 138 | Score ledger, unique prop scoring, rider thresholds and caps, combo timing and multiplier ceiling, medal boundaries, all staircase heights, score formatting |
| Gameplay | 79 | Three full runs, charged launch, acceleration, real obstacle collisions, eleven-limb ragdoll plus board, ten joints, three finite boosts, pause, slow motion, ground return, transform replay and replay completion, saved records |
| Route variations | 41 | Nine physical runs with different starting lanes; each completes and produces a multi-object chain, different lines yield different results, manual bail and keyboard retry |
| Interface | 201 | Actual Godot font metrics, text fitting, viewport bounds, keyboard focus on buttons, three route screens, help, pause, and large-score results |
| Audio | 32 | Eight imported audio streams have sample data and duration; music and rolling ambience loop forward, one-shot effects do not loop |

The tests exercise actual Godot rigid bodies and collisions. They assert behavior and invariants rather than exact, brittle physics scores. Tests use isolated record files. The shell runner fails on script errors, failed assertions, and resource leaks. Headless audio playback is disabled because there is no audio device; the imported sample resources and loop settings are verified separately.

The package checker launches the **bundled app executable and game PCK**, rather than the working source tree, and completes autoplay runs in all three routes. Each requires at least four physically wrecked objects and a score above 3,000. It also checks the app's sealed ad-hoc signature:

```sh
./tools/check_package.sh
```

## Visual inspection

The native computer-use service could not start, and this environment had no available WindowServer. Godot's native macOS window could not be opened. Consequently, live mouse/keyboard play, native-renderer appearance, audible playback, and rendered frame rate have not been manually verified in this session.

The fallback exports the instantiated Godot meshes, material colors, camera matrices, and Control rectangles and font sizes, then renders them with Blender. Static decoration uses MultiMesh batching; its CPU transform data is retained for inspection because Godot's dummy headless renderer does not return the GPU instance transforms. Blender uses a substitute font and different lighting and color processing. These images are **Blender validation previews**, not native Godot screenshots.

Inspected previews:

- [Original Blender asset kit](screenshots/blender_assets.png)
- [Civic Cascade route menu](screenshots/level_1_menu_validation.png)
- [Night Market launch view](screenshots/level_2_ready_validation.png)
- [Port Authority route menu](screenshots/level_3_menu_validation.png)
- [Civic Cascade crash](screenshots/level_1_crash_validation.png)
- [Damage report](screenshots/level_1_results_validation.png)

Visual inspection led to moving foreground buildings and crane crossbeams away from the route preview, making the launch platform and stairs solid to the foundation, correcting batch-transform export, and capping blast energy so the crash camera follows action near the arena. A tall, visible end-of-course backstop catches the rider and wrecks. Static windows, paint, stalls, and container details are grouped by material to reduce draw calls.

## Deliverable

`builds/StairWreck.app` is a universal Intel / Apple Silicon macOS app with the game pack, custom app icon, and engine licensing notices. It uses the installed official full Godot binary as its runtime, so it has a larger download size than a dedicated release-template export. The project source, editable Blender asset studio, asset generator, audio generator, packaging tools, and tests are included in the workspace. The distributable app archive is `builds/StairWreck-macOS.zip`.
