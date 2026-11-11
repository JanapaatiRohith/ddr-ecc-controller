`timescale 1ns/1ps

// 64-bit SECDED encoder: 64 data + 7 Hamming parity + 1 overall parity
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

        // Place data in non-power-of-two positions 1 through 71.
        for (pos = 1; pos <= 71; pos = pos + 1) begin
            if ((pos != 1) && (pos != 2) && (pos != 4) &&
                (pos != 8) && (pos != 16) && (pos != 32) &&
                (pos != 64)) begin
                codeword_out[pos-1] = data_in[data_idx];
                data_idx = data_idx + 1;
            end
        end

        // Generate seven Hamming parity bits.
        for (p = 0; p < 7; p = p + 1) begin
            parity_bit = 1'b0;
            for (pos = 1; pos <= 71; pos = pos + 1) begin
                if ((pos & (1 << p)) != 0)
                    parity_bit = parity_bit ^ codeword_out[pos-1];
            end
            codeword_out[(1 << p)-1] = parity_bit;
        end

        // Overall even parity.
        codeword_out[71] = ^codeword_out[70:0];
    end
endmodule


module secded_64_72_decoder (
    input  wire [71:0] codeword_in,
    output reg  [63:0] data_out,
    output reg         single_error,
    output reg         double_error,
    output reg  [6:0]  syndrome
);
    integer pos;
    integer data_idx;
    integer p;
    reg parity_bit;
    reg overall_parity;
    reg [71:0] corrected_codeword;

    always @* begin
        syndrome = 7'b0;
        data_out = 64'b0;
        single_error = 1'b0;
        double_error = 1'b0;
        corrected_codeword = codeword_in;
        overall_parity = ^codeword_in;

        // Calculate syndrome.
        for (p = 0; p < 7; p = p + 1) begin
            parity_bit = 1'b0;
            for (pos = 1; pos <= 71; pos = pos + 1) begin
                if ((pos & (1 << p)) != 0)
                    parity_bit = parity_bit ^ codeword_in[pos-1];
            end
            syndrome[p] = parity_bit;
        end

        // Classify and correct errors.
        if ((syndrome != 7'd0) && overall_parity) begin
            single_error = 1'b1;
            if (syndrome <= 7'd71)
                corrected_codeword[syndrome-1'b1] =
                    ~corrected_codeword[syndrome-1'b1];
        end
        else if ((syndrome == 7'd0) && overall_parity) begin
            // Overall parity-bit error.
            single_error = 1'b1;
            corrected_codeword[71] = ~corrected_codeword[71];
        end
        else if ((syndrome != 7'd0) && !overall_parity) begin
            double_error = 1'b1;
        end

        // Extract the original 64-bit payload.
        data_idx = 0;
        for (pos = 1; pos <= 71; pos = pos + 1) begin
            if ((pos != 1) && (pos != 2) && (pos != 4) &&
                (pos != 8) && (pos != 16) && (pos != 32) &&
                (pos != 64)) begin
                data_out[data_idx] = corrected_codeword[pos-1];
                data_idx = data_idx + 1;
            end
        end
    end
endmodule
