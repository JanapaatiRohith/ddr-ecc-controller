# DDR3L Memory Interface with Integrated SECDED ECC

**Board:** Digilent Arty A7-100T  
**FPGA part:** `xc7a100tcsg324-1`  
**FPGA implementation tool:** AMD/Xilinx Vivado 2025.2  
**Vivado top module:** `ecc_arty_ddr_top`  
**Project status date:** 11 November 2026

This repository contains the Verilog RTL, behavioral testbenches, MIG/board integration sources, Arty A7 constraints, IP configuration collateral, scripts, reports, and project documentation for a DDR3L memory interface with SECDED error protection.

> **Status summary:** The integrated design has passed Vivado 2025.2 synthesis and place-and-route. The reported post-constraint timing is WNS `+1.274 ns`, TNS `0 ns`, with zero failing endpoints. One MIG clock-topology DRC warning (`REQP-1709`) remains documented. The final bitstream generated after the latest constraints change and physical DDR3L/ECC validation on the board still need confirmation.

---

## 1. Project overview

The project combines a Xilinx 7-series MIG DDR3L interface with a custom AXI master and SECDED encoder/decoder. The target is the on-board x16 DDR3L memory on the Arty A7-100T.

The ECC data path is:

1. Accept a 64-bit user payload.
2. Encode it into a 72-bit SECDED codeword: 64 data bits, 7 Hamming parity bits, and 1 overall parity bit.
3. Place the codeword in `WDATA[71:0]` of one 128-bit AXI beat; `WDATA[127:72]` is zero padding.
4. Transfer the beat through the MIG AXI interface to the physical DDR3L memory.
5. On reads, decode the 72-bit codeword, correct a single-bit error, or flag a detected double-bit error.

The MIG physical memory bus remains x16. The 128-bit width described above is the MIG AXI user-side data width, not the physical DDR data-bus width.

## 2. Toolchain

| Purpose | Tool |
|---|---|
| FPGA project, IP generation, synthesis, implementation and bitstream | AMD/Xilinx Vivado 2025.2 |
| FPGA target | Digilent Arty A7-100T, `xc7a100tcsg324-1` |
| DDR controller/PHY IP | Xilinx MIG 7-Series, IP 4.2 Rev. 2 as reported by Vivado 2025.2 |
| Clock generation | Clocking Wizard 6.0 Rev. 17 (`arty_clock_wiz_v25`) |
| Behavioral RTL simulation | Icarus Verilog (`iverilog`, `vvp`) |
| Waveform viewing (optional) | GTKWave |
| Source control | Git |

The Vivado 2025.2 Clocking Wizard is configured for a 100 MHz board-clock input, 166.666 MHz MIG system-clock output, 200 MHz IDELAY reference-clock output, and a `locked` output. The replacement IP instance is named `arty_clock_wiz_v25`.

## 3. Repository layout

```text
.
├── README.md
├── PROJECT_REPORT.md                 # project report, when present in the working clone
├── PROJECT_STATUS.md
├── FILE_INVENTORY.txt
├── Makefile                          # standalone controller simulation helpers, if present
├── src/                              # simplified educational DDR-style controller + SECDED RTL
├── rtl/                              # ECC AXI master, SECDED and self-test logic
│   └── vivado_board/                 # Arty wrapper, MIG example integration and board RTL
├── tb/                               # SECDED, AXI and behavioral-memory testbenches
│   └── vivado_mig/                   # MIG simulation collateral
├── constraints/                      # Arty A7 pin, clock and board constraints
├── board/                            # board-specific MIG configuration (`mig.prj` when collected)
├── ip/                               # IP configuration notes and supplied MIG XCI
├── scripts/                          # regression scripts and Vivado archive/collection helpers
├── reports/                          # MIG interface and integration inspection reports
├── docs/                             # updated presentation, workbook and implementation evidence
└── vivado/current_project_archive/   # exact Vivado 2025.2 project archive (add after capture)
```

