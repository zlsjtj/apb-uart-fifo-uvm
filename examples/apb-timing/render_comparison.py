"""Render a checked APB timing comparison from the frozen VCDs and log excerpts."""

import argparse
from bisect import bisect_left, bisect_right
from decimal import Decimal
import hashlib
import json
from pathlib import Path
import re

import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt
from matplotlib.animation import PillowWriter
from vcdvcd import VCDVCD

ROOT = Path(__file__).resolve().parent
START, EDGE, END = 180_000, 195_000, 210_000  # Source VCD ticks, 1 ps each.
SIGNALS = {
    "pclk": "tb_apb_uart.pclk",
    **{s: f"tb_apb_uart.apb_vif.{s}" for s in
       ("psel", "penable", "pwrite", "pready", "pslverr")},
    "paddr": "tb_apb_uart.apb_vif.paddr[7:0]",
    "prdata": "tb_apb_uart.apb_vif.prdata[31:0]",
}


def value_at(tv, tick, *, before=False):
    times = [time for time, _ in tv]
    index = (bisect_left(times, tick) if before else bisect_right(times, tick)) - 1
    if index < 0 or re.fullmatch("[01]+", tv[index][1]) is None:
        raise ValueError(f"Unknown or missing value at {tick}")
    return int(tv[index][1], 2)


def load_trace(path):
    vcd = VCDVCD(str(path))
    if vcd.timescale["timescale"] != Decimal("1e-12"):
        raise ValueError("Expected 1 ps source ticks")
    traces = {}
    for name, ref in SIGNALS.items():
        if ref not in vcd.signals:
            raise ValueError(f"Missing signal: {ref}")
        tv = vcd[ref].tv
        value_at(tv, START)
        value_at(tv, END)
        for tick, _ in tv:
            if START <= tick <= END:
                value_at(tv, tick)
        traces[name] = tv
    if vcd.endtime < END:
        raise ValueError("Truncated waveform")
    return traces


def validate_transfer(trace):
    for name, expected in {"psel": 1, "penable": 1, "pwrite": 0,
                           "pready": 1, "paddr": 8, "pslverr": 0}.items():
        if value_at(trace[name], EDGE, before=True) != expected:
            raise ValueError(f"Not the expected BAUD read: {name}")
    if (value_at(trace["pclk"], EDGE, before=True), value_at(trace["pclk"], EDGE)) != (0, 1):
        raise ValueError("Completion must be a rising PCLK edge")


def check(root=ROOT):
    manifest = json.loads((root / "manifest.json").read_text(encoding="utf-8-sig"))
    required = {f"{name}.{ext}" for name in ("baseline", "mutant") for ext in ("vcd",)}
    required |= {f"{name}_excerpt.txt" for name in ("baseline", "mutant")}
    if set(manifest["artifacts"]) != required:
        raise ValueError("Unexpected sample inventory")
    for file, info in manifest["artifacts"].items():
        if hashlib.sha256((root / file).read_bytes()).hexdigest() != info["sha256"]:
            raise ValueError(f"Hash mismatch: {file}")
    if (manifest["test"], manifest["seed"], manifest["mutationDefine"]) != (
            "uart_reg_test", 1071, "UART_MUTATE_APB_LATE_RESPONSE"):
        raise ValueError("Unexpected comparison identity")
    if not manifest["outcome"]["baselinePass"] or manifest["outcome"]["result"] != "KILLED":
        raise ValueError("Capture did not pass its baseline/fault gate")
    if any(code != 0 for code in manifest["simulatorExit"].values()):
        raise ValueError("Simulator did not finish normally")
    for name, errors in (("baseline", 0), ("mutant", 5)):
        log = (root / f"{name}_excerpt.txt").read_text()
        for marker in ("Running test uart_reg_test...", "[TEST_DONE]", "[SB_SUMMARY]"):
            if marker not in log:
                raise ValueError(f"Incomplete {name} excerpt")
        for level, count in (("ERROR", errors), ("FATAL", 0), ("WARNING", 0)):
            if not re.search(rf"^# UVM_{level}\s*:\s*{count}\s*$", log, re.M):
                raise ValueError(f"Unexpected {name} {level} count")
        if name == "baseline" and re.search(r"^# (UVM_ERROR (?!\s*:).*|\*\* Error:)", log, re.M):
            raise ValueError("Baseline contains a failure")
        if name == "mutant" and "[REG_DEFAULT] BAUD reset value is 0" not in log:
            raise ValueError("Missing register detector")
    baseline, mutant = (load_trace(root / f"{name}.vcd") for name in ("baseline", "mutant"))
    for trace in (baseline, mutant):
        validate_transfer(trace)
    for signal in ("pclk", "psel", "penable", "pwrite", "paddr", "pready"):
        points = {START, END} | {t for trace in (baseline, mutant)
                                for t, _ in trace[signal] if START <= t <= END}
        if any(value_at(baseline[signal], t) != value_at(mutant[signal], t) for t in points):
            raise ValueError(f"Stimulus differs: {signal}")
    sampled = tuple(value_at(t["prdata"], EDGE, before=True) for t in (baseline, mutant))
    if sampled != (16, 0):
        raise ValueError(f"Unexpected sampled values: {sampled}")
    if value_at(mutant["prdata"], EDGE) != 16:
        raise ValueError("Expected late data after the completion edge")
    return baseline, mutant


