#!/usr/bin/env python3
"""Render selected signals from a VCD file to a PNG timing diagram.

Usage:
    python3 scripts/plot_wave.py build/tb_uart_echo_top.vcd docs/uart_echo.png \
        --start 0 --end 4000 \
        --signals tb_uart_echo_top.h_txd tb_uart_echo_top.dut.rx_valid \
                  tb_uart_echo_top.dut_txd

Times are in ns. Requires: pip install vcdvcd matplotlib
"""
import argparse

import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt
from vcdvcd import VCDVCD


def to_int(v):
    try:
        return int(v, 2)
    except ValueError:
        return None  # x / z


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("vcd")
    ap.add_argument("out")
    ap.add_argument("--signals", nargs="+", required=True)
    ap.add_argument("--labels", nargs="+")
    ap.add_argument("--start", type=float, default=0)
    ap.add_argument("--end", type=float, required=True)
    ap.add_argument("--title", default="")
    a = ap.parse_args()

    vcd = VCDVCD(a.vcd)
    scale = 1e-3  # VCD timescale is 1ps in these testbenches -> convert to ns
    labels = a.labels or [s.split(".")[-1] for s in a.signals]

    n = len(a.signals)
    fig, axes = plt.subplots(n, 1, figsize=(12, 0.9 * n + 0.8), sharex=True)
    if n == 1:
        axes = [axes]

    for ax, name, label in zip(axes, a.signals, labels):
        sig = vcd[name]
        width = int(sig.size)
        tv = [(t * scale, v) for t, v in sig.tv]
        # value at window start
        xs, ys, segs = [], [], []
        cur = None
        for t, v in tv:
            if t <= a.start:
                cur = v
        pts = [(a.start, cur)] + [(t, v) for t, v in tv if a.start < t < a.end] + [(a.end, None)]
        if width == 1:
            for (t0, v0), (t1, _) in zip(pts, pts[1:]):
                y = to_int(v0) if v0 is not None else 0
                xs += [t0, t1]
                ys += [y, y]
            ax.plot(xs, ys, drawstyle="steps-post", lw=1.6, color="#1f6feb")
            ax.set_ylim(-0.3, 1.3)
        else:
            for (t0, v0), (t1, _) in zip(pts, pts[1:]):
                ax.fill_between([t0, t1], 0.1, 0.9, color="#dbe9ff", ec="#1f6feb", lw=1)
                val = to_int(v0) if v0 is not None else None
                txt = "x" if val is None else f"{val:02X}"
                if t1 - t0 > (a.end - a.start) * 0.03:
                    ax.text((t0 + t1) / 2, 0.5, txt, ha="center", va="center", fontsize=8)
            ax.set_ylim(0, 1)
        ax.set_yticks([])
        ax.set_ylabel(label, rotation=0, ha="right", va="center", fontsize=9)
        for s in ("top", "right", "left"):
            ax.spines[s].set_visible(False)
        ax.grid(axis="x", alpha=0.25)

    axes[-1].set_xlim(a.start, a.end)
    axes[-1].set_xlabel("time (ns)")
    if a.title:
        fig.suptitle(a.title, fontsize=11)
    fig.tight_layout()
    fig.savefig(a.out, dpi=150)
    print(f"wrote {a.out}")


if __name__ == "__main__":
    main()
