"""Render the README overview. This is a structural diagram, not run evidence."""

import argparse
from io import StringIO
from pathlib import Path

import matplotlib

matplotlib.use("Agg")
import matplotlib.pyplot as plt
from matplotlib.patches import FancyArrowPatch, FancyBboxPatch


COLORS = {
    "bg": "#171D21", "panel": "#202A30", "text": "#F0F4F6",
    "muted": "#B8C5CD", "line": "#53636D", "apb": "#8BC7F0",
    "tx": "#55E0D3", "rx": "#FF99A7", "check": "#C7E88B",
}
plt.rcParams.update({"font.family": "DejaVu Sans", "svg.fonttype": "none",
                     "svg.hashsalt": "apb-uart-overview"})


class Diagram:
    def __init__(self, width, height):
        self.width, self.height = width, height
        self.fig, self.ax = plt.subplots(figsize=(width / 100, height / 100), dpi=100)
        self.fig.patch.set_facecolor(COLORS["bg"])
        self.ax.set(xlim=(0, width), ylim=(height, 0))
        self.ax.set_axis_off()
        self.fig.subplots_adjust(0, 0, 1, 1)
        self.labels = []

    def text(self, x, y, value, size=25, color="text", bold=False, align="center"):
        label = self.ax.text(x, y, value, fontsize=size * 72 / 100,
                             color=COLORS[color], ha=align, va="center",
                             weight="bold" if bold else "normal", linespacing=1.35,
                             zorder=4)
        self.labels.append(label)

    def box(self, x, y, width, height, color):
        self.ax.add_patch(FancyBboxPatch(
            (x, y), width, height, boxstyle="round,pad=0,rounding_size=6",
            facecolor=COLORS["panel"], edgecolor=COLORS[color], linewidth=1.7,
            zorder=3))

    def line(self, points, color="line", dashed=False):
        x, y = zip(*points)
        self.ax.plot(x, y, color=COLORS[color], linewidth=1.6,
                     linestyle=(0, (4, 5)) if dashed else "-", solid_capstyle="butt")

    def arrow(self, start, end, color, bend=None):
        if bend:
            self.line([start, *bend], color)
            start = bend[-1]
        self.ax.add_patch(FancyArrowPatch(
            start, end, arrowstyle="-|>", mutation_scale=17,
            linewidth=2, color=COLORS[color], shrinkA=0, shrinkB=1))

    def save(self, directory, name):
        self.fig.canvas.draw()
        renderer = self.fig.canvas.get_renderer()
        boxes = [label.get_window_extent(renderer) for label in self.labels]
        for index, box in enumerate(boxes):
            if box.x0 < 0 or box.y0 < 0 or box.x1 > self.width or box.y1 > self.height:
                raise ValueError(f"Label outside canvas: {self.labels[index].get_text()}")
            if any(box.overlaps(other) for other in boxes[index + 1:]):
                raise ValueError(f"Overlapping label: {self.labels[index].get_text()}")
        self.fig.savefig(directory / f"{name}.png", dpi=200)
        svg = StringIO()
        self.fig.savefig(svg, format="svg", metadata={"Date": None})
        (directory / f"{name}.svg").write_text(
            "\n".join(line.rstrip() for line in svg.getvalue().splitlines()) + "\n",
            encoding="utf-8", newline="\n")
        plt.close(self.fig)


