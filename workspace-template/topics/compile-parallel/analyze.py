#!/usr/bin/env python3
"""Read a compile-parallel job log, print its metric lines, and draw scaling.png.

Parses only the log protocol lines (topics/LOG-PROTOCOL.md): `[ws-env]`, the programs'
`PROGRAM: <name> N: <n>` and `RESULT: <pi> TIME: <s> WORKERS: <w>` pairs, report.py's
`SPEEDUP_OMP16:`, `SPEEDUP_MPI16:`, `RESULT_AGREE:`, and `RESULTS_OK`.
Speedup is serial TIME / parallel TIME; efficiency is speedup / workers. The plot has two
panels, speedup and efficiency against workers (OpenMP threads as a line, MPI ranks as
points, the ideal as a dashed line). It is written next to the log unless --out is given. A
`PLOT:` line says in words what the plot shows (each series' speedup from the fewest workers to
the most, and its efficiency's min and max), so the agent, which never opens images, can quote it.

    module reset && module load pytorch-conda/2.12 && python topics/compile-parallel/analyze.py slurm-<jobid>.out
"""
import argparse
import re
import sys
from pathlib import Path

PROG_RE = re.compile(r"^PROGRAM:\s*(\S+)")
RES_RE = re.compile(r"^RESULT:\s*([-+0-9.eE]+)\s+TIME:\s*([-+0-9.eE]+)\s+WORKERS:\s*(\d+)")
KEY_RE = re.compile(r"^([A-Z][A-Z0-9_]*):\s*(\S+)")
JOB_RE = re.compile(r"\bjob=(\S+)")

# Chart styling: categorical slots 1 and 2 (OpenMP, MPI), recessive axes and grid, text in ink colors.
OMP = "#2a78d6"
MPI = "#eb6834"
SURFACE = "#fcfcfb"
INK = "#0b0b0b"
INK_2 = "#52514e"
GRID = "#e4e3df"


def parse(path):
    runs, metrics, env, ok, prog = [], {}, None, False, None
    for line in Path(path).read_text(errors="replace").splitlines():
        line = line.rstrip()
        if line.startswith("[ws-env]") and env is None:
            env = line
        elif line == "RESULTS_OK":
            ok = True
        elif (m := PROG_RE.match(line)):
            prog = m.group(1)
        elif (m := RES_RE.match(line)):
            runs.append((prog or "unknown", float(m.group(1)), float(m.group(2)), int(m.group(3))))
            prog = None
        elif (m := KEY_RE.match(line)):
            metrics[m.group(1)] = m.group(2)  # the last value wins, as in check.sh
    return runs, metrics, env, ok


def scaling(runs):
    """(serial time, {threads: time}, {ranks: time}) from the last run of each kind and worker count."""
    serial = [r[2] for r in runs if r[0] == "pi_serial"]
    omp = {r[3]: r[2] for r in runs if r[0] == "pi_omp"}
    mpi = {r[3]: r[2] for r in runs if r[0] == "pi_mpi"}
    return (serial[-1] if serial else None), omp, mpi


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


def plot_line(ts, omp, mpi):
    """The PLOT: line (C22, KF15): per series, the speedup's trend from the fewest workers to the most,
    and the efficiency's min and max."""
    parts = []
    for name, unit, table in (("OpenMP", "threads", omp), ("MPI", "ranks", mpi)):
        if not table:
            continue
        ws = sorted(table)
        sp = [ts / table[w] for w in ws]
        eff = [s / w for s, w in zip(sp, ws)]
        if len(ws) == 1:   # one point (the prepared job runs MPI at 16 ranks only)
            parts.append(f"{name} speedup {sp[0]:.2f} at {ws[0]} {unit} (ideal {ws[0]}), efficiency {eff[0]:.2f}")
            continue
        word = "rises" if sp[-1] > sp[0] else "falls" if sp[-1] < sp[0] else "stays flat"
        parts.append(f"{name} speedup {word} from {sp[0]:.2f} at {ws[0]} to {sp[-1]:.2f} at {ws[-1]} {unit} "
                     f"(ideal {ws[-1]}), efficiency min {min(eff):.2f}, max {max(eff):.2f}")
    return "PLOT: " + "; ".join(parts)


