# Task 3: energy per bit E_bit = P_dyn / BW

P_dyn = dynamic power of the whole memory test design (controller + memory interface + memory) with LFSR data; for the BRAM the Block RAM component alone is listed too. BW = measured bandwidth of the same traffic.

| Memory | Op | P_dyn (mW) | BW (MB/s) | BW source | E_bit (pJ/bit) | E_bit BRAM block only (pJ/bit) |
|---|---|---|---|---|---|---|
| BRAM | write | 10.623 | 133.33 | simulation | 10.0 | 5.9 |
| BRAM | read | 9.758 | 133.33 | simulation | 9.1 | 5.1 |

