// SECDED ECC for 64-bit payloads.
// Codeword: 71-bit Hamming SEC part + 1 overall parity bit = 72 bits.
// Hamming parity positions (1-based): 1,2,4,8,16,32,64.
// Overall parity is codeword bit [71].

module ecc_secded_encode (
    input  [63:0] data_in,
    output reg [71:0] code_out
);
    integer pos;
    integer p;
    integer di;
    reg [70:0] hcode;
    reg parity;
    reg is_parity;

    always @* begin
        hcode = 71'b0;
        di = 0;

        // Place 64 payload bits in all non-power-of-two positions.
        for (pos = 1; pos <= 71; pos = pos + 1) begin
            is_parity = (pos == 1) || (pos == 2) || (pos == 4) ||
                        (pos == 8) || (pos == 16) || (pos == 32) ||
                        (pos == 64);
            if (!is_parity) begin
                hcode[pos-1] = data_in[di];
                di = di + 1;
            end
        end

        // Even Hamming parity.
        for (p = 1; p <= 64; p = p * 2) begin
            parity = 1'b0;
            for (pos = 1; pos <= 71; pos = pos + 1) begin
                if ((pos & p) != 0)
                    parity = parity ^ hcode[pos-1];
            end
            hcode[p-1] = parity;
        end

        code_out[70:0] = hcode;
        code_out[71] = ^hcode; // overall even parity
    end
endmodule


module ecc_secded_decode (
    input  [71:0] code_in,
    output reg [63:0] data_out,
    output reg        single_error,
    output reg        uncorrectable_error,
    output reg [6:0]  syndrome
);
    integer pos;
    integer p;
    integer di;
    reg [70:0] corrected;
    reg parity;
    reg overall;
    reg is_parity;

    always @* begin
        corrected = code_in[70:0];
        syndrome = 7'b0;

        // Calculate Hamming syndrome using even parity checks.
        for (p = 1; p <= 64; p = p * 2) begin
            parity = 1'b0;
            for (pos = 1; pos <= 71; pos = pos + 1) begin
                if ((pos & p) != 0)
                    parity = parity ^ code_in[pos-1];
            end
            case (p)
                1:  syndrome[0] = parity;
                2:  syndrome[1] = parity;
                4:  syndrome[2] = parity;
                8:  syndrome[3] = parity;
                16: syndrome[4] = parity;
                32: syndrome[5] = parity;
                64: syndrome[6] = parity;
                default: ;
            endcase
        end

        overall = ^code_in;
        single_error = 1'b0;
        uncorrectable_error = 1'b0;

        // SECDED decision table:
        // syndrome=0, overall=0 : clean
        // syndrome!=0, overall=1: single bit in Hamming portion -> correct
        // syndrome=0, overall=1 : error in overall parity bit -> no data correction
        // syndrome!=0, overall=0: double-bit error -> uncorrectable
        if (overall) begin
            single_error = 1'b1;
            if (syndrome != 0 && syndrome <= 71)
                corrected[syndrome-1] = ~corrected[syndrome-1];
        end else if (syndrome != 0) begin
            uncorrectable_error = 1'b1;
        end

        // Extract data bits from corrected Hamming word.
        data_out = 64'b0;
        di = 0;
        for (pos = 1; pos <= 71; pos = pos + 1) begin
            is_parity = (pos == 1) || (pos == 2) || (pos == 4) ||
                        (pos == 8) || (pos == 16) || (pos == 32) ||
                        (pos == 64);
            if (!is_parity) begin
                data_out[di] = corrected[pos-1];
                di = di + 1;
            end
        end

        // On an uncorrectable error the extracted data is intentionally left uncorrected.
        if (uncorrectable_error) begin
            data_out = 64'b0;
            di = 0;
            for (pos = 1; pos <= 71; pos = pos + 1) begin
                is_parity = (pos == 1) || (pos == 2) || (pos == 4) ||
                            (pos == 8) || (pos == 16) || (pos == 32) ||
                            (pos == 64);
                if (!is_parity) begin
                    data_out[di] = code_in[pos-1];
                    di = di + 1;
                end
            end
        end
    end
endmodule
