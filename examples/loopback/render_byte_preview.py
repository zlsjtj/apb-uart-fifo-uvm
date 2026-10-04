"""Annotate one byte in the frozen 8N1 sample; not a general UART checker."""

import argparse
from bisect import bisect_right
from decimal import Decimal
from pathlib import Path
import re

from render_preview import draw_trace, load_sample, plt, rising_edges


PREFIX = "tb_apb_uart.apb_vif."
BUS_SIGNALS = ("psel", "penable", "pwrite", "paddr[7:0]", "pwdata[31:0]",
               "prdata[31:0]", "pslverr")
TX_SIGNAL = "tb_apb_uart.uart_vif.tx_o"
PALETTES = {
    "light": {"background": "white", "text": "#222222", "ticks": "black",
              "grid": "#D9DEE0", "write": "#00718B", "serial": "#A04B00", "read": "#237544"},
    "dark": {"background": "#0D1117", "text": "#E6EDF3", "ticks": "#E6EDF3",
             "grid": "#30363D", "write": "#79C0FF", "serial": "#FFA657", "read": "#7EE787"},
}


def known_value(value):
    if not value or any(bit not in "01" for bit in value):
        raise ValueError(f"Unknown value in annotated data: {value}")
    return int(value, 2)


def at(trace, time):
    index = bisect_right([tick for tick, _ in trace], time) - 1
    if index < 0:
        raise ValueError("No recorded value at requested time")
    return known_value(trace[index][1])


def constant_level(trace, start, end):
    values = [at(trace, start)]
    values.extend(known_value(value) for tick, value in trace if start < tick < end)
    if len(set(values)) != 1:
        raise ValueError("Serial transition inside a bit interval")
    return values[0]


def annotated_byte(vcd, log, index=1):
    missing = [PREFIX + name for name in BUS_SIGNALS if PREFIX + name not in vcd.signals]
    if missing:
        raise ValueError(f"Missing annotation signals: {', '.join(missing)}")
    bus = {name: vcd[PREFIX + name].tv for name in BUS_SIGNALS}
    accesses = []
    for time in rising_edges(bus["penable"]):
        if at(bus["psel"], time) != 1 or at(bus["pslverr"], time) != 0:
            raise ValueError("Sample needs selected, error-free APB accesses")
        write = at(bus["pwrite"], time)
        data = at(bus["pwdata[31:0]" if write else "prdata[31:0]"], time)
        accesses.append((time, write, at(bus["paddr[7:0]"], time), data))

    # These addresses and the fixed 8N1 format belong to this recorded example.
    writes = [(time, data) for time, wr, addr, data in accesses if wr and addr == 0x0C]
    reads = [(time, data) for time, wr, addr, data in accesses if not wr and addr == 0x10]
    baud = [(time, data) for time, wr, addr, data in accesses if wr and addr == 0x08]
    ctrl = [(time, data) for time, wr, addr, data in accesses if wr and addr == 0x00]
    if not writes or len(writes) != len(reads) or not 0 <= index < len(writes):
        raise ValueError("Unmatched byte counts or invalid byte index")
    if (len(baud) != 1 or len(ctrl) != 1 or baud[0][1] < 1 or ctrl[0][1] != 3
            or max(baud[0][0], ctrl[0][0]) >= writes[0][0]):
        raise ValueError("Sample needs one fixed baud and enabled internal loopback")
    for name, transfers in (("tx_push", writes), ("rx_pop", reads)):
        if rising_edges(vcd[f"tb_apb_uart.u_dut.{name}"].tv) != [t for t, _ in transfers]:
            raise ValueError(f"APB accesses do not match {name} pulses")

    clock = re.search(r"\[TB_CLOCKS\].*?uart_half=(\d+)ns", log)
    if not clock or int(clock[1]) <= 0:
        raise ValueError("Missing UART clock period in sample log")
    bit_ticks = Decimal(clock[1]) * 2 * baud[0][1] * Decimal("1e-9") / vcd.timescale["timescale"]
    if bit_ticks != int(bit_ticks) or bit_ticks < 1:
        raise ValueError("Bit period is not an integral number of VCD ticks")
    bit_ticks = int(bit_ticks)
    trace = vcd[TX_SIGNAL].tv
    starts = [t for (_, prev), (t, value) in zip(trace, trace[1:])
              if prev == "1" and value == "0"]
    frames = []
    until = 0
    for start in starts:
        if start < until:
            continue
        end = start + 10 * bit_ticks
        if end > vcd.endtime:
            raise ValueError("Incomplete recorded frame")
        if start > until and constant_level(trace, until, start) != 1:
            raise ValueError("Serial line is not idle between frames")
        bits = [constant_level(trace, start + b * bit_ticks, start + (b + 1) * bit_ticks)
                for b in range(10)]
        if bits[0] != 0 or bits[-1] != 1:
            raise ValueError("Invalid start or stop bit")
        value = sum(bit << b for b, bit in enumerate(bits[1:9]))
        frames.append({"start": start, "end": end, "bits": bits, "value": value})
        until = end
    if constant_level(trace, until, vcd.endtime) != 1:
        raise ValueError("Serial line is not idle after the recorded frames")
    if ([data for _, data in writes] != [frame["value"] for frame in frames]
            or [data for _, data in reads] != [frame["value"] for frame in frames]):
        raise ValueError("APB writes, serial frames and APB reads disagree")
    if any(not write[0] < frame["start"] < frame["end"] <= read[0]
           for write, frame, read in zip(writes, frames, reads)):
        raise ValueError("Byte order in time is inconsistent")
    return {**frames[index], "index": index, "count": len(frames), "bit_ticks": bit_ticks,
            "tx_access_start": writes[index][0], "rx_access_start": reads[index][0]}


