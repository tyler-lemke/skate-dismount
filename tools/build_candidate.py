#!/usr/bin/env python3
"""Construct and verify a private candidate; never promote the public app/ZIP.

Runtime PCKPacker deliberately uses the existing checked import cache. This is
not an editor export or proof of a clean import. See `build --help`.
"""

import argparse
import datetime
import hashlib
import json
import os
from pathlib import Path, PurePosixPath
import plistlib
import re
import shutil
import stat
import struct
import sys
import uuid
import zipfile

import run_bounded


PROJECT = Path(__file__).resolve().parent.parent
SCHEMA = 1
APP_NAME = "StairWreck.app"
ZIP_NAME = "StairWreck-macOS.zip"
BUILD_METHOD = "runtime_pckpacker/from_existing_import_cache"
PACKAGING_INPUTS = ("export_presets.cfg", "LICENSE", "docs/GODOT_LICENSE.txt",
                    "tools/build_candidate.py", "tools/pack_candidate.gd", "tools/run_bounded.py",
                    "tools/package_assets_probe.gd", "tools/packaged_records_probe.gd")
FORBIDDEN_PACK_ROOTS = {"blender", "docs", "tests", "tools", "builds", ".beads", ".git", ".agents", ".codex"}


class CandidateError(ValueError):
    pass


def require(condition, message):
    if not condition:
        raise CandidateError(message)


def canonical(value):
    return json.dumps(value, sort_keys=True, separators=(",", ":"), ensure_ascii=False).encode("utf-8")


def sha256(path):
    digest = hashlib.sha256()
    with Path(path).open("rb") as stream:
        for block in iter(lambda: stream.read(1024 * 1024), b""):
            digest.update(block)
    return digest.hexdigest()


def file_entry(path, relative):
    path = Path(path)
    require(path.is_file() and not path.is_symlink(), f"missing or symlink input: {relative}")
    return {"path": relative, "bytes": path.stat().st_size, "sha256": sha256(path)}


def inventory(project):
    files = {project / "project.godot"}
    for root in ("scripts", "scenes", "assets"):
        files.update(path for path in (project / root).rglob("*") if path.is_file() and
                     path.name != ".DS_Store" and "__pycache__" not in path.parts)
    files.update(project / name for name in PACKAGING_INPUTS)
    return [file_entry(path, path.relative_to(project).as_posix()) for path in sorted(files)]


def safe_resource_path(path):
    require(isinstance(path, str) and path.startswith("res://"), f"invalid imported resource path: {path}")
    result = path[6:]
    require(result.startswith(".godot/imported/") and len(PurePosixPath(result).parts) == 3 and
            "\\" not in result and ".." not in result.split("/"), f"unsafe imported resource path: {path}")
    return result


def import_cache(project):
    """Check the real cache's source/destination MD5s; do not claim regeneration."""
    imported, proofs = set(), []
    for remap in sorted((project / "assets").rglob("*.import")):
        text = remap.read_text(encoding="utf-8")
        source_match = re.search(r'^source_file=(".*")$', text, re.M)
        destinations_match = re.search(r'^dest_files=(\[.*\])$', text, re.M)
        path_match = re.search(r'^path=(".*")$', text, re.M)
        require(source_match and destinations_match and path_match, f"incomplete import remap: {remap}")
        source = json.loads(source_match[1])
        destinations = json.loads(destinations_match[1])
        require(source == "res://" + remap.relative_to(project).as_posix()[:-7],
                f"import source does not match remap: {remap}")
        require(isinstance(destinations, list) and destinations, f"empty imported destinations: {remap}")
        require(json.loads(path_match[1]) in destinations, f"remap destination missing from deps: {remap}")
        paths = [safe_resource_path(value) for value in destinations]
        # Godot FileAccess::get_multiple_md5 hashes concatenated destination bytes.
        destination_md5 = hashlib.md5()
        for relative in paths:
            entry = file_entry(project / relative, relative)
            imported.add(relative)
            with (project / relative).open("rb") as stream:
                for block in iter(lambda: stream.read(1024 * 1024), b""):
                    destination_md5.update(block)
        cache_md5 = project / (paths[0].rsplit(".", 1)[0] + ".md5")
        metadata = cache_md5.read_text(encoding="utf-8")
        recorded = dict(re.findall(r'^(source_md5|dest_md5)="([a-f0-9]{32})"$', metadata, re.M))
        source_md5 = hashlib.md5((project / source[6:]).read_bytes()).hexdigest()
        require(recorded.get("source_md5") == source_md5, f"stale imported source digest: {remap}")
        require(recorded.get("dest_md5") == destination_md5.hexdigest(), f"stale imported destination digest: {remap}")
        proofs.append({"remap": remap.relative_to(project).as_posix(), "source_md5": source_md5,
                       "dest_md5": destination_md5.hexdigest(), "destinations": paths,
                       "metadata": file_entry(cache_md5, cache_md5.relative_to(project).as_posix())})
    require(len(proofs) >= 35, "missing expected authored asset remaps")
    classes = ".godot/global_script_class_cache.cfg"
    class_text = (project / classes).read_text(encoding="utf-8")
    for path in re.findall(r'"path": "res://([^"\n]+)"', class_text):
        require(path.startswith("scripts/") and (project / path).is_file(), f"invalid global class cache path: {path}")
    imported.add(classes)
    return {"files": [file_entry(project / path, path) for path in sorted(imported)],
            "source_destination_md5_checks": proofs, "import_settings_regenerated": False}


