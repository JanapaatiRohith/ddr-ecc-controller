module ecc_mig_logic_top (
    input wire ui_clk,
    input wire ui_rst,
    input wire init_calib_complete,

    output wire test_done,
    output wire test_error,

    output wire [3:0] m_axi_awid,
    output wire [27:0] m_axi_awaddr,
    output wire [7:0] m_axi_awlen,
    output wire [2:0] m_axi_awsize,
    output wire [1:0] m_axi_awburst,
    output wire m_axi_awlock,
    output wire [3:0] m_axi_awcache,
    output wire [2:0] m_axi_awprot,
    output wire [3:0] m_axi_awqos,
    output wire m_axi_awvalid,
    input wire m_axi_awready,

    output wire [127:0] m_axi_wdata,
    output wire [15:0] m_axi_wstrb,
    output wire m_axi_wlast,
    output wire m_axi_wvalid,
    input wire m_axi_wready,

    input wire [3:0] m_axi_bid,
    input wire [1:0] m_axi_bresp,
    input wire m_axi_bvalid,
    output wire m_axi_bready,

    output wire [3:0] m_axi_arid,
    output wire [27:0] m_axi_araddr,
    output wire [7:0] m_axi_arlen,
    output wire [2:0] m_axi_arsize,
    output wire [1:0] m_axi_arburst,
    output wire m_axi_arlock,
    output wire [3:0] m_axi_arcache,
    output wire [2:0] m_axi_arprot,
    output wire [3:0] m_axi_arqos,
    output wire m_axi_arvalid,
    input wire m_axi_arready,

    input wire [3:0] m_axi_rid,
    input wire [127:0] m_axi_rdata,
    input wire [1:0] m_axi_rresp,
    input wire m_axi_rlast,
    input wire m_axi_rvalid,
    output wire m_axi_rready
);

    wire req_valid;
    wire req_ready;
    wire req_write;
    wire [23:0] req_word_addr;
    wire [63:0] req_wdata;

    wire rsp_valid;
    wire rsp_ready;
    wire [63:0] rsp_rdata;
    wire rsp_single_error;
    wire rsp_double_error;
    wire rsp_axi_error;

    ecc_mig_selftest #(
        .AXI_ADDR_WIDTH(28)
    ) u_selftest (
        .clk(ui_clk),
        .rst(ui_rst),
        .init_calib_complete(init_calib_complete),

        .req_valid(req_valid),
        .req_ready(req_ready),
        .req_write(req_write),
        .req_word_addr(req_word_addr),
        .req_wdata(req_wdata),

        .rsp_valid(rsp_valid),
        .rsp_ready(rsp_ready),
        .rsp_rdata(rsp_rdata),
        .rsp_single_error(rsp_single_error),
        .rsp_double_error(rsp_double_error),
        .rsp_axi_error(rsp_axi_error),

        .test_done(test_done),
        .test_error(test_error)
    );

    ecc_mig_axi_master #(
        .AXI_ADDR_WIDTH(28),
        .AXI_ID_WIDTH(4)
    ) u_ecc_master (
        .ui_clk(ui_clk),
        .ui_rst(ui_rst),
        .init_calib_complete(init_calib_complete),

        .req_valid(req_valid),
        .req_ready(req_ready),
        .req_write(req_write),
        .req_word_addr(req_word_addr),
        .req_wdata(req_wdata),

        .rsp_valid(rsp_valid),
        .rsp_ready(rsp_ready),
        .rsp_rdata(rsp_rdata),
        .rsp_single_error(rsp_single_error),
        .rsp_double_error(rsp_double_error),
        .rsp_axi_error(rsp_axi_error),

        .m_axi_awid(m_axi_awid),
        .m_axi_awaddr(m_axi_awaddr),
        .m_axi_awlen(m_axi_awlen),
        .m_axi_awsize(m_axi_awsize),
        .m_axi_awburst(m_axi_awburst),
        .m_axi_awlock(m_axi_awlock),
        .m_axi_awcache(m_axi_awcache),
        .m_axi_awprot(m_axi_awprot),
        .m_axi_awqos(m_axi_awqos),
        .m_axi_awvalid(m_axi_awvalid),
        .m_axi_awready(m_axi_awready),

        .m_axi_wdata(m_axi_wdata),
        .m_axi_wstrb(m_axi_wstrb),
        .m_axi_wlast(m_axi_wlast),
        .m_axi_wvalid(m_axi_wvalid),
        .m_axi_wready(m_axi_wready),

        .m_axi_bid(m_axi_bid),
        .m_axi_bresp(m_axi_bresp),
        .m_axi_bvalid(m_axi_bvalid),
        .m_axi_bready(m_axi_bready),

        .m_axi_arid(m_axi_arid),
        .m_axi_araddr(m_axi_araddr),
        .m_axi_arlen(m_axi_arlen),
        .m_axi_arsize(m_axi_arsize),
        .m_axi_arburst(m_axi_arburst),
        .m_axi_arlock(m_axi_arlock),
        .m_axi_arcache(m_axi_arcache),
        .m_axi_arprot(m_axi_arprot),
        .m_axi_arqos(m_axi_arqos),
        .m_axi_arvalid(m_axi_arvalid),
        .m_axi_arready(m_axi_arready),

        .m_axi_rid(m_axi_rid),
        .m_axi_rdata(m_axi_rdata),
        .m_axi_rresp(m_axi_rresp),
        .m_axi_rlast(m_axi_rlast),
        .m_axi_rvalid(m_axi_rvalid),
        .m_axi_rready(m_axi_rready)
    );

endmodule
