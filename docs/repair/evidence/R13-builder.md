# R13 candidate builder and verifier evidence

This document records builder and verifier preparation, not R13 completion or an
accepted release. An initial private candidate was constructed and retained with
its actual failed storage-wrapper result. The final frozen-source candidate
completed its archive, headless runtime, and isolated bookkeeping checks below.
The preserved public `builds/StairWreck.app` and `builds/StairWreck-macOS.zip` are
untouched. Root owns final R13 evidence and all promotion/native gates.

## Method and limits

`tools/build_candidate.py` builds a new private candidate from a stable successful
R01 runtime integration report. It compares current project and import-cache
digests to the actual report and requires the same engine version/executable SHA.
The report now records engine identity before/after and cache inventory before/after.
A runtime-only run rejects changes to its existing import cache.
Build qualification additionally requires the canonical `tools/test_suites.json`
path, current registry SHA, normalized expected entries, and every mandatory suite
in exact order with successful, positive-check, zero-failure completion. A
successful focused custom registry does not qualify the build. Per-run deadline
overrides remain valid.

The build method is explicitly `runtime_pckpacker/from_existing_import_cache` and
`clean_import_verified=false`. It never requests editor initialization, import, or
export and does not reclassify the separately failed sandbox editor import as a
pass. An optional `--import-result` records the existing actual editor outcome,
its result-file digest, and its original log digest. Historical reports without
the newer top-level status field are read through their actual nested import
outcome and original strict log; the original report is never rewritten. The ObjectDB `user://` write failure remains a separate
environmental limitation. Neither HOME nor the installed engine is modified.

The builder hashes canonical sorted authored/runtime/packaging inputs, import
settings, used imported resources and their metadata, and the original tested
engine identity. The existing cache is checked against actual authored-source and
destination MD5 bytes. These checks establish which existing cache is used; they
do not claim a fresh import or regenerate/validate importer settings equivalence.
All files packed are staged and individually checked against the input SHA/size.
Source/cache/engine bytes are checked again after construction.

An immutable canonical identity and full build ID are embedded before signing.
An external manifest records signed-app inventory/modes, PCK inventory/hash/size,
ZIP inventory/CRC/hash/size, bounded process results, and exact extraction path.
No output hash participates in its own input build ID. Candidates use separate
UTC/UUID run IDs and `builds/candidates/<full-build-id>-<run-id>/`.

The installed universal executable is copied and the bundle ad-hoc signed after
all modifications. Its original tested SHA and signed bundled SHA are separate
fields because signing changes Mach-O signature bytes. Architecture and minimum
OS metadata are read with lipo/otool; both arm64 and x86_64 are required and the
declared minimum uses the maximum slice minimum. Info.plist identifies
`3.1candidate` and the full build ID. This is structural evidence only.

The signed bundle is zipped with ditto. The independent verifier rejects unsafe,
duplicate, symlink, missing, unexpected, CRC-corrupt, or byte/mode-mismatched
archive members. Only checked AppleDouble metadata is allowed outside the app.
It independently parses ordinary Godot PCK format 3/4 and hashes every file,
requiring exact staged input inventory and excluding tests/docs/tools/Blender,
builds, repair records, beads, and private roots. It extracts with ditto into a
fresh path containing spaces, compares every extracted app file/mode, verifies
deep strict signatures, and checks actual architecture/minimum OS metadata.
Verification binds the output manifest's source/cache/engine inventories back to
the embedded canonical identity and derives the expected PCK files from that
identity. Refreshing output hashes cannot retain an old source build ID for
changed packed inputs.

## Public CLI and deferred actual checks

After root freezes sources and completes the final exact runtime report:

```sh
GODOT_BIN=/opt/homebrew/bin/godot tools/test.sh --runtime-only
python3 tools/build_candidate.py build --runtime-result /absolute/final-runtime/result.json --import-result /absolute/actual-import/result.json --check-runtime
python3 tools/build_candidate.py verify --candidate /absolute/builds/candidates/BUILDID-RUNID
python3 tools/build_candidate.py check-runtime --candidate /absolute/builds/candidates/BUILDID-RUNID
```