def version_tuple(value):
    require(re.fullmatch(r"\d+(?:\.\d+){1,2}", value) is not None, f"invalid macOS version: {value}")
    return tuple(int(part) for part in value.split(".")) + (0,) * (3 - len(value.split(".")))


def architecture_metadata(architectures, load_commands):
    archs = architectures.strip().split()
    require(set(archs) == {"x86_64", "arm64"} and len(archs) == 2, f"engine must contain x86_64 and arm64; found {archs}")
    sections = re.split(r'^.*\(architecture (x86_64|arm64)\):\s*$', load_commands, flags=re.M)
    require(len(sections) == 5 and {sections[1], sections[3]} == set(archs), "otool output lacks both architecture sections")
    slices = []
    for arch, commands in zip(sections[1::2], sections[2::2]):
        found = []
        for block in re.split(r'^Load command \d+\s*$', commands, flags=re.M):
            legacy = re.search(r'^\s*cmd LC_VERSION_MIN_MACOSX\s*$', block, re.M)
            modern = re.search(r'^\s*cmd LC_BUILD_VERSION\s*$', block, re.M)
            if not legacy and not modern:
                continue
            if modern:
                require(re.search(r'^\s*platform (?:1|macos)\s*$', block, re.M), f"engine slice {arch} is not a macOS build")
            field = "version" if legacy else "minos"
            minimum = re.search(r'^\s*' + field + r' (\d+(?:\.\d+){1,2})\s*$', block, re.M)
            require(minimum is not None, f"engine slice {arch} lacks declared minimum OS")
            sdk = re.search(r'^\s*sdk (\d+(?:\.\d+){1,2})\s*$', block, re.M)
            found.append({"architecture": arch, "minimum_os": minimum[1], "sdk": sdk[1] if sdk else None,
                          "load_command": "LC_VERSION_MIN_MACOSX" if legacy else "LC_BUILD_VERSION"})
        require(len(found) == 1, f"engine slice {arch} has ambiguous/missing macOS minimum metadata")
        slices.extend(found)
    slices.sort(key=lambda item: item["architecture"])
    minimums = [item["minimum_os"] for item in slices]
    declared = max(minimums, key=version_tuple)
    return {"architectures": sorted(archs), "slice_minimum_os": minimums,
            "slice_metadata": slices, "declared_minimum_os": declared}


def engine_matches_report(identity, report):
    require(report.get("success") is True, "integration runtime report did not pass")
    require(report.get("engine_version") == identity["version"], "engine version differs from tested integration engine")
    require(report.get("engine_executable", {}).get("sha256") == identity["sha256"],
            "engine executable identity differs from tested integration engine")
    require(report.get("engine_executable_after") == report.get("engine_executable"),
            "integration report lacks a stable engine executable identity")


def stable_inputs(before, after, engine_before, engine_after):
    require(before == after, "source or existing import cache changed during construction")
    require(engine_before == engine_after, "engine executable changed during construction")


def import_evidence(path):
    """Read actual bounded import evidence, including R01's pre-label result."""
    imported = json.loads(path.read_text(encoding="utf-8"))
    outcome = imported.get("import", imported)
    require(isinstance(outcome, dict) and "--import" in outcome.get("command", []) and
            type(outcome.get("success")) is bool, "supplied import evidence lacks an actual bounded import outcome")
    log = Path(outcome["log"])
    inspected = run_bounded.inspect_output(log.read_text(encoding="utf-8", errors="replace"))
    rejected = bool(outcome.get("exit_code") != 0 or outcome.get("timed_out", False) or
                    outcome.get("interrupted", False) or outcome.get("errors") or inspected["errors"])
    require(outcome["success"] == (not rejected), "supplied import result contradicts actual bounded diagnostics")
    status = "passed" if outcome["success"] else "failed"
    require(imported.get("import_status", status) == status, "supplied import status contradicts actual import outcome")
    return {"result": str(path.resolve()), "sha256": sha256(path), "import_status": status,
            "log": str(log), "log_sha256": sha256(log), "engine_exit_code": outcome.get("exit_code"),
            "unexpected_diagnostics": inspected["errors"], "evidence_source_digest": imported.get("input_source_digest", {}).get("sha256"),
            "historical_evidence": True}


def run_check(report, name, command, directory, timeout, *, expected=None, cwd=None):
    result = run_bounded.run_command(command, timeout, directory / "logs" / (name + ".output.log"),
                                     expected_summary=expected, cwd=cwd)
    report.setdefault("bounded_checks", {})[name] = result
    run_bounded.write_json(directory / "manifest.json", report)
    require(result["success"], f"{name} failed; see {result['result']}: {result['errors']}")
    return Path(result["log"]).read_text(encoding="utf-8").strip()


