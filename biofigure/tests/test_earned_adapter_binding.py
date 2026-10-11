import copy
import sys
import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / 'scripts'))
from retrieve_learned_methods import retrieve, validate_binding, validate_adapter_sources, sha


class EarnedAdapterBindingTests(unittest.TestCase):
    def setUp(self):
        self.learning = retrieve('', case_id='SCICASE-007')
        entry = self.learning['results'][0]
        self.renderer = {'path': 'scripts/retrieve_learned_methods.py', 'sha256': entry['source_sha256']}
        entry['qualified_reuse'] = {'status': 'PASS', 'reuse_recipe': {'renderer': self.renderer}}
        self.receipt = {'query': '', 'request': {'learned_method_id': 'SCICASE-007'}, 'learned_methods': self.learning}
        self.spec = {'reference_evidence': {'learned_method_reuse': {'adopted': ['SCICASE-007'],
            'rejected': [], 'data_adaptation': 'CSV key mapping', 'known_failures_addressed': 'range/missing/key QA'}}}

    def check(self):
        with patch('retrieve_learned_methods.retrieve', return_value=self.learning):
            return validate_binding(self.receipt, self.spec)

    def test_qualified_adapter_cannot_be_silently_forgotten(self):
        self.assertTrue(any('adapter' in e for e in self.check()))

    def test_exact_qualified_renderer_is_bound_before_reuse(self):
        self.spec['reference_evidence']['learned_method_reuse']['adapter_decisions'] = [
            {'method_id': 'SCICASE-007', 'decision': 'reuse', 'renderer': self.renderer}]
        self.assertEqual(self.check(), [])
        self.spec['reference_evidence']['learned_method_reuse']['adapter_decisions'][0]['renderer'] = {'path': 'unrelated.R', 'sha256': '0' * 64}
        self.assertTrue(any('renderer' in e for e in self.check()))

    def test_adapter_change_requires_scientific_difference_and_new_validation(self):
        choice = {'method_id': 'SCICASE-007', 'decision': 'adapt'}
        self.spec['reference_evidence']['learned_method_reuse']['adapter_decisions'] = [choice]
        self.assertTrue(self.check())
        choice.update(data_contract_difference='Paired subject display requires different mark layout', new_validation_required=True)
        self.assertEqual(self.check(), [])

    def test_duplicate_decisions_cannot_hide_wrong_adapter(self):
        choice = {'method_id': 'SCICASE-007', 'decision': 'reuse', 'renderer': self.renderer}
        self.spec['reference_evidence']['learned_method_reuse']['adapter_decisions'] = [choice, copy.deepcopy(choice)]
        self.assertTrue(self.check())

    def test_actual_sources_must_include_earned_bytes_even_when_copied(self):
        with tempfile.TemporaryDirectory() as directory:
            original = Path(directory) / 'earned.R'
            original.write_text('plot(1:3)\n')
            self.renderer['sha256'] = sha(original)
            self.spec['reference_evidence']['learned_method_reuse']['adapter_decisions'] = [
                {'method_id': 'SCICASE-007', 'decision': 'reuse', 'renderer': self.renderer}]
            other = Path(directory) / 'other.R'
            other.write_text('plot(1:4)\n')
            self.assertTrue(validate_adapter_sources(self.receipt, self.spec, [other]))
            other.write_bytes(original.read_bytes())
            self.assertEqual(validate_adapter_sources(self.receipt, self.spec, [other]), [])


if __name__ == '__main__':
    unittest.main()
