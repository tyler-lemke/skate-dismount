"""Validate only the repair planning artifact, not the game implementation."""
import hashlib
import json
import random
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
PLAN = ROOT / 'docs/repair'
round_id = int(sys.argv[1]) if len(sys.argv) > 1 else 0
spec = json.loads((PLAN / 'task_graph.json').read_text())
by_key = {item['key']: item for item in spec}
assert len(by_key) == len(spec) == 15, 'duplicate/missing task'
assert set(by_key) == {f'R{i:02}' for i in range(1, 16)}
assert sum(not item['depends_on'] for item in spec) == 1
assert not by_key['R01']['depends_on']
consumers = {key: [] for key in by_key}
seen = set()
active = set()
order = []

def visit(key):
    assert key not in active, f'cycle at {key}'
    if key in seen:
        return
    active.add(key)
    for dep in by_key[key]['depends_on']:
        assert dep in by_key and dep != key, f'invalid dependency {key}->{dep}'
        visit(dep)
    active.remove(key)
    seen.add(key)
    order.append(key)

for item in spec:
    visit(item['key'])
    for dep in item['depends_on']:
        consumers[dep].append(item['key'])
assert all(consumers[k] for k in by_key if k != 'R15'), 'orphan task'
assert not consumers['R15'], 'release is not sink'
main_text = (PLAN / 'PLAN.md').read_text()
mermaid_edges = set(re.findall(r'(R\d{2}) --> (R\d{2})', main_text))
expected_edges = {(dep, item['key']) for item in spec for dep in item['depends_on']}
assert mermaid_edges == expected_edges, f'diagram/manifest differ: {mermaid_edges ^ expected_edges}'

reachable = set()
def ancestors(key):
    if key in reachable:
        return
    reachable.add(key)
    for dep in by_key[key]['depends_on']:
        ancestors(dep)
ancestors('R15')
assert reachable == set(by_key), 'release misses task'

texts = {}
for item in spec:
    path = ROOT / item['path']
    assert path.is_file(), f'missing {path}'
    content = path.read_text()
    texts[item['key']] = content
    assert content.startswith(f"# {item['key']}"), f'wrong title {path}'
    assert len(content.splitlines()) >= 95, f'underspecified card {path}'
    assert 'Godot 4.7.2' in content and 'stair-dismount' in content, f'missing runtime context {path}'
    assert re.search(r'rationale|Why:|why ', content, re.I), f'missing rationale {path}'
    assert re.search(r'acceptance|pass criteria|oracle|regression', content, re.I), f'missing acceptance {path}'
    assert re.search(r'completion|Done|handoff', content, re.I), f'missing completion {path}'
    assert re.search(r'rollback|fallback|failure|recover|Risks', content, re.I), f'missing recovery {path}'
    header = content.split('##', 1)[0]
    declaration = re.search(r'(?:Depends on|Dependencies|Prerequisites?):\s*([^\n.]*)', header)
    assert declaration, f'missing prerequisite declaration {path}'
    declared = set(re.findall(r'R\d{2}', declaration.group(1)))
    assert declared == set(item['depends_on']), f'header graph mismatch {path}: {declared}'
    assert f"P{item['priority']}" in header, f'priority mismatch {path}'
    for dep in item['depends_on']:
        assert dep in header, f'prerequisite missing from header {path}: {dep}'
line_total = sum(len(t.splitlines()) for t in texts.values()) + len((PLAN / 'PLAN.md').read_text().splitlines())
assert 1500 <= line_total <= 10000, f'plan lines {line_total}'

sample = random.Random(90210 + round_id).sample(sorted(texts), 5)
sampled = []
for key in sample:
    lines = texts[key].splitlines()
    hits = [(i + 1, line) for i, line in enumerate(lines) if re.search(r'Why:|rationale|Choose .*because|why ', line, re.I)]
    assert hits
    sampled.append({'task': key, 'rationale_lines': hits[:3]})
files = [PLAN / 'PLAN.md', PLAN / 'task_graph.json'] + [ROOT / i['path'] for i in spec]
digests = {str(p.relative_to(ROOT)): hashlib.sha256(p.read_bytes()).hexdigest() for p in files}
report = {'round': round_id, 'tasks': len(spec), 'dependency_edges': sum(len(i['depends_on']) for i in spec),
          'line_total': line_total, 'topological_order': order, 'initial_ready': ['R01'],
          'intentional_sink': 'R15', 'all_tasks_reach_release': True, 'cycles': [],
          'rationale_sample': sampled, 'document_sha256': digests,
          'limitations': 'Static plan validation; no gameplay implementation or native acceptance is claimed.'}
output = PLAN / 'reviews' / f'validation_{round_id}.json'
output.write_text(json.dumps(report, indent=2) + '\n')
print(json.dumps({k: v for k, v in report.items() if k not in ['document_sha256', 'rationale_sample']}))
