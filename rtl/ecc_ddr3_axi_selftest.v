`timescale 1ns/1ps

// One-outstanding, single-beat AXI4 master for the Arty A7 DDR3L SECDED demo.
// Writes and reads three 128-bit beats:
//   0x00: clean 72-bit codeword
//   0x10: codeword with bit 0 flipped before the DDR write
//   0x20: codeword with bits 0 and 1 flipped before the DDR write
//
// Read responses are deliberately split into capture, ECC-decode and
// ECC-check states. This creates register boundaries around the SECDED
// datapath and prevents the AXI response FIFO -> SECDED correction -> FSM
// comparison path from becoming one long controller-clock path.

module ecc_ddr3_axi_selftest #(
    parameter integer AXI_ADDR_WIDTH = 28,
    parameter integer AXI_DATA_WIDTH = 128,
    parameter integer AXI_ID_WIDTH   = 4,
    parameter [63:0] TEST_PAYLOAD     = 64'h0123_4567_89AB_CDEF,
    parameter [31:0] TIMEOUT_CYCLES   = 32'd100_000_000
) (
    input  wire                         clk,
    input  wire                         resetn,
    input  wire                         calib_complete,

    output wire [AXI_ID_WIDTH-1:0]      m_axi_awid,
    output reg  [AXI_ADDR_WIDTH-1:0]    m_axi_awaddr,
    output wire [7:0]                   m_axi_awlen,
    output wire [2:0]                   m_axi_awsize,
    output wire [1:0]                   m_axi_awburst,
    output wire [0:0]                   m_axi_awlock,
    output wire [3:0]                   m_axi_awcache,
    output wire [2:0]                   m_axi_awprot,
    output wire [3:0]                   m_axi_awqos,
    output wire                         m_axi_awvalid,
    input  wire                         m_axi_awready,

    output reg  [AXI_DATA_WIDTH-1:0]    m_axi_wdata,
    output wire [AXI_DATA_WIDTH/8-1:0]  m_axi_wstrb,
    output wire                         m_axi_wlast,
    output wire                         m_axi_wvalid,
    input  wire                         m_axi_wready,

    input  wire [AXI_ID_WIDTH-1:0]      m_axi_bid,
    input  wire [1:0]                   m_axi_bresp,
    input  wire                         m_axi_bvalid,
    output wire                         m_axi_bready,

    output wire [AXI_ID_WIDTH-1:0]      m_axi_arid,
    output reg  [AXI_ADDR_WIDTH-1:0]    m_axi_araddr,
    output wire [7:0]                   m_axi_arlen,
    output wire [2:0]                   m_axi_arsize,
    output wire [1:0]                   m_axi_arburst,
    output wire [0:0]                   m_axi_arlock,
    output wire [3:0]                   m_axi_arcache,
    output wire [2:0]                   m_axi_arprot,
    output wire [3:0]                   m_axi_arqos,
    output wire                         m_axi_arvalid,
    input  wire                         m_axi_arready,

    input  wire [AXI_ID_WIDTH-1:0]      m_axi_rid,
    input  wire [AXI_DATA_WIDTH-1:0]    m_axi_rdata,
    input  wire [1:0]                   m_axi_rresp,
    input  wire                         m_axi_rlast,
    input  wire                         m_axi_rvalid,
    output wire                         m_axi_rready,

    output reg                          test_done,
    output reg                          test_pass,
    output reg                          test_fail,
    output reg                          clean_read_ok,
    output reg                          single_corrected,
    output reg                          double_detected
);

    localparam [3:0] ST_WAIT_CAL   = 4'd0;
    localparam [3:0] ST_WRITE      = 4'd1;
    localparam [3:0] ST_WRITE_RSP  = 4'd2;
    localparam [3:0] ST_READ_ADDR  = 4'd3;
    localparam [3:0] ST_READ_DATA  = 4'd4;
    localparam [3:0] ST_ECC_DECODE = 4'd5;
    localparam [3:0] ST_ECC_CHECK  = 4'd6;
    localparam [3:0] ST_DONE       = 4'd7;
    localparam [3:0] ST_FAIL       = 4'd8;

    reg [3:0] state;
    reg [1:0] test_phase;
    reg aw_done;
    reg w_done;
    reg [31:0] timeout_count;

    wire [71:0] encoded_codeword;
    wire [63:0] decoded_payload;
    wire        decoded_single_error;
    wire        decoded_double_error;
    wire [6:0]  decoded_syndrome;

    // First pipeline boundary: capture the AXI response beat and metadata.
    reg [AXI_DATA_WIDTH-1:0] read_data_q;
    reg [AXI_ID_WIDTH-1:0]   read_id_q;
    reg [1:0]                read_resp_q;
    reg                      read_last_q;

    // Second pipeline boundary: capture SECDED decode results.
    reg [63:0] decoded_payload_q;
    reg        decoded_single_error_q;
    reg        decoded_double_error_q;

    wire read_metadata_ok;
    assign read_metadata_ok =
        (read_resp_q == 2'b00) &&
        read_last_q &&
        (read_id_q == {AXI_ID_WIDTH{1'b0}});

    secded_64_72_encoder u_ecc_encoder (
        .data_in(TEST_PAYLOAD),
        .codeword_out(encoded_codeword)
    );

    secded_64_72_decoder u_ecc_decoder (
        .codeword_in(read_data_q[71:0]),
        .data_out(decoded_payload),
        .single_error(decoded_single_error),
        .double_error(decoded_double_error),
        .syndrome(decoded_syndrome)
    );

    assign m_axi_awid    = {AXI_ID_WIDTH{1'b0}};
    assign m_axi_awlen   = 8'd0;
    assign m_axi_awsize  = 3'd4;       // 16 bytes per beat
    assign m_axi_awburst = 2'b01;      // INCR
    assign m_axi_awlock  = 1'b0;
    assign m_axi_awcache = 4'b0011;
    assign m_axi_awprot  = 3'b000;
    assign m_axi_awqos   = 4'b0000;
    assign m_axi_awvalid = (state == ST_WRITE) && !aw_done;

    assign m_axi_wstrb   = {AXI_DATA_WIDTH/8{1'b1}};
    assign m_axi_wlast   = 1'b1;
    assign m_axi_wvalid  = (state == ST_WRITE) && !w_done;
    assign m_axi_bready  = (state == ST_WRITE_RSP);

    assign m_axi_arid    = {AXI_ID_WIDTH{1'b0}};
    assign m_axi_arlen   = 8'd0;
    assign m_axi_arsize  = 3'd4;
    assign m_axi_arburst = 2'b01;
    assign m_axi_arlock  = 1'b0;
    assign m_axi_arcache = 4'b0011;
    assign m_axi_arprot  = 3'b000;
    assign m_axi_arqos   = 4'b0000;
    assign m_axi_arvalid = (state == ST_READ_ADDR);
    assign m_axi_rready  = (state == ST_READ_DATA);

    always @(posedge clk or negedge resetn) begin
        if (!resetn) begin
            state                    <= ST_WAIT_CAL;
            test_phase               <= 2'd0;
            aw_done                  <= 1'b0;
            w_done                   <= 1'b0;
            m_axi_awaddr             <= {AXI_ADDR_WIDTH{1'b0}};
            m_axi_araddr             <= {AXI_ADDR_WIDTH{1'b0}};
            m_axi_wdata              <= {AXI_DATA_WIDTH{1'b0}};
            timeout_count            <= 32'd0;
            read_data_q              <= {AXI_DATA_WIDTH{1'b0}};
            read_id_q                <= {AXI_ID_WIDTH{1'b0}};
            read_resp_q              <= 2'b00;
            read_last_q              <= 1'b0;
            decoded_payload_q        <= 64'd0;
            decoded_single_error_q   <= 1'b0;
            decoded_double_error_q   <= 1'b0;
            test_done                <= 1'b0;
            test_pass                <= 1'b0;
            test_fail                <= 1'b0;
            clean_read_ok            <= 1'b0;
            single_corrected         <= 1'b0;
            double_detected          <= 1'b0;
        end else if (!test_done && (timeout_count >= TIMEOUT_CYCLES)) begin
            test_fail <= 1'b1;
            test_done <= 1'b1;
            test_pass <= 1'b0;
            state     <= ST_FAIL;
        end else begin
            if (!test_done)
                timeout_count <= timeout_count + 1'b1;

            case (state)
                ST_WAIT_CAL: begin
                    if (calib_complete) begin
                        test_phase   <= 2'd0;
                        m_axi_awaddr <= {{(AXI_ADDR_WIDTH-8){1'b0}}, 8'h00};
                        m_axi_wdata  <= {{(AXI_DATA_WIDTH-72){1'b0}}, encoded_codeword};
                        aw_done      <= 1'b0;
                        w_done       <= 1'b0;
                        state        <= ST_WRITE;
                    end
                end

                ST_WRITE: begin
                    if (m_axi_awvalid && m_axi_awready)
                        aw_done <= 1'b1;
                    if (m_axi_wvalid && m_axi_wready)
                        w_done <= 1'b1;

                    if ((aw_done || (m_axi_awvalid && m_axi_awready)) &&
                        (w_done  || (m_axi_wvalid  && m_axi_wready)))
                        state <= ST_WRITE_RSP;
                end

                ST_WRITE_RSP: begin
                    if (m_axi_bvalid && m_axi_bready) begin
                        if ((m_axi_bresp != 2'b00) ||
                            (m_axi_bid != {AXI_ID_WIDTH{1'b0}}))
                            test_fail <= 1'b1;
                        m_axi_araddr <= m_axi_awaddr;
                        state <= ST_READ_ADDR;
                    end
                end

                ST_READ_ADDR: begin
                    if (m_axi_arvalid && m_axi_arready)
                        state <= ST_READ_DATA;
                end

                // Capture the bus response only. No ECC decode or comparison
                // is allowed in this state.
                ST_READ_DATA: begin
                    if (m_axi_rvalid && m_axi_rready) begin
                        read_data_q <= m_axi_rdata;
                        read_id_q   <= m_axi_rid;
                        read_resp_q <= m_axi_rresp;
                        read_last_q <= m_axi_rlast;
                        state       <= ST_ECC_DECODE;
                    end
                end

                // Decode the registered data beat and register the results.
                ST_ECC_DECODE: begin
                    decoded_payload_q      <= decoded_payload;
                    decoded_single_error_q <= decoded_single_error;
                    decoded_double_error_q <= decoded_double_error;
                    state                  <= ST_ECC_CHECK;
                end

                // Result comparison and state progression now use registered
                // decode outputs, cutting the read-FIFO-to-FSM critical path.
                ST_ECC_CHECK: begin
                    if (!read_metadata_ok)
                        test_fail <= 1'b1;

                    case (test_phase)
                        2'd0: begin
                            if (read_metadata_ok &&
                                (decoded_payload_q == TEST_PAYLOAD) &&
                                !decoded_single_error_q &&
                                !decoded_double_error_q)
                                clean_read_ok <= 1'b1;
                            else
                                test_fail <= 1'b1;

                            test_phase   <= 2'd1;
                            m_axi_awaddr <= {{(AXI_ADDR_WIDTH-8){1'b0}}, 8'h10};
                            m_axi_wdata  <= {{(AXI_DATA_WIDTH-72){1'b0}},
                                             (encoded_codeword ^ 72'h000000000000000001)};
                            aw_done      <= 1'b0;
                            w_done       <= 1'b0;
                            state        <= ST_WRITE;
                        end

                        2'd1: begin
                            if (read_metadata_ok &&
                                (decoded_payload_q == TEST_PAYLOAD) &&
                                decoded_single_error_q &&
                                !decoded_double_error_q)
                                single_corrected <= 1'b1;
                            else
                                test_fail <= 1'b1;

                            test_phase   <= 2'd2;
                            m_axi_awaddr <= {{(AXI_ADDR_WIDTH-8){1'b0}}, 8'h20};
                            m_axi_wdata  <= {{(AXI_DATA_WIDTH-72){1'b0}},
                                             (encoded_codeword ^ 72'h000000000000000003)};
                            aw_done      <= 1'b0;
                            w_done       <= 1'b0;
                            state        <= ST_WRITE;
                        end

                        2'd2: begin
                            if (read_metadata_ok &&
                                decoded_double_error_q &&
                                !decoded_single_error_q)
                                double_detected <= 1'b1;
                            else
                                test_fail <= 1'b1;

                            test_done <= 1'b1;
                            if (!test_fail &&
                                clean_read_ok &&
                                single_corrected &&
                                read_metadata_ok &&
                                decoded_double_error_q &&
                                !decoded_single_error_q) begin
                                test_pass <= 1'b1;
                                test_fail <= 1'b0;
                                state <= ST_DONE;
                            end else begin
                                test_pass <= 1'b0;
                                test_fail <= 1'b1;
                                state <= ST_FAIL;
                            end
                        end

                        default: begin
                            test_fail <= 1'b1;
                            test_done <= 1'b1;
                            test_pass <= 1'b0;
                            state <= ST_FAIL;
                        end
                    endcase
                end

                ST_DONE: begin
                    test_done <= 1'b1;
                end

                ST_FAIL: begin
                    test_done <= 1'b1;
                    test_pass <= 1'b0;
                end

                default: begin
                    test_fail <= 1'b1;
                    test_done <= 1'b1;
                    test_pass <= 1'b0;
                    state <= ST_FAIL;
                end
            endcase
        end
    end

endmodule
