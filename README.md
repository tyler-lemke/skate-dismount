# STAIR // WRECK — The Treatment Fund

A three-level skateboard crash game in Godot, with original Blender models and audio. Build speed, choreograph a ragdoll fall, and connect dominoes, carts, cargo towers, explosive drums, and moving traffic. Your score is an **insurance payout**. Mom needs cancer treatment; your absurd fictional stunt policy is your last shot at funding it.

**Play the repaired Mac build:** [download the 3.1 candidate](builds/candidates/f6434bb1219b2b27c0638961f6b00b13d2deb1ed157271fcba7d05f455bfe4bb-20261005T052800.141632Z-ab4472e9/StairWreck-macOS.zip), extract it and open `StairWreck.app`. The universal Intel/Apple Silicon application includes its engine; Godot and Blender are not required to play. Declared minimum: macOS11. See [exact package verification and limits](docs/repair/evidence/R13.md).

To run current workspace source with Godot4.7.2 installed, double-click `Play.command`. The original `builds/StairWreck.app` and `builds/StairWreck-macOS.zip` remain historicalv3.0 artifacts.

![The treatment fund and Civic route](docs/screenshots/level_1_menu_validation.png)

These are historical v3.0 Blender renders of actual Godot runtime geometry and interface bounds. Native screenshots of the repair candidate remain unavailable. See [current repair evidence](docs/repair/evidence/R12.md) and [historical validation](docs/VALIDATION.md).

## Make the next landing count

Before launching, choose your lane, a **Tuck, Starfish, or Torpedo** pose, and a ridiculous hat. The poses have different silhouettes, joint anchors, and angular momentum. Civic starts on its domino line so the first launch demonstrates a proper cascade.

Hold Space to charge, then release. W adds speed through timed rear-foot kicks on the run-up; coasting has gentle drag. A/D carves a forward arc, with the rider leaning and facing the board's travel. Hitting an obstacle or pressing Space throws the rider into eleven connected physical body parts, alongside a separate skateboard. The continuous, weighted character mesh follows those parts, preserving its shape at bail and through replay.

Crashes automatically run at **55% speed**. A major body impact briefly drops to 18%, with a global cooldown to keep the action moving. Bruises and glowing injury markers persist on the struck limbs; the anatomy diagram shows **OK, Bruised, Strained, or Fractured**. Receipts explain each awarded claim. Resting contacts and skateboard impacts cannot earn injury money.

A/D aims your crashbreaker; S aims uphill. A dotted arc previews its direction. Press Shift to spend **one charge per attempt**. It relaunches the rider and can shove nearby objects inside a short, unobstructed cone. It never directly pays or ignites a drum. A good second landing connects another cluster; a poorly timed relaunch can miss it. Drums have visible burning fuses and smaller blasts, so their handoffs unfold in sequence.

For the traffic challenge, select the marked far-left line before launch, carry speed down the staircase, and bail near the final steps. Save Shift for the landing by the road. Cars drive and brake using bounded physical forces, then relinquish their motors after an impact. Wrecks retain their momentum and can push another car into a third. Each car pays once; the claim feed shows `RIDER → CAR A`, `CAR A → CAR B`, and `CAR B → CAR C` when those actual collisions occur. There is no traffic respawn or automatic cascade reward.

| Control | Action |
| --- | --- |
| A / D or ← / → | Choose lane, steer, apply aftertouch, aim crashbreaker |
| Hold / release Space | Charge / launch |
| W or ↑ on the run-up | Kick for speed |
| Space while riding | Bail |
| 1 / 2 / 3 before launch | Tuck / Starfish / Torpedo; buttons also work |
| F before launch | Clockwork crown / paper crane / traffic cone |
| Shift after bailing | Fire aimed crashbreaker |
| S or ↓ after bailing | Aim uphill |
| Hold Tab | Extra slow motion |
| Enter during crash | File the current claim immediately |
| C | Chase / side / overhead camera |
| R | Immediate retry |
| V on results | Watch the recorded crash and injury progression |
| Esc | Pause / resume; routes from results |
| H | Controls guide |
| M | Toggle sound |

