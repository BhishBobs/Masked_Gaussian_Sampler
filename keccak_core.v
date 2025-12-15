/*welcome to the engine room of the drbg! please note that this is not PURE Keccak-f[1600] and that it is only a close approximation - custom permutation that uses correct round constants, bit rotations, xors but does not implement keccak's 5 step mappings. This is only for academic demo of the masking effect */

module keccak_core #(
    parameter ROUNDS = 24
) (
    input wire clk,
    input wire rst,
    input wire start, //latch input state
    input wire [1599:0] state_in,
    output reg [1599:0] state_out,
    output reg done
);
//internal registers
    reg [1599:0] state;
    reg [4:0] round_count;
    reg processing;
    
    // Round constants for Keccak-f[1600] (this is official rc values from specifications)
    reg [63:0] RC [0:23];
    
    initial begin
        RC[0]  = 64'h0000000000000001;
        RC[1]  = 64'h0000000000008082;
        RC[2]  = 64'h800000000000808A;
        RC[3]  = 64'h8000000080008000;
        RC[4]  = 64'h000000000000808B;
        RC[5]  = 64'h0000000080000001;
        RC[6]  = 64'h8000000080008081;
        RC[7]  = 64'h8000000000008009;
        RC[8]  = 64'h000000000000008A;
        RC[9]  = 64'h0000000000000088;
        RC[10] = 64'h0000000080008009;
        RC[11] = 64'h000000008000000A;
        RC[12] = 64'h000000008000808B;
        RC[13] = 64'h800000000000008B;
        RC[14] = 64'h8000000000008089;
        RC[15] = 64'h8000000000008003;
        RC[16] = 64'h8000000000008002;
        RC[17] = 64'h8000000000000080;
        RC[18] = 64'h000000000000800A;
        RC[19] = 64'h800000008000000A;
        RC[20] = 64'h8000000080008081;
        RC[21] = 64'h8000000000008080;
        RC[22] = 64'h0000000080000001;
        RC[23] = 64'h8000000080008008;
    end
    
    //improved mixing function
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            state <= 1600'd0;
            state_out <= 1600'd0;
            done <= 1'b0;
            round_count <= 5'd0;
            processing <= 1'b0;
        end else begin
            if (start && !processing) begin
                state <= state_in;
                round_count <= 5'd0;
                processing <= 1'b1;
                done <= 1'b0;
            end else if (processing) begin
                if (round_count < ROUNDS) begin
                    // Better mixing with multiple rotations and XORs
                    state <= state ^ 
                             {state[1535:0], state[1599:1536]} ^ 
                             {state[1471:0], state[1599:1472]} ^
                             {state[1279:0], state[1599:1280]} ^
                             RC[round_count];
// effectively state xor rotate left (state,64) xor rotate left (state, 128) xor rotate left (state, 320 ) xor RC
                    round_count <= round_count + 1;
                end else begin
                    state_out <= state;
                    done <= 1'b1;
                    processing <= 1'b0;
                end
            end else begin
                done <= 1'b0;
            end
        end
    end

endmodule
