`timescale 1ns / 1ps

// Top-level wrapper for the Digilent Arty A7-100T DDR3 MIG example design.
// CLK100MHZ is the board's 100 MHz oscillator on package pin E3.
// The Clocking Wizard generates:
//   clk_out1 = 166.666 MHz MIG system clock
//   clk_out2 = 200 MHz MIG IDELAY reference clock
// LED[0] lights after DDR3 calibration completes.
// LED[1] lights if the ECC MIG self-test reports an error.

module ecc_arty_ddr_top (
    input  wire        CLK100MHZ,
    input  wire [2:0]  SW,
    output wire [1:0]  LED,

    inout  wire [15:0] ddr3_dq,
    inout  wire [1:0]  ddr3_dqs_n,
    inout  wire [1:0]  ddr3_dqs_p,

    output wire [13:0] ddr3_addr,
    output wire [2:0]  ddr3_ba,
    output wire        ddr3_ras_n,
    output wire        ddr3_cas_n,
    output wire        ddr3_we_n,
    output wire        ddr3_reset_n,
    output wire [0:0]  ddr3_ck_p,
    output wire [0:0]  ddr3_ck_n,
    output wire [0:0]  ddr3_cke,
    output wire [0:0]  ddr3_cs_n,
    output wire [1:0]  ddr3_dm,
    output wire [0:0]  ddr3_odt
);

    wire clk_sys_166;
    wire clk_ref_200;
    wire clock_locked;
    wire init_calib_complete;
    wire ecc_test_done;
    wire tg_compare_error;

    // The Clocking Wizard is configured for 100 MHz input,
    // 166.666 MHz output 1, 200 MHz output 2, and locked output enabled.
    arty_clock_wiz_v25 u_arty_clock_wiz (
        .clk_in1 (CLK100MHZ),
        .clk_out1(clk_sys_166),
        .clk_out2(clk_ref_200),
        .locked  (clock_locked)
    );

    // MIG's configured reset polarity is active-low. While the Clocking
    // Wizard is not locked, clock_locked=0 asserts sys_rst; once locked,
    // clock_locked=1 deasserts sys_rst.
    ecc_example_top u_ecc_example_top (
        .sys_clk_i          (clk_sys_166),
        .clk_ref_i          (clk_ref_200),
        .sys_rst            (clock_locked),

        .ddr3_dq            (ddr3_dq),
        .ddr3_dqs_n          (ddr3_dqs_n),
        .ddr3_dqs_p          (ddr3_dqs_p),
        .ddr3_addr           (ddr3_addr),
        .ddr3_ba             (ddr3_ba),
        .ddr3_ras_n           (ddr3_ras_n),
        .ddr3_cas_n           (ddr3_cas_n),
        .ddr3_we_n            (ddr3_we_n),
        .ddr3_reset_n         (ddr3_reset_n),
        .ddr3_ck_p            (ddr3_ck_p),
        .ddr3_ck_n            (ddr3_ck_n),
        .ddr3_cke             (ddr3_cke),
        .ddr3_cs_n            (ddr3_cs_n),
        .ddr3_dm              (ddr3_dm),
        .ddr3_odt             (ddr3_odt),

        .init_calib_complete  (init_calib_complete),
        .ecc_test_done        (ecc_test_done),
        .tg_compare_error     (tg_compare_error)
    );

    // Normal operation: LED0 = calibration complete, LED1 = ECC error.
    // Switch override mode: SW[2] selects SW[0] and SW[1] for LED testing.
    // SW2=0: LED0 shows DDR calibration. SW2=1: LED0 shows completion
    // of clean R/W + physical single-bit correction + double-bit detection.
    // LED1 is always the sticky ECC/AXI self-test error indicator.
    // SW2=0: integrated DDR calibration + ECC test status
    // Green LED0 = calibration complete AND all ECC tests passed
    // Red LED1   = sticky ECC/AXI self-test error
    // SW2=1: manual truth-table mode (SW0 -> green, SW1 -> red)
    assign LED[0] = SW[2] ? SW[0] :
                    (init_calib_complete && ecc_test_done);
    assign LED[1] = SW[2] ? SW[1] : tg_compare_error;

endmodule
