#!/usr/bin/env python3
"""Read an ml-gpu job log, print its metric lines, and draw ml-gpu.png.

Parses only the log protocol lines (topics/LOG-PROTOCOL.md): `[ws-env]`,
`EPOCH n loss <l> acc <a>`, `THROUGHPUT:`, `ACCURACY:`, `RESULTS_OK`.
The plot has two panels, training loss and test accuracy per epoch, with the
throughput in the title. It is written next to the log unless --out is given. A `PLOT:`
line says in words what the plot shows (each panel's trend, min and max), so the agent,
which never opens images, can quote it.

    python topics/ml-gpu/analyze.py slurm-<jobid>.out
"""
import argparse
import re
import sys
from pathlib import Path

EPOCH_RE = re.compile(r"^EPOCH\s+(\d+)\s+loss[=\s]+([-+0-9.eE]+)\s+acc[=\s]+([-+0-9.eE]+)")
KEY_RE = re.compile(r"^([A-Z][A-Z0-9_]*):\s*([-+]?[0-9.]+(?:[eE][-+]?[0-9]+)?)")
JOB_RE = re.compile(r"\bjob=(\S+)")

# Chart styling: one hue per series, recessive axes and grid, text in ink colors.
SERIES = "#2a78d6"
SURFACE = "#fcfcfb"
INK = "#0b0b0b"
INK_2 = "#52514e"
GRID = "#e4e3df"


def parse(path):
    epochs, metrics, env, ok = [], {}, None, False
    for line in Path(path).read_text(errors="replace").splitlines():
        line = line.rstrip()
        if line.startswith("[ws-env]") and env is None:
            env = line
        elif line == "RESULTS_OK":
            ok = True
        elif (m := EPOCH_RE.match(line)):
            epochs.append((int(m.group(1)), float(m.group(2)), float(m.group(3))))
        elif (m := KEY_RE.match(line)):
            metrics[m.group(1)] = m.group(2)  # the last value wins, as in check.sh
    return epochs, metrics, env, ok


def style_axes(ax):
    ax.set_facecolor(SURFACE)
    for side in ("top", "right"):
        ax.spines[side].set_visible(False)
    for side in ("left", "bottom"):
        ax.spines[side].set_color(INK_2)
    ax.tick_params(colors=INK_2, labelsize=9)
    ax.grid(True, color=GRID, linewidth=0.8)
    ax.set_axisbelow(True)


def agg_text_workaround():
    """Work around "FT_Render_Glyph ... raster overflow" (pytorch-conda/2.12: matplotlib 3.11, FreeType
    2.14.2): Agg asks FreeType to render each glyph at its absolute canvas offset, which overflows away
    from the origin. Render near the origin (keeping the sub-pixel part) and place the bitmap ourselves."""
    import math

    import numpy as np
    from matplotlib.backends import backend_agg as ba

    orig = ba.RendererAgg._draw_text_glyphs_and_boxes

    def draw(self, gc, x, y, angle, glyphs, boxes):
        cos, sin = math.cos(math.radians(angle)), math.sin(math.radians(angle))
        flags = ba.get_hinting_flag()
        for font, size, glyph_index, slant, extend, dx, dy in glyphs:
            font.set_size(size, self.dpi)
            tx = round(0x40 * (x + dx * cos - dy * sin))
            ty = round(0x40 * (self.height - y + dx * sin + dy * cos))
            ix, iy = tx // 0x40, ty // 0x40
            matrix = (0x10000 * np.array([[cos, -sin], [sin, cos]])
                      @ [[extend, extend * slant], [0, 1]]).round().astype(int)
            font._set_transform(matrix, [tx - 0x40 * ix, ty - 0x40 * iy])
            bitmap = font._render_glyph(glyph_index, flags,
                                        ba.RenderMode.NORMAL if gc.get_antialiased() else ba.RenderMode.MONO)
            buffer = bitmap.buffer
            if not gc.get_antialiased():
                buffer *= 0xff
            self._renderer.draw_text_image(buffer, bitmap.left + ix,
                                           int(self.height) - (bitmap.top + iy) + buffer.shape[0], 0, gc)
        orig(self, gc, x, y, angle, (), boxes)

    ba.RendererAgg._draw_text_glyphs_and_boxes = draw


