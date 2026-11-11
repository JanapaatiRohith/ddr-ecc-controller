`timescale 1ns/1ps

module tb_ecc_mig_axi_bridge;
    reg clk = 1'b0;
    always #5 clk = ~clk;

    reg ui_rst = 1'b1;
    reg init_calib_complete = 1'b0;

    reg req_valid = 1'b0;
    wire req_ready;
    reg req_write = 1'b0;
    reg [23:0] req_word_addr = 24'd0;
    reg [63:0] req_wdata = 64'd0;

    wire rsp_valid;
    reg rsp_ready = 1'b0;
    wire [63:0] rsp_rdata;
    wire rsp_single_error;
    wire rsp_double_error;
    wire rsp_axi_error;

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
    wire wlast, wvalid, wready;
    wire [3:0] bid;
    wire [1:0] bresp;
    wire bvalid, bready;

    wire [3:0] arid;
    wire [27:0] araddr;
    wire [7:0] arlen;
    wire [2:0] arsize;
    wire [1:0] arburst;
    wire arlock;
    wire [3:0] arcache;
    wire [2:0] arprot;
    wire [3:0] arqos;
    wire arvalid, arready;
    wire [3:0] rid;
    wire [127:0] rdata;
    wire [1:0] rresp;
    wire rlast, rvalid, rready;
    wire protocol_error;

    ecc_mig_axi_master #(
        .AXI_ADDR_WIDTH(28),
        .AXI_ID_WIDTH(4)
    ) dut (
        .ui_clk(clk), .ui_rst(ui_rst),
        .init_calib_complete(init_calib_complete),
        .req_valid(req_valid), .req_ready(req_ready),
        .req_write(req_write), .req_word_addr(req_word_addr),
        .req_wdata(req_wdata),
        .rsp_valid(rsp_valid), .rsp_ready(rsp_ready),
        .rsp_rdata(rsp_rdata),
        .rsp_single_error(rsp_single_error),
        .rsp_double_error(rsp_double_error),
        .rsp_axi_error(rsp_axi_error),

        .m_axi_awid(awid), .m_axi_awaddr(awaddr), .m_axi_awlen(awlen),
        .m_axi_awsize(awsize), .m_axi_awburst(awburst),
        .m_axi_awlock(awlock), .m_axi_awcache(awcache),
        .m_axi_awprot(awprot), .m_axi_awqos(awqos),
        .m_axi_awvalid(awvalid), .m_axi_awready(awready),
        .m_axi_wdata(wdata), .m_axi_wstrb(wstrb), .m_axi_wlast(wlast),
        .m_axi_wvalid(wvalid), .m_axi_wready(wready),
        .m_axi_bid(bid), .m_axi_bresp(bresp),
        .m_axi_bvalid(bvalid), .m_axi_bready(bready),

        .m_axi_arid(arid), .m_axi_araddr(araddr), .m_axi_arlen(arlen),
        .m_axi_arsize(arsize), .m_axi_arburst(arburst),
        .m_axi_arlock(arlock), .m_axi_arcache(arcache),
        .m_axi_arprot(arprot), .m_axi_arqos(arqos),
        .m_axi_arvalid(arvalid), .m_axi_arready(arready),
        .m_axi_rid(rid), .m_axi_rdata(rdata), .m_axi_rresp(rresp),
        .m_axi_rlast(rlast), .m_axi_rvalid(rvalid), .m_axi_rready(rready)
    );

    axi128_ram_model #(
        .AXI_ADDR_WIDTH(28),
        .AXI_ID_WIDTH(4)
    ) u_mem (
        .clk(clk), .rst(ui_rst),
        .awid(awid), .awaddr(awaddr), .awlen(awlen),
        .awsize(awsize), .awburst(awburst),
        .awvalid(awvalid), .awready(awready),
        .wdata(wdata), .wstrb(wstrb), .wlast(wlast),
        .wvalid(wvalid), .wready(wready),
        .bid(bid), .bresp(bresp), .bvalid(bvalid), .bready(bready),
        .arid(arid), .araddr(araddr), .arlen(arlen),
        .arsize(arsize), .arburst(arburst),
        .arvalid(arvalid), .arready(arready),
        .rid(rid), .rdata(rdata), .rresp(rresp),
        .rlast(rlast), .rvalid(rvalid), .rready(rready),
        .protocol_error(protocol_error)
    );

    task automatic issue_write;
        input [23:0] addr;
        input [63:0] data;
        begin
            @(negedge clk);
            while (!req_ready) @(negedge clk);
            req_word_addr = addr;
            req_wdata = data;
            req_write = 1'b1;
            req_valid = 1'b1;
            @(negedge clk);
            req_valid = 1'b0;
            while (!rsp_valid) @(negedge clk);
            if (rsp_axi_error)
                $fatal(1, "AXI write response error at slot %0d", addr);
            rsp_ready = 1'b1;
            @(negedge clk);
            rsp_ready = 1'b0;
        end
    endtask

    task automatic issue_read_check;
        input [23:0] addr;
        input [63:0] expected_data;
        input expected_single;
        input expected_double;
        input expected_axi_error;
        begin
            @(negedge clk);
            while (!req_ready) @(negedge clk);
            req_word_addr = addr;
            req_write = 1'b0;
            req_valid = 1'b1;
            @(negedge clk);
            req_valid = 1'b0;
            while (!rsp_valid) @(negedge clk);

            if (rsp_single_error !== expected_single)
                $fatal(1, "Single-error flag mismatch at slot %0d: got %b expected %b",
                       addr, rsp_single_error, expected_single);
            if (rsp_double_error !== expected_double)
                $fatal(1, "Double-error flag mismatch at slot %0d: got %b expected %b",
                       addr, rsp_double_error, expected_double);
            if (rsp_axi_error !== expected_axi_error)
                $fatal(1, "AXI-error flag mismatch at slot %0d", addr);
            if (!expected_double && (rsp_rdata !== expected_data))
                $fatal(1, "Data mismatch at slot %0d: got %016h expected %016h",
                       addr, rsp_rdata, expected_data);

            rsp_ready = 1'b1;
            @(negedge clk);
            rsp_ready = 1'b0;
        end
    endtask

    initial begin
        repeat (4) @(negedge clk);
        ui_rst = 1'b0;
        repeat (5) @(negedge clk);
        init_calib_complete = 1'b1;

        // Baseline write/read round-trip.
        issue_write(24'd0, 64'hA55A_1234_DEAD_BEEF);
        issue_read_check(24'd0, 64'hA55A_1234_DEAD_BEEF, 1'b0, 1'b0, 1'b0);

        // Inject one physical codeword bit error: decoder must correct it.
        u_mem.mem[0][5] = ~u_mem.mem[0][5];
        issue_read_check(24'd0, 64'hA55A_1234_DEAD_BEEF, 1'b1, 1'b0, 1'b0);

        // Inject a second distinct bit error: SECDED must report uncorrectable.
        u_mem.mem[0][17] = ~u_mem.mem[0][17];
        issue_read_check(24'd0, 64'd0, 1'b0, 1'b1, 1'b0);

        // Check independent address slots and a second payload.
        issue_write(24'd1, 64'h0123_4567_89AB_CDEF);
        issue_read_check(24'd1, 64'h0123_4567_89AB_CDEF, 1'b0, 1'b0, 1'b0);

        if (protocol_error)
            $fatal(1, "AXI RAM model detected an illegal burst, alignment, or strobe");

        $display("ECC + AXI MIG BRIDGE TEST PASSED");
        $display("  AXI write/read round-trip : PASS");
        $display("  single-bit correction    : PASS");
        $display("  double-bit detection     : PASS");
        $display("  independent AW/W stalls  : PASS");
        $display("  128-bit beat formatting  : PASS");
        $finish;
    end

    initial begin
        #200000;
        $fatal(1, "GLOBAL TESTBENCH TIMEOUT");
    end
endmodule
