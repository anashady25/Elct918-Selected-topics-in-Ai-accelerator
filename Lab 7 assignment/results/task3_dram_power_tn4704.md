# Task 3 bonus: DDR2 chip power (Micron TN-47-04 method)

Datasheet MT47H64M16HR-25E (1Gb, x16, die rev. H): IDD0 80, IDD2N 30, IDD3N 35, IDD4R 150, IDD4W 160, IDD5 150 mA at tCK(IDD) = 2.5 ns (400 MHz), VDD max 1.9 V. Scaled to VDD = 1.8 V ((1.8/1.9)^2) and to the 300 MHz memory clock (x 300/400 for the frequency-dependent background and burst terms). tRC 55 ns, tRAS 40 ns, tRFC 127.5 ns, tREFI 7.8 us. One ACTIVATE per 1024 sequential words (one row).

| Component (mW) | Write | Read |
|---|---|---|
| background (IDD3N) | 44.76 | 44.76 |
| activate (IDD0) | 0.03 | 0.01 |
| read/write burst (IDD4) | 14.21 | 6.54 |
| refresh (IDD5) | 3.21 | 3.21 |
| DQ/DQS I/O + termination | 46.59 | 10.59 |
| total | 108.80 | 65.11 |
| burst duty cycle on the bus | 8.89 % | 4.44 % |

The IDD values are measured with a mixed data pattern and the DQ lines are terminated to VDDQ/2, so a driven 0 and a driven 1 draw the same termination current: all-zeros and all-ones cost the same on the DRAM side; only toggling (charging the pin / line capacitance) adds energy, and at this low duty cycle that part is tiny. The DRAM power is dominated by background (IDD3N) and refresh, because the controller keeps the bus idle >95 % of the time.
