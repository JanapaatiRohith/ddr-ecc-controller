# Project Status — 11 November 2026

| Stage | Evidence/status |
|---|---|
| RTL and behavioral verification | Passed in saved regression logs |
| ECC AXI master + self-test behavioral integration | Passed against a 128-bit behavioral AXI RAM model |
| MIG IP synthesis (Vivado 2025.2) | Passed |
| Integrated top synthesis (Vivado 2025.2) | Passed; zero errors / zero critical warnings |
| FPGA implementation | `route_design Complete!` |
| Timing | WNS +1.274 ns; TNS 0 ns; zero failing endpoints |
| DRC | One remaining warning: REQP-1709 in MIG PLL clock-buffer topology |
| Final post-correction bitstream | Must be confirmed after the latest implementation run |
| Physical Arty A7 DDR calibration and ECC test | Pending |

The REQP-1709 message identifies MIG PLL `CLKOUT3` driving a BUFH while other outputs drive different types of loads. The project deliberately leaves generated MIG clocking RTL unmodified. The warning must be documented and the hardware behavior verified; timing closure by itself does not prove DDR calibration or ECC functionality on the board.