def savefig(fig, out, **kw):
    """fig.savefig, retried once with agg_text_workaround() on FreeType's "raster overflow"."""
    try:
        fig.savefig(out, **kw)
    except RuntimeError as e:
        if "raster overflow" not in str(e):
            raise
        agg_text_workaround()
        fig.savefig(out, **kw)


def trend(ys):
    """"rises", "falls" or "stays flat" from the first value to the last."""
    return "rises" if ys[-1] > ys[0] else "falls" if ys[-1] < ys[0] else "stays flat"


def plot_line(epochs):
    """The PLOT: line (C22, KF15): each panel's trend from the first epoch to the last, min and max."""
    parts = []
    for name, ys in (("training loss", [e[1] for e in epochs]), ("test accuracy", [e[2] for e in epochs])):
        parts.append(f"{name} {trend(ys)} from {ys[0]:.3f} (epoch {epochs[0][0]}) to {ys[-1]:.3f} "
                     f"(epoch {epochs[-1][0]}), min {min(ys):.3f}, max {max(ys):.3f}")
    return "PLOT: " + "; ".join(parts)


def plot(epochs, metrics, jobid, out):
    import matplotlib
    matplotlib.use("Agg")
    import matplotlib.pyplot as plt

    xs = [e[0] for e in epochs]
    fig, axes = plt.subplots(1, 2, figsize=(9, 3.6), facecolor=SURFACE)
    for ax, ys, label, fmt in ((axes[0], [e[1] for e in epochs], "training loss", "{:.3f}"),
                               (axes[1], [e[2] for e in epochs], "test accuracy", "{:.3f}")):
        style_axes(ax)
        ax.plot(xs, ys, color=SERIES, linewidth=2, marker="o", markersize=7,
                markeredgecolor=SURFACE, markeredgewidth=2)
        ax.annotate(fmt.format(ys[-1]), (xs[-1], ys[-1]), textcoords="offset points",
                    xytext=(8, 0), va="center", color=INK, fontsize=9)
        ax.set_xlabel("epoch", color=INK_2)
        ax.set_title(label, color=INK, fontsize=10, loc="left")
        ax.set_xticks(xs)
        if len(xs) == 1:
            ax.set_xlim(xs[0] - 0.5, xs[0] + 1.0)
    thr = metrics.get("THROUGHPUT", "n/a")
    fig.suptitle(f"ml-gpu job {jobid}: THROUGHPUT {thr} samples/s, ACCURACY {metrics.get('ACCURACY', 'n/a')}",
                 color=INK, fontsize=11, x=0.02, ha="left")
    fig.tight_layout()
    savefig(fig, out, dpi=120, facecolor=SURFACE)
    plt.close(fig)


def main():
    ap = argparse.ArgumentParser(description="Metrics and plot from an ml-gpu job log.")
    ap.add_argument("log", help="the job's log, e.g. slurm-<jobid>.out")
    ap.add_argument("--out", help="plot path (default: ml-gpu.png next to the log)")
    args = ap.parse_args()

    log = Path(args.log)
    if not log.is_file():
        sys.exit(f"no such log: {log}")
    epochs, metrics, env, ok = parse(log)
    m = JOB_RE.search(env or "") or re.search(r"(\d+)", log.name)
    jobid = m.group(1) if m else "unknown"

    print(f"JOBID: {jobid}")
    print(env or "[ws-env] (missing: the log has no [ws-env] line)")
    for key in ("THROUGHPUT", "ACCURACY"):
        print(f"{key}: {metrics[key]}" if key in metrics else f"{key}: (missing in the log)")
    print("RESULTS_OK" if ok else "RESULTS_OK missing: the run did not finish")
    if not epochs:
        sys.exit("no EPOCH lines in the log: nothing to plot")
    out = Path(args.out) if args.out else log.with_name("ml-gpu.png")
    plot(epochs, metrics, jobid, out)
    print(f"plot: {out}")
    print(plot_line(epochs))
    return 0 if ok and "THROUGHPUT" in metrics and "ACCURACY" in metrics else 1


if __name__ == "__main__":
    sys.exit(main())