The default bounded deadline is 180 seconds; public overrides are 10..600 seconds.
`build --check-runtime` or later `check-runtime` uses the extracted executable from
an unrelated empty working directory, with no source mounted as `res://`, for all
three actual packaged self-check routes. It requires the expected route and
positive score/wreck/frame completion evidence. The existing external assets
probe checks all 19 models, 15 audio resources, hero bones, taxi morphs, and the
representative exclusions; the full PCK inventory supplies exclusion coverage.

The new external `tools/packaged_records_probe.gd` loads the packaged main scene
and real record service. It supplies only ordinary `--records-path` startup,
never `--test-mode`/`--self-check`. Its fresh processes exercise a controlled
claim/preferences/restart, actual missing-parent write failure with pending
session and no secured contribution, explicit parent repair and retry with no
duplicate credit, v1 migration without legacy funding, and protected future
profile bytes. Python independently reads the resulting durable profiles.
These are bookkeeping fixtures, not physical crash provenance or native play.
Their final actual candidate results are recorded separately below.

Manifest statuses distinguish archive-only completion from headless runtime and
isolated storage completion. `r13_acceptance_complete` remains false for root's
final gate; native presentation/input/render/audio/performance, both-CPU execution,
oldest-OS execution, and quarantined launch remain explicitly unverified.
Each runtime recheck first revokes the current runtime/storage success labels,
keeps the previous summary as history, and gives actual bounded logs unique check
IDs. A failed recheck records the actual current failure and cannot retain the
previous passing validation scope.
Standalone archive verification also revokes current qualification before checks,
saves it as history, and persists an explicit archive-verification failure on any
error. A successful new extraction has archive-only status and requires a new
runtime/storage check; it does not retain the prior qualified runtime status.

## Actual preparation evidence

- Runner controls: 22 tests passed, actual subprocess artifacts at
  `builds/runner_controls/20261005T024903.657116Z-8fcc6337/result.json`.
  This includes strict default import failure versus explicit runtime-only labels,
  mandatory registry extensions, exact certificate adjacency, diagnostic failures,
  early/wrong/missing/duplicate summaries, bounded hangs and descendant cleanup.
- Candidate verifier controls: 28 tests passed, artifacts at
  `builds/candidate_controls/20261005T052500.927324Z-6c7010d4/result.json`.
  Real disposable archive controls reject CRC corruption, stale archive/app bytes,
  missing/extra runtime members, traversal/absolute/backslash paths, symlinks,
  duplicate members, external manifest ZIP digest changes, wrong supplied candidate
  path, bad plist/build identity, non-executable mode, PCK changes, source mutation,
  changed engine identity, actual lipo-thinned arm64 engine, and bounded hanging child.
  The preserved baseline PCK is read independently; only a disposable copy is
  corrupted. No packaged-game success is inferred from these corrupt fixtures.
  Actual installed Mach-O metadata is read per architecture's macOS OS load
  command, excluding unrelated source/dylinker version fields: arm64 minimum 11.0
  and x86_64 minimum 10.13, declared maximum 11.0. Valid AppleDouble metadata and
  invalid opaque metadata are also exercised with actual disposable ZIPs.
  The original strict failed-import report at
  `builds/test_runs/20261005T021641.874148Z-5053-b6376428/result.json` is read as a
  failed historical import with its exact diagnostics. Its SHA remains
  `5ac963538f21b0811fec83f8caa6f8a44021112dfc2f44d51e4ec788f703c533`;
  a disposable falsely labelled passing import is rejected.
  A disposable copy of the actual runtime PCK smoke output is changed and its
  internal MD5/output manifest hashes repaired; verification still rejects its
  disagreement with the original embedded canonical source identity. A real CLI
  repeat check of a disposable hanging child times out and removes previous
  passing runtime/storage labels while preserving the old summary. These remain
  verifier controls, never packaged-game evidence.
  One actual focused public runner invocation passes RULES (170 checks) with the
  same current source digest, then the actual build CLI refuses its custom
  registry. An actual CLI archive recheck of a disposable previously qualified
  fixture rejects CRC corruption and persists false/current archive-failed labels
  while preserving the old qualification in history. The state-marker control
  reads the preserved actual failed packaged log; the corrected `STATE=` marker
  no longer collides with strict suite completion detection, and errors/duplicate
  completions still fail.