def inspect_engine(engine, report, directory, timeout):
    before = run_bounded.executable_identity(engine)
    version = run_check(report, "engine_version", [engine, "--version"], directory, 10)
    require(version.startswith("4.7.2."), f"candidate requires tested Godot 4.7.2; found {version}")
    archs = run_check(report, "engine_architectures", ["/usr/bin/lipo", "-archs", before["path"]], directory, timeout)
    loads = run_check(report, "engine_load_commands", ["/usr/bin/otool", "-l", before["path"]], directory, timeout)
    metadata = architecture_metadata(archs, loads)
    return {**before, "version": version, **metadata}


def identity_payload(inputs, cache, engine):
    return {"schema": SCHEMA, "source_inputs": inputs,
            "existing_import_cache": cache, "engine": {key: value for key, value in engine.items() if key != "path"},
            "build_method": BUILD_METHOD, "clean_import_verified": False}


def packed_inputs(inputs, cache):
    result = [entry for entry in inputs if entry["path"] == "project.godot" or
              entry["path"].startswith(("scripts/", "scenes/")) or
              (entry["path"].startswith("assets/") and not entry["path"].startswith("assets/stairwreck.iconset/") and
               entry["path"] != "assets/StairWreck.icns")]
    return sorted(result + cache["files"], key=lambda entry: entry["path"])


def stage_files(project, stage, entries):
    stage.mkdir(parents=True, exist_ok=False)
    result = []
    for entry in entries:
        destination = stage / entry["path"]
        destination.parent.mkdir(parents=True, exist_ok=True)
        shutil.copyfile(project / entry["path"], destination)
        require(file_entry(destination, entry["path"]) == entry, f"staged source changed: {entry['path']}")
        result.append({**entry, "source": str(destination)})
    return result


def read_pck(path):
    """Independent Godot format 3/4 reader for unencrypted, non-sparse packs."""
    size = Path(path).stat().st_size
    with Path(path).open("rb") as stream:
        def read(length):
            value = stream.read(length)
            require(len(value) == length, "truncated PCK")
            return value
        header = struct.unpack("<6I2Q", read(40))
        magic, fmt, major, minor, patch, flags, filebase, directory = header
        require(magic == 0x43504447 and fmt in (3, 4), f"unsupported PCK magic/format: {magic}/{fmt}")
        require(flags == 2, f"unsupported encrypted/sparse PCK flags: {flags}")
        require(104 <= filebase <= directory < size, "invalid PCK header offsets")
        stream.seek(directory)
        count, = struct.unpack("<I", read(4))
        require(0 < count < 10000, "invalid PCK entry count")
        entries = []
        seen = set()
        for _ in range(count):
            length, = struct.unpack("<I", read(4))
            require(0 < length <= 4096 and length % 4 == 0, "invalid PCK path length")
            raw = read(length)
            name = raw.rstrip(b"\0").decode("utf-8")
            if name.startswith("res://"):
                name = name[6:]
            archive_path(name)
            require(name not in seen and PurePosixPath(name).parts[0] not in FORBIDDEN_PACK_ROOTS,
                    f"duplicate or excluded PCK entry: {name}")
            seen.add(name)
            offset, length = struct.unpack("<QQ", read(16))
            md5 = read(16).hex()
            entry_flags, = struct.unpack("<I", read(4))
            require(entry_flags == 0, f"unsupported PCK entry flags: {name}")
            require(filebase + offset + length <= directory, f"PCK entry points outside data region: {name}")
            entries.append({"path": name, "bytes": length, "offset": filebase + offset, "md5": md5})
        for entry in entries:
            stream.seek(entry.pop("offset"))
            data = read(entry["bytes"])
            require(hashlib.md5(data).hexdigest() == entry["md5"], f"PCK entry checksum mismatch: {entry['path']}")
            entry["sha256"] = hashlib.sha256(data).hexdigest()
    return {"format": fmt, "engine_format_version": [major, minor, patch], "files": entries}


def verify_pck(path, expected):
    result = read_pck(path)
    actual = sorted(({key: entry[key] for key in ("path", "bytes", "sha256")} for entry in result["files"]),
                    key=lambda entry: entry["path"])
    require(actual == expected, "PCK inventory or staged file bytes differ")
    return result


def app_file_map(app):
    require(app.is_dir() and not app.is_symlink(), f"missing app directory: {app}")
    result = []
    for path in sorted(app.rglob("*")):
        require(not path.is_symlink(), f"symlink not allowed in candidate app: {path}")
        if path.is_file():
            result.append({**file_entry(path, path.relative_to(app).as_posix()),
                           "mode": stat.S_IMODE(path.stat().st_mode)})
    require(result, "empty candidate app")
    return result


