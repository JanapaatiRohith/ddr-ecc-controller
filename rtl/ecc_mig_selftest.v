`timescale 1ns/1ps

// Physical DDR3L + SECDED diagnostic sequence.
// After MIG calibration this controller performs three write/read tests:
//   1) Clean write/read: returned payload must match with no ECC flags.
//   2) Single-bit test: master flips one payload-codeword bit BEFORE the MIG write;
//      the corrupted codeword is stored in DDR and must be corrected after read.
//   3) Double-bit test: master flips two payload-codeword bits BEFORE the MIG write;
//      the stored codeword must be flagged as uncorrectable after read.
//
// req_fault_mode: 00=clean write, 01=inject one codeword-bit error on write,
//                 10=inject two codeword-bit errors on write.
// Reads always use mode 00 so the fault must travel through physical DDR.
module ecc_mig_selftest #(
    parameter AXI_ADDR_WIDTH = 28,
    parameter [63:0] TEST_DATA = 64'hD3C5_7A91_6E2B_40F8
) (
    input  wire                         clk,
    input  wire                         rst,
    input  wire                         init_calib_complete,

    output wire                         req_valid,
    input  wire                         req_ready,
    output wire                         req_write,
    output wire [AXI_ADDR_WIDTH-5:0]    req_word_addr,
    output wire [63:0]                  req_wdata,
    output wire [1:0]                   req_fault_mode,

    input  wire                         rsp_valid,
    output wire                         rsp_ready,
    input  wire [63:0]                  rsp_rdata,
    input  wire                         rsp_single_error,
    input  wire                         rsp_double_error,
    input  wire                         rsp_axi_error,

    output reg                          test_done,
    output reg                          test_error
);

    localparam [3:0] ST_WAIT_CALIB       = 4'd0;
    localparam [3:0] ST_CLEAN_WR_REQ     = 4'd1;
    localparam [3:0] ST_CLEAN_WR_WAIT    = 4'd2;
    localparam [3:0] ST_CLEAN_RD_REQ     = 4'd3;
    localparam [3:0] ST_CLEAN_RD_WAIT    = 4'd4;
    localparam [3:0] ST_SINGLE_WR_REQ    = 4'd5;
    localparam [3:0] ST_SINGLE_WR_WAIT   = 4'd6;
    localparam [3:0] ST_SINGLE_RD_REQ    = 4'd7;
    localparam [3:0] ST_SINGLE_RD_WAIT   = 4'd8;
    localparam [3:0] ST_DOUBLE_WR_REQ    = 4'd9;
    localparam [3:0] ST_DOUBLE_WR_WAIT   = 4'd10;
    localparam [3:0] ST_DOUBLE_RD_REQ    = 4'd11;
    localparam [3:0] ST_DOUBLE_RD_WAIT   = 4'd12;
    localparam [3:0] ST_DONE             = 4'd13;

    reg [3:0] state;

    assign req_valid =
        (state == ST_CLEAN_WR_REQ)  ||
        (state == ST_CLEAN_RD_REQ)  ||
        (state == ST_SINGLE_WR_REQ) ||
        (state == ST_SINGLE_RD_REQ) ||
        (state == ST_DOUBLE_WR_REQ) ||
        (state == ST_DOUBLE_RD_REQ);

    assign req_write =
        (state == ST_CLEAN_WR_REQ)  ||
        (state == ST_SINGLE_WR_REQ) ||
        (state == ST_DOUBLE_WR_REQ);

    // Single/double faults are injected only on the corresponding write.
    // The master captures this mode when it accepts the request.
    assign req_fault_mode =
        (state == ST_SINGLE_WR_REQ) ? 2'b01 :
        (state == ST_DOUBLE_WR_REQ) ? 2'b10 : 2'b00;

    // One 64-bit payload occupies one 16-byte AXI address slot.
    // All three phases deliberately reuse byte address zero.
    assign req_word_addr = {(AXI_ADDR_WIDTH-4){1'b0}};
    assign req_wdata = TEST_DATA;

    assign rsp_ready =
        (state == ST_CLEAN_WR_WAIT)  ||
        (state == ST_CLEAN_RD_WAIT)  ||
        (state == ST_SINGLE_WR_WAIT) ||
        (state == ST_SINGLE_RD_WAIT) ||
        (state == ST_DOUBLE_WR_WAIT) ||
        (state == ST_DOUBLE_RD_WAIT);

    always @(posedge clk) begin
        if (rst) begin
            state      <= ST_WAIT_CALIB;
            test_done  <= 1'b0;
            test_error <= 1'b0;
        end else begin
            case (state)
                ST_WAIT_CALIB: begin
                    if (init_calib_complete)
                        state <= ST_CLEAN_WR_REQ;
                end

                ST_CLEAN_WR_REQ: begin
                    if (req_valid && req_ready)
                        state <= ST_CLEAN_WR_WAIT;
                end
                ST_CLEAN_WR_WAIT: begin
                    if (rsp_valid && rsp_ready) begin
                        if (rsp_axi_error) begin
                            test_error <= 1'b1;
                            state <= ST_DONE;
                        end else begin
                            state <= ST_CLEAN_RD_REQ;
                        end
                    end
                end
                ST_CLEAN_RD_REQ: begin
                    if (req_valid && req_ready)
                        state <= ST_CLEAN_RD_WAIT;
                end
                ST_CLEAN_RD_WAIT: begin
                    if (rsp_valid && rsp_ready) begin
                        if (rsp_axi_error || rsp_single_error || rsp_double_error ||
                            (rsp_rdata != TEST_DATA)) begin
                            test_error <= 1'b1;
                            state <= ST_DONE;
                        end else begin
                            state <= ST_SINGLE_WR_REQ;
                        end
                    end
                end

                ST_SINGLE_WR_REQ: begin
                    if (req_valid && req_ready)
                        state <= ST_SINGLE_WR_WAIT;
                end
                ST_SINGLE_WR_WAIT: begin
                    if (rsp_valid && rsp_ready) begin
                        if (rsp_axi_error) begin
                            test_error <= 1'b1;
                            state <= ST_DONE;
                        end else begin
                            state <= ST_SINGLE_RD_REQ;
                        end
                    end
                end
                ST_SINGLE_RD_REQ: begin
                    if (req_valid && req_ready)
                        state <= ST_SINGLE_RD_WAIT;
                end
                ST_SINGLE_RD_WAIT: begin
                    if (rsp_valid && rsp_ready) begin
                        // Must correct the stored single-bit corruption and
                        // reproduce the exact original 64-bit payload.
                        if (rsp_axi_error || !rsp_single_error || rsp_double_error ||
                            (rsp_rdata != TEST_DATA)) begin
                            test_error <= 1'b1;
                            state <= ST_DONE;
                        end else begin
                            state <= ST_DOUBLE_WR_REQ;
                        end
                    end
                end

                ST_DOUBLE_WR_REQ: begin
                    if (req_valid && req_ready)
                        state <= ST_DOUBLE_WR_WAIT;
                end
                ST_DOUBLE_WR_WAIT: begin
                    if (rsp_valid && rsp_ready) begin
                        if (rsp_axi_error) begin
                            test_error <= 1'b1;
                            state <= ST_DONE;
                        end else begin
                            state <= ST_DOUBLE_RD_REQ;
                        end
                    end
                end
                ST_DOUBLE_RD_REQ: begin
                    if (req_valid && req_ready)
                        state <= ST_DOUBLE_RD_WAIT;
                end
                ST_DOUBLE_RD_WAIT: begin
                    if (rsp_valid && rsp_ready) begin
                        // Must detect two errors and must not claim recovery.
                        if (rsp_axi_error || rsp_single_error || !rsp_double_error ||
                            (rsp_rdata == TEST_DATA)) begin
                            test_error <= 1'b1;
                        end else begin
                            test_done <= 1'b1;
                        end
                        state <= ST_DONE;
                    end
                end

                ST_DONE: begin
                    state <= ST_DONE;
                end

                default: begin
                    test_error <= 1'b1;
                    state <= ST_DONE;
                end
            endcase
        end
    end
endmodule
