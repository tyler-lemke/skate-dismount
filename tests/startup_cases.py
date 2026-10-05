#!/usr/bin/env python3
"""Cold startup oracles. All engine processes and poison data stay in this suite."""
import argparse
import importlib.util
import json
from pathlib import Path
import shutil
import subprocess
import sys
import time

PREFIX = "STARTUP_OBSERVATION: "


class StartupChecks:
    def __init__(self, engine, project, directory):
        self.engine = engine
        self.original_project = project
        self.directory = directory
        self.project = directory / "cold_project"
        self.checks = 0
        self.failures = 0
        self.cases = []

        # Share the runner's narrowly scoped diagnostic classifier. Never write
        # Python caches into a host user directory during a regression run.
        sys.dont_write_bytecode = True
        spec = importlib.util.spec_from_file_location("startup_runner_contract", project / "tools" / "run_bounded.py")
        module = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(module)
        self.inspect_output = module.inspect_output

    def check(self, condition, message):
        self.checks += 1
        if not condition:
            self.failures += 1
            print("FAIL: " + message, flush=True)

    def copy_project(self):
        # Copy imported assets too: no second import competes with the runner.
        self.project.mkdir()
        shutil.copy2(self.original_project / "project.godot", self.project / "project.godot")
        for name in ("assets", "scripts", "scenes", "tests", ".godot"):
            shutil.copytree(self.original_project / name, self.project / name)
        self.write_json(self.project / "builds" / "test_records.json", {
            "version": 2, "best_scores": [901001, 902002, 903003],
            "legacy_scores": [801001, 802002, 803003], "muted": False, "hat": 1,
        })

    @staticmethod
    def write_json(path, data):
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(json.dumps(data), encoding="utf-8")
        return path

    def record(self, name, scores=(11, 22, 33), muted=True, hat=2, version=2):
        return self.write_json(self.directory / "cases" / name / "records.json", {
            "version": version, "best_scores": list(scores),
            "legacy_scores": [101, 202, 303] if version == 2 else [],
            "muted": muted, "hat": hat,
        })

    def launch(self, name, arguments):
        case_dir = self.directory / "cases" / name
        case_dir.mkdir(parents=True, exist_ok=True)
        engine_log = case_dir / "engine.log"
        output_log = case_dir / "output.log"
        command = [self.engine, "--headless", "--path", str(self.project),
                   "--script", "res://tests/startup_case.gd", "--log-file", str(engine_log),
                   "--", *arguments]
        started = time.monotonic()
        output_file = output_log.open("w", encoding="utf-8")
        process = subprocess.Popen(command, stdout=output_file, stderr=subprocess.STDOUT)
        return process, output_file, started, {
            "name": name, "command": command, "output_log": str(output_log),
            "engine_log": str(engine_log),
        }

    def finish(self, pending, expected_exit=0):
        process, output_file, started, result = pending
        timed_out = False
        try:
            code = process.wait(timeout=30)
        except subprocess.TimeoutExpired:
            timed_out = True
            process.kill()
            code = process.wait(timeout=5)
        finally:
            output_file.close()
        output = Path(result["output_log"]).read_text(encoding="utf-8", errors="replace")
        result.update(exit_code=code, elapsed_seconds=time.monotonic()-started, timeout=timed_out)
        observations = [line[len(PREFIX):] for line in output.splitlines() if line.startswith(PREFIX)]
        observation = {}
        if len(observations) == 1:
            try:
                observation = json.loads(observations[0])
            except json.JSONDecodeError:
                pass
        result["observation"] = observation
        self.cases.append(result)
        self.check(not timed_out and code == expected_exit,
                   result["name"] + " has its expected bounded engine exit")
        self.check(len(observations) == 1 and bool(observation),
                   result["name"] + " emits exactly one real startup observation")
        self.check("SCRIPT ERROR" not in output and "Parse Error" not in output and "Compile Error" not in output,
                   result["name"] + " has no script or compilation error")
        classified_output = output
        if expected_exit == 2 and observation.get("error"):
            expected_error = "ERROR: STARTUP: " + observation["error"]
            exact_errors = [line for line in output.splitlines() if line.strip() == expected_error]
            self.check(len(exact_errors) == 1, result["name"] + " emits one exact startup rejection diagnostic")
            classified_output = "\n".join(line for line in output.splitlines() if line.strip() != expected_error)
        diagnostic = self.inspect_output(classified_output)
        result["diagnostics"] = diagnostic
        self.check(not diagnostic["errors"], result["name"] + " has no unexpected engine diagnostic: " + "; ".join(diagnostic["errors"]))
        # Successful child output remains visible to the runner's engine-error oracle.
        # Rejected override diagnostics are expected and retained in the case log.
        if expected_exit == 0:
            print(output, end="", flush=True)
        else:
            print("Expected rejection %s: exit %s; evidence %s" %
                  (result["name"], code, result["output_log"]), flush=True)
        return observation

    def run(self, name, arguments, expected_exit=0):
        return self.finish(self.launch(name, arguments), expected_exit)

    def selected(self, observation, path, source="cli", scores=(11, 22, 33),
                 legacy=(101, 202, 303), muted=True, hat=2):
        self.check(observation.get("path") == str(path) and observation.get("source") == source,
                   "startup selects the supplied %s destination before loading" % source)
        self.check(observation.get("read_path") == str(path),
                   "first record-read event uses only the selected isolated destination")
        self.check(observation.get("best_scores") == list(scores) and observation.get("legacy_scores") == list(legacy),
                   "cold startup reads independently specified treatment and historical scores")
        self.check(observation.get("muted") is muted and observation.get("hat") == hat,
                   "cold startup reads the specified mute and hat preferences")
        self.check(observation.get("rider_hat") == hat and observation.get("has_hat") is True,
                   "the first startup rider wears the loaded hat preference")
        self.check(observation.get("error") == "" and observation.get("world_built") is True,
                   "a valid selected fixture completes normal world startup")

    def defaults(self, name, arguments, source):
        observation = self.run(name, arguments)
        path = Path(observation.get("path", ""))
        self.check(path.is_absolute() and path.is_relative_to(self.project / "builds" / "test_runs"),
                   name + " allocates isolated storage inside the copied project")
        self.check(path.parent.is_dir() and not path.exists(),
                   name + " creates its fresh parent before the first read")
        self.check(observation.get("source") == source and observation.get("read_path") == str(path),
                   name + " records its mode default as the actual first read destination")
        self.check(observation.get("best_scores") == [0, 0, 0] and observation.get("legacy_scores") == [0, 0, 0],
                   name + " cannot load the poisoned old shared fixture")
        self.check(observation.get("muted") is False and observation.get("hat") == 0,
                   name + " starts with fresh preferences")
        return path

    def execute(self):
        self.copy_project()
        for name, before in (("cli-before-test", True), ("cli-after-test", False)):
            path = self.record(name)
            arguments = ["--records-path=" + str(path), "--test-mode"]
            if not before:
                arguments.reverse()
            self.selected(self.run(name, arguments), path)

        path = self.record("fixture with spaces=exact")
        self.selected(self.run("fixture with spaces=exact", ["--test-mode", "--records-path=" + str(path)]), path)

        path = self.record("v1-cold", (700000, 800000, 900000), True, 1, 1)
        self.selected(self.run("v1-cold", ["--test-mode", "--records-path=" + str(path)]), path,
                      scores=(0, 0, 0), legacy=(700000, 800000, 900000), hat=1)

        for name, flags in (("injected-cli-mode", ["--test-mode"]),
                            ("injected-pre-ready-mode", ["--inject-test-mode"]),
                            ("capture-injected", ["--capture"]),
                            ("selfcheck-injected", ["--self-check"])):
            path = self.record(name)
            self.selected(self.run(name, ["--inject-path=" + str(path), *flags]), path, "injected")

        injected = self.record("ignored-injected", (444, 555, 666), False, 1)
        path = self.record("cli-wins-injected")
        self.selected(self.run("cli-wins-injected", ["--inject-path=" + str(injected),
                      "--test-mode", "--records-path=" + str(path)]), path)

        for name, flags in (("capture-cli", ["--capture"]),
                            ("selfcheck-cli", ["--self-check"]),
                            ("combined-cli", ["--test-mode", "--capture", "--self-check"])):
            path = self.record(name)
            observation = self.run(name, ["--records-path=" + str(path), *flags])
            self.selected(observation, path)
            self.check(observation.get("automate") is True,
                       name + " preserves its automation behavior with explicit storage")

        path = self.record("native-storage-only", (31, 41, 59), False, 1)
        observation = self.run("native-storage-only", ["--records-path=" + str(path)])
        self.selected(observation, path, scores=(31, 41, 59), muted=False, hat=1)
        self.check(all(observation.get(flag) is False for flag in ("test_mode", "capture", "self_check", "automate")),
                   "a records override alone does not imply automation, test mode, capture, or self-check")

        first_default = self.defaults("default-test-a", ["--test-mode"], "test-default")
        second_default = self.defaults("default-test-b", ["--test-mode"], "test-default")
        self.check(first_default != second_default, "direct test launches never reuse a shared fixture")
        self.defaults("default-capture", ["--capture"], "capture-default")
        self.defaults("default-selfcheck", ["--self-check"], "selfcheck-default")
        self.defaults("default-combined", ["--test-mode", "--capture", "--self-check"], "selfcheck-default")

        valid = self.record("invalid-reference")
        second = self.record("invalid-second-reference", (99, 88, 77))
        invalid_cases = {
            "invalid-empty": ["--records-path="],
            "invalid-bare": ["--records-path"],
            "invalid-relative": ["--records-path=relative.json"],
            "invalid-user-uri": ["--records-path=user://records.json"],
            "invalid-resource-uri": ["--records-path=res://builds/records.json"],
            "invalid-directory": ["--records-path=" + str(valid.parent) + "/"],
            "invalid-conflicting": ["--records-path=" + str(valid), "--records-path=" + str(second)],
            "invalid-duplicate": ["--records-path=" + str(valid), "--records-path=" + str(valid)],
        }
        for name, arguments in invalid_cases.items():
            observation = self.run(name, ["--test-mode", *arguments], expected_exit=2)
            self.check(bool(observation.get("error")) and observation.get("world_built") is False,
                       name + " rejects the malformed override before world startup")
            self.check(observation.get("read_path") == "",
                       name + " rejects the override before any record read")

        missing = self.directory / "deliberately_missing_parent" / "records.json"
        observation = self.run("missing-parent", ["--records-path=" + str(missing), "--test-mode"])
        self.selected(observation, missing, scores=(0, 0, 0), legacy=(0, 0, 0), muted=False, hat=0)
        self.check(not missing.parent.exists(), "explicit missing-parent fixture remains available for R02 save-open failure")
        blocker = self.directory / "blocked_parent"
        blocker.write_text("This is an ordinary file, not a records directory.\n", encoding="utf-8")
        blocked = blocker / "records.json"
        observation = self.run("inaccessible-destination", ["--records-path=" + str(blocked)])
        self.selected(observation, blocked, scores=(0, 0, 0), legacy=(0, 0, 0), muted=False, hat=0)

        a = self.record("concurrent-a")
        b = self.record("concurrent-b", (91, 82, 73), False, 1)
        pending_a = self.launch("concurrent-a", ["--records-path=" + str(a), "--test-mode"])
        pending_b = self.launch("concurrent-b", ["--records-path=" + str(b), "--test-mode"])
        self.check(pending_a[0].poll() is None and pending_b[0].poll() is None,
                   "the two different cold-start processes actually overlap")
        observed_a = self.finish(pending_a)
        observed_b = self.finish(pending_b)
        self.selected(observed_a, a)
        self.selected(observed_b, b, scores=(91, 82, 73), muted=False, hat=1)
        self.check(observed_a.get("pid") != observed_b.get("pid"),
                   "concurrent fixtures were observed by distinct engine processes")

        self.write_json(self.directory / "startup_cases_result.json", {
            "checks": self.checks, "failures": self.failures,
            "project_copy": str(self.project), "cases": self.cases,
        })
        print("STARTUP: %d checks, %d failures; independent cold-process fixture oracles" %
              (self.checks, self.failures), flush=True)
        return 1 if self.failures else 0


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--engine", required=True)
    parser.add_argument("--project", required=True, type=Path)
    parser.add_argument("--fixture-directory", required=True, type=Path)
    arguments = parser.parse_args()
    directory = arguments.fixture_directory.resolve()
    directory.mkdir(parents=True, exist_ok=True)
    try:
        return StartupChecks(arguments.engine, arguments.project.resolve(), directory).execute()
    except (OSError, subprocess.SubprocessError, ValueError) as error:
        print("FAIL: cold-start fixture setup/process error: " + str(error), flush=True)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
