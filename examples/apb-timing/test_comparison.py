"""Checks for the sample renderer, including failures that a plot must not hide."""

import hashlib
import json
from pathlib import Path
import shutil
import tempfile
import unittest

from PIL import Image

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

    def test_wide_no_overwrite(self):
        for name in ("comparison-wide.png", "comparison-wide-dark.png",
                     "comparison-wide.svg", "replay-wide.gif", "replay-wide-dark.gif"):
            with self.subTest(name=name):
                output = self.root / name.replace('.', '_')
                output.mkdir()
                (output / name).touch()
                with self.assertRaisesRegex(ValueError, "overwrite"):
                    plot.render(output, self.root, layout="wide")
                self.assertEqual(len(list(output.iterdir())), 1)

    def test_invalid_layout(self):
        with self.assertRaisesRegex(ValueError, "Unknown layout"):
            plot.render(self.root / "output", self.root, layout="unknown")

    def test_wide_phase_labels(self):
        baseline, mutant = plot.check(self.root)
        for phase in (0, 1, 2):
            with self.subTest(phase=phase):
                fig = plot.draw_wide(baseline, mutant, phase=phase)
                try:
                    labels = [text.get_text() for text in fig.texts]
                    for value in ("16", "0"):
                        self.assertEqual(value in labels, phase >= 1)
                    for result in ("PASS", "DETECTED", "[REG_DEFAULT]", "BAUD reset value is 0"):
                        self.assertEqual(result in labels, phase == 2)
                    self.assertIn("195 ns completion", labels)
                    self.assertIn("Time (ns)", labels)
                finally:
                    plot.plt.close(fig)

    def test_wide_labels_fit(self):
        baseline, mutant = plot.check(self.root)
        for dark in (False, True):
            for phase in (0, 1, 2):
                with self.subTest(dark=dark, phase=phase):
                    fig = plot.draw_wide(baseline, mutant, dark, phase)
                    try:
                        fig.canvas.draw()
                        renderer = fig.canvas.get_renderer()
                        boxes = [text.get_window_extent(renderer) for text in fig.texts]
                        for index, box in enumerate(boxes):
                            self.assertGreaterEqual(box.x0, 0)
                            self.assertGreaterEqual(box.y0, 0)
                            self.assertLessEqual(box.x1, fig.bbox.width)
                            self.assertLessEqual(box.y1, fig.bbox.height)
                            for other in boxes[index + 1:]:
                                self.assertFalse(box.overlaps(other), "Figure labels overlap")
                        for ax in fig.axes:
                            self.assertEqual(tuple(ax.get_xlim()), (180, 210))
                            self.assertEqual(list(ax.lines[-1].get_xdata()), [195, 195])
                    finally:
                        plot.plt.close(fig)

    def test_wide_exports(self):
        output = self.root / "wide"
        plot.render(output, self.root, layout="wide")
        for name in ("comparison-wide.png", "comparison-wide-dark.png"):
            with Image.open(output / name) as image:
                self.assertEqual(image.size, (1800, 880))
        for name in ("replay-wide.gif", "replay-wide-dark.gif"):
            with Image.open(output / name) as image:
                self.assertEqual(image.size, (900, 440))
                self.assertEqual(image.info["loop"], 0)
                duration = 0
                for frame in range(image.n_frames):
                    image.seek(frame)
                    duration += image.info["duration"]
                self.assertEqual(duration, 8000)
                self.assertGreaterEqual(image.n_frames, 3)
        svg = (output / "comparison-wide.svg").read_text()
        self.assertIn("<text", svg)
        self.assertIn("BAUD reset value is 0", svg)
        self.assertNotIn("<image", svg)


if __name__ == "__main__":
    unittest.main()