def segments(tv):
    points = sorted({START, END} | {t for t, _ in tv if START < t < END})
    return [(a / 1000, b / 1000, value_at(tv, a)) for a, b in zip(points, points[1:])]


def draw(baseline, mutant, dark=False, phase=2):
    bg, fg, muted = (("#111416", "#f0f3f5", "#bac1c7") if dark else
                     ("#ffffff", "#202629", "#52616b"))
    teal, coral = ("#5ed8c8", "#ffab8f") if dark else ("#007b70", "#b34127")
    plt.rcParams.update({"font.family": "DejaVu Sans", "svg.fonttype": "none"})
    fig = plt.figure(figsize=(5.4, 5.8), dpi=100, facecolor=bg)
    fig.text(.06, .945, "One edge. Two outcomes.", color=fg, fontsize=21, weight="bold")
    fig.text(.06, .903, "BAUD read / uart_reg_test / seed 1071", color=muted, fontsize=11)
    positions = [("PCLK", baseline["pclk"], .73, fg, False),
                 ("PENABLE", baseline["penable"], .59, muted, False),
                 ("Fixed PRDATA", baseline["prdata"], .41, teal, True),
                 ("Late PRDATA", mutant["prdata"], .23, coral, True)]
    for label, tv, y, color, bus in positions:
        ax = fig.add_axes([.11, y, .80, .075], facecolor=bg)
        ax.set_xlim(180, 210)
        ax.set_ylim(-.2, 1.2)
        ax.set_yticks([])
        ax.set_xticks([180, 185, 190, 195, 200, 205, 210])
        ax.tick_params(axis="x", colors=muted, labelsize=10, length=0, pad=6,
                       labelbottom=label == "Late PRDATA")
        for spine in ax.spines.values():
            spine.set_visible(False)
        fig.text(.06, y + .10, label, color=fg, fontsize=13, weight="bold")
        if bus:
            for a, b, value in segments(tv):
                ax.fill_between([a, b], 0, 1, color=color, alpha=.12)
                ax.plot([a, a, b, b], [0, 1, 1, 0], color=color, lw=1.8)
                ax.plot([a, b], [0, 0], color=color, lw=1.8)
                ax.text((a + b) / 2, .5, str(value), color=fg, fontsize=14,
                        ha="center", va="center", weight="bold")
        else:
            parts = segments(tv)
            xs = [p[0] for p in parts] + [parts[-1][1]]
            vals = [p[2] for p in parts] + [parts[-1][2]]
            ax.step(xs, vals, where="post", color=color, lw=1.8)
        ax.axvline(195, color=muted, linestyle=(0, (3, 3)), linewidth=1.2)
        if phase >= 1 and bus:
            value = value_at(tv, EDGE, before=True)
            fig.text(.91, y + .10, f"{value} sampled", ha="right", color=color,
                     fontsize=13, weight="bold")
    fig.text(.51, .145, "Time (ns)", ha="center", color=muted, fontsize=11)
    captions = ["1 / Same register read. Same clock edge.",
                "2 / input #1step samples before 195 ns.",
                "3 / [REG_DEFAULT] BAUD reset value is 0"]
    fig.text(.06, .081, captions[phase], color=fg, fontsize=11, weight="bold")
    fig.text(.06, .042, "2026-10-05 capture / injected fault, not historical RTL", color=muted, fontsize=9)
    return fig


