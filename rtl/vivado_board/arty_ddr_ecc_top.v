`timescale 1ns / 1ps

module arty_ddr_ecc_top (
    input  wire        CLK100MHZ,
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

    // ---------------------------------------------------------
    // Arty A7 clock generation
    // ---------------------------------------------------------

    wire clk_sys_166;
    wire clk_ref_200;
    wire clock_locked;

    arty_clock_wiz u_arty_clock_wiz (
        .clk_in1  (CLK100MHZ),
        .clk_out1 (clk_sys_166),
        .clk_out2 (clk_ref_200),
        .locked   (clock_locked)
    );

    // ---------------------------------------------------------
    // MIG clocks, reset and calibration
    // ---------------------------------------------------------

    wire ui_clk;
    wire ui_clk_sync_rst;
    wire mmcm_locked;
    wire init_calib_complete;

    reg aresetn;

    // Preserve the reset sequencing used in example_top.
    always @(posedge ui_clk) begin
        aresetn <= ~ui_clk_sync_rst;
    end

    wire app_sr_active;
    wire app_ref_ack;
    wire app_zq_ack;
    wire [11:0] device_temp;

    // ---------------------------------------------------------
    // ECC self-test status
    // ---------------------------------------------------------

    wire test_done;
    wire test_error;

    // Slow LED indication:
    // LED[0] = MIG calibration complete
    // LED[1] = solid ON after successful ECC test
    // LED[1] = blinking if ECC test reports an error

    reg [25:0] status_count;

    always @(posedge ui_clk) begin
        if (ui_clk_sync_rst)
            status_count <= 26'd0;
        else
            status_count <= status_count + 1'b1;
    end

    assign LED[0] = init_calib_complete;
    assign LED[1] = test_error ? status_count[25] : test_done;

    // ---------------------------------------------------------
    // ECC master AXI signals
    // ---------------------------------------------------------

    wire [3:0]   m_axi_awid;
    wire [27:0]  m_axi_awaddr;
    wire [7:0]   m_axi_awlen;
    wire [2:0]   m_axi_awsize;
    wire [1:0]   m_axi_awburst;
    wire         m_axi_awlock;
    wire [3:0]   m_axi_awcache;
    wire [2:0]   m_axi_awprot;
    wire [3:0]   m_axi_awqos;
    wire         m_axi_awvalid;
    wire         m_axi_awready;

    wire [127:0] m_axi_wdata;
    wire [15:0]  m_axi_wstrb;
    wire         m_axi_wlast;
    wire         m_axi_wvalid;
    wire         m_axi_wready;

    wire [3:0]   m_axi_bid;
    wire [1:0]   m_axi_bresp;
    wire         m_axi_bvalid;
    wire         m_axi_bready;

    wire [3:0]   m_axi_arid;
    wire [27:0]  m_axi_araddr;
    wire [7:0]   m_axi_arlen;
    wire [2:0]   m_axi_arsize;
    wire [1:0]   m_axi_arburst;
    wire         m_axi_arlock;
    wire [3:0]   m_axi_arcache;
    wire [2:0]   m_axi_arprot;
    wire [3:0]   m_axi_arqos;
    wire         m_axi_arvalid;
    wire         m_axi_arready;

    wire [3:0]   m_axi_rid;
    wire [127:0] m_axi_rdata;
    wire [1:0]   m_axi_rresp;
    wire         m_axi_rlast;
    wire         m_axi_rvalid;
    wire         m_axi_rready;

    // ---------------------------------------------------------
    // ECC engine and automatic memory self-test
    // ---------------------------------------------------------

    ecc_mig_logic_top u_ecc_mig_logic (
        .ui_clk              (ui_clk),
        .ui_rst              (ui_clk_sync_rst),
        .init_calib_complete (init_calib_complete),

        .test_done           (test_done),
        .test_error          (test_error),

        .m_axi_awid          (m_axi_awid),
        .m_axi_awaddr        (m_axi_awaddr),
        .m_axi_awlen         (m_axi_awlen),
        .m_axi_awsize        (m_axi_awsize),
        .m_axi_awburst       (m_axi_awburst),
        .m_axi_awlock        (m_axi_awlock),
        .m_axi_awcache       (m_axi_awcache),
        .m_axi_awprot        (m_axi_awprot),
        .m_axi_awqos         (m_axi_awqos),
        .m_axi_awvalid       (m_axi_awvalid),
        .m_axi_awready       (m_axi_awready),

        .m_axi_wdata         (m_axi_wdata),
        .m_axi_wstrb         (m_axi_wstrb),
        .m_axi_wlast         (m_axi_wlast),
        .m_axi_wvalid        (m_axi_wvalid),
        .m_axi_wready        (m_axi_wready),

        .m_axi_bid           (m_axi_bid),
        .m_axi_bresp         (m_axi_bresp),
        .m_axi_bvalid        (m_axi_bvalid),
        .m_axi_bready        (m_axi_bready),

        .m_axi_arid          (m_axi_arid),
        .m_axi_araddr        (m_axi_araddr),
        .m_axi_arlen         (m_axi_arlen),
        .m_axi_arsize        (m_axi_arsize),
        .m_axi_arburst       (m_axi_arburst),
        .m_axi_arlock        (m_axi_arlock),
        .m_axi_arcache       (m_axi_arcache),
        .m_axi_arprot        (m_axi_arprot),
        .m_axi_arqos         (m_axi_arqos),
        .m_axi_arvalid       (m_axi_arvalid),
        .m_axi_arready       (m_axi_arready),

        .m_axi_rid           (m_axi_rid),
        .m_axi_rdata         (m_axi_rdata),
        .m_axi_rresp         (m_axi_rresp),
        .m_axi_rlast         (m_axi_rlast),
        .m_axi_rvalid        (m_axi_rvalid),
        .m_axi_rready        (m_axi_rready)
    );

    // ---------------------------------------------------------
    // Physical MIG DDR3 interface
    // ---------------------------------------------------------

    mig_7series_0 u_mig_7series_0 (

        // DDR3 physical memory interface
        .ddr3_dq       (ddr3_dq),
        .ddr3_dqs_n    (ddr3_dqs_n),
        .ddr3_dqs_p    (ddr3_dqs_p),
        .ddr3_addr     (ddr3_addr),
        .ddr3_ba       (ddr3_ba),
        .ddr3_ras_n    (ddr3_ras_n),
        .ddr3_cas_n    (ddr3_cas_n),
        .ddr3_we_n     (ddr3_we_n),
        .ddr3_reset_n  (ddr3_reset_n),
        .ddr3_ck_p     (ddr3_ck_p),
        .ddr3_ck_n     (ddr3_ck_n),
        .ddr3_cke      (ddr3_cke),
        .ddr3_cs_n     (ddr3_cs_n),
        .ddr3_dm       (ddr3_dm),
        .ddr3_odt      (ddr3_odt),

        // MIG clock and reset
        .sys_clk_i         (clk_sys_166),
        .clk_ref_i         (clk_ref_200),
        .sys_rst           (clock_locked),

        .ui_clk            (ui_clk),
        .ui_clk_sync_rst   (ui_clk_sync_rst),
        .mmcm_locked       (mmcm_locked),
        .aresetn           (aresetn),

        // Optional application requests unused
        .app_sr_req        (1'b0),
        .app_ref_req       (1'b0),
        .app_zq_req        (1'b0),
        .app_sr_active     (app_sr_active),
        .app_ref_ack       (app_ref_ack),
        .app_zq_ack        (app_zq_ack),

        // AXI write address
        .s_axi_awid        (m_axi_awid),
        .s_axi_awaddr      (m_axi_awaddr),
        .s_axi_awlen       (m_axi_awlen),
        .s_axi_awsize      (m_axi_awsize),
        .s_axi_awburst     (m_axi_awburst),
        .s_axi_awlock      (m_axi_awlock),
        .s_axi_awcache     (m_axi_awcache),
        .s_axi_awprot      (m_axi_awprot),
        .s_axi_awqos       (m_axi_awqos),
        .s_axi_awvalid     (m_axi_awvalid),
        .s_axi_awready     (m_axi_awready),

        // AXI write data
        .s_axi_wdata       (m_axi_wdata),
        .s_axi_wstrb       (m_axi_wstrb),
        .s_axi_wlast       (m_axi_wlast),
        .s_axi_wvalid      (m_axi_wvalid),
        .s_axi_wready      (m_axi_wready),

        // AXI write response
        .s_axi_bid         (m_axi_bid),
        .s_axi_bresp       (m_axi_bresp),
        .s_axi_bvalid      (m_axi_bvalid),
        .s_axi_bready      (m_axi_bready),

        // AXI read address
        .s_axi_arid        (m_axi_arid),
        .s_axi_araddr      (m_axi_araddr),
        .s_axi_arlen       (m_axi_arlen),
        .s_axi_arsize      (m_axi_arsize),
        .s_axi_arburst     (m_axi_arburst),
        .s_axi_arlock      (m_axi_arlock),
        .s_axi_arcache     (m_axi_arcache),
        .s_axi_arprot      (m_axi_arprot),
        .s_axi_arqos       (m_axi_arqos),
        .s_axi_arvalid     (m_axi_arvalid),
        .s_axi_arready     (m_axi_arready),

        // AXI read data
        .s_axi_rid         (m_axi_rid),
        .s_axi_rdata       (m_axi_rdata),
        .s_axi_rresp       (m_axi_rresp),
        .s_axi_rlast       (m_axi_rlast),
        .s_axi_rvalid      (m_axi_rvalid),
        .s_axi_rready      (m_axi_rready),

        .init_calib_complete (init_calib_complete),
        .device_temp        (device_temp)
    );

endmodule
