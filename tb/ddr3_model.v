// Behavioral DDR3-like memory model for simulation.
// It accepts the simplified command interface from ddr_controller and stores
// 72-bit ECC codewords. This model is intentionally small so simulations run fast.

module ddr3_model #(
    parameter ROWS = 16,
    parameter BANKS = 4,
    parameter COLS = 16,
    parameter READ_LATENCY = 3
)(
    input                  clk,
    input                  rst,
    input      [2:0]       ddr_cmd,
    input      [1:0]       ddr_ba,
    input      [3:0]       ddr_addr,
    input      [71:0]      ddr_dq_out,
    input                  ddr_dq_oe,
    output reg [71:0]      ddr_dq_in,

    // Simulation-only fault injection. The mask is XORed into the next READ.
    input                  fault_enable,
    input      [71:0]      fault_mask
);
    localparam [2:0] CMD_ACT = 3'd0;
    localparam [2:0] CMD_RD  = 3'd1;
    localparam [2:0] CMD_WR  = 3'd2;
    localparam [2:0] CMD_PRE = 3'd3;
    localparam [2:0] CMD_REF = 3'd4;

    reg [71:0] mem [0:BANKS*ROWS*COLS-1];
    reg [BANKS-1:0] open_bank;
    reg [3:0] open_row [0:BANKS-1];

    reg [3:0] read_count;
    reg [71:0] pending_read;
    reg        dq_valid;

    integer i;
    integer idx;

    always @(posedge clk) begin
        if (rst) begin
            ddr_dq_in <= 72'b0;
            read_count <= 0;
            pending_read <= 0;
            dq_valid <= 1'b0;
            open_bank <= 0;
            for (i = 0; i < BANKS; i = i + 1)
                open_row[i] <= 0;
            for (i = 0; i < BANKS*ROWS*COLS; i = i + 1)
                mem[i] <= 72'b0;
        end else begin
            dq_valid <= 1'b0;

            // Read return pipeline.
            if (read_count != 0) begin
                if (read_count == 1) begin
                    ddr_dq_in <= pending_read;
                    dq_valid <= 1'b1;
                    read_count <= 0;
                end else begin
                    read_count <= read_count - 1'b1;
                end
            end

            case (ddr_cmd)
                CMD_ACT: begin
                    if (open_bank[ddr_ba]) begin
                        $display("ERROR: ACT while bank %0d is already open at t=%0t", ddr_ba, $time);
                    end
                    open_bank[ddr_ba] <= 1'b1;
                    open_row[ddr_ba] <= ddr_addr;
                end

                CMD_PRE: begin
                    open_bank[ddr_ba] <= 1'b0;
                end

                CMD_WR: begin
                    if (!ddr_dq_oe) begin
                        $display("ERROR: WRITE command without DQ output enable at t=%0t", $time);
                    end
                    if (!open_bank[ddr_ba]) begin
                        $display("ERROR: WRITE to closed bank %0d at t=%0t", ddr_ba, $time);
                    end
                    if (ddr_addr >= COLS) begin
                        $display("ERROR: column out of range at t=%0t", $time);
                    end
                    idx = ddr_ba*ROWS*COLS + open_row[ddr_ba]*COLS + ddr_addr;
                    mem[idx] <= ddr_dq_out;
                end

                CMD_RD: begin
                    if (!open_bank[ddr_ba]) begin
                        $display("ERROR: READ from closed bank %0d at t=%0t", ddr_ba, $time);
                    end
                    if (ddr_addr >= COLS) begin
                        $display("ERROR: column out of range at t=%0t", $time);
                    end
                    idx = ddr_ba*ROWS*COLS + open_row[ddr_ba]*COLS + ddr_addr;
                    pending_read <= mem[idx] ^ (fault_enable ? fault_mask : 72'b0);
                    read_count <= READ_LATENCY;
                end

                CMD_REF: begin
                    if (|open_bank) begin
                        $display("ERROR: REFRESH issued while a bank remains open at t=%0t", $time);
                    end
                end

                default: ;
            endcase
        end
    end
endmodule
