`timescale 1ns/1ps

// Single-outstanding AXI4 master for the Arty A7 MIG configuration.
//
// Memory mapping:
//   One 64-bit payload is SECDED encoded to 72 bits.
//   The 72-bit codeword occupies WDATA[71:0] of one 128-bit AXI beat.
//   WDATA[127:72] is zero padding. One payload slot consumes 16 bytes.
//   req_word_addr is a logical 16-byte slot index; AXI byte address is
//   {req_word_addr, 4'b0000}.
//
// This module connects to the MIG's AXI4 SLAVE interface (s_axi_* ports).
// It does NOT connect to MIG's internal app_* interface or DDR pins.
// AXI data width is fixed by this Arty A7 MIG instance at 128 bits.

module ecc_mig_axi_master #(
    parameter AXI_ADDR_WIDTH = 28,
    parameter AXI_ID_WIDTH   = 4
) (
    input  wire                         ui_clk,
    input  wire                         ui_rst,              // active-high, synchronous to ui_clk
    input  wire                         init_calib_complete,

    // Simple user-side request/response interface.
    input  wire                         req_valid,
    output wire                         req_ready,
    input  wire                         req_write,           // 1=write, 0=read
    input  wire [AXI_ADDR_WIDTH-5:0]     req_word_addr,       // 16-byte slot address
    input  wire [63:0]                  req_wdata,
    input  wire [1:0]                   req_fault_mode,      // 00=clean, 01=single-bit, 10=double-bit write fault
    output reg                          rsp_valid,
    input  wire                         rsp_ready,
    output reg  [63:0]                  rsp_rdata,
    output reg                          rsp_single_error,
    output reg                          rsp_double_error,
    output reg                          rsp_axi_error,

    // AXI4 master write address channel -> MIG s_axi_aw*
    output reg  [AXI_ID_WIDTH-1:0]      m_axi_awid,
    output reg  [AXI_ADDR_WIDTH-1:0]    m_axi_awaddr,
    output reg  [7:0]                   m_axi_awlen,
    output reg  [2:0]                   m_axi_awsize,
    output reg  [1:0]                   m_axi_awburst,
    output reg                          m_axi_awlock,
    output reg  [3:0]                   m_axi_awcache,
    output reg  [2:0]                   m_axi_awprot,
    output reg  [3:0]                   m_axi_awqos,
    output reg                          m_axi_awvalid,
    input  wire                         m_axi_awready,

    // AXI4 master write data channel
    output reg  [127:0]                 m_axi_wdata,
    output reg  [15:0]                  m_axi_wstrb,
    output reg                          m_axi_wlast,
    output reg                          m_axi_wvalid,
    input  wire                         m_axi_wready,

    // AXI4 write response channel
    input  wire [AXI_ID_WIDTH-1:0]      m_axi_bid,
    input  wire [1:0]                   m_axi_bresp,
    input  wire                         m_axi_bvalid,
    output reg                          m_axi_bready,

    // AXI4 master read address channel -> MIG s_axi_ar*
    output reg  [AXI_ID_WIDTH-1:0]      m_axi_arid,
    output reg  [AXI_ADDR_WIDTH-1:0]    m_axi_araddr,
    output reg  [7:0]                   m_axi_arlen,
    output reg  [2:0]                   m_axi_arsize,
    output reg  [1:0]                   m_axi_arburst,
    output reg                          m_axi_arlock,
    output reg  [3:0]                   m_axi_arcache,
    output reg  [2:0]                   m_axi_arprot,
    output reg  [3:0]                   m_axi_arqos,
    output reg                          m_axi_arvalid,
    input  wire                         m_axi_arready,

    // AXI4 read response channel
    input  wire [AXI_ID_WIDTH-1:0]      m_axi_rid,
    input  wire [127:0]                 m_axi_rdata,
    input  wire [1:0]                   m_axi_rresp,
    input  wire                         m_axi_rlast,
    input  wire                         m_axi_rvalid,
    output reg                          m_axi_rready
);

    localparam [2:0] ST_IDLE      = 3'd0;
    localparam [2:0] ST_WR_SEND   = 3'd1;
    localparam [2:0] ST_WR_RESP   = 3'd2;
    localparam [2:0] ST_RD_ADDR   = 3'd3;
    localparam [2:0] ST_RD_DATA   = 3'd4;
    localparam [2:0] ST_RESPONSE  = 3'd5;

    reg [2:0] state;
    wire [71:0] encoded_codeword;
    wire [71:0] write_codeword_with_fault;
    wire [63:0] decoded_data;
    wire        decoded_single_error;
    wire        decoded_double_error;
    wire [6:0]  decoded_syndrome;

    assign req_ready = (state == ST_IDLE) && init_calib_complete && !ui_rst;

    secded_64_72_encoder u_ecc_encoder (
        .data_in      (req_wdata),
        .codeword_out (encoded_codeword)
    );

    // Fault injection occurs AFTER SECDED encoding and BEFORE the MIG write.
    // Bit 2 is the first payload bit (Hamming position 3); bits 2 and 4
    // are two payload bits. Thus the corrupted codeword is actually stored
    // in physical DDR and later returned through the MIG read channel.
    assign write_codeword_with_fault = encoded_codeword ^
        ((req_fault_mode == 2'b01) ? 72'h4  :
         (req_fault_mode == 2'b10) ? 72'h14 :
                                    72'b0);

    secded_64_72_decoder u_ecc_decoder (
        .codeword_in  (m_axi_rdata[71:0]),
        .data_out     (decoded_data),
        .single_error (decoded_single_error),
        .double_error (decoded_double_error),
        .syndrome     (decoded_syndrome)
    );

    always @(posedge ui_clk) begin
        if (ui_rst) begin
            state                <= ST_IDLE;
            rsp_valid            <= 1'b0;
            rsp_rdata            <= 64'b0;
            rsp_single_error    <= 1'b0;
            rsp_double_error    <= 1'b0;
            rsp_axi_error        <= 1'b0;

            m_axi_awid           <= {AXI_ID_WIDTH{1'b0}};
            m_axi_awaddr         <= {AXI_ADDR_WIDTH{1'b0}};
            m_axi_awlen          <= 8'd0;
            m_axi_awsize         <= 3'd4;       // 16 bytes per beat
            m_axi_awburst        <= 2'b01;      // INCR
            m_axi_awlock         <= 1'b0;
            m_axi_awcache        <= 4'b0000;
            m_axi_awprot         <= 3'b000;
            m_axi_awqos          <= 4'b0000;
            m_axi_awvalid        <= 1'b0;

            m_axi_wdata          <= 128'b0;
            m_axi_wstrb          <= 16'hffff;
            m_axi_wlast          <= 1'b1;
            m_axi_wvalid         <= 1'b0;
            m_axi_bready         <= 1'b0;

            m_axi_arid           <= {AXI_ID_WIDTH{1'b0}};
            m_axi_araddr         <= {AXI_ADDR_WIDTH{1'b0}};
            m_axi_arlen          <= 8'd0;
            m_axi_arsize         <= 3'd4;       // 16 bytes per beat
            m_axi_arburst        <= 2'b01;      // INCR
            m_axi_arlock         <= 1'b0;
            m_axi_arcache        <= 4'b0000;
            m_axi_arprot         <= 3'b000;
            m_axi_arqos          <= 4'b0000;
            m_axi_arvalid        <= 1'b0;
            m_axi_rready         <= 1'b0;
        end else begin
            case (state)
                ST_IDLE: begin
                    if (req_valid && req_ready) begin
                        rsp_rdata         <= 64'b0;
                        rsp_single_error <= 1'b0;
                        rsp_double_error <= 1'b0;
                        rsp_axi_error     <= 1'b0;
                        rsp_valid         <= 1'b0;

                        if (req_write) begin
                            m_axi_awid    <= {AXI_ID_WIDTH{1'b0}};
                            m_axi_awaddr  <= {req_word_addr, 4'b0000};
                            m_axi_awlen   <= 8'd0;
                            m_axi_awsize  <= 3'd4;
                            m_axi_awburst <= 2'b01;
                            m_axi_awlock  <= 1'b0;
                            m_axi_awcache <= 4'b0000;
                            m_axi_awprot  <= 3'b000;
                            m_axi_awqos   <= 4'b0000;
                            m_axi_awvalid <= 1'b1;

                            m_axi_wdata   <= {56'b0, write_codeword_with_fault};
                            m_axi_wstrb   <= 16'hffff;
                            m_axi_wlast   <= 1'b1;
                            m_axi_wvalid  <= 1'b1;
                            state         <= ST_WR_SEND;
                        end else begin
                            m_axi_arid    <= {AXI_ID_WIDTH{1'b0}};
                            m_axi_araddr  <= {req_word_addr, 4'b0000};
                            m_axi_arlen   <= 8'd0;
                            m_axi_arsize  <= 3'd4;
                            m_axi_arburst <= 2'b01;
                            m_axi_arlock  <= 1'b0;
                            m_axi_arcache <= 4'b0000;
                            m_axi_arprot  <= 3'b000;
                            m_axi_arqos   <= 4'b0000;
                            m_axi_arvalid <= 1'b1;
                            state         <= ST_RD_ADDR;
                        end
                    end
                end

                ST_WR_SEND: begin
                    // AXI AW and W channels are independent. Keep each VALID
                    // asserted until its own READY handshake occurs.
                    if (m_axi_awvalid && m_axi_awready)
                        m_axi_awvalid <= 1'b0;
                    if (m_axi_wvalid && m_axi_wready)
                        m_axi_wvalid <= 1'b0;

                    if ((!m_axi_awvalid || m_axi_awready) &&
                        (!m_axi_wvalid  || m_axi_wready)) begin
                        m_axi_bready <= 1'b1;
                        state        <= ST_WR_RESP;
                    end
                end

                ST_WR_RESP: begin
                    if (m_axi_bvalid && m_axi_bready) begin
                        m_axi_bready  <= 1'b0;
                        rsp_axi_error <= (m_axi_bresp != 2'b00);
                        rsp_valid     <= 1'b1;
                        state         <= ST_RESPONSE;
                    end
                end

                ST_RD_ADDR: begin
                    if (m_axi_arvalid && m_axi_arready) begin
                        m_axi_arvalid <= 1'b0;
                        m_axi_rready  <= 1'b1;
                        state         <= ST_RD_DATA;
                    end
                end

                ST_RD_DATA: begin
                    if (m_axi_rvalid && m_axi_rready) begin
                        m_axi_rready       <= 1'b0;
                        rsp_rdata          <= decoded_data;
                        rsp_single_error  <= decoded_single_error;
                        rsp_double_error  <= decoded_double_error;
                        rsp_axi_error      <= (m_axi_rresp != 2'b00) || !m_axi_rlast;
                        rsp_valid          <= 1'b1;
                        state              <= ST_RESPONSE;
                    end
                end

                ST_RESPONSE: begin
                    if (rsp_valid && rsp_ready) begin
                        rsp_valid <= 1'b0;
                        state     <= ST_IDLE;
                    end
                end

                default: begin
                    state <= ST_IDLE;
                end
            endcase
        end
    end

endmodule
