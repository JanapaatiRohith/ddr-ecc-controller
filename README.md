# DDR Controller + SECDED ECC — Digital System Design Project

## 1. Project goal

This project is a compact, simulation-friendly implementation inspired by the DDR3/DDR4 Memory Interface Solution architecture in the supplied reference material.

The reference architecture separates the Memory Controller, PHY, application/user interface, maintenance logic, and optional ECC. The controller schedules Activate/CAS/Precharge commands, handles DRAM timing and refresh, and the optional ECC path implements SECDED on a 72-bit data bus. The supplied reference also notes that a PHY-only solution leaves DRAM protocol/timing checking to the custom controller.

This student implementation deliberately stops at the controller/protocol abstraction so it is practical with open-source RTL tools.

## 2. Blocks

- `src/ecc_secded.v`
  - 64-bit data -> 72-bit SECDED codeword
  - 7 Hamming parity bits + 1 overall parity bit
  - Corrects one-bit errors
  - Detects two-bit errors
  - Reports a 7-bit syndrome

- `src/ddr_controller.v`
  - One-request-at-a-time user interface
  - Open-page policy
  - 4 banks, compact row/bank/column mapping
  - ACT, READ, WRITE, PRECHARGE, REFRESH
  - Simplified tRCD, tRP, CAS latency and tRFC handling
  - Refresh deadline / pending mechanism
  - Integrated ECC
  - Debug signals for GTKWave

- `tb/ddr3_model.v`
  - Small behavioral DRAM model
  - Stores 72-bit ECC words
  - Checks basic command legality
  - Returns reads after programmable latency
  - Supports one-shot simulation fault injection through an XOR mask

- `tb/tb_ddr_controller.v`
  - Basic write/read test
  - Page miss test
  - Cross-bank test
  - Single-bit ECC correction test
  - Double-bit ECC detection test
  - Refresh activity observation
  - VCD generation for GTKWave

## 3. Address map

The user address is a byte address. The lowest three bits are ignored for this simplified model.

- `addr[6:3]` = column (4 bits)
- `addr[8:7]` = bank (2 bits)
- `addr[12:9]` = row (4 bits)

This is only a compact educational mapping. The supplied Xilinx reference uses a configurable flat-address mapping and recommends a `ROW_COLUMN_BANK` mapping for its interface.

## 4. SECDED algorithm

The 71-bit Hamming portion uses parity positions:

`1, 2, 4, 8, 16, 32, 64`

All remaining positions carry the 64 payload bits. Bit 71 of the 72-bit codeword is an overall parity bit.

Decoder classification:

| Syndrome | Overall parity | Meaning |
|---|---:|---|
| 0 | 0 | No error |
| non-zero | 1 | Single-bit error; correct it |
| 0 | 1 | Overall parity-bit error |
| non-zero | 0 | Double-bit error; uncorrectable |

This is the SECDED behavior to demonstrate in the viva.

## 4.1 DDR command encoding

The controller also exposes a small abstract command code for simulation visibility:

| `ddr_cmd` | Operation | DDR3 control pattern `(RAS,CAS,WE)` |
|---:|---|---|
| 0 | ACTIVATE | 0,1,1 |
| 1 | READ | 1,0,1 |
| 2 | WRITE | 1,0,0 |
| 3 | PRECHARGE | 1,1,0 |
| 4 | REFRESH | 0,0,1 |
| 7 | NOP | 1,1,1 |

The abstract `ddr_cmd` is convenient for the behavioral memory model and GTKWave. The individual DDR-style control outputs are also generated to make the command sequence visible in a conventional command-bus form.

## 5. Simulation

Requirements on the user's machine:

- Icarus Verilog or another Verilog simulator
- GTKWave

Run:

```bash
make sim
make wave
```

The testbench writes and reads several addresses, injects one corrupted codeword bit, then two corrupted codeword bits, and finally waits long enough to see refresh activity.

## 6. Yosys synthesis

Run:

```bash
make synth
```

The output is `scripts/ddr_controller_synth.v`.

The intended flow is:

`Verilog RTL -> Yosys synthesis -> OpenROAD physical design -> reports/GDS`

GTKWave is the simulation/debug stage and is not a physical-design tool. OpenROAD is used after synthesis for floorplanning, placement, clock-tree synthesis, routing, timing analysis, and related RTL-to-GDS tasks.

A real OpenROAD run additionally needs a compatible standard-cell PDK/platform and Liberty/LEF technology files, which are intentionally not bundled here.

## 7. What this project does NOT claim

This is not a drop-in DDR3/DDR4 FPGA PHY or JEDEC-complete production controller. It intentionally abstracts away:

- DQS source-synchronous I/O
- Double-data-rate launch/capture
- PHY calibration/training
- Mode-register initialization
- ODT/write leveling/read leveling
- Full bank/rank timing matrix
- Burst-length-8 beat scheduling
- Multiple outstanding transaction queues
- Read/write reordering
- ECC read-modify-write for masked writes

Those are appropriate Phase-2 extensions after the baseline simulation passes.

## 8. Recommended Phase-2 upgrades

1. Add a FIFO for multiple outstanding requests.
2. Implement page-hit/page-miss arbitration.
3. Add auto-precharge handling.
4. Add masked writes using ECC read-modify-write.
5. Add a more complete DDR command timing table.
6. Add AXI4-Lite or AXI4 interface if required by the course.
7. Push the synthesized DUT through OpenROAD with the exact PDK supplied by the course/lab.

## 9. Suggested viva statement

"We designed a synthesizable simplified DDR3-style memory controller with an open-page policy and explicit DRAM command states. To improve reliability, we integrated a SECDED ECC path that maps 64-bit user data to a 72-bit codeword, corrects single-bit faults, and detects double-bit faults. A behavioral DRAM model is used for verification, while Yosys is used for RTL synthesis, GTKWave for waveform analysis, and OpenROAD for the physical-design stage."
