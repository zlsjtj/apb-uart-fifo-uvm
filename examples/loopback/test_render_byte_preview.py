import hashlib
import json
from pathlib import Path
import shutil
import tempfile
import unittest

from PIL import Image
from render_preview import load_sample
from render_byte_preview import annotated_byte, at, render


class BytePreviewTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.directory = Path(self.temp.name)
        for name in ("loopback.vcd", "log_excerpt.txt", "manifest.json"):
            shutil.copyfile(Path(__file__).resolve().parent / name, self.directory / name)

    def extract(self):
        vcd, _ = load_sample(self.directory)
        log = (self.directory / "log_excerpt.txt").read_text(encoding="utf-8-sig")
        return annotated_byte(vcd, log)

    def replace_fixture(self, old, new):
        path = self.directory / "loopback.vcd"
        data = path.read_bytes()
        self.assertIn(old, data)
        path.write_bytes(data.replace(old, new))
        path = self.directory / "manifest.json"
        manifest = json.loads(path.read_text(encoding="utf-8-sig"))
        manifest["artifacts"][0]["sha256"] = hashlib.sha256(
            (self.directory / "loopback.vcd").read_bytes()).hexdigest()
        path.write_text(json.dumps(manifest), encoding="utf-8")

    def test_recorded_byte_and_times(self):
        record = self.extract()
        self.assertEqual(record["value"], 0x55)
        self.assertEqual(record["bits"], [0, 1, 0, 1, 0, 1, 0, 1, 0, 1])
        self.assertEqual((record["count"], record["start"], record["end"]), (6, 1260000, 1660000))
        self.assertEqual((record["tx_access_start"], record["rx_access_start"]), (760000, 4990000))

    def test_unknown_bus_value_is_rejected(self):
        self.replace_fixture(b"b1010101 &", b"bx &")
        with self.assertRaisesRegex(ValueError, "Unknown value"):
            self.extract()

    def test_missing_annotation_signal_is_rejected(self):
        self.replace_fixture(b"pwdata", b"not_pwdata")
        with self.assertRaisesRegex(ValueError, "Missing annotation signals"):
            self.extract()

    def test_frame_unknown_glitch_and_stop_are_rejected(self):
        original = {p.name: p.read_bytes() for p in self.directory.iterdir()}
        for old, new, message in (
            (b"#1300000\r\n1*", b"#1300000\r\nx*", "Unknown value"),
            (b"#1300000", b"#1300001", "inside a bit interval"),
            (b"#1620000\r\n1*", b"#1620000\r\n0*", "Invalid start or stop"),
        ):
            with self.subTest(message=message):
                for name, contents in original.items():
                    (self.directory / name).write_bytes(contents)
                self.replace_fixture(old, new)
                with self.assertRaisesRegex(ValueError, message):
                    self.extract()

    def test_wrong_apb_value_is_rejected(self):
        self.replace_fixture(b"b1010101 &", b"b1010100 &")
        with self.assertRaisesRegex(ValueError, "disagree"):
            self.extract()

    def test_unshown_bytes_are_also_checked(self):
        self.replace_fixture(b"b110111 '", b"b110110 '")
        with self.assertRaisesRegex(ValueError, "disagree"):
            self.extract()

    def test_incomplete_frame_is_rejected(self):
        vcd, _ = load_sample(self.directory)
        vcd.endtime = 1659999
        log = (self.directory / "log_excerpt.txt").read_text(encoding="utf-8-sig")
        with self.assertRaisesRegex(ValueError, "Incomplete recorded frame"):
            annotated_byte(vcd, log)

    def test_invalid_sample_does_not_write_a_preview(self):
        self.replace_fixture(b"b1010101 &", b"bz &")
        output = self.directory / "invalid.png"
        with self.assertRaisesRegex(ValueError, "Unknown value"):
            render(self.directory, output)
        self.assertFalse(output.exists())

    def test_recording_timescale_not_assumed(self):
        self.replace_fixture(b"1ps", b"10ps")
        with self.assertRaisesRegex(ValueError, "Invalid start or stop|inside a bit interval"):
            self.extract()

    def test_missing_clock_is_rejected(self):
        vcd, _ = load_sample(self.directory)
        with self.assertRaisesRegex(ValueError, "Missing UART clock"):
            annotated_byte(vcd, "")

    def test_sampling_is_at_access_start_not_after_update(self):
        vcd, _ = load_sample(self.directory)
        trace = vcd["tb_apb_uart.apb_vif.prdata[31:0]"].tv
        self.assertEqual(at(trace, 4990000), 0x55)
        self.assertEqual(at(trace, 4995000), 0xAA)

    def test_render_preserves_inputs_and_existing_output(self):
        originals = {p.name: p.read_bytes() for p in self.directory.iterdir()}
        output = self.directory / "byte-preview.png"
        source_hash, _ = render(self.directory, output)
        with Image.open(output) as image:
            self.assertEqual(image.size, (1080, 600))
            self.assertEqual(image.info["SourceSHA256"], source_hash)
            self.assertEqual(image.info["ByteValue"], "0x55")
        saved = output.read_bytes()
        with self.assertRaises(FileExistsError):
            render(self.directory, output)
        self.assertEqual(output.read_bytes(), saved)
        for name, original in originals.items():
            self.assertEqual((self.directory / name).read_bytes(), original)

    def test_dark_theme_preserves_data_and_inputs(self):
        originals = {p.name: p.read_bytes() for p in self.directory.iterdir()}
        light = self.directory / "light.png"
        dark = self.directory / "dark.png"
        self.assertEqual(render(self.directory, light), render(self.directory, dark, "dark"))
        with Image.open(light) as light_image, Image.open(dark) as dark_image:
            self.assertEqual(light_image.size, dark_image.size)
            for field in ("SourceSHA256", "VCDTimescale", "ByteIndex", "ByteValue", "Description"):
                self.assertEqual(light_image.info[field], dark_image.info[field])
            self.assertEqual(dark_image.info["Theme"], "dark")
            self.assertEqual(dark_image.convert("RGB").getpixel((0, 0)), (13, 17, 23))
        with self.assertRaises(FileExistsError):
            render(self.directory, dark, "dark")
        for name, original in originals.items():
            self.assertEqual((self.directory / name).read_bytes(), original)

    def test_invalid_theme_does_not_create_output(self):
        output = self.directory / "invalid-theme.png"
        with self.assertRaisesRegex(ValueError, "Unknown preview theme"):
            render(self.directory, output, "unknown")
        self.assertFalse(output.exists())


if __name__ == "__main__":
    unittest.main()
