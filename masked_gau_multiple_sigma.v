//lets generate a discrete Gaussian sample using CDT sampling and then MASK it

`timescale 1ns / 1ps

module masked_gaussian_sampler_cdt_multi_sigma #(
    parameter PRECISION = 64,
    parameter TABLE_SIZE = 21,
    parameter X_MIN = -10,
    parameter X_MAX = 10,
    parameter SAMPLE_WIDTH = 16,
    parameter CENTER_WIDTH = 32,
    parameter CENTER_FRAC_BITS = 16,
    parameter MASK_WIDTH = 32,
    parameter NUM_SIGMA_TABLES = 4,
    parameter SIGMA_SEL_WIDTH = 2
) (
    input wire clk,
    input wire rst,
    input wire start,
    input wire [PRECISION-1:0] random_u, //uniform random number from dbrg
    input wire signed [CENTER_WIDTH-1:0] center, //mean
    input wire [SIGMA_SEL_WIDTH-1:0] sigma_sel, //which sigma table to use
    //Mask input from DRBG
    input wire [MASK_WIDTH-1:0] mask_in,//fresh random mask
    input wire mask_valid,//mask handshake
    //Request new mask from DRBG
    output reg req_mask,
    //Masked outputs (two shares)
    output reg signed [SAMPLE_WIDTH-1:0] sample_share0,
    output reg signed [SAMPLE_WIDTH-1:0] sample_share1,
    output reg valid
);

    //Multiple CDT tables for different sigma values
    // Table 0: sigma = 1.278 (Falcon leaf nodes)
    // Table 1: sigma = 1.40
    // Table 2: sigma = 1.55
    // Table 3: sigma = 1.85 (Falcon root)
    reg [PRECISION-1:0] CDT_tables [0:NUM_SIGMA_TABLES-1][0:TABLE_SIZE-1];
    
    initial begin
        //CDT Table for sigma = 1.278
        CDT_tables[0][ 0] = 64'h00000000000EE2BD;
        CDT_tables[0][ 1] = 64'h0000000010008171;
        CDT_tables[0][ 2] = 64'h0000000970EE458A;
        CDT_tables[0][ 3] = 64'h00000311062D9F70;
        CDT_tables[0][ 4] = 64'h00008CF77AB42DFF;
        CDT_tables[0][ 5] = 64'h000E14BA89683A83;
        CDT_tables[0][ 6] = 64'h00CA265B5AF726A0;
        CDT_tables[0][ 7] = 64'h0674F109D1541480;
        CDT_tables[0][ 8] = 64'h1EC915D5A762BC00;
        CDT_tables[0][ 9] = 64'h590A2916917F0000;
        CDT_tables[0][10] = 64'hA6F5D6E96E810000;
        CDT_tables[0][11] = 64'hE136EA2A589D4000;
        CDT_tables[0][12] = 64'hF98B0EF62EABE800;
        CDT_tables[0][13] = 64'hFF35D9A4A508D800;
        CDT_tables[0][14] = 64'hFFF1EB457697C800;
        CDT_tables[0][15] = 64'hFFFF7308854BD000;
        CDT_tables[0][16] = 64'hFFFFFCEEF9D26000;
        CDT_tables[0][17] = 64'hFFFFFFF68F11B800;
        CDT_tables[0][18] = 64'hFFFFFFFFEFFF8000;
        CDT_tables[0][19] = 64'hFFFFFFFFFFF12000;
        CDT_tables[0][20] = 64'hFFFFFFFFFFFFF800;
        
        //Table 1: sigma = 1.4
        CDT_tables[1][ 0] = 64'h000000000659B572;
        CDT_tables[1][ 1] = 64'h00000002B8F741D2;
        CDT_tables[1][ 2] = 64'h000000B590E72FEC;
        CDT_tables[1][ 3] = 64'h00001CD344A4FC69;
        CDT_tables[1][ 4] = 64'h0002CCD2B5B09B07;
        CDT_tables[1][ 5] = 64'h002AD9BD378C9A00;
        CDT_tables[1][ 6] = 64'h0196F4E57E49CE10;
        CDT_tables[1][ 7] = 64'h097D99CBA24F3A80;
        CDT_tables[1][ 8] = 64'h245959D1BF359400;
        CDT_tables[1][ 9] = 64'h5C493B6163AE2800;
        CDT_tables[1][10] = 64'hA3B6C49E9C51D800;
        CDT_tables[1][11] = 64'hDBA6A62E40CA7000;
        CDT_tables[1][12] = 64'hF68266345DB0C800;
        CDT_tables[1][13] = 64'hFE690B1A81B63000;
        CDT_tables[1][14] = 64'hFFD52642C8736800;
        CDT_tables[1][15] = 64'hFFFD332D4A4F6800;
        CDT_tables[1][16] = 64'hFFFFE32CBB5B0000;
        CDT_tables[1][17] = 64'hFFFFFF4A6F18D000;
        CDT_tables[1][18] = 64'hFFFFFFFD4708C000;
        CDT_tables[1][19] = 64'hFFFFFFFFF9A64800;
        CDT_tables[1][20] = 64'hFFFFFFFFFFF70800;
        
        //Table 2: sigma = 1.55
        CDT_tables[2][ 0] = 64'h00000001E6115527;
        CDT_tables[2][ 1] = 64'h000000595C58E8E5;
        CDT_tables[2][ 2] = 64'h00000AF66F2B0869;
        CDT_tables[2][ 3] = 64'h0000E65F278E0081;
        CDT_tables[2][ 4] = 64'h000CB368A46711A3;
        CDT_tables[2][ 5] = 64'h007906810C990728;
        CDT_tables[2][ 6] = 64'h03108502FC5AF4E0;
        CDT_tables[2][ 7] = 64'h0DAA7E3702BC8800;
        CDT_tables[2][ 8] = 64'h2AA56BF30A40DC00;
        CDT_tables[2][ 9] = 64'h5F9E1E001AFF9C00;
        CDT_tables[2][10] = 64'hA061E1FFE5006000;
        CDT_tables[2][11] = 64'hD55A940CF5BF2000;
        CDT_tables[2][12] = 64'hF25581C8FD437800;
        CDT_tables[2][13] = 64'hFCEF7AFD03A50800;
        CDT_tables[2][14] = 64'hFF86F97EF366F800;
        CDT_tables[2][15] = 64'hFFF34C975B98F000;
        CDT_tables[2][16] = 64'hFFFF19A0D8720000;
        CDT_tables[2][17] = 64'hFFFFF50990D4F800;
        CDT_tables[2][18] = 64'hFFFFFFA6A3A71800;
        CDT_tables[2][19] = 64'hFFFFFFFE19EEA800;
        CDT_tables[2][20] = 64'hFFFFFFFFF91F5800;
        
        //Table 3: sigma = 1.85
        CDT_tables[3][ 0] = 64'h0000025D76E74AF6;
        CDT_tables[3][ 1] = 64'h0000245F4DF3A3D8;
        CDT_tables[3][ 2] = 64'h0001A6431F8A6A6A;
        CDT_tables[3][ 3] = 64'h000E7DA056E72672;
        CDT_tables[3][ 4] = 64'h0060A48E8B33C8B4;
        CDT_tables[3][ 5] = 64'h01EB7293A6936DE0;
        CDT_tables[3][ 6] = 64'h077D1AC06D808F00;
        CDT_tables[3][ 7] = 64'h169A44CF1CF07C00;
        CDT_tables[3][ 8] = 64'h356FCC76C2E80C00;
        CDT_tables[3][ 9] = 64'h64BADAA817517C00;
        CDT_tables[3][10] = 64'h9B452557E8AE8800;
        CDT_tables[3][11] = 64'hCA9033893D17F000;
        CDT_tables[3][12] = 64'hE965BB30E30F8000;
        CDT_tables[3][13] = 64'hF882E53F927F7000;
        CDT_tables[3][14] = 64'hFE148D6C596C9000;
        CDT_tables[3][15] = 64'hFF9F5B7174CC3800;
        CDT_tables[3][16] = 64'hFFF1825FA918D800;
        CDT_tables[3][17] = 64'hFFFE59BCE0759800;
        CDT_tables[3][18] = 64'hFFFFDBA0B20C6000;
        CDT_tables[3][19] = 64'hFFFFFDA28918B800;
        CDT_tables[3][20] = 64'hFFFFFFE2558C1800;
    end

    //State machine
    localparam IDLE = 3'd0;
    localparam REQUEST_MASK = 3'd1;
    localparam WAIT_MASK = 3'd2;
    localparam SEARCH = 3'd3;
    localparam ADD_CENTER = 3'd4;
    localparam MASK_OUTPUT = 3'd5;
    localparam DONE = 3'd6;
    
    reg [2:0] state;
    
    // Binary search variables
    reg [7:0] left, right, mid;
    reg [3:0] search_iter;
    reg signed [SAMPLE_WIDTH-1:0] sample_unmasked;
    reg signed [SAMPLE_WIDTH-1:0] sample_with_center;
    reg [SIGMA_SEL_WIDTH-1:0] current_sigma_sel;
    
    // Stored mask
    reg [MASK_WIDTH-1:0] current_mask;
    
    // FIXED: Increased search depth to ensure convergence
    // For TABLE_SIZE=21, we need ceil(log2(21)) = 5 iterations minimum
    // Adding extra iterations to guarantee convergence
    localparam SEARCH_DEPTH = 7;  // Changed from 5 to 7
    
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            state <= IDLE;
            sample_share0 <= 0;
            sample_share1 <= 0;
            valid <= 0;
            left <= 0;
            right <= 0;
            mid <= 0;
            search_iter <= 0;
            sample_unmasked <= 0;
            sample_with_center <= 0;
            current_mask <= 0;
            current_sigma_sel <= 0;
            req_mask <= 0;
        end else begin
            case (state)
                IDLE: begin
                    valid <= 0;
                    req_mask <= 0;
                    if (start) begin
                        current_sigma_sel <= sigma_sel;
                        req_mask <= 1;
                        state <= REQUEST_MASK; //latch sigma, request fresh mask, prevent mask reuse
                    end
                end
                
                REQUEST_MASK: begin
                    req_mask <= 0;
                    state <= WAIT_MASK;
                end//req_mask asserted for 1 cycle, waits until mask_valid ==1
                
                WAIT_MASK: begin
                    if (mask_valid) begin
                        current_mask <= mask_in;
                        left <= 0;
                        right <= TABLE_SIZE - 1;
                        search_iter <= 0;
                        state <= SEARCH;
                    end
                end
                
                SEARCH: begin
                    // Continue searching until fully converged
                    if (left < right) begin
                        mid <= (left + right) >> 1;
                        
                        //comparison, is CDF(mid) >or= to u?
if (random_u <= CDT_tables[current_sigma_sel][mid]) begin
                            right <= mid;
                        end else begin
                            left <= mid + 1;
                        end
                        
                        search_iter <= search_iter + 1;
                        
                        //Safety check - prevent infinite loop
                        if (search_iter >= SEARCH_DEPTH) begin
                            state <= ADD_CENTER;
                        end
                    end else begin
                        //Fully converged: left == right
                        //This points to the smallest x where CDF(x) >= random_u
                        sample_unmasked <= X_MIN + left;
                        state <= ADD_CENTER;
                    end
                end
                
                ADD_CENTER: begin
                    //Add center to sample (with proper rounding for fixed-point)
                    if (center >= 0) begin
                        sample_with_center <= sample_unmasked + 
                            ((center + (1 << (CENTER_FRAC_BITS-1))) >> CENTER_FRAC_BITS);
                    end else begin
                        sample_with_center <= sample_unmasked + 
                            ((center - (1 << (CENTER_FRAC_BITS-1))) >> CENTER_FRAC_BITS);
                    end
                    state <= MASK_OUTPUT;
                end
                
                MASK_OUTPUT: begin
                    //Apply boolean masking: sample = share0 XOR share1
                    //share0 = sample XOR mask
                    //share1 = mask
                    sample_share0 <= sample_with_center ^ current_mask[SAMPLE_WIDTH-1:0];
                    sample_share1 <= current_mask[SAMPLE_WIDTH-1:0];
                    state <= DONE; //first-order masking, sample never appears unmasked internally after this stage
                end
                
                DONE: begin
                    valid <= 1;
                    state <= IDLE;
                end
                
                default: state <= IDLE;
            endcase
        end
    end

endmodule