`timescale 1ns / 1ps

//==============================================================================
// BUFFER INSPECTION TESTBENCH
// Simplified test focusing on exactly what gets captured and stored
//==============================================================================

module buffer_inspection_tb;

    reg clk;
    reg rst_n;
    
    // Capture
    reg capture_initial;
    reg [7:0] init_array [0:3];  // Using array for clarity
    reg [3:0] num_bars;
    
    reg operation_valid;
    reg [2:0] write_addr;
    reg [7:0] write_data;
    reg [2:0] compare_pos1, compare_pos2;
    reg comparison_active;
    reg prev_comparison_active;  // Track edge
    
    // Playback
    reg play_pause_pulse;
    wire [7:0] pb_array [0:3];
    wire [5:0] total_ops;
    wire is_playing;
    
    // Debug
    wire capture_pulse;
    wire [5:0] write_ptr;
    wire init_captured;
    
    wire [7:0] playback_array_0, playback_array_1, playback_array_2, playback_array_3;
        wire [7:0] playback_array_4, playback_array_5, playback_array_6, playback_array_7;
        wire [2:0] playback_pos1, playback_pos2;
        wire playback_comparison_active;
        wire [3:0] playback_merge_left_start, playback_merge_right_start;
        wire playback_merge_active;
        wire [5:0] current_operation;
        
    
    // Unpack outputs
    assign pb_array[0] = playback_array_0;
    assign pb_array[1] = playback_array_1;
    assign pb_array[2] = playback_array_2;
    assign pb_array[3] = playback_array_3;
    
    
        wire [5:0] total_operations;
    assign total_ops = total_operations;
    
    delta_animation_buffer #(
        .DATA_WIDTH(8),
        .ARRAY_SIZE(8),
        .MAX_OPERATIONS(32),
        .BASE_DELAY(50)  // Very fast for testing
    ) dut (
        .clk(clk),
        .rst_n(rst_n),
        .capture_initial(capture_initial),
        .init_array_0(init_array[0]), .init_array_1(init_array[1]),
        .init_array_2(init_array[2]), .init_array_3(init_array[3]),
        .init_array_4(8'd0), .init_array_5(8'd0),
        .init_array_6(8'd0), .init_array_7(8'd0),
        .num_bars(num_bars),
        .operation_valid(operation_valid),
        .write_addr(write_addr),
        .write_data(write_data),
        .compare_pos1(compare_pos1),
        .compare_pos2(compare_pos2),
        .comparison_active(comparison_active),
        .merge_left_start(4'd0),
        .merge_right_start(4'd0),
        .merge_active(1'b0),
        .sort_finished(1'b0),
        .play_pause_pulse(play_pause_pulse),
        .back_pulse(1'b0),
        .speed_select(2'b01),
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
        .debug_capture_pulse(capture_pulse),
        .debug_write_ptr(write_ptr),
        .debug_initial_captured(init_captured)
    );
    
    initial clk = 0;
    always #5 clk = ~clk;
    
    // Task to perform a comparison (the key capture moment!)
    task do_comparison(
        input [2:0] pos1,
        input [2:0] pos2,
        input [7:0] result_val,
        input [2:0] result_addr
    );
    begin
        $display("\n--- COMPARISON: pos[%0d] vs pos[%0d] ---", pos1, pos2);
        
        // Start comparison
        compare_pos1 = pos1;
        compare_pos2 = pos2;
        comparison_active = 1;
        operation_valid = 0;
        
        $display("  [START] comparison_active=1");
        #30;  // Hold comparison active
        
        // End comparison (THIS IS THE KEY MOMENT!)
        comparison_active = 0;
        $display("  [END]   comparison_active=0 (trigger capture)");
        #10;
        
        // Write result
        operation_valid = 1;
        write_addr = result_addr;
        write_data = result_val;
        $display("  [WRITE] addr=%0d data=%0d", result_addr, result_val);
        #10;
        operation_valid = 0;
        
        #20;
        $display("  Buffer write_ptr=%0d, total_ops=%0d", write_ptr, total_ops);
    end
    endtask
    
    // Task to display buffer entry
    task display_buffer_entry(input integer idx);
    begin:shaded
        automatic reg [31:0] entry;
        automatic reg [3:0] op_type;
        automatic reg [2:0] addr;
        automatic reg [7:0] data;
        automatic reg [2:0] pos1, pos2;
        
        entry = dut.delta_buffer[idx];
        op_type = entry[31:28];
        addr = entry[26:24];
        data = entry[23:16];
        pos1 = entry[13:11];
        pos2 = entry[10:8];
        
        case (op_type)
            4'd1: $display("  [%0d] WRITE:   addr=%0d data=%3d", idx, addr, data);
            4'd2: $display("  [%0d] COMPARE: addr=%0d data=%3d pos1=%0d pos2=%0d", 
                          idx, addr, data, pos1, pos2);
            4'd3: $display("  [%0d] MERGE:   (not used in this test)", idx);
            default: $display("  [%0d] UNKNOWN: op=%0d", idx, op_type);
        endcase
    end
    endtask
    
    integer i;
    
    initial begin
        $dumpfile("buffer_inspection.vcd");
        $dumpvars(0, buffer_inspection_tb);
        
        // Dump buffer contents
        for (i = 0; i < 8; i = i + 1) begin
            $dumpvars(0, dut.delta_buffer[i]);
        end
        
        $display("\n??????????????????????????????????????????????????");
        $display("?   DELTA BUFFER INSPECTION TEST                ?");
        $display("??????????????????????????????????????????????????\n");
        
        // Initialize
        rst_n = 0;
        capture_initial = 0;
        init_array[0] = 8'd50;
        init_array[1] = 8'd30;
        init_array[2] = 8'd70;
        init_array[3] = 8'd20;
        num_bars = 4;
        operation_valid = 0;
        write_addr = 0;
        write_data = 0;
        compare_pos1 = 0;
        compare_pos2 = 0;
        comparison_active = 0;
        prev_comparison_active = 0;
        play_pause_pulse = 0;
        
        #20;
        rst_n = 1;
        #20;
        
        //======================================================================
        // PHASE 1: CAPTURE INITIAL STATE
        //======================================================================
        $display("??????????????????????????????????????????????????");
        $display("? PHASE 1: CAPTURE INITIAL STATE                ?");
        $display("??????????????????????????????????????????????????");
        $display("\nInitial Array: [%0d, %0d, %0d, %0d]", 
                 init_array[0], init_array[1], init_array[2], init_array[3]);
        
        capture_initial = 1;
        #10;
        capture_initial = 0;
        #30;
        
        $display("? Initial captured = %0b", init_captured);
        $display("  Buffer write_ptr = %0d", write_ptr);
        
        //======================================================================
        // PHASE 2: SIMULATE SORT OPERATIONS
        //======================================================================
        $display("\n??????????????????????????????????????????????????");
        $display("? PHASE 2: SIMULATE SORT OPERATIONS             ?");
        $display("??????????????????????????????????????????????????");
        
        // First comparison: swap 0 and 1 (50 vs 30 -> 30, 50)
        do_comparison(3'd0, 3'd1, 8'd30, 3'd0);
        
        // Second comparison: swap 2 and 3 (70 vs 20 -> 20, 70)
        do_comparison(3'd2, 3'd3, 8'd20, 3'd2);
        
        #50;
        
        //======================================================================
        // PHASE 3: INSPECT BUFFER CONTENTS
        //======================================================================
        $display("\n??????????????????????????????????????????????????");
        $display("? PHASE 3: BUFFER CONTENTS                      ?");
        $display("??????????????????????????????????????????????????");
        $display("\nTotal operations captured: %0d\n", total_ops);
        
        if (total_ops > 0) begin
            $display("Buffer Entries:");
            for (i = 0; i < total_ops && i < 8; i = i + 1) begin
                display_buffer_entry(i);
            end
        end else begin
            $display("? WARNING: No operations captured!");
        end
        
        //======================================================================
        // PHASE 4: TEST PLAYBACK
        //======================================================================
        $display("\n??????????????????????????????????????????????????");
        $display("? PHASE 4: PLAYBACK TEST                        ?");
        $display("??????????????????????????????????????????????????\n");
        
        if (total_ops == 0) begin
            $display("? Cannot test playback - no operations captured!");
        end else begin
            $display("Starting playback...\n");
            play_pause_pulse = 1;
            #10;
            play_pause_pulse = 0;
            #20;
            
            $display("Step | Array State                | Pos1 | Pos2 | Cmp");
            $display("-----|----------------------------|------|------|-----");
            
            // Monitor several playback steps
            for (i = 0; i < 8; i = i + 1) begin
                #100;  // Wait for operation advance
                $display(" %2d  | [%3d, %3d, %3d, %3d]      |  %0d   |  %0d   | %0b",
                         current_operation,
                         pb_array[0], pb_array[1], pb_array[2], pb_array[3],
                         playback_pos1, playback_pos2,
                         playback_comparison_active);
                         
                if (current_operation >= total_ops - 1) begin
                    $display("\n? Reached end of captured operations");
                    i = 8;  // Break loop
                end
            end
        end
        
        //======================================================================
        // PHASE 5: DIAGNOSIS
        //======================================================================
        $display("\n??????????????????????????????????????????????????");
        $display("? DIAGNOSIS                                     ?");
        $display("??????????????????????????????????????????????????\n");
        
        $display("Expected behavior:");
        $display("  - Should capture on comparison END (active 1?0)");
        $display("  - Should capture ~2 operations (one per comparison)");
        $display("  - Playback should show array changes\n");
        
        $display("Actual results:");
        $display("  - Total operations: %0d", total_ops);
        $display("  - Buffer write pointer: %0d", write_ptr);
        $display("  - Playback working: %0b\n", is_playing);
        
        if (total_ops == 0) begin
            $display("? PROBLEM DETECTED: No captures!");
            $display("\nPossible causes:");
            $display("  1. Capture trigger logic not working");
            $display("  2. comparison_active edge not detected");
            $display("  3. operation_valid not set correctly");
            $display("\nCheck waveform at these signals:");
            $display("  - dut.prev_comparison_active");
            $display("  - dut.comparison_active");
            $display("  - dut.operation_valid");
            $display("  - dut.capture_this_cycle");
        end else if (total_ops < 2) begin
            $display("? WARNING: Fewer captures than expected");
        end else begin
            $display("? Capture count looks reasonable");
        end
        
        $display("\n??????????????????????????????????????????????????");
        $display("? TEST COMPLETE - Check waveform VCD file      ?");
        $display("??????????????????????????????????????????????????\n");
        
        #100;
        $finish;
    end
    
    // Monitor captures in real-time
    always @(posedge clk) begin
        prev_comparison_active <= comparison_active;
        
        if (capture_pulse) begin
            $display("  ? CAPTURE at t=%0t: write_ptr now %0d", $time, write_ptr);
        end
    end

endmodule