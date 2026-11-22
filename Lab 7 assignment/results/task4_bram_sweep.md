# Task 4.1: block RAM sweep (100 MHz)

| DATA_W | DEPTH | Kbit | Result | RAMB36 | RAMB18 | LUT | WNS (ns) | eta |
|---|---|---|---|---|---|---|---|---|
| 8 | 4096 | 32 | ROUTED | 1 | 0 | 8 | 6.286 | 0.889 |
| 8 | 65536 | 512 | ROUTED | 16 | 0 | 9 | 5.464 | 0.889 |
| 8 | 262144 | 2048 | ROUTED | 64 | 0 | 81 | 2.906 | 0.889 |
| 8 | 524288 | 4096 | ROUTED | 128 | 0 | 153 | 0.864 | 0.889 |
| 8 | 524800 | 4100 | FAILED_place | 0 | 0 | 96455 | NA | 0.000 |
| 8 | 525824 | 4108 | FAILED_place | 0 | 0 | 96664 | NA | 0.000 |
| 8 | 527872 | 4124 | FAILED_place | 0 | 0 | 97043 | NA | 0.000 |
| 8 | 531456 | 4152 | FAILED_place | 0 | 0 | 97705 | NA | 0.000 |
| 8 | 538624 | 4208 | FAILED_place | 0 | 0 | 99025 | NA | 0.000 |
| 8 | 552960 | 4320 | FAILED_place | 0 | 0 | 101641 | NA | 0.000 |
| 16 | 2048 | 32 | ROUTED | 1 | 0 | 14 | 6.557 | 0.889 |
| 16 | 32768 | 512 | ROUTED | 16 | 0 | 8 | 5.776 | 0.889 |
| 16 | 131072 | 2048 | ROUTED | 64 | 0 | 77 | 1.457 | 0.889 |
| 16 | 262144 | 4096 | ROUTED | 128 | 0 | 153 | 1.081 | 0.889 |
| 16 | 262400 | 4100 | FAILED_place | 0 | 0 | 95146 | NA | 0.000 |
| 16 | 262912 | 4108 | FAILED_place | 0 | 0 | 95340 | NA | 0.000 |
| 16 | 263936 | 4124 | FAILED_place | 0 | 0 | 95709 | NA | 0.000 |
| 16 | 265728 | 4152 | FAILED_place | 0 | 0 | 96362 | NA | 0.000 |
| 16 | 269312 | 4208 | FAILED_place | 0 | 0 | 97648 | NA | 0.000 |
| 16 | 276480 | 4320 | FAILED_place | 0 | 0 | 100251 | NA | 0.000 |
| 18 | 2048 | 36 | ROUTED | 1 | 0 | 16 | 5.415 | 1.000 |
| 18 | 8192 | 144 | ROUTED | 4 | 1 | 10 | 6.132 | 0.889 |
| 18 | 16384 | 288 | ROUTED | 9 | 0 | 10 | 6.174 | 0.889 |
| 18 | 32768 | 576 | ROUTED | 18 | 0 | 10 | 5.254 | 0.889 |
| 18 | 131072 | 2304 | ROUTED | 72 | 0 | 84 | 1.522 | 0.889 |
| 18 | 196608 | 3456 | ROUTED | 108 | 0 | 132 | 0.851 | 0.889 |
| 18 | 229376 | 4032 | ROUTED | 126 | 0 | 159 | 0.816 | 0.889 |
| 18 | 229632 | 4036 | FAILED_place | 0 | 0 | 93508 | NA | 0.000 |
| 18 | 229888 | 4041 | FAILED_place | 0 | 0 | 93610 | NA | 0.000 |
| 18 | 230400 | 4050 | FAILED_place | 0 | 0 | 93819 | NA | 0.000 |
| 18 | 231424 | 4068 | FAILED_place | 0 | 0 | 94225 | NA | 0.000 |
| 18 | 233472 | 4104 | FAILED_place | 0 | 0 | 95064 | NA | 0.000 |
| 18 | 237568 | 4176 | FAILED_place | 0 | 0 | 96734 | NA | 0.000 |
| 18 | 245760 | 4320 | FAILED_place | 0 | 0 | 100077 | NA | 0.000 |
| 18 | 262144 | 4608 | FAILED_place | 0 | 0 | 106820 | NA | 0.000 |
| 32 | 1024 | 32 | ROUTED | 1 | 0 | 28 | 6.231 | 0.889 |
| 32 | 8192 | 256 | ROUTED | 8 | 0 | 24 | 6.049 | 0.889 |
| 32 | 16384 | 512 | ROUTED | 16 | 0 | 24 | 5.118 | 0.889 |
| 32 | 65536 | 2048 | ROUTED | 64 | 0 | 25 | 3.927 | 0.889 |
| 32 | 131072 | 4096 | ROUTED | 128 | 0 | 145 | 0.853 | 0.889 |
| 32 | 131200 | 4100 | FAILED_place | 0 | 0 | 94996 | NA | 0.000 |
| 32 | 131456 | 4108 | FAILED_place | 0 | 0 | 95158 | NA | 0.000 |
| 32 | 131968 | 4124 | FAILED_place | 0 | 0 | 95545 | NA | 0.000 |
| 32 | 132864 | 4152 | FAILED_place | 0 | 0 | 96136 | NA | 0.000 |
| 32 | 134656 | 4208 | FAILED_place | 0 | 0 | 97435 | NA | 0.000 |
| 32 | 138240 | 4320 | FAILED_place | 0 | 0 | 100037 | NA | 0.000 |
| 36 | 1024 | 36 | ROUTED | 1 | 0 | 28 | 6.121 | 1.000 |
| 36 | 4096 | 144 | ROUTED | 4 | 0 | 24 | 5.983 | 1.000 |
| 36 | 8192 | 288 | ROUTED | 9 | 0 | 24 | 5.596 | 0.889 |
| 36 | 16384 | 576 | ROUTED | 18 | 0 | 24 | 5.686 | 0.889 |
| 36 | 65536 | 2304 | ROUTED | 72 | 0 | 25 | 4.422 | 0.889 |
| 36 | 98304 | 3456 | ROUTED | 108 | 0 | 111 | 1.154 | 0.889 |
| 36 | 98432 | 3460 | FAILED_place | 0 | 0 | 74559 | NA | 0.000 |
| 36 | 98560 | 3465 | FAILED_place | 0 | 0 | 74632 | NA | 0.000 |
| 36 | 98816 | 3474 | FAILED_place | 0 | 0 | 74833 | NA | 0.000 |
| 36 | 99328 | 3492 | FAILED_place | 0 | 0 | 75192 | NA | 0.000 |
| 36 | 100352 | 3528 | FAILED_place | 0 | 0 | 75897 | NA | 0.000 |
| 36 | 102400 | 3600 | FAILED_place | 0 | 0 | 77412 | NA | 0.000 |
| 36 | 106496 | 3744 | FAILED_place | 0 | 0 | 80519 | NA | 0.000 |
| 36 | 114688 | 4032 | FAILED_place | 0 | 0 | 86896 | NA | 0.000 |
| 36 | 131072 | 4608 | FAILED_place | 0 | 0 | 99952 | NA | 0.000 |