def validate_app(app, build_id, engine, *, expected_map=None):
    plist = plistlib.loads((app / "Contents/Info.plist").read_bytes())
    expected = {"CFBundleExecutable": "StairWreck", "CFBundleName": "STAIR WRECK",
                "CFBundleShortVersionString": "3.1candidate", "StairWreckBuildID": build_id,
                "LSMinimumSystemVersion": engine["declared_minimum_os"]}
    for key, value in expected.items():
        require(plist.get(key) == value, f"plist {key} differs from candidate identity")
    identity = json.loads((app / "Contents/Resources/build_identity.json").read_text(encoding="utf-8"))
    require(identity.get("build_id") == build_id, "embedded build ID differs from candidate")
    payload = identity.get("identity")
    require(isinstance(payload, dict) and hashlib.sha256(canonical(payload)).hexdigest() == build_id,
            "embedded canonical source/engine identity digest mismatch")
    require(payload.get("engine", {}).get("sha256") == engine["sha256"], "embedded engine identity mismatch")
    for relative in ("Contents/MacOS/StairWreck", "Contents/MacOS/StairWreck.pck", "Contents/Resources/StairWreck.icns",
                     "Contents/Resources/GODOT_LICENSE.txt", "Contents/Resources/GAME_LICENSE.txt"):
        require((app / relative).is_file() and (app / relative).stat().st_size > 0, f"missing runtime member: {relative}")
    require(stat.S_IMODE((app / "Contents/MacOS/StairWreck").stat().st_mode) == 0o755, "runtime executable mode must be 0755")
    actual = app_file_map(app)
    if expected_map is not None:
        require(actual == expected_map, "app file bytes/inventory/modes differ from signed candidate map")
    return plist


def archive_path(value):
    require(isinstance(value, str) and value and "\\" not in value and "\0" not in value and
            not value.startswith("/") and all(part not in ("", ".", "..") for part in value.rstrip("/").split("/")),
            f"unsafe archive path: {value!r}")
    return PurePosixPath(value.rstrip("/"))


def verify_zip(path, expected_map):
    expected = {APP_NAME + "/" + entry["path"]: entry for entry in expected_map}
    actual, members, seen = {}, [], set()
    try:
        with zipfile.ZipFile(path) as archive:
            for info in archive.infolist():
                member = archive_path(info.filename)
                require(info.filename not in seen, f"duplicate archive member: {info.filename}")
                seen.add(info.filename)
                mode = info.external_attr >> 16
                require(not stat.S_ISLNK(mode), f"archive symlink forbidden: {info.filename}")
                parts = member.parts
                metadata = parts[0] == "__MACOSX" and (info.is_dir() or parts[-1].startswith("._"))
                require(parts[0] == APP_NAME or metadata, f"unexpected archive member: {info.filename}")
                if info.is_dir():
                    if not metadata:
                        require(any(name.startswith(str(member) + "/") for name in expected),
                                f"unexpected archive directory: {info.filename}")
                    continue
                if metadata:
                    # AppleDouble metadata is CRC-checked, never treated as a runtime file.
                    require(info.file_size < 16 * 1024 * 1024, "oversized macOS archive metadata")
                else:
                    require(info.filename in expected, f"unexpected runtime archive member: {info.filename}")
                    require(info.file_size == expected[info.filename]["bytes"], f"archive member size mismatch: {info.filename}")
                data = archive.read(info)  # zipfile verifies the actual member CRC.
                if metadata:
                    require(len(data) >= 26 and struct.unpack(">II", data[:8]) == (0x00051607, 0x00020000),
                            f"invalid AppleDouble archive metadata: {info.filename}")
                    counterpart = "/".join((*parts[1:-1], parts[-1][2:]))
                    require(counterpart == APP_NAME or counterpart in expected or
                            any(name.startswith(counterpart + "/") for name in expected),
                            f"macOS metadata identifies no candidate member: {info.filename}")
                digest = hashlib.sha256(data).hexdigest()
                members.append({"path": info.filename, "bytes": len(data), "sha256": digest, "crc32": info.CRC,
                                "mode": stat.S_IMODE(mode), "metadata": metadata})
                if not metadata:
                    require(digest == expected[info.filename]["sha256"], f"archive member checksum mismatch: {info.filename}")
                    permissions = stat.S_IMODE(mode)
                    if permissions:
                        require(permissions == expected[info.filename]["mode"], f"archive member mode mismatch: {info.filename}")
                    actual[info.filename] = digest
            require(set(actual) == set(expected), "archive missing runtime member(s): " + str(sorted(set(expected) - set(actual))))
    except (zipfile.BadZipFile, RuntimeError, OSError) as exc:
        raise CandidateError(f"archive CRC/structure check failed: {exc}") from exc
    return sorted(members, key=lambda entry: entry["path"])


def verify_outputs(directory, report):
    app, archive = directory / APP_NAME, directory / ZIP_NAME
    require(sha256(archive) == report["zip"]["sha256"] and archive.stat().st_size == report["zip"]["bytes"],
            "ZIP digest/size differs from candidate manifest")
    validate_app(app, report["build_id"], report["engine"], expected_map=report["app_file_map"])
    embedded = json.loads((app / "Contents/Resources/build_identity.json").read_text(encoding="utf-8"))["identity"]
    require(report.get("identity") == embedded, "manifest source/engine identity differs from embedded candidate")
    require(report.get("input_inventory") == embedded["source_inputs"] and
            report.get("existing_import_cache") == embedded["existing_import_cache"],
            "manifest input inventory differs from canonical source/cache identity")
    require({key: value for key, value in report["engine"].items() if key != "path"} == embedded["engine"],
            "manifest engine metadata differs from canonical engine identity")
    canonical_pack = packed_inputs(embedded["source_inputs"], embedded["existing_import_cache"])
    require(report["packed_inputs"] == canonical_pack, "manifest packed inventory differs from canonical source/cache identity")
    pck = app / "Contents/MacOS/StairWreck.pck"
    require(sha256(pck) == report["pck"]["sha256"], "PCK digest differs from candidate manifest")
    pck_report = verify_pck(pck, report["packed_inputs"])
    members = verify_zip(archive, report["app_file_map"])
    return {"zip_members": members, "pck": pck_report, "success": True}


