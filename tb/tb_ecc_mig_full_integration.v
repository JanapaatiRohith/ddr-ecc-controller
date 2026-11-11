`timescale 1ns/1ps

module tb_ecc_mig_full_integration;

    localparam AXI_ADDR_WIDTH = 28;
    localparam AXI_ID_WIDTH   = 4;
    localparam [63:0] TEST_DATA = 64'hD3C5_7A91_6E2B_40F8;

    reg clk = 1'b0;
    always #5 clk = ~clk;

    reg ui_rst = 1'b1;
    reg init_calib_complete = 1'b0;

    // ---------------------------------------------------------
    // Self-test controller interface
    // ---------------------------------------------------------
    wire st_req_valid;
    wire st_req_ready;
    wire st_req_write;
    wire [23:0] st_req_word_addr;
    wire [63:0] st_req_wdata;

    wire st_rsp_valid;
    wire st_rsp_ready;
    wire [63:0] st_rsp_rdata;
    wire st_rsp_single_error;
    wire st_rsp_double_error;
    wire st_rsp_axi_error;

    wire test_done;
    wire test_error;

    // ---------------------------------------------------------
    // Manual request interface for integrated fault testing
    // ---------------------------------------------------------
    reg manual_mode = 1'b0;

    reg manual_req_valid = 1'b0;
    wire manual_req_ready;
    reg manual_req_write = 1'b0;
    reg [23:0] manual_req_word_addr = 24'd0;
    reg [63:0] manual_req_wdata = 64'd0;

    wire manual_rsp_valid;
    reg manual_rsp_ready = 1'b0;

    // ---------------------------------------------------------
    // Multiplexed request/response interface to ECC master
    // ---------------------------------------------------------
    wire master_req_valid;
    wire master_req_ready;
    wire master_req_write;
    wire [23:0] master_req_word_addr;
    wire [63:0] master_req_wdata;

    wire master_rsp_valid;
    wire master_rsp_ready;
    wire [63:0] master_rsp_rdata;
    wire master_rsp_single_error;
    wire master_rsp_double_error;
    wire master_rsp_axi_error;

    wire [63:0] manual_rsp_rdata;
    wire manual_rsp_single_error;
    wire manual_rsp_double_error;
    wire manual_rsp_axi_error;

    assign master_req_valid =
        manual_mode ? manual_req_valid : st_req_valid;

    assign master_req_write =
        manual_mode ? manual_req_write : st_req_write;

    assign master_req_word_addr =
        manual_mode ? manual_req_word_addr : st_req_word_addr;

    assign master_req_wdata =
        manual_mode ? manual_req_wdata : st_req_wdata;

    assign st_req_ready =
        (!manual_mode) && master_req_ready;

    assign manual_req_ready =
        manual_mode && master_req_ready;

    assign st_rsp_valid =
        (!manual_mode) && master_rsp_valid;

    assign manual_rsp_valid =
        manual_mode && master_rsp_valid;

    assign master_rsp_ready =
        manual_mode ? manual_rsp_ready : st_rsp_ready;

    assign st_rsp_rdata = master_rsp_rdata;
    assign st_rsp_single_error = master_rsp_single_error;
    assign st_rsp_double_error = master_rsp_double_error;
    assign st_rsp_axi_error = master_rsp_axi_error;

    assign manual_rsp_rdata = master_rsp_rdata;
    assign manual_rsp_single_error = master_rsp_single_error;
    assign manual_rsp_double_error = master_rsp_double_error;
    assign manual_rsp_axi_error = master_rsp_axi_error;


    // ---------------------------------------------------------
    // AXI4 signals: ECC master to behavioral RAM
    // ---------------------------------------------------------
    wire [3:0] awid;
    wire [27:0] awaddr;
    wire [7:0] awlen;
    wire [2:0] awsize;
    wire [1:0] awburst;
    wire awlock;
    wire [3:0] awcache;
    wire [2:0] awprot;
    wire [3:0] awqos;
    wire awvalid;
    wire awready;

    wire [127:0] wdata;
    wire [15:0] wstrb;
    wire wlast;
    wire wvalid;
    wire wready;

    wire [3:0] bid;
    wire [1:0] bresp;
    wire bvalid;
    wire bready;

    wire [3:0] arid;
    wire [27:0] araddr;
    wire [7:0] arlen;
    wire [2:0] arsize;
    wire [1:0] arburst;
    wire arlock;
    wire [3:0] arcache;
    wire [2:0] arprot;
    wire [3:0] arqos;
    wire arvalid;
    wire arready;

    wire [3:0] rid;
    wire [127:0] rdata;
    wire [1:0] rresp;
    wire rlast;
    wire rvalid;
    wire rready;

    wire protocol_error;

    // ---------------------------------------------------------
    // ECC self-test controller
    // ---------------------------------------------------------
    ecc_mig_selftest #(
        .AXI_ADDR_WIDTH(AXI_ADDR_WIDTH),
        .TEST_DATA(TEST_DATA)
    ) u_selftest (
        .clk(clk),
        .rst(ui_rst),
        .init_calib_complete(init_calib_complete),

        .req_valid(st_req_valid),
        .req_ready(st_req_ready),
        .req_write(st_req_write),
        .req_word_addr(st_req_word_addr),
        .req_wdata(st_req_wdata),

        .rsp_valid(st_rsp_valid),
        .rsp_ready(st_rsp_ready),
        .rsp_rdata(st_rsp_rdata),
        .rsp_single_error(st_rsp_single_error),
        .rsp_double_error(st_rsp_double_error),
        .rsp_axi_error(st_rsp_axi_error),

        .test_done(test_done),
        .test_error(test_error)
    );

    // ---------------------------------------------------------
    // ECC AXI master
    // ---------------------------------------------------------
    ecc_mig_axi_master #(
        .AXI_ADDR_WIDTH(AXI_ADDR_WIDTH),
        .AXI_ID_WIDTH(AXI_ID_WIDTH)
    ) u_ecc_master (
        .ui_clk(clk),
        .ui_rst(ui_rst),
        .init_calib_complete(init_calib_complete),

        .req_valid(master_req_valid),
        .req_ready(master_req_ready),
        .req_write(master_req_write),
        .req_word_addr(master_req_word_addr),
        .req_wdata(master_req_wdata),

        .rsp_valid(master_rsp_valid),
        .rsp_ready(master_rsp_ready),
        .rsp_rdata(master_rsp_rdata),
        .rsp_single_error(master_rsp_single_error),
        .rsp_double_error(master_rsp_double_error),
        .rsp_axi_error(master_rsp_axi_error),

        .m_axi_awid(awid),
        .m_axi_awaddr(awaddr),
        .m_axi_awlen(awlen),
        .m_axi_awsize(awsize),
        .m_axi_awburst(awburst),
        .m_axi_awlock(awlock),
        .m_axi_awcache(awcache),
        .m_axi_awprot(awprot),
        .m_axi_awqos(awqos),
        .m_axi_awvalid(awvalid),
        .m_axi_awready(awready),

        .m_axi_wdata(wdata),
        .m_axi_wstrb(wstrb),
        .m_axi_wlast(wlast),
        .m_axi_wvalid(wvalid),
        .m_axi_wready(wready),

        .m_axi_bid(bid),
        .m_axi_bresp(bresp),
        .m_axi_bvalid(bvalid),
        .m_axi_bready(bready),

        .m_axi_arid(arid),
        .m_axi_araddr(araddr),
        .m_axi_arlen(arlen),
        .m_axi_arsize(arsize),
        .m_axi_arburst(arburst),
        .m_axi_arlock(arlock),
        .m_axi_arcache(arcache),
        .m_axi_arprot(arprot),
        .m_axi_arqos(arqos),
        .m_axi_arvalid(arvalid),
        .m_axi_arready(arready),

        .m_axi_rid(rid),
        .m_axi_rdata(rdata),
        .m_axi_rresp(rresp),
        .m_axi_rlast(rlast),
        .m_axi_rvalid(rvalid),
        .m_axi_rready(rready)
    );

    // ---------------------------------------------------------
    // Behavioral 128-bit AXI memory model
    // ---------------------------------------------------------
    axi128_ram_model #(
        .AXI_ADDR_WIDTH(AXI_ADDR_WIDTH),
        .AXI_ID_WIDTH(AXI_ID_WIDTH)
    ) u_mem (
        .clk(clk),
        .rst(ui_rst),

        .awid(awid),
        .awaddr(awaddr),
        .awlen(awlen),
        .awsize(awsize),
        .awburst(awburst),
        .awvalid(awvalid),
        .awready(awready),

        .wdata(wdata),
        .wstrb(wstrb),
        .wlast(wlast),
        .wvalid(wvalid),
        .wready(wready),

        .bid(bid),
        .bresp(bresp),
        .bvalid(bvalid),
        .bready(bready),

        .arid(arid),
        .araddr(araddr),
        .arlen(arlen),
        .arsize(arsize),
        .arburst(arburst),
        .arvalid(arvalid),
        .arready(arready),

        .rid(rid),
        .rdata(rdata),
        .rresp(rresp),
        .rlast(rlast),
        .rvalid(rvalid),
        .rready(rready),

        .protocol_error(protocol_error)
    );

    // ---------------------------------------------------------
    // Manual read helper for integrated fault-injection tests
    // ---------------------------------------------------------
    task automatic manual_read_check;
        input [23:0] slot;
        input [63:0] expected_data;
        input check_data;
        input expected_single;
        input expected_double;
        input expected_axi_error;

        integer n;

        begin
            @(negedge clk);
            n = 0;

            while ((manual_req_ready !== 1'b1) && n < 100) begin
                @(negedge clk);
                n = n + 1;
            end

            if (manual_req_ready !== 1'b1)
                $fatal(1, "Manual request was not accepted.");

            manual_req_word_addr = slot;
            manual_req_write = 1'b0;
            manual_req_valid = 1'b1;

            @(negedge clk);
            manual_req_valid = 1'b0;

            n = 0;
            while ((manual_rsp_valid !== 1'b1) && n < 100) begin
                @(negedge clk);
                n = n + 1;
            end

            if (manual_rsp_valid !== 1'b1)
                $fatal(1, "Manual read response timeout.");

            if (manual_rsp_single_error !== expected_single)
                $fatal(1, "Single-bit status mismatch.");

            if (manual_rsp_double_error !== expected_double)
                $fatal(1, "Double-bit status mismatch.");

            if (manual_rsp_axi_error !== expected_axi_error)
                $fatal(1, "AXI response status mismatch.");

            if (check_data && manual_rsp_rdata !== expected_data)
                $fatal(1, "Manual read data mismatch: got %016h expected %016h",
                       manual_rsp_rdata, expected_data);

            manual_rsp_ready = 1'b1;
            @(negedge clk);
            manual_rsp_ready = 1'b0;
        end
    endtask

    // ---------------------------------------------------------
    // Main integration test
    // ---------------------------------------------------------
    integer n;

    initial begin
        $display("Starting ECC + self-test + AXI RAM integration test");

        // Reset all logic and the RAM model.
        repeat (5) @(negedge clk);
        ui_rst = 1'b0;

        // Confirm the self-test waits for MIG calibration.
        repeat (8) @(negedge clk);

        if (st_req_valid !== 1'b0)
            $fatal(1, "Self-test issued a request before calibration.");

        if (awvalid || wvalid || arvalid)
            $fatal(1, "AXI request issued before calibration.");

        $display("Calibration gating: PASS");

        // Simulate successful MIG calibration.
        init_calib_complete = 1'b1;

        // Wait for self-test write/read completion.
        n = 0;
        while (!test_done && !test_error && n < 100) begin
            @(negedge clk);
            n = n + 1;
        end

        if (!test_done)
            $fatal(1, "ECC self-test did not complete successfully.");

        if (test_error)
            $fatal(1, "ECC self-test reported an error.");

        if (protocol_error)
            $fatal(1, "AXI RAM model detected an illegal transaction.");

        if (u_mem.mem[0][127:72] !== 56'b0)
            $fatal(1, "Unexpected nonzero padding in the 128-bit AXI beat.");

        $display("Self-test write/read round-trip: PASS");
        $display("ECC payload: %016h", TEST_DATA);
        $display("128-bit AXI beat padding: PASS");

        // Switch to manual requests after the self-test has completed.
        manual_mode = 1'b1;

        // Inject one bit into the stored ECC codeword.
        @(negedge clk);
        u_mem.mem[0][5] = ~u_mem.mem[0][5];

        manual_read_check(
            24'd0,
            TEST_DATA,
            1'b1,
            1'b1,
            1'b0,
            1'b0
        );

        $display("Integrated single-bit correction: PASS");

        // Add a second distinct bit error to the same codeword.
        @(negedge clk);
        u_mem.mem[0][17] = ~u_mem.mem[0][17];

        manual_read_check(
            24'd0,
            64'd0,
            1'b0,
            1'b0,
            1'b1,
            1'b0
        );

        $display("Integrated double-bit detection: PASS");

        if (protocol_error)
            $fatal(1, "AXI protocol error detected.");

        $display("--------------------------------------------");
        $display("FULL ECC MIG BEHAVIORAL INTEGRATION PASSED");
        $display("  Calibration gating        : PASS");
        $display("  Self-test write/read      : PASS");
        $display("  AXI beat formatting       : PASS");
        $display("  Single-bit correction     : PASS");
        $display("  Double-bit detection      : PASS");
        $display("  AXI protocol checks       : PASS");
        $display("--------------------------------------------");

        $finish;
    end

    initial begin
        #500000;
        $fatal(1, "GLOBAL INTEGRATION TEST TIMEOUT");
    end

endmodule
