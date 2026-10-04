# Persistence, validation, and release audit

Audit date: 2026-10-04. Scope: records loading/migration/saving, local test orchestration, macOS packaging, and what the existing evidence can establish. This is planning evidence; gameplay, test suites, launchers, and build scripts were not changed. The full suite was not rerun and the app was not rebuilt. Controlled probes were added only under `builds/repair_audit/` and used project-local record filenames; they did not write `user://records.json`.

The parent's preceding completed run reports 1,780 passing assertions. That result and the saved report are compatible with the defects below: current persistence checks cover valid writable round trips, while failure and malformed-input paths are absent. Passing headless assertions cannot resolve the reported human experience by themselves.

## Evidence classification

- **CONFIRMED** means reproduced against the existing Godot 4.7.2 code or established directly by local control flow. A missing verification gate is labeled as a gate defect, not as proof that the current artifact is broken.
- **NEEDS_REPRODUCTION** means a plausible trigger or release condition was not exercised. It must remain an investigation/acceptance item rather than be presented as an observed runtime bug.
- Headless probes emitted the already documented macOS certificate-store diagnostic. Any script error listed below is a separate diagnostic and is explicitly identified.

## Isolated reproduction commands

Run from the project root. These scripts already exist under `builds/repair_audit/`; they create/replace only their named synthetic fixtures. They do not run or rewrite the normal test suites. The settlement probe does not pass `--test-mode`: it supplies its isolated save path before the scene starts. The final startup probe deliberately passes it to demonstrate the shared **test** path override without writing that shared file.

```sh
for mode in coercion invalid_element future_version malformed open_failure; do
  /opt/homebrew/bin/godot --headless --path "$PWD" \
    --script res://builds/repair_audit/records_probe.gd \
    --log-file "$PWD/builds/repair_audit/records_$mode.log" -- "--probe=$mode"
done
/opt/homebrew/bin/godot --headless --path "$PWD" \
  --script res://builds/repair_audit/settlement_probe.gd \
  --log-file "$PWD/builds/repair_audit/settlement.log"
/opt/homebrew/bin/godot --headless --path "$PWD" \
  --script res://builds/repair_audit/startup_path_probe.gd \
  --log-file "$PWD/builds/repair_audit/startup_path.log" -- --test-mode
```

## V01 — CONFIRMED, high: unsuccessful saving still reports money as secured

**Exact code:** `scripts/main.gd:124–126` opens the destination for writing and silently does nothing when opening fails. The function returns `void`, never checks write errors, and cannot communicate a result. `scripts/main.gd:459–465` updates best scores and `last_money_secured`, calls that function, then proceeds to the normal results display. `scripts/game_hud.gd:373` says the contribution is “secured.” Preference callers at `scripts/main.gd:201–204` and `scripts/main.gd:223` have the same silent-failure contract.

**Trigger:** a record destination cannot be opened, for example because its directory is missing or its parent is unwritable. For actual `user://` failure, permissions or storage problems are candidate triggers; this audit did not alter the real user directory.

**Reproduction:** `builds/repair_audit/records_probe.gd` with `--probe=open_failure` returned `exists=false`, `open_error=7`, and `funds_in_memory=520000`. `builds/repair_audit/settlement_probe.gd` exercised the existing scene's `finish_run()` using a controlled bookkeeping fixture and a missing project-local directory. It reported `phase=4`, `memory_funds=200000`, `money_secured=200000`, and `disk_exists=false`. This second probe validates settlement/save/UI control flow, not the provenance of a physical claim.

**Existing test blind spot:** `tests/test_inputs.gd:105–133`, `tests/test_game.gd:87–89`, and `tests/test_playability.gd:116–119` use existing writable directories. None checks a failed open/write, pending durability, or relaunch after failed settlement.

**Smallest fix:** introduce a structured save result and keep in-memory best claims available for retry. Distinguish the claim earned this session from a successful durable save in the UI. Surface one actionable save failure and retry after the storage condition resolves; do not deduct the earned claim merely because persistence failed. Check serialization, file open, store/flush/close result, and replacement operations where applicable. Avoid making “secured” synonymous with a void function returning.

