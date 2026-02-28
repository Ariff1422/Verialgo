`timescale 1ns / 1ps

// SNAPSHOT ANIMATION BUFFER

module delta_animation_buffer #(
    parameter DATA_WIDTH = 8,
    parameter ARRAY_SIZE = 8,
    parameter MAX_OPERATIONS = 64,
    parameter BASE_DELAY = 50000000
)(
    input wire clk,
    input wire rst,

    // Capture initial state once
    input wire capture_initial,
    input wire [DATA_WIDTH-1:0] init_array_0, init_array_1, init_array_2, init_array_3,
    input wire [DATA_WIDTH-1:0] init_array_4, init_array_5, init_array_6, init_array_7,
    input wire [3:0] num_bars,

    // Capture operations (on comparison transitions)
    input wire operation_valid,
    input wire write_enable,      
    input wire [2:0] write_addr,
    input wire [DATA_WIDTH-1:0] write_data,
    input wire [2:0] compare_pos1,
    input wire [2:0] compare_pos2,
    input wire comparison_active,
    input wire [3:0] merge_left_start,
    input wire [3:0] merge_left_end,
    input wire [3:0] merge_right_start,
    input wire [3:0] merge_right_end,
    input wire merge_active,
    input wire sort_finished,

    // Playback controls
    input wire play_pause_pulse,
    input wire back_pulse,
    input wire step_fwd_pulse,
    input wire go_to_first_pulse,
    input wire go_to_final_pulse,
    input wire [1:0] speed_select,

    // Playback outputs
    output reg [DATA_WIDTH-1:0] playback_array_0, playback_array_1, playback_array_2, playback_array_3,
    output reg [DATA_WIDTH-1:0] playback_array_4, playback_array_5, playback_array_6, playback_array_7,
    output reg [2:0] playback_pos1,
    output reg [2:0] playback_pos2,
    output reg playback_comparison_active,
    output reg [3:0] playback_merge_left_start,
    output reg [3:0] playback_merge_left_end,
    output reg [3:0] playback_merge_right_start,
    output reg [3:0] playback_merge_right_end,
    output reg playback_merge_active,
    output reg [5:0] current_operation,
    output reg [5:0] total_operations,
    output wire is_playing,
    
    // DEBUG OUTPUTS
    output wire debug_capture_pulse,
    output wire [5:0] debug_write_ptr,
    output wire debug_initial_captured
);

    
    // SNAPSHOT STORAGE
    
    (* ram_style = "block" *) reg [DATA_WIDTH-1:0] snapshot_array_0 [0:MAX_OPERATIONS-1];
    (* ram_style = "block" *) reg [DATA_WIDTH-1:0] snapshot_array_1 [0:MAX_OPERATIONS-1];
    (* ram_style = "block" *) reg [DATA_WIDTH-1:0] snapshot_array_2 [0:MAX_OPERATIONS-1];
    (* ram_style = "block" *) reg [DATA_WIDTH-1:0] snapshot_array_3 [0:MAX_OPERATIONS-1];
    (* ram_style = "block" *) reg [DATA_WIDTH-1:0] snapshot_array_4 [0:MAX_OPERATIONS-1];
    (* ram_style = "block" *) reg [DATA_WIDTH-1:0] snapshot_array_5 [0:MAX_OPERATIONS-1];
    (* ram_style = "block" *) reg [DATA_WIDTH-1:0] snapshot_array_6 [0:MAX_OPERATIONS-1];
    (* ram_style = "block" *) reg [DATA_WIDTH-1:0] snapshot_array_7 [0:MAX_OPERATIONS-1];
    
    // Metadata for each snapshot
    reg [2:0] snapshot_pos1 [0:MAX_OPERATIONS-1];
    reg [2:0] snapshot_pos2 [0:MAX_OPERATIONS-1];
    reg snapshot_comparison_active [0:MAX_OPERATIONS-1];
    reg [3:0] snapshot_merge_left_start [0:MAX_OPERATIONS-1];
    reg [3:0] snapshot_merge_left_end [0:MAX_OPERATIONS-1];
    reg [3:0] snapshot_merge_right_start [0:MAX_OPERATIONS-1];
    reg [3:0] snapshot_merge_right_end [0:MAX_OPERATIONS-1];
    reg snapshot_merge_active [0:MAX_OPERATIONS-1];
    
    
    // PLAYBACK STATE MACHINE
    localparam IDLE = 2'b00, PLAYING = 2'b01, PAUSED = 2'b10;
    reg [1:0] state;
    
    // CONTROL SIGNALS
    reg [5:0] write_ptr;
    reg [5:0] read_ptr;
    reg [31:0] timer;
    reg [31:0] delay_value;
    reg [3:0] saved_num_bars;
    reg initial_captured;
    
    reg prev_comparison_active;
    reg capture_this_cycle;
    reg prev_operation_valid;  
    
    reg [DATA_WIDTH-1:0] current_array [0:ARRAY_SIZE-1];
    
    integer i;

    // DEBUG OUTPUTS
    assign debug_capture_pulse = capture_this_cycle;
    assign debug_write_ptr = write_ptr;
    assign debug_initial_captured = initial_captured;

    // SPEED CONTROL
    always @(*) begin
        case (speed_select)
            2'b00: delay_value = BASE_DELAY * 2; // 0.5x
            2'b01: delay_value = BASE_DELAY; // 1.0x
            2'b10: delay_value = (BASE_DELAY * 2) / 3; // 1.5x
            2'b11: delay_value = BASE_DELAY / 2; // 2.0x
            default: delay_value = BASE_DELAY;
        endcase
    end

    // CAPTURE LOGIC
    always @(posedge clk) begin
        if (rst) begin
            write_ptr <= 0;
            total_operations <= 0;
            saved_num_bars <= 0;
            initial_captured <= 0;
            prev_comparison_active <= 0;
            capture_this_cycle <= 0;
            prev_operation_valid <= 0;  
            
            for (i = 0; i < ARRAY_SIZE; i = i + 1) begin
                current_array[i] <= 0;
            end
        end else begin
            capture_this_cycle <= 0;
            prev_comparison_active <= comparison_active;
            prev_operation_valid <= operation_valid;  
    
            // This happens *before* capture/reset logic
            if (write_enable && write_addr < ARRAY_SIZE) begin
                current_array[write_addr] <= write_data;
            end
    
            // Handle captures first.
            if (capture_initial && !initial_captured) begin
                current_array[0] <= init_array_0;
                current_array[1] <= init_array_1;
                current_array[2] <= init_array_2;
                current_array[3] <= init_array_3;
                current_array[4] <= init_array_4;
                current_array[5] <= init_array_5;
                current_array[6] <= init_array_6;
                current_array[7] <= init_array_7;
                saved_num_bars <= num_bars;
                write_ptr <= 0;
                total_operations <= 0;
                initial_captured <= 1;
                capture_this_cycle <= 1;
                
                snapshot_array_0[0] <= init_array_0;
                snapshot_array_1[0] <= init_array_1;
                snapshot_array_2[0] <= init_array_2;
                snapshot_array_3[0] <= init_array_3;
                snapshot_array_4[0] <= init_array_4;
                snapshot_array_5[0] <= init_array_5;
                snapshot_array_6[0] <= init_array_6;
                snapshot_array_7[0] <= init_array_7;
                snapshot_pos1[0] <= 0;
                snapshot_pos2[0] <= 0;
                snapshot_comparison_active[0] <= 0;
                snapshot_merge_left_start[0] <= 0;
                snapshot_merge_left_end[0] <= 0;
                snapshot_merge_right_start[0] <= 0;
                snapshot_merge_right_end[0] <= 0;
                snapshot_merge_active[0] <= 0;
                write_ptr <= 1;
                total_operations <= 1;
            
            end else if (operation_valid && !prev_operation_valid && write_ptr < MAX_OPERATIONS) begin
                
                snapshot_array_0[write_ptr] <= current_array[0];
                snapshot_array_1[write_ptr] <= current_array[1];
                snapshot_array_2[write_ptr] <= current_array[2];
                snapshot_array_3[write_ptr] <= current_array[3];
                snapshot_array_4[write_ptr] <= current_array[4];
                snapshot_array_5[write_ptr] <= current_array[5];
                snapshot_array_6[write_ptr] <= current_array[6];
                snapshot_array_7[write_ptr] <= current_array[7];
                
                snapshot_pos1[write_ptr] <= compare_pos1;
                snapshot_pos2[write_ptr] <= compare_pos2;
                snapshot_comparison_active[write_ptr] <= 1'b1;
                snapshot_merge_left_start[write_ptr] <= merge_left_start;
                snapshot_merge_left_end[write_ptr] <= merge_left_end;
                snapshot_merge_right_start[write_ptr] <= merge_right_start;
                snapshot_merge_right_end[write_ptr] <= merge_right_end;
                snapshot_merge_active[write_ptr] <= merge_active;
                
                write_ptr <= write_ptr + 1;
                total_operations <= write_ptr + 1;
                capture_this_cycle <= 1;
            end
    
            // Handle reset after capture logic.
            // This allows the final state (op_valid=1) to be saved
            // on the same cycle that sort_finished=1 is detected.
            if (sort_finished) begin
                write_ptr <= 0;
                initial_captured <= 0;
            end
        end
    end
    
    
    // PLAYBACK FSM (Unchanged from previous fix)
        always @(posedge clk) begin
        if (rst) begin
            read_ptr <= 0;
            timer <= 0;
            state <= IDLE;
            current_operation <= 0;
            
            playback_pos1 <= 0;
            playback_pos2 <= 0;
            playback_comparison_active <= 0;
            playback_merge_active <= 0;
            playback_merge_left_start <= 0;
            playback_merge_left_end <= 0;
            playback_merge_right_start <= 0;
            playback_merge_right_end <= 0;
            
            playback_array_0 <= 0;
            playback_array_1 <= 0;
            playback_array_2 <= 0;
            playback_array_3 <= 0;
            playback_array_4 <= 0;
            playback_array_5 <= 0;
            playback_array_6 <= 0;
            playback_array_7 <= 0;
            
        end else begin
            if (sort_finished) begin
                read_ptr <= 0;
                timer <= 0;
                state <= IDLE;
                current_operation <= 0;
            end else begin
                case (state)
                    IDLE: begin
                        read_ptr <= 0;
                        current_operation <= 0;
                        timer <= 0;
                        
                        if (total_operations > 0) begin
                            playback_array_0 <= snapshot_array_0[0];
                            playback_array_1 <= snapshot_array_1[0];
                            playback_array_2 <= snapshot_array_2[0];
                            playback_array_3 <= snapshot_array_3[0];
                            playback_array_4 <= snapshot_array_4[0];
                            playback_array_5 <= snapshot_array_5[0];
                            playback_array_6 <= snapshot_array_6[0];
                            playback_array_7 <= snapshot_array_7[0];
                            playback_pos1 <= snapshot_pos1[0];
                            playback_pos2 <= snapshot_pos2[0];
                            playback_comparison_active <= snapshot_comparison_active[0];
                            playback_merge_left_start <= snapshot_merge_left_start[0];
                            playback_merge_left_end <= snapshot_merge_left_end[0];
                            playback_merge_right_start <= snapshot_merge_right_start[0];
                            playback_merge_right_end <= snapshot_merge_right_end[0];
                            playback_merge_active <= snapshot_merge_active[0];
                        end
                        
                        if (play_pause_pulse && total_operations > 0) begin
                            state <= PLAYING;
                        end
                        // Go to first (unsorted) state
                        else if (go_to_first_pulse && read_ptr != 0) begin
                            read_ptr <= 0;
                            current_operation <= 0;
                            // Load snapshot 0
                            playback_array_0 <= snapshot_array_0[0];
                            playback_array_1 <= snapshot_array_1[0];
                            playback_array_2 <= snapshot_array_2[0];
                            playback_array_3 <= snapshot_array_3[0];
                            playback_array_4 <= snapshot_array_4[0];
                            playback_array_5 <= snapshot_array_5[0];
                            playback_array_6 <= snapshot_array_6[0];
                            playback_array_7 <= snapshot_array_7[0];
                            playback_pos1 <= snapshot_pos1[0];
                            playback_pos2 <= snapshot_pos2[0];
                            playback_comparison_active <= snapshot_comparison_active[0];
                            playback_merge_left_start <= snapshot_merge_left_start[0];
                            playback_merge_left_end <= snapshot_merge_left_end[0];
                            playback_merge_right_start <= snapshot_merge_right_start[0];
                            playback_merge_right_end <= snapshot_merge_right_end[0];
                            playback_merge_active <= snapshot_merge_active[0];
                        end
                        // Go to final (sorted) state
                        else if (go_to_final_pulse && total_operations > 0 && read_ptr != (total_operations - 1)) begin
                            read_ptr <= total_operations - 1;
                            current_operation <= total_operations - 1;
                            // Load last snapshot
                            playback_array_0 <= snapshot_array_0[total_operations - 1];
                            playback_array_1 <= snapshot_array_1[total_operations - 1];
                            playback_array_2 <= snapshot_array_2[total_operations - 1];
                            playback_array_3 <= snapshot_array_3[total_operations - 1];
                            playback_array_4 <= snapshot_array_4[total_operations - 1];
                            playback_array_5 <= snapshot_array_5[total_operations - 1];
                            playback_array_6 <= snapshot_array_6[total_operations - 1];
                            playback_array_7 <= snapshot_array_7[total_operations - 1];
                            playback_pos1 <= snapshot_pos1[total_operations - 1];
                            playback_pos2 <= snapshot_pos2[total_operations - 1];
                            playback_comparison_active <= snapshot_comparison_active[total_operations - 1];
                            playback_merge_left_start <= snapshot_merge_left_start[total_operations - 1];
                            playback_merge_left_end <= snapshot_merge_left_end[total_operations - 1];
                            playback_merge_right_start <= snapshot_merge_right_start[total_operations - 1];
                            playback_merge_right_end <= snapshot_merge_right_end[total_operations - 1];
                            playback_merge_active <= snapshot_merge_active[total_operations - 1];
                        end
                        // Step back one
                        else if (back_pulse && read_ptr > 0) begin
                            read_ptr <= read_ptr - 1;
                            
                            // Load previous snapshot
                            playback_array_0 <= snapshot_array_0[read_ptr - 1];
                            playback_array_1 <= snapshot_array_1[read_ptr - 1];
                            playback_array_2 <= snapshot_array_2[read_ptr - 1];
                            playback_array_3 <= snapshot_array_3[read_ptr - 1];
                            playback_array_4 <= snapshot_array_4[read_ptr - 1];
                            playback_array_5 <= snapshot_array_5[read_ptr - 1];
                            playback_array_6 <= snapshot_array_6[read_ptr - 1];
                            playback_array_7 <= snapshot_array_7[read_ptr - 1];
                            playback_pos1 <= snapshot_pos1[read_ptr - 1];
                            playback_pos2 <= snapshot_pos2[read_ptr - 1];
                            playback_comparison_active <= snapshot_comparison_active[read_ptr - 1];
                            playback_merge_left_start <= snapshot_merge_left_start[read_ptr - 1];
                            playback_merge_left_end <= snapshot_merge_left_end[read_ptr - 1];
                            playback_merge_right_start <= snapshot_merge_right_start[read_ptr - 1];
                            playback_merge_right_end <= snapshot_merge_right_end[read_ptr - 1];
                            playback_merge_active <= snapshot_merge_active[read_ptr - 1];
                            
                            current_operation <= read_ptr - 1;
                        end
                        // Step forward one
                        else if (step_fwd_pulse && read_ptr < (total_operations - 1)) begin
                            read_ptr <= read_ptr + 1;
                            
                            // Load next snapshot
                            playback_array_0 <= snapshot_array_0[read_ptr + 1];
                            playback_array_1 <= snapshot_array_1[read_ptr + 1];
                            playback_array_2 <= snapshot_array_2[read_ptr + 1];
                            playback_array_3 <= snapshot_array_3[read_ptr + 1];
                            playback_array_4 <= snapshot_array_4[read_ptr + 1];
                            playback_array_5 <= snapshot_array_5[read_ptr + 1];
                            playback_array_6 <= snapshot_array_6[read_ptr + 1];
                            playback_array_7 <= snapshot_array_7[read_ptr + 1];
                            playback_pos1 <= snapshot_pos1[read_ptr + 1];
                            playback_pos2 <= snapshot_pos2[read_ptr + 1];
                            playback_comparison_active <= snapshot_comparison_active[read_ptr + 1];
                            playback_merge_left_start <= snapshot_merge_left_start[read_ptr + 1];
                            playback_merge_left_end <= snapshot_merge_left_end[read_ptr + 1];
                            playback_merge_right_start <= snapshot_merge_right_start[read_ptr + 1];
                            playback_merge_right_end <= snapshot_merge_right_end[read_ptr + 1];
                            playback_merge_active <= snapshot_merge_active[read_ptr + 1];
                            
                            current_operation <= read_ptr + 1;
                        end
                    end
                    
                    PLAYING: begin
                        if (play_pause_pulse) begin
                            state <= PAUSED;
                            timer <= 0;
                        end
                        else if (read_ptr >= total_operations - 1) begin
                            state <= PAUSED;
                            timer <= 0;
                        end
                        else if (timer >= delay_value - 1) begin
                            timer <= 0;
                            if (read_ptr < total_operations - 1) begin
                                read_ptr <= read_ptr + 1;
                                
                                // Load next snapshot
                                playback_array_0 <= snapshot_array_0[read_ptr + 1];
                                playback_array_1 <= snapshot_array_1[read_ptr + 1];
                                playback_array_2 <= snapshot_array_2[read_ptr + 1];
                                playback_array_3 <= snapshot_array_3[read_ptr + 1];
                                playback_array_4 <= snapshot_array_4[read_ptr + 1];
                                playback_array_5 <= snapshot_array_5[read_ptr + 1];
                                playback_array_6 <= snapshot_array_6[read_ptr + 1];
                                playback_array_7 <= snapshot_array_7[read_ptr + 1];
                                playback_pos1 <= snapshot_pos1[read_ptr + 1];
                                playback_pos2 <= snapshot_pos2[read_ptr + 1];
                                playback_comparison_active <= snapshot_comparison_active[read_ptr + 1];
                                playback_merge_left_start <= snapshot_merge_left_start[read_ptr + 1];
                                playback_merge_left_end <= snapshot_merge_left_end[read_ptr + 1];
                                playback_merge_right_start <= snapshot_merge_right_start[read_ptr + 1];
                                playback_merge_right_end <= snapshot_merge_right_end[read_ptr + 1];
                                playback_merge_active <= snapshot_merge_active[read_ptr + 1];
                                
                                current_operation <= read_ptr + 1;
                            end
                        end else begin
                            timer <= timer + 1;
                        end
                    end
                    
                    PAUSED: begin
                        timer <= 0;
                        
                        if (play_pause_pulse && read_ptr < total_operations - 1) begin
                            state <= PLAYING;
                        end
                        // Go to first (unsorted) state
                        else if (go_to_first_pulse && read_ptr != 0) begin
                            read_ptr <= 0;
                            current_operation <= 0;
                            // Load snapshot 0
                            playback_array_0 <= snapshot_array_0[0];
                            playback_array_1 <= snapshot_array_1[0];
                            playback_array_2 <= snapshot_array_2[0];
                            playback_array_3 <= snapshot_array_3[0];
                            playback_array_4 <= snapshot_array_4[0];
                            playback_array_5 <= snapshot_array_5[0];
                            playback_array_6 <= snapshot_array_6[0];
                            playback_array_7 <= snapshot_array_7[0];
                            playback_pos1 <= snapshot_pos1[0];
                            playback_pos2 <= snapshot_pos2[0];
                            playback_comparison_active <= snapshot_comparison_active[0];
                            playback_merge_left_start <= snapshot_merge_left_start[0];
                            playback_merge_left_end <= snapshot_merge_left_end[0];
                            playback_merge_right_start <= snapshot_merge_right_start[0];
                            playback_merge_right_end <= snapshot_merge_right_end[0];
                            playback_merge_active <= snapshot_merge_active[0];
                        end
                        // Go to final (sorted) state
                        else if (go_to_final_pulse && total_operations > 0 && read_ptr != (total_operations - 1)) begin
                            read_ptr <= total_operations - 1;
                            current_operation <= total_operations - 1;
                            // Load last snapshot
                            playback_array_0 <= snapshot_array_0[total_operations - 1];
                            playback_array_1 <= snapshot_array_1[total_operations - 1];
                            playback_array_2 <= snapshot_array_2[total_operations - 1];
                            playback_array_3 <= snapshot_array_3[total_operations - 1];
                            playback_array_4 <= snapshot_array_4[total_operations - 1];
                            playback_array_5 <= snapshot_array_5[total_operations - 1];
                            playback_array_6 <= snapshot_array_6[total_operations - 1];
                            playback_array_7 <= snapshot_array_7[total_operations - 1];
                            playback_pos1 <= snapshot_pos1[total_operations - 1];
                            playback_pos2 <= snapshot_pos2[total_operations - 1];
                            playback_comparison_active <= snapshot_comparison_active[total_operations - 1];
                            playback_merge_left_start <= snapshot_merge_left_start[total_operations - 1];
                            playback_merge_left_end <= snapshot_merge_left_end[total_operations - 1];
                            playback_merge_right_start <= snapshot_merge_right_start[total_operations - 1];
                            playback_merge_right_end <= snapshot_merge_right_end[total_operations - 1];
                            playback_merge_active <= snapshot_merge_active[total_operations - 1];
                        end
                        // Step back one
                        else if (back_pulse && read_ptr > 0) begin
                            read_ptr <= read_ptr - 1;
                            
                            // Load previous snapshot
                            playback_array_0 <= snapshot_array_0[read_ptr - 1];
                            playback_array_1 <= snapshot_array_1[read_ptr - 1];
                            playback_array_2 <= snapshot_array_2[read_ptr - 1];
                            playback_array_3 <= snapshot_array_3[read_ptr - 1];
                            playback_array_4 <= snapshot_array_4[read_ptr - 1];
                            playback_array_5 <= snapshot_array_5[read_ptr - 1];
                            playback_array_6 <= snapshot_array_6[read_ptr - 1];
                            playback_array_7 <= snapshot_array_7[read_ptr - 1];
                            playback_pos1 <= snapshot_pos1[read_ptr - 1];
                            playback_pos2 <= snapshot_pos2[read_ptr - 1];
                            playback_comparison_active <= snapshot_comparison_active[read_ptr - 1];
                            playback_merge_left_start <= snapshot_merge_left_start[read_ptr - 1];
                            playback_merge_left_end <= snapshot_merge_left_end[read_ptr - 1];
                            playback_merge_right_start <= snapshot_merge_right_start[read_ptr - 1];
                            playback_merge_right_end <= snapshot_merge_right_end[read_ptr - 1];
                            playback_merge_active <= snapshot_merge_active[read_ptr - 1];
                            
                            current_operation <= read_ptr - 1;
                        end
                        // Step forward one
                        else if (step_fwd_pulse && read_ptr < (total_operations - 1)) begin
                            read_ptr <= read_ptr + 1;
                            
                            // Load next snapshot
                            playback_array_0 <= snapshot_array_0[read_ptr + 1];
                            playback_array_1 <= snapshot_array_1[read_ptr + 1];
                            playback_array_2 <= snapshot_array_2[read_ptr + 1];
                            playback_array_3 <= snapshot_array_3[read_ptr + 1];
                            playback_array_4 <= snapshot_array_4[read_ptr + 1];
                            playback_array_5 <= snapshot_array_5[read_ptr + 1];
                            playback_array_6 <= snapshot_array_6[read_ptr + 1];
                            playback_array_7 <= snapshot_array_7[read_ptr + 1];
                            playback_pos1 <= snapshot_pos1[read_ptr + 1];
                            playback_pos2 <= snapshot_pos2[read_ptr + 1];
                            playback_comparison_active <= snapshot_comparison_active[read_ptr + 1];
                            playback_merge_left_start <= snapshot_merge_left_start[read_ptr + 1];
                            playback_merge_left_end <= snapshot_merge_left_end[read_ptr + 1];
                            playback_merge_right_start <= snapshot_merge_right_start[read_ptr + 1];
                            playback_merge_right_end <= snapshot_merge_right_end[read_ptr + 1];
                            playback_merge_active <= snapshot_merge_active[read_ptr + 1];
                            
                            current_operation <= read_ptr + 1;
                        end
                    end
                    
                    default: state <= IDLE;
                endcase
            end
        end
    end
    
    assign is_playing = (state == PLAYING);

endmodule