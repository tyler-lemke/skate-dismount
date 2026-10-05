#!/usr/bin/env python3
"""Candidate verifier controls using real disposable archives/files.

These are deliberate corrupt package fixtures, not packaged-game success proof.
No preserved public artifact is modified and no engine process is launched.
"""

import datetime
import hashlib
import json
import os
from pathlib import Path
import plistlib
import stat
import struct
import subprocess
import sys
import unittest
import uuid
import zipfile

import build_candidate as candidate
import run_bounded


ARTIFACTS = candidate.PROJECT / "builds/candidate_controls" / (
    datetime.datetime.now(datetime.timezone.utc).strftime("%Y%m%dT%H%M%S.%fZ") + "-" + uuid.uuid4().hex[:8])


class CandidateControls(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        ARTIFACTS.mkdir(parents=True)
        cls.actual_engine = run_bounded.executable_identity("/opt/homebrew/bin/godot")
        cls.engine = {**cls.actual_engine, "version": "4.7.2.stable.official.ed1daf0bf",
                      "architectures": ["arm64", "x86_64"], "slice_minimum_os": ["10.13", "11.0"], "declared_minimum_os": "11.0"}
        cls.identity = candidate.identity_payload([], {"files": [], "import_settings_regenerated": False}, cls.engine)
        cls.build_id = hashlib.sha256(candidate.canonical(cls.identity)).hexdigest()

    def fixture(self, name):
        directory = ARTIFACTS / name
        directory.mkdir()
        app = directory / candidate.APP_NAME
        (app / "Contents/MacOS").mkdir(parents=True)
        (app / "Contents/Resources").mkdir()
        for relative, content in (("Contents/MacOS/StairWreck", b"disposable executable-mode fixture\n"),
                                  ("Contents/MacOS/StairWreck.pck", b"disposable pack hash fixture\n"),
                                  ("Contents/Resources/StairWreck.icns", b"icon fixture"),
                                  ("Contents/Resources/GODOT_LICENSE.txt", b"Godot fixture license"),
                                  ("Contents/Resources/GAME_LICENSE.txt", b"game fixture license")):
            (app / relative).write_bytes(content)
        (app / "Contents/MacOS/StairWreck").chmod(0o755)
        plist = {"CFBundleExecutable": "StairWreck", "CFBundleName": "STAIR WRECK", "CFBundleShortVersionString": "3.1candidate",
                 "StairWreckBuildID": self.build_id, "LSMinimumSystemVersion": "11.0"}
        (app / "Contents/Info.plist").write_bytes(plistlib.dumps(plist))
        run_bounded.write_json(app / "Contents/Resources/build_identity.json", {"build_id": self.build_id, "identity": self.identity})
        return directory, app, candidate.app_file_map(app)

    def archive(self, directory, app, *, omit=None, extra=None, duplicate=None, symlink=None):
        path = directory / candidate.ZIP_NAME
        with zipfile.ZipFile(path, "w", compression=zipfile.ZIP_STORED) as archive:
            for source in sorted(app.rglob("*")):
                if not source.is_file():
                    continue
                name = candidate.APP_NAME + "/" + source.relative_to(app).as_posix()
                if name == omit:
                    continue
                info = zipfile.ZipInfo(name)
                info.external_attr = (stat.S_IFREG | stat.S_IMODE(source.stat().st_mode)) << 16
                archive.writestr(info, source.read_bytes())
                if name == duplicate:
                    archive.writestr(info, source.read_bytes())
            if extra:
                archive.writestr(extra, b"unexpected member")
            if symlink:
                info = zipfile.ZipInfo(symlink)
                info.external_attr = (stat.S_IFLNK | 0o777) << 16
                archive.writestr(info, b"../../outside")
        return path

    def rejects(self, expected, operation):
        with self.assertRaisesRegex(candidate.CandidateError, expected) as caught:
            operation()
        path = ARTIFACTS / (self._testMethodName + ".diagnostic.json")
        run_bounded.write_json(path, {"expected_gate": expected, "actual_diagnostic": str(caught.exception), "rejected": True})

    def test_correct_fixture_archive_and_bytes(self):
        directory, app, expected = self.fixture("valid archive with spaces")
        archive = self.archive(directory, app)
        members = candidate.verify_zip(archive, expected)
        self.assertEqual(len(members), len(expected))
        candidate.validate_app(app, self.build_id, self.engine, expected_map=expected)
        self.assertEqual(candidate.sha256(archive), hashlib.sha256(archive.read_bytes()).hexdigest())

    def test_corrupt_zip_crc(self):
        directory, app, expected = self.fixture("CRC corruption")
        archive = self.archive(directory, app)
        with zipfile.ZipFile(archive) as source:
            info = source.infolist()[0]
            with archive.open("r+b") as stream:
                stream.seek(info.header_offset)
                header = stream.read(30)
                name_len, extra_len = struct.unpack_from("<HH", header, 26)
                stream.seek(info.header_offset + 30 + name_len + extra_len)
                byte = stream.read(1)
                stream.seek(-1, os.SEEK_CUR)
                stream.write(bytes([byte[0] ^ 0x40]))
        self.rejects("CRC/structure", lambda: candidate.verify_zip(archive, expected))

    def test_stale_zip_app_mismatch(self):
        directory, app, expected = self.fixture("stale archive")
        archive = self.archive(directory, app)
        (app / "Contents/MacOS/StairWreck.pck").write_bytes(b"different live app PCK bytes\n")
        self.rejects("size mismatch|checksum mismatch", lambda: candidate.verify_zip(archive, candidate.app_file_map(app)))

    def test_archive_manifest_checksum_and_supplied_candidate_cli(self):
        directory, app, expected = self.fixture("supplied candidate CLI")
        archive = self.archive(directory, app)
        report = {"candidate_directory": str(directory), "build_id": self.build_id, "engine": self.engine,
                  "app_file_map": expected, "zip": candidate.file_entry(archive, candidate.ZIP_NAME)}
        with archive.open("ab") as stream:
            stream.write(b"tampered archive trailing bytes")
        run_bounded.write_json(directory / "manifest.json", report)
        caller = subprocess.run([sys.executable, str(candidate.PROJECT / "tools/build_candidate.py"), "verify", "--candidate", str(directory)],
                                capture_output=True, text=True, timeout=10)
        (directory / "caller.output.log").write_text(caller.stdout + caller.stderr)
        self.assertEqual(caller.returncode, 1)
        self.assertIn("ZIP digest/size differs", caller.stderr)
        self.rejects("ZIP digest/size differs", lambda: candidate.verify_outputs(directory, report))

    def test_manifest_identifies_wrong_candidate_path(self):
        directory = ARTIFACTS / "wrong candidate identity"
        directory.mkdir()
        run_bounded.write_json(directory / "manifest.json", {"candidate_directory": str(directory / "other")})
        caller = subprocess.run([sys.executable, str(candidate.PROJECT / "tools/build_candidate.py"), "verify", "--candidate", str(directory)],
                                capture_output=True, text=True, timeout=10)
        (directory / "caller.output.log").write_text(caller.stdout + caller.stderr)
        self.assertEqual(caller.returncode, 1)
        self.assertIn("manifest identifies a different candidate path", caller.stderr)

    def test_missing_runtime_member(self):
        directory, app, expected = self.fixture("missing member")
        archive = self.archive(directory, app, omit=candidate.APP_NAME + "/Contents/MacOS/StairWreck.pck")
        self.rejects("missing runtime", lambda: candidate.verify_zip(archive, expected))

    def test_traversal_absolute_and_backslash_paths(self):
        for number, path in enumerate(("../escaped", "/absolute", "StairWreck.app/../escaped", "StairWreck.app\\escaped")):
            with self.subTest(path=path):
                directory, app, expected = self.fixture("unsafe" + str(number))
                archive = self.archive(directory, app, extra=path)
                self.rejects("unsafe archive path", lambda: candidate.verify_zip(archive, expected))

    def test_unexpected_runtime_file(self):
        directory, app, expected = self.fixture("extra runtime member")
        archive = self.archive(directory, app, extra=candidate.APP_NAME + "/Contents/test-only.txt")
        self.rejects("unexpected runtime", lambda: candidate.verify_zip(archive, expected))

    def test_documented_appledouble_metadata_and_invalid_metadata(self):
        directory, app, expected = self.fixture("AppleDouble metadata")
        archive = self.archive(directory, app)
        name = "__MACOSX/" + candidate.APP_NAME + "/Contents/Resources/._GAME_LICENSE.txt"
        with zipfile.ZipFile(archive, "a") as target:
            target.writestr(name, struct.pack(">II16sH", 0x00051607, 0x00020000, b"\0" * 16, 0))
        members = candidate.verify_zip(archive, expected)
        self.assertEqual(len([entry for entry in members if entry["metadata"]]), 1)
        bad_directory, bad_app, bad_expected = self.fixture("invalid metadata")
        bad_archive = self.archive(bad_directory, bad_app, extra=name)
        self.rejects("invalid AppleDouble", lambda: candidate.verify_zip(bad_archive, bad_expected))

    def test_escaping_symlink(self):
        directory, app, expected = self.fixture("escaping symlink")
        archive = self.archive(directory, app, symlink=candidate.APP_NAME + "/Contents/escape")
        self.rejects("symlink", lambda: candidate.verify_zip(archive, expected))

    def test_duplicate_archive_member(self):
        directory, app, expected = self.fixture("duplicate member")
        archive = self.archive(directory, app, duplicate=candidate.APP_NAME + "/Contents/MacOS/StairWreck.pck")
        self.rejects("duplicate archive", lambda: candidate.verify_zip(archive, expected))

    def test_bad_plist_build_id(self):
        directory, app, expected = self.fixture("bad plist ID")
        path = app / "Contents/Info.plist"
        plist = plistlib.loads(path.read_bytes())
        plist["StairWreckBuildID"] = "stale"
        path.write_bytes(plistlib.dumps(plist))
        self.rejects("plist StairWreckBuildID", lambda: candidate.validate_app(app, self.build_id, self.engine))

    def test_bad_embedded_identity(self):
        directory, app, expected = self.fixture("bad embedded engine ID")
        path = app / "Contents/Resources/build_identity.json"
        identity = json.loads(path.read_text())
        identity["identity"]["engine"]["sha256"] = "0" * 64
        run_bounded.write_json(path, identity)
        self.rejects("canonical source/engine identity", lambda: candidate.validate_app(app, self.build_id, self.engine))

    def test_nonexecutable_runtime_mode(self):
        directory, app, expected = self.fixture("nonexecutable runtime")
        (app / "Contents/MacOS/StairWreck").chmod(0o644)
        self.rejects("executable mode", lambda: candidate.validate_app(app, self.build_id, self.engine))

    def test_altered_pack_hash(self):
        directory, app, expected = self.fixture("altered PCK")
        (app / "Contents/MacOS/StairWreck.pck").write_bytes(b"tampered disposable pack\n")
        self.rejects("app file bytes", lambda: candidate.validate_app(app, self.build_id, self.engine, expected_map=expected))

    def test_source_mutation_during_construction(self):
        path = ARTIFACTS / "mutated authored input.gd"
        path.write_text("before\n")
        before = candidate.file_entry(path, path.name)
        path.write_text("after mutation\n")
        after = candidate.file_entry(path, path.name)
        self.rejects("source or existing import cache changed", lambda: candidate.stable_inputs(before, after, self.actual_engine, self.actual_engine))

    def test_engine_identity_mismatch(self):
        report = {"success": True, "engine_version": self.engine["version"], "engine_executable": self.actual_engine,
                  "engine_executable_after": self.actual_engine}
        candidate.engine_matches_report(self.engine, report)
        wrong = {**self.engine, "sha256": "0" * 64}
        self.rejects("engine executable identity", lambda: candidate.engine_matches_report(wrong, report))

    def test_preserved_legacy_import_failure_is_read_truthfully(self):
        path = candidate.PROJECT / "builds/test_runs/20261005T021641.874148Z-5053-b6376428/result.json"
        before = candidate.sha256(path)
        evidence = candidate.import_evidence(path)
        self.assertEqual(evidence["import_status"], "failed")
        self.assertEqual(evidence["engine_exit_code"], 0)
        self.assertEqual(len(evidence["unexpected_diagnostics"]), 3)
        self.assertEqual(candidate.sha256(path), before)
        self.assertTrue(evidence["historical_evidence"])
        altered = json.loads(path.read_text())
        altered["import_status"] = "passed"
        bad = ARTIFACTS / "false import success.json"
        run_bounded.write_json(bad, altered)
        self.rejects("import status contradicts", lambda: candidate.import_evidence(bad))

    def test_real_single_architecture_engine_rejected(self):
        directory = ARTIFACTS / "actual thin engine control"
        directory.mkdir()
        thin = directory / "Godot-arm64"
        result = run_bounded.run_command(["/usr/bin/lipo", self.actual_engine["path"], "-thin", "arm64", "-output", str(thin)],
                                         30, directory / "thin.output.log")
        self.assertTrue(result["success"], result)
        result = run_bounded.run_command(["/usr/bin/lipo", "-archs", str(thin)], 10, directory / "architectures.output.log")
        self.assertTrue(result["success"], result)
        archs = Path(result["log"]).read_text().strip()
        self.assertEqual(archs, "arm64")
        self.rejects("must contain x86_64 and arm64", lambda: candidate.architecture_metadata(archs, ""))
        self.assertNotEqual(candidate.sha256(thin), self.actual_engine["sha256"])

    def test_actual_engine_minimum_os_commands_only(self):
        directory = ARTIFACTS / "actual engine minimum OS metadata"
        directory.mkdir()
        result = run_bounded.run_command(["/usr/bin/otool", "-l", self.actual_engine["path"]], 10, directory / "load_commands.output.log")
        self.assertTrue(result["success"], result)
        metadata = candidate.architecture_metadata("x86_64 arm64", Path(result["log"]).read_text())
        self.assertEqual(metadata["declared_minimum_os"], "11.0")
        self.assertEqual({entry["architecture"]:entry["minimum_os"] for entry in metadata["slice_metadata"]},
                         {"x86_64":"10.13","arm64":"11.0"})
        self.assertEqual({entry["architecture"]:entry["load_command"] for entry in metadata["slice_metadata"]},
                         {"x86_64":"LC_VERSION_MIN_MACOSX","arm64":"LC_BUILD_VERSION"})
        run_bounded.write_json(directory / "metadata.json", metadata)

    def test_actual_original_pack_reader_and_tampered_copy(self):
        original = candidate.PROJECT / "builds/StairWreck.app/Contents/MacOS/StairWreck.pck"
        before = candidate.sha256(original)
        parsed = candidate.read_pck(original)
        self.assertEqual(parsed["format"], 4)
        self.assertGreater(len(parsed["files"]), 35)
        copy = ARTIFACTS / "tampered baseline-copy.pck"
        copy.write_bytes(original.read_bytes())
        with copy.open("r+b") as stream:
            stream.seek(112)
            byte = stream.read(1)
            stream.seek(-1, os.SEEK_CUR)
            stream.write(bytes([byte[0] ^ 0x10]))
        self.rejects("PCK entry checksum", lambda: candidate.read_pck(copy))
        self.assertEqual(candidate.sha256(original), before)

    def test_existing_import_cache_actual_source_and_destination_hashes(self):
        cache = candidate.import_cache(candidate.PROJECT)
        self.assertEqual(len(cache["source_destination_md5_checks"]), 35)
        self.assertEqual(len(cache["files"]), 36)
        self.assertFalse(cache["import_settings_regenerated"])

    def test_bounded_packaged_process_timeout_gate(self):
        directory = ARTIFACTS / "packaged timeout control"
        directory.mkdir()
        # Timeout plumbing is exercised with a real hanging child, not an engine run.
        report = {}
        self.rejects("deadline exceeded", lambda: candidate.run_check(report, "hang", [sys.executable, "-c", "import time;time.sleep(30)"],
                                                                          directory, 0.2))
        self.assertTrue(report["bounded_checks"]["hang"]["timed_out"])
        self.assertFalse(report["bounded_checks"]["hang"]["success"])


if __name__ == "__main__":
    suite = unittest.defaultTestLoader.loadTestsFromTestCase(CandidateControls)
    outcome = unittest.TextTestRunner(verbosity=2).run(suite)
    run_bounded.write_json(ARTIFACTS / "result.json", {
        "success": outcome.wasSuccessful(), "tests_run": outcome.testsRun,
        "failures": [{"test": str(test), "detail": detail} for test, detail in outcome.failures],
        "errors": [{"test": str(test), "detail": detail} for test, detail in outcome.errors],
        "artifacts": str(ARTIFACTS), "scope": "candidate verifier corrupt file/archive controls; no packaged-game or native acceptance"})
    print(f"Candidate control artifacts: {ARTIFACTS}")
    sys.exit(0 if outcome.wasSuccessful() else 1)
