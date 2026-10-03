// Simplified open-page DDR3-style memory controller for a DSD project.
//
// Purpose:
//   * Accept one user transaction at a time.
//   * Translate a flat byte address into row/bank/column fields.
//   * Generate ACT, READ, WRITE, PRECHARGE and REFRESH commands.
//   * Enforce simplified tRCD / tRP / CL / tRFC timing in controller clock cycles.
//   * Use SECDED ECC: 64-bit user payload -> 72-bit DRAM word.
//   * Keep bank/page state visible for GTKWave.
//
// This is a synthesizable controller abstraction, not an electrical DDR PHY.
// Real DDR3 uses DQS, double-data-rate capture/launch, initialization,
// write leveling/read leveling, and device-specific timing values.

module ddr_controller #(
    parameter ADDR_WIDTH       = 13,  // byte address; low 3 bits are ignored
    parameter ROW_WIDTH        = 4,
    parameter BANK_WIDTH       = 2,
    parameter COL_WIDTH        = 4,
    parameter TRCD             = 2,
    parameter TRP              = 2,
    parameter TCL              = 3,
    parameter TRFC             = 4,
    parameter REFRESH_INTERVAL = 40
)(
    input                  clk,
    input                  rst,

    // User-side transaction interface.
    input                  req_valid,
    input                  req_write,
    input  [ADDR_WIDTH-1:0] req_addr,
    input  [63:0]          req_wdata,
    output                 req_ready,

    // Read completion / transaction completion.
    output reg             resp_valid,
    output reg [63:0]      resp_rdata,
    output reg             ecc_single_error,
    output reg             ecc_multiple_error,
    output reg [6:0]       ecc_syndrome,
    output reg             done,

    // Abstract DDR command interface + realistic DDR3 command pins.
    output reg [2:0]       ddr_cmd,
    output reg             ddr_cs_n,
    output reg             ddr_ras_n,
    output reg             ddr_cas_n,
    output reg             ddr_we_n,
    output reg [BANK_WIDTH-1:0] ddr_ba,
    output reg [ROW_WIDTH-1:0]  ddr_addr,
    output reg [71:0]      ddr_dq_out,
    output reg             ddr_dq_oe,
    input      [71:0]      ddr_dq_in,

    output reg             busy,
    output [3:0]           dbg_state,
    output [BANK_WIDTH-1:0] dbg_active_bank,
    output [ROW_WIDTH-1:0]  dbg_open_row_bank0,
    output [ROW_WIDTH-1:0]  dbg_open_row_bank1,
    output [ROW_WIDTH-1:0]  dbg_open_row_bank2,
    output [ROW_WIDTH-1:0]  dbg_open_row_bank3,
    output                  dbg_refresh_pending
);

    localparam [2:0] CMD_ACT = 3'd0;
    localparam [2:0] CMD_RD  = 3'd1;
    localparam [2:0] CMD_WR  = 3'd2;
    localparam [2:0] CMD_PRE = 3'd3;
    localparam [2:0] CMD_REF = 3'd4;
    localparam [2:0] CMD_NOP = 3'd7;

    localparam [3:0] S_IDLE      = 4'd0;
    localparam [3:0] S_PRE       = 4'd1;
    localparam [3:0] S_WAIT_TRP  = 4'd2;
    localparam [3:0] S_ACT       = 4'd3;
    localparam [3:0] S_WAIT_TRCD = 4'd4;
    localparam [3:0] S_READ      = 4'd5;
    localparam [3:0] S_READ_WAIT = 4'd6;
    localparam [3:0] S_WRITE     = 4'd7;
    localparam [3:0] S_REF_SCAN  = 4'd8;
    localparam [3:0] S_REF_PRE   = 4'd9;
    localparam [3:0] S_REF_TRP   = 4'd10;
    localparam [3:0] S_REFRESH   = 4'd11;
    localparam [3:0] S_REF_WAIT  = 4'd12;

    reg [3:0] state;
    reg refresh_pending;
    assign dbg_state = state;
    assign req_ready = (state == S_IDLE) && !refresh_pending;
    assign dbg_refresh_pending = refresh_pending;

    reg [BANK_WIDTH-1:0] active_bank;
    reg [ROW_WIDTH-1:0]  active_row;
    reg [COL_WIDTH-1:0]  active_col;
    reg [63:0]           active_wdata;
    reg                  active_write;

    reg [BANK_WIDTH-1:0] target_bank;
    reg [ROW_WIDTH-1:0]  target_row;
    reg [COL_WIDTH-1:0]  target_col;

    reg [3:0] wait_count;
    reg [3:0] refresh_bank;
    reg [15:0] refresh_count;

    reg [3:0] bank_open;
    reg [ROW_WIDTH-1:0] open_row [0:3];

    wire [71:0] encoded_write_word;
    wire [63:0] decoded_read_data;
    wire        decoded_single_error;
    wire        decoded_uncorrectable;
    wire [6:0]  decoded_syndrome;

    ecc_secded_encode u_ecc_enc (
        .data_in(active_wdata),
        .code_out(encoded_write_word)
    );

    ecc_secded_decode u_ecc_dec (
        .code_in(ddr_dq_in),
        .data_out(decoded_read_data),
        .single_error(decoded_single_error),
        .uncorrectable_error(decoded_uncorrectable),
        .syndrome(decoded_syndrome)
    );

    assign dbg_active_bank = active_bank;
    assign dbg_open_row_bank0 = open_row[0];
    assign dbg_open_row_bank1 = open_row[1];
    assign dbg_open_row_bank2 = open_row[2];
    assign dbg_open_row_bank3 = open_row[3];

    // Translate the flat user address using a compact ROW/COLUMN/BANK map.
    // The low three address bits are the byte-in-burst offset and are ignored.
    wire [COL_WIDTH-1:0]  req_col_dec  = req_addr[3+COL_WIDTH-1:3];
    wire [BANK_WIDTH-1:0] req_bank_dec = req_addr[3+COL_WIDTH+BANK_WIDTH-1:3+COL_WIDTH];
    wire [ROW_WIDTH-1:0]  req_row_dec  = req_addr[ADDR_WIDTH-1:3+COL_WIDTH+BANK_WIDTH];

    // Command outputs are combinational, making the command and address easy to inspect.
    always @* begin
        ddr_cmd   = CMD_NOP;
        ddr_cs_n  = 1'b0;
        ddr_ras_n = 1'b1;
        ddr_cas_n = 1'b1;
        ddr_we_n  = 1'b1;
        ddr_ba    = active_bank;
        ddr_addr  = active_row;
        ddr_dq_out = encoded_write_word;
        ddr_dq_oe = 1'b0;

        case (state)
            S_ACT: begin
                ddr_cmd   = CMD_ACT;
                ddr_ras_n = 1'b0;
                ddr_cas_n = 1'b1;
                ddr_we_n  = 1'b1;
                ddr_ba    = target_bank;
                ddr_addr  = target_row;
            end
            S_READ: begin
                ddr_cmd   = CMD_RD;
                ddr_ras_n = 1'b1;
                ddr_cas_n = 1'b0;
                ddr_we_n  = 1'b1;
                ddr_ba    = target_bank;
                ddr_addr  = active_col;
            end
            S_WRITE: begin
                ddr_cmd   = CMD_WR;
                ddr_ras_n = 1'b1;
                ddr_cas_n = 1'b0;
                ddr_we_n  = 1'b0;
                ddr_ba    = target_bank;
                ddr_addr  = active_col;
                ddr_dq_oe = 1'b1;
            end
            S_PRE,
            S_REF_PRE: begin
                ddr_cmd   = CMD_PRE;
                ddr_ras_n = 1'b1;
                ddr_cas_n = 1'b1;
                ddr_we_n  = 1'b0;
                ddr_ba    = active_bank;
                ddr_addr  = {ROW_WIDTH{1'b0}};
            end
            S_REFRESH: begin
                ddr_cmd   = CMD_REF;
                ddr_ras_n = 1'b0;
                ddr_cas_n = 1'b0;
                ddr_we_n  = 1'b1;
                ddr_ba    = {BANK_WIDTH{1'b0}};
                ddr_addr  = {ROW_WIDTH{1'b0}};
            end
            default: begin end
        endcase
    end

    // Main FSM and timing bookkeeping.
    integer b;
    always @(posedge clk) begin
        if (rst) begin
            state              <= S_IDLE;
            active_bank        <= 2'b00;
            active_row         <= 4'b0000;
            active_col         <= 4'b0000;
            active_wdata       <= 64'b0;
            active_write       <= 1'b0;
            wait_count         <= 4'd0;
            refresh_bank       <= 4'd0;
            refresh_count      <= 16'd0;
            refresh_pending    <= 1'b0;
            bank_open          <= 4'b0000;
            for (b = 0; b < 4; b = b + 1)
                open_row[b] <= 4'b0;
            resp_valid         <= 1'b0;
            resp_rdata         <= 64'b0;
            ecc_single_error   <= 1'b0;
            ecc_multiple_error <= 1'b0;
            ecc_syndrome       <= 7'b0;
            done               <= 1'b0;
            busy               <= 1'b0;
        end else begin
            resp_valid         <= 1'b0;
            ecc_single_error   <= 1'b0;
            ecc_multiple_error <= 1'b0;
            done               <= 1'b0;

            // Refresh deadline is converted into a pending flag so that an
            // in-flight transaction can complete before maintenance starts.
            if (!refresh_pending) begin
                if (refresh_count >= REFRESH_INTERVAL-1) begin
                    refresh_count   <= 16'd0;
                    refresh_pending <= 1'b1;
                end else begin
                    refresh_count <= refresh_count + 1'b1;
                end
            end

            case (state)
                S_IDLE: begin
                    busy <= 1'b0;
                    if (refresh_pending) begin
                        refresh_bank <= 0;
                        state <= S_REF_SCAN;
                        busy <= 1'b1;
                    end else if (req_valid && req_ready) begin
                        target_bank  <= req_bank_dec;
                        target_row   <= req_row_dec;
                        target_col   <= req_col_dec;
                        active_bank  <= req_bank_dec;
                        active_row   <= req_row_dec;
                        active_col   <= req_col_dec;
                        active_wdata <= req_wdata;
                        active_write <= req_write;
                        busy         <= 1'b1;

                        if (bank_open[req_bank_dec] && (open_row[req_bank_dec] == req_row_dec))
                            state <= req_write ? S_WRITE : S_READ;
                        else if (bank_open[req_bank_dec])
                            state <= S_PRE;
                        else
                            state <= S_ACT;
                    end
                end

                S_PRE: begin
                    bank_open[active_bank] <= 1'b0;
                    wait_count <= 0;
                    state <= S_WAIT_TRP;
                end

                S_WAIT_TRP: begin
                    if (wait_count >= TRP-1) begin
                        state <= S_ACT;
                        wait_count <= 0;
                    end else
                        wait_count <= wait_count + 1'b1;
                end

                S_ACT: begin
                    bank_open[target_bank] <= 1'b1;
                    open_row[target_bank]  <= target_row;
                    wait_count <= 0;
                    state <= S_WAIT_TRCD;
                end

                S_WAIT_TRCD: begin
                    if (wait_count >= TRCD-1) begin
                        state <= active_write ? S_WRITE : S_READ;
                        wait_count <= 0;
                    end else
                        wait_count <= wait_count + 1'b1;
                end

                S_READ: begin
                    wait_count <= 0;
                    state <= S_READ_WAIT;
                end

                S_READ_WAIT: begin
                    if (wait_count >= TCL) begin
                        resp_rdata         <= decoded_read_data;
                        resp_valid         <= 1'b1;
                        ecc_single_error   <= decoded_single_error;
                        ecc_multiple_error <= decoded_uncorrectable;
                        ecc_syndrome       <= decoded_syndrome;
                        done               <= 1'b1;
                        state              <= S_IDLE;
                        busy               <= 1'b0;
                    end else
                        wait_count <= wait_count + 1'b1;
                end

                S_WRITE: begin
                    // DRAM model captures encoded_write_word during this command.
                    done  <= 1'b1;
                    state <= S_IDLE;
                    busy  <= 1'b0;
                end

                S_REF_SCAN: begin
                    if (refresh_bank >= 4) begin
                        state <= S_REFRESH;
                    end else if (bank_open[refresh_bank]) begin
                        active_bank <= refresh_bank[BANK_WIDTH-1:0];
                        state <= S_REF_PRE;
                    end else begin
                        refresh_bank <= refresh_bank + 1'b1;
                    end
                end

                S_REF_PRE: begin
                    bank_open[active_bank] <= 1'b0;
                    wait_count <= 0;
                    state <= S_REF_TRP;
                end

                S_REF_TRP: begin
                    if (wait_count >= TRP-1) begin
                        refresh_bank <= refresh_bank + 1'b1;
                        state <= S_REF_SCAN;
                        wait_count <= 0;
                    end else
                        wait_count <= wait_count + 1'b1;
                end

                S_REFRESH: begin
                    refresh_pending <= 1'b0;
                    wait_count <= 0;
                    state <= S_REF_WAIT;
                end

                S_REF_WAIT: begin
                    if (wait_count >= TRFC-1) begin
                        state <= S_IDLE;
                        busy <= 1'b0;
                    end else
                        wait_count <= wait_count + 1'b1;
                end

                default: state <= S_IDLE;
            endcase
        end
    end
endmodule
