from pathlib import Path
import unittest
import yaml

ROOT = Path(__file__).resolve().parents[1]


class SkillEntryContractTests(unittest.TestCase):
    def test_skill_entry_embeds_bootstrap_gate_and_contract_location(self):
        skill = (ROOT / 'SKILL.md').read_text(encoding='utf-8')
        self.assertIn('先定位', skill)
        self.assertIn('失败', skill)
        self.assertIn('CP2', skill)
        self.assertIn('static/core/execution-contract.yaml', skill)
        self.assertIn('prepare_figure.py', skill)

    def test_skill_discovery_description_retains_suitable_chart_selection_trigger(self):
        skill = (ROOT / 'SKILL.md').read_text(encoding='utf-8')
        self.assertIn('判断适合的图型', skill)
        self.assertIn('按数据选图', skill)

    def test_cp2_opens_coding_and_render_auth_is_issued_after_source_exists(self):
        skill = (ROOT / 'SKILL.md').read_text(encoding='utf-8')
        contract = yaml.safe_load((ROOT / 'static/core/execution-contract.yaml').read_text(encoding='utf-8'))
        self.assertIn('CP2', skill)
        self.assertIn('成功才可开始编码', skill)
        self.assertIn('编码后、渲染前', skill)
        self.assertEqual(contract['bootstrap']['write_renderer_code_only_after'],
                         ['valid_request', 'successful_bootstrap', 'validated_cp2_spec_and_receipt'])
        self.assertIn('issue_render_authorization_after_source_exists', contract['workflow'])

    def test_manifest_is_only_a_dynamic_route_and_does_not_claim_host_loading(self):
        manifest = yaml.safe_load((ROOT / 'manifest.yaml').read_text(encoding='utf-8'))
        serialized = str(manifest)
        self.assertNotIn('always_load', manifest)
        self.assertIn('dynamic_load', serialized)
        self.assertFalse(manifest.get('host_enforcement'))

    def test_missing_chart_name_is_not_a_scientific_data_blocker(self):
        contract = yaml.safe_load((ROOT / 'static/core/execution-contract.yaml').read_text(encoding='utf-8'))
        self.assertIn('missing_required_data_or_scientific_semantics', contract['bootstrap']['block_on'])
        self.assertNotIn('missing_chart_specification', contract['bootstrap']['block_on'])
        self.assertIn('analyze_data_and_question_then_propose_chart_family_if_unspecified', contract['workflow'])

    def test_bootstrap_chinese_budget_and_single_file_limit(self):
        manifest = yaml.safe_load((ROOT / 'manifest.yaml').read_text(encoding='utf-8'))
        files = ['SKILL.md', *manifest['common_dynamic_load']]
        total = 0
        for rel in files:
            count = sum('\u4e00' <= char <= '\u9fff' for char in (ROOT / rel).read_text(encoding='utf-8'))
            self.assertLessEqual(count, 1200, rel)
            total += count
        self.assertLessEqual(total, 8000)
        phase_files = [rel for values in manifest.get('phase_dynamic_load', {}).values() for rel in values]
        for rel in phase_files:
            count = sum('\u4e00' <= char <= '\u9fff' for char in (ROOT / rel).read_text(encoding='utf-8'))
            self.assertLessEqual(count, 1200, rel)


if __name__ == '__main__':
    unittest.main()
