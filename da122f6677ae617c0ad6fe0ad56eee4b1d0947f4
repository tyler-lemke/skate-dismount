# Reconstructed development history

This repository was created retrospectively on **October 31, 2026**. The October
3–5 commits reconstruct development checkpoints; they are **not original Git
commits**. Their dates come from recorded agent tool calls and source-snapshot
creation events. Both the author and committer identify the reconstruction.

## Evidence and confidence

- Literal file writes, context-matched patches, and a limited set of Python text
  edits were recovered from the original Codex session and its recorded workers.
  Archived commands were parsed as data and were never executed.
- `builds/baseline-2.0-source.zip` supplied an exact v2 baseline for the 93
  retained files it contains. It does not include the documentation directory.
- `builds/StairWreck-source-3.0.zip` supplied an exact v3 snapshot of 197 files.
  Both archives passed ZIP CRC checks before extraction.
- Three retained build-stage directories supplied exact runtime checkpoints
  during the repair work. They are runtime subsets, not full-project snapshots.
- Forty-three early files were recovered from the v2 archive using their ZIP
  modification times. That attribution is lower confidence: a file timestamp
  cannot prove its complete edit history.

The reconstruction recovered **801 file writes** and recorded **206 unsupported
or failed reconstruction fragments**. These fragments are not independent missing
features: later authoritative snapshots supersede many of them. Unknown edits,
generated data, earlier overwritten binaries, and concurrency ordering cannot all
be recovered. Early checkpoints may be incomplete or unbuildable. The historical
test counts in the documentation were not rerun at every reconstructed commit.

The nineteenth commit, dated October 31 rather than backdated, reconciles all
**333 tracked files** against the original project's exact bytes and executable
bits. It records 70 added, changed, or removed paths that conservative replay did
not fully reproduce. This checkpoint matches the original source before the
subsequent README, history-note, and capture-helper additions. Ignored build
packages, Godot caches, Python caches, and Beads database/lock files are excluded;
the original files remain in place. `builds/.gitkeep` is retained.

## Explore

```sh
git log --reverse --format='%h %aI %s'
git show reconstructed-v3-source:scripts/main.gd
git show reconstructed-current-source:README.md
git notes --ref=reconstruction show reconstructed-current-source
```

The `reconstructed-*` tags mark reconstructed checkpoints, not original release
tags. Detailed local manifests, checkpoint metadata, recovered-write provenance,
and gap records live in `.git/reconstruction/`; that local metadata directory is
preserved by the supplied installer. Git notes and this document preserve the
summary when the repository is cloned or bundled. Raw conversation logs are not
committed or published.

## New documentation and capture work

The README and [gameplay capture helper](CAPTURE_GAMEPLAY.md) were added in a new
October 31 commit after reconstruction. The README's three existing images are
explicitly labeled historical Blender reconstructions. Actual runtime GIFs were
not produced: native Godot capture stalled before engine initialization with
macOS LaunchServices/HIServices failures, and computer-control service startup
failed. The helper's syntax, help, and dry-run paths were checked; the three map
demo commands exited successfully in headless mode. Rendering and actual GIF
encoding remain unverified. No new physics, performance, or human-playability
claims follow from those checks.
