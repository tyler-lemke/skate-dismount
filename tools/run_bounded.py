#!/usr/bin/env python3
"""Bound argv commands and validate Godot suites. See --help and `suite --help`."""

import argparse
import datetime
import hashlib
import json
import math
import os
from pathlib import Path
import re
import signal
import subprocess
import sys
import time
import uuid


DEFAULT_TIMEOUT = 180
TERMINATE_GRACE_SECONDS = 0.5
ANSI = re.compile(r"\x1b\[[0-?]*[ -/]*[@-~]")
SUMMARY = re.compile(r"^([A-Z][A-Z0-9_]*): ([0-9]+) checks, ([0-9]+) failures(?:;.*)?$")
SUMMARY_CANDIDATE = re.compile(r"^[A-Za-z][A-Za-z0-9_]*:.*\b(?:checks?|failures?)\b", re.I)
CERTIFICATE_ERROR = 'ERROR: Condition "ret != noErr" is true. Returning: ""'
CERTIFICATE_LOCATION = "at: get_system_ca_certificates (platform/macos/os_macos.mm:1035)"
ERROR_MARKERS = re.compile(
    r"SCRIPT ERROR|Parse Error|Compile Error|\bFAIL(?:\s|:|$)|\bERROR(?:\s|:|$)|"
    r"leaked at exit|resources still in use|ObjectDB instances leaked", re.I
)


def timeout_value(value):
    try:
        result = float(value)
    except (ValueError, TypeError) as exc:
        raise argparse.ArgumentTypeError("timeout must be a number from 10 to 600 seconds") from exc
    if not math.isfinite(result) or not 10 <= result <= 600:
        raise argparse.ArgumentTypeError("timeout must be from 10 to 600 seconds")
    return result


