//seed accumulator (seeder.v)
// takes 8 bit random bytes from TRNG and assembles them into full seed
//keep track of how many bytes have been collected
module seed_accumulator #(
    parameter SEED_WIDTH = 256,        //seed size in bits
    parameter BYTES_PER_CYCLE = 1      //bytes received per cycle
) (
    input wire clk,
    input wire rst,
    input wire start,                  //start collection!
    input wire trng_valid,             //TRNG data valid
    input wire [7:0] trng_byte,        //random byte from TRNG
    output reg [SEED_WIDTH-1:0] seed,  //Accumulated seed
    output reg seed_ready,             //Seed collection complete
    output reg collecting              //Currently collecting
);

    localparam BYTES_NEEDED = SEED_WIDTH / 8;  // 256 bits = 32 bytes
    localparam COUNTER_WIDTH = $clog2(BYTES_NEEDED) + 1;
    
    reg [COUNTER_WIDTH-1:0] byte_counter;
    reg [SEED_WIDTH-1:0] seed_buffer;
    
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            seed <= {SEED_WIDTH{1'b0}};
            seed_ready <= 1'b0;
            collecting <= 1'b0;
            byte_counter <= 0;
            seed_buffer <= {SEED_WIDTH{1'b0}};
        end else begin
            if (start && !collecting && !seed_ready) begin
                //Start new seed collection (collecting is high)
                collecting <= 1'b1;
                seed_ready <= 1'b0;
                byte_counter <= 0;
                seed_buffer <= {SEED_WIDTH{1'b0}};
            end else if (collecting) begin
                if (trng_valid) begin
                    // Shift in new byte (LSB first)
                    seed_buffer <= {seed_buffer[SEED_WIDTH-9:0], trng_byte};
                    byte_counter <= byte_counter + 1;
                    
                    //Check if we have enough bytes
                    if (byte_counter >= BYTES_NEEDED - 1) begin
                        seed <= {seed_buffer[SEED_WIDTH-9:0], trng_byte};
                        seed_ready <= 1'b1;
                        collecting <= 1'b0;
                        byte_counter <= 0;
                    end
                end
            end else if (seed_ready) begin
                //Clear seed_ready when start goes low
                if (!start) begin
                    seed_ready <= 1'b0;
                end
            end
        end
    end

endmodule /*each clock cycle with trng_valid =1, shift seed bits left by 8 bits and append new bytes from trng at the end, after collecting all 32 bytes, seed is complete (seed_ready =1, stop collecting so collecting =0)*/