//this is shake256 based drbg

//Shake256 is an XOF (extendable output function)
//It is built on Keccak-f[1600]
//Internal state = 1600 bits, rate = 1088 bits, capacity = 512 bits
//we absorb input (from trng + seeder), permute and squeeze unlimited output bits

//think of whole drbg system as Absorb -> Permute -> Squeeze


module shake256_drbg #(
    parameter SEED_WIDTH = 256,
    parameter OUTPUT_WIDTH = 32,
    parameter RATE = 1088
) (
    input wire clk,
    input wire rst,
    input wire reseed,
    input wire [SEED_WIDTH-1:0] seed,
    input wire gen,
    output reg [OUTPUT_WIDTH-1:0] random_out,
    output reg valid
);

    //state machine encoding
    localparam IDLE = 3'd0;//wait for reseed or gen
    localparam ABSORB = 3'd1;//prepare Keccak permutation
    localparam PERMUTE = 3'd2;//run Keccak-f
    localparam SQUEEZE = 3'd3;//extract output
    localparam OUTPUT = 3'd4;//Pulse valid
    localparam WAIT_PERMUTE = 3'd5;//permute again
    
    reg [2:0] state;
    reg [1599:0] keccak_state;//1600-bit sponge state
    reg keccak_start; //triggers permutation
    wire [1599:0] keccak_state_out;
    wire keccak_done; //permutation finished
    
    reg [1087:0] output_buffer;
    reg [10:0] bits_available;
    reg [31:0] output_counter;
    reg seeded;
    
    //24 rounds for Keccak-f[1600]
    keccak_core #(
        .ROUNDS(24)
    ) keccak_inst (
        .clk(clk),
        .rst(rst),
        .start(keccak_start),
        .state_in(keccak_state),
        .state_out(keccak_state_out),
        .done(keccak_done)
    );
    
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            state <= IDLE;
            keccak_state <= 1600'd0;
            keccak_start <= 1'b0;
            output_buffer <= 1088'd0;
            bits_available <= 11'd0;
            random_out <= 32'd0;
            valid <= 1'b0;
            output_counter <= 32'd0;
            seeded <= 1'b0;
        end else begin
            case (state)
                IDLE: begin
                    valid <= 1'b0;
                    keccak_start <= 1'b0;

                    
                    if (reseed) begin
                        //zero the state, insert seed at lsb side
                        keccak_state <= 1600'd0;
                        keccak_state[SEED_WIDTH-1:0] <= seed;
                        keccak_state[SEED_WIDTH+7:SEED_WIDTH] <= 8'h1F; //0x1F is SHAKE domain separator
                        keccak_state[RATE-1:RATE-8] <= 8'h80;//multi-rate padding msb
                        
                        bits_available <= 11'd0;
                        output_counter <= 32'd0;
                        seeded <= 1'b1;
                        state <= ABSORB;//marking dbrg initialised
                    end else if (gen && seeded) begin
                        if (bits_available >= OUTPUT_WIDTH) //if buffer has enough bits
			 begin
                            // Extract from buffer
                            random_out <= output_buffer[OUTPUT_WIDTH-1:0];
                            output_buffer <= output_buffer >> OUTPUT_WIDTH;
                            bits_available <= bits_available - OUTPUT_WIDTH;
                            output_counter <= output_counter + 1;
                            valid <= 1'b1;
                            state <= OUTPUT;
                        end else begin
                            //need more bits
                            state <= WAIT_PERMUTE;
                        end
                    end
                end
                
                ABSORB: begin
                    keccak_start <= 1'b1;
                    state <= PERMUTE;
                end
                
                WAIT_PERMUTE: begin
                    //Re-permute the state for more output
                    keccak_start <= 1'b1;
                    state <= PERMUTE;
                end
                
                PERMUTE: begin
                    keccak_start <= 1'b0;
                    if (keccak_done) begin
                        keccak_state <= keccak_state_out;
                        state <= SQUEEZE;
                    end
                end
                
                SQUEEZE: begin
                    //Extract output and buffer remaining bits
                    random_out <= keccak_state_out[OUTPUT_WIDTH-1:0];
                    output_buffer <= keccak_state_out[RATE-1:OUTPUT_WIDTH];
                    bits_available <= RATE - OUTPUT_WIDTH;
                    output_counter <= output_counter + 1;
                    valid <= 1'b1;
                    state <= OUTPUT;
                end
                
                OUTPUT: begin
                    valid <= 1'b0;
                    state <= IDLE;
                end
                
                default: state <= IDLE;
            endcase
        end
    end

endmodule //please note this is a bare-bones dbrg, just for showing the masking effect