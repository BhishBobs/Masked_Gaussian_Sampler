`timescale 1ns / 1ps
module masked_gaussian_system_multi_sigma #(
    parameter PRECISION = 64,
    parameter TABLE_SIZE = 21,
    parameter X_MIN = -10,
    parameter X_MAX = 10,
    parameter SAMPLE_WIDTH = 16,
    parameter CENTER_WIDTH = 32,
    parameter CENTER_FRAC_BITS = 16,
    parameter SEED_WIDTH = 256,
    parameter MASK_WIDTH = 32,
    parameter NUM_SIGMA_TABLES = 4,
    parameter SIGMA_SEL_WIDTH = 2
) (
    input wire clk,
    input wire rst,
    
    // DRBG reseeding control
    input wire start_reseed,
    
    // Gaussian sampling inputs
    input wire start_sample,
    input wire [PRECISION-1:0] random_u,
    input wire signed [CENTER_WIDTH-1:0] center,
    input wire [SIGMA_SEL_WIDTH-1:0] sigma_sel,  // Select sigma table
    
    // Masked outputs
    output wire signed [SAMPLE_WIDTH-1:0] sample_share0,
    output wire signed [SAMPLE_WIDTH-1:0] sample_share1,
    output wire sample_valid,
    
    // Status outputs
    output wire reseeding,
    output wire [SAMPLE_WIDTH-1:0] sample_reconstructed  // For verification only
);

    // DRBG signals
    wire [MASK_WIDTH-1:0] mask_out;
    wire mask_valid;
    wire req_mask;
    
    // Instantiate DRBG System
    drbg_system #(
        .SEED_WIDTH(SEED_WIDTH),
        .MASK_WIDTH(MASK_WIDTH)
    ) drbg_inst (
        .clk(clk),
        .rst(rst),
        .start_reseed(start_reseed),
        .gen_mask(req_mask),
        .mask_out(mask_out),
        .mask_valid(mask_valid),
        .reseeding(reseeding)
    );
    
    // Instantiate Masked Multi-Sigma Gaussian Sampler
    masked_gaussian_sampler_cdt_multi_sigma #(
        .PRECISION(PRECISION),
        .TABLE_SIZE(TABLE_SIZE),
        .X_MIN(X_MIN),
        .X_MAX(X_MAX),
        .SAMPLE_WIDTH(SAMPLE_WIDTH),
        .CENTER_WIDTH(CENTER_WIDTH),
        .CENTER_FRAC_BITS(CENTER_FRAC_BITS),
        .MASK_WIDTH(MASK_WIDTH),
        .NUM_SIGMA_TABLES(NUM_SIGMA_TABLES),
        .SIGMA_SEL_WIDTH(SIGMA_SEL_WIDTH)
    ) sampler_inst (
        .clk(clk),
        .rst(rst),
        .start(start_sample),
        .random_u(random_u),
        .center(center),
        .sigma_sel(sigma_sel),
        .mask_in(mask_out),
        .mask_valid(mask_valid),
        .req_mask(req_mask),
        .sample_share0(sample_share0),
        .sample_share1(sample_share1),
        .valid(sample_valid)
    );
    
    // Reconstruct sample for verification (XOR the two shares)
    // In real hardware, this should NOT be done to maintain security!
    assign sample_reconstructed = sample_share0 ^ sample_share1;

endmodule
