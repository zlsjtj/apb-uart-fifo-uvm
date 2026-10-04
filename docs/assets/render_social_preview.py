"""Render the GitHub share image for the verified v0.1.0 release."""

import argparse
from pathlib import Path

from render_architecture import Diagram


def preview():
    d = Diagram(640, 320)
    d.text(32, 42, "APB UART FIFO UVM", 38, bold=True, align="left")
    d.text(32, 86, "Verify the design. Test the checkers.", 19, "muted", align="left")

    d.box(32, 118, 140, 98, "apb")
    d.text(102, 154, "APB", 25, "apb", True)
    d.text(102, 186, "registers", 18, "muted")
    for y, name, color in [(118, "TX", "tx"), (176, "RX", "rx")]:
        d.box(247, y, 154, 40, color)
        d.text(324, y + 20, name + " async FIFO", 17, color, True)
        d.box(475, y, 133, 40, color)
        d.text(541.5, y + 20, "UART " + name, 19, color, True)
    d.arrow((172, 138), (247, 138), "tx")
    d.arrow((401, 138), (475, 138), "tx")
    d.arrow((247, 196), (172, 196), "rx")
    d.arrow((475, 196), (401, 196), "rx")

    d.line([(32, 228), (608, 228)])
    d.text(32, 260, "60/60", 35, "check", True, "left")
    d.text(32, 299, "UVM runs passed", 15, "muted", align="left")
    d.text(250, 260, "13/13", 35, "check", True, "left")
    d.text(250, 299, "RTL faults detected", 15, "muted", align="left")
    d.text(484, 265, "v0.1.0", 22, bold=True, align="left")
    d.text(484, 294, "2026-10-04", 16, "muted", align="left")
    return d


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output-dir", type=Path, required=True)
    args = parser.parse_args()
    for ext in ("png", "svg"):
        target = args.output_dir / f"social-preview.{ext}"
        if target.exists():
            parser.error(f"Refusing to overwrite {target}")
    args.output_dir.mkdir(parents=True, exist_ok=True)
    preview().save(args.output_dir, "social-preview")
    print(f"Wrote 1280 x 640 PNG and editable SVG to {args.output_dir}")


if __name__ == "__main__":
    main()
