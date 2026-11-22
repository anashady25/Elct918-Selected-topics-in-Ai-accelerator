#!/usr/bin/env python3
"""
collect_results.py -- turns the raw Vivado reports into the tables and plots
of the Lab 7 report. Run from the "Lab7 assignment" folder at any time; parts
whose reports do not exist yet are skipped.

Inputs
  reports/task3/power_{bram,ddr}_*.rpt         (power_bram.tcl / power_ddr.tcl)
  reports/task4/bram/summary_*.txt              (sweep_bram.tcl)
  reports/task4/pe/summary_*.txt                (sweep_pe.tcl)
  results/bandwidth.json                        (cycle counts: simulation / board)
Outputs (results/)
  task1_task2_bandwidth.md, task3_power_*.csv, task3_power_tables.md,
  task3_energy_per_bit.md, task3_dram_power_tn4704.md, task4_*.csv/.md,
  and the plots *.png
"""
import csv
import glob
import json
import os
import re

import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt  # noqa: E402

ROOT = os.path.normpath(os.path.join(os.path.dirname(os.path.abspath(__file__)), ".."))
REP = os.path.join(ROOT, "reports")
RES = os.path.join(ROOT, "results")
os.makedirs(RES, exist_ok=True)

PATTERNS = ["zeros", "ones", "alt01", "5555aaaa", "lfsr"]
PAT_LABEL = {"zeros": "all 0", "ones": "all 1", "alt01": "0/1 alt.",
             "5555aaaa": "5555/AAAA", "lfsr": "LFSR"}
COMPONENTS = ["Clocks", "Slice Logic", "Signals", "Block RAM", "DSPs", "MMCM", "PLL",
              "PHASER", "I/O", "XADC"]
DEVICE = {"lut": 63400, "ff": 126800, "dsp": 240, "bram_tile": 135}


# ---------------------------------------------------------------- helpers
def load_bandwidth():
    path = os.path.join(RES, "bandwidth.json")
    with open(path) as f:
        return json.load(f)


def num(s):
    s = s.strip()
    if s.startswith("<"):
        return 0.0
    try:
        return float(s)
    except ValueError:
        return None


def parse_power(path):
    """On-chip power summary of a report_power text file, in mW."""
    txt = open(path).read()
    scale = 1.0 if "Total On-Chip Power (mW)" in txt else 1000.0
    out = {}
    m = re.search(r"\|\s*Total On-Chip Power \((?:mW|W)\)\s*\|\s*([0-9.<]+)", txt)
    out["total"] = num(m.group(1)) * scale if m else None
    m = re.search(r"\|\s*Dynamic \((?:mW|W)\)\s*\|\s*([0-9.<]+)", txt)
    out["dynamic"] = num(m.group(1)) * scale if m else None
    m = re.search(r"\|\s*Device Static \((?:mW|W)\)\s*\|\s*([0-9.<]+)", txt)
    out["static"] = num(m.group(1)) * scale if m else None
    m = re.search(r"Design Nets Matched\s*\|\s*([^|]+)\|", txt)
    out["matched"] = m.group(1).strip() if m else ""
    sec = txt.split("1.1 On-Chip Components")[-1].split("1.2 Power Supply")[0]
    for comp in COMPONENTS:
        m = re.search(r"^\|\s*" + re.escape(comp) + r"\s*\|\s*([0-9.<]+)", sec, re.M)
        out[comp] = (num(m.group(1)) * scale) if m else 0.0
    return out


def write_csv(path, rows, fields):
    with open(path, "w", newline="") as f:
        w = csv.DictWriter(f, fieldnames=fields, extrasaction="ignore")
        w.writeheader()
        for r in rows:
            w.writerow(r)


def md_table(rows, fields, headers, fmt=None):
    fmt = fmt or {}
    lines = ["| " + " | ".join(headers) + " |", "|" + "---|" * len(headers)]
    for r in rows:
        cells = []
        for k in fields:
            v = r.get(k, "")
            if isinstance(v, float):
                v = format(v, fmt.get(k, ".3f"))
            cells.append(str(v))
        lines.append("| " + " | ".join(cells) + " |")
    return "\n".join(lines) + "\n"


