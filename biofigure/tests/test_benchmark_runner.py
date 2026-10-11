import importlib.util
import json
import sys
import tempfile
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


def load():
    sys.path.insert(0, str(ROOT / "scripts"))
    path = ROOT / "scripts/run_benchmark_case.py"
    spec = importlib.util.spec_from_file_location("benchmark_runner", path)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


class BenchmarkRunnerModeTests(unittest.TestCase):
    def test_source_exposed_independent_reconstruction_is_recordable(self):
        runner = load()
        self.assertEqual(
            runner.validate_generation_mode("source-exposed-independent"),
            "source-exposed-independent",
        )

    def test_unknown_generation_mode_is_rejected(self):
        runner = load()
        with self.assertRaises(ValueError):
            runner.validate_generation_mode("blind-transfer-without-isolation")

    def test_script_scientific_results_are_loaded_as_observed_evidence(self):
        runner = load()
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "scientific_results.json"
            expected = {"composition-closure": {"status": "pass", "evidence": "10 groups close"}}
            path.write_text(json.dumps(expected))
            self.assertEqual(runner.read_scientific_results(path), expected)

    def test_malformed_scientific_results_are_rejected(self):
        runner = load()
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "scientific_results.json"
            path.write_text("[]")
            with self.assertRaises(ValueError):
                runner.read_scientific_results(path)


if __name__ == "__main__":
    unittest.main()