- Actual runtime PCKPacker smoke with installed Godot 4.7.2: `PACK: 284 checks,
  0 failures`, 141 staged entries independently verified in an ordinary format-4
  PCK. Artifacts at
  `builds/repair_work/R13/packer-smoke-20261005T024931.157278Z-2faa6e14/` include
  the actual output/result JSON, staged inputs, `probe.pck`, and `verification.json`.
  No editor/main scene was initialized. The only diagnostic was R01's exact known
  adjacent macOS certificate pair. This is API/serialization evidence only.
- Packaged records probe parse: helper exit 0 at
  `builds/repair_work/R13/records-probe-parse/output.log.result.json`; no game/storage
  execution or final-candidate acceptance is claimed.

## Actual final frozen-source candidate

The final public runner invocation completed all 31 mandatory suites with 10,807
checks and zero failures. Its scope is `runtime_suites_only` and its import status
is `not_run_runtime_only`. Exact result:
`builds/test_runs/20261005T052525.893099Z-52125-28f61817/result.json`, SHA-256
`c40a57e2a7b0373e298272f5a4fef5b28ed0ae112d04d24e2fa8ed92060588f9`.
Before/after source digest is
`4d20e15387061ba5f4865d484dea2beb4cd6cbe87193d90e0dd8ce00ed5ebfc7`;
cache digest is
`a754a19fb2e1bc7f2563996cba8e8a509c144cf847ec2c94ebd03543b345b58b`;
canonical registry SHA is
`64e610d23605184ef73e5439f00525ab33353f20613d617170ca4136abb80340`.
The same installed Godot executable identity was stable before/after:
351,312,912 bytes, SHA
`c7cccbf8fb143e34e02fd6521e09be2c2b974f0d5db080b19071c9c570718ccf`.

Actual `build --check-runtime` returned zero for private directory
`builds/candidates/f6434bb1219b2b27c0638961f6b00b13d2deb1ed157271fcba7d05f455bfe4bb-20261005T052800.141632Z-ab4472e9/`.
Its full canonical build ID is
`f6434bb1219b2b27c0638961f6b00b13d2deb1ed157271fcba7d05f455bfe4bb`.

| Artifact | Bytes | SHA-256 |
| --- | ---: | --- |
| `StairWreck-macOS.zip` | 173269671 | `38754b8ce557ae1670f0304fa1a70541ce3e7f9c62d403ca49530b3193110f96` |
| `StairWreck.app/Contents/MacOS/StairWreck.pck` | 7786080 | `94e822e202985a5d194fa57181dee27063f42e0cd7f369c5b3bfdf40a25864cd` |
| Signed bundled executable | 350329232 | `4607575fee32c6f898632231f73f0f9ce68ac397b316abaeaf7611cee3446ea6` |

At builder completion the external `manifest.json` SHA was
`4c2511ec7c34093f6364154c47f22eb9e0eb432db798c67d7377c02f1daf52af`.
The fresh actual extraction is `extracted candidate 79a47fa4/StairWreck.app`
inside that directory. ZIP CRC/path/member checks, all eight app files/modes,
142 PCK entries, embedded identity, deep strict signatures, universal architecture,
and declared macOS minimum 11.0 passed. Actual packing reports `PACK: 286 checks,
0 failures`. All 22 bounded build/package process results passed with no
unexpected diagnostics.

The extracted executable ran from `packaged checks cafaf996/unrelated empty cwd`
with no source project mounted. The exact packaged route completions were:

| Requested level | Reported level | Score | Wrecks | Explosions | Frames |
| ---: | ---: | ---: | ---: | ---: | ---: |
| 0 | 1 | 193148 | 32 | 4 | 201 |
| 1 | 2 | 100329 | 22 | 7 | 322 |
| 2 | 3 | 254145 | 36 | 8 | 224 |

The external asset probe passed 19 models / 15 audio, 11 hero bones, and taxi morph
checks. Seven fresh ordinary-records processes passed 83 checks total, every
state reporting `test_mode=false` and `self_check=false`. Independent Python
reads confirmed normal `[100000,0,0]`, failed-write/repair/retry `[0,150000,0]`, and
migrated `[0,0,250000]` durable scores. Normal/retry profiles persist mute=true and
hat 2; migrated profiles persist mute=true, hat 1 and non-funding legacy
`[111,222,333]`. Cold restarts reproduce these states without duplicate credit.
The unsupported version99 profile remains byte-identical, SHA
`c0679183456ed7c0672a4b3bf36681dfee32449770ff63bf0cda8f2cfa25716c`.
All profiles and actual transcripts remain inside `packaged checks cafaf996/`.

The manifest records success=true,
`candidate_headless_and_storage_verified_native_pending`, and
`candidate_archive_headless_runtime_and_isolated_bookkeeping_only`;
archive/runtime/normal isolated persistence are passed. `clean_import_verified`
and the producer-owned `r13_acceptance_complete` remain false. Root independently
reviewed the exact archive/app/PCK bytes, all 22 bounded results, seven normal
processes, four durable profiles, and current source/cache identity. Root's
acceptance is a separate `root_acceptance.json` beside the unchanged manifest,
bound to that manifest SHA, build ID, ZIP and PCK hashes. Its scope is the existing
cache, headless runtime, and isolated bookkeeping gates. R13 closure uses that
receipt; it does not alter the producer manifest or supply native acceptance.
Native presentation/input/render/audio/performance, both-CPU execution,
oldest-OS execution, and quarantined launch remain unverified.

The failed initial candidate
`f236cc82018fb54172cdcf8b9465b3bfb4f36339de1cdb9ee9d6fdf542f92e73-20261005T051131.502615Z-1f21c626`
and its strict storage-wrapper rejection are preserved. Its JSON `STATE:` line
contained the phrase `packaged checks` in a path and collided with strict summary
detection. The narrow `STATE=` fix and actual-log negative control resolved that
wrapper defect without weakening completion/error policy or rewriting old logs.

The public 3.0 ZIP and PCK still match the original preserved bytes and hashes:
ZIP 171197676 / `a558b85b00dacbb9f264c563ce028f73ab7e1d4d446bb81d15720ab2e5bd1ae4`;
PCK 3562592 / `77a4074084da1aa8b6286cffaf4467dbc70db667a35cbf56d30a80937f407f03`.
The original strict editor-import failure result/log hashes above are unchanged
and included separately as historical failed evidence in the candidate manifest.

## Primary API/source basis

[Godot 4.7 PCKPacker documentation](https://docs.godotengine.org/en/4.7/classes/class_pckpacker.html)
documents runtime `pck_start`, `add_file`, and `flush` Error returns. The actual
installed engine and original PCK use format 4; the independent directory reader
follows [Godot's exact PCK writer source](https://github.com/godotengine/godot/blob/ed1daf0bf001b61586d9930840f2f1394092c079/core/io/pck_packer.cpp)
and [format definitions](https://github.com/godotengine/godot/blob/ed1daf0bf001b61586d9930840f2f1394092c079/core/io/file_access_pack.h).
The existing-cache MD5 checks follow the authored-source and concatenated
destination checks in [Godot's editor filesystem implementation](https://github.com/godotengine/godot/blob/ed1daf0bf001b61586d9930840f2f1394092c079/editor/file_system/editor_file_system.cpp).