def construct_app(directory, engine, build_id, identity):
    app = directory / APP_NAME
    (app / "Contents/MacOS").mkdir(parents=True)
    (app / "Contents/Resources").mkdir()
    shutil.copyfile(engine["path"], app / "Contents/MacOS/StairWreck")
    copied_engine = app / "Contents/MacOS/StairWreck"
    require(copied_engine.stat().st_size == engine["bytes"] and sha256(copied_engine) == engine["sha256"],
            "copied engine differs from tested original before signing")
    (app / "Contents/MacOS/StairWreck").chmod(0o755)
    expected_inputs = {entry["path"]: entry for entry in identity["source_inputs"]}
    for source, target in ((PROJECT / "assets/StairWreck.icns", "StairWreck.icns"),
                           (PROJECT / "docs/GODOT_LICENSE.txt", "GODOT_LICENSE.txt"), (PROJECT / "LICENSE", "GAME_LICENSE.txt")):
        shutil.copyfile(source, app / "Contents/Resources" / target)
        relative = source.relative_to(PROJECT).as_posix()
        require(sha256(app / "Contents/Resources" / target) == expected_inputs[relative]["sha256"],
                f"copied packaging input differs: {relative}")
    run_bounded.write_json(app / "Contents/Resources/build_identity.json", {"build_id": build_id, "identity": identity})
    plist = {"CFBundleExecutable": "StairWreck", "CFBundleIdentifier": "com.stairwreck.game",
             "CFBundleName": "STAIR WRECK", "CFBundleDisplayName": "STAIR // WRECK",
             "CFBundlePackageType": "APPL", "CFBundleShortVersionString": "3.1candidate",
             "CFBundleVersion": "3.1", "CFBundleIconFile": "StairWreck.icns", "StairWreckBuildID": build_id,
             "LSMinimumSystemVersion": engine["declared_minimum_os"], "NSHighResolutionCapable": True}
    (app / "Contents/Info.plist").write_bytes(plistlib.dumps(plist, sort_keys=True))
    return app


def extract_and_verify(directory, report, timeout):
    extraction = directory / ("extracted candidate " + uuid.uuid4().hex[:8])
    extraction.mkdir(exist_ok=False)
    run_check(report, "archive_extract_" + extraction.name[-8:],
              ["/usr/bin/ditto", "-x", "-k", str(directory / ZIP_NAME), str(extraction)], directory, timeout)
    app = extraction / APP_NAME
    validate_app(app, report["build_id"], report["engine"], expected_map=report["app_file_map"])
    run_check(report, "extracted_signature_" + extraction.name[-8:],
              ["/usr/bin/codesign", "--verify", "--deep", "--strict", str(app)], directory, timeout)
    archs = run_check(report, "extracted_architectures_" + extraction.name[-8:],
                      ["/usr/bin/lipo", "-archs", str(app / "Contents/MacOS/StairWreck")], directory, timeout)
    loads = run_check(report, "extracted_load_commands_" + extraction.name[-8:],
                      ["/usr/bin/otool", "-l", str(app / "Contents/MacOS/StairWreck")], directory, timeout)
    metadata = architecture_metadata(archs, loads)
    require(metadata == {key: report["engine"][key] for key in metadata}, "extracted runtime architecture/minimum OS differs")
    report["extraction_path"] = str(extraction)
    report["extracted_app"] = str(app)
    report["bundled_signed_engine"] = file_entry(app / "Contents/MacOS/StairWreck", "Contents/MacOS/StairWreck")
    report["archive_verified"] = True
    run_bounded.write_json(directory / "manifest.json", report)
    return app


