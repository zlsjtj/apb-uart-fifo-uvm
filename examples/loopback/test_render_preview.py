import hashlib
import json
import math
import shutil
import tempfile
import unittest
from pathlib import Path

from render_preview import SIGNALS, draw_trace, load_sample, render, rising_edges, step_data
import matplotlib.pyplot as plt
from PIL import Image


class PreviewTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.directory = Path(self.temp.name)
        for name in ("loopback.vcd", "log_excerpt.txt", "manifest.json"):
            shutil.copyfile(Path(__file__).resolve().parent / name, self.directory / name)

    def replace_fixture(self, name, old, new):
        path = self.directory / name
        data = path.read_bytes()
        self.assertIn(old, data)
        path.write_bytes(data.replace(old, new))
        manifest_path = self.directory / "manifest.json"
        manifest = json.loads(manifest_path.read_text(encoding="utf-8-sig"))
        for artifact in manifest["artifacts"]:
            if artifact["path"] == name:
                artifact["sha256"] = hashlib.sha256(path.read_bytes()).hexdigest()
        manifest_path.write_text(json.dumps(manifest), encoding="utf-8")

    def test_recorded_times_and_counts(self):
        vcd, _ = load_sample(self.directory)
        scale = float(vcd.timescale["timescale"]) * 1e6
        self.assertAlmostEqual(vcd.endtime * scale, 6.88)
        pushes = rising_edges(vcd[SIGNALS[0][0]].tv)
        pops = rising_edges(vcd[SIGNALS[2][0]].tv)
        self.assertEqual((len(pushes), len(pops)), (6, 6))
        self.assertAlmostEqual(pushes[0] * scale, 0.73)
        self.assertAlmostEqual(pops[-1] * scale, 6.87)

    def test_both_artifact_checksums_are_required(self):
        for name in ("loopback.vcd", "log_excerpt.txt"):
            with self.subTest(name=name):
                path = self.directory / name
                original = path.read_bytes()
                path.write_bytes(original + b"tampered")
                with self.assertRaisesRegex(ValueError, "Checksum mismatch"):
                    render(self.directory, self.directory / "rejected.png")
                self.assertFalse((self.directory / "rejected.png").exists())
                path.write_bytes(original)

    def test_missing_signal_even_with_updated_checksum(self):
        self.replace_fixture("loopback.vcd", b"tx_push", b"not_tx_push")
        with self.assertRaisesRegex(ValueError, "Missing signals"):
            render(self.directory, self.directory / "missing.png")
        self.assertFalse((self.directory / "missing.png").exists())

    def test_count_mismatch(self):
        self.replace_fixture("log_excerpt.txt", b"checked TX=6", b"checked TX=5")
        with self.assertRaisesRegex(ValueError, "Pulse count differs"):
            load_sample(self.directory)

    def test_timescale_is_read_not_assumed(self):
        self.replace_fixture("loopback.vcd", b"1ps", b"10ns")
        vcd, _ = load_sample(self.directory)
        times, _ = step_data(vcd[SIGNALS[0][0]].tv, vcd.endtime,
                             float(vcd.timescale["timescale"]) * 1e6)
        self.assertAlmostEqual(times[1], 7300)

    def test_unknowns_are_gaps_and_labelled(self):
        trace = [(0, "0"), (1, "x"), (2, "z"), (3, "1")]
        _, values = step_data(trace, 4, 1)
        self.assertTrue(math.isnan(values[1]) and math.isnan(values[2]))
        fig, ax = plt.subplots()
        self.addCleanup(plt.close, fig)
        ax.set_xlim(0, 4)
        draw_trace(ax, trace, 4, 1, "#00718B")
        self.assertEqual([text.get_text() for text in ax.texts], ["X", "Z"])
        self.assertEqual([patch.get_hatch() for patch in ax.patches], ["///", "///"])

    def test_render_preserves_inputs_and_existing_output(self):
        originals = {p.name: p.read_bytes() for p in self.directory.iterdir()}
        output = self.directory / "preview.png"
        source_hash = render(self.directory, output)
        with Image.open(output) as image:
            self.assertEqual(image.info["SourceSHA256"], source_hash)
            self.assertEqual(image.size, (1080, 1300))
            self.assertEqual(image.info["VCDTimescale"], "1E-12 seconds")
        image_hash = hashlib.sha256(output.read_bytes()).hexdigest()
        with self.assertRaises(FileExistsError):
            render(self.directory, output)
        self.assertEqual(hashlib.sha256(output.read_bytes()).hexdigest(), image_hash)
        for name, original in originals.items():
            self.assertEqual((self.directory / name).read_bytes(), original)


if __name__ == "__main__":
    unittest.main()
