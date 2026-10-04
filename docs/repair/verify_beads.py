"""Read-only audit of initial planning conversion; not a gameplay/release test."""
from pathlib import Path
import hashlib
import json
import subprocess

ROOT = Path(__file__).resolve().parents[2]
DB = ROOT / '.beads/beads.db'
PLAN = ROOT / 'docs/repair'
manifest = json.loads((PLAN / 'task_graph.json').read_text())
mapping = json.loads((PLAN / 'bead_mapping.json').read_text())

def br(*arguments):
    process = subprocess.run(['br', '--db', str(DB), *arguments, '--json'],
                             cwd=ROOT, text=True, capture_output=True, timeout=30)
    if process.returncode:
        raise RuntimeError(process.stderr)
    return json.loads(process.stdout)

def one(result):
    if isinstance(result, list):
        assert len(result) == 1
        return result[0]
    if isinstance(result, dict) and 'issue' in result:
        return result['issue']
    return result

results = []
for task in manifest:
    issue = one(br('show', mapping[task['key']]['id']))
    description = (ROOT / task['path']).read_text()
    assert issue['description'] == description, f"description drift {task['key']}"
    assert issue['title'] == f"{task['key']} — {task['title']}", f"title drift {task['key']}"
    assert issue['priority'] == task['priority'], f"priority drift {task['key']}"
    assert issue['status'] == 'open', f"repair falsely claimed {task['key']}"
    assert hashlib.sha256(description.encode()).hexdigest() == mapping[task['key']]['description_sha256']
    dependencies = br('dep', 'list', issue['id'])
    assert isinstance(dependencies, list), dependencies
    assert all(d['issue_id'] == issue['id'] and d['type'] == 'blocks' for d in dependencies)
    actual = {d['depends_on_id'] for d in dependencies}
    expected = {mapping[dep]['id'] for dep in task['depends_on']}
    assert actual == expected, f"blocking-edge drift {task['key']}: {actual ^ expected}"
    assert len(dependencies) == len(expected), f"duplicate edges {task['key']}"
    results.append({'task': task['key'], 'id': issue['id'], 'description_bytes':len(description.encode()),
                    'dependency_result': dependencies})
ready = br('ready')
assert isinstance(ready, list), ready
assert [item['id'] for item in ready] == [mapping['R01']['id']], 'unexpected readiness'
cycles = br('dep', 'cycles')
assert not cycles['cycles'], cycles
health = br('doctor')
assert health['ok'], health
report = {'tasks': len(results), 'blocking_edges':sum(len(i['depends_on']) for i in manifest),
          'all_blocking_edges_exact': True, 'all_descriptions_exact': True, 'all_repairs_open': True,
          'ready': [{'task':'R01', 'id':mapping['R01']['id']}], 'cycles':cycles,
          'tracker_healthy': health['ok'], 'dependency_results':results,
          'scope':'Planning queue only; no gameplay repair acceptance is claimed.'}
(PLAN / 'bead_verification.json').write_text(json.dumps(report,indent=2)+'\n')
print(json.dumps({k:v for k,v in report.items() if k != 'dependency_results'}))
