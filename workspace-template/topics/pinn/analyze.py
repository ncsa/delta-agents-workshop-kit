#!/usr/bin/env python3
"""Read a pinn job log, print its metric lines, and draw pinn.png.

Parses only the log protocol lines (topics/LOG-PROTOCOL.md) and the lines src/pinn.py
prints for the plot: `[ws-env]`, `[pinn] ... alpha=<a>`, `STEP n loss <l>`,
`PROFILE <t> <x> <u_pred>`, `L2_ERROR:`, `PDE_RESIDUAL:`, `TRAIN_SECONDS:`, `RESULTS_OK`.
The plot has two panels: the training loss per step (log scale), and the predicted
u(x, t) against the analytic exp(-alpha pi^2 t) sin(pi x) at t = 0.25 and t = 0.5.
It is written next to the log unless --out is given. A `PLOT:` line says in words what the
plot shows (the loss trend with its min and max, each profile's peak against the exact one),
so the agent, which never opens images, can quote it.

    python topics/pinn/analyze.py slurm-<jobid>.out
"""
import argparse
import math
import re
import sys
from pathlib import Path

STEP_RE = re.compile(r"^STEP\s+(\d+)\s+loss[=\s]+([-+0-9.eE]+)")
PROFILE_RE = re.compile(r"^PROFILE\s+([-+0-9.eE]+)\s+([-+0-9.eE]+)\s+([-+0-9.eE]+)")
KEY_RE = re.compile(r"^([A-Z][A-Z0-9_]*):\s*([-+]?[0-9.]+(?:[eE][-+]?[0-9]+)?)")
ALPHA_RE = re.compile(r"\balpha=([-+0-9.eE]+)")
JOB_RE = re.compile(r"\bjob=(\S+)")

# Chart styling: one hue per series, recessive axes and grid, text in ink colors.
SERIES = ("#2a78d6", "#d9730d")
SURFACE = "#fcfcfb"
INK = "#0b0b0b"
INK_2 = "#52514e"
GRID = "#e4e3df"


def parse(path):
    steps, profiles, metrics, env, alpha, ok = [], {}, {}, None, None, False
    for line in Path(path).read_text(errors="replace").splitlines():
        line = line.rstrip()
        if line.startswith("[ws-env]") and env is None:
            env = line
        elif line.startswith("[pinn]") and (m := ALPHA_RE.search(line)):
            alpha = float(m.group(1))
        elif line == "RESULTS_OK":
            ok = True
        elif (m := STEP_RE.match(line)):
            steps.append((int(m.group(1)), float(m.group(2))))
        elif (m := PROFILE_RE.match(line)):
            profiles.setdefault(float(m.group(1)), []).append((float(m.group(2)), float(m.group(3))))
        elif (m := KEY_RE.match(line)):
            metrics[m.group(1)] = m.group(2)  # the last value wins, as in check.sh
    return steps, profiles, metrics, env, alpha, ok


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


def plot_line(steps, profiles, alpha):
    """The PLOT: line (C22, KF15): the loss trend from the first step to the last with its min and max,
    and each plotted profile's peak, against the exact peak exp(-alpha pi^2 t) when alpha is known."""
    ys = [s[1] for s in steps]
    word = "rises" if ys[-1] > ys[0] else "falls" if ys[-1] < ys[0] else "stays flat"
    parts = [f"training loss {word} from {ys[0]:.2e} (step {steps[0][0]}) to {ys[-1]:.2e} (step {steps[-1][0]}), "
             f"min {min(ys):.2e}, max {max(ys):.2e}"]
    for t in sorted(profiles)[:2]:
        peak = max(p[1] for p in profiles[t])
        exact = f" (exact {math.exp(-alpha * math.pi ** 2 * t):.3f})" if alpha is not None else ""
        parts.append(f"u(x, t={t:g}) peaks at {peak:.3f}{exact}")
    return "PLOT: " + "; ".join(parts)