**Meaningful acceptance:** an isolated unwritable/missing destination produces an explicit failure state; the previous durable record remains intact; the new claim remains available in memory; resolving the destination and retrying writes it exactly once; a fresh process reloads that claim. Test preference failures as well as settlement failures. Do not use chmod alone as the portable oracle because root/admin execution may bypass it; the nonexistent-parent case is a deterministic open-failure fixture. Write-stage failure needs its own controlled mechanism.

## V02 — CONFIRMED, high: malformed field types cause loader errors and partially applied state

**Exact code:** `scripts/main.gd:111–122` checks the top-level dictionary and score-array lengths, then immediately casts unvalidated values with `int()` and `bool()`. It mutates live arrays as it proceeds rather than committing one validated record.

**Triggers and reproduction:**

- `{"version":2,"best_scores":[123,{},456],"muted":true}` caused `SCRIPT ERROR: Invalid call. Nonexistent 'int' constructor.` at `scripts/main.gd:116`. The loader returned with `best_scores=[123,0,0]` and `muted=false`, proving a partial update.
- `{"version":2,"best_scores":["120000",true,12.9],"muted":"false","hat":"2"}` accepted the score coercions as `[120000,1,12]`, then caused `SCRIPT ERROR: Invalid call. Nonexistent 'bool' constructor.` at `scripts/main.gd:121`. Hat application did not occur.

Evidence: `builds/repair_audit/records_invalid_element.log`, `records_coercion.log`, and `records_probe.gd`. Both probe processes exited zero despite the script errors; this is why the runner's script-error checks matter.

**Existing test blind spot:** valid integer arrays, a Boolean mute value, and the normal hat selection are used in `tests/test_inputs.gd:105–123`. Negative values, bounds, element dictionaries/nulls/strings/Booleans/fractions, malformed version fields, and malformed preference types are not checked there.

**Smallest fix:** validate the complete supported schema into temporary typed state, including the version and every array element. Decide explicitly which numeric values the JSON parser legitimately represents and reject fractional/nonfinite/out-of-range values rather than coercing unrelated types. Commit the entire validated record only after validation succeeds. Preserve invalid input for recovery and communicate the reason without a script error.

**Meaningful acceptance:** a table of malformed fields produces zero script errors and no partial state updates. Valid v1/v2 fixtures still produce the existing migration results. Test first, middle, and last invalid score entries so a partially applied prefix cannot pass. The expected values must be explicit fixture values, not generated by calling the same loader/conversion helper under test.

## V03 — CONFIRMED, high: corrupted records are silently replaced with a zeroed record

**Exact code:** `scripts/main.gd:111–112` returns after failed JSON parsing without distinguishing corruption from a first run. Any later preference save at `scripts/main.gd:202` or `scripts/main.gd:223`, or successful new best at `scripts/main.gd:463`, writes the default/partial current state over the same path via `scripts/main.gd:125`.

**Trigger:** truncated or otherwise invalid JSON at startup, followed by an ordinary mute/hat change or new claim.

**Reproduction:** the isolated malformed fixture `{"version":2,"best_scores":[100,200` produced the parser diagnostic at `scripts/main.gd:111`; a normal save then replaced it with `{"best_scores":[0,0,0],"hat":0,"legacy_scores":[0,0,0],"muted":true,"version":2}`. See `builds/repair_audit/records_malformed.log`.

**Existing test blind spot:** there is no corrupted-JSON fixture, last-known-good fallback, preserved-original assertion, or startup recovery path in the persistence checks cited for V01.

**Smallest fix:** distinguish missing, unreadable, invalid, unsupported, recovered, and loaded records. Preserve an invalid original or a recoverable backup before allowing replacement. Use a validated last-known-good backup when available and tell the player whether the session started without saved progress. New preferences must not silently erase the sole recoverable input.

**Meaningful acceptance:** malformed primary plus valid backup restores the backup; malformed primary without backup remains preserved and produces an explicit recovery state; changing mute/hat cannot destroy either recovery input; missing file remains a normal new-game path. A clean restart after successful recovery verifies the restored score and preferences from disk.