def build(args):
    require(PROJECT == args.project_dir.resolve(), "this builder targets its own workspace only")
    runtime_path = args.runtime_result.resolve()
    runtime = json.loads(runtime_path.read_text(encoding="utf-8"))
    current_runtime_digest = run_bounded.source_digest(PROJECT)["sha256"]
    require(runtime.get("success") is True and runtime.get("input_source_digest", {}).get("sha256") == current_runtime_digest and
            runtime.get("input_source_digest_after") == current_runtime_digest, "source differs from successful stable runtime integration report")
    current_cache_digest = run_bounded.import_cache_digest(PROJECT)["sha256"]
    require(runtime.get("input_import_cache_digest_after") == current_cache_digest,
            "existing import cache differs from successful runtime integration report")
    inputs, cache = inventory(PROJECT), import_cache(PROJECT)
    run_id = datetime.datetime.now(datetime.timezone.utc).strftime("%Y%m%dT%H%M%S.%fZ") + "-" + uuid.uuid4().hex[:8]
    # Engine metadata commands are recorded before the canonical build ID exists.
    preparation = PROJECT / "builds/candidates" / ("prepare-" + run_id)
    preparation.mkdir(parents=True, exist_ok=False)
    report = {"schema": SCHEMA, "run_id": run_id, "candidate_status": "preparing", "success": False,
              "build_method": BUILD_METHOD, "clean_import_verified": False, "editor_import_status": "not_run_by_candidate_builder",
              "runtime_integration_report": str(runtime_path), "runtime_integration_report_sha256": sha256(runtime_path),
              "runtime_integration_validation_scope": runtime.get("validation_scope"), "bounded_checks": {},
              "native_acceptance": "unverified", "both_cpu_execution": "unverified", "oldest_os_execution": "unverified",
              "quarantined_launch": "unverified", "packaged_runtime_status": "not_run", "normal_packaged_persistence": "not_run",
              "r13_acceptance_complete": False, "validation_scope": "candidate_archive_integrity_only"}
    if args.import_result:
        report["separate_editor_import_evidence"] = import_evidence(args.import_result)
    directory = preparation
    try:
        engine = inspect_engine(args.engine, report, preparation, args.timeout_seconds)
        engine_matches_report(engine, runtime)
        identity = identity_payload(inputs, cache, engine)
        build_id = hashlib.sha256(canonical(identity)).hexdigest()
        directory = preparation.with_name(build_id + "-" + run_id)
        require(not directory.exists(), "candidate directory already exists")
        preparation.rename(directory)
        # Logs generated before the rename remain real files; repair their stored locations.
        for check in report["bounded_checks"].values():
            for key in ("log", "result"):
                check[key] = str(directory / Path(check[key]).relative_to(preparation))
            run_bounded.write_json(check["result"], check)
        report.update({"build_id": build_id, "identity": identity, "input_inventory": inputs,
                       "input_digest": hashlib.sha256(canonical(inputs)).hexdigest(), "engine": engine,
                       "existing_import_cache": cache, "candidate_directory": str(directory)})
        expected = packed_inputs(inputs, cache)
        report["packed_inputs"] = expected
        staged = stage_files(PROJECT, directory / "stage", expected)
        pack_manifest = directory / "pack_inputs.json"
        run_bounded.write_json(pack_manifest, {"schema": SCHEMA, "files": staged})
        app = construct_app(directory, engine, build_id, identity)
        pck = app / "Contents/MacOS/StairWreck.pck"
        run_check(report, "runtime_pckpacker", [engine["path"], "--headless", "--path", str(directory / "stage"),
                  "--script", str(PROJECT / "tools/pack_candidate.gd"), "--log-file", str(directory / "logs/packer.engine.log"),
                  "--", "--manifest=" + str(pack_manifest), "--output=" + str(pck)], directory, args.timeout_seconds,
                  expected="PACK", cwd=directory / "stage")
        report["pck_entry_verification"] = verify_pck(pck, expected)
        validate_app(app, build_id, engine)
        stable_inputs({"sources": inputs, "cache": cache}, {"sources": inventory(PROJECT), "cache": import_cache(PROJECT)},
                      {key: engine[key] for key in ("path", "bytes", "sha256")}, run_bounded.executable_identity(args.engine))
        run_check(report, "candidate_sign", ["/usr/bin/codesign", "--force", "--deep", "--sign", "-", str(app)], directory, args.timeout_seconds)
        run_check(report, "candidate_signature", ["/usr/bin/codesign", "--verify", "--deep", "--strict", str(app)], directory, args.timeout_seconds)
        report["plist"] = validate_app(app, build_id, engine)
        report["app_file_map"] = app_file_map(app)
        archive = directory / ZIP_NAME
        run_check(report, "candidate_archive", ["/usr/bin/ditto", "-c", "-k", "--sequesterRsrc", "--keepParent", str(app), str(archive)],
                  directory, args.timeout_seconds)
        report["pck"] = file_entry(pck, "Contents/MacOS/StairWreck.pck")
        report["zip"] = file_entry(archive, ZIP_NAME)
        report["archive_verification"] = verify_outputs(directory, report)
        extract_and_verify(directory, report, args.timeout_seconds)
        stable_inputs({"sources": inputs, "cache": cache}, {"sources": inventory(PROJECT), "cache": import_cache(PROJECT)},
                      {key: engine[key] for key in ("path", "bytes", "sha256")}, run_bounded.executable_identity(args.engine))
        require(run_bounded.source_digest(PROJECT)["sha256"] == current_runtime_digest, "tested project changed during candidate construction")
        require(run_bounded.import_cache_digest(PROJECT)["sha256"] == current_cache_digest, "tested import cache changed during candidate construction")
        report.update({"candidate_status": "candidate_archive_verified_runtime_pending", "success": True,
                       "input_hashes_stable": True, "tested_source_digest": current_runtime_digest,
                       "tested_import_cache_digest": current_cache_digest})
        if args.check_runtime:
            check_runtime(directory, report, args.timeout_seconds)
    except (CandidateError, OSError, ValueError, KeyError) as exc:
        report.update({"success": False, "candidate_status": "failed", "error": str(exc)})
        run_bounded.write_json(directory / "manifest.json", report)
        print(f"CANDIDATE: failed: {exc}; manifest {directory / 'manifest.json'}", file=sys.stderr)
        return 1
    run_bounded.write_json(directory / "manifest.json", report)
    print(f"CANDIDATE: {report['candidate_status']}; manifest {directory / 'manifest.json'}")
    print(f"CANDIDATE: build ID {report['build_id']}; ZIP SHA-256 {report['zip']['sha256']}; extracted app {report['extracted_app']}")
    return 0