# ---------------------------------------------------------------- bandwidth
def bandwidths(bw):
    f = bw["f_clk_hz"]
    out = {}
    # DDR2: measured on the board if available, otherwise the estimate
    w = bw["ddr_words"]
    for op in ("write", "read"):
        cyc = bw.get(f"ddr_{op}_cycles")
        src = "board"
        if not cyc:
            cyc = bw[f"ddr_est_{op}_cycles_per_word"] * w
            src = "estimate"
        t = cyc / f
        out[("ddr", op)] = {"cycles": cyc, "cyc_per_word": cyc / w,
                            "MBps": w * 2 / t / 1e6, "bps": w * 16 / t, "source": src}
    w = bw["bram_words"]
    for op in ("write", "read"):
        cyc = bw.get(f"bram_{op}_cycles_board") or bw[f"bram_{op}_cycles_sim"]
        src = "board" if bw.get(f"bram_{op}_cycles_board") else "simulation"
        t = cyc / f
        out[("bram", op)] = {"cycles": cyc, "cyc_per_word": cyc / w,
                             "MBps": w * 4 / t / 1e6, "bps": w * 32 / t, "source": src}
    return out


def report_bandwidth(bw, B):
    f_mem = bw["ddr_f_mem_hz"]
    theo = f_mem * 2 * 2 / 1e6
    rows = []
    for mem, wbytes in (("ddr", 2), ("bram", 4)):
        for op in ("write", "read"):
            b = B[(mem, op)]
            rows.append({"mem": "DDR2 (16 bit)" if mem == "ddr" else "BRAM (32 bit)", "op": op,
                         "cycles": f"{b['cycles']:.0f}", "cpw": b["cyc_per_word"],
                         "MBps": b["MBps"], "source": b["source"]})
    txt = "# Tasks 1 and 2: measured bandwidth\n\n"
    txt += md_table(rows, ["mem", "op", "cycles", "cpw", "MBps", "source"],
                    ["Memory", "Operation", "Cycles per pass", "Cycles per word",
                     "Bandwidth (MB/s)", "Source"], {"cpw": ".2f", "MBps": ".2f"})
    txt += (f"\nTheoretical DDR2 bandwidth B = f_mem x 2 x w = {f_mem/1e6:.0f} MHz x 2 x 2 B "
            f"= {theo:.0f} MB/s.\n")
    for op in ("write", "read"):
        txt += f"- DDR2 {op}: {B[('ddr', op)]['MBps']:.2f} MB/s = {100*B[('ddr', op)]['MBps']/theo:.2f} % of theoretical\n"
    txt += (f"\nBRAM peak (one 32-bit word per 100 MHz cycle, one port) = 400 MB/s; "
            f"the 4-phase handshake needs 3 cycles per word -> 133.3 MB/s.\n")
    open(os.path.join(RES, "task1_task2_bandwidth.md"), "w").write(txt)


