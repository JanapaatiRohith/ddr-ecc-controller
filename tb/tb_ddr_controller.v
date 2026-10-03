`timescale 1ns/1ps

module tb_ddr_controller;
    reg clk;
    reg rst;
    reg req_valid;
    reg req_write;
    reg [12:0] req_addr;
    reg [63:0] req_wdata;
    wire req_ready;

    wire resp_valid;
    wire [63:0] resp_rdata;
    wire ecc_single_error;
    wire ecc_multiple_error;
    wire [6:0] ecc_syndrome;
    wire done;

    wire [2:0] ddr_cmd;
    wire ddr_cs_n, ddr_ras_n, ddr_cas_n, ddr_we_n;
    wire [1:0] ddr_ba;
    wire [3:0] ddr_addr;
    wire [71:0] ddr_dq_out;
    wire ddr_dq_oe;
    wire [71:0] ddr_dq_in;

    wire busy;
    wire [3:0] dbg_state;
    wire [1:0] dbg_active_bank;
    wire [3:0] dbg_open_row_bank0, dbg_open_row_bank1;
    wire [3:0] dbg_open_row_bank2, dbg_open_row_bank3;
    wire dbg_refresh_pending;

    reg fault_enable;
    reg [71:0] fault_mask;

    ddr_controller #(
        .TRCD(2),
        .TRP(2),
        .TCL(3),
        .TRFC(4),
        .REFRESH_INTERVAL(30)
    ) dut (
        .clk(clk),
        .rst(rst),
        .req_valid(req_valid),
        .req_write(req_write),
        .req_addr(req_addr),
        .req_wdata(req_wdata),
        .req_ready(req_ready),
        .resp_valid(resp_valid),
        .resp_rdata(resp_rdata),
        .ecc_single_error(ecc_single_error),
        .ecc_multiple_error(ecc_multiple_error),
        .ecc_syndrome(ecc_syndrome),
        .done(done),
        .ddr_cmd(ddr_cmd),
        .ddr_cs_n(ddr_cs_n),
        .ddr_ras_n(ddr_ras_n),
        .ddr_cas_n(ddr_cas_n),
        .ddr_we_n(ddr_we_n),
        .ddr_ba(ddr_ba),
        .ddr_addr(ddr_addr),
        .ddr_dq_out(ddr_dq_out),
        .ddr_dq_oe(ddr_dq_oe),
        .ddr_dq_in(ddr_dq_in),
        .busy(busy),
        .dbg_state(dbg_state),
        .dbg_active_bank(dbg_active_bank),
        .dbg_open_row_bank0(dbg_open_row_bank0),
        .dbg_open_row_bank1(dbg_open_row_bank1),
        .dbg_open_row_bank2(dbg_open_row_bank2),
        .dbg_open_row_bank3(dbg_open_row_bank3),
        .dbg_refresh_pending(dbg_refresh_pending)
    );

    ddr3_model #(
        .ROWS(16),
        .BANKS(4),
        .COLS(16),
        .READ_LATENCY(3)
    ) mem_model (
        .clk(clk),
        .rst(rst),
        .ddr_cmd(ddr_cmd),
        .ddr_ba(ddr_ba),
        .ddr_addr(ddr_addr),
        .ddr_dq_out(ddr_dq_out),
        .ddr_dq_oe(ddr_dq_oe),
        .ddr_dq_in(ddr_dq_in),
        .fault_enable(fault_enable),
        .fault_mask(fault_mask)
    );

    // 100 MHz simulation clock.
    initial begin
        clk = 0;
        forever #5 clk = ~clk;
    end

    task send_write;
        input [12:0] a;
        input [63:0] d;
        begin
            @(posedge clk);
            while (!req_ready) @(posedge clk);
            req_valid <= 1'b1;
            req_write <= 1'b1;
            req_addr <= a;
            req_wdata <= d;
            @(posedge clk);
            req_valid <= 1'b0;
            req_write <= 1'b0;
            wait(done);
        end
    endtask

    task send_read;
        input [12:0] a;
        input [63:0] expected;
        begin
            @(posedge clk);
            while (!req_ready) @(posedge clk);
            req_valid <= 1'b1;
            req_write <= 1'b0;
            req_addr <= a;
            req_wdata <= 64'b0;
            @(posedge clk);
            req_valid <= 1'b0;
            wait(resp_valid);
            if (resp_rdata !== expected) begin
                $display("FAIL: read mismatch addr=%h expected=%h got=%h", a, expected, resp_rdata);
                $finish;
            end
            if (ecc_single_error || ecc_multiple_error) begin
                $display("FAIL: unexpected ECC error on clean read addr=%h", a);
                $finish;
            end
            @(posedge clk);
        end
    endtask

    task send_read_ecc;
        input [12:0] a;
        input [63:0] expected;
        input expect_single;
        input expect_multiple;
        begin
            @(negedge clk);
            while (!req_ready)
                @(negedge clk);

            req_valid = 1'b1;
            req_write = 1'b0;
            req_addr  = a;
            req_wdata = 64'b0;

            @(posedge clk);

            @(negedge clk);
            req_valid = 1'b0;
            req_write = 1'b0;

            wait(resp_valid === 1'b1);
            #1;

            // For a correctable error, the original data must be restored.
            if (!expect_multiple) begin
                if (resp_rdata !== expected) begin
                    $display("FAIL: ECC read data mismatch addr=%h expected=%h got=%h",
                             a, expected, resp_rdata);
                    $finish;
                end
            end

            if (ecc_single_error !== expect_single) begin
                $display("FAIL: single-error flag mismatch addr=%h expected=%b got=%b",
                         a, expect_single, ecc_single_error);
                $finish;
            end

            if (ecc_multiple_error !== expect_multiple) begin
                $display("FAIL: multiple-error flag mismatch addr=%h expected=%b got=%b",
                         a, expect_multiple, ecc_multiple_error);
                $finish;
            end

            if (expect_multiple) begin
                $display("ECC CHECK PASS addr=%h uncorrectable data=%h single=%b multiple=%b syndrome=%b",
                         a, resp_rdata, ecc_single_error,
                         ecc_multiple_error, ecc_syndrome);
            end
            else begin
                $display("ECC CHECK PASS addr=%h data=%h single=%b multiple=%b syndrome=%b",
                         a, resp_rdata, ecc_single_error,
                         ecc_multiple_error, ecc_syndrome);
            end

            @(negedge clk);
        end
    endtask

initial begin
        req_valid = 0;
        req_write = 0;
        req_addr = 0;
        req_wdata = 0;
        fault_enable = 0;
        fault_mask = 0;
        rst = 1;

        repeat (4) @(posedge clk);
        rst = 0;

        $display("--- TEST 1: basic write/read ---");
        // bank=0,row=1,col=8 => byte address = row<<9 | bank<<7 | col<<3
        send_write(13'h242, 64'h0123_4567_89AB_CDEF);
        send_read (13'h242, 64'h0123_4567_89AB_CDEF);

        $display("--- TEST 2: page miss / different row same bank ---");
        send_write(13'h442, 64'hCAFE_F00D_1234_5678);
        send_read (13'h442, 64'hCAFE_F00D_1234_5678);

        $display("--- TEST 3: cross-bank access ---");
        send_write(13'h2C2, 64'hDEAD_BEEF_A5A5_5A5A);
        send_read (13'h2C2, 64'hDEAD_BEEF_A5A5_5A5A);

        $display("--- TEST 4: single-bit ECC correction ---");
        fault_enable = 1'b1;
        fault_mask = 72'b0;
        fault_mask[10] = 1'b1;

        send_read_ecc(
            13'h242,
            64'h0123_4567_89AB_CDEF,
            1'b1,
            1'b0
        );

        fault_enable = 1'b0;
        fault_mask = 72'b0;

        $display("--- TEST 5: double-bit ECC detection ---");
        fault_enable = 1'b1;
        fault_mask = 72'b0;
        fault_mask[10] = 1'b1;
        fault_mask[20] = 1'b1;

        send_read_ecc(
            13'h242,
            64'h0123_4567_89AB_CDEF,
            1'b0,
            1'b1
        );

        fault_enable = 1'b0;
        fault_mask = 72'b0;

        $display("--- Waiting for refresh activity ---");
        repeat (45) @(posedge clk);

        $display("PASS: DDR controller + SECDED ECC simulation completed.");
        $finish;
    end

    initial begin
        $dumpfile("ddr_controller.vcd");
        $dumpvars(0, tb_ddr_controller);
    end

    // Simulation watchdog: helps identify deadlocks in controller/testbench.
    initial begin
        repeat (250) @(posedge clk);
        $display("");
        $display("========== WATCHDOG TIMEOUT ==========");
        $display("time              = %0t", $time);
        $display("dut.state         = %0d", dut.state);
        $display("req_valid         = %b", req_valid);
        $display("req_ready         = %b", req_ready);
        $display("resp_valid        = %b", resp_valid);
        $display("busy              = %b", busy);
        $display("refresh_pending   = %b", dbg_refresh_pending);
        $display("refresh_count     = %0d", dut.refresh_count);
        $display("refresh_bank      = %0d", dut.refresh_bank);
        $display("wait_count        = %0d", dut.wait_count);
        $display("ddr_cmd           = %0d", ddr_cmd);
        $display("ecc_single        = %b", ecc_single_error);
        $display("ecc_multiple      = %b", ecc_multiple_error);
        $display("ecc_syndrome      = %b", ecc_syndrome);
        $display("======================================");
        $finish;
    end

endmodule
