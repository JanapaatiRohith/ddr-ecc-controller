# Digital System Design Project Report
## Design and Simulation of a DDR-Style Memory Controller with SECDED ECC

### Abstract

This project implements a compact, synthesizable DDR3-style memory controller with an integrated Single Error Correction, Double Error Detection (SECDED) error-correcting code. The design accepts read/write requests through a simple user interface, translates addresses into row/bank/column fields, tracks open pages, generates DRAM commands, observes simplified timing constraints, and performs periodic refresh. A 64-bit application data word is encoded into a 72-bit memory codeword using seven Hamming parity bits and one overall parity bit. During a read, the ECC decoder corrects a single-bit corruption and flags a double-bit corruption as uncorrectable.

### Objectives

1. Understand the architecture of a DDR memory controller.
2. Implement an RTL controller using Verilog FSMs.
3. Model ACTIVATE, READ, WRITE, PRECHARGE and REFRESH commands.
4. Demonstrate open-page behavior and DRAM timing waits.
5. Integrate SECDED ECC into the read/write datapath.
6. Verify normal operation and injected memory errors in simulation.
7. Synthesize the DUT with Yosys.
8. Prepare the design for the OpenROAD RTL-to-GDS stage.
9. Inspect controller timing, commands and ECC status using GTKWave.

### Architecture

User transaction interface

-> Address decoder / request register

-> DDR controller FSM

-> DRAM command generation

-> 72-bit ECC datapath

-> Behavioral DDR memory model (simulation)

The reference material supplied with this project describes a larger production-class architecture containing a user interface, memory controller, PHY, maintenance/refresh logic, and optional ECC. It also describes group FSMs, timing checks, arbitration, and a two-stage transaction structure. This project implements the essential educational subset instead of attempting to reproduce a complete FPGA DDR PHY.

### ECC Design

Data payload: 64 bits

Hamming portion: 71 bits

Overall parity: 1 bit

Total codeword: 72 bits

Parity positions are 1, 2, 4, 8, 16, 32, and 64 (1-based positions in the 71-bit Hamming portion). The remaining positions carry the 64 payload bits.

#### Decoder cases

- Syndrome = 0, overall parity = 0: no error.
- Syndrome != 0, overall parity = 1: one-bit error; correct indicated bit.
- Syndrome = 0, overall parity = 1: error only in overall parity; data remains valid.
- Syndrome != 0, overall parity = 0: two-bit error; uncorrectable.

### Controller FSM

`IDLE` -> accept request

`ACT` -> open target row

`WAIT_TRCD` -> satisfy activate-to-CAS delay

`READ` / `WRITE` -> issue CAS command

`READ_WAIT` -> wait for read-return latency and decode ECC

`PRE` -> close an open page on a page miss

`WAIT_TRP` -> satisfy precharge delay

`REF_SCAN` / `REF_PRE` / `REF_TRP` / `REFRESH` / `REF_WAIT` -> refresh maintenance

### Verification plan

#### Test 1 — Basic write/read

Write a known 64-bit pattern, read it back, verify equality, and confirm no ECC error.

#### Test 2 — Page miss

Access one row, then access a different row in the same bank. The controller must generate PRE before ACT.

#### Test 3 — Bank interleaving

Access two different banks and observe the bank address changing in GTKWave.

#### Test 4 — Single-bit error correction

Inject one XOR fault into the 72-bit codeword. The read data must match the original payload and `ecc_single_error` must assert.

#### Test 5 — Double-bit error detection

Inject two XOR faults into the codeword. `ecc_multiple_error` must assert and the controller must not claim the data is corrected.

#### Test 6 — Refresh

Run the simulation long enough for the refresh counter to expire. Observe PRE commands for open banks followed by REFRESH.

### Expected GTKWave signals

Add these groups to the waveform:

**User side**

`req_valid`, `req_ready`, `req_write`, `req_addr`, `req_wdata`, `resp_valid`, `resp_rdata`, `done`

**Controller**

`dbg_state`, `busy`, `dbg_active_bank`, `dbg_refresh_pending`

**DDR command bus**

`ddr_cmd`, `ddr_cs_n`, `ddr_ras_n`, `ddr_cas_n`, `ddr_we_n`, `ddr_ba`, `ddr_addr`, `ddr_dq_out`, `ddr_dq_oe`, `ddr_dq_in`

**ECC**

`ecc_single_error`, `ecc_multiple_error`, `ecc_syndrome`

### Example results to capture in the final report

1. Write transaction followed by READ returning the same 64-bit data.
2. ACT -> WAIT -> READ waveform.
3. Page miss showing PRE -> WAIT -> ACT -> WAIT -> CAS.
4. Single-bit fault showing original data recovered and `ecc_single_error=1`.
5. Double-bit fault showing `ecc_multiple_error=1`.
6. Refresh sequence showing page closure followed by REFRESH.
7. Yosys synthesis statistics.
8. OpenROAD area/timing report when a course-approved PDK is supplied.

### Limitations

The design is intentionally a controller/protocol abstraction. It does not implement a physical DDR PHY, source-synchronous DQS timing, full DDR3 initialization, calibration/training, ODT, burst-length-8 serialization, multiple outstanding request queues, transaction reordering, or the full bank/rank timing matrix. The supplied Xilinx reference material explicitly distinguishes the controller from the PHY and notes that a PHY-only custom-controller solution is responsible for DRAM protocol/timing checking.

### Future work

The strongest Phase-2 extension is a multi-bank transaction scheduler with per-bank queues. After that, add auto-precharge, masked writes with ECC read-modify-write, more complete DDR timing constraints, and an AXI interface.

### Conclusion

The project demonstrates the core ideas expected from a Digital System Design implementation: finite-state control, address decoding, timing-aware command sequencing, memory datapath design, ECC generation/correction, simulation-based verification, and synthesis preparation. The project is small enough to debug in GTKWave while being structured so that more advanced DDR features can be added incrementally.