# ---------------------------------------------------------------- Task 3
def task3(B):
    tables = {}
    for mem in ("bram", "ddr"):
        rows = []
        for op in ("write", "read"):
            for pat in PATTERNS:
                p = os.path.join(REP, "task3", f"power_{mem}_{op}_{pat}.rpt")
                if os.path.exists(p):
                    r = parse_power(p)
                    r.update({"memory": mem.upper(), "op": op, "pattern": PAT_LABEL[pat], "pat": pat})
                    rows.append(r)
        sweep = []
        for op in ("write", "read"):
            for tr in (0, 25, 50, 100):
                p = os.path.join(REP, "task3", f"power_{mem}_{op}_toggle{tr}.rpt")
                if os.path.exists(p):
                    r = parse_power(p)
                    r.update({"op": op, "toggle": tr})
                    sweep.append(r)
        tables[mem] = (rows, sweep)
        if rows:
            fields = ["memory", "op", "pattern", "total", "dynamic", "static"] + COMPONENTS + ["matched"]
            write_csv(os.path.join(RES, f"task3_power_{mem}.csv"), rows, fields)
        if sweep:
            write_csv(os.path.join(RES, f"task3_toggle_sweep_{mem}.csv"), sweep,
                      ["op", "toggle", "total", "dynamic"] + COMPONENTS)

    # markdown tables
    txt = "# Task 3: on-chip power per memory x operation x pattern (mW)\n\n"
    for mem in ("bram", "ddr"):
        rows, sweep = tables[mem]
        if not rows:
            txt += f"## {mem.upper()}: no reports yet\n\n"
            continue
        comps = [c for c in COMPONENTS if any(r[c] for r in rows)]
        txt += f"## {mem.upper()}\n\n"
        txt += md_table(rows, ["op", "pattern", "total", "dynamic"] + comps,
                        ["Op", "Pattern", "Total", "Dynamic"] + comps)
        txt += "\n"
        if sweep:
            txt += f"### {mem.upper()} toggle-rate sweep (data pins / buses, SP 0.5)\n\n"
            txt += md_table(sweep, ["op", "toggle", "dynamic"] + comps,
                            ["Op", "Toggle (%)", "Dynamic"] + comps)
            txt += "\n"
    open(os.path.join(RES, "task3_power_tables.md"), "w").write(txt)

    # plot: dynamic power vs pattern
    mems = [m for m in ("ddr", "bram") if tables[m][0]]
    if mems:
        fig, axes = plt.subplots(1, len(mems), figsize=(6.5 * len(mems), 4.2), squeeze=False)
        for ax, mem in zip(axes[0], mems):
            rows = tables[mem][0]
            x = range(len(PATTERNS))
            for k, op in enumerate(("write", "read")):
                vals = [next((r["dynamic"] for r in rows if r["op"] == op and r["pat"] == p), 0)
                        for p in PATTERNS]
                ax.bar([i + (k - 0.5) * 0.38 for i in x], vals, 0.38, label=op)
                for i, v in zip(x, vals):
                    ax.text(i + (k - 0.5) * 0.38, v, f"{v:.2f}", ha="center", va="bottom", fontsize=7)
            ax.set_xticks(list(x))
            ax.set_xticklabels([PAT_LABEL[p] for p in PATTERNS])
            ax.set_ylabel("Dynamic power (mW)")
            ax.set_title(f"{mem.upper()}: dynamic power vs data pattern")
            lo = min(r["dynamic"] for r in rows)
            ax.set_ylim(lo * 0.9 if mem == "ddr" else 0, None)
            ax.legend()
            ax.grid(axis="y", alpha=0.3)
        fig.tight_layout()
        fig.savefig(os.path.join(RES, "task3_pdyn_vs_pattern.png"), dpi=150)
        plt.close(fig)

        # component breakdown: what changes with the data (LFSR minus zeros)
        fig, axes = plt.subplots(1, len(mems), figsize=(6.5 * len(mems), 4.0), squeeze=False)
        for ax, mem in zip(axes[0], mems):
            rows = tables[mem][0]
            comps = [c for c in COMPONENTS if any(r[c] for r in rows)]
            for k, op in enumerate(("write", "read")):
                z = next((r for r in rows if r["op"] == op and r["pat"] == "zeros"), None)
                l = next((r for r in rows if r["op"] == op and r["pat"] == "alt01"), None)
                if z and l:
                    d = [l[c] - z[c] for c in comps]
                    ax.bar([i + (k - 0.5) * 0.38 for i in range(len(comps))], d, 0.38, label=op)
            ax.set_xticks(range(len(comps)))
            ax.set_xticklabels(comps, rotation=30, ha="right")
            ax.set_ylabel("Power increase (mW)")
            ax.set_title(f"{mem.upper()}: 0/1-alternating minus all-zeros")
            ax.axhline(0, color="k", lw=0.6)
            ax.legend()
            ax.grid(axis="y", alpha=0.3)
        fig.tight_layout()
        fig.savefig(os.path.join(RES, "task3_component_delta.png"), dpi=150)
        plt.close(fig)

    # plot: dynamic power vs toggle rate
    mems = [m for m in ("ddr", "bram") if tables[m][1]]
    if mems:
        fig, axes = plt.subplots(1, len(mems), figsize=(6 * len(mems), 4), squeeze=False)
        for ax, mem in zip(axes[0], mems):
            sweep = tables[mem][1]
            for op in ("write", "read"):
                pts = sorted((r["toggle"], r["dynamic"]) for r in sweep if r["op"] == op)
                ax.plot([p[0] for p in pts], [p[1] for p in pts], "o-", label=op)
            ax.set_xlabel("Toggle rate of the data pins / bus (%)")
            ax.set_ylabel("Dynamic power (mW)")
            ax.set_title(f"{mem.upper()}: dynamic power vs toggle rate")
            ax.set_xticks([0, 25, 50, 100])
            ax.legend()
            ax.grid(alpha=0.3)
        fig.tight_layout()
        fig.savefig(os.path.join(RES, "task3_pdyn_vs_toggle.png"), dpi=150)
        plt.close(fig)

    # energy per bit
    txt = "# Task 3: energy per bit E_bit = P_dyn / BW\n\n"
    txt += ("P_dyn = dynamic power of the whole memory test design (controller + memory "
            "interface + memory) with LFSR data; for the BRAM the Block RAM component "
            "alone is listed too. BW = measured bandwidth of the same traffic.\n\n")
    rows = []
    for mem in ("ddr", "bram"):
        for op in ("write", "read"):
            r = next((x for x in tables[mem][0] if x["op"] == op and x["pat"] == "lfsr"), None)
            if not r:
                continue
            b = B[(mem, op)]
            e = r["dynamic"] * 1e-3 / b["bps"] * 1e12
            row = {"mem": mem.upper(), "op": op, "pdyn": r["dynamic"], "bw": b["MBps"],
                   "src": b["source"], "ebit": e}
            if mem == "bram":
                row["ecore"] = r["Block RAM"] * 1e-3 / b["bps"] * 1e12
            rows.append(row)
    if rows:
        txt += md_table(rows, ["mem", "op", "pdyn", "bw", "src", "ebit", "ecore"],
                        ["Memory", "Op", "P_dyn (mW)", "BW (MB/s)", "BW source",
                         "E_bit (pJ/bit)", "E_bit BRAM block only (pJ/bit)"],
                        {"bw": ".2f", "ebit": ".1f", "ecore": ".1f"})
        for op in ("write", "read"):
            d = next((r for r in rows if r["mem"] == "DDR" and r["op"] == op), None)
            s = next((r for r in rows if r["mem"] == "BRAM" and r["op"] == op), None)
            if d and s:
                txt += f"\nDDR2 / BRAM energy-per-bit ratio ({op}): {d['ebit'] / s['ebit']:.0f}x"
        txt += "\n"
    open(os.path.join(RES, "task3_energy_per_bit.md"), "w").write(txt)
    return tables


