# Homepage Diagram

[Desktop SVG](architecture.svg) · [Mobile SVG](architecture-mobile.svg) ·
[Rendering script](render_architecture.py)

The overview follows [apb_uart.sv](../../rtl/apb_uart.sv) and the analysis-port
connections in [uart_env.svh](../../tb/uvm/uart_env.svh). Teal follows TX,
coral follows RX, and the lower panel separates observed data from predictions.
Arrows, labels, and placement carry the meaning without relying on color alone.

This is a structural overview, not a simulation trace. The UART blocks are
instantiated in [apb_uart_serial_core](../../rtl/apb_uart_serial_core.sv);
the FIFO crossing is the dashed boundary. The
mobile layout reads top to bottom. Both layouts omit configuration handshakes,
reset, the internal loopback mux, RAL, coverage, and assertions. See the
[detailed architecture](../architecture_figures.md) for the broader context.
The actual-data branch includes APB and TX observations only; RX pin
observations enter the predictor, not the scoreboard directly.

Rebuild with Python and Matplotlib (rendered with Matplotlib 3.11.2):

```bash
python docs/assets/render_architecture.py --output-dir work_overview
```

Choose a new output directory; existing images will not be overwritten. The
script writes two PNGs and two editable-text SVGs, using Matplotlib's bundled
DejaVu Sans. PNGs are embedded in the README for consistent font rendering;
SVGs remain editable. The vertical asset is selected below 1024 CSS pixels,
including narrow tablet layouts where GitHub's sidebar reduces article width.

These files do not replace or modify the saved VCD and waveform plots in
[`examples/loopback`](../../examples/loopback/README.md).

## Social Preview

[PNG for upload](social-preview.png) · [Editable SVG](social-preview.svg) ·
[Rendering script](render_social_preview.py)

This 1280 x 640 image uses the same TX/RX colors and data directions as the
overview. Its two results belong to
[v0.1.0, validated on 2026-10-04](https://github.com/zlsjtj/apb-uart-fifo-uvm/releases/tag/v0.1.0):
60/60 UVM runs passed and 13/13 declared RTL faults detected, each with a
passing matching baseline. The drawing is structural, not a waveform.

```bash
python docs/assets/render_social_preview.py --output-dir work_social_preview
```

The renderer uses `render_architecture.py`, Matplotlib, and its bundled
DejaVu Sans font. It refuses to overwrite existing output. The SVG keeps
editable text; use the PNG for GitHub's share image.

To activate it, upload `social-preview.png` in the repository's
**Settings > General > Social preview > Edit > Upload an image**.
Committing this file alone does not change the share preview. GitHub recommends
1280 x 640 pixels and a file smaller than 1 MB; see the
[official setup instructions](https://docs.github.com/en/repositories/managing-your-repositorys-settings-and-features/customizing-your-repository/customizing-your-repositorys-social-media-preview).
