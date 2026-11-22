#!/usr/bin/env python3
"""
gen_init.py -- generates $readmemh init files for the parameterized BRAM.

Content rule (the testbenches use the same rule to check the preload):
    addr 0      -> 0xDEADBEEF
    addr 1      -> 0xCAFEBABE
    addr a >= 2 -> {a[15:0], ~a[15:0]}         (upper half = a, lower = ~a)
truncated to DATA_W bits (for DATA_W > 32 the 32-bit value is extended with
the low bits of a on top). One word per line, hex, no address markers.

Usage:
    python gen_init.py WIDTH DEPTH OUTFILE
    python gen_init.py --all            # files used by Tasks 2 and 3
"""
import os
import sys


def word(a: int, width: int) -> int:
    if a == 0:
        v = 0xDEADBEEF
    elif a == 1:
        v = 0xCAFEBABE
    else:
        v = ((a & 0xFFFF) << 16) | (~a & 0xFFFF)
    if width > 32:
        v |= (a & ((1 << (width - 32)) - 1)) << 32
    return v & ((1 << width) - 1)


def write_init(width: int, depth: int, path: str) -> None:
    digits = (width + 3) // 4
    with open(path, "w", newline="\n") as f:
        for a in range(depth):
            f.write(f"{word(a, width):0{digits}X}\n")


def main() -> None:
    if len(sys.argv) == 2 and sys.argv[1] == "--all":
        mem = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "mem")
        write_init(32, 4096, os.path.join(mem, "bram32_init.mem"))
        write_init(16, 4096, os.path.join(mem, "bram16_init.mem"))
        print("wrote mem/bram32_init.mem and mem/bram16_init.mem")
        return
    if len(sys.argv) != 4:
        print(__doc__)
        sys.exit(1)
    width, depth, path = int(sys.argv[1]), int(sys.argv[2]), sys.argv[3]
    write_init(width, depth, path)
    print(f"wrote {path}: {depth} x {width} bit")


if __name__ == "__main__":
    main()