# ---------------------------------------------------------------- DRAM power (TN-47-04)
def dram_power(bw, B):
    """Micron TN-47-04 method for one MT47H64M16HR-25E (die rev. H, x16)."""
    idd = {"IDD0": 80, "IDD2N": 30, "IDD3N": 35, "IDD4R": 150, "IDD4W": 160, "IDD5": 150}  # mA
    vdd_spec, vdd_use = 1.9, 1.8           # IDD are max values, specified up to VDD max
    f_spec, f_use = 400e6, bw["ddr_f_mem_hz"]
    t_rc, t_ras = 55e-9, 40e-9
    t_rfc, t_refi = 127.5e-9, 7.8e-6
    t_burst = 4 / f_use                    # BL8 = 4 clocks on the bus
    words_per_row = 1024                   # 10 column bits, BANK_ROW_COLUMN map
    v = vdd_spec
    res = {}
    for op in ("write", "read"):
        t_acc = B[("ddr", op)]["cyc_per_word"] / bw["f_clk_hz"]
        duty = t_burst / t_acc
        t_rrd_sch = words_per_row * t_acc
        p_bg = idd["IDD3N"] * 1e-3 * v
        p_act = (idd["IDD0"] - (idd["IDD3N"] * t_ras + idd["IDD2N"] * (t_rc - t_ras)) / t_rc) \
            * 1e-3 * v * t_rc / t_rrd_sch
        p_rdwr = ((idd["IDD4W"] if op == "write" else idd["IDD4R"]) - idd["IDD3N"]) * 1e-3 * v * duty
        p_ref = (idd["IDD5"] - idd["IDD3N"]) * 1e-3 * v * t_rfc / t_refi
        vs = (vdd_use / vdd_spec) ** 2
        fs = f_use / f_spec
        comp = {"background (IDD3N)": p_bg * vs * fs, "activate (IDD0)": p_act * vs,
                "read/write burst (IDD4)": p_rdwr * vs * fs, "refresh (IDD5)": p_ref * vs}
        # DQ I/O + termination of the 16 DQ + 2 DM + 4 DQS pins while the burst is on
        # the bus: SSTL18, RTT = 50 ohm Thevenin to VDDQ/2, ~18 ohm full-strength driver.
        i_dq = (vdd_use / 2) / (18 + 50)
        p_pin = vdd_use * i_dq                # drawn from VDDQ per driven pin, 0 or 1
        pins = 16 + (2 if op == "write" else 0) + 4
        comp["DQ/DQS I/O + termination"] = pins * p_pin * duty * (0.5 if op == "read" else 1.0)
        comp["total"] = sum(comp.values())
        res[op] = (duty, comp)
    txt = "# Task 3 bonus: DDR2 chip power (Micron TN-47-04 method)\n\n"
    txt += ("Datasheet MT47H64M16HR-25E (1Gb, x16, die rev. H): IDD0 80, IDD2N 30, IDD3N 35, "
            "IDD4R 150, IDD4W 160, IDD5 150 mA at tCK(IDD) = 2.5 ns (400 MHz), VDD max 1.9 V. "
            "Scaled to VDD = 1.8 V ((1.8/1.9)^2) and to the 300 MHz memory clock (x 300/400 "
            "for the frequency-dependent background and burst terms). tRC 55 ns, tRAS 40 ns, "
            "tRFC 127.5 ns, tREFI 7.8 us. One ACTIVATE per 1024 sequential words (one row).\n\n")
    txt += "| Component (mW) | Write | Read |\n|---|---|---|\n"
    for k in res["write"][1]:
        txt += f"| {k} | {res['write'][1][k]*1e3:.2f} | {res['read'][1][k]*1e3:.2f} |\n"
    txt += (f"| burst duty cycle on the bus | {100*res['write'][0]:.2f} % | {100*res['read'][0]:.2f} % |\n\n")
    txt += ("The IDD values are measured with a mixed data pattern and the DQ lines are "
            "terminated to VDDQ/2, so a driven 0 and a driven 1 draw the same termination "
            "current: all-zeros and all-ones cost the same on the DRAM side; only toggling "
            "(charging the pin / line capacitance) adds energy, and at this low duty cycle "
            "that part is tiny. The DRAM power is dominated by background (IDD3N) and refresh, "
            "because the controller keeps the bus idle >95 % of the time.\n")
    open(os.path.join(RES, "task3_dram_power_tn4704.md"), "w").write(txt)


