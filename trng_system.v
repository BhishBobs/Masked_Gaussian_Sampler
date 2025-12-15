//trng_system (top module) to trng.v and seeder.v

`timescale 1ns / 1ps
// this is a true random number generator, the first module of the drbg system

//basically, it generates random bytes
//then it accumulates bytes into a seed of desired width
//signals when the seed is ready

module trng_system #(
    parameter SEED_WIDTH = 256 //output seed width
) (
    input wire clk,

    input wire rst,

    input wire start_seed_collection, //start collecting a new seed

    output wire [SEED_WIDTH-1:0] seed, //output seed
    output wire seed_ready,      //output seed ready
    output wire collecting     //basically enable signal
);

   
    wire [7:0] trng_byte; //8 bit output from trng module
    wire trng_valid; //indicator of trng byte whether it is valid or not
    wire trng_enable; //turn trng on or off (we will use it with 'collecting'
    

    assign trng_enable = collecting;
    
    // let us instantiate trng (8 bit per cycle)
    // generates 8 random bits per clock cycle, controlled by trng_enable
    trng trng_inst (
        .clk(clk),
        .rst(rst),
        .enable(trng_enable),
        .random_byte(trng_byte),
        .valid(trng_valid)
    );
    
    // what this seed accumulator does is, collect trng bytes and concatenates them into a full seed of width 256 (SEED_WIDTH), so it signals seed_ready when enough bytes are collected and signals collecting when seed is being assembled

    seed_accumulator #(
        .SEED_WIDTH(SEED_WIDTH),
        .BYTES_PER_CYCLE(1)//8 bits per clock cycle
    ) accumulator_inst (
        .clk(clk),
        .rst(rst),
        .start(start_seed_collection),
        .trng_valid(trng_valid),
        .trng_byte(trng_byte),
        .seed(seed),
        .seed_ready(seed_ready),
        .collecting(collecting)
    ); /* so, to understand flow here is how it goes -> start_seed_collection goes high, collecting goes high, enabling trng, each trng byte fed to accumulator, when seed is ready, seed_ready goes high and collecting goes low.
*/

// see bottom modules for further clarity on how it works!
endmodule
