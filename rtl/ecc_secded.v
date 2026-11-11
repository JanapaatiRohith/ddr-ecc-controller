`timescale 1ns/1ps

// SECDED (72,64): 64 payload bits, 7 Hamming parity bits,
// and one overall even-parity bit. Bit mapping follows positions 1..71;
// the overall parity bit is codeword_in[71].

module secded_64_72_encoder (
    input  wire [63:0] data_in,
    output reg  [71:0] codeword_out
);
    integer pos;
    integer data_idx;
    integer p;
    reg parity_bit;

    always @* begin
        codeword_out = 72'b0;
        data_idx = 0;

        for (pos = 1; pos <= 71; pos = pos + 1) begin
            if ((pos != 1) && (pos != 2) && (pos != 4) &&
                (pos != 8) && (pos != 16) && (pos != 32) &&
                (pos != 64)) begin
                codeword_out[pos-1] = data_in[data_idx];
                data_idx = data_idx + 1;
            end
        end

        for (p = 0; p < 7; p = p + 1) begin
            parity_bit = 1'b0;
            for (pos = 1; pos <= 71; pos = pos + 1) begin
                if ((pos & (1 << p)) != 0)
                    parity_bit = parity_bit ^ codeword_out[pos-1];
            end
            codeword_out[(1 << p)-1] = parity_bit;
        end

        codeword_out[71] = ^codeword_out[70:0];
    end
endmodule


// Timing-oriented SECDED decoder.
//
// The previous decoder performed:
//   corrected_codeword[syndrome-1] = ~corrected_codeword[syndrome-1];
//
// That variable bit-select write synthesized into a wide dynamic mux,
// subtractor/carry path and a large correction network. This implementation
// uses constant syndrome comparisons for each payload bit. The codeword
// format and public module interface are unchanged.
module secded_64_72_decoder (
    input  wire [71:0] codeword_in,
    output wire [63:0] data_out,
    output wire        single_error,
    output wire        double_error,
    output wire [6:0]  syndrome
);
    assign syndrome[0] = ^(codeword_in[70:0] & 71'h555555555555555555);
    assign syndrome[1] = ^(codeword_in[70:0] & 71'h666666666666666666);
    assign syndrome[2] = ^(codeword_in[70:0] & 71'h787878787878787878);
    assign syndrome[3] = ^(codeword_in[70:0] & 71'h007F807F807F807F80);
    assign syndrome[4] = ^(codeword_in[70:0] & 71'h007FFF80007FFF8000);
    assign syndrome[5] = ^(codeword_in[70:0] & 71'h007FFFFFFF80000000);
    assign syndrome[6] = ^(codeword_in[70:0] & 71'h7F8000000000000000);

    wire overall_parity;
    assign overall_parity = ^codeword_in;

    // Preserve the original status convention: odd overall parity indicates
    // a single-bit error; non-zero syndrome plus even overall parity detects
    // a double-bit error. Correction is applied only to a matching data-bit
    // position. Hamming-parity-bit and overall-parity-bit errors leave the
    // recovered payload unchanged.
    assign single_error = overall_parity;
    assign double_error = (|syndrome) && !overall_parity;

    assign data_out[0] = codeword_in[2] ^ (overall_parity && (syndrome == 7'd3));
    assign data_out[1] = codeword_in[4] ^ (overall_parity && (syndrome == 7'd5));
    assign data_out[2] = codeword_in[5] ^ (overall_parity && (syndrome == 7'd6));
    assign data_out[3] = codeword_in[6] ^ (overall_parity && (syndrome == 7'd7));
    assign data_out[4] = codeword_in[8] ^ (overall_parity && (syndrome == 7'd9));
    assign data_out[5] = codeword_in[9] ^ (overall_parity && (syndrome == 7'd10));
    assign data_out[6] = codeword_in[10] ^ (overall_parity && (syndrome == 7'd11));
    assign data_out[7] = codeword_in[11] ^ (overall_parity && (syndrome == 7'd12));
    assign data_out[8] = codeword_in[12] ^ (overall_parity && (syndrome == 7'd13));
    assign data_out[9] = codeword_in[13] ^ (overall_parity && (syndrome == 7'd14));
    assign data_out[10] = codeword_in[14] ^ (overall_parity && (syndrome == 7'd15));
    assign data_out[11] = codeword_in[16] ^ (overall_parity && (syndrome == 7'd17));
    assign data_out[12] = codeword_in[17] ^ (overall_parity && (syndrome == 7'd18));
    assign data_out[13] = codeword_in[18] ^ (overall_parity && (syndrome == 7'd19));
    assign data_out[14] = codeword_in[19] ^ (overall_parity && (syndrome == 7'd20));
    assign data_out[15] = codeword_in[20] ^ (overall_parity && (syndrome == 7'd21));
    assign data_out[16] = codeword_in[21] ^ (overall_parity && (syndrome == 7'd22));
    assign data_out[17] = codeword_in[22] ^ (overall_parity && (syndrome == 7'd23));
    assign data_out[18] = codeword_in[23] ^ (overall_parity && (syndrome == 7'd24));
    assign data_out[19] = codeword_in[24] ^ (overall_parity && (syndrome == 7'd25));
    assign data_out[20] = codeword_in[25] ^ (overall_parity && (syndrome == 7'd26));
    assign data_out[21] = codeword_in[26] ^ (overall_parity && (syndrome == 7'd27));
    assign data_out[22] = codeword_in[27] ^ (overall_parity && (syndrome == 7'd28));
    assign data_out[23] = codeword_in[28] ^ (overall_parity && (syndrome == 7'd29));
    assign data_out[24] = codeword_in[29] ^ (overall_parity && (syndrome == 7'd30));
    assign data_out[25] = codeword_in[30] ^ (overall_parity && (syndrome == 7'd31));
    assign data_out[26] = codeword_in[32] ^ (overall_parity && (syndrome == 7'd33));
    assign data_out[27] = codeword_in[33] ^ (overall_parity && (syndrome == 7'd34));
    assign data_out[28] = codeword_in[34] ^ (overall_parity && (syndrome == 7'd35));
    assign data_out[29] = codeword_in[35] ^ (overall_parity && (syndrome == 7'd36));
    assign data_out[30] = codeword_in[36] ^ (overall_parity && (syndrome == 7'd37));
    assign data_out[31] = codeword_in[37] ^ (overall_parity && (syndrome == 7'd38));
    assign data_out[32] = codeword_in[38] ^ (overall_parity && (syndrome == 7'd39));
    assign data_out[33] = codeword_in[39] ^ (overall_parity && (syndrome == 7'd40));
    assign data_out[34] = codeword_in[40] ^ (overall_parity && (syndrome == 7'd41));
    assign data_out[35] = codeword_in[41] ^ (overall_parity && (syndrome == 7'd42));
    assign data_out[36] = codeword_in[42] ^ (overall_parity && (syndrome == 7'd43));
    assign data_out[37] = codeword_in[43] ^ (overall_parity && (syndrome == 7'd44));
    assign data_out[38] = codeword_in[44] ^ (overall_parity && (syndrome == 7'd45));
    assign data_out[39] = codeword_in[45] ^ (overall_parity && (syndrome == 7'd46));
    assign data_out[40] = codeword_in[46] ^ (overall_parity && (syndrome == 7'd47));
    assign data_out[41] = codeword_in[47] ^ (overall_parity && (syndrome == 7'd48));
    assign data_out[42] = codeword_in[48] ^ (overall_parity && (syndrome == 7'd49));
    assign data_out[43] = codeword_in[49] ^ (overall_parity && (syndrome == 7'd50));
    assign data_out[44] = codeword_in[50] ^ (overall_parity && (syndrome == 7'd51));
    assign data_out[45] = codeword_in[51] ^ (overall_parity && (syndrome == 7'd52));
    assign data_out[46] = codeword_in[52] ^ (overall_parity && (syndrome == 7'd53));
    assign data_out[47] = codeword_in[53] ^ (overall_parity && (syndrome == 7'd54));
    assign data_out[48] = codeword_in[54] ^ (overall_parity && (syndrome == 7'd55));
    assign data_out[49] = codeword_in[55] ^ (overall_parity && (syndrome == 7'd56));
    assign data_out[50] = codeword_in[56] ^ (overall_parity && (syndrome == 7'd57));
    assign data_out[51] = codeword_in[57] ^ (overall_parity && (syndrome == 7'd58));
    assign data_out[52] = codeword_in[58] ^ (overall_parity && (syndrome == 7'd59));
    assign data_out[53] = codeword_in[59] ^ (overall_parity && (syndrome == 7'd60));
    assign data_out[54] = codeword_in[60] ^ (overall_parity && (syndrome == 7'd61));
    assign data_out[55] = codeword_in[61] ^ (overall_parity && (syndrome == 7'd62));
    assign data_out[56] = codeword_in[62] ^ (overall_parity && (syndrome == 7'd63));
    assign data_out[57] = codeword_in[64] ^ (overall_parity && (syndrome == 7'd65));
    assign data_out[58] = codeword_in[65] ^ (overall_parity && (syndrome == 7'd66));
    assign data_out[59] = codeword_in[66] ^ (overall_parity && (syndrome == 7'd67));
    assign data_out[60] = codeword_in[67] ^ (overall_parity && (syndrome == 7'd68));
    assign data_out[61] = codeword_in[68] ^ (overall_parity && (syndrome == 7'd69));
    assign data_out[62] = codeword_in[69] ^ (overall_parity && (syndrome == 7'd70));
    assign data_out[63] = codeword_in[70] ^ (overall_parity && (syndrome == 7'd71));
endmodule
