import importlib.util,json
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
def load():
 p=ROOT/'scripts/retrieve_capabilities.py';s=importlib.util.spec_from_file_location('rc',p);m=importlib.util.module_from_spec(s);s.loader.exec_module(m);return m
def test_graph_counts_and_status_boundary():
 g=json.loads((ROOT/'atlas/unified-capability-graph.json').read_text());assert g['summary']['case_count']==231;assert g['summary']['source_compared_pass']==0;assert 'only review_status=pass' in g['summary']['status_boundary']
def test_retrieval_never_promotes_needs_revision_to_pass():
 out=load().retrieve('三元 ggtern',20);assert out['results'];assert all(x['visual_status']!='source-compared-png' for x in out['results']);assert all('ternary' in x['method_families'] or 'ggtern' in x['packages'] or '三元' in x['title'] for x in out['results'])
