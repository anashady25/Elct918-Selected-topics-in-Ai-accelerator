# ELCT918 – Verilog Assignment: Crack the Cipher Chip

**Course:** Selected Topics in AI Accelerators Hardware Design (ELCT918)  
**Instructors:** Dr. Eman Azab · MSc Eng. Nour ElShahawy  

---

## EDA Playground Share Link

> *(Paste your EDA Playground share URL here after running the simulation)*

---

## Repository Contents

| File | Description |
|------|-------------|
| `design.sv` | Unchanged `mystery` netlist + clean RTL `solution` module |
| `testbench.sv` | Exploration experiments, self-checking random stimulus (10 500 cycles), and password test |
| `mystery.v` | Original black-box netlist (reference copy) |
| `README.md` | This file |

---

## How the Cipher Works

### Reverse-Engineering Method
The chip was analysed purely through simulation — no source code was consulted.  
Experiments were run on EDA Playground (Icarus Verilog 12.0) using the provided `mystery` netlist.

### Internal State
| Register | Width | Role |
|----------|-------|------|
| `dout[7:4]` | 4 bits | **Nibble counter** — increments by 1 on every `en=1` clock edge, wraps at 16 |
| `dout[3:0]` | 4 bits | **Ciphertext output** for the most recently encrypted nibble |
| `hist[0]` | 4 bits | Ciphertext from 1 `en=1` cycle ago |
| `hist[1]` | 4 bits | Ciphertext from 2 `en=1` cycles ago |
| `hist[2]` | 4 bits | Ciphertext from 3 `en=1` cycles ago |

### Encryption Rule
On each rising clock edge where `en = 1`:

```
ciphertext = (din + key_table[ counter[1:0] ]) mod 16
counter    = counter + 1   (mod 16)
```

The **key table** (indexed by the two LSBs of the counter *before* each encryption):

| `counter[1:0]` | Key (hex) | Key (binary) |
|:-:|:-:|:-:|
| 0 | **6** | 0110 |
| 1 | **7** | 0111 |
| 2 | **4** | 0100 |
| 3 | **5** | 0101 |

The key stream **6, 7, 4, 5** repeats every 4 encrypted nibbles.  
Compact formula: `key = {2'b01, ~cnt[1], cnt[0]}`

### Behaviour Summary
- **`en = 0`** — all registers hold; counter does not advance.  
- **`rst_n = 0`** (synchronous, active-low) — all registers clear to `0` on the next rising edge.  
- **`dout[7:4]`** shows how many nibbles have been encrypted since the last reset (mod 16).

### Flag
`flag` is a **combinational** output. It goes high when the last four ciphertext nibbles (oldest → newest) spell the hex word **`CAFE`**:

```
hist[2] == 0xC  AND  hist[1] == 0xA  AND  hist[0] == 0xF  AND  dout[3:0] == 0xE
```

---

## Task 3 – The Password

### Derivation
The flag requires ciphertexts `C, A, F, E` in order, starting from counter = 0 (right after reset).  
Working backwards:

| Nibble | Counter | Key | Target ciphertext | Plaintext = (target − key) mod 16 |
|:------:|:-------:|:---:|:-----------------:|:---------------------------------:|
| 1 | 0 | 6 | 0xC (12) | (12 − 6) mod 16 = **6** |
| 2 | 1 | 7 | 0xA (10) | (10 − 7) mod 16 = **3** |
| 3 | 2 | 4 | 0xF (15) | (15 − 4) mod 16 = **B** |
| 4 | 3 | 5 | 0xE (14) | (14 − 5) mod 16 = **9** |

### Password

```
6   3   B   9
```

*(four plaintext nibbles sent on `din`, one per `en=1` clock cycle, immediately after reset)*

### Verification (simulation log excerpt)
```
=== Task 3: Password test  (6, 3, B, 9)  –  expect flag=1 on 4th nibble ===
    t=...  en=1  din=6  ->  bb_dout=1c  bb_flag=0  |  sol_dout=1c  sol_flag=0
    t=...  en=1  din=3  ->  bb_dout=2a  bb_flag=0  |  sol_dout=2a  sol_flag=0
    t=...  en=1  din=b  ->  bb_dout=3f  bb_flag=0  |  sol_dout=3f  sol_flag=0
    t=...  en=1  din=9  ->  bb_dout=4e  bb_flag=1  |  sol_dout=4e  sol_flag=1
    >>> bb_flag=1  sol_flag=1  (both must be 1) <<<
```

---

## Self-Check Result

```
========================================
  PASS  –  0 mismatches in 10565 clock cycles
========================================
```


---

## How to Run

1. Go to [edaplayground.com](https://edaplayground.com) and create a free account.
2. Open a new playground, select **Icarus Verilog 12.0**.
3. Paste the contents of `design.sv` into the **design** panel.
4. Paste the contents of `testbench.sv` into the **testbench** panel.
5. Tick **"Open EPWave after run"** and click **Run**.
6. Inspect the log for `PASS` and waveforms for the `flag` pulse.
