`timescale 1ns / 1ps

module merge_sort_engine #(
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

    localparam IDLE = 4'd0;
    localparam INIT = 4'd1;
    localparam PASS_START = 4'd2;
    localparam PASS_MERGE = 4'd3;
    localparam PASS_COMPLETE = 4'd4;
    localparam FINAL_COPY_START = 4'd5;
    localparam FINAL_COPY_READ = 4'd6;
    localparam FINAL_COPY_WAIT = 4'd7;
    localparam FINAL_COPY_WRITE = 4'd8;
    localparam DONE_STATE = 4'd9;

    localparam M_IDLE = 4'd0;
    localparam M_FETCH_LEFT = 4'd1;
    localparam M_WAIT_LEFT = 4'd2;
    localparam M_FETCH_RIGHT = 4'd3;
    localparam M_WAIT_RIGHT = 4'd4;
    localparam M_COMPARE = 4'd5;
    localparam M_WRITE_RESULT = 4'd6;
    localparam M_FETCH_REMAIN = 4'd7;
    localparam M_WAIT_REMAIN = 4'd8;
    localparam M_WRITE_REMAIN = 4'd9;
    localparam M_COMPLETE = 4'd10;

    localparam OP_IDLE = 2'd0;
    localparam OP_COMPARE = 2'd1;
    localparam OP_MERGE = 2'd2;
    localparam OP_COPY = 2'd3;

    reg [3:0] pass_state;
    reg [3:0] merge_state;

    reg src_is_live;  // Internal tracking of which buffer has current data

    reg [ADDR_WIDTH:0] merge_size;
    reg [ADDR_WIDTH:0] left_start;

    reg [ADDR_WIDTH:0] left_idx, right_idx, write_idx;
    reg [ADDR_WIDTH:0] left_end, right_end;
    reg [DATA_WIDTH-1:0] left_val, right_val;
    reg left_done, right_done;

    reg [ADDR_WIDTH:0] copy_idx;

    reg prev_step_forward;
    reg step_edge_detected;

    assign debug_pass_state = pass_state;
    assign debug_merge_state = merge_state;
    assign busy = sorting;

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            pass_state <= IDLE;
            merge_state <= M_IDLE;
            done <= 0;
            sorting <= 0;
            merge_size <= 1;
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
            left_start <= 0;
            left_idx <= 0;
            right_idx <= 0;
            write_idx <= 0;
            left_end <= 0;
            right_end <= 0;
            left_val <= 0;
            right_val <= 0;
            left_done <= 0;
            right_done <= 0;
            copy_idx <= 0;
            prev_step_forward <= 0;
            step_edge_detected <= 0;
            src_is_live <= 1;  // Start with live buffer

            operation_type <= OP_IDLE;
            capture_valid <= 0;
            capture_merge_size <= 0;
            capture_left_start <= 0;
            capture_left_idx <= 0;
            capture_right_idx <= 0;
            capture_write_idx <= 0;
            capture_left_val <= 0;
            capture_right_val <= 0;
            capture_src_is_live <= 1;  // Initialize output
            capture_left_done <= 0;
            capture_right_done <= 0;
        end else begin
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
                capture_valid <= 0;  // Default: no capture this cycle

                case (pass_state)
                    IDLE: begin
                        done <= 0;
                        sorting <= 0;
                        comparison_active <= 0;
                        operation_type <= OP_IDLE;
                        if (start && array_length > 1) begin
                            pass_state <= INIT;
                            sorting <= 1;
                            merge_size <= 1;
                            current_pass <= 0;
                            src_is_live <= 1;  // Start with live buffer
                            capture_src_is_live <= 1;  
                        end
                    end

                    INIT: begin
                        left_start <= 0;
                        current_merge <= 0;
                        merge_state <= M_IDLE;
                        comparison_active <= 0;
                        pass_state <= PASS_START;
                        
                        // Capture initial state
                        
                        capture_src_is_live <= src_is_live;
                    end

                    PASS_START: begin
                        // Check if we are done: merge_size must be GREATER than array_length
                        // NOT equal - we need to do one more merge when they are equal
                        if (merge_size >= array_length) begin
                            if (!src_is_live) begin
                                pass_state <= FINAL_COPY_START;
                            end else begin
                                pass_state <= DONE_STATE;
                            end
                        end else if (left_start < array_length) begin
                            pass_state <= PASS_MERGE;
                            merge_state <= M_IDLE;
                            comparison_active <= 0;
                        end else begin
                            pass_state <= PASS_COMPLETE;
                        end
                        
                        // Capture state at pass start
                        
                        capture_src_is_live <= src_is_live;
                    end

                    PASS_MERGE: begin
                        operation_type <= OP_MERGE;

                        case (merge_state)
                            M_IDLE: begin
                                left_idx <= left_start;
                                write_idx <= left_start;

                                if (left_start + merge_size < array_length) begin
                                    left_end <= left_start + merge_size;
                                    right_idx <= left_start + merge_size;
                                    if (left_start + 2*merge_size < array_length) begin
                                        right_end <= left_start + 2*merge_size;
                                    end else begin
                                        right_end <= array_length;
                                    end
                                end else begin
                                    left_end <= array_length;
                                    right_idx <= array_length;
                                    right_end <= array_length;
                                end

                                if (left_start >= array_length) begin
                                    merge_state <= M_COMPLETE;
                                end else if (left_start + merge_size >= array_length) begin
                                    left_done <= 0;
                                    right_done <= 1;
                                    if (src_is_live) begin
                                        live_addr <= left_start;
                                    end else begin
                                        temp_addr <= left_start;
                                    end
                                    merge_state <= M_WAIT_REMAIN;
                                end else begin
                                    left_done <= 0;
                                    right_done <= 0;
                                    if (src_is_live) begin
                                        live_addr <= left_start;
                                    end else begin
                                        temp_addr <= left_start;
                                    end
                                    merge_state <= M_FETCH_LEFT;
                                end
                                
                                // Capture at merge start
                                
                                capture_src_is_live <= src_is_live;
                            end

                            M_FETCH_LEFT: begin
                                merge_state <= M_WAIT_LEFT;
                            end

                            M_WAIT_LEFT: begin
                                left_val <= src_is_live ? live_data_out : temp_data_out;
                                if (src_is_live) begin
                                    live_addr <= right_idx;
                                end else begin
                                    temp_addr <= right_idx;
                                end
                                merge_state <= M_FETCH_RIGHT;
                            end

                            M_FETCH_RIGHT: begin
                                merge_state <= M_WAIT_RIGHT;
                            end

                            M_WAIT_RIGHT: begin
                                right_val <= src_is_live ? live_data_out : temp_data_out;
                                current_pos1 <= left_idx;
                                current_pos2 <= right_idx;
                                comparison_active <= 1;
                                operation_type <= OP_COMPARE;
                                merge_state <= M_COMPARE;
                            end

                            M_COMPARE: begin
                                if (step_edge_detected) begin
                                    //comparison_active <= 0;
                                    merge_state <= M_WRITE_RESULT;

                                    // Capture comparison snapshot
                                    capture_valid <= 1;
                                    capture_merge_size <= merge_size;
                                    capture_left_start <= left_start;
                                    capture_left_idx <= left_idx;
                                    capture_right_idx <= right_idx;
                                    capture_write_idx <= write_idx;
                                    capture_left_val <= left_val;
                                    capture_right_val <= right_val;
                                    capture_src_is_live <= src_is_live;  // capture current buffer
                                    capture_left_done <= left_done;
                                    capture_right_done <= right_done;
                                end
                            end

                            M_WRITE_RESULT: begin
                                operation_type <= OP_MERGE;
                                comparison_active <= 0;
                                // WRITE TO THE OPPOSITE BUFFER (ping-pong)
                                // ASCENDING ORDER: Pick smaller value first
                                if (src_is_live) begin
                                    temp_addr <= write_idx;
                                    temp_data_in <= (left_val < right_val) ? left_val : right_val;
                                    temp_we <= 1;
                                end else begin
                                    live_addr <= write_idx;
                                    live_data_in <= (left_val < right_val) ? left_val : right_val;
                                    live_we <= 1;
                                end

                                write_idx <= write_idx + 1;

                                if (left_val >= right_val) begin
                                    swap_occurred <= 1;
                                end

                                // Capture merge write
                                capture_valid <= 1;
                                capture_merge_size <= merge_size;
                                capture_left_start <= left_start;
                                capture_left_idx <= left_idx;
                                capture_right_idx <= right_idx;
                                capture_write_idx <= write_idx;
                                capture_left_val <= left_val;
                                capture_right_val <= right_val;
                                capture_src_is_live <= src_is_live;  // Capture current source
                                capture_left_done <= left_done;
                                capture_right_done <= right_done;

                                if (left_val < right_val) begin
                                    // Left value is smaller, so we used it - advance left
                                    left_idx <= left_idx + 1;
                                    if (left_idx + 1 >= left_end) begin
                                        left_done <= 1;
                                        merge_state <= M_FETCH_REMAIN;
                                    end else begin
                                        if (src_is_live) begin
                                            live_addr <= left_idx + 1;
                                        end else begin
                                            temp_addr <= left_idx + 1;
                                        end
                                        merge_state <= M_FETCH_LEFT;
                                    end
                                end else begin
                                    // Right value is smaller or equal, so we used it - advance right
                                    right_idx <= right_idx + 1;
                                    if (right_idx + 1 >= right_end) begin
                                        right_done <= 1;
                                        merge_state <= M_FETCH_REMAIN;
                                    end else begin
                                        if (src_is_live) begin
                                            live_addr <= right_idx + 1;
                                        end else begin
                                            temp_addr <= right_idx + 1;
                                        end
                                        merge_state <= M_FETCH_RIGHT;
                                    end
                                end
                            end

                            M_FETCH_REMAIN: begin
                                if (!left_done && left_idx < left_end) begin
                                    if (src_is_live) begin
                                        live_addr <= left_idx;
                                    end else begin
                                        temp_addr <= left_idx;
                                    end
                                    merge_state <= M_WAIT_REMAIN;
                                end else if (!right_done && right_idx < right_end) begin
                                    if (src_is_live) begin
                                        live_addr <= right_idx;
                                    end else begin
                                        temp_addr <= right_idx;
                                    end
                                    merge_state <= M_WAIT_REMAIN;
                                end else begin
                                    merge_state <= M_COMPLETE;
                                end
                            end

                            M_WAIT_REMAIN: begin
                                merge_state <= M_WRITE_REMAIN;
                            end

                            M_WRITE_REMAIN: begin
                                if (src_is_live) begin
                                    temp_addr <= write_idx;
                                    temp_data_in <= live_data_out;
                                    temp_we <= 1;
                                end else begin
                                    live_addr <= write_idx;
                                    live_data_in <= temp_data_out;
                                    live_we <= 1;
                                end

                                write_idx <= write_idx + 1;

                                // Capture remaining element write
                                capture_valid <= 1;
                                capture_write_idx <= write_idx;
                                capture_left_idx <= left_idx;
                                capture_right_idx <= right_idx;
                                capture_src_is_live <= src_is_live;  // Capture source

                                if (!left_done && left_idx < left_end) begin
                                    left_idx <= left_idx + 1;
                                    if (left_idx + 1 >= left_end) begin
                                        left_done <= 1;
                                    end
                                end else if (!right_done && right_idx < right_end) begin
                                    right_idx <= right_idx + 1;
                                    if (right_idx + 1 >= right_end) begin
                                        right_done <= 1;
                                    end
                                end

                                merge_state <= M_FETCH_REMAIN;
                            end

                            M_COMPLETE: begin
                                current_merge <= current_merge + 1;
                                left_start <= left_start + 2*merge_size;
                                comparison_active <= 0;
                                pass_state <= PASS_START;
                                merge_state <= M_IDLE;
                                
                                // Capture at merge complete
                                
                                capture_src_is_live <= src_is_live;
                            end

                            default: merge_state <= M_IDLE;
                        endcase
                    end

                    PASS_COMPLETE: begin
                        current_pass <= current_pass + 1;
                        merge_size <= merge_size << 1;
                        left_start <= 0;
                        src_is_live <= !src_is_live;  // Toggle Buffer
                        pass_state <= PASS_START;
                        
                        // Capture buffer swap
                        
                        capture_src_is_live <= !src_is_live;  // Capture NEW buffer state
                    end

 FINAL_COPY_START: begin
    operation_type <= OP_COPY;
    copy_idx <= 0;
    temp_addr <= 0;
    src_is_live <= 1;
    pass_state <= FINAL_COPY_READ;
    
    // NO capture here anymore
end

 FINAL_COPY_READ: begin
    if (copy_idx < array_length) begin
        temp_addr <= copy_idx;
        pass_state <= FINAL_COPY_WAIT;
    end else begin
        pass_state <= DONE_STATE;
    end
end

 FINAL_COPY_WAIT: begin
    pass_state <= FINAL_COPY_WRITE;
end

 FINAL_COPY_WRITE: begin
    live_addr <= copy_idx;
    live_data_in <= temp_data_out;
    live_we <= 1;

    copy_idx <= copy_idx + 1;
    pass_state <= FINAL_COPY_READ;
end

 DONE_STATE: begin
    done <= 1;
    sorting <= 0;
    comparison_active <= 0;
    operation_type <= OP_IDLE;
    src_is_live <= 1;

    // Keep final capture - animation already shows sorted array
     capture_valid <= 1;  
     capture_src_is_live <= 1;

    pass_state <= IDLE;
end

                    default: pass_state <= IDLE;
                endcase
            end
        end
    end

endmodule