def plot(steps, profiles, metrics, alpha, jobid, out):
    import matplotlib
    matplotlib.use("Agg")
    import matplotlib.pyplot as plt

    fig, (ax_loss, ax_u) = plt.subplots(1, 2, figsize=(9, 3.6), facecolor=SURFACE)

    style_axes(ax_loss)
    xs, ys = [s[0] for s in steps], [s[1] for s in steps]
    ax_loss.plot(xs, ys, color=SERIES[0], linewidth=2)
    ax_loss.set_yscale("log")
    ax_loss.annotate(f"{ys[-1]:.2e}", (xs[-1], ys[-1]), textcoords="offset points",
                     xytext=(-10, -4), ha="right", va="center", color=INK, fontsize=9)
    ax_loss.set_xlabel("step", color=INK_2)
    ax_loss.set_title("training loss (PDE + initial + boundary)", color=INK, fontsize=10, loc="left")

    style_axes(ax_u)
    top = 0.0
    # direct labels: the earlier (higher) profile is labelled above its peak, the later one below
    for n, (color, t) in enumerate(zip(SERIES, sorted(profiles)[:2])):
        pts = sorted(profiles[t])
        top = max(top, max(p[1] for p in pts))
        px, pu = [p[0] for p in pts], [p[1] for p in pts]
        if alpha is not None:
            fine = [i / 200 for i in range(201)]
            ax_u.plot(fine, [math.exp(-alpha * math.pi ** 2 * t) * math.sin(math.pi * x) for x in fine],
                      color=color, linewidth=1.5, alpha=0.6)
        ax_u.plot(px, pu, linestyle="none", marker="o", markersize=5, color=color,
                  markeredgecolor=SURFACE, markeredgewidth=1)
        i_peak = max(range(len(pu)), key=lambda i: pu[i])
        ax_u.annotate(f"t = {t:g}", (px[i_peak], pu[i_peak]), textcoords="offset points",
                      xytext=(0, 8 if n == 0 else -10), ha="center", va="bottom" if n == 0 else "top",
                      color=color, fontsize=9)
    if top > 0:
        ax_u.set_ylim(top=top * 1.15)
    ax_u.set_xlabel("x", color=INK_2)
    title = "u(x, t): dots = PINN, lines = exact" if alpha is not None else "u(x, t) predicted by the PINN"
    ax_u.set_title(title, color=INK, fontsize=10, loc="left")

    fig.suptitle(f"pinn job {jobid}: L2_ERROR {metrics.get('L2_ERROR', 'n/a')}, "
                 f"PDE_RESIDUAL {metrics.get('PDE_RESIDUAL', 'n/a')}",
                 color=INK, fontsize=11, x=0.02, ha="left")
    fig.tight_layout()
    savefig(fig, out, dpi=120, facecolor=SURFACE)
    plt.close(fig)


def main():
    ap = argparse.ArgumentParser(description="Metrics and plot from a pinn job log.")
    ap.add_argument("log", help="the job's log, e.g. slurm-<jobid>.out")
    ap.add_argument("--out", help="plot path (default: pinn.png next to the log)")
    ap.add_argument("--alpha", type=float, help="diffusivity for the exact curve (default: from the log)")
    args = ap.parse_args()

    log = Path(args.log)
    if not log.is_file():
        sys.exit(f"no such log: {log}")
    steps, profiles, metrics, env, alpha, ok = parse(log)
    if args.alpha is not None:
        alpha = args.alpha
    m = JOB_RE.search(env or "") or re.search(r"(\d+)", log.name)
    jobid = m.group(1) if m else "unknown"

    print(f"JOBID: {jobid}")
    print(env or "[ws-env] (missing: the log has no [ws-env] line)")
    for key in ("L2_ERROR", "PDE_RESIDUAL", "TRAIN_SECONDS"):
        print(f"{key}: {metrics[key]}" if key in metrics else f"{key}: (missing in the log)")
    print("RESULTS_OK" if ok else "RESULTS_OK missing: the run did not finish")
    if not steps:
        sys.exit("no STEP lines in the log: nothing to plot")
    out = Path(args.out) if args.out else log.with_name("pinn.png")
    plot(steps, profiles, metrics, alpha, jobid, out)
    print(f"plot: {out}")
    print(plot_line(steps, profiles, alpha))
    return 0 if ok and "L2_ERROR" in metrics and "PDE_RESIDUAL" in metrics else 1


if __name__ == "__main__":
    sys.exit(main())