def write_json(path, value):
    path = Path(path)
    path.parent.mkdir(parents=True, exist_ok=True)
    temporary = path.with_name(path.name + ".tmp")
    temporary.write_text(json.dumps(value, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    temporary.replace(path)


def inspect_output(output, expected_summary=None):
    """Only the exact adjacent certificate condition/location pair is exempted."""
    lines = ANSI.sub("", output).splitlines()
    errors, summaries, ignored = [], [], []
    for index, raw in enumerate(lines):
        line = raw.strip()
        if line == CERTIFICATE_ERROR and index + 1 < len(lines):
            if lines[index + 1].strip() == CERTIFICATE_LOCATION:
                ignored.append({"line": index + 1, "diagnostic": "macos_system_ca_certificates"})
                continue
        if ERROR_MARKERS.search(line):
            errors.append(f"line {index + 1}: {line}")
        marker = SUMMARY.fullmatch(line)
        if marker:
            summaries.append({"name": marker[1], "checks": int(marker[2]),
                              "failures": int(marker[3]), "line": index + 1})
        elif SUMMARY_CANDIDATE.search(line) or (expected_summary and line.startswith(expected_summary + ":")):
            errors.append(f"line {index + 1}: malformed completion marker: {line}")
    if expected_summary:
        expected = [entry for entry in summaries if entry["name"] == expected_summary]
        if len(expected) != 1:
            errors.append(f"expected exactly one {expected_summary} completion marker, found {len(expected)}")
        for entry in summaries:
            if entry["name"] != expected_summary:
                errors.append(f"unexpected completion marker {entry['name']}; expected {expected_summary}")
            if entry["checks"] == 0:
                errors.append(f"{entry['name']} reported zero checks")
            if entry["failures"] != 0:
                errors.append(f"{entry['name']} reported {entry['failures']} failures")
    elif summaries:
        errors.append("unexpected completion marker in command without an expected suite")
    return {"errors": errors, "summaries": summaries, "ignored_diagnostics": ignored}


def stop_process_group(process):
    """Terminate, wait briefly, then kill the group even if its leader exited."""
    errors = []
    if os.name == "posix":
        for sig in (signal.SIGTERM, signal.SIGKILL):
            try:
                os.killpg(process.pid, sig)
            except ProcessLookupError:
                pass
            except OSError as exc:
                errors.append(f"process group cleanup: {exc}")
            if sig == signal.SIGTERM:
                time.sleep(TERMINATE_GRACE_SECONDS)
        try:
            process.wait(timeout=5)
        except subprocess.TimeoutExpired:
            errors.append("process leader did not exit after group kill")
    else:
        try:
            subprocess.run(["taskkill", "/PID", str(process.pid), "/T", "/F"],
                           stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, timeout=5, check=False)
            process.wait(timeout=5)
        except (OSError, subprocess.TimeoutExpired) as exc:
            errors.append(f"process tree cleanup: {exc}")
    return errors


def run_command(command, timeout_seconds, log, *, expected_summary=None, result_path=None, cwd=None):
    """Internal callers may use a short positive deadline for timeout controls."""
    if not math.isfinite(timeout_seconds) or timeout_seconds <= 0:
        raise ValueError("internal deadline must be positive and finite")
    command = [str(part) for part in command]
    if not command:
        raise ValueError("an argument-vector command is required")
    log = Path(log).resolve()
    log.parent.mkdir(parents=True, exist_ok=True)
    result_path = Path(result_path).resolve() if result_path else Path(str(log) + ".result.json")
    started = datetime.datetime.now(datetime.timezone.utc).isoformat()
    begin = time.monotonic()
    result = {"command": command, "command_sha256": hashlib.sha256(
        json.dumps(command, ensure_ascii=False).encode("utf-8")).hexdigest(),
        "cwd": str(Path(cwd).resolve()) if cwd else str(Path.cwd()), "started_at": started,
        "timeout_seconds": timeout_seconds, "timed_out": False, "interrupted": False,
        "exit_code": None, "expected_summary": expected_summary,
        "log": str(log), "result": str(result_path), "process_group": None}
    errors = []
    with log.open("wb") as stream:
        try:
            options = {"start_new_session": True} if os.name == "posix" else {
                "creationflags": subprocess.CREATE_NEW_PROCESS_GROUP}
            process = subprocess.Popen(command, cwd=cwd, stdout=stream, stderr=subprocess.STDOUT,
                                       stdin=subprocess.DEVNULL, **options)
            result["process_group"] = process.pid
            try:
                result["exit_code"] = process.wait(timeout=timeout_seconds)
                if os.name == "posix":
                    try:
                        os.killpg(process.pid, 0)
                    except ProcessLookupError:
                        pass
                    else:
                        errors.append("command leader exited while descendants remained in its process group")
                        errors.extend(stop_process_group(process))
            except subprocess.TimeoutExpired:
                result["timed_out"] = True
                errors.append(f"deadline exceeded ({timeout_seconds:g} seconds)")
                errors.extend(stop_process_group(process))
                result["exit_code"] = process.returncode
            except KeyboardInterrupt:
                result["interrupted"] = True
                errors.append("caller interrupted command")
                errors.extend(stop_process_group(process))
                result["exit_code"] = process.returncode
        except OSError as exc:
            errors.append(f"could not launch command: {exc}")
            stream.write((errors[-1] + "\n").encode("utf-8"))
    result["elapsed_seconds"] = round(time.monotonic() - begin, 6)
    if result["exit_code"] != 0:
        errors.append(f"command exit code: {result['exit_code']}")
    result.update(inspect_output(log.read_text(encoding="utf-8", errors="replace"), expected_summary))
    result["errors"] = errors + result["errors"]
    result["success"] = not result["errors"]
    write_json(result_path, result)
    return result


def load_registry(path, project):
    entries = json.loads(Path(path).read_text(encoding="utf-8"))
    if not isinstance(entries, list) or not entries:
        raise ValueError("suite registry must be a nonempty list")
    scripts, summaries, directories = set(), set(), set()
    for entry in entries:
        if not isinstance(entry, dict) or set(entry) != {"script", "summary", "timeout_seconds"}:
            raise ValueError("every suite needs script, summary, and timeout_seconds only")
        script, name = entry["script"], entry["summary"]
        if not isinstance(script, str) or not isinstance(name, str) or not re.fullmatch(r"[A-Z][A-Z0-9_]*", name):
            raise ValueError("invalid script or summary name in registry")
        relative = Path(script)
        if relative.is_absolute() or ".." in relative.parts or relative.suffix != ".gd":
            raise ValueError(f"suite script must be a relative .gd path: {script}")
        if not (project / relative).is_file():
            raise ValueError(f"registered suite script is missing: {script}")
        if script in scripts or name in summaries or relative.stem in directories:
            raise ValueError(f"duplicate script, summary, or artifact directory: {script} / {name}")
        scripts.add(script)
        summaries.add(name)
        directories.add(relative.stem)
        entry["timeout_seconds"] = timeout_value(entry["timeout_seconds"])
    return entries


def source_digest(project):
    """Hash project inputs, including assets and harness; exclude generated runs/caches."""
    files = []
    for name in ("project.godot", "export_presets.cfg", "scripts", "scenes", "tests", "tools", "assets"):
        path = project / name
        if path.is_file():
            files.append(path)
        elif path.is_dir():
            files.extend(p for p in path.rglob("*") if p.is_file() and
                         "__pycache__" not in p.parts and p.name != ".DS_Store")
    digest = hashlib.sha256()
    manifest = []
    for path in sorted(files):
        relative = path.relative_to(project).as_posix()
        data = ("symlink:" + os.readlink(path)).encode() if path.is_symlink() else path.read_bytes()
        item = {"path": relative, "bytes": len(data), "sha256": hashlib.sha256(data).hexdigest()}
        digest.update(json.dumps(item, sort_keys=True).encode("utf-8") + b"\n")
        manifest.append(item)
    return {"sha256": digest.hexdigest(), "files": manifest}


def print_result(result):
    sys.stdout.write(Path(result["log"]).read_text(encoding="utf-8", errors="replace"))
    sys.stdout.flush()
    if not result["success"]:
        for error in result["errors"]:
            print(f"RUNNER: {error}", file=sys.stderr)


def suite_main(argv):
    parser = argparse.ArgumentParser(description="Run import and every registered suite sequentially.")
    parser.add_argument("--project-dir", required=True, type=Path)
    parser.add_argument("--engine", default=os.environ.get("GODOT_BIN", "godot"))
    parser.add_argument("--registry", type=Path, help="default: tools/test_suites.json in project")
    parser.add_argument("--timeout-seconds", type=timeout_value,
                        help="bounded 10–600 second override for import and every suite (default: 180)")
    args = parser.parse_args(argv)
    project = args.project_dir.resolve()
    registry = (args.registry or project / "tools/test_suites.json").resolve()
    try:
        entries = load_registry(registry, project)
    except (OSError, ValueError, argparse.ArgumentTypeError) as exc:
        parser.error(str(exc))
    run_id = datetime.datetime.now(datetime.timezone.utc).strftime("%Y%m%dT%H%M%S.%fZ") + f"-{os.getpid()}-{uuid.uuid4().hex[:8]}"
    run_dir = project / "builds/test_runs" / run_id
    run_dir.mkdir(parents=True, exist_ok=False)
    report_path = run_dir / "result.json"
    report = {"run_id": run_id, "success": False, "engine": args.engine, "engine_version": None,
              "registry": str(registry), "registry_sha256": hashlib.sha256(registry.read_bytes()).hexdigest(),
              "timeout_override_seconds": args.timeout_seconds, "input_source_digest": source_digest(project),
              "expected_suites": entries, "suites": [], "run_directory": str(run_dir),
              "result": str(report_path), "errors": []}
    write_json(report_path, report)
    print(f"RUNNER: run {run_id}; artifacts {run_dir}", flush=True)
    version = run_command([args.engine, "--version"], 10, run_dir / "version.output.log", cwd=project)
    report["version_command"] = version
    if version["success"]:
        report["engine_version"] = Path(version["log"]).read_text(encoding="utf-8").strip()
    else:
        report["errors"].append("engine version command failed")
        print_result(version)
    if not report["errors"]:
        import_dir = run_dir / "import"
        import_dir.mkdir()
        imported = run_command([args.engine, "--headless", "--path", str(project), "--import", "--log-file",
                                str(import_dir / "engine.log")],
                               args.timeout_seconds or DEFAULT_TIMEOUT, import_dir / "output.log",
                               result_path=import_dir / "result.json", cwd=project)
        report["import"] = imported
        print_result(imported)
        if not imported["success"]:
            report["errors"].append("project import failed")
    if not report["errors"]:
        for entry in entries:
            suite_dir = run_dir / Path(entry["script"]).stem
            suite_dir.mkdir()
            records = suite_dir / "records.json"
            command = [args.engine, "--headless", "--path", str(project), "--fixed-fps", "60", "--script",
                       entry["script"], "--log-file", str(suite_dir / "engine.log"), "--", "--test-mode",
                       "--records-path=" + str(records)]
            result = run_command(command, args.timeout_seconds or entry["timeout_seconds"],
                                 suite_dir / "output.log", expected_summary=entry["summary"],
                                 result_path=suite_dir / "result.json", cwd=project)
            result["script"] = entry["script"]
            result["records_path"] = str(records)
            result["engine_log"] = str(suite_dir / "engine.log")
            write_json(result["result"], result)
            report["suites"].append(result)
            print_result(result)
            write_json(report_path, report)
            if not result["success"]:
                report["errors"].append(f"suite failed: {entry['summary']}")
                break
    report["input_source_digest_after"] = source_digest(project)["sha256"]
    if report["input_source_digest_after"] != report["input_source_digest"]["sha256"]:
        report["errors"].append("project input sources changed during the run")
    report["completed_suites"] = len(report["suites"])
    report["total_checks"] = sum(marker["checks"] for result in report["suites"] for marker in result["summaries"]
                                 if result["success"] and marker["name"] == result["expected_summary"])
    report["success"] = not report["errors"] and len(report["suites"]) == len(entries) and all(
        result["success"] for result in report["suites"])
    report["finished_at"] = datetime.datetime.now(datetime.timezone.utc).isoformat()
    write_json(report_path, report)
    if report["success"]:
        print(f"RUNNER: all {len(entries)} registered suites passed; {report['total_checks']} checks; result {report_path}")
    else:
        print(f"RUNNER: run failed; {len(report['suites'])}/{len(entries)} suites completed; result {report_path}", file=sys.stderr)
    return 0 if report["success"] else 1


def main(argv=None):
    argv = sys.argv[1:] if argv is None else argv
    if argv and argv[0] == "suite":
        return suite_main(argv[1:])
    parser = argparse.ArgumentParser(description="Run an argv command with a bounded deadline and combined output.")
    parser.add_argument("--timeout-seconds", type=timeout_value, default=DEFAULT_TIMEOUT)
    parser.add_argument("--log", type=Path, required=True)
    parser.add_argument("--result", type=Path, help="default: LOG.result.json")
    parser.add_argument("--expected-summary", help="require exactly one NAME: N checks, 0 failures marker")
    parser.add_argument("command", nargs=argparse.REMAINDER, help="-- followed by command and separate arguments")
    args = parser.parse_args(argv)
    if not args.command or args.command[0] != "--" or len(args.command) < 2:
        parser.error("provide -- followed by an argument-vector command")
    if args.expected_summary and not re.fullmatch(r"[A-Z][A-Z0-9_]*", args.expected_summary):
        parser.error("expected summary must be an uppercase suite name")
    result = run_command(args.command[1:], args.timeout_seconds, args.log,
                         expected_summary=args.expected_summary, result_path=args.result)
    print_result(result)
    print(f"RUNNER: result {result['result']}", flush=True)
    return 0 if result["success"] else 1


if __name__ == "__main__":
    sys.exit(main())