def render(directory, output, theme="light"):
    if theme not in PALETTES:
        raise ValueError(f"Unknown preview theme: {theme}")
    colors = PALETTES[theme]
    if output.exists():
        raise FileExistsError(f"Output already exists; choose a new --output path: {output}")
    vcd, source_hash = load_sample(directory)
    record = annotated_byte(vcd, (directory / "log_excerpt.txt").read_text(encoding="utf-8-sig"))
    scale = float(vcd.timescale["timescale"]) * 1e6
    start, end, bit = record["start"], record["end"], record["bit_ticks"]
    byte = f"0x{record['value']:02X}"
    with plt.rc_context({"font.family": "DejaVu Sans", "font.size": 14,
                         "text.color": colors["text"], "axes.labelcolor": colors["text"],
                         "axes.facecolor": colors["background"],
                         "xtick.color": colors["ticks"], "ytick.color": colors["ticks"]}):
        fig = plt.figure(figsize=(5.4, 3.0), dpi=200)
        try:
            fig.text(0.5, 0.925, f"One byte through loopback: {byte}", ha="center", fontsize=16)
            for x, label, color in ((0.19, "APB write", colors["write"]),
                                    (0.5, "Serial TX", colors["serial"]),
                                    (0.81, "APB read", colors["read"])):
                fig.text(x, 0.82, label, ha="center", color=color)
                fig.text(x, 0.73, byte, ha="center", fontsize=17, color=color, weight="bold")
            ax = fig.add_axes((0.08, 0.23, 0.88, 0.38))
            ax.set_xlim((start - bit * 0.15) * scale, (end + bit * 0.15) * scale)
            draw_trace(ax, vcd[TX_SIGNAL].tv, vcd.endtime, scale, colors["serial"])
            ax.set_ylim(-0.18, 1.55)
            ax.set_yticks([0, 1])
            for b, label in enumerate(["S", *map(str, range(8)), "P"]):
                ax.axvline((start + b * bit) * scale, color=colors["grid"], linewidth=0.6, zorder=0)
                ax.text((start + (b + 0.5) * bit) * scale, 1.26, label, ha="center", fontsize=15)
            ax.set_xticks([(start + offset * bit) * scale for offset in (0, 3, 6, 10)])
            ax.set_xlabel("Time (us)", fontsize=13, labelpad=2)
            ax.tick_params(length=0, labelsize=13)
            for spine in ax.spines.values():
                spine.set_visible(False)
            fig.text(0.5, 0.025, "S: start   0-7: LSB first   P: stop", ha="center", fontsize=14)
            output.parent.mkdir(parents=True, exist_ok=True)
            with output.open("xb") as stream:
                fig.savefig(stream, format="png", facecolor=colors["background"], metadata={
                    "Source": "loopback.vcd", "SourceSHA256": source_hash,
                    "VCDTimescale": str(vcd.timescale["timescale"]) + " seconds",
                    "ByteIndex": str(record["index"]), "ByteValue": byte,
                    "Description": "Serial time axis only; APB values sampled at ACCESS starts.",
                    **({"Theme": theme} if theme != "light" else {}),
                })
        finally:
            plt.close(fig)
    return source_hash, record


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output", type=Path, required=True, help="New PNG path (not overwritten)")
    parser.add_argument("--theme", choices=PALETTES, default="light", help="Display palette only")
    args = parser.parse_args()
    try:
        source_hash, record = render(Path(__file__).resolve().parent, args.output, args.theme)
    except (ValueError, KeyError, OSError) as error:
        parser.exit(1, f"Byte preview failed: {error}\n")
    print(f"BYTE_PREVIEW_OK {args.output}\nVCD SHA256 {source_hash}")
    print(f"Matched {record['count']} bytes; showing index {record['index']}: 0x{record['value']:02X}")


if __name__ == "__main__":
    main()
