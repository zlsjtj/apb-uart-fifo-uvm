"""Plot the recorded VCD, after checking the sample's original checksums."""

import argparse
import hashlib
import json
import re
from pathlib import Path

import matplotlib

matplotlib.use("Agg")
import matplotlib.pyplot as plt
from vcdvcd import VCDVCD


SIGNALS = (
    ("tb_apb_uart.u_dut.tx_push", "TX enqueue", "#00718B"),
    ("tb_apb_uart.uart_vif.tx_o", "Serial TX", "#A04B00"),
    ("tb_apb_uart.u_dut.rx_pop", "RX dequeue", "#237544"),
)


def load_sample(directory):
    manifest = json.loads((directory / "manifest.json").read_text(encoding="utf-8-sig"))
    checksums = {item["path"]: item["sha256"] for item in manifest["artifacts"]}
    for name in ("loopback.vcd", "log_excerpt.txt"):
        actual = hashlib.sha256((directory / name).read_bytes()).hexdigest()
        if actual != checksums.get(name):
            raise ValueError(f"Checksum mismatch: {name}")

    vcd = VCDVCD(str(directory / "loopback.vcd"))
    missing = [name for name, _, _ in SIGNALS if name not in vcd.signals]
    if missing:
        raise ValueError(f"Missing signals: {', '.join(missing)}")
    if not vcd.timescale or vcd.endtime <= 0:
        raise ValueError("VCD needs a timescale and a nonempty time interval")

    for name, _, _ in SIGNALS:
        signal = vcd[name]
        if int(signal.size) != 1 or not signal.tv or signal.tv[0][0] != 0:
            raise ValueError(f"Expected a scalar trace starting at time zero: {name}")
        if any(value.lower() not in ("0", "1", "x", "z") for _, value in signal.tv):
            raise ValueError(f"Unsupported scalar value: {name}")

    log = (directory / "log_excerpt.txt").read_text(encoding="utf-8-sig")
    summary = re.search(r"\[SB_SUMMARY\] checked TX=(\d+) RX=(\d+)", log)
    if not summary:
        raise ValueError("Missing scoreboard counts in the recorded log")
    for index, expected in ((0, int(summary[1])), (2, int(summary[2]))):
        if len(rising_edges(vcd[SIGNALS[index][0]].tv)) != expected:
            raise ValueError(f"Pulse count differs from the recorded log: {SIGNALS[index][0]}")
    return vcd, checksums["loopback.vcd"]


def rising_edges(trace):
    return [time for (_, previous), (time, value) in zip(trace, trace[1:])
            if previous == "0" and value == "1"]


def step_data(trace, endtime, scale):
    # NaN breaks the line: unknown states must never turn into logical zero.
    times = [time * scale for time, _ in trace] + [endtime * scale]
    levels = [float(value) if value in ("0", "1") else float("nan")
              for _, value in trace]
    return times, levels + [levels[-1]]


def draw_trace(ax, trace, endtime, scale, color):
    times, levels = step_data(trace, endtime, scale)
    ax.step(times, levels, where="post", color=color, linewidth=1.7)
    for index, (time, value) in enumerate(trace):
        if value.lower() not in ("x", "z"):
            continue
        until = trace[index + 1][0] if index + 1 < len(trace) else endtime
        ax.axvspan(time * scale, until * scale, facecolor="#E0E0E0",
                   edgecolor="#666666", hatch="///", linewidth=0)
        if time * scale < ax.get_xlim()[1] and until * scale > ax.get_xlim()[0]:
            midpoint = (max(time * scale, ax.get_xlim()[0]) +
                        min(until * scale, ax.get_xlim()[1])) / 2
            ax.text(midpoint, 0.5, value.upper(), ha="center", va="center",
                    color="#333333", fontsize=13)


def render(directory, output):
    vcd, source_hash = load_sample(directory)
    if output.exists():
        raise FileExistsError(f"Output already exists; choose a new --output path: {output}")
    scale = float(vcd.timescale["timescale"]) * 1e6
    plt.rcParams.update({"font.family": "DejaVu Sans", "font.size": 15,
                         "axes.labelcolor": "#222222", "text.color": "#222222"})
    fig, axes = plt.subplots(3, 1, figsize=(5.4, 6.5), dpi=200)
    fig.subplots_adjust(left=0.08, right=0.97, bottom=0.08, top=0.865, hspace=1.10)
    fig.suptitle("Loopback: three time windows", fontsize=16, y=0.97)
    for ax, (name, title, color) in zip(axes, SIGNALS):
        trace = vcd[name].tv
        changes = [time for (_, previous), (time, value) in zip(trace, trace[1:])
                   if value != previous]
        if not changes:
            raise ValueError(f"No activity to show: {name}")
        # Each row has its own labelled time window; no pulse is widened.
        margin = max((changes[-1] - changes[0]) * 0.04, 0.02 / scale)
        start = max(0, changes[0] - margin)
        end = min(vcd.endtime, changes[-1] + margin)
        ax.set_xlim(start * scale, end * scale)
        draw_trace(ax, trace, vcd.endtime, scale, color)
        if name != SIGNALS[1][0]:
            edges = [time * scale for time in rising_edges(trace)]
            ax.scatter(edges, [1] * len(edges), s=18, marker="v", color=color, zorder=3)
        ax.set_title(f"{title}  /  {name.rsplit('.', 1)[-1]}", loc="left", fontsize=16, pad=9)
        ax.set_ylim(-0.18, 1.23)
        ax.set_yticks([0, 1])
        ax.set_xlabel("Time (us)", fontsize=14, labelpad=3)
        ax.xaxis.set_major_locator(plt.MaxNLocator(4))
        ax.tick_params(axis="both", length=0, pad=5, labelsize=14)
        ax.grid(axis="x", color="#D9DEE0", linewidth=0.6)
        for spine in ax.spines.values():
            spine.set_visible(False)

    output.parent.mkdir(parents=True, exist_ok=True)
    try:
        # Exclusive creation also avoids overwriting a file created during rendering.
        with output.open("xb") as stream:
            fig.savefig(stream, format="png", facecolor="white", metadata={
                "Source": "loopback.vcd", "SourceSHA256": source_hash,
                "VCDTimescale": str(vcd.timescale["timescale"]) + " seconds",
                "Description": "Three separately scaled windows; triangles mark rising edges.",
            })
    finally:
        plt.close(fig)
    return source_hash


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output", type=Path, required=True, help="New PNG path (not overwritten)")
    args = parser.parse_args()
    try:
        source_hash = render(Path(__file__).resolve().parent, args.output)
    except (ValueError, KeyError, OSError) as error:
        parser.exit(1, f"Preview failed: {error}\n")
    print(f"PREVIEW_OK {args.output}\nVCD SHA256 {source_hash}")


if __name__ == "__main__":
    main()