def plot(ts, omp, mpi, metrics, jobid, out):
    import matplotlib
    matplotlib.use("Agg")
    import matplotlib.pyplot as plt

    workers = sorted(set(omp) | set(mpi) | {1})
    fig, axes = plt.subplots(1, 2, figsize=(9, 3.6), facecolor=SURFACE)
    for ax, title, fn, ideal in ((axes[0], "speedup (serial time / time)", lambda w, t: ts / t, workers),
                                 (axes[1], "parallel efficiency (speedup / workers)", lambda w, t: ts / t / w,
                                  [1.0] * len(workers))):
        style_axes(ax)
        ax.plot(workers, ideal, color=INK_2, linewidth=1, linestyle="--", label="ideal")
        for table, color, label in ((omp, OMP, "OpenMP threads"), (mpi, MPI, "MPI ranks")):
            if not table:
                continue
            xs = sorted(table)
            ys = [fn(w, table[w]) for w in xs]
            ax.plot(xs, ys, color=color, linewidth=2 if len(xs) > 1 else 0, marker="o", markersize=8,
                    markeredgecolor=SURFACE, markeredgewidth=2, label=label, zorder=3)
            ax.annotate(f"{ys[-1]:.2f}", (xs[-1], ys[-1]), textcoords="offset points", xytext=(8, 0),
                        va="center", color=INK, fontsize=9)
        ax.set_xscale("log", base=2)
        ax.set_xticks(workers)
        ax.set_xticklabels([str(w) for w in workers])
        ax.set_xlabel("workers", color=INK_2)
        ax.set_title(title, color=INK, fontsize=10, loc="left")
    axes[1].set_ylim(0, 1.15)
    axes[0].legend(frameon=False, fontsize=9, labelcolor=INK_2, loc="upper left")
    fig.suptitle(f"compile-parallel job {jobid}: SPEEDUP_OMP16 {metrics.get('SPEEDUP_OMP16', 'n/a')}, "
                 f"SPEEDUP_MPI16 {metrics.get('SPEEDUP_MPI16', 'n/a')}", color=INK, fontsize=11, x=0.02, ha="left")
    fig.tight_layout()
    savefig(fig, out, dpi=120, facecolor=SURFACE)
    plt.close(fig)


def main():
    ap = argparse.ArgumentParser(description="Metrics and scaling plot from a compile-parallel job log.")
    ap.add_argument("log", help="the job's log, e.g. slurm-<jobid>.out")
    ap.add_argument("--out", help="plot path (default: scaling.png next to the log)")
    args = ap.parse_args()

    log = Path(args.log)
    if not log.is_file():
        sys.exit(f"no such log: {log}")
    runs, metrics, env, ok = parse(log)
    m = JOB_RE.search(env or "") or re.search(r"(\d+)", log.name)
    jobid = m.group(1) if m else "unknown"
    ts, omp, mpi = scaling(runs)

    print(f"JOBID: {jobid}")
    print(env or "[ws-env] (missing: the log has no [ws-env] line)")
    for key in ("SPEEDUP_OMP16", "SPEEDUP_MPI16", "RESULT_AGREE"):
        print(f"{key}: {metrics[key]}" if key in metrics else f"{key}: (missing in the log)")
    print("RESULTS_OK" if ok else "RESULTS_OK missing: the run did not finish")
    if ts is None or not (omp or mpi):
        sys.exit("no pi_serial run, or no parallel run, in the log: nothing to plot")
    print("workers  omp_speedup  omp_efficiency  mpi_speedup  mpi_efficiency")
    for w in sorted(set(omp) | set(mpi)):
        cols = []
        for table in (omp, mpi):
            cols += [f"{ts / table[w]:.2f}", f"{ts / table[w] / w:.2f}"] if w in table else ["-", "-"]
        print(f"{w:>7}  {cols[0]:>11}  {cols[1]:>14}  {cols[2]:>11}  {cols[3]:>14}")
    out = Path(args.out) if args.out else log.with_name("scaling.png")
    plot(ts, omp, mpi, metrics, jobid, out)
    print(f"plot: {out}")
    print(plot_line(ts, omp, mpi))
    return 0 if ok and "SPEEDUP_OMP16" in metrics and "SPEEDUP_MPI16" in metrics else 1


if __name__ == "__main__":
    sys.exit(main())