Claims settle after the action rests, after 16 simulated crash seconds, or after a maximum of 34 presentation seconds. You can file early with Enter. Replay cannot add payout. Fresh wrecks build a multiplier up to ×8; each object pays once. Each anatomical region has a finite injury settlement.

## Three different crash puzzles

| Route | Left line | Center line | Right line |
| --- | --- | --- | --- |
| Civic Cascade — 26 steps | Domino run into cargo | Body impacts and carts | Heavy taxi into stacked crates |
| Night Market — 32 steps | Cart slalom | Cargo drop into drum supply | Domino fuse run |
| Port Authority — 38 steps | Cargo-tower collapse | Domino-fed drum avalanche | Heavy taxi through terminal cargo |

At the foot of the stairs, Civic has staggered passing lanes, Night Market has a turning taxi lane, and Port Authority has a diagonal merge through a terminal gate. Launch starts each finite traffic encounter, so waiting to select a line does not miss it.

The **$600,000 treatment fund** accumulates the best claim from each route. Better retries bank only the improvement; weaker retries never reduce savings. The game shows the current claim's potential contribution before settlement. Funding treatment produces a story ending, and all routes remain available for mastery. Mom's notes change by chapter. Cancer is the sincere stake; the insurer and exaggerated crashes supply the comedy.

Preferences, hats, and claim records persist locally. Pending claims remain distinct from secured funds if a save fails; the results screen offers Retry Save and protected-profile recovery. Old version-1 arcade records are retained separately and do not pre-fund the new story.

## Design and verification

The redesign follows research into [Porrasturvat's physics tuning](https://www.flipcode.com/archives/08-06-2003.shtml), [Stair Dismount's impact spectacle](https://apps.apple.com/us/app/stair-dismount/id326469137), and [Burnout CRASH's strategic high-value targets and pinball inspiration](https://news.ea.com/press-releases/press-releases-details/2011/EA-and-Criterion-Games-Announce-Burnout-CRASH/default.aspx). See [research and designer competition](docs/DESIGN_RESEARCH.md).

All 31 mandatory runtime suites pass, with 10,807 checks and zero failures. Checks exercise real Godot rigid bodies, event dispatch, collisions, articulated poses, damage presentation, replay, input focus, progression, save recovery, UI geometry, and audio resources. A fresh keys-only campaign reaches $623,887 without injected money or physical impulses. These measurements do **not** establish human enjoyment. See [repair notes](docs/repair/REPAIR_NOTES.md), [current results](docs/repair/evidence/R12.md) and [ordinary-control campaign](docs/repair/evidence/R12_good_play.md).

```sh
./tools/test.sh
```

The default check includes strict editor import. This environment denies Godot's user/editor snapshot writes, so its failed import is retained separately. `GODOT_BIN=/opt/homebrew/bin/godot ./tools/test.sh --runtime-only` explicitly tests the runtime against checked existing import-cache bytes. Each run writes its own result under `builds/test_runs/`; unexpected errors and leaks fail the run even if a test prints a passing summary.

The candidate builder takes a complete stable runtime result and the actual import evidence. See [packaging method and commands](docs/repair/evidence/R13-builder.md). The historical `build_macos.sh` and `check_package.sh` target the old public bundle; they are not the repair candidate pipeline.

Open `project.godot` in Godot to develop. Tested with Godot 4.7.2 and the Compatibility renderer. Packaged candidates include the official universal Godot binary and a runtime PCK; downloads are larger than dedicated release-template exports. Native rendered performance and audibility remain unverified because the desktop service fails to start.

The editable studios are `blender/stair_wreck_assets.blend` and `blender/hero.blend`, with 19 GLB exports. `blender/build_assets.py` regenerates the core kit; `blender/build_hats.py` adds the designer hats; `blender/build_hero_assets.py` creates the weighted rider, detailed board, and taxi with rotating wheel pivots and a local dent morph. They ran through **Blender MCP in background mode**. `tools/generate_audio.py` and `tools/generate_traffic_audio.py` synthesize all 15 audio assets without external samples. `tests/render_snapshot.gd` exports posed runtime scene geometry and UI bounds for `blender/render_validation.py`.

Game code, models, and audio are MIT licensed. Engine and third-party notices are included in `docs/GODOT_LICENSE.txt` and the app.