## V04 — CONFIRMED code defect; interruption trigger NEEDS_REPRODUCTION: saves overwrite the sole file in place

**Exact code:** `scripts/main.gd:125–126` opens the only record for `FileAccess.WRITE` and stores directly into it. There is no sibling temporary file, validated replacement, or backup anywhere in the saving path.

**Trigger to reproduce:** process termination, storage exhaustion, or write failure between opening/truncating and completing the new JSON. No process-kill or power-loss experiment was performed. This audit confirms the absence of a protection mechanism, not an observed instance of physical disk corruption.

**Existing test blind spot:** valid same-process write/read round trips cannot establish resilience to interruption. They cannot detect loss of the old file before the replacement is complete.

**Smallest fix:** write and validate a sibling temporary record, then replace according to the available platform's checked file operations while retaining a last-known-good record. Define what happens when each operation fails and on next startup. Confirm the actual Godot/filesystem replacement guarantees before promising atomicity; a rename sequence that first deletes the previous file recreates the loss window.

**Meaningful acceptance:** controlled failures before temp creation, after partial temp write, after complete temp write, and during replacement each leave a recoverable complete record. Fresh-process startup chooses a valid committed record/backup deterministically and never claims that an uncommitted temporary score is durable. These are correctness cases, not generic requirements for an extensive storage framework.

## V05 — CONFIRMED, medium: unknown future schemas are accepted and downgraded

**Exact code:** `scripts/main.gd:116` treats every numeric version `>=2` as the current schema. `scripts/main.gd:126` always writes version 2 and only five fields.

**Trigger:** opening a newer save with this older game, then toggling a preference or filing a claim.

**Reproduction:** a version-99 isolated fixture with `unknown_future_field` loaded current scores and then saved as version 2 with that extra field removed. See `builds/repair_audit/records_future_version.log`.

**Existing test blind spot:** `tests/test_inputs.gd:105–133` exercises only versions 1 and 2.

**Smallest fix:** recognize exactly the supported schema versions and migration paths. Unknown higher versions enter a preserved unsupported-save state rather than being rewritten by the old client. Do not silently merge arbitrary unknown fields into the current schema as a substitute for a version policy.

**Meaningful acceptance:** supported v1/v2 load/migrate; future versions, invalid versions, and ambiguous/missing version policy have explicit expected behavior; unsupported input stays byte-for-byte preserved through preference toggles. Do not describe this as a known deployed future-version incident.

## V06 — CONFIRMED, medium: suites do not isolate record loading at actual startup

**Exact code:** `tools/test.sh:12` gives all suites `--test-mode`. `scripts/main.gd:82` unconditionally redirects it to shared `res://builds/test_records.json`, then `scripts/main.gd:89` loads immediately in `_ready()`. Several suites assign their supposedly isolated path after `root.add_child(game)`: `tests/test_inputs.gd:32–35`, `tests/test_game.gd:22–23`, `tests/test_routes.gd:11`, `tests/test_playability.gd:158–161`, and `tests/test_skating.gd:21–22`. `tests/test_ui.gd:40` does not set a unique record path. Even `tests/test_traffic.gd:32`, which assigns one before adding the scene, has that path overridden by the command-line processing.

**Reproduction:** the startup-path probe assigned `res://builds/repair_audit/startup_isolated.json` before adding the scene, with fixture scores `[11,22,33]`. With `--test-mode`, the effective path after `_ready()` was `res://builds/test_records.json` and loaded pre-existing `[46895,40536,56646]`. It did not modify that shared file. See `builds/repair_audit/startup_path.log`.

**Impact:** suite-local save writes can be isolated while startup loads are still influenced by earlier runs. Existing “fresh game instance” persistence checks at `tests/test_inputs.gd:126–131` add the scene, then change its path and manually load again; they do not verify loading a chosen fixture as part of a real process launch. Poisoned/stale shared test data can affect unrelated suites. Running a suite manually without the documented `--test-mode` can additionally read the default user records before its later assignment; this audit did not perform that unsafe invocation.

