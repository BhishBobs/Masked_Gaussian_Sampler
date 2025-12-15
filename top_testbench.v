`timescale 1ns / 1ps

module tb_masked_gaussian_system_multi_sigma;
    parameter PRECISION = 64;
    parameter SAMPLE_WIDTH = 16;
    parameter CENTER_WIDTH = 32;
    parameter CENTER_FRAC_BITS = 16;
    parameter CLK_PERIOD = 10;
    
    reg clk;
    reg rst;
    reg start_reseed;
    reg start_sample;
    reg [PRECISION-1:0] random_u;
    reg signed [CENTER_WIDTH-1:0] center;
    reg [1:0] sigma_sel;
    
    wire signed [SAMPLE_WIDTH-1:0] sample_share0;
    wire signed [SAMPLE_WIDTH-1:0] sample_share1;
    wire sample_valid;
    wire reseeding;
    wire signed [SAMPLE_WIDTH-1:0] sample_reconstructed;
    
    //Instantiate the system
    masked_gaussian_system_multi_sigma #(
        .PRECISION(PRECISION),
        .SAMPLE_WIDTH(SAMPLE_WIDTH),
        .CENTER_WIDTH(CENTER_WIDTH),
        .CENTER_FRAC_BITS(CENTER_FRAC_BITS)
    ) dut (
        .clk(clk),
        .rst(rst),
        .start_reseed(start_reseed),
        .start_sample(start_sample),
        .random_u(random_u),
        .center(center),
        .sigma_sel(sigma_sel),
        .sample_share0(sample_share0),
        .sample_share1(sample_share1),
        .sample_valid(sample_valid),
        .reseeding(reseeding),
        .sample_reconstructed(sample_reconstructed)
    );
    
    // Clock generation
    initial begin
        clk = 0;
        forever #(CLK_PERIOD/2) clk = ~clk;
    end
    
    // Test variables
    integer i;
    
    // Test sequence
    initial begin
        $display("==========================================================");
        $display("Masked Multi-Sigma Gaussian Sampler Test with DRBG");
        $display("Sigma Tables: [0]=1.278, [1]=1.40, [2]=1.55, [3]=1.85");
        $display("==========================================================\n");
        
        // Initialize
        rst = 1;
        start_reseed = 0;
        start_sample = 0;
        random_u = 0;
        center = 0;
        sigma_sel = 0;
        #100;
        
        rst = 0;
        #50;
        
        // Step 1: Reseed DRBG
        $display("Step 1: Reseeding DRBG...");
        start_reseed = 1;
        #10;
        start_reseed = 0;
        
        wait(!reseeding);
        #100;
        $display("DRBG ready!\n");
        
        // Step 2: Test different sigma values with center = 0, random_u = 0.5
        $display("Step 2: Testing different sigma values (center = 0, u = 0.5)");
        $display("----------------------------------------------------------");
        center = 32'h0000_0000;  // center = 0.0
        random_u = 64'h8000_0000_0000_0000;  // u = 0.5
        
        // Test each sigma
        for (i = 0; i < 4; i = i + 1) begin
            sigma_sel = i[1:0];
            start_sample = 1;
            #10;
            start_sample = 0;
            
            // Wait for valid output
            wait(sample_valid);
            #10;
            
            // DEBUG: Check internal state
            $display("\nDEBUG: Internal sampler state:");
            $display("  left = %d, right = %d", dut.sampler_inst.left, dut.sampler_inst.right);
            $display("  sample_unmasked = %d", dut.sampler_inst.sample_unmasked);
            $display("  sample_with_center = %d", dut.sampler_inst.sample_with_center);
            $display("  current_sigma_sel = %d", dut.sampler_inst.current_sigma_sel);
            
            // Display results (read directly from output signals)
            case(i)
                0: $display("Sigma[0] = 1.278 (Leaf):");
                1: $display("Sigma[1] = 1.40:");
                2: $display("Sigma[2] = 1.55:");
                3: $display("Sigma[3] = 1.85 (Root):");
            endcase
            $display("  Share0 = %d (0x%04h)", sample_share0, sample_share0);
            $display("  Share1 = %d (0x%04h)", sample_share1, sample_share1);
            $display("  Reconstructed = %d (Expected: 0)", sample_reconstructed);
            
            // Verify XOR
            if ((sample_share0 ^ sample_share1) == sample_reconstructed) begin
                $display("  [PASS] XOR verification: %d XOR %d = %d", 
                         sample_share0, sample_share1, sample_reconstructed);
            end else begin
                $display("  [FAIL] XOR verification failed!");
            end
            
            // Check if sample is correct
            if (sample_reconstructed == 0) begin
                $display("  [PASS] Sample value correct!\n");
            end else begin
                $display("  [FAIL] Sample value incorrect! Expected 0, got %d\n", 
                         sample_reconstructed);
            end
            
            #100;
        end
        
        // Step 3: Test leaf node sampling (sigma = 1.278) with different centers
        $display("\nStep 3: Leaf node sampling (sigma=1.278, various centers)");
        $display("----------------------------------------------------------");
        sigma_sel = 2'd0;  // Leaf sigma
        random_u = 64'h8000_0000_0000_0000;  // u = 0.5
        
        // Test 3a: Center = 0
        center = 32'h0000_0000;  // 0.0
        start_sample = 1;
        #10;
        start_sample = 0;
        wait(sample_valid);
        #10;
        $display("Center = 0.0:");
        $display("  Share0 = %d, Share1 = %d", sample_share0, sample_share1);
        $display("  Reconstructed = %d (Expected: 0)", sample_reconstructed);
        if (sample_reconstructed == 0) begin
            $display("  [PASS] Correct!\n");
        end else begin
            $display("  [FAIL] Expected 0, got %d\n", sample_reconstructed);
        end
        #100;
        
        // Test 3b: Center = 5.0
        center = 32'h0005_0000;  // 5.0
        start_sample = 1;
        #10;
        start_sample = 0;
        wait(sample_valid);
        #10;
        $display("Center = 5.0:");
        $display("  Share0 = %d, Share1 = %d", sample_share0, sample_share1);
        $display("  Reconstructed = %d (Expected: 5)", sample_reconstructed);
        if (sample_reconstructed == 5) begin
            $display("  [PASS] Correct!\n");
        end else begin
            $display("  [FAIL] Expected 5, got %d\n", sample_reconstructed);
        end
        #100;
        
        // Test 3c: Center = -3.5
        center = 32'hFFFD_8000;  // -3.5
        start_sample = 1;
        #10;
        start_sample = 0;
        wait(sample_valid);
        #10;
        $display("Center = -3.5:");
        $display("  Share0 = %d, Share1 = %d", sample_share0, sample_share1);
        $display("  Reconstructed = %d (Expected: -4 or -3)", sample_reconstructed);
        if (sample_reconstructed == -4 || sample_reconstructed == -3) begin
            $display("  [PASS] Correct!\n");
        end else begin
            $display("  [FAIL] Expected -4 or -3, got %d\n", sample_reconstructed);
        end
        #100;
        
        // Step 4: Test root node sampling (sigma = 1.85)
        $display("\nStep 4: Root node sampling (sigma=1.85, center=0)");
        $display("----------------------------------------------------------");
        sigma_sel = 2'd3;  // Root sigma
        center = 32'h0000_0000;  // 0.0
        random_u = 64'h8000_0000_0000_0000;  // u = 0.5
        
        start_sample = 1;
        #10;
        start_sample = 0;
        wait(sample_valid);
        #10;
        
        $display("Root sample:");
        $display("  Share0 = %d (0x%04h)", sample_share0, sample_share0);
        $display("  Share1 = %d (0x%04h)", sample_share1, sample_share1);
        $display("  Reconstructed = %d (Expected: 0)", sample_reconstructed);
        
        if (sample_reconstructed == 0) begin
            $display("  [PASS] Correct!\n");
        end else begin
            $display("  [FAIL] Expected 0, got %d\n", sample_reconstructed);
        end
        #100;
        
        // Step 5: Test masking randomness (multiple samples with same inputs should have different shares)
        $display("\nStep 5: Testing Masking Randomness");
        $display("----------------------------------------------------------");
        $display("Generating 3 samples with identical inputs...");
        $display("Shares should be different (due to fresh masks from DRBG)");
        $display("But reconstructed values should all be the same.\n");
        
        sigma_sel = 2'd0;
        center = 32'h0000_0000;
        random_u = 64'h8000_0000_0000_0000;
        
        for (i = 0; i < 3; i = i + 1) begin
            start_sample = 1;
            #10;
            start_sample = 0;
            wait(sample_valid);
            #10;
            
            $display("Sample %0d:", i+1);
            $display("  Share0 = %d (0x%04h)", sample_share0, sample_share0);
            $display("  Share1 = %d (0x%04h)", sample_share1, sample_share1);
            $display("  Reconstructed = %d", sample_reconstructed);
            #100;
        end
        
        // Final summary
        $display("\n==========================================================");
        $display("Test Complete!");
        $display("==========================================================");
        $display("\nKey Points:");
        $display("1. Masking uses Boolean (XOR) scheme");
        $display("2. sample = share0 XOR share1");
        $display("3. Shares are randomized by fresh masks from DRBG");
        $display("4. Different shares ? Same reconstructed value = CORRECT!");
        $display("5. Individual shares should look random (side-channel protected)");
        $display("==========================================================\n");
        
        #100;
        $finish;
    end
    
    // Monitor key signals
    initial begin
        $monitor("Time=%0dns | reseed=%b | start=%b | sigma=%d | valid=%b | share0=%6d | share1=%6d | recon=%6d",
                 $time, reseeding, start_sample, sigma_sel, sample_valid, 
                 sample_share0, sample_share1, sample_reconstructed);
    end
    
    // Timeout watchdog
    initial begin
        #500000;
        $display("\nERROR: Simulation timeout!");
        $finish;
    end
    
endmodule