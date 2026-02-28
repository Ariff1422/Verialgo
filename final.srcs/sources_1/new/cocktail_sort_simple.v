`timescale 1ns / 1ps

// COCKTAIL SORT WRAPPER MODULE
module cocktail_sort_simple #(
    parameter DATA_WIDTH = 8,
    parameter MAX_ARRAY_SIZE = 8,
    parameter ADDR_WIDTH = 3
)(
    input wire clk,
    input wire rst,
    
    // Random Mode
    input wire [7:0] seed_in,
    input wire btn_generate,
    
    // Manual Load Mode
    input wire manual_load_enable,
    input wire [DATA_WIDTH-1:0] manual_data_in,
    input wire [ADDR_WIDTH-1:0] manual_addr_in,
    input wire manual_we_in,

    // Sort Controls
    input wire btn_start_sort,
    input wire btn_step,
    input wire [ADDR_WIDTH:0] array_size,
    
    output reg [2:0] state,
    output reg done,
    
    // Display interface
    input wire [ADDR_WIDTH-1:0] display_addr,
    output wire [DATA_WIDTH-1:0] display_data,
    
    output wire readback_busy,
    
    // Delta buffer write interface
    output wire [ADDR_WIDTH-1:0] live_addr_out,
    output wire [DATA_WIDTH-1:0] live_data_out,
    output wire live_we_out,
    output wire [ADDR_WIDTH-1:0] temp_addr_out,
    output wire [DATA_WIDTH-1:0] temp_data_out_delta,
    output wire temp_we_out,
    
    // History buffer interface
    output wire [DATA_WIDTH-1:0] live_array_0,
    output wire [DATA_WIDTH-1:0] live_array_1,
    output wire [DATA_WIDTH-1:0] live_array_2,
    output wire [DATA_WIDTH-1:0] live_array_3,
    output wire [DATA_WIDTH-1:0] live_array_4,
    output wire [DATA_WIDTH-1:0] live_array_5,
    output wire [DATA_WIDTH-1:0] live_array_6,
    output wire [DATA_WIDTH-1:0] live_array_7,
    output wire [DATA_WIDTH-1:0] temp_array_0,
    output wire [DATA_WIDTH-1:0] temp_array_1,
    output wire [DATA_WIDTH-1:0] temp_array_2,
    output wire [DATA_WIDTH-1:0] temp_array_3,
    output wire [DATA_WIDTH-1:0] temp_array_4,
    output wire [DATA_WIDTH-1:0] temp_array_5,
    output wire [DATA_WIDTH-1:0] temp_array_6,
    output wire [DATA_WIDTH-1:0] temp_array_7,
    
    // Metadata outputs
    output wire [ADDR_WIDTH-1:0] compare_pos1,
    output wire [ADDR_WIDTH-1:0] compare_pos2,
    output wire comparison_active,
    output wire [1:0] operation_type,
    output wire capture_valid,
    output wire [ADDR_WIDTH-1:0] capture_write_idx,
    output wire src_is_live,
    
    // Cocktail sort boundary outputs for visualization
    output wire [ADDR_WIDTH:0] cocktail_left_bound,
    output wire [ADDR_WIDTH:0] cocktail_right_bound,
    output wire [ADDR_WIDTH:0] cocktail_current_idx,
    output wire cocktail_forward_pass
);
    
    localparam RB_IDLE = 2'd0;
    localparam RB_SET_ADDR = 2'd1;
    localparam RB_SAVE = 2'd2;
    reg [1:0] readback_fsm_state;
        
    localparam IDLE = 3'd0;
    localparam GENERATING = 3'd1;
    localparam READY = 3'd2;
    localparam SORTING = 3'd3;
    localparam MANUAL_LOAD = 3'd4;
    
    reg init_mode;
    reg [ADDR_WIDTH:0] active_array_length;
    
    reg sort_start;
    reg sort_step;
    
    wire lfsr_enable;
    wire lfsr_done;
    wire [DATA_WIDTH-1:0] lfsr_random_value;
    wire [ADDR_WIDTH-1:0] lfsr_write_addr;
    wire lfsr_write_enable;
    
    wire [ADDR_WIDTH-1:0] sort_addr;
    wire [DATA_WIDTH-1:0] sort_data_in;
    wire [DATA_WIDTH-1:0] sort_data_out;
    wire sort_we;
    wire [ADDR_WIDTH-1:0] temp_addr;
    wire [DATA_WIDTH-1:0] temp_data_in;
    wire [DATA_WIDTH-1:0] temp_data_out;
    wire temp_we;
    wire sort_done;
    wire sort_busy;
    wire [ADDR_WIDTH-1:0] cocktail_write_idx_internal;
    
    wire [ADDR_WIDTH-1:0] final_addr;
    wire [DATA_WIDTH-1:0] final_data_in;
    wire final_we;
    
    reg [ADDR_WIDTH:0] readback_addr;
    wire readback_active = (readback_fsm_state != RB_IDLE);
    assign readback_busy = readback_active;
    wire [ADDR_WIDTH-1:0] readback_request = (readback_active) ? readback_addr : sort_addr;
    
    assign final_addr = (sort_busy) ? sort_addr :
                        (lfsr_write_enable) ? lfsr_write_addr :
                        (state == MANUAL_LOAD) ? manual_addr_in : 
                        readback_request;
    
    assign final_data_in = (sort_busy) ? sort_data_in : 
                           (lfsr_write_enable) ? lfsr_random_value :
                           (state == MANUAL_LOAD) ? manual_data_in : 
                           8'd0;
    
    assign final_we = (sort_busy) ? sort_we :
                      (lfsr_write_enable) ? 1'b1 :
                      (state == MANUAL_LOAD && manual_we_in) ? 1'b1 : 
                      1'b0;
    
    assign live_addr_out = final_addr;
    assign live_data_out = final_data_in;
    assign live_we_out = final_we && sort_busy;
    
    assign temp_addr_out = temp_addr;
    assign temp_data_out_delta = temp_data_in;
    assign temp_we_out = temp_we && sort_busy;
    
    assign capture_write_idx = cocktail_write_idx_internal;
    
    reg [DATA_WIDTH-1:0] live_shadow [0:MAX_ARRAY_SIZE-1];
    reg [DATA_WIDTH-1:0] temp_shadow [0:MAX_ARRAY_SIZE-1];
    
    assign live_array_0 = live_shadow[0];
    assign live_array_1 = live_shadow[1];
    assign live_array_2 = live_shadow[2];
    assign live_array_3 = live_shadow[3];
    assign live_array_4 = live_shadow[4];
    assign live_array_5 = live_shadow[5];
    assign live_array_6 = live_shadow[6];
    assign live_array_7 = live_shadow[7];
    
    assign temp_array_0 = temp_shadow[0];
    assign temp_array_1 = temp_shadow[1];
    assign temp_array_2 = temp_shadow[2];
    assign temp_array_3 = temp_shadow[3];
    assign temp_array_4 = temp_shadow[4];
    assign temp_array_5 = temp_shadow[5];
    assign temp_array_6 = temp_shadow[6];
    assign temp_array_7 = temp_shadow[7];
    
    dual_port_ram #(.DATA_WIDTH(DATA_WIDTH), .ADDR_WIDTH(ADDR_WIDTH), .RAM_DEPTH(MAX_ARRAY_SIZE)) 
    live_memory (
        .clk(clk), .rst(rst),
        .addr_a(final_addr), .data_in_a(final_data_in), .data_out_a(sort_data_out), .we_a(final_we),
        .addr_b(display_addr), .data_out_b(display_data)
    );
    
    single_port_ram #(.DATA_WIDTH(DATA_WIDTH), .ADDR_WIDTH(ADDR_WIDTH), .RAM_DEPTH(MAX_ARRAY_SIZE)) 
    temp_memory (
        .clk(clk), .rst(rst),
        .addr(temp_addr), .data_in(temp_data_in), .data_out(temp_data_out), .we(temp_we)
    );
    
    wire [ADDR_WIDTH:0] capture_left_start_internal;
    wire [ADDR_WIDTH:0] capture_right_idx_internal;
    wire [ADDR_WIDTH:0] capture_left_idx_internal;
    
    assign src_is_live = 1'b1;
    assign cocktail_left_bound = capture_left_start_internal;
    assign cocktail_right_bound = capture_right_idx_internal;
    assign cocktail_current_idx = capture_left_idx_internal;
    
    wire [3:0] debug_state;
    assign cocktail_forward_pass = (debug_state >= 4'd2 && debug_state <= 4'd8);
    
    lfsr_rng #(.DATA_WIDTH(DATA_WIDTH), .ADDR_WIDTH(ADDR_WIDTH), .MAX_ARRAY_SIZE(MAX_ARRAY_SIZE)) 
    random_gen (
        .clk(clk), .rst(rst),
        .seed_in(seed_in), .generate_enable(lfsr_enable), .array_length(active_array_length),
        .random_value(lfsr_random_value), .write_addr(lfsr_write_addr),
        .write_enable(lfsr_write_enable), .generation_done(lfsr_done)
    );
    
    assign lfsr_enable = (state == GENERATING);
    
    cocktail_sort_engine #(.DATA_WIDTH(DATA_WIDTH), .MAX_ARRAY_SIZE(MAX_ARRAY_SIZE), .ADDR_WIDTH(ADDR_WIDTH)) 
    sort_engine (
        .clk(clk), .rst(rst),
        .start(sort_start), .array_length(active_array_length),
        .step_forward(sort_step), .step_backward(1'b0),
        .init_mode(1'b0), .ext_addr(3'd0), .ext_data(8'd0), .ext_we(1'b0),
        .live_addr(sort_addr), .live_data_in(sort_data_in), .live_data_out(sort_data_out), .live_we(sort_we),
        .temp_addr(temp_addr), .temp_data_in(temp_data_in), .temp_data_out(temp_data_out), .temp_we(temp_we),
        .done(sort_done), .sorting(sort_busy), .busy(),
        .current_pos1(compare_pos1), .current_pos2(compare_pos2),
        .comparison_active(comparison_active), .swap_occurred(),
        .current_pass(), .current_merge(),
        .debug_pass_state(debug_state), .debug_merge_state(),
        .operation_type(operation_type),
        .capture_valid(capture_valid),
        .capture_write_idx(cocktail_write_idx_internal),
        .capture_merge_size(),
        .capture_left_start(capture_left_start_internal),
        .capture_left_idx(capture_left_idx_internal),
        .capture_right_idx(capture_right_idx_internal),
        .capture_left_val(), .capture_right_val(),
        .capture_src_is_live(),
        .capture_left_done(), .capture_right_done()
    );

    integer i;
    always @(posedge clk) begin
        if (rst) begin
            for (i = 0; i < MAX_ARRAY_SIZE; i = i + 1) begin
                live_shadow[i] <= 0;
                temp_shadow[i] <= 0;
            end
            readback_addr <= 0;
            readback_fsm_state <= RB_IDLE;
        
        end else begin
            
            if (final_we && final_addr < MAX_ARRAY_SIZE) begin
                live_shadow[final_addr] <= final_data_in;
            end
            
            if (temp_we && temp_addr < MAX_ARRAY_SIZE) begin
                temp_shadow[temp_addr] <= temp_data_in;
            end
            
            case (readback_fsm_state)
                RB_IDLE: begin
                    //Start readback when in READY OR MANUAL_LOAD
                    if (state == READY && !sort_busy) begin 
                        readback_addr <= 0;
                        readback_fsm_state <= RB_SET_ADDR;
                    end
                end
                
                RB_SET_ADDR: begin
                    readback_fsm_state <= RB_SAVE;
                end
                
                RB_SAVE: begin
                    live_shadow[readback_addr] <= sort_data_out;
                    
                    if (readback_addr >= active_array_length - 1) begin
                        readback_fsm_state <= RB_IDLE;
                    end else begin
                        readback_addr <= readback_addr + 1;
                        readback_fsm_state <= RB_SET_ADDR;
                    end
                end
            endcase
            
            if (state == SORTING) begin
                readback_fsm_state <= RB_IDLE;
            end
        end
    end

    // Main state machine
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            state <= IDLE;
            init_mode <= 0;
            sort_start <= 0;
            sort_step <= 0;
            active_array_length <= 0;
            done <= 0;
        end else begin
            sort_start <= 0;
            sort_step <= 0;
            
            case (state)
                IDLE: begin
                    init_mode <= 0;
                    done <= 0;
                    
                    if (btn_generate && array_size > 0 && array_size <= MAX_ARRAY_SIZE) begin
                        state <= GENERATING;
                        active_array_length <= array_size;
                    end
                    else if (manual_load_enable && array_size > 0 && array_size <= MAX_ARRAY_SIZE) begin
                        state <= MANUAL_LOAD;
                        active_array_length <= array_size;
                    end
                end
                
                GENERATING: begin
                    if (lfsr_done) begin
                        state <= READY;
                    end
                end

                // This state now waits for the 'start' signal
                MANUAL_LOAD: begin
                    if (!manual_load_enable) begin
                        // Once loading is done, go to READY
                        state <= READY;
                    end
                end
                
                READY: begin
                    init_mode <= 0;
                    done <= 0;
                    
                    if (btn_start_sort && active_array_length > 0) begin
                        state <= SORTING;
                        sort_start <= 1;
                    end
                    else if (btn_generate && array_size > 0 && array_size <= MAX_ARRAY_SIZE) begin
                        state <= GENERATING;
                        active_array_length <= array_size;
                    end
                    
                end
                
                SORTING: begin
                    init_mode <= 0;
                    
                    if (btn_step) begin
                        sort_step <= 1;
                    end
                    
                    if (sort_done) begin
                        state <= READY;
                        done <= 1;
                    end
                end
            endcase
        end
    end

endmodule