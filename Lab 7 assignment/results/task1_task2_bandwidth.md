# Tasks 1 and 2: measured bandwidth

| Memory | Operation | Cycles per pass | Cycles per word | Bandwidth (MB/s) | Source |
|---|---|---|---|---|---|
| DDR2 (16 bit) | write | 1006632960 | 15.00 | 13.33 | estimate |
| DDR2 (16 bit) | read | 2013265920 | 30.00 | 6.67 | estimate |
| BRAM (32 bit) | write | 12288 | 3.00 | 133.33 | simulation |
| BRAM (32 bit) | read | 12288 | 3.00 | 133.33 | simulation |

Theoretical DDR2 bandwidth B = f_mem x 2 x w = 300 MHz x 2 x 2 B = 1200 MB/s.
- DDR2 write: 13.33 MB/s = 1.11 % of theoretical
- DDR2 read: 6.67 MB/s = 0.56 % of theoretical

BRAM peak (one 32-bit word per 100 MHz cycle, one port) = 400 MB/s; the 4-phase handshake needs 3 cycles per word -> 133.3 MB/s.