def check_runtime(directory, report, timeout):
    previous = {key: report[key] for key in ("runtime_check_id", "packaged_runtime_status", "normal_packaged_persistence",
                "packaged_routes", "external_asset_probe", "normal_records_probe", "validation_scope", "error") if key in report}
    if "runtime_check_id" in previous:
        report.setdefault("runtime_check_history", []).append(previous)
    check_id = uuid.uuid4().hex[:8]
    for key in ("packaged_routes", "external_asset_probe", "normal_records_probe", "error"):
        report.pop(key, None)
    report.update({"success": False, "runtime_check_id": check_id, "candidate_status": "candidate_runtime_checks_running",
                   "archive_verified": False, "packaged_runtime_status": "not_run", "normal_packaged_persistence": "not_run",
                   "validation_scope": "candidate_runtime_revalidation_pending"})
    run_bounded.write_json(directory / "manifest.json", report)
    try:
        _check_runtime(directory, report, timeout, check_id)
    except (CandidateError, OSError, ValueError, KeyError) as exc:
        if report["packaged_runtime_status"] == "running":
            report["packaged_runtime_status"] = "failed"
        if report["normal_packaged_persistence"] == "running":
            report["normal_packaged_persistence"] = "failed"
        report.update({"success": False, "candidate_status": "candidate_runtime_checks_failed", "error": str(exc)})
        run_bounded.write_json(directory / "manifest.json", report)
        raise
    report["success"] = True
    run_bounded.write_json(directory / "manifest.json", report)


def _check_runtime(directory, report, timeout, check_id):
    verify_outputs(directory, report)
    app = Path(report["extracted_app"])
    validate_app(app, report["build_id"], report["engine"], expected_map=report["app_file_map"])
    report.update({"archive_verified": True, "validation_scope": "candidate_archive_integrity_only"})
    check_root = directory / ("packaged checks " + check_id)
    cwd = check_root / "unrelated empty cwd"
    cwd.mkdir(parents=True, exist_ok=False)
    executable = app / "Contents/MacOS/StairWreck"
    expected_tools = {entry["path"]: entry["sha256"] for entry in report["input_inventory"]}
    for script in ("tools/package_assets_probe.gd", "tools/packaged_records_probe.gd"):
        require(sha256(PROJECT / script) == expected_tools.get(script), f"external packaged probe changed since candidate identity: {script}")
    report["packaged_runtime_status"] = "running"
    results = []
    for level in range(3):
        case = check_root / ("level" + str(level))
        case.mkdir()
        output = run_check(report, check_id + "_packaged_level" + str(level), [str(executable), "--headless", "--fixed-fps", "60",
                           "--log-file", str(case / "engine.log"), "--", "--self-check", "--level=" + str(level),
                           "--records-path=" + str(case / "records.json")], directory, timeout, cwd=cwd)
        lines = [line.strip() for line in output.splitlines() if line.strip().startswith("SELF_CHECK:")]
        require(len(lines) == 1, f"packaged level {level} requires one SELF_CHECK marker")
        fields = dict(re.findall(r'([a-z_]+)=([^\s]+)', lines[0]))
        require(fields.get("level") == str(level + 1), f"packaged level {level} completed wrong route")
        require(int(fields.get("score", "0")) > 3000 and int(fields.get("wrecks", "0")) >= 4 and
                int(fields.get("frames", "0")) > 0, f"packaged level {level} lacks score/wreck/completion evidence")
        results.append({"requested_level": level, "marker": lines[0], "fields": fields, "records_path": str(case / "records.json")})
    probe = PROJECT / "tools/package_assets_probe.gd"
    output = run_check(report, check_id + "_external_packaged_assets_probe", [str(executable), "--headless", "--script", str(probe),
                       "--log-file", str(check_root / "assets.engine.log")], directory, timeout, cwd=cwd)
    markers = [line.strip() for line in output.splitlines() if line.strip().startswith("PACKAGED_ASSETS:")]
    require(markers == ["PACKAGED_ASSETS: 19 models / 15 audio; 0 failures"], "external packaged asset probe did not satisfy model/audio contracts")
    require(not list(cwd.iterdir()), "unrelated packaged working directory acquired source/runtime files")
    report.update({"packaged_routes": results, "external_asset_probe": {"script": str(probe), "sha256": sha256(probe),
                  "models": 19, "audio": 15, "hero_bones": 11, "taxi_morph": "verified_by_existing_probe", "external": True},
                  "packaged_runtime_status": "passed", "candidate_status": "candidate_runtime_verified_persistence_pending"})
    report["validation_scope"] = "candidate_archive_and_headless_runtime_only"
    run_bounded.write_json(directory / "manifest.json", report)
    report["normal_packaged_persistence"] = "running"
    check_records(directory, report, timeout, executable, check_root, cwd, check_id)