def draw_wide(baseline, mutant, dark=False, phase=2):
    """Keep the common time axis and both sampled outcomes in one desktop view."""
    bg, fg, muted = (("#111416", "#f0f3f5", "#bac1c7") if dark else
                     ("#ffffff", "#202629", "#52616b"))
    teal, coral = ("#5ed8c8", "#ffab8f") if dark else ("#007b70", "#b34127")
    plt.rcParams.update({"font.family": "DejaVu Sans", "svg.fonttype": "none"})
    fig = plt.figure(figsize=(9, 4.4), dpi=100, facecolor=bg)
    fig.text(.035, .915, "One edge. Two outcomes.", color=fg, fontsize=22, weight="bold")
    fig.text(.035, .85, "BAUD read / uart_reg_test / seed 1071", color=muted, fontsize=13)
    positions = [("PCLK", baseline["pclk"], .66, fg, False),
                 ("PENABLE", baseline["penable"], .52, muted, False),
                 ("Fixed", baseline["prdata"], .38, teal, True),
                 ("Late", mutant["prdata"], .24, coral, True)]
    for label, tv, y, color, bus in positions:
        ax = fig.add_axes([.19, y, .45, .075], facecolor=bg)
        ax.set_xlim(180, 210)
        ax.set_ylim(-.2, 1.2)
        ax.set_yticks([])
        ax.set_xticks([180, 195, 210])
        ax.tick_params(axis="x", colors=muted, labelsize=14, length=0, pad=5,
                       labelbottom=label == "Late")
        for spine in ax.spines.values():
            spine.set_visible(False)
        fig.text(.035, y + .03, label, color=fg, fontsize=14, weight="bold")
        if bus:
            fig.text(.035, y - .01, "PRDATA", color=muted, fontsize=11)
            for a, b, value in segments(tv):
                ax.fill_between([a, b], 0, 1, color=color, alpha=.12)
                ax.plot([a, a, b, b], [0, 1, 1, 0], color=color, lw=1.8)
                ax.plot([a, b], [0, 0], color=color, lw=1.8)
                ax.text((a + b) / 2, .5, str(value), color=fg, fontsize=14,
                        ha="center", va="center", weight="bold")
        else:
            parts = segments(tv)
            ax.step([p[0] for p in parts] + [parts[-1][1]],
                    [p[2] for p in parts] + [parts[-1][2]],
                    where="post", color=color, lw=1.8)
        # Keep the completion marker out of the bus values.
        spans = ((0, .14), (.86, 1)) if bus else ((0, 1),)
        for bottom, top in spans:
            ax.axvline(195, ymin=bottom, ymax=top, color=muted,
                       linestyle=(0, (3, 3)), linewidth=1.2)
    fig.text(.415, .775, "195 ns completion", ha="center", color=muted, fontsize=13)
    fig.text(.415, .125, "Time (ns)", ha="center", color=muted, fontsize=13)
    fig.add_artist(plt.Line2D([.685, .685], [.22, .77], transform=fig.transFigure,
                             color=muted, alpha=.3, lw=1))
    fig.text(.735, .775, "PRE-EDGE SAMPLE", color=muted, fontsize=12, weight="bold")
    fig.text(.735, .705, "Fixed", color=teal, fontsize=14, weight="bold")
    fig.text(.735, .49, "Late", color=coral, fontsize=14, weight="bold")
    if phase >= 1:
        for trace, y, color, result in ((baseline, .60, teal, "PASS"),
                                       (mutant, .385, coral, "DETECTED")):
            sampled = value_at(trace["prdata"], EDGE, before=True)
            fig.text(.735, y, str(sampled), color=color, fontsize=34, weight="bold")
            fig.text(.845, y + .015, result if phase == 2 else "sampled",
                     color=color, fontsize=12, weight="bold")
    if phase == 2:
        fig.text(.735, .28, "[REG_DEFAULT]", color=coral, fontsize=13, weight="bold")
        fig.text(.735, .225, "BAUD reset value is 0", color=fg, fontsize=12)
    captions = ["1 / Same read. Same completion edge.",
                "2 / input #1step samples before the edge.",
                "3 / Fixed passes. Injected fault is detected."]
    fig.text(.035, .035, captions[phase], color=fg, fontsize=13, weight="bold")
    return fig


def render(output, root=ROOT, layout="portrait"):
    if layout not in ("portrait", "wide"):
        raise ValueError(f"Unknown layout: {layout}")
    baseline, mutant = check(root)
    suffix = "-wide" if layout == "wide" else ""
    names = [f"comparison{suffix}.png", f"comparison{suffix}-dark.png",
             f"comparison{suffix}.svg", f"replay{suffix}.gif"]
    if layout == "wide":
        names.append("replay-wide-dark.gif")
    if any((output / name).exists() for name in names):
        raise ValueError("Refusing to overwrite existing figures")
    output.mkdir(parents=True, exist_ok=True)
    draw_layout = draw_wide if layout == "wide" else draw
    for dark in (False, True):
        fig = draw_layout(baseline, mutant, dark)
        theme = "-dark" if dark else ""
        fig.savefig(output / f"comparison{suffix}{theme}.png", dpi=200)
        if not dark:
            fig.savefig(output / f"comparison{suffix}.svg")
        plt.close(fig)
    # A data/log replay with deliberate pauses, not a screen recording or run timer.
    for dark in ((False, True) if layout == "wide" else (False,)):
        theme = "-dark" if dark else ""
        fig = draw_layout(baseline, mutant, dark, phase=0)
        writer = PillowWriter(fps=1)
        with writer.saving(fig, str(output / f"replay{suffix}{theme}.gif"), dpi=100):
            for phase in (0, 0, 1, 1, 2, 2, 2, 2):
                frame = draw_layout(baseline, mutant, dark, phase=phase)
                writer.fig = frame
                writer.grab_frame(facecolor=frame.get_facecolor())
                plt.close(frame)
        plt.close(fig)
    print("APB_SAMPLE_PASS baseline=16 mutant=0 at pre-edge 195 ns")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output-dir", type=Path)
    parser.add_argument("--check-only", action="store_true")
    parser.add_argument("--layout", choices=("portrait", "wide"), default="portrait")
    args = parser.parse_args()
    if args.check_only:
        check()
        print("APB_SAMPLE_PASS hashes, reports, transfer, pre-edge values")
    elif args.output_dir:
        render(args.output_dir, layout=args.layout)
    else:
        parser.error("Choose --output-dir or --check-only")


if __name__ == "__main__":
    main()
