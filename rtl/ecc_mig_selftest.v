`timescale 1ns/1ps

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

    input  wire                         rsp_valid,
    output wire                         rsp_ready,
    input  wire [63:0]                  rsp_rdata,
    input  wire                         rsp_single_error,
    input  wire                         rsp_double_error,
    input  wire                         rsp_axi_error,

    output reg                          test_done,
    output reg                          test_error
);

    localparam [2:0] ST_WAIT_CALIB = 3'd0;
    localparam [2:0] ST_WRITE_REQ  = 3'd1;
    localparam [2:0] ST_WRITE_WAIT = 3'd2;
    localparam [2:0] ST_READ_REQ   = 3'd3;
    localparam [2:0] ST_READ_WAIT  = 3'd4;
    localparam [2:0] ST_DONE       = 3'd5;

    reg [2:0] state;

    assign req_valid =
        (state == ST_WRITE_REQ) || (state == ST_READ_REQ);

    assign req_write = (state == ST_WRITE_REQ);

    // One 64-bit payload occupies one 16-byte AXI address slot.
    assign req_word_addr = {(AXI_ADDR_WIDTH-4){1'b0}};

    assign req_wdata = TEST_DATA;

    assign rsp_ready =
        (state == ST_WRITE_WAIT) || (state == ST_READ_WAIT);

    always @(posedge clk) begin
        if (rst) begin
            state     <= ST_WAIT_CALIB;
            test_done <= 1'b0;
            test_error <= 1'b0;
        end else begin
            case (state)

                ST_WAIT_CALIB: begin
                    if (init_calib_complete)
                        state <= ST_WRITE_REQ;
                end

                ST_WRITE_REQ: begin
                    if (req_valid && req_ready)
                        state <= ST_WRITE_WAIT;
                end

                ST_WRITE_WAIT: begin
                    if (rsp_valid && rsp_ready) begin
                        if (rsp_axi_error) begin
                            test_error <= 1'b1;
                            state <= ST_DONE;
                        end else begin
                            state <= ST_READ_REQ;
                        end
                    end
                end

                ST_READ_REQ: begin
                    if (req_valid && req_ready)
                        state <= ST_READ_WAIT;
                end

                ST_READ_WAIT: begin
                    if (rsp_valid && rsp_ready) begin
                        if (rsp_axi_error ||
                            rsp_single_error ||
                            rsp_double_error ||
                            (rsp_rdata != TEST_DATA)) begin
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
