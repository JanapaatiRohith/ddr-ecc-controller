`timescale 1ns/1ps

// Extended SECDED regression: five payload patterns, every one-bit error,
// and every two-bit error in the 72-bit extended-Hamming codeword.
module tb_ecc_secded;
    reg  [63:0] data_in;
    wire [71:0] codeword;
    reg  [71:0] damaged_codeword;
    wire [63:0] decoded_data;
    wire single_error;
    wire double_error;
    wire [6:0] syndrome;

    reg [63:0] patterns [0:4];
    integer errors;
    integer pattern_idx;
    integer i;
    integer j;
    integer clean_count;
    integer single_count;
    integer double_count;

    secded_64_72_encoder enc (
        .data_in(data_in),
        .codeword_out(codeword)
    );

    secded_64_72_decoder dec (
        .codeword_in(damaged_codeword),
        .data_out(decoded_data),
        .single_error(single_error),
        .double_error(double_error),
        .syndrome(syndrome)
    );

    initial begin
        errors = 0;
        clean_count = 0;
        single_count = 0;
        double_count = 0;

        patterns[0] = 64'h0000000000000000;
        patterns[1] = 64'hFFFFFFFFFFFFFFFF;
        patterns[2] = 64'h0123456789ABCDEF;
        patterns[3] = 64'hA5A55A5A_DEADBEEF;
        patterns[4] = 64'h8000000000000001;

        for (pattern_idx = 0; pattern_idx < 5; pattern_idx = pattern_idx + 1) begin
            data_in = patterns[pattern_idx];
            #1;

            // No-error case.
            damaged_codeword = codeword;
            #1;
            if ((decoded_data !== data_in) || single_error || double_error ||
                (syndrome !== 7'd0)) begin
                $display("FAIL clean pattern=%0d data=%h decoded=%h syndrome=%h single=%b double=%b",
                         pattern_idx, data_in, decoded_data, syndrome,
                         single_error, double_error);
                errors = errors + 1;
            end else begin
                clean_count = clean_count + 1;
            end

            // Every single-bit fault: bits 0..70 map to Hamming positions 1..71;
            // bit 71 is the overall parity bit and therefore has syndrome zero.
            for (i = 0; i < 72; i = i + 1) begin
                damaged_codeword = codeword ^ (72'b1 << i);
                #1;
                if ((decoded_data !== data_in) || !single_error || double_error) begin
                    $display("FAIL single pattern=%0d bit=%0d data=%h decoded=%h syndrome=%h single=%b double=%b",
                             pattern_idx, i, data_in, decoded_data, syndrome,
                             single_error, double_error);
                    errors = errors + 1;
                end else if ((i < 71 && syndrome !== (i + 1)) ||
                             (i == 71 && syndrome !== 7'd0)) begin
                    $display("FAIL single syndrome pattern=%0d bit=%0d expected=%0d got=%0d",
                             pattern_idx, i, (i < 71) ? (i + 1) : 0, syndrome);
                    errors = errors + 1;
                end else begin
                    single_count = single_count + 1;
                end
            end

            // All C(72,2)=2556 two-bit fault combinations must be detected.
            for (i = 0; i < 72; i = i + 1) begin
                for (j = i + 1; j < 72; j = j + 1) begin
                    damaged_codeword = codeword ^ (72'b1 << i) ^ (72'b1 << j);
                    #1;
                    if (!double_error || single_error || (syndrome === 7'd0)) begin
                        $display("FAIL double pattern=%0d bits=(%0d,%0d) syndrome=%h single=%b double=%b",
                                 pattern_idx, i, j, syndrome, single_error, double_error);
                        errors = errors + 1;
                    end else begin
                        double_count = double_count + 1;
                    end
                end
            end

            $display("Pattern %0d complete: data=%h", pattern_idx, data_in);
        end

        $display("SECDED regression summary:");
        $display("  clean payloads       : %0d / 5", clean_count);
        $display("  single-bit cases     : %0d / 360", single_count);
        $display("  double-bit cases     : %0d / 12780", double_count);
        $display("  failures             : %0d", errors);

        if ((errors == 0) && (clean_count == 5) &&
            (single_count == 360) && (double_count == 12780)) begin
            $display("SECDED RTL TEST PASSED");
            $finish;
        end else begin
            $fatal(1, "SECDED RTL TEST FAILED");
        end
    end
endmodule
