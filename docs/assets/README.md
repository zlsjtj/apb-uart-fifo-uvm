# Homepage Visuals

## Cover

[1280 x 640 JPEG](social-preview.jpg)

The cover is generated concept artwork: two layered FIFO queues and data paths
in graphite, cyan, coral, and amber. It is not a chip photograph, a physical
layout, or a literal representation of FIFO depth or wiring. The diagrams below
and the recorded VCDs carry the technical meaning.

Created on 2026-10-05 with ImageGen, then exported using Sharp 0.35.4 to a
1280 x 640 JPEG (quality 92, 4:4:4 chroma). The art direction was an isometric
hardware sculpture, restrained material lighting, large APB/UART typography,
and no benchmark numbers or fabricated hardware markings. There is no vector
source or deterministic renderer for this bitmap artwork.

Upload `social-preview.jpg` through **Settings > General > Social preview >
Edit > Upload an image** to use it for shared links. Merely committing the
image does not activate it. See GitHub's
[official instructions](https://docs.github.com/en/repositories/managing-your-repositorys-settings-and-features/customizing-your-repository/customizing-your-repositorys-social-media-preview).

## README Banner

[1536 x 512 JPEG](readme-banner.jpg)

The README uses a separate 3:1 banner to keep its title, results, and run links
closer together. The 2:1 social preview above is unchanged. Both are concept
artwork, not technical diagrams.

The banner was edited with the built-in ImageGen tool on 2026-10-05, using
`social-preview.jpg` as its reference. The edit kept the graphite, cyan, coral,
and amber palette, recomposed both FIFO queues for a panoramic frame, and kept
only the large `APB / UART` text. The original 2172 x 724 output was resized
proportionally to 1536 x 512 with Sharp 0.35.4 and exported as JPEG
(quality 92, 4:4:4 chroma), without cropping. No deterministic renderer exists
for this artwork.

## Architecture Diagram

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

## Earlier Diagram-Based Preview

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

This older alternative is retained with its source; the current cover is the
JPEG above. Its renderer only writes PNG/SVG and cannot overwrite that JPEG.
The renderer uses `render_architecture.py`, Matplotlib, and its bundled
DejaVu Sans font. It refuses to overwrite existing output. The SVG keeps
editable text.

Use this script only to rebuild the earlier diagram-based option, not the
new bitmap cover.