**Smallest fix:** make the records destination/fixture selection effective before the first load and have the harness allocate a fresh directory per suite/run. Ensure the test-mode parser respects an explicit harness destination. Test startup migration in a new process, not only a subsequent manual `load_records()` call. All test-generated data and logs should remain outside the user's record directory.

**Meaningful acceptance:** distinct simultaneous/sequential suite runs load only their own explicit fixtures; a deliberately malformed unrelated shared `builds/test_records.json` cannot alter those runs; the harness leaves the real user directory byte-for-byte unchanged; a cold-start process applies the fixture's score, mute, hat, and v1 migration without a second manual load.

## V07 — CONFIRMED validation gate gap, medium: the runner accepts success without proof of completion and has no deadline

**Exact code:** `tools/test.sh:11–18` requires exit success and absence of selected error strings. It does not require the expected suite summary, a positive assertion count, or a structured completion result. None of its engine invocations has a deadline. `docs/TEST_RESULTS.json:1–74` is a static report; the runner does not regenerate or validate it.

**Triggers:** a suite exits zero before reaching its assertions or completion summary; a changed suite produces zero checks; an awaited frame or engine operation never returns. These are established control-flow gaps, not evidence that the current completed 1,780-assertion run skipped assertions.

**Existing test blind spot:** there are no runner-level negative fixtures for empty/early success, missing completion, a wrong suite result, script error with zero process exit, or a hang. The records probes in V02 did directly demonstrate script errors with zero process exit; the current regex would correctly reject those errors if they appeared in a suite log.

**Smallest fix:** require one identified completion result per expected suite with positive scenario/check counts and zero failures. Fail when the summary is absent, duplicated, or malformed. Generate the current report from that run's outputs. Apply a portable bounded deadline that cleans up its child and reports the timed-out suite. Keep the known certificate diagnostic separate from unexpected errors. Do not freeze every assertion count as the test oracle; legitimate added coverage should not require weakening the completion gate.

**Meaningful acceptance:** isolated runner-fixture processes cover success, early-zero-exit, script-error-zero-exit, failure, bad/missing summary, and timeout. The failure exit must propagate to callers. A generated report must identify the engine, run, suite names, actual counts, and tested source/build identity. Existing behavior assertions must remain intact rather than being replaced by only these orchestration tests.

## V08 — CONFIRMED launcher behavior; current source/artifact mismatch NEEDS_REPRODUCTION

**Exact code:** `Play.command:4–5` always launches the existing `builds/StairWreck.app` first. `Play.command:7–8` reaches the current project only when that executable is absent. The source suite at `tools/test.sh:12` instead exercises the source project. `tools/build_macos.sh:11–13` is the separate operation that refreshes the PCK/runtime.

**Trigger:** source changes are tested but the app is not rebuilt, and a player uses the workspace launcher. That player continues to run the old PCK. This audit did not establish that the currently bundled PCK differs from the current source; no such mismatch is claimed.

**Existing test blind spot:** source tests do not invoke `Play.command`, and the packaged checker does not record or compare a source/build identity.

**Smallest fix:** make workspace source play and packaged release play explicit, and record a build identity in the release manifest. The developer launcher must not quietly hide source edits behind a stale app. Avoid automatically rebuilding on every normal game launch; building is a separate development operation with its own failure contract.

**Meaningful acceptance:** after a harmless isolated source/build identity difference, the development launch visibly selects the intended source project and the release launch selects the intended artifact. Final release validation uses the freshly built identity and a build record, not the presence of a directory named `StairWreck.app`.

## V09 — CONFIRMED release gate gaps, medium: repeatable package checking omits the deliverable archive and durable saving

**Exact code:** `tools/check_package.sh:4` chooses the app directory, `:7–12` runs its automated three-route self-check, `:13–16` runs a source-side asset probe, and `:17` verifies its signature. It never opens `StairWreck-macOS.zip`, compares archived app contents to the signed directory, checks archive CRC, confirms architectures/minimum OS/plist versions, or compares source/build identity. The one-time claim in `docs/VALIDATION.md:82` correctly says several archive checks were performed separately; they are not part of the reusable tool. `scripts/main.gd:463` explicitly skips saving in self-check mode, while `:84` automates all input.

