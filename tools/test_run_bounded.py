#!/usr/bin/env python3
"""Real subprocess negative controls for the runner, independent of game checks.

Generated argv fixtures deliberately emit success/failure text to test its parser.
They are not Godot suites or evidence that the game passes. All evidence is retained.
"""

import datetime
import json
import os
from pathlib import Path
import signal
import subprocess
import sys
import time
import unittest
import uuid

import run_bounded


PROJECT = Path(__file__).resolve().parent.parent
ARTIFACTS = PROJECT / "builds/runner_controls" / (
    datetime.datetime.now(datetime.timezone.utc).strftime("%Y%m%dT%H%M%S.%fZ") + "-" + uuid.uuid4().hex[:8])
HELPER = PROJECT / "tools/run_bounded.py"
GOOD = "RULES: 7 checks, 0 failures\n"
CERT = ('ERROR: Condition "ret != noErr" is true. Returning: ""\n'
        '   at: get_system_ca_certificates (platform/macos/os_macos.mm:1035)\n')


class RunnerControls(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        ARTIFACTS.mkdir(parents=True)
        cls.emitter = ARTIFACTS / "emit fixture.py"
        cls.emitter.write_text(
            "import json, sys\n"
            "spec = json.loads(sys.argv[1])\n"
            "sys.stdout.write(spec.get('stdout', ''))\n"
            "sys.stderr.write(spec.get('stderr', ''))\n"
            "sys.exit(spec.get('exit', 0))\n", encoding="utf-8")

    def fixture(self, name, output, *, stderr="", exit_code=0, expected_success=False):
        directory = ARTIFACTS / name
        directory.mkdir()
        spec = {"stdout": output, "stderr": stderr, "exit": exit_code}
        command = [sys.executable, str(HELPER), "--timeout-seconds", "10", "--log", str(directory / "output.log"),
                   "--expected-summary", "RULES", "--", sys.executable, str(self.emitter), json.dumps(spec)]
        caller = subprocess.run(command, capture_output=True, text=True, timeout=15)
        (directory / "caller.output.log").write_text(caller.stdout + caller.stderr, encoding="utf-8")
        result = json.loads((directory / "output.log.result.json").read_text(encoding="utf-8"))
        self.assertEqual(caller.returncode, 0 if expected_success else 1, caller.stdout + caller.stderr)
        self.assertEqual(result["success"], expected_success, result)
        self.assertEqual(result["exit_code"], exit_code)
        self.assertEqual(result["command"], [sys.executable, str(self.emitter), json.dumps(spec)])
        self.assertIn(output, Path(result["log"]).read_text(encoding="utf-8"))
        return result

    def test_success_and_combined_stderr(self):
        result = self.fixture("success", GOOD.rstrip() + "; useful telemetry\n", stderr="fixture stderr\n",
                              expected_success=True)
        self.assertEqual(result["summaries"][0]["checks"], 7)
        self.assertIn("fixture stderr", Path(result["log"]).read_text())

    def test_generic_command_allows_external_probe_telemetry_but_rejects_errors(self):
        # The pre-existing external asset probe has its own non-suite count format.
        output = "PACKAGED_ASSETS: 19 models / 15 audio; 0 failures\n"
        self.assertEqual(run_bounded.inspect_output(output)["errors"], [])
        self.assertTrue(run_bounded.inspect_output(output + "ERROR: probe failed\n")["errors"])
        self.assertTrue(run_bounded.inspect_output(output, "PACKAGED_ASSETS")["errors"])

    def test_early_zero_exit(self):
        self.fixture("early_zero_exit", "")

    def test_missing_marker(self):
        self.fixture("missing_marker", "ran some work without completing\n")

    def test_zero_checks(self):
        self.fixture("zero_checks", "RULES: 0 checks, 0 failures\n")

    def test_wrong_name(self):
        self.fixture("wrong_name", "INPUTS: 7 checks, 0 failures\n")

    def test_duplicate_marker(self):
        self.fixture("duplicate_marker", GOOD + GOOD)

    def test_unknown_marker_alongside_expected(self):
        self.fixture("unknown_marker", GOOD + "SURPRISE: 2 checks, 0 failures\n")

    def test_malformed_marker(self):
        for number, marker in enumerate(("RULES: seven checks, 0 failures\n", "RULES: 7 checks 0 failures\n",
                                         "RULES: 7 checks, 0 failures garbage\n", "RULES: done\n")):
            with self.subTest(marker=marker):
                self.fixture(f"malformed_{number}", marker)

    def test_nonzero_failures(self):
        self.fixture("nonzero_failures", "RULES: 7 checks, 1 failures\n")

    def test_nonzero_exit_after_marker(self):
        self.fixture("nonzero_exit", GOOD, exit_code=9)

    def test_script_error_zero_exit(self):
        self.fixture("script_error", GOOD, stderr="SCRIPT ERROR: a real parser control\n")

    def test_other_fatal_diagnostics(self):
        diagnostics = ("Parse Error: fixture", "Compile Error: fixture", "FAIL: fixture",
                       "ERROR: unexpected fixture", "WARNING: ObjectDB instances leaked at exit",
                       "WARNING: 1 resources still in use at exit")
        for number, diagnostic in enumerate(diagnostics):
            with self.subTest(diagnostic=diagnostic):
                self.fixture(f"fatal_{number}", GOOD + diagnostic + "\n")

    def test_exact_certificate_diagnostic(self):
        result = self.fixture("certificate_only", CERT + GOOD, expected_success=True)
        self.assertEqual(len(result["ignored_diagnostics"]), 1)

    def test_certificate_does_not_hide_script_error(self):
        self.fixture("certificate_then_script_error", CERT + "SCRIPT ERROR: fixture\n" + GOOD)

    def test_certificate_exemption_requires_exact_adjacent_location(self):
        for number, output in enumerate((CERT.replace(":1035", ":9999") + GOOD,
                                         CERT.splitlines()[0] + "\n" + GOOD,
                                         CERT.splitlines()[0] + "\nERROR: later failure\n" +
                                         CERT.splitlines()[1] + "\n" + GOOD)):
            with self.subTest(output=output):
                result = self.fixture(f"certificate_not_exact_{number}", output)
                self.assertEqual(result["ignored_diagnostics"], [])

    def test_timeout_bounds_and_no_command(self):
        for value in ("0", "9", "601", "nan", "inf", "-1", "nope"):
            with self.subTest(value=value):
                caller = subprocess.run([sys.executable, str(HELPER), "--timeout-seconds", value,
                                         "--log", str(ARTIFACTS / "invalid.log"), "--", sys.executable, "-c", "pass"],
                                        capture_output=True, text=True, timeout=5)
                self.assertEqual(caller.returncode, 2)
        for value in ("10", "600"):
            caller = subprocess.run([sys.executable, str(HELPER), "--timeout-seconds", value,
                                     "--log", str(ARTIFACTS / ("bound_" + value + ".log")), "--",
                                     sys.executable, "-c", "pass"], capture_output=True, text=True, timeout=5)
            self.assertEqual(caller.returncode, 0, caller.stderr)
        caller = subprocess.run([sys.executable, str(HELPER), "--log", str(ARTIFACTS / "missing_command.log")],
                                capture_output=True, text=True, timeout=5)
        self.assertEqual(caller.returncode, 2)

    def test_paths_and_argv_preserve_spaces_and_shell_syntax(self):
        directory = ARTIFACTS / "space directory $(literal)"
        directory.mkdir()
        path = directory / "argv fixture.py"
        values = ["space value", "$(must stay literal)", "semi;colon", "quote'and\"quote"]
        path.write_text("import json, sys\nprint(json.dumps(sys.argv[1:]))\nprint('RULES: 1 checks, 0 failures')\n")
        result = run_bounded.run_command([sys.executable, str(path), *values], 10, directory / "output.log",
                                         expected_summary="RULES")
        self.assertTrue(result["success"], result)
        self.assertEqual(json.loads((directory / "output.log").read_text().splitlines()[0]), values)

    @unittest.skipUnless(os.name == "posix", "POSIX group-liveness control")
    def test_timeout_kills_ignoring_descendant_and_returns_nonzero(self):
        directory = ARTIFACTS / "timeout"
        directory.mkdir()
        pid_file = directory / "child.pid"
        hanging = directory / "hang.py"
        hanging.write_text(
            "import os, pathlib, signal, subprocess, sys, time\n"
            "signal.signal(signal.SIGTERM, signal.SIG_IGN)\n"
            "if sys.argv[1] == 'child':\n"
            "    pathlib.Path(sys.argv[2]).write_text(str(os.getpid()))\n"
            "    while True: time.sleep(1)\n"
            "child = subprocess.Popen([sys.executable, __file__, 'child', sys.argv[2]])\n"
            "print('RULES: 1 checks, 0 failures', flush=True)\n"
            "child.wait()\n", encoding="utf-8")
        # The public CLI cannot select sub-10-second limits. This internal caller
        # still returns the real helper result as its process status.
        invocation = (
            "import pathlib,sys;sys.path.insert(0,sys.argv[1]);import run_bounded;"
            "r=run_bounded.run_command([sys.executable,sys.argv[2],'parent',sys.argv[3]],"
            "0.35,pathlib.Path(sys.argv[4]),expected_summary='RULES');sys.exit(0 if r['success'] else 1)"
        )
        caller = subprocess.run([sys.executable, "-c", invocation, str(PROJECT / "tools"), str(hanging),
                                 str(pid_file), str(directory / "output.log")], capture_output=True, text=True, timeout=5)
        self.assertEqual(caller.returncode, 1, caller.stderr)
        result = json.loads((directory / "output.log.result.json").read_text())
        self.assertTrue(result["timed_out"])
        self.assertFalse(result["success"])
        self.assertLess(result["elapsed_seconds"], 3)
        child_pid = int(pid_file.read_text())
        alive = True
        for _ in range(20):
            try:
                os.kill(child_pid, 0)
            except ProcessLookupError:
                alive = False
                break
            time.sleep(0.05)
        self.assertFalse(alive, f"fixture child {child_pid} remains alive after deadline cleanup")

    @unittest.skipUnless(os.name == "posix", "POSIX process-group control")
    def test_leader_exit_cannot_leave_hanging_child_or_publish_success(self):
        directory = ARTIFACTS / "leader_exits"
        directory.mkdir()
        script = directory / "orphan fixture.py"
        pid_file = directory / "child.pid"
        script.write_text(
            "import os,pathlib,signal,subprocess,sys,time\n"
            "path=pathlib.Path(sys.argv[2])\n"
            "if sys.argv[1]=='child':\n"
            "    signal.signal(signal.SIGTERM,signal.SIG_IGN)\n"
            "    path.write_text(str(os.getpid()))\n"
            "    while True: time.sleep(1)\n"
            "subprocess.Popen([sys.executable,__file__,'child',str(path)])\n"
            "while not path.exists(): time.sleep(0.01)\n"
            "print('RULES: 1 checks, 0 failures')\n", encoding="utf-8")
        caller = subprocess.run([sys.executable, str(HELPER), "--log", str(directory / "output.log"),
                                 "--expected-summary", "RULES", "--", sys.executable, str(script), "parent", str(pid_file)],
                                capture_output=True, text=True, timeout=5)
        self.assertEqual(caller.returncode, 1, caller.stdout + caller.stderr)
        result = json.loads((directory / "output.log.result.json").read_text())
        self.assertEqual(result["exit_code"], 0)
        self.assertFalse(result["success"])
        child_pid = int(pid_file.read_text())
        with self.assertRaises(ProcessLookupError):
            os.kill(child_pid, 0)

    def test_fourteenth_registered_suite_is_mandatory(self):
        project = ARTIFACTS / "registered project with spaces"
        (project / "tests").mkdir(parents=True)
        (project / "tools").mkdir()
        registry = []
        for number in range(1, 15):
            script = f"tests/test_fixture_{number:02}.gd"
            (project / script).write_text(json.dumps({"summary": f"FIXTURE_{number:02}", "mode": "success"}))
            registry.append({"script": script, "summary": f"FIXTURE_{number:02}", "timeout_seconds": 180})
        registry_path = project / "tools/test_suites.json"
        registry_path.write_text(json.dumps(registry))
        engine = project / "tools/fixture engine"
        engine.write_text(
            "#!/usr/bin/env python3\n"
            "import json,pathlib,sys\n"
            "args=sys.argv[1:]\n"
            "if '--version' in args: print('argv fixture engine 1');sys.exit(0)\n"
            "if '--import' in args:\n"
            "    if pathlib.Path('import_error').exists(): print('ERROR: unexpected import fixture error')\n"
            "    sys.exit(0)\n"
            "spec=json.loads(pathlib.Path(args[args.index('--script')+1]).read_text())\n"
            "if spec['mode']=='missing': print('fixture exited early');sys.exit(0)\n"
            "name='FIXTURE_01' if spec['mode']=='wrong' else spec['summary']\n"
            "print(name+': 1 checks, 0 failures')\n", encoding="utf-8")
        engine.chmod(0o755)
        for mode in ("success", "missing", "wrong", "import_failure", "runtime_only"):
            with self.subTest(mode=mode):
                script_mode = mode if mode in ("missing", "wrong") else "success"
                (project / registry[-1]["script"]).write_text(json.dumps({"summary": "FIXTURE_14", "mode": script_mode}))
                if mode == "import_failure":
                    (project / "import_error").write_text("explicit import error control")
                before = run_bounded.source_digest(project)["sha256"]
                caller = subprocess.run([sys.executable, str(HELPER), "suite", "--project-dir", str(project),
                                         "--engine", str(engine), "--registry", str(registry_path)] +
                                        (["--runtime-only"] if mode == "runtime_only" else []),
                                        capture_output=True, text=True, timeout=20)
                (project / (mode + ".caller.output.log")).write_text(caller.stdout + caller.stderr)
                results = sorted((project / "builds/test_runs").glob("*/result.json"))
                report = json.loads(results[-1].read_text())
                success = mode in ("success", "runtime_only")
                self.assertEqual(caller.returncode, 0 if success else 1, caller.stdout + caller.stderr)
                self.assertEqual(report["success"], success)
                self.assertEqual(len(report["expected_suites"]), 14)
                self.assertEqual(report["completed_suites"], 0 if mode == "import_failure" else 14)
                self.assertEqual(report["total_checks"], 14 if success else (0 if mode == "import_failure" else 13))
                self.assertEqual(report["input_source_digest"]["sha256"], before)
                self.assertEqual(report["input_source_digest_after"], before)
                self.assertEqual(report["engine_version"], "argv fixture engine 1")
                self.assertEqual(report["engine_executable"], run_bounded.executable_identity(engine))
                self.assertEqual(report["engine_executable_after"], report["engine_executable"])
                self.assertEqual(report["input_import_cache_digest_after"], run_bounded.import_cache_digest(project)["sha256"])
                if mode == "runtime_only":
                    self.assertEqual(report["import_status"], "not_run_runtime_only")
                    self.assertEqual(report["validation_scope"], "runtime_suites_only")
                    self.assertNotIn("import", report)
                    self.assertIn("runtime suites only (import not run)", caller.stdout)
                else:
                    self.assertEqual(report["import_status"], "failed" if mode == "import_failure" else "passed")
                    self.assertEqual(report["validation_scope"], "import_and_runtime_suites")
                records = [entry["records_path"] for entry in report["suites"]]
                self.assertEqual(len(set(records)), 0 if mode == "import_failure" else 14)
                self.assertTrue(all(str(project / "builds/test_runs" / report["run_id"]) in path for path in records))

    def test_duplicate_registry_is_rejected(self):
        project = ARTIFACTS / "invalid registry"
        project.mkdir()
        (project / "suite.gd").write_text("fixture")
        path = project / "registry.json"
        entry = {"script": "suite.gd", "summary": "DUPLICATE", "timeout_seconds": 180}
        path.write_text(json.dumps([entry, entry]))
        with self.assertRaisesRegex(ValueError, "duplicate"):
            run_bounded.load_registry(path, project)


if __name__ == "__main__":
    suite = unittest.defaultTestLoader.loadTestsFromTestCase(RunnerControls)
    outcome = unittest.TextTestRunner(verbosity=2).run(suite)
    run_bounded.write_json(ARTIFACTS / "result.json", {
        "success": outcome.wasSuccessful(), "tests_run": outcome.testsRun,
        "failures": [{"test": str(test), "detail": detail} for test, detail in outcome.failures],
        "errors": [{"test": str(test), "detail": detail} for test, detail in outcome.errors],
        "skipped": [{"test": str(test), "reason": reason} for test, reason in outcome.skipped],
        "artifacts": str(ARTIFACTS),
        "scope": "runner subprocess controls; no Godot/game validation"})
    print(f"Runner control artifacts: {ARTIFACTS}")
    sys.exit(0 if outcome.wasSuccessful() else 1)
