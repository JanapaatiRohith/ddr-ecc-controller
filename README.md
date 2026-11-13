# DDR3L Memory Interface with Integrated SECDED ECC

**Target board:** Digilent Arty A7-100T  
**FPGA:** `xc7a100tcsg324-1` (Artix-7)  
**FPGA tool:** AMD/Xilinx Vivado 2025.2  
**Top module:** `ecc_arty_ddr_top`  
**Status updated:** 13 November 2026

This repository contains the RTL, behavioral testbenches, Xilinx MIG-based DDR3L integration, SECDED ECC logic, Arty A7 constraints, Vivado IP/project collateral, reports, and project documentation for a 64-bit payload protected by 72-bit SECDED codewords.

## Current project status

The project has completed the behavioral RTL verification and the Vivado FPGA implementation flow. The integrated top-level design was synthesized, implemented (place and route), and a bitstream was generated for the Arty A7-100T. The user also reports successful programming and board-level integrated LED status testing.

Latest reported Vivado implementation metrics:

| Metric | Result |
|---|---:|
| Device | `xc7a100tcsg324-1` |
| Vivado synthesis | Complete, 0 errors, 0 critical warnings |
| Implementation | `route_design Complete!` |
| Bitstream generation | `write_bitstream Complete!` |
| WNS | `+1.274 ns` |
| TNS | `0 ns` |
| Failing timing endpoints | `0` |
| Remaining DRC warning | `REQP-1709` (MIG PLL output/buffer topology) |
| Bitstream path | `arty_ecc25.runs/impl_1/ecc_arty_ddr_top.bit` |
| Reported bitstream size | `3,825,917 bytes` |

The `REQP-1709` warning concerns the generated MIG `PLLE2_ADV` output clock-buffer topology (`CLKOUT3` feeding a `BUFH`). It was inspected and not suppressed or “fixed” by changing generated MIG clock circuitry. The warning should remain documented when presenting the implementation results.

The user reports that the board was programmed, the Arty A7 `DONE` status was high, DDR calibration was indicated by the green status LED, and the integrated DDR/ECC LED-status test was working. The integrated status LED logic is intended to show green only when calibration and the self-test completion are both true, and red on a reported test error. This is board-level status-indicator evidence; raw internal signals were not captured with ILA/VIO because the tested bitstream did not contain those debug cores.

The manual switch/LED truth-table test was also performed on the FPGA. With `SW2=1`, `SW0` controls green `LED[0]` and `SW1` controls red `LED[1]`. With `SW2=0`, the LEDs indicate the integrated MIG/ECC status.

## Architecture

The physical DDR3L controller and PHY are provided by AMD/Xilinx MIG 7-Series IP. The custom AXI master and SECDED logic sit on the MIG user-side AXI interface.

- User payload: 64 bits.
- SECDED codeword: 72 bits = 64 data + 7 Hamming parity + 1 overall parity.
- MIG AXI beat: 128 bits; codeword in `WDATA[71:0]`, `WDATA[127:72]` padded with zeros.
- Physical DDR3L data interface: x16; the 128-bit width is the MIG AXI user-side width, not the physical DRAM bus width.

The repository also contains a separate simplified DDR-style controller and behavioral DRAM model. That educational model is useful for RTL learning and verification, but is not the physical DDR3 PHY. Keep those two design paths clearly distinguished in reports and presentations.

## Repository layout

```text
.
├── README.md
├── PROJECT_STATUS.md
├── PROJECT_REPORT.md
├── src/                         # simplified DDR-style controller and SECDED RTL
├── rtl/
│   ├── ecc_mig_axi_master.v      # MIG-facing AXI master
│   ├── ecc_mig_selftest.v        # self-test control
│   └── vivado_board/             # board top and MIG example integration RTL
├── tb/                          # behavioral DRAM, AXI RAM, ECC and integration tests
│   └── vivado_mig/               # MIG simulation collateral (if included)
├── constraints/                 # Arty A7 XDC constraints
├── board/                       # board-specific MIG configuration (`mig.prj`)
├── ip/                           # MIG and Clock Wizard XCI/IP notes
├── scripts/                      # test scripts and Vivado archive helpers
├── reports/                      # interface, timing and integration reports
├── docs/                         # presentation, workbook and hardware evidence
└── artifacts/                    # optional release bitstream and checksums
```

## Behavioral verification

Install Icarus Verilog (`iverilog` and `vvp`) and run from the repository root:

```bash
bash scripts/run_ecc_test.sh
bash scripts/run_ecc_axi_test.sh
bash scripts/run_ecc_full_integration_test.sh
```

Previously recorded regression results include 5 clean payload patterns, 360 single-bit fault cases, and 12,780 double-bit fault cases with zero reported failures. The behavioral AXI RAM model exercises AXI handshakes and stalls. These tests are simulation evidence, not physical DRAM measurements.

