`timescale 1ns / 1ps

//==============================================================================
// DELTA ANIMATION BUFFER TESTBENCH
// This testbench verifies what the buffer captures and how playback works
//==============================================================================

module delta_animation_tb;

    // Clock and reset
    reg clk;
    reg rst_n;
    
    // Capture signals
    reg capture_initial;
    reg [7:0] init_array_0, init_array_1, init_array_2, init_array_3;
    reg [7:0] init_array_4, init_array_5, init_array_6, init_array_7;
    reg [3:0] num_bars;
    
    // Operation capture
    reg operation_valid;
    reg [2:0] write_addr;
    reg [7:0] write_data;
    reg [2:0] compare_pos1;
    reg [2:0] compare_pos2;
    reg comparison_active;
    reg [3:0] merge_left_start;
    reg [3:0] merge_right_start;
    reg merge_active;
    reg sort_finished;
    
    // Playback controls
    reg play_pause_pulse;
    reg back_pulse;
    reg [1:0] speed_select;
    
    // Playback outputs
    wire [7:0] playback_array_0, playback_array_1, playback_array_2, playback_array_3;
    wire [7:0] playback_array_4, playback_array_5, playback_array_6, playback_array_7;
    wire [2:0] playback_pos1;
    wire [2:0] playback_pos2;
    wire playback_comparison_active;
    wire [3:0] playback_merge_left_start;
    wire [3:0] playback_merge_right_start;
    wire playback_merge_active;
    wire [5:0] current_operation;
    wire [5:0] total_operations;
    wire is_playing;
    
    // Debug outputs
    wire debug_capture_pulse;
    wire [5:0] debug_write_ptr;
    wire debug_initial_captured;
    
    // DUT instantiation
    delta_animation_buffer #(
        .DATA_WIDTH(8),
        .ARRAY_SIZE(8),
        .MAX_OPERATIONS(32),
        .BASE_DELAY(100)  // Fast for simulation
    ) dut (
        .clk(clk),
        .rst_n(rst_n),
        .capture_initial(capture_initial),
        .init_array_0(init_array_0), .init_array_1(init_array_1),
        .init_array_2(init_array_2), .init_array_3(init_array_3),
        .init_array_4(init_array_4), .init_array_5(init_array_5),
        .init_array_6(init_array_6), .init_array_7(init_array_7),
        .num_bars(num_bars),
        .operation_valid(operation_valid),
        .write_addr(write_addr),
        .write_data(write_data),
        .compare_pos1(compare_pos1),
        .compare_pos2(compare_pos2),
        .comparison_active(comparison_active),
        .merge_left_start(merge_left_start),
        .merge_right_start(merge_right_start),
        .merge_active(merge_active),
        .sort_finished(sort_finished),
        .play_pause_pulse(play_pause_pulse),
        .back_pulse(back_pulse),
        .speed_select(speed_select),
        .playback_array_0(playback_array_0), .playback_array_1(playback_array_1),
        .playback_array_2(playback_array_2), .playback_array_3(playback_array_3),
        .playback_array_4(playback_array_4), .playback_array_5(playback_array_5),
        .playback_array_6(playback_array_6), .playback_array_7(playback_array_7),
        .playback_pos1(playback_pos1),
        .playback_pos2(playback_pos2),
        .playback_comparison_active(playback_comparison_active),
        .playback_merge_left_start(playback_merge_left_start),
        .playback_merge_right_start(playback_merge_right_start),
        .playback_merge_active(playback_merge_active),
        .current_operation(current_operation),
        .total_operations(total_operations),
        .is_playing(is_playing),
        .debug_capture_pulse(debug_capture_pulse),
        .debug_write_ptr(debug_write_ptr),
        .debug_initial_captured(debug_initial_captured)
    );
    
    // Clock generation (10ns period = 100MHz)
    initial clk = 0;
    always #5 clk = ~clk;
    
    // Test stimulus
    initial begin
        $dumpfile("delta_animation.vcd");
        $dumpvars(0, delta_animation_tb);
        
        // Also dump internal buffer contents for first few entries
        $dumpvars(1, dut.delta_buffer[0]);
        $dumpvars(1, dut.delta_buffer[1]);
        $dumpvars(1, dut.delta_buffer[2]);
        $dumpvars(1, dut.delta_buffer[3]);
        $dumpvars(1, dut.delta_buffer[4]);
        $dumpvars(1, dut.playback_working[0]);
        $dumpvars(1, dut.playback_working[1]);
        $dumpvars(1, dut.playback_working[2]);
        $dumpvars(1, dut.playback_working[3]);
        
        // Initialize signals
        rst_n = 0;
        capture_initial = 0;
        init_array_0 = 0; init_array_1 = 0; init_array_2 = 0; init_array_3 = 0;
        init_array_4 = 0; init_array_5 = 0; init_array_6 = 0; init_array_7 = 0;
        num_bars = 4;
        operation_valid = 0;
        write_addr = 0;
        write_data = 0;
        compare_pos1 = 0;
        compare_pos2 = 0;
        comparison_active = 0;
        merge_left_start = 0;
        merge_right_start = 0;
        merge_active = 0;
        sort_finished = 0;
        play_pause_pulse = 0;
        back_pulse = 0;
        speed_select = 2'b01;  // Normal speed
        
        $display("\n=== DELTA ANIMATION BUFFER TEST ===\n");
        
        // Reset
        #20;
        rst_n = 1;
        #20;
        
        //======================================================================
        // TEST 1: Capture initial array
        //======================================================================
        $display("TEST 1: Capturing initial array [50, 30, 70, 20]");
        init_array_0 = 50;
        init_array_1 = 30;
        init_array_2 = 70;
        init_array_3 = 20;
        num_bars = 4;
        
        #10;
        capture_initial = 1;
        #10;
        capture_initial = 0;
        #20;
        
        if (debug_initial_captured) 
            $display("? Initial capture successful");
        else
            $display("? Initial capture FAILED");
        
        //======================================================================
        // TEST 2: Simulate a comparison and swap (indices 0 and 1)
        //======================================================================
        $display("\nTEST 2: Simulating comparison between indices 0 and 1");
        $display("Before: [50, 30, 70, 20]");
        $display("After swap: [30, 50, 70, 20]");
        
        // Start comparison
        #10;
        compare_pos1 = 0;
        compare_pos2 = 1;
        comparison_active = 1;
        $display("  Comparison started at t=%0t", $time);
        
        #50;  // Wait during comparison
        
        // End comparison and write result
        comparison_active = 0;
        operation_valid = 1;
        write_addr = 0;
        write_data = 30;  // Smaller value goes to position 0
        #10;
        
        if (debug_capture_pulse)
            $display("  ? Captured operation at write_ptr=%0d", debug_write_ptr);
        else
            $display("  ? Operation NOT captured!");
        
        operation_valid = 0;
        #10;
        
        // Write the other value
        operation_valid = 1;
        write_addr = 1;
        write_data = 50;  // Larger value goes to position 1
        #10;
        
        if (debug_capture_pulse)
            $display("  ? Captured operation at write_ptr=%0d", debug_write_ptr);
        
        operation_valid = 0;
        #20;
        
        //======================================================================
        // TEST 3: Another comparison (indices 2 and 3)
        //======================================================================
        $display("\nTEST 3: Simulating comparison between indices 2 and 3");
        $display("Before: [30, 50, 70, 20]");
        $display("After swap: [30, 50, 20, 70]");
        
        compare_pos1 = 2;
        compare_pos2 = 3;
        comparison_active = 1;
        $display("  Comparison started at t=%0t", $time);
        
        #50;
        
        comparison_active = 0;
        operation_valid = 1;
        write_addr = 2;
        write_data = 20;
        #10;
        
        if (debug_capture_pulse)
            $display("  ? Captured operation at write_ptr=%0d", debug_write_ptr);
        
        operation_valid = 0;
        #10;
        
        operation_valid = 1;
        write_addr = 3;
        write_data = 70;
        #10;
        operation_valid = 0;
        #20;
        
        //======================================================================
        // TEST 4: Check total operations captured
        //======================================================================
        $display("\nTEST 4: Checking captured operations");
        $display("  Total operations captured: %0d", total_operations);
        $display("  Expected: ~2 (one per comparison)");
        
        if (total_operations >= 2)
            $display("  ? Reasonable number of operations captured");
        else
            $display("  ? Too few operations captured");
        
        //======================================================================
        // TEST 5: Start playback
        //======================================================================
        $display("\nTEST 5: Starting playback");
        #10;
        play_pause_pulse = 1;
        #10;
        play_pause_pulse = 0;
        #20;
        
        if (is_playing)
            $display("  ? Playback started");
        else
            $display("  ? Playback did NOT start");
        
        // Monitor playback for several operations
        $display("\n  Monitoring playback:");
        $display("  Op# | Array State");
        $display("  ----|------------------------------------------");
        
        repeat(10) begin
            #150;  // Wait for operation to advance
            $display("  %2d  | [%2d, %2d, %2d, %2d] pos1=%0d pos2=%0d active=%0b",
                     current_operation,
                     playback_array_0, playback_array_1, 
                     playback_array_2, playback_array_3,
                     playback_pos1, playback_pos2,
                     playback_comparison_active);
        end
        
        //======================================================================
        // TEST 6: Pause and step backward
        //======================================================================
        $display("\nTEST 6: Pausing playback");
        play_pause_pulse = 1;
        #10;
        play_pause_pulse = 0;
        #20;
        
        if (!is_playing)
            $display("  ? Playback paused at operation %0d", current_operation);
        else
            $display("  ? Playback still running");
        
        $display("\n  Stepping backward:");
        repeat(3) begin
            back_pulse = 1;
            #10;
            back_pulse = 0;
            #30;
            $display("  Op %2d: [%2d, %2d, %2d, %2d]",
                     current_operation,
                     playback_array_0, playback_array_1,
                     playback_array_2, playback_array_3);
        end
        
        //======================================================================
        // TEST 7: Verify buffer contents
        //======================================================================
        $display("\nTEST 7: Examining buffer contents");
        $display("  Delta buffer format: {op_type[4], reserved, addr[3], data[8], ...}");
        $display("  ");
        $display("  Entry | Hex Value        | Op Type | Addr | Data | Pos1 | Pos2");
        $display("  ------|------------------|---------|------|------|------|-----");
        
        // Display first 5 captured operations
        repeat(5) begin:shad
            automatic integer i;
            for (i = 0; i < 5 && i < total_operations; i = i + 1) begin
                #1;  // Small delay for display
            end
        end
        
        //======================================================================
        // TEST 8: Test sort_finished reset
        //======================================================================
        $display("\nTEST 8: Testing sort_finished reset");
        #50;
        sort_finished = 1;
        #10;
        sort_finished = 0;
        #20;
        
        if (debug_write_ptr == 0)
            $display("  ? Buffer reset correctly");
        else
            $display("  ? Buffer NOT reset (write_ptr=%0d)", debug_write_ptr);
        
        //======================================================================
        // Summary
        //======================================================================
        #100;
        $display("\n=== TEST COMPLETE ===");
        $display("\nKey Observations:");
        $display("  - Check if comparisons are being captured");
        $display("  - Check if playback reconstructs array correctly");
        $display("  - Check if stepping works properly");
        $display("  - Look at waveform to see capture_pulse timing");
        $display("\nView waveform with: gtkwave delta_animation.vcd\n");
        
        $finish;
    end
    
    // Timeout watchdog
    initial begin
        #50000;
        $display("\n*** TIMEOUT - Test took too long ***");
        $finish;
    end
    
    // Monitor for debugging
    always @(posedge debug_capture_pulse) begin
        $display("  [CAPTURE] t=%0t write_ptr=%0d comp_active=%0b addr=%0d data=%0d",
                 $time, debug_write_ptr, comparison_active, write_addr, write_data);
    end

endmodule