**Triggers:** app rebuilt without replacing ZIP; damaged/old ZIP left beside a healthy app; overridden engine lacks the promised architecture; interactive packaged records cannot be written; current source tests pass while an older PCK is packaged. These triggers were not injected into the existing deliverable.

**Current artifact checks that passed in this audit:**

- ZIP CRC: no corrupt member.
- Archived app files: all seven exactly match the signed app directory; no extra app file.
- Deep strict ad-hoc signature: valid.
- Binary architectures: `x86_64 arm64`.
- Mach-O minimum OS: x86_64 10.13, arm64 11.0; application plist requires 11.0.
- Plist version and build version: both 3.0; executable is `StairWreck`.
- ZIP SHA-256: `a558b85b00dacbb9f264c563ce028f73ab7e1d4d446bb81d15720ab2e5bd1ae4`, 171,197,676 bytes.
- PCK SHA-256: `77a4074084da1aa8b6286cffaf4467dbc70db667a35cbf56d30a80937f407f03`, 3,562,592 bytes.
- Those sizes/hashes agree with `docs/PACKAGE_CHECK.txt:20–23`.

**Smallest fix:** extend the local release gate to verify the ZIP that will be shared, extract it into a fresh writable directory, and launch that extracted runtime from an unrelated working directory. Generate one manifest tying source identity, exact engine/version/architectures, app/PCK/ZIP hashes, plist, and validations together. Include an isolated normal save/restart path; automation self-check deliberately does not exercise it. Continue excluding tools/test sources from the game PCK; a source-side probe is acceptable when clearly labeled and linked to the actual artifact identity.

**Meaningful acceptance:** stale/corrupt ZIP, mismatched app bytes, wrong architecture/plist, and source/build mismatch each fail the release gate. A fresh extracted artifact completes all routes, resources and real record write/restart from a controlled save directory. Use actual platform evidence for Intel/Apple Silicon/minimum-OS promises; universal binary structure alone proves neither execution on both CPUs nor compatibility on the oldest declared system.

## V10 — NEEDS_REPRODUCTION: native player and distribution paths remain open acceptance items

`docs/VALIDATION.md:61` already states that native GPU inspection, audio audition, human play, and rendered-FPS measurement were unavailable. `tests/test_ui.gd:33` uses a 1440×900 canvas; `tests/test_audio.gd:45–52` explicitly verifies allocation-free headless behavior rather than actual playback. `scripts/main.gd:602` bypasses live particles in headless/test mode. `tools/check_package.sh:8` uses automated headless fixed-frame execution. These choices make the existing tests useful but leave the actual player-facing branches unobserved.

Use a concise reproducible manual matrix after code fixes: extracted release starts from Finder and an unrelated working directory; native keyboard/mouse/focus work; pause/help/retry/replay behave; earned scores and preferences survive quit/relaunch; representative window sizes/fullscreen and display scaling stay readable; effects/shaders/camera remain legible; sound/mute/pause transitions are heard; sustained crash/traffic performance is measured. Record actual engine, macOS, CPU, display, and artifact hash. Test a downloaded/quarantined artifact where that is the intended distribution path: an ad-hoc signature check alone is not a completed Finder/Gatekeeper test. No launch restriction was observed or asserted in this audit.

Human bug reports should be captured as route, selected lane/pose/hat, launch charge, inputs/timing, phase, expected/actual outcome, and the exact source/artifact identity. Until native access exists, these gates remain open and the final release must say so. Blender reconstructions and repeated headless geometry checks cannot close them.

## What the assertion totals do and do not establish