Some folders in this repository are separate design/test paths rather than a single source set. In particular, `src/` contains the simplified educational DDR-style controller and its behavioral-memory regression, while `rtl/` and `rtl/vivado_board/` contain the ECC AXI/MIG integration. For the final Arty A7 FPGA build, use the active Vivado project archive described below as the authoritative project snapshot.

## 4. Behavioral regression tests

The scripts below run from the repository root. Install Icarus Verilog first (`iverilog` and `vvp` must be on `PATH`).

```bash
bash scripts/run_ecc_test.sh
bash scripts/run_ecc_axi_test.sh
bash scripts/run_ecc_full_integration_test.sh
```

The supplied regressions cover:

- SECDED encode/decode and error classification.
- A 64-bit payload encoded as a 72-bit codeword.
- AXI write-address/data channel handshakes and independent AW/W stalls.
- Write/read round trip through a 128-bit behavioral AXI RAM model.
- Single-bit correction and double-bit detection in the integrated behavioral path.
- Calibration gating and AXI response/protocol checks.

Previously recorded SECDED regression results include 5 clean payload patterns, 360 single-bit fault cases, and 12,780 double-bit fault cases, with zero reported failures. The behavioral AXI RAM is a simulation model: these results do **not** establish physical DDR3L operation or board-level ECC correction.

For the separate simplified controller in `src/`, the repository's Makefile and testbench files provide the standalone simulation path where present. These simulations are not a replacement for the MIG-backed board test.

## 5. Vivado 2025.2 FPGA implementation

### Target project and source of truth

The active working project used for the latest reported implementation is:

```text
C:/Users/vrnsr/arty_ddr_fpga/v25ecc/arty_ecc25.xpr
```

It targets `xc7a100tcsg324-1` and uses `ecc_arty_ddr_top` as its top module. The project integrates:

- `arty_clock_wiz_v25` — Vivado 2025.2-compatible Clocking Wizard.
- `mig_7series_0` — 7-Series MIG for the Arty A7 DDR3L interface.
- `ecc_example_top` — MIG and custom ECC AXI integration wrapper.
- `ecc_mig_axi_master`, `ecc_mig_selftest`, and `ecc_secded` — user-side AXI/ECC logic.
- Arty A7 board XDC constraints and the MIG-generated constraints.

The board XDC includes the configuration-bank properties added during DRC cleanup:

```tcl
set_property CFGBVS VCCO [current_design]
set_property CONFIG_VOLTAGE 3.3 [current_design]
```

### Vivado GUI flow

Open the `arty_ecc25` project in **Vivado 2025.2** and confirm the target part and top module. The implementation sequence is:

1. Confirm the MIG and `arty_clock_wiz_v25` IP are generated for Vivado 2025.2.
2. Run the MIG IP synthesis/out-of-context synthesis if its generated checkpoint is absent or stale.
3. Run top-level **Run Synthesis** and confirm `synth_design Complete!`.
4. Run **Run Implementation** through placement, optimization and routing.
5. Review the timing summary and DRC report.
6. Run **Generate Bitstream** after the final XDC/implementation changes.
7. Program the Arty A7 through Hardware Manager and run the physical DDR/ECC checks.

Do not use a generated IP checkpoint created by a newer Vivado release with Vivado 2025.2. If an IP checkpoint reports a version mismatch, reset/regenerate the affected IP output products in Vivado 2025.2, then synthesize that IP before the top-level design.

### Recorded Vivado results

| Stage / metric | Recorded result |
|---|---|
| MIG IP synthesis | `synth_design Complete!` |
| Integrated top synthesis | `synth_design Complete!`; zero errors and zero critical warnings |
| Implementation | `route_design Complete!` |
| Worst negative slack (WNS) | `+1.274 ns` |
| Total negative slack (TNS) | `0 ns` |
| Failing endpoints | `0` |
| Remaining DRC warning | One `REQP-1709` warning in MIG PLL clock-buffer connectivity |

The remaining `REQP-1709` warning identifies the MIG `PLLE2_ADV` `CLKOUT3` signal feeding a `BUFH`, while other PLL outputs drive different load/buffer types. The generated MIG clocking network was left unmodified. The warning is recorded for review and hardware validation; positive timing slack does not by itself prove the DDR clock phase relationship, calibration, memory transactions, or ECC self-test on the physical board.