## Largest implemented memory per width

| DATA_W | max DEPTH | Kbit | RAMB36 | RAMB18 | LUT | WNS (ns) | eta |
|---|---|---|---|---|---|---|---|
| 8 | 524288 | 4096 | 128 | 0 | 153 | 0.864 | 0.889 |
| 16 | 262144 | 4096 | 128 | 0 | 153 | 1.081 | 0.889 |
| 18 | 229376 | 4032 | 126 | 0 | 159 | 0.816 | 0.889 |
| 32 | 131072 | 4096 | 128 | 0 | 145 | 0.853 | 0.889 |
| 36 | 98304 | 3456 | 108 | 0 | 111 | 1.154 | 0.889 |

## Failing points and Vivado's message

- W=8 D=524800: FAILED_place: ERROR: [Common 17-69] Command failed: Placer could not place all instances 
- W=8 D=525824: FAILED_place: ERROR: [Common 17-69] Command failed: Placer could not place all instances 
- W=8 D=527872: FAILED_place: ERROR: [Common 17-69] Command failed: Placer could not place all instances 
- W=8 D=531456: FAILED_place: ERROR: [Common 17-69] Command failed: Placer could not place all instances 
- W=8 D=538624: FAILED_place: ERROR: [Common 17-69] Command failed: Placer could not place all instances 
- W=8 D=552960: FAILED_place: ERROR: [Common 17-69] Command failed: Placer could not place all instances 
- W=16 D=262400: FAILED_place: ERROR: [Common 17-69] Command failed: Placer could not place all instances 
- W=16 D=262912: FAILED_place: ERROR: [Common 17-69] Command failed: Placer could not place all instances 
- W=16 D=263936: FAILED_place: ERROR: [Common 17-69] Command failed: Placer could not place all instances 
- W=16 D=265728: FAILED_place: ERROR: [Common 17-69] Command failed: Placer could not place all instances 
- W=16 D=269312: FAILED_place: ERROR: [Common 17-69] Command failed: Placer could not place all instances 
- W=16 D=276480: FAILED_place: ERROR: [Common 17-69] Command failed: Placer could not place all instances 
- W=18 D=229632: FAILED_place: ERROR: [Common 17-69] Command failed: Placer could not place all instances 
- W=18 D=229888: FAILED_place: ERROR: [Common 17-69] Command failed: Placer could not place all instances 
- W=18 D=230400: FAILED_place: ERROR: [Common 17-69] Command failed: Placer could not place all instances 
- W=18 D=231424: FAILED_place: ERROR: [Common 17-69] Command failed: Placer could not place all instances 
- W=18 D=233472: FAILED_place: ERROR: [Common 17-69] Command failed: Placer could not place all instances 
- W=18 D=237568: FAILED_place: ERROR: [Common 17-69] Command failed: Placer could not place all instances 
- W=18 D=245760: FAILED_place: ERROR: [Common 17-69] Command failed: Placer could not place all instances 
- W=18 D=262144: FAILED_place: ERROR: [Common 17-69] Command failed: Placer could not place all instances 
- W=32 D=131200: FAILED_place: ERROR: [Common 17-69] Command failed: Placer could not place all instances 
- W=32 D=131456: FAILED_place: ERROR: [Common 17-69] Command failed: Placer could not place all instances 
- W=32 D=131968: FAILED_place: ERROR: [Common 17-69] Command failed: Placer could not place all instances 
- W=32 D=132864: FAILED_place: ERROR: [Common 17-69] Command failed: Placer could not place all instances 
- W=32 D=134656: FAILED_place: ERROR: [Common 17-69] Command failed: Placer could not place all instances 
- W=32 D=138240: FAILED_place: ERROR: [Common 17-69] Command failed: Placer could not place all instances 
- W=36 D=98432: FAILED_place: ERROR: [Common 17-69] Command failed: Placer could not place all instances 
- W=36 D=98560: FAILED_place: ERROR: [Common 17-69] Command failed: Placer could not place all instances 
- W=36 D=98816: FAILED_place: ERROR: [Common 17-69] Command failed: Placer could not place all instances 
- W=36 D=99328: FAILED_place: ERROR: [Common 17-69] Command failed: Placer could not place all instances 
- W=36 D=100352: FAILED_place: ERROR: [Common 17-69] Command failed: Placer could not place all instances 
- W=36 D=102400: FAILED_place: ERROR: [Common 17-69] Command failed: Placer could not place all instances 
- W=36 D=106496: FAILED_place: ERROR: [Common 17-69] Command failed: Placer could not place all instances 
- W=36 D=114688: FAILED_place: ERROR: [Common 17-69] Command failed: Placer could not place all instances 
- W=36 D=131072: FAILED_place: ERROR: [Common 17-69] Command failed: Placer could not place all instances 
