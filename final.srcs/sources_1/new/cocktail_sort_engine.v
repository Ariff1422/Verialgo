`timescale 1ns / 1ps

// COCKTAIL SORT ENGINE (Bidirectional Bubble Sort)
module cocktail_sort_engine #(
    parameter DATA_WIDTH = 8,
    parameter MAX_ARRAY_SIZE = 8,
    parameter ADDR_WIDTH = 3
)(
    input wire clk,
    input wire rst,
    input wire start,
    input wire [ADDR_WIDTH:0] array_length,
    input wire step_forward,
    input wire step_backward,

    input wire init_mode,
    input wire [ADDR_WIDTH-1:0] ext_addr,
    input wire [DATA_WIDTH-1:0] ext_data,
    input wire ext_we,

    output reg [ADDR_WIDTH-1:0] live_addr,
    output reg [DATA_WIDTH-1:0] live_data_in,
    input wire [DATA_WIDTH-1:0] live_data_out,
    output reg live_we,

    output reg [ADDR_WIDTH-1:0] temp_addr,
    output reg [DATA_WIDTH-1:0] temp_data_in,
    input wire [DATA_WIDTH-1:0] temp_data_out,
    output reg temp_we,

    output reg done,
    output reg sorting,
    output wire busy,
    output reg [ADDR_WIDTH-1:0] current_pos1,
    output reg [ADDR_WIDTH-1:0] current_pos2,
    output reg comparison_active,
    output reg swap_occurred,
    output reg [3:0] current_pass,
    output reg [3:0] current_merge,

    output wire [3:0] debug_pass_state,
    output wire [3:0] debug_merge_state,

    // ENHANCED CAPTURE OUTPUTS 
    output reg [1:0] operation_type,
    output reg capture_valid,

    // Additional observability signals
    output reg [ADDR_WIDTH:0] capture_merge_size,
    output reg [ADDR_WIDTH:0] capture_left_start,
    output reg [ADDR_WIDTH:0] capture_left_idx,
    output reg [ADDR_WIDTH:0] capture_right_idx,
    output reg [ADDR_WIDTH:0] capture_write_idx,
    output reg [DATA_WIDTH-1:0] capture_left_val,
    output reg [DATA_WIDTH-1:0] capture_right_val,
    output reg capture_src_is_live,
    output reg capture_left_done,
    output reg capture_right_done
    
);

    // State definitions
    localparam IDLE = 4'd0;
    localparam INIT = 4'd1;
    localparam FORWARD_START = 4'd2;
    localparam FORWARD_FETCH_LEFT = 4'd3;
    localparam FORWARD_WAIT_LEFT = 4'd4;
    localparam FORWARD_FETCH_RIGHT = 4'd5;
    localparam FORWARD_WAIT_RIGHT = 4'd6;
    localparam FORWARD_COMPARE = 4'd7;
    localparam FORWARD_SWAP = 4'd8;
    localparam BACKWARD_START = 4'd9;
    localparam BACKWARD_FETCH_LEFT = 4'd10;
    localparam BACKWARD_WAIT_LEFT = 4'd11;
    localparam BACKWARD_FETCH_RIGHT = 4'd12;
    localparam BACKWARD_WAIT_RIGHT = 4'd13;
    localparam BACKWARD_COMPARE = 4'd14;
    localparam BACKWARD_SWAP = 4'd15;

    // Operation types
    localparam OP_IDLE = 2'd0;
    localparam OP_COMPARE = 2'd1;
    localparam OP_SWAP = 2'd2;
    localparam OP_COPY = 2'd3;

    // State registers
    reg [3:0] main_state;
    reg [3:0] sub_state; 

    // Cocktail sort specific registers
    reg [ADDR_WIDTH:0] current_idx;
    reg [ADDR_WIDTH:0] start_idx;
    reg [ADDR_WIDTH:0] end_idx; 
    reg [DATA_WIDTH-1:0] left_val, right_val;
    reg forward_direction;
    reg swap_made;

    // Step control
    reg prev_step_forward;
    reg step_edge_detected;

    // Debug outputs
    assign debug_pass_state = main_state;
    assign debug_merge_state = sub_state;
    assign busy = sorting;

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            main_state <= IDLE;
            sub_state <= 4'd0;
            done <= 0;
            sorting <= 0;
            current_pass <= 0;
            current_merge <= 0;
            live_we <= 0;
            temp_we <= 0;
            comparison_active <= 0;
            swap_occurred <= 0;
            current_pos1 <= 0;
            current_pos2 <= 0;
            live_addr <= 0;
            live_data_in <= 0;
            temp_addr <= 0;
            temp_data_in <= 0;
            
            current_idx <= 0;
            start_idx <= 0;
            end_idx <= 0;
            left_val <= 0;
            right_val <= 0;
            forward_direction <= 1;
            swap_made <= 0;
            
            prev_step_forward <= 0;
            step_edge_detected <= 0;

            operation_type <= OP_IDLE;
            capture_valid <= 0;
            capture_merge_size <= 0;
            capture_left_start <= 0;
            capture_left_idx <= 0;
            capture_right_idx <= 0;
            capture_write_idx <= 0;
            capture_left_val <= 0;
            capture_right_val <= 0;
            capture_src_is_live <= 1;
            capture_left_done <= 0;
            capture_right_done <= 0;
        end else begin
            // Edge detection for step control
            if (step_forward && !prev_step_forward) begin
                step_edge_detected <= 1;
            end else begin
                step_edge_detected <= 0;
            end
            prev_step_forward <= step_forward;

            if (!init_mode) begin
                live_we <= 0;
                temp_we <= 0;
                swap_occurred <= 0;
                capture_valid <= 0;

                case (main_state)
                    IDLE: begin
                        done <= 0;
                        sorting <= 0;
                        comparison_active <= 0;
                        operation_type <= OP_IDLE;
                        if (start && array_length > 1) begin
                            main_state <= INIT;
                            sorting <= 1;
                            current_pass <= 0;
                        end
                    end

                    INIT: begin
                        start_idx <= 0;
                        end_idx <= array_length;
                        current_idx <= 0;
                        forward_direction <= 1;
                        swap_made <= 0;
                        main_state <= FORWARD_START;
                        
                        capture_valid <= 1;
                        capture_src_is_live <= 1;
                        capture_left_start <= 0;
                        capture_right_idx <= array_length;
                    end

                    // FORWARD PASS 
                    FORWARD_START: begin
                        if (start_idx >= end_idx - 1) begin
                            // Go to IDLE, set done flags
                            main_state <= IDLE;
                            done <= 1;
                            sorting <= 0;
                        end else begin
                            current_idx <= start_idx;
                            swap_made <= 0; // Reset swap flag for this pass
                            main_state <= FORWARD_FETCH_LEFT;
                            operation_type <= OP_COMPARE;
                        end
                        
                        capture_valid <= 1;
                        capture_left_start <= start_idx;
                        capture_right_idx <= end_idx;
                    end

                    FORWARD_FETCH_LEFT: begin
                        if (current_idx < end_idx - 1) begin
                            live_addr <= current_idx;
                            main_state <= FORWARD_WAIT_LEFT;
                        end else begin
                            // Finished forward pass
                            if (!swap_made) begin
                                // Go to IDLE, set done flags
                                main_state <= IDLE;
                                done <= 1;
                                sorting <= 0;
                            end else begin
                                end_idx <= end_idx - 1;
                                main_state <= BACKWARD_START;
                            end
                        end
                    end

                    FORWARD_WAIT_LEFT: begin
                        main_state <= FORWARD_FETCH_RIGHT;
                    end

                    FORWARD_FETCH_RIGHT: begin
                        left_val <= live_data_out;
                        live_addr <= current_idx + 1;
                        main_state <= FORWARD_WAIT_RIGHT;
                    end

                    FORWARD_WAIT_RIGHT: begin
                        main_state <= FORWARD_COMPARE;
                    end

                    FORWARD_COMPARE: begin
                        right_val <= live_data_out;
                        current_pos1 <= current_idx;
                        current_pos2 <= current_idx + 1;
                        comparison_active <= 1;
                        
                        capture_left_idx <= current_idx;
                        capture_left_val <= left_val;
                        capture_right_val <= live_data_out;
                        
                        if (step_edge_detected) begin
                            main_state <= FORWARD_SWAP;
                        end
                    end

                    FORWARD_SWAP: begin
                        comparison_active <= 0;
                        operation_type <= OP_SWAP;
                        
                        if (left_val > right_val) begin
                            // Swap needed
                            swap_occurred <= 1;
                            swap_made <= 1;
                            capture_valid <= 1;
                            
                            if (sub_state == 0) begin
                                live_addr <= current_idx;
                                live_data_in <= right_val;
                                live_we <= 1;
                                capture_write_idx <= current_idx;
                                sub_state <= 1;
                            end else begin
                                live_addr <= current_idx + 1;
                                live_data_in <= left_val;
                                live_we <= 1; 
                                capture_write_idx <= current_idx + 1;
                                sub_state <= 0; 
                                current_idx <= current_idx + 1;
                                main_state <= FORWARD_FETCH_LEFT;
                            end
                        end else begin
                            // No swap needed
                            current_idx <= current_idx + 1;
                            main_state <= FORWARD_FETCH_LEFT;
                            sub_state <= 0;
                        end
                    end

                    // BACKWARD PASS 
                    BACKWARD_START: begin
                        if (start_idx >= end_idx - 1) begin
                            // Go to IDLE, set done flags
                            main_state <= IDLE;
                            done <= 1;
                            sorting <= 0;
                        end else begin
                            current_idx <= end_idx - 1;
                            swap_made <= 0; // Reset swap flag for this pass
                            main_state <= BACKWARD_FETCH_RIGHT;
                            operation_type <= OP_COMPARE;
                            current_pass <= current_pass + 1;
                        end
                        
                        capture_valid <= 1;
                        capture_left_start <= start_idx;
                        capture_right_idx <= end_idx;
                    end

                    BACKWARD_FETCH_RIGHT: begin
                        if (current_idx > start_idx) begin
                            live_addr <= current_idx;
                            main_state <= BACKWARD_WAIT_RIGHT;
                        end else begin
                            // Finished backward pass
                            if (!swap_made) begin
                                // Go to IDLE, set done flags
                                main_state <= IDLE;
                                done <= 1;
                                sorting <= 0;
                            end else begin
                                start_idx <= start_idx + 1;
                                main_state <= FORWARD_START;
                            end
                        end
                    end

                    BACKWARD_WAIT_RIGHT: begin
                        main_state <= BACKWARD_FETCH_LEFT;
                    end

                    BACKWARD_FETCH_LEFT: begin
                        right_val <= live_data_out;
                        live_addr <= current_idx - 1;
                        main_state <= BACKWARD_WAIT_LEFT;
                    end

                    BACKWARD_WAIT_LEFT: begin
                        main_state <= BACKWARD_COMPARE;
                    end

                    BACKWARD_COMPARE: begin
                        left_val <= live_data_out;
                        current_pos1 <= current_idx - 1;
                        current_pos2 <= current_idx;
                        comparison_active <= 1;
                        
                        capture_left_idx <= current_idx - 1;
                        capture_left_val <= live_data_out;
                        capture_right_val <= right_val;
                        
                        if (step_edge_detected) begin
                            main_state <= BACKWARD_SWAP;
                        end
                    end

                    BACKWARD_SWAP: begin
                        comparison_active <= 0;
                        operation_type <= OP_SWAP;
                        
                        if (left_val > right_val) begin
                            // Swap needed
                            swap_occurred <= 1;
                            swap_made <= 1;
                            capture_valid <= 1;
                            
                            if (sub_state == 0) begin
                                live_addr <= current_idx - 1;
                                live_data_in <= right_val;
                                live_we <= 1;
                                capture_write_idx <= current_idx - 1;
                                sub_state <= 1;
                            end else begin
                                live_addr <= current_idx;
                                live_data_in <= left_val;
                                live_we <= 1;
                                capture_write_idx <= current_idx;
                                sub_state <= 0; 
                                current_idx <= current_idx - 1;
                                main_state <= BACKWARD_FETCH_RIGHT;
                            end
                        end else begin
                            // No swap
                            current_idx <= current_idx - 1;
                            main_state <= BACKWARD_FETCH_RIGHT;
                            sub_state <= 0;
                        end
                    end
                    default: main_state <= IDLE;
                endcase
            end
        end
    end

endmodule