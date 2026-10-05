#!/usr/bin/env python3
"""Read an llm-batch results file, print its metric lines, and draw llm-batch.png.

The input is the results file LLMFlux writes (a JSON list of records
{input, output, error, metadata{model, timestamp, request_latency_ms, retry_count}}, or
{"results": [...]}); src/raw_vllm_batch.py writes the same shape. You may also pass the job's
log (logs/<jobid>.out or slurm-<jobid>.out): the results file is then the one its
`RESULTS_FILE:` line names, else results/results.json, else the newest data/output/*.json
of the topic directory.

Metrics (the same numbers `ws-check llm-batch` computes, with this file):
  RECORDS          records in the file
  ANSWERED         records with a non-empty output text
  JSON_VALID_RATE  records whose text is one JSON object with "field", "confidence" and "why"
                   (a surrounding ```json fence is allowed), divided by RECORDS
  FIELD_MATCH_RATE records whose JSON "field" equals the field in the custom_id, divided by RECORDS
  P50_LATENCY_MS, P90_LATENCY_MS
                   percentiles (linear interpolation, as LLMFlux) of metadata.request_latency_ms
                   over the answered records
The plot has two panels: the per-request latency, sorted, with p50 and p90 marked; and the
three rates. It is written to the topic directory unless --out is given. A `PLOT:` line says in
words what the plot shows (the latency's min, p50, p90 and max, and the three rates), so the
agent, which never opens images, can quote it; --metrics prints no PLOT: line.

    python analyze.py results/results.json       (module reset && module load llmflux: matplotlib)
    python3 analyze.py --metrics results/results.json   (numbers only; system python3 is enough)
"""
import argparse
import json
import re
import sys
from pathlib import Path

REQUIRED_KEYS = ("field", "confidence", "why")
JOB_RE = re.compile(r"(\d+)")

# Chart styling: one hue per series, recessive axes and grid, text in ink colors.
SERIES = "#2a78d6"
SURFACE = "#fcfcfb"
INK = "#0b0b0b"
INK_2 = "#52514e"
GRID = "#e4e3df"


def topic_dir(path):
    """The directory a results file or log belongs to: results/, logs/ and data/output/ climb up."""
    d = Path(path).resolve().parent
    if d.name == "output" and d.parent.name == "data":
        return d.parent.parent
    if d.name in ("results", "logs"):
        return d.parent
    return d


def find_results(path):
    """The results file for a results file (itself) or a job log."""
    p = Path(path)
    if p.suffix == ".json":
        return p
    tdir = topic_dir(p)
    for line in p.read_text(errors="replace").splitlines():
        if line.startswith("RESULTS_FILE:"):
            named = Path(line.split(":", 1)[1].strip())
            for base in (p.resolve().parent, tdir):
                cand = named if named.is_absolute() else base / named
                if cand.is_file():
                    return cand
    cand = tdir / "results" / "results.json"
    if cand.is_file():
        return cand
    outs = sorted((tdir / "data" / "output").glob("*.json"), key=lambda q: q.stat().st_mtime)
    return outs[-1] if outs else None


def load_records(path):
    data = json.loads(Path(path).read_text())
    if isinstance(data, dict) and isinstance(data.get("results"), list):
        data = data["results"]
    if not isinstance(data, list):
        raise ValueError(f"{path}: expected a JSON list of records or {{\"results\": [...]}}")
    return [r for r in data if isinstance(r, dict)]


def output_text(rec):
    """The generated text of a record: an OpenAI chat/completions response, or a plain string."""
    out = rec.get("output")
    if out is None:
        return ""
    if isinstance(out, str):
        return out
    if isinstance(out, dict):
        choices = out.get("choices") or []
        if choices and isinstance(choices[0], dict):
            c = choices[0]
            msg = c.get("message")
            if isinstance(msg, dict) and isinstance(msg.get("content"), str):
                return msg["content"]
            if isinstance(c.get("text"), str):
                return c["text"]
        for key in ("text", "content"):
            if isinstance(out.get(key), str):
                return out[key]
    return ""


def parse_answer(text):
    """The answer object when the text is one JSON object with the three keys, else None."""
    s = text.strip()
    if s.startswith("```"):
        s = s.split("\n", 1)[1] if "\n" in s else ""
        if s.rstrip().endswith("```"):
            s = s.rstrip()[:-3]
    try:
        obj = json.loads(s)
    except ValueError:
        return None
    if isinstance(obj, dict) and all(k in obj for k in REQUIRED_KEYS):
        return obj
    return None


def expected_field(rec):
    inp = rec.get("input") if isinstance(rec.get("input"), dict) else {}
    cid = str(inp.get("custom_id") or rec.get("custom_id") or "")
    m = re.match(r"^p\d+-(.+)$", cid)
    return m.group(1).replace("-", " ") if m else None


def percentile(values, pct):
    """Linear interpolation between closest ranks (LLMFlux's BatchProcessor._percentile)."""
    if not values:
        return None
    v = sorted(values)
    rank = (len(v) - 1) * (pct / 100.0)
    lo = int(rank)
    hi = min(lo + 1, len(v) - 1)
    return v[lo] + (v[hi] - v[lo]) * (rank - lo)