- `docs/VALIDATION.md:7` already correctly distinguishes 1,780 assertions from independent scenarios. Do not reframe the count as 1,780 independent player journeys.
- The suites contain meaningful physical and negative controls. For example, `tests/test_traffic.gd:103–115` checks measured contacts and a displaced-middle-car negative case, and `tests/test_playability.gd:113–119` checks replay/double-settlement/banking. Preserve these while adding targeted missing cases.
- Some suites deliberately invoke handlers or set phase/state: `tests/test_game.gd:14–16`, `tests/test_routes.gd:27–30`, and `tests/test_ui.gd:121–124`. Their assertions validate those components, not every GUI/native event path. Real dispatched-input suites improve coverage but do not turn all other fixtures into end-to-end play.
- Existing save round trips establish valid schema behavior on writable test paths. They establish neither corruption recovery, write durability, schema rejection, isolated cold startup, nor packaged normal user storage.
- Headless frame-clock pacing is not native rendered performance. Resource load/PCM bounds are not audio mix audition. UI font/control bounds on the design canvas are not full native scaling coverage.
- Current ZIP integrity, matching bytes, universal structure, and signature are positive evidence. Their repeatability and link to future fixes still require the release gate work above.

## Suggested dependency-aware work boundaries

These are inputs to the root repair plan rather than authorization to implement:

1. **Evidence/fixture contract:** explicit source/artifact identity, isolated startup storage, malformed/failure fixture table, meaningful fixed expected values, and native report format. This blocks persistence and release acceptance work.
2. **Loader/recovery contract (V02/V03/V05):** version policy and transactional validation, preserved invalid inputs, and backup selection. Depends on 1. Unblocks durable saving and cold-start verification.
3. **Durable save and truthful UI (V01/V04):** checked write/replace/retry semantics and earned-versus-persisted state. Depends on 1 and 2. Unblocks packaged persistence validation.
4. **Harness reliability (V06/V07):** cold startup isolation, completion parsing, timeout handling, and generated run evidence. Depends on 1; integrates persistence regressions after 2/3.
5. **Launcher/release identity and archive verification (V08/V09):** source versus artifact launch choice, freshly extracted ZIP checks, checked engine/architectures/plist, and normal isolated storage restart. Depends on 1, 3, and 4 plus the root's gameplay fixes.
6. **Native player acceptance (V10):** manual launch/input/display/audio/performance matrix against the final ZIP. Depends on 5. A lack of native access leaves this gate open rather than substituting new assertion totals.

## Beads bootstrap without Git

No `.git`, `.beads`, or `AGENTS.md` existed at audit inspection. The installed tracker is `br 0.6.0`. Read-only `br init --help` has `--prefix`, `--db`, and other global options but no `--no-git`. `br capabilities --json` marks `init` as `workspace: none` and promises no automatic Git operations. `br robot-docs guide` says normal issue/sync paths never run Git and only explicit `vcs-status` requests run read-only Git probes. `br config schema --json` has no honored no-git configuration key.

The root subsequently reported that unqualified `br init` selected a home-directory workspace, while project initialization succeeded with an explicit database path. `.beads/beads.db` and its local metadata now exist here. Use `br --db /Users/tyler/Documents/GitHub/stair-dismount/.beads/beads.db init --prefix stair --json` when bootstrapping this project, and retain that explicit `--db` for `create`, `dep add <task> <blocker> --type blocks --json`, `dep cycles --blocking-only --json`, `ready --json`, and `sync --flush-only`. Do not reinitialize the existing local DB, use `--force`, add `git init` merely to satisfy the tracker, or invent a `--no-git` flag. This audit only inspected tracker documentation; the root performed and owns graph creation. Verify selected workspace and ready tasks with the explicit path so home-directory discovery cannot silently redirect work.

## Limitations and preserved work

No main save was read or changed by the new probes; their record paths were `res://builds/repair_audit/*`. The startup-path probe intentionally read the existing shared **test** record to establish V06 without modifying it. The current source suite and package self-checks were not rerun, and no export/repackage occurred. There was no native or external Gemini review; no external review credit is claimed. Interruption durability, actual `user://` permission/storage failure, source/PCK freshness, both-CPU/minimum-OS execution, native rendering/audio/input/performance, and downloaded-app launch remain bounded reproduction/acceptance tasks.
