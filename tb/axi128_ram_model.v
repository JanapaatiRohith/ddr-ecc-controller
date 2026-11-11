`timescale 1ns/1ps

// Small behavioral AXI4 single-beat memory model for bridge verification.
// AW and W are accepted independently and may be stalled independently.
module axi128_ram_model #(
    parameter AXI_ADDR_WIDTH = 28,
    parameter AXI_ID_WIDTH   = 4
) (
    input  wire                     clk,
    input  wire                     rst,

    input  wire [AXI_ID_WIDTH-1:0]  awid,
    input  wire [AXI_ADDR_WIDTH-1:0] awaddr,
    input  wire [7:0]               awlen,
    input  wire [2:0]               awsize,
    input  wire [1:0]               awburst,
    input  wire                    awvalid,
    output wire                    awready,

    input  wire [127:0]             wdata,
    input  wire [15:0]              wstrb,
    input  wire                    wlast,
    input  wire                    wvalid,
    output wire                    wready,

    output reg  [AXI_ID_WIDTH-1:0]  bid,
    output reg  [1:0]               bresp,
    output reg                     bvalid,
    input  wire                    bready,

    input  wire [AXI_ID_WIDTH-1:0]  arid,
    input  wire [AXI_ADDR_WIDTH-1:0] araddr,
    input  wire [7:0]               arlen,
    input  wire [2:0]               arsize,
    input  wire [1:0]               arburst,
    input  wire                    arvalid,
    output wire                    arready,

    output reg  [AXI_ID_WIDTH-1:0]  rid,
    output reg  [127:0]             rdata,
    output reg  [1:0]               rresp,
    output reg                     rlast,
    output reg                     rvalid,
    input  wire                    rready,

    output reg                     protocol_error
);

    reg [127:0] mem [0:15];
    reg [2:0] ready_count;
    reg aw_seen, w_seen;
    reg [AXI_ADDR_WIDTH-1:0] awaddr_hold;
    reg [127:0] wdata_hold;
    reg [15:0] wstrb_hold;
    reg rd_pending;
    reg [1:0] rd_delay;
    reg [AXI_ADDR_WIDTH-1:0] rdaddr_hold;
    integer i;

    assign awready = ready_count[0] | ready_count[2];
    assign wready  = ready_count[1] | ready_count[2];
    assign arready = ready_count[0];

    always @(posedge clk) begin
        if (rst) begin
            ready_count   <= 3'd0;
            aw_seen       <= 1'b0;
            w_seen        <= 1'b0;
            awaddr_hold   <= {AXI_ADDR_WIDTH{1'b0}};
            wdata_hold    <= 128'b0;
            wstrb_hold    <= 16'b0;
            bid           <= {AXI_ID_WIDTH{1'b0}};
            bresp         <= 2'b00;
            bvalid        <= 1'b0;
            rid           <= {AXI_ID_WIDTH{1'b0}};
            rdata         <= 128'b0;
            rresp         <= 2'b00;
            rlast         <= 1'b0;
            rvalid        <= 1'b0;
            rd_pending    <= 1'b0;
            rd_delay      <= 2'd0;
            rdaddr_hold   <= {AXI_ADDR_WIDTH{1'b0}};
            protocol_error <= 1'b0;
            for (i = 0; i < 16; i = i + 1)
                mem[i] <= 128'b0;
        end else begin
            ready_count <= ready_count + 1'b1;

            if (awvalid && awready) begin
                if ((awlen != 8'd0) || (awsize != 3'd4) ||
                    (awburst != 2'b01) || (awaddr[3:0] != 4'b0000))
                    protocol_error <= 1'b1;
                aw_seen     <= 1'b1;
                awaddr_hold <= awaddr;
                bid         <= awid;
            end

            if (wvalid && wready) begin
                if (!wlast || (wstrb != 16'hffff))
                    protocol_error <= 1'b1;
                w_seen     <= 1'b1;
                wdata_hold <= wdata;
                wstrb_hold <= wstrb;
            end

            // Commit only after both independent write channels were accepted.
            if (aw_seen && w_seen && !bvalid) begin
                for (i = 0; i < 16; i = i + 1) begin
                    if (wstrb_hold[i])
                        mem[awaddr_hold[7:4]][i*8 +: 8] <= wdata_hold[i*8 +: 8];
                end
                aw_seen <= 1'b0;
                w_seen  <= 1'b0;
                bresp   <= 2'b00;
                bvalid  <= 1'b1;
            end

            if (bvalid && bready)
                bvalid <= 1'b0;

            if (arvalid && arready) begin
                if ((arlen != 8'd0) || (arsize != 3'd4) ||
                    (arburst != 2'b01) || (araddr[3:0] != 4'b0000))
                    protocol_error <= 1'b1;
                rd_pending  <= 1'b1;
                rd_delay    <= 2'd2;
                rdaddr_hold <= araddr;
                rid         <= arid;
            end

            if (rd_pending && !rvalid) begin
                if (rd_delay != 0) begin
                    rd_delay <= rd_delay - 1'b1;
                end else begin
                    rdata      <= mem[rdaddr_hold[7:4]];
                    rresp      <= 2'b00;
                    rlast      <= 1'b1;
                    rvalid     <= 1'b1;
                    rd_pending <= 1'b0;
                end
            end

            if (rvalid && rready) begin
                rvalid <= 1'b0;
                rlast  <= 1'b0;
            end
        end
    end

endmodule
