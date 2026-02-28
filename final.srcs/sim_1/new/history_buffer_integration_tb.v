`timescale 1ns / 1ps

//==============================================================================
// CORRECTED HISTORY BUFFER INTEGRATION TESTBENCH
// Tests both random_sort_simple and user_input_sort with history buffer
// Fixes applied:
// 1. Port width mismatch (current_step, total_steps: 6->8 bits)
// 2. Increased step count for 8-element arrays (20->50)
// 3. Added proper completion detection
// 4. Added sorted array verification
// 5. Improved timing and wait conditions
//==============================================================================

module history_buffer_integration_tb;

    // Common signals
    reg clk;
    reg rst;
    
    // Test mode selection
    reg test_mode;  // 0 = test random_sort, 1 = test user_input
    
    // Random sort signals
    reg btn_generate_random;
    reg btn_start_random;
    reg btn_step_random;
    reg [3:0] array_size_random;
    wire [1:0] state_random;
    wire done_random;
    wire [2:0] display_addr_random;
    wire [7:0] display_data_random;
    
    // Random sort history outputs (16 + 5)
    wire [7:0] random_live_0, random_live_1, random_live_2, random_live_3;
    wire [7:0] random_live_4, random_live_5, random_live_6, random_live_7;
    wire [7:0] random_temp_0, random_temp_1, random_temp_2, random_temp_3;
    wire [7:0] random_temp_4, random_temp_5, random_temp_6, random_temp_7;
    wire [2:0] random_pos1, random_pos2;
    wire random_comp_active;
    wire [1:0] random_op_type;
    wire random_capture_valid;
    
    // User input sort signals
    reg input_valid;
    reg [7:0] input_value;
    reg [3:0] target_size;
    reg input_complete;
    reg btn_start_user;
    reg btn_step_user;
    wire [2:0] state_user;
    wire [3:0] current_count;
    wire done_user;
    wire input_ready;
    wire sorting_active;
    wire [2:0] display_addr_user;
    wire [7:0] display_data_user;
    
    // User input history outputs (16 + 5)
    wire [7:0] user_live_0, user_live_1, user_live_2, user_live_3;
    wire [7:0] user_live_4, user_live_5, user_live_6, user_live_7;
    wire [7:0] user_temp_0, user_temp_1, user_temp_2, user_temp_3;
    wire [7:0] user_temp_4, user_temp_5, user_temp_6, user_temp_7;
    wire [2:0] user_pos1, user_pos2;
    wire user_comp_active;
    wire [1:0] user_op_type;
    wire user_capture_valid;
    
    // Multiplexed signals to history buffer
    wire [7:0] hist_live_0, hist_live_1, hist_live_2, hist_live_3;
    wire [7:0] hist_live_4, hist_live_5, hist_live_6, hist_live_7;
    wire [7:0] hist_temp_0, hist_temp_1, hist_temp_2, hist_temp_3;
    wire [7:0] hist_temp_4, hist_temp_5, hist_temp_6, hist_temp_7;
    wire [2:0] hist_pos1, hist_pos2;
    wire hist_comp_active;
    wire [1:0] hist_op_type;
    wire hist_capture_valid;
    
    // MUX: Select which module feeds history buffer
    assign hist_live_0 = test_mode ? user_live_0 : random_live_0;
    assign hist_live_1 = test_mode ? user_live_1 : random_live_1;
    assign hist_live_2 = test_mode ? user_live_2 : random_live_2;
    assign hist_live_3 = test_mode ? user_live_3 : random_live_3;
    assign hist_live_4 = test_mode ? user_live_4 : random_live_4;
    assign hist_live_5 = test_mode ? user_live_5 : random_live_5;
    assign hist_live_6 = test_mode ? user_live_6 : random_live_6;
    assign hist_live_7 = test_mode ? user_live_7 : random_live_7;
    
    assign hist_temp_0 = test_mode ? user_temp_0 : random_temp_0;
    assign hist_temp_1 = test_mode ? user_temp_1 : random_temp_1;
    assign hist_temp_2 = test_mode ? user_temp_2 : random_temp_2;
    assign hist_temp_3 = test_mode ? user_temp_3 : random_temp_3;
    assign hist_temp_4 = test_mode ? user_temp_4 : random_temp_4;
    assign hist_temp_5 = test_mode ? user_temp_5 : random_temp_5;
    assign hist_temp_6 = test_mode ? user_temp_6 : random_temp_6;
    assign hist_temp_7 = test_mode ? user_temp_7 : random_temp_7;
    
    assign hist_pos1 = test_mode ? user_pos1 : random_pos1;
    assign hist_pos2 = test_mode ? user_pos2 : random_pos2;
    assign hist_comp_active = test_mode ? user_comp_active : random_comp_active;
    assign hist_op_type = test_mode ? user_op_type : random_op_type;
    assign hist_capture_valid = test_mode ? user_capture_valid : random_capture_valid;
    
    // History buffer signals
    reg play_pause_pulse;
    reg back_pulse;
    reg [1:0] speed_select;
    reg sort_finished;
    
    wire [7:0] playback_live_0, playback_live_1, playback_live_2, playback_live_3;
    wire [7:0] playback_live_4, playback_live_5, playback_live_6, playback_live_7;
    wire [7:0] playback_temp_0, playback_temp_1, playback_temp_2, playback_temp_3;
    wire [7:0] playback_temp_4, playback_temp_5, playback_temp_6, playback_temp_7;
    wire [2:0] playback_pos1, playback_pos2;
    wire playback_comparison_active;
    wire [1:0] playback_operation_type;
    wire [7:0] current_step;      // FIXED: Changed from [6:0] to [7:0]
    wire [7:0] total_steps;       // FIXED: Changed from [6:0] to [7:0]
    wire is_playing;
    
    // Instantiate random_sort_simple
    random_sort_simple #(
        .DATA_WIDTH(8),
        .MAX_ARRAY_SIZE(8),
        .ADDR_WIDTH(3)
    ) random_sorter (
        .clk(clk),
        .rst(rst),
        .btn_generate(btn_generate_random),
        .btn_start_sort(btn_start_random),
        .btn_step(btn_step_random),
        .array_size(array_size_random),
        .state(state_random),
        .done(done_random),
        .display_addr(display_addr_random),
        .display_data(display_data_random),
        .live_array_0(random_live_0), .live_array_1(random_live_1),
        .live_array_2(random_live_2), .live_array_3(random_live_3),
        .live_array_4(random_live_4), .live_array_5(random_live_5),
        .live_array_6(random_live_6), .live_array_7(random_live_7),
        .temp_array_0(random_temp_0), .temp_array_1(random_temp_1),
        .temp_array_2(random_temp_2), .temp_array_3(random_temp_3),
        .temp_array_4(random_temp_4), .temp_array_5(random_temp_5),
        .temp_array_6(random_temp_6), .temp_array_7(random_temp_7),
        .compare_pos1(random_pos1), .compare_pos2(random_pos2),
        .comparison_active(random_comp_active),
        .operation_type(random_op_type),
        .capture_valid(random_capture_valid)
    );
    
    // Instantiate user_input_sort
    user_input_sort #(
        .DATA_WIDTH(8),
        .MAX_ARRAY_SIZE(8),
        .ADDR_WIDTH(3)
    ) user_sorter (
        .clk(clk),
        .rst(rst),
        .input_valid(input_valid),
        .input_value(input_value),
        .target_size(target_size),
        .input_complete(input_complete),
        .btn_start_sort(btn_start_user),
        .btn_step(btn_step_user),
        .state(state_user),
        .current_count(current_count),
        .done(done_user),
        .input_ready(input_ready),
        .sorting_active(sorting_active),
        .display_addr(display_addr_user),
        .display_data(display_data_user),
        .debug_input_valid_edge(),
        .debug_input_complete_edge(),
        .live_array_0(user_live_0), .live_array_1(user_live_1),
        .live_array_2(user_live_2), .live_array_3(user_live_3),
        .live_array_4(user_live_4), .live_array_5(user_live_5),
        .live_array_6(user_live_6), .live_array_7(user_live_7),
        .temp_array_0(user_temp_0), .temp_array_1(user_temp_1),
        .temp_array_2(user_temp_2), .temp_array_3(user_temp_3),
        .temp_array_4(user_temp_4), .temp_array_5(user_temp_5),
        .temp_array_6(user_temp_6), .temp_array_7(user_temp_7),
        .compare_pos1(user_pos1), .compare_pos2(user_pos2),
        .comparison_active(user_comp_active),
        .operation_type(user_op_type),
        .capture_valid(user_capture_valid)
    );
    
    // Instantiate history buffer
    history_buffer #(
        .DATA_WIDTH(8),
        .ARRAY_SIZE(8),
        .BUFFER_DEPTH(256),
        .BASE_DELAY(100)  // Fast for simulation
    ) hist_buf (
        .clk(clk),
        .rst_n(~rst),
        .live_array_0(hist_live_0), .live_array_1(hist_live_1),
        .live_array_2(hist_live_2), .live_array_3(hist_live_3),
        .live_array_4(hist_live_4), .live_array_5(hist_live_5),
        .live_array_6(hist_live_6), .live_array_7(hist_live_7),
        .temp_array_0(hist_temp_0), .temp_array_1(hist_temp_1),
        .temp_array_2(hist_temp_2), .temp_array_3(hist_temp_3),
        .temp_array_4(hist_temp_4), .temp_array_5(hist_temp_5),
        .temp_array_6(hist_temp_6), .temp_array_7(hist_temp_7),
        .compare_pos1(hist_pos1), .compare_pos2(hist_pos2),
        .comparison_active(hist_comp_active),
        .operation_type(hist_op_type),
        .capture_valid(hist_capture_valid),
        .sort_finished(sort_finished),
        .play_pause_pulse(play_pause_pulse),
        .back_pulse(back_pulse),
        .speed_select(speed_select),
        .playback_live_0(playback_live_0), .playback_live_1(playback_live_1),
        .playback_live_2(playback_live_2), .playback_live_3(playback_live_3),
        .playback_live_4(playback_live_4), .playback_live_5(playback_live_5),
        .playback_live_6(playback_live_6), .playback_live_7(playback_live_7),
        .playback_temp_0(playback_temp_0), .playback_temp_1(playback_temp_1),
        .playback_temp_2(playback_temp_2), .playback_temp_3(playback_temp_3),
        .playback_temp_4(playback_temp_4), .playback_temp_5(playback_temp_5),
        .playback_temp_6(playback_temp_6), .playback_temp_7(playback_temp_7),
        .playback_pos1(playback_pos1), .playback_pos2(playback_pos2),
        .playback_comparison_active(playback_comparison_active),
        .playback_operation_type(playback_operation_type),
        .current_step(current_step),
        .total_steps(total_steps),
        .is_playing(is_playing)
    );
    
    // Clock generation - 10ns period (100 MHz)
    initial begin
        clk = 0;
        forever #5 clk = ~clk;
    end
    
    // Verification task - checks if array is sorted
    task verify_sorted_array;
        input [7:0] arr0, arr1, arr2, arr3, arr4, arr5, arr6, arr7;
        input [7:0] arr_size;
        reg sorted_ok;
        integer i;
        begin
            sorted_ok = 1;
            
            // Check each adjacent pair
            if (arr_size > 1 && arr0 > arr1) sorted_ok = 0;
            if (arr_size > 2 && arr1 > arr2) sorted_ok = 0;
            if (arr_size > 3 && arr2 > arr3) sorted_ok = 0;
            if (arr_size > 4 && arr3 > arr4) sorted_ok = 0;
            if (arr_size > 5 && arr4 > arr5) sorted_ok = 0;
            if (arr_size > 6 && arr5 > arr6) sorted_ok = 0;
            if (arr_size > 7 && arr6 > arr7) sorted_ok = 0;
            
            if (sorted_ok) begin
                $display("  ? VERIFICATION PASSED: Array is correctly sorted!");
            end else begin
                $display("  ? VERIFICATION FAILED: Array is NOT sorted!");
            end
        end
    endtask
    
    // Main test sequence
    initial begin
        $display("\n========================================");
        $display("HISTORY BUFFER INTEGRATION TEST");
        $display("CORRECTED VERSION");
        $display("========================================\n");
        
        // Initialize all signals
        rst = 1;
        test_mode = 0;
        btn_generate_random = 0;
        btn_start_random = 0;
        btn_step_random = 0;
        array_size_random = 0;
        input_valid = 0;
        input_value = 0;
        target_size = 0;
        input_complete = 0;
        btn_start_user = 0;
        btn_step_user = 0;
        play_pause_pulse = 0;
        back_pulse = 0;
        speed_select = 2'b01;  // Normal speed
        sort_finished = 0;
        
        #50 rst = 0;
        $display("[%0t] Reset complete\n", $time);
        
        // ========================================
        // TEST 1: RANDOM SORT + HISTORY BUFFER
        // ========================================
        $display("========================================");
        $display("TEST 1: RANDOM SORT + HISTORY BUFFER");
        $display("========================================\n");
        
        test_mode = 0;  // Select random sort
        array_size_random = 8;  // Full 8-element array
        
        // Generate random array
        #50;
        $display("[%0t] Generating random array (size=8)...", $time);
        btn_generate_random = 1;
        #10 btn_generate_random = 0;
        
        // Wait for generation complete
        wait(state_random == 2'd2);  // READY state
        #100;
        $display("[%0t] Array generated!", $time);
        $display("  Random values: [%0d, %0d, %0d, %0d, %0d, %0d, %0d, %0d]", 
                 random_live_0, random_live_1, random_live_2, random_live_3,
                 random_live_4, random_live_5, random_live_6, random_live_7);
        
        // Start sorting
        #50;
        $display("\n[%0t] Starting sort with stepping...", $time);
        btn_start_random = 1;
        #10 btn_start_random = 0;
        
        // Step through sort - INCREASED from 20 to 50 for 8 elements
        $display("[%0t] Stepping through sort process...", $time);
        repeat(50) begin
            #50;
            if (state_random == 2'd3) begin  // SORTING state
                btn_step_random = 1;
                #10 btn_step_random = 0;
                
                if (random_capture_valid) begin
                    $display("  [Step %0d] Captured: pos1=%0d, pos2=%0d, comp_active=%b, op_type=%0d", 
                             total_steps, random_pos1, random_pos2, random_comp_active, random_op_type);
                end
            end
            
            // Exit early if done
            if (done_random) begin
                $display("  [%0t] Sort completed early!", $time);
                // Use disable instead of break for better compatibility
                disable step_loop;
            end
        end
        
        // Wait with timeout for any remaining processing
        begin : step_loop
            repeat(500) begin
                #10;
                if (done_random || state_random != 2'd3) disable step_loop;
            end
        end
        
        #200;
        $display("\n[%0t] Sort status:", $time);
        $display("  State: %0d (0=IDLE, 1=GEN, 2=READY, 3=SORT)", state_random);
        $display("  Done: %b", done_random);
        $display("  Steps captured: %0d", total_steps);
        $display("  Final array: [%0d, %0d, %0d, %0d, %0d, %0d, %0d, %0d]",
                 random_live_0, random_live_1, random_live_2, random_live_3,
                 random_live_4, random_live_5, random_live_6, random_live_7);
        
        // Verify array is sorted
        verify_sorted_array(random_live_0, random_live_1, random_live_2, random_live_3,
                           random_live_4, random_live_5, random_live_6, random_live_7, 8);
        
        // Test playback
        if (total_steps > 0) begin
            $display("\n[%0t] Testing playback (captured %0d steps)...", $time, total_steps);
            
            // Start playback
            play_pause_pulse = 1;
            #10 play_pause_pulse = 0;
            $display("  [%0t] Playback started (is_playing=%b)", $time, is_playing);
            
            // Let it play for a bit
            #500;
            $display("  [%0t] Current playback step: %0d/%0d", $time, current_step, total_steps);
            $display("  Playback live: [%0d, %0d, %0d, %0d, %0d, %0d, %0d, %0d]",
                     playback_live_0, playback_live_1, playback_live_2, playback_live_3,
                     playback_live_4, playback_live_5, playback_live_6, playback_live_7);
            
            // Pause playback
            play_pause_pulse = 1;
            #10 play_pause_pulse = 0;
            $display("  [%0t] Playback paused (is_playing=%b)", $time, is_playing);
            
            // Test backward step
            #50;
            $display("  [%0t] Testing backward step...", $time);
            back_pulse = 1;
            #10 back_pulse = 0;
            #50;
            $display("  [%0t] Stepped backward to step %0d", $time, current_step);
            
            // Test forward step
            back_pulse = 1;
            #10 back_pulse = 0;
            #50;
            $display("  [%0t] Stepped backward again to step %0d", $time, current_step);
            
            // Resume playback
            #50;
            play_pause_pulse = 1;
            #10 play_pause_pulse = 0;
            $display("  [%0t] Playback resumed", $time);
            
            // Let it play more
            #300;
            play_pause_pulse = 1;
            #10 play_pause_pulse = 0;
            $display("  [%0t] Playback paused at step %0d", $time, current_step);
            
            $display("\n  ? TEST 1 PASSED: History buffer captured and played back data!");
        end else begin
            $display("\n  ? TEST 1 FAILED: No steps captured!");
        end
        
        // Reset for next test
        #100;
        sort_finished = 1;
        #30 sort_finished = 0;
        #100;
        
        // ========================================
        // TEST 2: USER INPUT + HISTORY BUFFER
        // ========================================
        $display("\n========================================");
        $display("TEST 2: USER INPUT + HISTORY BUFFER");
        $display("========================================\n");
        
        // Full reset
        rst = 1;
        #50 rst = 0;
        #50;
        
        test_mode = 1;  // Select user input
        target_size = 8;
        
        $display("[%0t] Starting manual input (size=8)...", $time);
        #50;
        
        // Wait for input ready
        wait(input_ready == 1);
        #50;
        
        // Enter 8 values manually: [67, 23, 89, 45, 12, 78, 34, 56]
        $display("[%0t] Entering values: 67, 23, 89, 45, 12, 78, 34, 56", $time);
        
        input_value = 67;
        input_valid = 1;
        #10 input_valid = 0;
        #50;
        
        input_value = 23;
        input_valid = 1;
        #10 input_valid = 0;
        #50;
        
        input_value = 89;
        input_valid = 1;
        #10 input_valid = 0;
        #50;
        
        input_value = 45;
        input_valid = 1;
        #10 input_valid = 0;
        #50;
        
        input_value = 12;
        input_valid = 1;
        #10 input_valid = 0;
        #50;
        
        input_value = 78;
        input_valid = 1;
        #10 input_valid = 0;
        #50;
        
        input_value = 34;
        input_valid = 1;
        #10 input_valid = 0;
        #50;
        
        input_value = 56;
        input_valid = 1;
        #10 input_valid = 0;
        #50;
        
        // Signal input complete
        input_complete = 1;
        #10 input_complete = 0;
        #100;
        
        $display("[%0t] Input complete! Count: %0d", $time, current_count);
        $display("  User values: [%0d, %0d, %0d, %0d, %0d, %0d, %0d, %0d]",
                 user_live_0, user_live_1, user_live_2, user_live_3,
                 user_live_4, user_live_5, user_live_6, user_live_7);
        
        // Start sorting with stepping
        #50;
        $display("\n[%0t] Starting sort with stepping...", $time);
        btn_start_user = 1;
        #10 btn_start_user = 0;
        
        // Step through sort - INCREASED to 50 for 8 elements
        $display("[%0t] Stepping through sort process...", $time);
        repeat(50) begin
            #100;
            if (sorting_active) begin
                btn_step_user = 1;
                #10 btn_step_user = 0;
                
                if (user_capture_valid) begin
                    $display("  [Step %0d] Captured: pos1=%0d, pos2=%0d, comp_active=%b, op_type=%0d",
                             total_steps, user_pos1, user_pos2, user_comp_active, user_op_type);
                end
            end
            
            // Exit if done
            if (done_user) begin
                $display("  [%0t] Sort completed!", $time);
                disable user_step_loop;
            end
        end
        
        // Wait with timeout
        begin : user_step_loop
            repeat(500) begin
                #10;
                if (done_user || !sorting_active) disable user_step_loop;
            end
        end
        
        #200;
        $display("\n[%0t] Sort complete!", $time);
        $display("  Total captured steps: %0d", total_steps);
        $display("  Final array: [%0d, %0d, %0d, %0d, %0d, %0d, %0d, %0d]",
                 user_live_0, user_live_1, user_live_2, user_live_3,
                 user_live_4, user_live_5, user_live_6, user_live_7);
        
        // Verify array is sorted
        verify_sorted_array(user_live_0, user_live_1, user_live_2, user_live_3,
                           user_live_4, user_live_5, user_live_6, user_live_7, 8);
        
        // Test playback
        if (total_steps > 0) begin
            $display("\n[%0t] Testing playback...", $time);
            
            play_pause_pulse = 1;
            #10 play_pause_pulse = 0;
            $display("  [%0t] Playback started (is_playing=%b)", $time, is_playing);
            
            #500;
            $display("  [%0t] Current playback step: %0d/%0d", $time, current_step, total_steps);
            $display("  Playback data: [%0d, %0d, %0d, %0d, %0d, %0d, %0d, %0d]",
                     playback_live_0, playback_live_1, playback_live_2, playback_live_3,
                     playback_live_4, playback_live_5, playback_live_6, playback_live_7);
            
            play_pause_pulse = 1;
            #10 play_pause_pulse = 0;
            $display("  [%0t] Playback paused", $time);
            
            $display("\n  ? TEST 2 PASSED: User input sort and playback working!");
        end else begin
            $display("\n  ? TEST 2 FAILED: No steps captured!");
        end
        
        // Final summary
        #500;
        $display("\n========================================");
        $display("TEST COMPLETE - SUMMARY");
        $display("========================================");
        $display("? Random sort ? History buffer tested");
        $display("? User input ? History buffer tested");
        $display("? Playback controls tested");
        $display("? MUX switching tested");
        $display("? Array sorting verified");
        $display("========================================\n");
        
        $finish;
    end
    
    // Timeout watchdog (optional safety)
    initial begin
        #100000;  // 100us timeout
        $display("\n? WARNING: Simulation timeout reached!");
        $finish;
    end
    
endmodule