The `CFGBVS` configuration-bank warning was addressed by adding the configuration properties to the board XDC. The remaining PLL warning should not be hidden or “fixed” by changing generated MIG PLL/buffer wiring without a vendor-supported clocking change and fresh timing/DRC validation.

## 6. Capture and add the exact Vivado project archive

The source bundle initially used to assemble this repository predates the final local `arty_ecc25` project. The repository must also contain the archive generated from the active Vivado 2025.2 project to preserve the final project configuration, including the replacement Clock Wizard IP and current MIG/XDC settings.

1. Open `C:/Users/vrnsr/arty_ddr_fpga/v25ecc/arty_ecc25.xpr` in Vivado 2025.2.
2. Copy `scripts/archive_current_vivado_project.tcl` to a Windows-accessible location, for example:

   ```bash
   cp scripts/archive_current_vivado_project.tcl /mnt/c/Users/vrnsr/Downloads/
   ```

3. In the Vivado Tcl Console, run:

   ```tcl
   source C:/Users/vrnsr/Downloads/archive_current_vivado_project.tcl
   ```

4. Back in WSL, from the repository root, run:

   ```bash
   bash scripts/collect_vivado_project.sh
   ```

The helper copies the archive and project recreation Tcl into `vivado/current_project_archive/`, and copies `C:/Users/vrnsr/arty_ddr_fpga/board/mig.prj` into `board/` when that source file is present. Review the collected files before committing them. The archive excludes run results to reduce size; Vivado can regenerate them.

## 7. Physical board validation — still pending

The recorded synthesis and routing results are FPGA implementation evidence, not a completed physical DDR test. After confirming successful bitstream generation from the latest implementation:

1. Connect and power the Arty A7-100T.
2. Open Vivado Hardware Manager and auto-connect to the device.
3. Program the latest `ecc_arty_ddr_top.bit` bitstream.
4. Verify `init_calib_complete` asserts after DDR3L initialization/calibration.
5. Verify the automatic ECC self-test completes and that its error output remains inactive for the expected test pattern.
6. Capture board status and, where possible, an ILA or UART/log trace proving the test completion and read data.
7. Do not claim physical single-bit correction or double-bit detection until hardware fault injection or a suitable hardware-visible test demonstrates those cases.

At the time of this README update, the final post-CFGBVS bitstream generation and physical Arty A7 DDR3L/ECC validation have not been confirmed in the project record.

## 8. Documentation

- `docs/DDR3L_SECDED_ECC_Vivado_Implementation_Updated.pptx` — updated project presentation with Vivado implementation as the FPGA flow.
- `docs/DDR3L_SECDED_ECC_Vivado_Implementation_Updated.xlsx` — updated project workbook/tracker.
- `PROJECT_STATUS.md` — concise implementation and validation status.
- `PROJECT_REPORT.md` — detailed project report, if present in the working clone.

## 9. Git hygiene

Do not commit local credentials or machine-specific Vivado cache/run directories. The `.gitignore` excludes common Vivado generated directories such as `.Xil/`, `*.cache/`, `*.runs/`, `*.gen/`, `*.sim/`, and `*.hw/`. The portable Vivado project archive is intentionally stored separately under `vivado/current_project_archive/` after it is captured.

Before committing:

```bash
git status --short
git diff --check
git add README.md PROJECT_STATUS.md docs rtl tb constraints ip scripts reports board vivado
git commit -m "Update project README and Vivado 2025.2 implementation status"
git push
```

---

## Project completion statement

The RTL/ECC behavioral verification, Vivado 2025.2 MIG synthesis, full-top synthesis, and FPGA place-and-route have passed according to the recorded logs. One MIG PLL clock-buffer DRC warning remains documented. The project should be described as **FPGA implementation completed, final bitstream confirmation and physical DDR3L/ECC board validation pending** until the final programming and on-board self-test evidence is captured.
