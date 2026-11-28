import concurrent.futures
import hashlib
import json
from pathlib import Path
import sys
import tempfile
import unittest
from unittest.mock import patch
sys.path.insert(0, str(Path(__file__).resolve().parents[1] / 'scripts'))
import feedback_learning as m


class FeedbackLearning(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.store = Path(self.temp.name) / 'store'
        self.packet = dict(user_instruction='Move this legend outside.', task_id='task1',
                           scope='template', scope_key='CASE1', correction='Reserve an external legend column.')
        self.lesson = dict(summary='Use the accepted external legend.',
                           applicability='CASE1 with the same category count; inspect new data.',
                           validation='Compared accepted final PNG/PDF; labels readable.', user_acceptance=True,
                           acceptance_evidence=dict(quote='This version is good.', source='test-conversation/message-2'))

    def queue(self, **overrides):
        return m.enqueue(dict(self.packet, **overrides), self.store)['id']

    def publish(self, **overrides):
        identifier = self.queue(**overrides)
        m.publish(identifier, self.lesson, self.store)
        return identifier

    def test_pending_never_retrieved(self):
        self.queue()
        self.assertEqual(m.retrieve(dict(case_id='CASE1'), self.store), [])
        self.assertEqual(m.list_records(self.store)[0]['status'], 'pending')

    def test_template_exact_match(self):
        self.publish()
        for key in ('case_id', 'learned_method_id', 'reusable_case_id', 'pattern_id'):
            self.assertEqual(len(m.retrieve({key: 'CASE1'}, self.store)), 1)
        self.assertEqual(m.retrieve(dict(case_id='CASE12'), self.store), [])
        self.assertEqual(m.retrieve(dict(figure_family='CASE1'), self.store), [])

    def test_confirmed_family_preference_is_available_before_template_selection(self):
        intent = 'For heatmaps, prefer this annotation when there is a matching sample key.'
        scoped = self.queue(scope='global', user_instruction=intent, long_term_intent=intent, figure_family='matrix')
        m.publish(scoped, dict(self.lesson, user_acceptance=False,
                               acceptance_evidence=dict(quote=intent, source='test-message')), self.store)
        generic = self.queue(scope='global', user_instruction=intent, long_term_intent=intent)
        m.publish(generic, self.lesson, self.store)
        self.assertEqual([r['id'] for r in m.retrieve({'figure_family': 'matrix'}, self.store)], [scoped, generic])
        self.assertEqual([r['id'] for r in m.retrieve({'figure_family': 'tree'}, self.store)], [generic])
        self.assertEqual([r['id'] for r in m.retrieve({}, self.store)], [generic])

    def test_no_acceptance_cannot_activate(self):
        identifier = self.queue()
        with self.assertRaisesRegex(ValueError, 'user acceptance'):
            m.publish(identifier, dict(self.lesson, user_acceptance=False), self.store)
        self.assertEqual(m.list_records(self.store)[0]['status'], 'pending')

    def test_evidence_drift_rejected_on_publish(self):
        evidence = Path(self.temp.name) / 'final.pdf'
        evidence.write_bytes(b'original')
        identifier = self.queue(evidence=[dict(path=str(evidence), role='accepted-figure',
                                             sha256=hashlib.sha256(evidence.read_bytes()).hexdigest())])
        evidence.write_bytes(b'changed')
        with self.assertRaisesRegex(ValueError, 'SHA-256 mismatch'):
            m.publish(identifier, self.lesson, self.store)

    def test_packet_drift_rejected(self):
        identifier = self.queue()
        path = self.store / 'packets' / (identifier + '.json')
        record = json.loads(path.read_text())
        record['packet']['scope_key'] = 'OTHER'
        path.write_text(json.dumps(record))
        with self.assertRaisesRegex(ValueError, 'packet changed'):
            m.publish(identifier, self.lesson, self.store)

    def test_retire_keeps_history(self):
        identifier = self.publish()
        m.retire(identifier, 'User rejected this preference.', self.store)
        self.assertEqual(m.retrieve(dict(case_id='CASE1'), self.store), [])
        record = json.loads((self.store / 'lessons' / (identifier + '.json')).read_text())
        self.assertEqual(record['lesson'], self.lesson)
        self.assertIn('User rejected', record['retirement_reason'])

    def test_store_isolation(self):
        self.publish()
        self.assertEqual(m.retrieve(dict(case_id='CASE1'), Path(self.temp.name) / 'other'), [])

    def test_concurrent_enqueue_no_lost_records(self):
        with concurrent.futures.ThreadPoolExecutor(max_workers=8) as pool:
            identifiers = list(pool.map(lambda _: self.queue(), range(30)))
        self.assertEqual(len(set(identifiers)), 30)
        self.assertEqual(len(m.list_records(self.store)), 30)

    def test_global_requires_quote_can_publish_without_render_acceptance(self):
        packet = dict(self.packet, scope='global', user_instruction='Always omit AI footers.',
                      long_term_intent='Always omit AI footers.')
        identifier = m.enqueue(packet, self.store)['id']
        lesson = dict(self.lesson, user_acceptance=False,
                      acceptance_evidence=dict(quote=packet['long_term_intent'], source='test/message-1'))
        m.publish(identifier, lesson, self.store)
        self.assertEqual(len(m.retrieve({}, self.store)), 1)
        with self.assertRaisesRegex(ValueError, 'long_term_intent'):
            m.enqueue(dict(self.packet, scope='global'), self.store)

    def test_project_and_task_scope(self):
        self.publish(scope='task', scope_key='task1')
        self.assertEqual(len(m.retrieve(dict(task_id='task1'), self.store)), 1)
        self.assertEqual(m.retrieve(dict(task_id='task2'), self.store), [])
        self.publish(scope='project', scope_key=str(Path(self.temp.name)))
        self.assertEqual(len(m.retrieve(dict(project_root=str(Path(self.temp.name) / 'child' / '..')), self.store)), 1)
        self.assertEqual(m.retrieve(dict(project='relative/path'), self.store), [])

    def test_plain_text_only_and_immutable_publication(self):
        identifier = self.queue()
        with self.assertRaises(ValueError):
            m.publish(identifier, dict(self.lesson, command='execute'), self.store)
        with self.assertRaises(ValueError):
            m.publish(identifier, dict(self.lesson, summary='```python\npass\n```'), self.store)
        m.publish(identifier, self.lesson, self.store)
        with self.assertRaisesRegex(ValueError, 'already published'):
            m.publish(identifier, self.lesson, self.store)

    def test_reader_skips_corruption_and_does_not_hash_artifacts(self):
        self.publish()
        (self.store / 'lessons' / 'broken.json').write_text('{')
        with patch.object(m, '_sha', side_effect=AssertionError('foreground must not hash plot data')):
            self.assertEqual(len(m.retrieve(dict(case_id='CASE1'), self.store)), 1)

    def test_enqueue_does_not_hash_large_artifacts(self):
        evidence = Path(self.temp.name) / 'data.csv'
        evidence.write_bytes(b'input')
        with patch.object(m, '_sha', side_effect=AssertionError('queue must not hash plot data')):
            identifier = self.queue(evidence=[dict(path=str(evidence), role='input', sha256='0' * 64)])
        with self.assertRaisesRegex(ValueError, 'SHA-256 mismatch'):
            m.publish(identifier, self.lesson, self.store)

    def test_latest_matching_lessons_first_and_include_evidence(self):
        first = self.publish()
        second = self.publish()
        results = m.retrieve(dict(case_id='CASE1'), self.store)
        self.assertEqual([item['id'] for item in results], [second, first])
        self.assertIn('published_at', results[0])
        self.assertEqual(results[0]['evidence'], [])

    def test_reader_limit(self):
        for _ in range(7):
            self.publish()
        self.assertEqual(len(m.retrieve(dict(case_id='CASE1'), self.store)), 5)

    def test_acceptance_source_required(self):
        identifier = self.queue()
        with self.assertRaisesRegex(ValueError, 'acceptance_evidence'):
            m.publish(identifier, dict(self.lesson, acceptance_evidence={}), self.store)


if __name__ == '__main__':
    unittest.main()