def desktop():
    d = Diagram(1200, 590)
    d.text(80, 43, "APB / pclk", 28, "apb", True, "left")
    d.text(890, 43, "UART / uart_clk", 28, "tx", True, "left")
    d.line([(620, 76), (620, 337)], dashed=True)

    d.box(80, 100, 260, 225, "apb")
    d.text(210, 129, "APB registers", 29, bold=True)
    d.text(210, 174, "TXDATA", 26, "tx")
    d.text(210, 266, "RXDATA", 26, "rx")
    d.text(210, 220, "CTRL / STATUS / BAUD", 19, "muted")
    for y, name, direction, color in [(125, "TX async FIFO", "pclk to uart_clk", "tx"),
                                       (237, "RX async FIFO", "uart_clk to pclk", "rx")]:
        d.box(485, y, 270, 88, color)
        d.text(620, y + 29, name, 28, color, True)
        d.text(620, y + 63, direction, 21, "muted")
        d.box(900, y, 175, 88, color)
        d.text(987.5, y + 44, "UART " + name[:2], 28, color, True)
    d.arrow((340, 169), (485, 169), "tx")
    d.arrow((755, 169), (900, 169), "tx")
    d.arrow((1075, 169), (1160, 169), "tx")
    d.text(1120, 139, "tx_o", 23)
    d.arrow((485, 281), (340, 281), "rx")
    d.arrow((900, 281), (755, 281), "rx")
    d.arrow((1160, 281), (1075, 281), "rx")
    d.text(1120, 251, "rx_i", 23)
    d.text(410, 143, "write", 20, "tx")
    d.text(410, 307, "read", 20, "rx")

    d.line([(40, 360), (1160, 360)])
    d.text(80, 398, "UVM / data checking", 26, "check", True, "left")
    d.box(80, 440, 310, 85, "apb")
    d.text(235, 466, "Interface monitors", 26, bold=True)
    d.text(235, 500, "APB + TX pin + RX pin", 22, "muted")
    d.box(510, 440, 240, 85, "check")
    d.text(630, 482, "Predictor", 29, bold=True)
    d.box(920, 440, 240, 85, "check")
    d.text(1040, 482, "Scoreboard", 29, bold=True)
    d.arrow((390, 475), (510, 475), "apb")
    d.arrow((750, 475), (920, 475), "check")
    d.text(835, 447, "expected", 22, "check")
    d.arrow((235, 525), (1040, 525), "apb", [(235, 559), (1040, 559)])
    d.text(630, 541, "actual: APB reads + TX frames", 22, "apb")
    return d


def mobile():
    d = Diagram(480, 840)
    d.text(240, 34, "APB / pclk", 27, "apb", True)
    d.box(40, 66, 400, 100, "apb")
    d.text(240, 96, "APB registers", 29, bold=True)
    d.text(240, 135, "TXDATA / RXDATA", 25, "muted")
    d.line([(20, 249), (460, 249)], dashed=True)
    for x, name, color in [(40, "TX", "tx"), (270, "RX", "rx")]:
        d.box(x, 205, 170, 90, color)
        d.text(x + 85, 250, name + " async\nFIFO", 27, color, True)
        d.box(x, 349, 170, 74, color)
        d.text(x + 85, 386, "UART " + name, 27, color, True)
    d.arrow((125, 166), (125, 205), "tx")
    d.arrow((355, 205), (355, 166), "rx")
    d.arrow((125, 295), (125, 349), "tx")
    d.arrow((355, 349), (355, 295), "rx")
    d.text(240, 323, "uart_clk", 23, "muted")
    d.arrow((125, 423), (125, 470), "tx")
    d.arrow((355, 470), (355, 423), "rx")
    d.text(125, 492, "tx_o", 25)
    d.text(355, 492, "rx_i", 25)

    d.line([(25, 530), (455, 530)])
    d.text(240, 565, "UVM / data checking", 27, "check", True)
    d.box(30, 605, 180, 88, "apb")
    d.text(120, 633, "Monitors", 26, bold=True)
    d.text(120, 667, "APB + TX + RX", 21, "muted")
    d.box(280, 605, 170, 88, "check")
    d.text(365, 649, "Predictor", 26, bold=True)
    d.box(280, 752, 170, 68, "check")
    d.text(365, 786, "Scoreboard", 25, bold=True)
    d.arrow((210, 649), (280, 649), "apb")
    d.arrow((365, 693), (365, 752), "check")
    d.text(414, 722, "expected", 18, "check")
    d.arrow((30, 649), (280, 786), "apb", [(15, 649), (15, 786)])
    d.text(135, 737, "actual\nAPB reads + TX frames", 20, "apb")
    return d


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output-dir", type=Path, required=True)
    args = parser.parse_args()
    names = ("architecture", "architecture-mobile")
    for name in names:
        for ext in ("png", "svg"):
            target = args.output_dir / f"{name}.{ext}"
            if target.exists():
                parser.error(f"Refusing to overwrite {target}")
    args.output_dir.mkdir(parents=True, exist_ok=True)
    for name, render in zip(names, (desktop, mobile)):
        render().save(args.output_dir, name)
    print(f"Wrote desktop and mobile PNG/SVG diagrams to {args.output_dir}")


if __name__ == "__main__":
    main()