def metrics(records):
    n = len(records)
    answered = [r for r in records if output_text(r).strip()]
    answers = [parse_answer(output_text(r)) for r in records]
    valid = sum(1 for a in answers if a is not None)
    match = sum(1 for r, a in zip(records, answers)
                if a is not None and expected_field(r) is not None
                and str(a.get("field", "")).strip().lower() == expected_field(r))
    lat = [float((r.get("metadata") or {}).get("request_latency_ms")) for r in answered
           if isinstance((r.get("metadata") or {}).get("request_latency_ms"), (int, float))]
    return {
        "RECORDS": n,
        "ANSWERED": len(answered),
        "JSON_VALID_RATE": valid / n if n else 0.0,
        "FIELD_MATCH_RATE": match / n if n else 0.0,
        "P50_LATENCY_MS": percentile(lat, 50),
        "P90_LATENCY_MS": percentile(lat, 90),
    }, lat


def metric_lines(m):
    lines = [f"RECORDS: {m['RECORDS']}", f"ANSWERED: {m['ANSWERED']}",
             f"JSON_VALID_RATE: {m['JSON_VALID_RATE']:.4f}", f"FIELD_MATCH_RATE: {m['FIELD_MATCH_RATE']:.4f}"]
    for key in ("P50_LATENCY_MS", "P90_LATENCY_MS"):
        lines.append(f"{key}: {m[key]:.1f}" if m[key] is not None else f"{key}: (no latencies in the file)")
    return lines


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


def plot_line(m, lat):
    """The PLOT: line (C22, KF15): the sorted latency curve rises from its min to its max (p50 and p90
    marked), and the three rates."""
    n = m["RECORDS"] or 1
    return (f"PLOT: latency over {len(lat)} answered requests rises from {min(lat):.0f} ms to {max(lat):.0f} ms "
            f"(p50 {m['P50_LATENCY_MS']:.0f} ms, p90 {m['P90_LATENCY_MS']:.0f} ms); rates: answered "
            f"{m['ANSWERED'] / n:.3f}, valid JSON {m['JSON_VALID_RATE']:.3f}, field matches {m['FIELD_MATCH_RATE']:.3f}")


def plot(m, lat, title, out):
    import matplotlib
    matplotlib.use("Agg")
    import matplotlib.pyplot as plt

    fig, axes = plt.subplots(1, 2, figsize=(9, 3.6), facecolor=SURFACE)
    ax = axes[0]
    style_axes(ax)
    xs = list(range(1, len(lat) + 1))
    ax.plot(xs, sorted(lat), color=SERIES, linewidth=2, marker="o", markersize=4)
    for key, pct in (("P50_LATENCY_MS", "p50"), ("P90_LATENCY_MS", "p90")):
        if m[key] is not None:
            ax.axhline(m[key], color=INK_2, linewidth=1, linestyle="--")
            ax.annotate(f"{pct} {m[key]:.0f} ms", (1, m[key]), textcoords="offset points", xytext=(2, 4),
                        color=INK, fontsize=9)
    ax.set_xlabel("answered requests, fastest to slowest", color=INK_2)
    ax.set_title("request latency (ms)", color=INK, fontsize=10, loc="left")
    ax = axes[1]
    style_axes(ax)
    n = m["RECORDS"] or 1
    names = ["answered", "valid JSON", "field matches"]
    vals = [m["ANSWERED"] / n, m["JSON_VALID_RATE"], m["FIELD_MATCH_RATE"]]
    ax.barh(names[::-1], vals[::-1], color=SERIES, height=0.5)
    for y, v in enumerate(vals[::-1]):
        ax.annotate(f"{v:.3f}", (v, y), textcoords="offset points", xytext=(4, 0), va="center",
                    color=INK, fontsize=9)
    ax.set_xlim(0, 1.15)
    ax.set_title(f"rates over {m['RECORDS']} records", color=INK, fontsize=10, loc="left")
    fig.suptitle(title, color=INK, fontsize=11, x=0.02, ha="left")
    fig.tight_layout()
    savefig(fig, out, dpi=120, facecolor=SURFACE)
    plt.close(fig)


def main():
    ap = argparse.ArgumentParser(description="Metrics and plot from an llm-batch results file (or job log).")
    ap.add_argument("path", help="results/results.json, or the job's log (logs/<jobid>.out, slurm-<jobid>.out)")
    ap.add_argument("--metrics", action="store_true", help="print the metric lines only (no plot, no matplotlib)")
    ap.add_argument("--out", help="plot path (default: llm-batch.png in the topic directory)")
    args = ap.parse_args()

    src = Path(args.path)
    if not src.is_file():
        sys.exit(f"no such file: {src}")
    res = find_results(src)
    if res is None or not res.is_file():
        sys.exit(f"no results file for {src} (expected results/results.json beside logs/)")
    try:
        m, lat = metrics(load_records(res))
    except ValueError as e:
        sys.exit(f"unreadable results file: {e}")
    if args.metrics:
        print("\n".join(metric_lines(m)))
        return 0

    jobid = None
    if src.suffix != ".json":
        mm = JOB_RE.search(src.name)
        jobid = mm.group(1) if mm else None
    if jobid:
        print(f"JOBID: {jobid}")
    print(f"results: {res}")
    print("\n".join(metric_lines(m)))
    if not lat:
        sys.exit("no answered record with a latency: nothing to plot")
    out = Path(args.out) if args.out else topic_dir(res) / "llm-batch.png"
    title = (f"llm-batch{' job ' + jobid if jobid else ''}: ANSWERED {m['ANSWERED']}/{m['RECORDS']}, "
             f"JSON_VALID_RATE {m['JSON_VALID_RATE']:.4f}, P50_LATENCY_MS {m['P50_LATENCY_MS']:.1f}")
    plot(m, lat, title, out)
    print(f"plot: {out}")
    print(plot_line(m, lat))
    return 0


if __name__ == "__main__":
    sys.exit(main())
