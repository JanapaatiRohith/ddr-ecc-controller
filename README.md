# DDR3L + SECDED ECC Controller — Full Project Source Package

**Target board:** Digilent Arty A7-100T  
**FPGA:** `xc7a100tcsg324-1`  
**Current implementation tool:** AMD/Xilinx Vivado 2025.2  
**Top module:** `ecc_arty_ddr_top`

## Project contents

- `rtl/` — ECC AXI master, SECDED encoder/decoder and self-test RTL used by the behavioral AXI regression scripts.
- `rtl/vivado_board/` — board-level top/wrapper, MIG example integration, board RTL and generated example traffic-generator source files. The board top wrapper is updated to instantiate `arty_clock_wiz_v25`, the Clocking Wizard created in Vivado 2025.2.
- `tb/` — AXI RAM model and ECC/AXI integration testbenches. `tb/vivado_mig/` contains MIG simulation collateral.
- `constraints/` — Arty A7 pin/clock constraints and switch constraints. `arty_ddr_top.xdc` includes the CFGBVS/CONFIG_VOLTAGE settings that cleared the first configuration-bank DRC warning.
- `ip/mig_config/mig_7series_0.xci` — MIG IP customization file from the supplied source bundle.
- `docs/` — updated project presentation and workbook, plus an implementation screenshot.
- `scripts/` — behavioral test commands, the current-project archive Tcl script, and a WSL helper to collect the archive.

The AXI verification RTL (`rtl/`) and board-level Vivado RTL (`rtl/vivado_board/`) are kept in separate folders because the uploaded bundle contains distinct snapshots of some source files. The Vivado project archive created from the active 2025.2 project is the source of truth for the exact board build.

## Important: add the exact current Vivado project archive

The earlier uploaded source bundle predates the final local `arty_ecc25` Vivado 2025.2 project. It does **not** contain the final `arty_ecc25.xpr`, the generated `arty_clock_wiz_v25` XCI, or the external `board/mig.prj` at their final locations. The locked Clock Wizard Rev. 19 XCI from the older Vivado 2026.1 project is intentionally not included as the active Clock Wizard.

To capture the exact working project, including the imported RTL files, generated 2025.2 IP configuration, MIG configuration and constraints:

1. Open `C:/Users/vrnsr/arty_ddr_fpga/v25ecc/arty_ecc25.xpr` in Vivado 2025.2.
2. In the Vivado Tcl Console, run `source` on `scripts/archive_current_vivado_project.tcl` (or paste its commands). It creates `C:/Users/vrnsr/arty_ddr_fpga/v25ecc/release/arty_ecc25_full_project.zip` and a project recreation Tcl file. Run results are excluded to keep the archive manageable; Vivado can regenerate them.
3. In WSL, from the cloned Git repository root, run `bash scripts/collect_vivado_project.sh`. This copies the Vivado archive and `C:/Users/vrnsr/arty_ddr_fpga/board/mig.prj` into the repository if the file is present.

The generated ZIP is the portable snapshot of the final local Vivado project. The source folders here are for code browsing and review.

## Behavioral regression commands

Run from the repository root in WSL/Linux with Icarus Verilog installed:

```bash
bash scripts/run_ecc_test.sh
bash scripts/run_ecc_axi_test.sh
bash scripts/run_ecc_full_integration_test.sh
```

These tests use a behavioral AXI RAM model. They do not demonstrate physical DDR3L operation on the Arty board.

## Current verified results

- Standalone behavioral DDR-style controller + SECDED regression: previously passed (basic read/write, page miss, cross-bank, single-bit correction, double-bit detection and refresh).
- Integrated ECC AXI bridge/self-test behavioral tests: passed against a 128-bit behavioral AXI RAM model; this is not physical DDR3L.
- Vivado 2025.2 MIG synthesis: `synth_design Complete!`.
- Vivado 2025.2 full-top synthesis: `synth_design Complete!`, zero errors and zero critical warnings.
- Vivado implementation after CFGBVS correction: `route_design Complete!`; WNS `+1.274 ns`, TNS `0 ns`, zero failing endpoints.
- One implementation DRC warning remains: `REQP-1709` on the MIG `PLLE2_ADV` CLKOUT3-to-BUFH clock path. Do not alter generated MIG PLL/buffer connections just to silence it.
- **Physical DDR3L/ECC board validation is not yet confirmed.** Final post-correction bitstream generation and physical calibration/read/write/ECC self-test on the Arty A7 remain to be confirmed.

## Vivado rebuild

After extracting `arty_ecc25_full_project.zip`, open the contained `.xpr` with Vivado 2025.2. Regenerate IP output products if prompted, then run synthesis and implementation. Review timing and DRC results before generating/programming the bitstream.

## Source-control hygiene

Do not commit machine-specific caches (`.Xil/`, `.cache/`, `.hw/`, `.runs/`, `.gen/`, `.sim/`) or credentials. The source archive is intentionally separated from temporary run outputs.