def check_records(directory, report, timeout, executable, check_root, cwd, check_id):
    probe = PROJECT / "tools/packaged_records_probe.gd"
    storage = check_root / "normal isolated records"
    storage.mkdir()
    normal = storage / "normal.json"
    failed = storage / "missing parent" / "retry.json"
    migration = storage / "migration.json"
    unsupported = storage / "future.json"
    run_bounded.write_json(migration, {"version": 1, "best_scores": [111, 222, 333], "muted": True, "hat": 1})
    unsupported.write_bytes(b'{"version":99,"best_scores":[1,2,3],"unknown":{"keep":"exact"}}\n')
    future_before = sha256(unsupported)
    states = []
    for case, records in (("write", normal), ("verify", normal), ("failed-retry", failed), ("verify-failed-retry", failed),
                          ("migrate", migration), ("verify-migrate", migration), ("unsupported", unsupported)):
        case_dir = storage / ("logs " + case)
        case_dir.mkdir()
        output = run_check(report, check_id + "_external_packaged_records_" + case,
                           [str(executable), "--headless", "--fixed-fps", "60", "--script", str(probe),
                            "--log-file", str(case_dir / "engine.log"), "--", "--probe-case=" + case,
                            "--records-path=" + str(records)], directory, timeout, expected="PACKAGED_RECORDS", cwd=cwd)
        markers = [line.strip()[len("PACKAGED_RECORDS_STATE: "):] for line in output.splitlines()
                   if line.strip().startswith("PACKAGED_RECORDS_STATE: ")]
        require(len(markers) == 1, f"packaged normal records case {case} lacks exact state evidence")
        state = json.loads(markers[0])
        require(state.get("case") == case and state.get("selected_path") == str(records) and state.get("read_path") == str(records),
                f"packaged normal records case {case} read a different profile")
        require(state.get("test_mode") is False and state.get("self_check") is False, "normal records probe selected automation storage mode")
        states.append(state)
    expected_profiles = ((normal, [100000,0,0], [0,0,0], True, 2),
                         (failed, [0,150000,0], [0,0,0], True, 2), (migration, [0,0,250000], [111,222,333], True, 1))
    for path, scores, legacy, muted, hat in expected_profiles:
        actual = json.loads(path.read_text(encoding="utf-8"))
        require(actual == {"version":2,"best_scores":scores,"legacy_scores":legacy,"muted":muted,"hat":hat},
                f"external independent durable profile bytes disagree: {path}")
    require(sha256(unsupported) == future_before, "normal packaged probe altered unsupported original profile bytes")
    require(not list(cwd.iterdir()), "normal packaged probe acquired source files in unrelated working directory")
    report.update({"normal_packaged_persistence": "passed", "normal_records_probe": {"external": True,
                   "scope": "controlled bookkeeping fixture; no physical crash/native claim provenance",
                   "script": str(probe), "sha256": sha256(probe), "states": states,
                   "profiles": [file_entry(path, str(path.relative_to(check_root))) for path in (normal,failed,migration,unsupported)]},
                   "candidate_status": "candidate_headless_and_storage_verified_native_pending",
                   "validation_scope": "candidate_archive_headless_runtime_and_isolated_bookkeeping_only"})
    run_bounded.write_json(directory / "manifest.json", report)


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    commands = parser.add_subparsers(dest="command", required=True)
    build_parser = commands.add_parser("build", help="explicit frozen-source build from a successful exact runtime report")
    build_parser.add_argument("--project-dir", type=Path, default=PROJECT)
    build_parser.add_argument("--runtime-result", type=Path, required=True)
    build_parser.add_argument("--import-result", type=Path, help="preserve separate actual editor import outcome; never reclassify it")
    build_parser.add_argument("--engine", default=os.environ.get("GODOT_BIN", "/opt/homebrew/bin/godot"))
    build_parser.add_argument("--timeout-seconds", type=run_bounded.timeout_value, default=180)
    build_parser.add_argument("--check-runtime", action="store_true", help="also run extracted headless routes and external assets; native/persistence remain unverified")
    for name in ("verify", "check-runtime"):
        subparser = commands.add_parser(name, help="verify supplied immutable candidate" if name == "verify" else "run supplied extracted candidate headless checks")
        subparser.add_argument("--candidate", type=Path, required=True)
        subparser.add_argument("--timeout-seconds", type=run_bounded.timeout_value, default=180)
    args = parser.parse_args(argv)
    if args.command == "build":
        try:
            return build(args)
        except (CandidateError, OSError, ValueError) as exc:
            print(f"CANDIDATE: refused before construction: {exc}", file=sys.stderr)
            return 1
    directory = args.candidate.resolve()
    try:
        report = json.loads((directory / "manifest.json").read_text(encoding="utf-8"))
        require(report.get("candidate_directory") == str(directory), "manifest identifies a different candidate path")
        if args.command == "verify":
            verify_outputs(directory, report)
            extract_and_verify(directory, report, args.timeout_seconds)
        else:
            check_runtime(directory, report, args.timeout_seconds)
    except (CandidateError, OSError, ValueError, KeyError) as exc:
        print(f"CANDIDATE: {args.command} failed: {exc}", file=sys.stderr)
        return 1
    print(f"CANDIDATE: {args.command} passed for {report['build_id']}; clean_import_verified=false; native acceptance unverified")
    return 0


if __name__ == "__main__":
    sys.exit(main())
