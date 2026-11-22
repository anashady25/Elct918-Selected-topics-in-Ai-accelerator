#!/usr/bin/env python3
"""
bandwidth_from_display.py -- converts the hex numbers read from the Nexys 4
7-segment display into bandwidth figures and stores them in
results/bandwidth.json (used by collect_results.py).

  DDR2 (ddr_top.bit, full 128 MiB run, SW[5] = 0):
    python scripts/bandwidth_from_display.py ddr  <SW76=01 value> <SW76=10 value> <SW76=11 value>
  BRAM (bram_top.bit):
    python scripts/bandwidth_from_display.py bram <SW76=01 value> <SW76=10 value>

  SW[7:6] = 01 shows write cycles [31:0], 10 shows read cycles [31:0],
  11 shows {write[39:32], read[39:32], passes[15:0]} (DDR only; the full run
  takes more than 2^32 cycles only if it is very slow, but always read it).
"""
import json
import os
import sys

ROOT = os.path.normpath(os.path.join(os.path.dirname(os.path.abspath(__file__)), ".."))
JSON = os.path.join(ROOT, "results", "bandwidth.json")
F_CLK = 100e6


def h(s):
    return int(s.replace(" ", "").replace("_", ""), 16)


def main():
    if len(sys.argv) < 4 or sys.argv[1] not in ("ddr", "bram"):
        print(__doc__)
        sys.exit(1)
    mem = sys.argv[1]
    wr, rd = h(sys.argv[2]), h(sys.argv[3])
    if mem == "ddr" and len(sys.argv) > 4:
        hi = h(sys.argv[4])
        wr |= ((hi >> 24) & 0xFF) << 32
        rd |= ((hi >> 16) & 0xFF) << 32
        print(f"passes completed: {hi & 0xFFFF}")
    cfg = json.load(open(JSON))
    words, wbytes = (cfg["ddr_words"], 2) if mem == "ddr" else (cfg["bram_words"], 4)
    for op, cyc in (("write", wr), ("read", rd)):
        t = cyc / F_CLK
        print(f"{mem.upper()} {op}: {cyc} cycles = {t*1e3:.3f} ms, "
              f"{cyc/words:.3f} cycles/word, {words*wbytes/t/1e6:.2f} MB/s")
    if mem == "ddr":
        cfg["ddr_write_cycles"], cfg["ddr_read_cycles"] = wr, rd
        theo = cfg["ddr_f_mem_hz"] * 2 * 2 / 1e6
        print(f"theoretical DDR2 bandwidth {theo:.0f} MB/s")
    else:
        cfg["bram_write_cycles_board"], cfg["bram_read_cycles_board"] = wr, rd
    with open(JSON, "w") as f:
        json.dump(cfg, f, indent=2)
    print("updated", JSON)


if __name__ == "__main__":
    main()
