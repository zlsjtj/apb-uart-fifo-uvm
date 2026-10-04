"""Checks for the sample renderer, including failures that a plot must not hide."""

import hashlib
import json
from pathlib import Path
import shutil
import tempfile
import unittest

import render_comparison as plot


class ComparisonTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        for name in ("manifest.json", "baseline.vcd", "mutant.vcd",
                     "baseline_excerpt.txt", "mutant_excerpt.txt"):
            shutil.copyfile(plot.ROOT / name, self.root / name)

    def replace(self, file, old, new, rehash=True):
        path = self.root / file
        text = path.read_text()
        self.assertIn(old, text)
        path.write_text(text.replace(old, new), encoding="utf-8")
        if rehash:
            manifest = json.loads((self.root / "manifest.json").read_text(encoding="utf-8-sig"))
            manifest["artifacts"][file]["sha256"] = hashlib.sha256(path.read_bytes()).hexdigest()
            (self.root / "manifest.json").write_text(json.dumps(manifest), encoding="utf-8")

    def test_recorded_sample(self):
        baseline, mutant = plot.check(self.root)
        self.assertEqual(plot.value_at(baseline["prdata"], plot.EDGE, before=True), 16)
        self.assertEqual(plot.value_at(mutant["prdata"], plot.EDGE, before=True), 0)
        self.assertEqual(plot.value_at(mutant["prdata"], plot.EDGE), 16)

    def test_hash_corruption(self):
        with (self.root / "baseline.vcd").open("ab") as stream:
            stream.write(b"\n")
        with self.assertRaisesRegex(ValueError, "Hash mismatch"):
            plot.check(self.root)

    def test_missing_signal(self):
        self.replace("baseline.vcd", "pready", "not_ready")
        with self.assertRaisesRegex(ValueError, "Missing signal"):
            plot.check(self.root)

    def test_timescale(self):
        self.replace("baseline.vcd", "1ps", "1ns")
        with self.assertRaisesRegex(ValueError, "1 ps"):
            plot.check(self.root)

    def test_failed_baseline_log(self):
        self.replace("baseline_excerpt.txt", "UVM_ERROR :    0", "UVM_ERROR :    1")
        with self.assertRaisesRegex(ValueError, "ERROR count"):
            plot.check(self.root)

    def test_missing_fault_detector(self):
        self.replace("mutant_excerpt.txt", "[REG_DEFAULT] BAUD reset value is 0", "[OTHER] unrelated")
        with self.assertRaisesRegex(ValueError, "Missing register detector"):
            plot.check(self.root)

    def test_incomplete_report(self):
        self.replace("baseline_excerpt.txt", "[TEST_DONE]", "[OTHER]")
        with self.assertRaisesRegex(ValueError, "Incomplete baseline"):
            plot.check(self.root)

    def test_unknown_never_becomes_zero(self):
        for unknown in ("x", "z", "10x0", "10z1"):
            with self.subTest(unknown=unknown), self.assertRaises(ValueError):
                plot.value_at([(0, "0"), (10, unknown)], 10)

    def test_pre_edge_is_strict(self):
        tv = [(0, "0"), (195000, "10000")]
        self.assertEqual(plot.value_at(tv, 195000, before=True), 0)
        self.assertEqual(plot.value_at(tv, 195000), 16)
        with self.assertRaises(ValueError):
            plot.value_at(tv, 0, before=True)

    def test_wrong_transfer(self):
        trace = plot.load_trace(self.root / "baseline.vcd")
        trace["paddr"] = [(0, "100")]
        with self.assertRaisesRegex(ValueError, "BAUD read"):
            plot.validate_transfer(trace)

    def test_wrong_edge(self):
        trace = plot.load_trace(self.root / "baseline.vcd")
        trace["pclk"] = [(0, "1")]
        with self.assertRaisesRegex(ValueError, "rising PCLK"):
            plot.validate_transfer(trace)

    def test_unknown_in_window(self):
        trace = plot.load_trace(self.root / "baseline.vcd")
        trace["prdata"] = [(0, "0"), (185000, "x")]
        with self.assertRaises(ValueError):
            plot.segments(trace["prdata"])

    def test_no_overwrite(self):
        (self.root / "comparison.png").touch()
        with self.assertRaisesRegex(ValueError, "overwrite"):
            plot.render(self.root, self.root)


if __name__ == "__main__":
    unittest.main()
