// trng inner working (trng.v)

`timescale 1ns / 1ps

// we implement a trng using TWO independent 32 bit linear feedback shift registers (LFSR)

module trng (
    input  wire       clk,
    input  wire        rst,
    input  wire        enable,      //enable trng generation
    output reg  [7:0]  random_byte, //8 random bits per cycle
    output reg         valid        // Valid signal
);
    // two independent LFSRs with different maximal-length polynomials, two LFSR used for increasing randomness by mixing two independent sequences 
    reg [31:0] lfsr1;  //Polynomial: x^32 + x^22 + x^2 + x^1 + 1
    reg [31:0] lfsr2;  //Polynomial: x^32 + x^30 + x^26 + x^25 + 1
 
    // feedback taps for maximal length sequences, this calculates new input bit for the shift register
    wire feedback1 = lfsr1[31] ^ lfsr1[21] ^ lfsr1[1]  ^ lfsr1[0];
    wire feedback2 = lfsr2[31] ^ lfsr2[29] ^ lfsr2[25] ^ lfsr2[24];
 
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            //initialize with different non-zero seeds
            lfsr1 <= 32'hACE1BABE;
            lfsr2 <= 32'hDEADBEEF;
            random_byte <= 8'd0;
            valid <= 1'b0;
        end else begin
            if (enable) begin
                // Shift both LFSRs
                lfsr1 <= {lfsr1[30:0], feedback1};
                lfsr2 <= {lfsr2[30:0], feedback2};
                
                //XOR different byte slices from each LFSR for better mixing
                //This combines non-overlapping regions for better randomness

                random_byte <= lfsr1[7:0] ^ lfsr2[23:16]; //key line!! randomness inducing
                valid <= 1'b1;
            end else begin
                valid <= 1'b0;
            end
        end
    end
endmodule //basic working: feedback taps are used as the XORed bits, and these decide the new bit to the right of LFSR, now two such lfsr with different taps, we mix them to get the random_byte to make output less predictable!!!
