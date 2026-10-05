# R13 candidate builder preparation

This document records builder and verifier preparation, not R13 completion or an
accepted release. No candidate app/ZIP has been constructed by this preparation.
The preserved public `builds/StairWreck.app` and `builds/StairWreck-macOS.zip` are
untouched. Root owns final R13 evidence and all promotion/native gates.

## Method and limits

`tools/build_candidate.py` builds a new private candidate from a stable successful
R01 runtime integration report. It compares current project and import-cache
digests to the actual report and requires the same engine version/executable SHA.
The report now records engine identity before/after and cache inventory before/after.
A runtime-only run rejects changes to its existing import cache.

The build method is explicitly `runtime_pckpacker/from_existing_import_cache` and
`clean_import_verified=false`. It never requests editor initialization, import, or
export and does not reclassify the separately failed sandbox editor import as a
pass. An optional `--import-result` records the existing actual editor outcome and
its result-file digest. The ObjectDB `user://` write failure remains a separate
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
They have parsed successfully but have not yet run against a final candidate.

Manifest statuses distinguish archive-only completion from headless runtime and
isolated storage completion. `r13_acceptance_complete` remains false for root's
final gate; native presentation/input/render/audio/performance, both-CPU execution,
oldest-OS execution, and quarantined launch remain explicitly unverified.

## Actual preparation evidence

- Runner controls: 22 tests passed, actual subprocess artifacts at
  `builds/runner_controls/20261005T024903.657116Z-8fcc6337/result.json`.
  This includes strict default import failure versus explicit runtime-only labels,
  mandatory registry extensions, exact certificate adjacency, diagnostic failures,
  early/wrong/missing/duplicate summaries, bounded hangs and descendant cleanup.
- Candidate verifier controls: 22 tests passed, artifacts at
  `builds/candidate_controls/20261005T025631.019933Z-bb074d09/result.json`.
  Real disposable archive controls reject CRC corruption, stale archive/app bytes,
  missing/extra runtime members, traversal/absolute/backslash paths, symlinks,
  duplicate members, external manifest ZIP digest changes, wrong supplied candidate
  path, bad plist/build identity, non-executable mode, PCK changes, source mutation,
  changed engine identity, actual lipo-thinned arm64 engine, and bounded hanging child.
  The preserved baseline PCK is read independently; only a disposable copy is
  corrupted. No engine or packaged-game success is inferred from these fixtures.
  Actual installed Mach-O metadata is read per architecture's macOS OS load
  command, excluding unrelated source/dylinker version fields: arm64 minimum11.0
  and x86_64 minimum10.13, declared maximum11.0. Valid AppleDouble metadata and
  invalid opaque metadata are also exercised with actual disposable ZIPs.
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

## Primary API/source basis

[Godot 4.7 PCKPacker documentation](https://docs.godotengine.org/en/4.7/classes/class_pckpacker.html)
documents runtime `pck_start`, `add_file`, and `flush` Error returns. The actual
installed engine and original PCK use format 4; the independent directory reader
follows [Godot's exact PCK writer source](https://github.com/godotengine/godot/blob/ed1daf0bf001b61586d9930840f2f1394092c079/core/io/pck_packer.cpp)
and [format definitions](https://github.com/godotengine/godot/blob/ed1daf0bf001b61586d9930840f2f1394092c079/core/io/file_access_pack.h).
The existing-cache MD5 checks follow the authored-source and concatenated
destination checks in [Godot's editor filesystem implementation](https://github.com/godotengine/godot/blob/ed1daf0bf001b61586d9930840f2f1394092c079/editor/file_system/editor_file_system.cpp).