## Vivado 2025.2 implementation

The working Windows project used for the integrated Arty A7 implementation is:

```text
C:/Users/vrnsr/arty_ddr_fpga/v25ecc/arty_ecc25.xpr
```

Target part:

```text
xc7a100tcsg324-1
```

Main IP:

- `mig_7series_0`: MIG 7-Series IP 4.2 Rev. 2.
- `arty_clock_wiz_v25`: Clocking Wizard 6.0 Rev. 17, regenerated for Vivado 2025.2.

Clock Wizard configuration: 100 MHz input, 166.666 MHz MIG system clock, 200 MHz IDELAY reference clock, and `locked` output. The MIG-generated PLL/PHY clocking and constraints should be treated as generated IP collateral; do not hand-edit generated PLL/buffer RTL to silence `REQP-1709`.

Typical Vivado flow:

1. Open `arty_ecc25.xpr` in Vivado 2025.2.
2. Confirm top module `ecc_arty_ddr_top` and the 2025.2 Clock Wizard IP `arty_clock_wiz_v25`.
3. Generate MIG and Clock Wizard output products.
4. Run synthesis.
5. Run implementation through route design and DRC.
6. Review timing summary and DRC; document the remaining MIG `REQP-1709` warning.
7. Run `write_bitstream` and program the Arty A7 using Hardware Manager.
8. Test normal status mode (`SW2=0`) and manual LED mode (`SW2=1`).

For the latest reported build, Vivado Hardware Manager detected `xc7a100t_0`; the FPGA `DONE` status was `1`, and programming reported startup status `HIGH`. The design had no ILA/VIO debug cores, so internal MIG/ECC signals were not directly readable in Hardware Manager.

## LED behavior and board test

The integrated status mode and manual test mode are selected by `SW2`:

| SW2 | SW1 | SW0 | LED[1] red | LED[0] green | Meaning |
|---:|---:|---:|---:|---:|---|
| 0 | X | X | actual error status | actual calibration / integrated completion status | normal status mode |
| 1 | 0 | 0 | 0 | 0 | manual LED test |
| 1 | 0 | 1 | 0 | 1 | manual LED test |
| 1 | 1 | 0 | 1 | 0 | manual LED test |
| 1 | 1 | 1 | 1 | 1 | manual LED test |

The final diagnostic top-level LED mapping is intended to make green `LED[0]` assert only when `init_calib_complete && ecc_test_done` is true in normal mode; red `LED[1]` reports `tg_compare_error`. Verify the committed RTL against the active Vivado project before relying on these definitions for a later rebuild.

The automatic physical self-test is intended to perform a clean DDR write/read, a single-bit codeword fault test, and a double-bit codeword fault test. Faults are deliberately injected in the FPGA data path before the MIG write, so the corrupted codewords traverse the physical DDR write/read path. This is controlled logic fault injection, not a naturally occurring DRAM-cell upset. The user reports that the integrated board status indication is working; retain photos/logs as supporting evidence and do not claim raw ILA traces unless they are captured separately.

## Reproducibility and release artifacts

Do not commit Vivado cache directories or temporary run products such as `.Xil/`, `*.cache/`, `*.hw/`, `*.runs/`, or `*.sim/`. A portable Vivado project archive (created with Vivado's `archive_project`) is preferred over copying generated run folders. Include the `.xpr`, required XCI files, MIG `mig.prj`, board XDC files, and a README note describing the Vivado version.

An optional release bitstream may be stored under `artifacts/bitstreams/` if repository policy permits binary artifacts. Include its SHA-256 checksum and the exact target part/Vivado version. Keep source RTL and constraints as the primary reproducible project contents.

## Remaining limitations

- The MIG `REQP-1709` DRC warning remains documented; do not suppress it or modify MIG clocking without a timing/clocking review.
- The current bitstream has no ILA/VIO cores; add an ILA in a separate debug build if direct internal signal capture is needed.
- The LED indication is a compact status summary. For stronger evidence, capture the individual clean-read comparison, single-error flag, double-error flag, syndrome, and self-test state via ILA or UART.
- Board-level results are tied to the exact committed RTL, XDC, IP configuration, and bitstream. Re-run implementation if any of these change.

## Suggested citation in a project report

“Implemented on the Digilent Arty A7-100T (XC7A100T) using Vivado 2025.2 and MIG 7-Series. Vivado reported successful synthesis, routing, and bitstream generation with WNS +1.274 ns, TNS 0 ns, and zero failing timing endpoints. The generated MIG PLL clock-buffer DRC warning REQP-1709 is documented. The FPGA was programmed and board-level DDR/MIG/ECC status and manual switch-to-LED tests were reported working.”