# ---------------------------------------------------------------- Task 4
def read_summaries(pattern):
    rows = []
    for p in glob.glob(pattern):
        d = {}
        for line in open(p):
            if "=" in line:
                k, v = line.rstrip("\n").split("=", 1)
                d[k] = v
        rows.append(d)
    return rows


def fnum(x, default=None):
    try:
        return float(x)
    except (TypeError, ValueError):
        return default


def task4():
    # ---- 4.1 maximum BRAM
    rows = read_summaries(os.path.join(REP, "task4", "bram", "summary_*.txt"))
    if rows:
        for r in rows:
            r["width"], r["depth"] = int(r["width"]), int(r["depth"])
            r36, r18 = fnum(r.get("ramb36"), 0), fnum(r.get("ramb18"), 0)
            tiles = r36 + r18 / 2.0
            r["tiles"] = tiles
            r["eta"] = (r["width"] * r["depth"]) / (tiles * 36 * 1024) if tiles > 0 else 0.0
            r["kbits"] = r["width"] * r["depth"] / 1024.0
        rows.sort(key=lambda r: (r["width"], r["depth"]))
        fields = ["width", "depth", "kbits", "status", "ramb36", "ramb18", "tiles", "bram_tile",
                  "lut", "ff", "wns", "eta", "seconds", "message"]
        write_csv(os.path.join(RES, "task4_bram_sweep.csv"), rows, fields)
        txt = "# Task 4.1: block RAM sweep (100 MHz)\n\n"
        txt += md_table(rows, ["width", "depth", "kbits", "status", "ramb36", "ramb18", "lut", "wns", "eta"],
                        ["DATA_W", "DEPTH", "Kbit", "Result", "RAMB36", "RAMB18", "LUT", "WNS (ns)", "eta"],
                        {"kbits": ".0f", "eta": ".3f"})
        best = {}
        for r in rows:
            if r["status"] == "ROUTED" and r["depth"] > best.get(r["width"], {"depth": 0})["depth"]:
                best[r["width"]] = r
        txt += "\n## Largest implemented memory per width\n\n"
        txt += md_table([best[w] for w in sorted(best)],
                        ["width", "depth", "kbits", "ramb36", "ramb18", "lut", "wns", "eta"],
                        ["DATA_W", "max DEPTH", "Kbit", "RAMB36", "RAMB18", "LUT", "WNS (ns)", "eta"],
                        {"kbits": ".0f", "eta": ".3f"})
        fails = [r for r in rows if r["status"] != "ROUTED"]
        if fails:
            txt += "\n## Failing points and Vivado's message\n\n"
            for r in fails:
                txt += f"- W={r['width']} D={r['depth']}: {r['status']}: {r['message'][:300]}\n"
        open(os.path.join(RES, "task4_bram_sweep.md"), "w").write(txt)

        if best:
            small = {}
            for r in rows:
                if r["status"] == "ROUTED" and r["depth"] < small.get(r["width"], {"depth": 1 << 40})["depth"]:
                    small[r["width"]] = r
            fig, ax = plt.subplots(figsize=(7, 4))
            ws = sorted(best)
            for k, (sel, lab) in enumerate(((small, "smallest point (one tile)"), (best, "largest memory"))):
                xs = [i + (k - 0.5) * 0.38 for i in range(len(ws))]
                ax.bar(xs, [sel[w]["eta"] for w in ws], 0.38, label=lab)
                for x, w in zip(xs, ws):
                    ax.text(x, sel[w]["eta"], f"{sel[w]['eta']:.3f}\n{sel[w]['depth']}",
                            ha="center", va="bottom", fontsize=7)
            ax.set_xticks(range(len(ws)))
            ax.set_xticklabels([str(w) for w in ws])
            ax.set_ylim(0, 1.25)
            ax.set_xlabel("DATA_W (bits)  (labels: eta, DEPTH)")
            ax.set_ylabel("storage efficiency eta")
            ax.set_title("BRAM storage efficiency per width")
            ax.legend(loc="lower right")
            ax.grid(axis="y", alpha=0.3)
            fig.tight_layout()
            fig.savefig(os.path.join(RES, "task4_bram_eta.png"), dpi=150)
            plt.close(fig)

    # ---- 4.2 PE array
    rows = read_summaries(os.path.join(REP, "task4", "pe", "summary_*.txt"))
    if not rows:
        return
    for r in rows:
        r["n_pe"] = int(r["n_pe"])
        for k in ("lut", "ff", "dsp", "bram_tile"):
            r[k + "_pct"] = 100.0 * fnum(r.get(k), 0) / DEVICE[k]
    rows.sort(key=lambda r: (r["variant"], r["spad"], r["n_pe"]))
    fields = ["variant", "spad", "n_pe", "status", "lut", "ff", "dsp", "bram_tile", "ramb18",
              "lut_pct", "ff_pct", "dsp_pct", "bram_tile_pct", "wns", "power_total",
              "power_dynamic", "seconds", "message"]
    write_csv(os.path.join(RES, "task4_pe_sweep.csv"), rows, fields)
    txt = "# Task 4.2: PE array sweep (100 MHz)\n\n"
    summary = []
    for variant in ("dsp", "lut"):
        for spad in ("0", "1"):
            sub = [r for r in rows if r["variant"] == variant and r["spad"] == spad]
            if not sub:
                continue
            txt += f"## {variant.upper()} multipliers, scratchpad = {spad}\n\n"
            txt += md_table(sub, ["n_pe", "status", "lut_pct", "ff_pct", "dsp_pct", "bram_tile_pct",
                                  "wns", "power_total"],
                            ["N_PE", "Result", "LUT %", "FF %", "DSP %", "BRAM %", "WNS (ns)", "Power (W)"],
                            {"lut_pct": ".1f", "ff_pct": ".1f", "dsp_pct": ".1f", "bram_tile_pct": ".1f"})
            ok = [r for r in sub if r["status"] == "ROUTED"]
            if ok:
                m = max(ok, key=lambda r: r["n_pe"])
                fail = min((r for r in sub if r["status"] != "ROUTED" and r["n_pe"] > m["n_pe"]),
                           key=lambda r: r["n_pe"], default=None)
                summary.append({"variant": variant.upper(), "spad": spad, "n": m["n_pe"], "wns": m["wns"],
                                "p": m["power_total"], "lut": m["lut_pct"], "ff": m["ff_pct"],
                                "dsp": m["dsp_pct"], "bram": m["bram_tile_pct"],
                                "fail": f"{fail['n_pe']}: {fail['status']}" if fail else "-"})
            txt += "\n"
    if summary:
        txt += "## Maximum N_PE\n\n"
        txt += md_table(summary, ["variant", "spad", "n", "wns", "p", "lut", "ff", "dsp", "bram", "fail"],
                        ["Multipliers", "Scratchpad", "max N_PE", "WNS (ns)", "Power (W)",
                         "LUT %", "FF %", "DSP %", "BRAM %", "first failing N_PE"],
                        {"lut": ".1f", "ff": ".1f", "dsp": ".1f", "bram": ".1f"})
    open(os.path.join(RES, "task4_pe_sweep.md"), "w").write(txt)

    for spad in ("0", "1"):
        variants = [v for v in ("dsp", "lut") if any(r["variant"] == v and r["spad"] == spad for r in rows)]
        if not variants:
            continue
        fig, axes = plt.subplots(1, len(variants), figsize=(6.2 * len(variants), 4.2), squeeze=False)
        for ax, v in zip(axes[0], variants):
            sub = [r for r in rows if r["variant"] == v and r["spad"] == spad and fnum(r.get("lut"), -1) >= 0]
            sub.sort(key=lambda r: r["n_pe"])
            n = [r["n_pe"] for r in sub]
            for k, lab in (("lut_pct", "LUT"), ("ff_pct", "FF"), ("dsp_pct", "DSP"), ("bram_tile_pct", "BRAM")):
                ax.plot(n, [r[k] for r in sub], "o-", label=lab, ms=4)
            for r in sub:
                if r["status"] != "ROUTED":
                    ax.axvline(r["n_pe"], color="r", ls=":", lw=0.8)
            ax.axhline(100, color="k", lw=0.6)
            ax.set_xscale("log", base=2)
            ax.set_xlabel("N_PE")
            ax.set_ylabel("Utilisation (%)")
            ax.set_title(f"{v.upper()} multipliers" + (", 1Ki x 16 scratchpad per PE" if spad == "1" else ""))
            ax.legend()
            ax.grid(alpha=0.3, which="both")
        fig.tight_layout()
        fig.savefig(os.path.join(RES, f"task4_pe_utilization_spad{spad}.png"), dpi=150)
        plt.close(fig)


def main():
    bw = load_bandwidth()
    B = bandwidths(bw)
    report_bandwidth(bw, B)
    task3(B)
    dram_power(bw, B)
    task4()
    print("results written to", RES)


if __name__ == "__main__":
    main()
