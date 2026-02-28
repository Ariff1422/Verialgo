`timescale 1ns / 1ps

// TOP MODULE - Verialgo Menu System

module Top_Student (
    input clk,
    input btnC,
    input btnU,
    input btnL,
    input btnR,
    input btnD,
    input [2:0] sw,

    // PS/2 Mouse Ports
    inout ps2_clk,
    inout ps2_data,

    output [7:0] JC,
    output [15:0] led
);

    // Clocks
    wire clk_6p25, clk_25;
    clock_divider unit_6p25(.clk(clk), .m(32'd7), .slow_clk(clk_6p25));
    clock_divider unit_25(.clk(clk), .m(32'd1), .slow_clk(clk_25));
    
    // Button debouncers
    wire btnC_lvl, btnC_edge, btnC_fall;
    wire btnU_lvl, btnU_edge, btnU_fall;
    wire btnL_lvl, btnL_edge, btnL_fall;
    wire btnR_lvl, btnR_edge, btnR_fall;
    wire btnD_lvl, btnD_edge, btnD_fall;
    
    btn_debouncer #(.COUNT_MAX(1000000)) dbC (.clk(clk), .btn_in(btnC), .level(btnC_lvl), .rise(btnC_edge), .fall(btnC_fall));
    btn_debouncer #(.COUNT_MAX(1000000)) dbU (.clk(clk), .btn_in(btnU), .level(btnU_lvl), .rise(btnU_edge), .fall(btnU_fall));
    btn_debouncer #(.COUNT_MAX(1000000)) dbL (.clk(clk), .btn_in(btnL), .level(btnL_lvl), .rise(btnL_edge), .fall(btnL_fall));
    btn_debouncer #(.COUNT_MAX(1000000)) dbR (.clk(clk), .btn_in(btnR), .level(btnR_lvl), .rise(btnR_edge), .fall(btnR_fall));
    btn_debouncer #(.COUNT_MAX(1000000)) dbD (.clk(clk), .btn_in(btnD), .level(btnD_lvl), .rise(btnD_edge), .fall(btnD_fall));

    wire any_button_edge = btnC_edge | btnU_edge | btnL_edge | btnR_edge | btnD_edge;

    // New Global Reset and Speed Controls 
    wire global_reset = sw[0]; // Reset is now sw[0]
    wire [1:0] speed_select_wires = sw[2:1]; // Use sw[2:1] for speed control

    
    // Delta (Snapshot) Buffer 
    wire [7:0] playback_array_0, playback_array_1, playback_array_2, playback_array_3, playback_array_4, playback_array_5, playback_array_6, playback_array_7;
    wire [2:0] playback_pos1, playback_pos2;
    wire playback_comparison_active;
    wire [3:0] playback_merge_left_start, playback_merge_left_end;
    wire [3:0] playback_merge_right_start, playback_merge_right_end;
    wire playback_merge_active; 

    
    // TOP LEVEL FSM
    reg [3:0] main_state; 
    localparam STATE_SPLASH_SCREEN   = 4'd0;
    localparam STATE_SPLASH_FADE_OUT = 4'd1;
    localparam STATE_ALGO_SELECT     = 4'd2; 
    localparam STATE_MENU_SELECT     = 4'd3; 
    localparam STATE_PRESCREEN_SETUP = 4'd4; 
    localparam STATE_GENERATE        = 4'd5; 
    localparam STATE_SORT_READY      = 4'd6; 
    localparam STATE_SORTING         = 4'd7; 
    localparam STATE_CELEBRATE       = 4'd8; 
    localparam STATE_PLAYBACK        = 4'd9; 
    localparam STATE_CREATE_SETUP    = 4'd10; 
    localparam STATE_CREATE_ENTRY    = 4'd11; 
    localparam STATE_MANUAL_PREP     = 4'd12; 
    localparam STATE_MANUAL_LOAD     = 4'd13; // Pushed back
    
    reg selected_algo; // 0 = Merge, 1 = Cocktail (Kept from File 1)
    
    reg [3:0] selected_array_size;
    reg [3:0] active_array_size;
    reg [6:0] wipe_counter;
    
    reg trigger_generate;
    reg trigger_start_sort;
    wire trigger_generate_merge    = trigger_generate && (selected_algo == 0);
    wire trigger_generate_cocktail = trigger_generate && (selected_algo == 1);
    wire trigger_start_merge       = trigger_start_sort && (selected_algo == 0);
    wire trigger_start_cocktail    = trigger_start_sort && (selected_algo == 1);
    
    
    // PS/2 MOUSE CONTROLLER
    
    wire [11:0] mouse_x_raw, mouse_y_raw;
    wire mouse_left_lvl, mouse_right_lvl, mouse_middle_lvl;
    wire mouse_new_event;
    
    MouseCtl mouse_controller (
        .clk(clk), .rst(global_reset), .xpos(mouse_x_raw), .ypos(mouse_y_raw),
        .zpos(), .left(mouse_left_lvl), .middle(mouse_middle_lvl), .right(mouse_right_lvl),
        .new_event(mouse_new_event), .value(12'd0), .setx(1'b0), .sety(1'b0),
        .setmax_x(1'b0), .setmax_y(1'b0), .ps2_clk(ps2_clk), .ps2_data(ps2_data)
    );
    
    wire [6:0] oled_mouse_x = (mouse_x_raw > 959) ? 95 : (mouse_x_raw / 10);
    wire [5:0] oled_mouse_y = (mouse_y_raw > 639) ? 63 : (mouse_y_raw / 10);

    reg prev_mouse_left_lvl;
    wire mouse_click_edge;
    always @(posedge clk) begin
        prev_mouse_left_lvl <= mouse_left_lvl;
    end
    assign mouse_click_edge = mouse_left_lvl & !prev_mouse_left_lvl;

    
    // MENU INTERACTION LOGIC
    
    localparam SLIDER_Y1 = 25, SLIDER_Y2 = 35;
    wire mouse_on_slider = (oled_mouse_y >= SLIDER_Y1 - 2 && oled_mouse_y <= SLIDER_Y2 + 2);

    localparam PRESCREEN_BTN_Y1 = 47, PRESCREEN_BTN_Y2 = 57; 
    localparam PRESCREEN_BTN_X1 = 28, PRESCREEN_BTN_X2 = 68;
    wire mouse_on_prescreen_sort_btn = (oled_mouse_x >= PRESCREEN_BTN_X1 && oled_mouse_x <= PRESCREEN_BTN_X2 && 
                                       oled_mouse_y >= PRESCREEN_BTN_Y1 && oled_mouse_y <= PRESCREEN_BTN_Y2);
    
    wire mouse_on_create_next_btn = mouse_on_prescreen_sort_btn;

    localparam SELECT_BTN_X1 = 25, SELECT_BTN_X2 = 70;
    localparam SELECT_RAND_BTN_Y1 = 22, SELECT_RAND_BTN_Y2 = 33;
    wire mouse_on_select_random_btn = (oled_mouse_x >= SELECT_BTN_X1 && oled_mouse_x <= SELECT_BTN_X2 && 
                                      oled_mouse_y >= SELECT_RAND_BTN_Y1 && oled_mouse_y <= SELECT_RAND_BTN_Y2);

    localparam SELECT_CREATE_BTN_Y1 = 42, SELECT_CREATE_BTN_Y2 = 53;
    wire mouse_on_select_create_btn = (oled_mouse_x >= SELECT_BTN_X1 && oled_mouse_x <= SELECT_BTN_X2 && 
                                      oled_mouse_y >= SELECT_CREATE_BTN_Y1 && oled_mouse_y <= SELECT_CREATE_BTN_Y2);
                                      
    localparam ALGO_BTN_X1 = 18, ALGO_BTN_X2 = 78;
    localparam ALGO_MERGE_BTN_Y1 = 22, ALGO_MERGE_BTN_Y2 = 33;
    wire mouse_on_select_merge_btn = (oled_mouse_x >= ALGO_BTN_X1 && oled_mouse_x <= ALGO_BTN_X2 && 
                                      oled_mouse_y >= ALGO_MERGE_BTN_Y1 && oled_mouse_y <= ALGO_MERGE_BTN_Y2);

    localparam ALGO_COCKTAIL_BTN_Y1 = 42, ALGO_COCKTAIL_BTN_Y2 = 53;
    wire mouse_on_select_cocktail_btn = (oled_mouse_x >= ALGO_BTN_X1 && oled_mouse_x <= ALGO_BTN_X2 && 
                                       oled_mouse_y >= ALGO_COCKTAIL_BTN_Y1 && oled_mouse_y <= ALGO_COCKTAIL_BTN_Y2);
    
    localparam BACK_BTN_X1 = 0, BACK_BTN_X2 = 20;
    localparam BACK_BTN_Y1 = 0, BACK_BTN_Y2 = 12;
    wire mouse_on_back_btn = (oled_mouse_x >= BACK_BTN_X1 && oled_mouse_x <= BACK_BTN_X2 &&
                            oled_mouse_y >= BACK_BTN_Y1 && oled_mouse_y <= BACK_BTN_Y2);
    wire mouse_on_back_entry_btn = (oled_mouse_x >= 60 && oled_mouse_x <= 80 && 
                            oled_mouse_y >= 45 && oled_mouse_y <= 60);
    
    // "CREATE ARRAY" DATA ENTRY LOGIC
    reg [7:0] user_array [0:7];
    reg [2:0] selected_entry_index;
    reg [7:0] current_entry_value;
    
    localparam BOX_Y1 = 4, BOX_Y2 = 15; 
    localparam BOX_W = 11, BOX_S = 12;
    wire mouse_on_box_0 = (oled_mouse_x >= 2 && oled_mouse_x < 13 && oled_mouse_y >= BOX_Y1 && oled_mouse_y <= BOX_Y2);
    wire mouse_on_box_1 = (oled_mouse_x >= 14 && oled_mouse_x < 25 && oled_mouse_y >= BOX_Y1 && oled_mouse_y <= BOX_Y2);
    wire mouse_on_box_2 = (oled_mouse_x >= 26 && oled_mouse_x < 37 && oled_mouse_y >= BOX_Y1 && oled_mouse_y <= BOX_Y2);
    wire mouse_on_box_3 = (oled_mouse_x >= 38 && oled_mouse_x < 49 && oled_mouse_y >= BOX_Y1 && oled_mouse_y <= BOX_Y2);
    wire mouse_on_box_4 = (oled_mouse_x >= 50 && oled_mouse_x < 61 && oled_mouse_y >= BOX_Y1 && oled_mouse_y <= BOX_Y2);
    wire mouse_on_box_5 = (oled_mouse_x >= 62 && oled_mouse_x < 73 && oled_mouse_y >= BOX_Y1 && oled_mouse_y <= BOX_Y2);
    wire mouse_on_box_6 = (oled_mouse_x >= 74 && oled_mouse_x < 85 && oled_mouse_y >= BOX_Y1 && oled_mouse_y <= BOX_Y2);
    wire mouse_on_box_7 = (oled_mouse_x >= 86 && oled_mouse_x < 97 && oled_mouse_y >= BOX_Y1 && oled_mouse_y <= BOX_Y2);
    
    localparam NUM_X1 = 4, NUM_W = 13, NUM_S_X = 14;
    localparam NUM_Y1 = 20, NUM_H = 9, NUM_S_Y = 10;
    wire mouse_on_num_1 = (oled_mouse_x >= (NUM_X1+NUM_S_X*0) && oled_mouse_x < (NUM_X1+NUM_S_X*0)+NUM_W && oled_mouse_y >= (NUM_Y1+NUM_S_Y*0) && oled_mouse_y < (NUM_Y1+NUM_S_Y*0)+NUM_H);
    wire mouse_on_num_2 = (oled_mouse_x >= (NUM_X1+NUM_S_X*1) && oled_mouse_x < (NUM_X1+NUM_S_X*1)+NUM_W && oled_mouse_y >= (NUM_Y1+NUM_S_Y*0) && oled_mouse_y < (NUM_Y1+NUM_S_Y*0)+NUM_H);
    wire mouse_on_num_3 = (oled_mouse_x >= (NUM_X1+NUM_S_X*2) && oled_mouse_x < (NUM_X1+NUM_S_X*2)+NUM_W && oled_mouse_y >= (NUM_Y1+NUM_S_Y*0) && oled_mouse_y < (NUM_Y1+NUM_S_Y*0)+NUM_H);
    wire mouse_on_num_4 = (oled_mouse_x >= (NUM_X1+NUM_S_X*0) && oled_mouse_x < (NUM_X1+NUM_S_X*0)+NUM_W && oled_mouse_y >= (NUM_Y1+NUM_S_Y*1) && oled_mouse_y < (NUM_Y1+NUM_S_Y*1)+NUM_H);
    wire mouse_on_num_5 = (oled_mouse_x >= (NUM_X1+NUM_S_X*1) && oled_mouse_x < (NUM_X1+NUM_S_X*1)+NUM_W && oled_mouse_y >= (NUM_Y1+NUM_S_Y*1) && oled_mouse_y < (NUM_Y1+NUM_S_Y*1)+NUM_H);
    wire mouse_on_num_6 = (oled_mouse_x >= (NUM_X1+NUM_S_X*2) && oled_mouse_x < (NUM_X1+NUM_S_X*2)+NUM_W && oled_mouse_y >= (NUM_Y1+NUM_S_Y*1) && oled_mouse_y < (NUM_Y1+NUM_S_Y*1)+NUM_H);
    wire mouse_on_num_7 = (oled_mouse_x >= (NUM_X1+NUM_S_X*0) && oled_mouse_x < (NUM_X1+NUM_S_X*0)+NUM_W && oled_mouse_y >= (NUM_Y1+NUM_S_Y*2) && oled_mouse_y < (NUM_Y1+NUM_S_Y*2)+NUM_H);
    wire mouse_on_num_8 = (oled_mouse_x >= (NUM_X1+NUM_S_X*1) && oled_mouse_x < (NUM_X1+NUM_S_X*1)+NUM_W && oled_mouse_y >= (NUM_Y1+NUM_S_Y*2) && oled_mouse_y < (NUM_Y1+NUM_S_Y*2)+NUM_H);
    wire mouse_on_num_9 = (oled_mouse_x >= (NUM_X1+NUM_S_X*2) && oled_mouse_x < (NUM_X1+NUM_S_X*2)+NUM_W && oled_mouse_y >= (NUM_Y1+NUM_S_Y*2) && oled_mouse_y < (NUM_Y1+NUM_S_Y*2)+NUM_H);
    wire mouse_on_bs    = (oled_mouse_x >= (NUM_X1+NUM_S_X*0) && oled_mouse_x < (NUM_X1+NUM_S_X*0)+NUM_W && oled_mouse_y >= (NUM_Y1+NUM_S_Y*3) && oled_mouse_y < (NUM_Y1+NUM_S_Y*3)+NUM_H);
    wire mouse_on_num_0 = (oled_mouse_x >= (NUM_X1+NUM_S_X*1) && oled_mouse_x < (NUM_X1+NUM_S_X*1)+NUM_W && oled_mouse_y >= (NUM_Y1+NUM_S_Y*3) && oled_mouse_y < (NUM_Y1+NUM_S_Y*3)+NUM_H);
    wire mouse_on_enter = (oled_mouse_x >= (NUM_X1+NUM_S_X*2) && oled_mouse_x < (NUM_X1+NUM_S_X*2)+NUM_W && oled_mouse_y >= (NUM_Y1+NUM_S_Y*3) && oled_mouse_y < (NUM_Y1+NUM_S_Y*3)+NUM_H);

    localparam SORT_BTN_X1 = 48, SORT_BTN_X2 = 92;
    localparam SORT_BTN_Y1 = 26, SORT_BTN_Y2 = 40;
    wire mouse_on_create_sort_btn = (oled_mouse_x >= SORT_BTN_X1 && oled_mouse_x <= SORT_BTN_X2 && 
                                   oled_mouse_y >= SORT_BTN_Y1 && oled_mouse_y <= SORT_BTN_Y2);

    
    // MANUAL ARRAY LOADER FSM
    reg [2:0] manual_load_index;
    reg [7:0] manual_data_out;
    reg [2:0] manual_addr_out;
    reg manual_we_out;
    reg manual_load_done_flag;

    // Simplified 3-state FSM
    reg [1:0] load_state;
    localparam LOAD_IDLE = 2'd0;
    localparam LOAD_WRITING = 2'd1;
    localparam LOAD_DONE = 2'd2;

    reg [4:0] write_hold_counter;   
    localparam HOLD_CYCLES = 5'd10; // Hold write enable for 10 cycles

    // Edge detection
    reg prev_in_manual_load;
    wire enter_manual_load = (main_state == STATE_MANUAL_LOAD) && !prev_in_manual_load;

    // Output signals
    wire manual_load_enable = (load_state == LOAD_WRITING);
    wire manual_load_finished = manual_load_done_flag;
    
    // These wires are used to mux the manual load signals to the correct sorter
    wire manual_load_merge     = manual_load_enable && (selected_algo == 0);
    wire manual_load_cocktail = manual_load_enable && (selected_algo == 1);
    
    always @(posedge clk) begin
        if (global_reset) begin
            // Reset everything
            load_state <= LOAD_IDLE;
            manual_load_index <= 0;
            manual_we_out <= 0;
            manual_addr_out <= 0;
            manual_data_out <= 0;
            manual_load_done_flag <= 0;
            write_hold_counter <= 0;
            prev_in_manual_load <= 0;
            
        end else begin
            // Update edge detector
            prev_in_manual_load <= (main_state == STATE_MANUAL_LOAD);
            
            case (load_state)
                LOAD_IDLE: begin
                    manual_we_out <= 0;
                    manual_load_done_flag <= 0;
                    write_hold_counter <= 0;
                    
                    // Start when entering MANUAL_LOAD state
                    if (enter_manual_load) begin
                        manual_load_index <= 0;
                        load_state <= LOAD_WRITING;
                    end
                end
                
                LOAD_WRITING: begin
                    // Set up address and data for current index
                    manual_addr_out <= manual_load_index;
                    manual_data_out <= user_array[manual_load_index];
                    manual_we_out <= 1;  // Keep write enable high
                    
                    // Hold write for multiple cycles
                    if (write_hold_counter < HOLD_CYCLES) begin
                        write_hold_counter <= write_hold_counter + 1;
                    end else begin
                        // Write complete for this element
                        write_hold_counter <= 0;
                        
                        // Check if we're done with all elements
                        if (manual_load_index >= active_array_size - 1) begin
                            // Finished loading all elements
                            manual_we_out <= 0;
                            load_state <= LOAD_DONE;
                        end else begin
                            // Move to next element
                            manual_load_index <= manual_load_index + 1;
                            // Stay in LOAD_WRITING state
                        end
                    end
                end
                
                LOAD_DONE: begin
                    manual_we_out <= 0;
                    manual_load_done_flag <= 1;
                    
                    // Stay in DONE until main FSM exits MANUAL_LOAD
                    if (main_state != STATE_MANUAL_LOAD) begin
                        load_state <= LOAD_IDLE;
                        manual_load_done_flag <= 0;
                        manual_load_index <= 0;
                    end
                end
                
                default: begin
                    load_state <= LOAD_IDLE;
                    manual_we_out <= 0;
                end
            endcase
        end
    end
    
    
    // AUTO-STEP GENERATOR
    
    reg [23:0] auto_step_counter; 
    reg auto_step_pulse; 
    localparam AUTO_STEP_DELAY = 24'd5000000;
    
    wire [2:0] active_sort_state; // Muxed output of the active sorter's state
    wire active_sort_is_active = (active_sort_state == 3'd3); // 3'd3 is SORTING
    
    always @(posedge clk) begin
        if (global_reset || !active_sort_is_active) begin
            auto_step_counter <= 0;
            auto_step_pulse <= 0;
        end else begin
            if (auto_step_counter >= AUTO_STEP_DELAY - 1) begin
                auto_step_counter <= 0;
                auto_step_pulse <= 1;
            end else begin
                auto_step_counter <= auto_step_counter + 1;
                auto_step_pulse <= 0;
            end
        end
    end
    
    wire playback_mode = (main_state == STATE_PLAYBACK);
    wire effective_step = playback_mode ? btnR_edge : (active_sort_is_active ? (auto_step_pulse | btnR_edge) : 1'b0);

    
    // RANDOM SEED GENERATOR
        reg [31:0] seed_counter;
    always @(posedge clk) begin
        seed_counter <= seed_counter + 1;
    end

    
    // DUAL SORTER INSTANTIATION (From File 1)
    

    // Sorter 1: Merge Sort 
    wire merge_sort_done, merge_readback_busy;
    wire [2:0] merge_sort_state;
    wire [7:0] merge_live_array_0, merge_live_array_1, merge_live_array_2, merge_live_array_3, merge_live_array_4, merge_live_array_5, merge_live_array_6, merge_live_array_7;
    wire [7:0] merge_temp_array_0, merge_temp_array_1, merge_temp_array_2, merge_temp_array_3, merge_temp_array_4, merge_temp_array_5, merge_temp_array_6, merge_temp_array_7;
    wire [2:0] merge_compare_pos1, merge_compare_pos2;
    wire merge_comparison_active;
    wire [1:0] merge_operation_type;
    wire merge_capture_valid;
    wire [2:0] merge_write_idx;
    wire merge_src_is_live;
    wire [3:0] merge_merge_left_start, merge_merge_left_end, merge_merge_right_start, merge_merge_right_end;
    wire merge_merge_in_progress;
    wire [2:0] merge_live_addr, merge_temp_addr;
    wire [7:0] merge_live_data, merge_temp_data;
    wire merge_live_we, merge_temp_we;
    
    random_sort_simple #(.DATA_WIDTH(8), .MAX_ARRAY_SIZE(8), .ADDR_WIDTH(3)) merge_sorter (
        .clk(clk), .rst(global_reset), 
        .seed_in(seed_counter[7:0]),
        .btn_generate(trigger_generate_merge),
        .manual_load_enable(manual_load_merge), // Connects to new loader
        .manual_data_in(manual_data_out),
        .manual_addr_in(manual_addr_out),
        .manual_we_in(manual_we_out),
        .btn_start_sort(trigger_start_merge),
        .btn_step(effective_step),
        .array_size(active_array_size),
        .state(merge_sort_state), .done(merge_sort_done), .readback_busy(merge_readback_busy),
        .display_addr(3'd0), .display_data(),
        .live_array_0(merge_live_array_0), .live_array_1(merge_live_array_1), .live_array_2(merge_live_array_2), .live_array_3(merge_live_array_3),
        .live_array_4(merge_live_array_4), .live_array_5(merge_live_array_5), .live_array_6(merge_live_array_6), .live_array_7(merge_live_array_7),
        .temp_array_0(merge_temp_array_0), .temp_array_1(merge_temp_array_1), .temp_array_2(merge_temp_array_2), .temp_array_3(merge_temp_array_3),
        .temp_array_4(merge_temp_array_4), .temp_array_5(merge_temp_array_5), .temp_array_6(merge_temp_array_6), .temp_array_7(merge_temp_array_7),
        .compare_pos1(merge_compare_pos1), .compare_pos2(merge_compare_pos2), .comparison_active(merge_comparison_active),
        .operation_type(merge_operation_type), 
        .capture_valid(merge_capture_valid), 
        .capture_write_idx(merge_write_idx),
        .src_is_live(merge_src_is_live),
        .merge_left_start(merge_merge_left_start), .merge_left_end(merge_merge_left_end),
        .merge_right_start(merge_merge_right_start), .merge_right_end(merge_merge_right_end), .merge_in_progress(merge_merge_in_progress),
        .live_addr_out(merge_live_addr), .live_data_out(merge_live_data), .live_we_out(merge_live_we),
        .temp_addr_out(merge_temp_addr), .temp_data_out_delta(merge_temp_data), .temp_we_out(merge_temp_we)
    );

    // Sorter 2: Cocktail Sort 
    wire cocktail_sort_done, cocktail_readback_busy;
    wire [2:0] cocktail_sort_state;
    wire [7:0] cocktail_live_array_0, cocktail_live_array_1, cocktail_live_array_2, cocktail_live_array_3, cocktail_live_array_4, cocktail_live_array_5, cocktail_live_array_6, cocktail_live_array_7;
    wire [2:0] cocktail_compare_pos1, cocktail_compare_pos2;
    wire cocktail_comparison_active;
    wire [1:0] cocktail_operation_type;
    wire cocktail_capture_valid;
    wire [2:0] cocktail_write_idx;
    wire cocktail_src_is_live;
    wire [3:0] cocktail_left_bound, cocktail_right_bound;
    wire [2:0] cocktail_live_addr;
    wire [7:0] cocktail_live_data;
    wire cocktail_live_we;
    
    cocktail_sort_simple #(.DATA_WIDTH(8), .MAX_ARRAY_SIZE(8), .ADDR_WIDTH(3)) cocktail_sorter (
        .clk(clk), .rst(global_reset), 
        .seed_in(seed_counter[7:0]),
        .btn_generate(trigger_generate_cocktail),
        .manual_load_enable(manual_load_cocktail), // Connects to new loader
        .manual_data_in(manual_data_out),
        .manual_addr_in(manual_addr_out),
        .manual_we_in(manual_we_out),
        .btn_start_sort(trigger_start_cocktail),
        .btn_step(effective_step),
        .array_size(active_array_size),
        .state(cocktail_sort_state), .done(cocktail_sort_done), .readback_busy(cocktail_readback_busy),
        .display_addr(3'd0), .display_data(),
        .live_array_0(cocktail_live_array_0), .live_array_1(cocktail_live_array_1), .live_array_2(cocktail_live_array_2), .live_array_3(cocktail_live_array_3),
        .live_array_4(cocktail_live_array_4), .live_array_5(cocktail_live_array_5), .live_array_6(cocktail_live_array_6), .live_array_7(cocktail_live_array_7),
        
        .temp_array_0(), .temp_array_1(), .temp_array_2(), .temp_array_3(),
        .temp_array_4(), .temp_array_5(), .temp_array_6(), .temp_array_7(),
        
        .compare_pos1(cocktail_compare_pos1), .compare_pos2(cocktail_compare_pos2), .comparison_active(cocktail_comparison_active),
        .operation_type(cocktail_operation_type), 
        .capture_valid(cocktail_capture_valid), 
        .capture_write_idx(cocktail_write_idx),
        .src_is_live(cocktail_src_is_live),
        
        .cocktail_left_bound(cocktail_left_bound), 
        .cocktail_right_bound(cocktail_right_bound), 
        .cocktail_current_idx(), 
        .cocktail_forward_pass(),
        
        .live_addr_out(cocktail_live_addr), .live_data_out(cocktail_live_data), .live_we_out(cocktail_live_we),
        .temp_addr_out(), .temp_data_out_delta(), .temp_we_out()
    );

    
    // SORTER OUTPUT MUX 
        
    assign active_sort_state = (selected_algo == 0) ? merge_sort_state : cocktail_sort_state;
    wire active_sort_done    = (selected_algo == 0) ? merge_sort_done : cocktail_sort_done;
    wire active_readback_busy= (selected_algo == 0) ? merge_readback_busy : cocktail_readback_busy;

    wire [7:0] active_live_array_0 = (selected_algo == 0) ? merge_live_array_0 : cocktail_live_array_0;
    wire [7:0] active_live_array_1 = (selected_algo == 0) ? merge_live_array_1 : cocktail_live_array_1;
    wire [7:0] active_live_array_2 = (selected_algo == 0) ? merge_live_array_2 : cocktail_live_array_2;
    wire [7:0] active_live_array_3 = (selected_algo == 0) ? merge_live_array_3 : cocktail_live_array_3;
    wire [7:0] active_live_array_4 = (selected_algo == 0) ? merge_live_array_4 : cocktail_live_array_4;
    wire [7:0] active_live_array_5 = (selected_algo == 0) ? merge_live_array_5 : cocktail_live_array_5;
    wire [7:0] active_live_array_6 = (selected_algo == 0) ? merge_live_array_6 : cocktail_live_array_6;
    wire [7:0] active_live_array_7 = (selected_algo == 0) ? merge_live_array_7 : cocktail_live_array_7;
    
    wire [7:0] active_temp_array_0 = (selected_algo == 0) ? merge_temp_array_0 : 8'd0;
    wire [7:0] active_temp_array_1 = (selected_algo == 0) ? merge_temp_array_1 : 8'd0;
    wire [7:0] active_temp_array_2 = (selected_algo == 0) ? merge_temp_array_2 : 8'd0;
    wire [7:0] active_temp_array_3 = (selected_algo == 0) ? merge_temp_array_3 : 8'd0;
    wire [7:0] active_temp_array_4 = (selected_algo == 0) ? merge_temp_array_4 : 8'd0;
    wire [7:0] active_temp_array_5 = (selected_algo == 0) ? merge_temp_array_5 : 8'd0;
    wire [7:0] active_temp_array_6 = (selected_algo == 0) ? merge_temp_array_6 : 8'd0;
    wire [7:0] active_temp_array_7 = (selected_algo == 0) ? merge_temp_array_7 : 8'd0;

    wire [2:0] active_compare_pos1 = (selected_algo == 0) ? merge_compare_pos1 : cocktail_compare_pos1;
    wire [2:0] active_compare_pos2 = (selected_algo == 0) ? merge_compare_pos2 : cocktail_compare_pos2;
    wire active_comparison_active = (selected_algo == 0) ? merge_comparison_active : cocktail_comparison_active;
    wire [1:0] active_operation_type = (selected_algo == 0) ? merge_operation_type : cocktail_operation_type;
    wire active_capture_valid = (selected_algo == 0) ? merge_capture_valid : cocktail_capture_valid;
    wire active_src_is_live = (selected_algo == 0) ? merge_src_is_live : cocktail_src_is_live;
    
    // This mux now feeds BOTH the live display AND the capture buffer
    reg active_show_boundaries;
    reg [3:0] active_left_start, active_left_end, active_right_start, active_right_end;
    
    always @* begin
        if (selected_algo == 0) begin // Merge Sort
            active_show_boundaries = merge_merge_in_progress;
            active_left_start = merge_merge_left_start;
            active_left_end = merge_merge_left_end;
            active_right_start = merge_merge_right_start;
            active_right_end = merge_merge_right_end;
        end else begin // Cocktail Sort
            active_show_boundaries = active_sort_is_active;
            active_left_start = 0; // For live display, left "sorted" region is from 0
            active_left_end = cocktail_left_bound; // to the left boundary
            active_right_start = cocktail_right_bound; // Right "sorted" region is from right boundary
            active_right_end = active_array_size; // to the end
        end
    end

    reg [2:0] active_write_addr_buffer;
    reg [7:0] active_write_data_buffer;
    reg active_write_enable;
    
    always @* begin
        if (selected_algo == 0) begin // Merge Sort
            active_write_addr_buffer = active_src_is_live ? merge_temp_addr : merge_live_addr;
            active_write_data_buffer = active_src_is_live ? merge_temp_data : merge_live_data;
            active_write_enable = active_src_is_live ? merge_temp_we : merge_live_we; 
        end else begin // Cocktail Sort
            active_write_addr_buffer = cocktail_live_addr;
            active_write_data_buffer = cocktail_live_data;
            active_write_enable = cocktail_live_we; 
        end
    end
    
    wire active_write_active = active_capture_valid && !playback_mode;
    wire [2:0] active_write_idx = (selected_algo == 0) ? merge_write_idx : cocktail_write_idx;

    
    // MAIN FSM and Playback Control 
    reg show_sorted_celebration;
    reg capture_initial_done;
    reg [31:0] celebration_timer;
    localparam CELEBRATION_TIME = 100000000;
    
    reg sort_ready_delay_flag;
    // Muxed capture_initial signal
    //Added !active_readback_busy to ensure RAM data is stable before capture
    
    wire capture_initial = trigger_start_sort && !capture_initial_done;
    // New Playback Control Wires 
    wire play_pause_pulse = btnC_edge && (main_state == STATE_PLAYBACK); 
    wire step_back_pulse = btnL_edge && (main_state == STATE_PLAYBACK); 
    wire step_fwd_pulse = btnR_edge && (main_state == STATE_PLAYBACK); 
    wire go_to_first_pulse = btnD_edge && (main_state == STATE_PLAYBACK); 
    wire go_to_final_pulse = btnU_edge && (main_state == STATE_PLAYBACK); 

    reg [25:0] anim_counter_26bit;
    wire flash_bit;
    reg anim_tick_q;
    wire anim_tick;
    integer i;
    
    always @(posedge clk) begin
        anim_counter_26bit <= anim_counter_26bit + 1;
        anim_tick_q <= anim_counter_26bit[18];
    end
    
    assign flash_bit = anim_counter_26bit[24];
    assign anim_tick = anim_counter_26bit[18] & ~anim_tick_q;
    
    
    always @(posedge clk) begin
        if (global_reset) begin
            main_state <= STATE_SPLASH_SCREEN;
            show_sorted_celebration <= 0;
            celebration_timer <= 0;
            capture_initial_done <= 0;
            selected_array_size <= 4'd8;
            active_array_size <= 4'd8;
            trigger_generate <= 0;
            trigger_start_sort <= 0;
            
            sort_ready_delay_flag <= 0;
            wipe_counter <= 0;
            selected_algo <= 0;
            
            selected_entry_index <= 0;
            current_entry_value <= 0;
            for (i = 0; i < 8; i = i + 1) begin
                user_array[i] <= 0;
            end
            
        end else begin
            trigger_generate <= 0;
            trigger_start_sort <= 0;
            
            if (main_state != STATE_SORT_READY) begin 
                            sort_ready_delay_flag <= 0;
                        end
                        
            if (capture_initial) begin
                capture_initial_done <= 1;
            end
            
            case (main_state)
                STATE_SPLASH_SCREEN: begin
                    if (any_button_edge || mouse_click_edge) begin
                        wipe_counter <= 0;
                        main_state <= STATE_SPLASH_FADE_OUT;
                    end
                end

                STATE_SPLASH_FADE_OUT: begin
                    if (anim_tick) begin
                        if (wipe_counter < 64) begin
                            wipe_counter <= wipe_counter + 1;
                        end else begin
                            main_state <= STATE_ALGO_SELECT; // Go to ALGO select
                        end
                    end
                end

                STATE_ALGO_SELECT: begin
                    if (mouse_click_edge) begin
                        if (mouse_on_select_merge_btn) begin
                            selected_algo <= 0;
                            main_state <= STATE_MENU_SELECT;
                        end else if (mouse_on_select_cocktail_btn) begin
                            selected_algo <= 1;
                            main_state <= STATE_MENU_SELECT;
                        end
                    end
                end

                STATE_MENU_SELECT: begin
                    if (mouse_click_edge) begin
                        if (mouse_on_back_btn) begin 
                            main_state <= STATE_ALGO_SELECT;
                        end else if (mouse_on_select_random_btn) begin
                            main_state <= STATE_PRESCREEN_SETUP;
                        end else if (mouse_on_select_create_btn) begin
                            main_state <= STATE_CREATE_SETUP;
                        end
                    end
                end

                STATE_PRESCREEN_SETUP: begin
                    if (mouse_left_lvl && mouse_on_slider) begin
                        if (oled_mouse_x <= 18)      selected_array_size <= 4'd2;
                        else if (oled_mouse_x <= 29) selected_array_size <= 4'd3;
                        else if (oled_mouse_x <= 40) selected_array_size <= 4'd4;
                        else if (oled_mouse_x <= 51) selected_array_size <= 4'd5;
                        else if (oled_mouse_x <= 62) selected_array_size <= 4'd6;
                        else if (oled_mouse_x <= 73) selected_array_size <= 4'd7;
                        else                         selected_array_size <= 4'd8;
                    end
                    
                    if (mouse_click_edge) begin // Check for click first
                       if (mouse_on_back_btn) begin // Then check for back btn
                           main_state <= STATE_MENU_SELECT;
                       end else if (mouse_on_prescreen_sort_btn) begin // Then check for sort btn
                           active_array_size <= selected_array_size;
                           trigger_generate <= 1;
                           main_state <= STATE_GENERATE;
                           capture_initial_done <= 0;
                        end
                     end
                 end

                STATE_CREATE_SETUP: begin
                    if (mouse_left_lvl && mouse_on_slider) begin
                        if (oled_mouse_x <= 18)      selected_array_size <= 4'd2;
                        else if (oled_mouse_x <= 29) selected_array_size <= 4'd3;
                        else if (oled_mouse_x <= 40) selected_array_size <= 4'd4;
                        else if (oled_mouse_x <= 51) selected_array_size <= 4'd5;
                        else if (oled_mouse_x <= 62) selected_array_size <= 4'd6;
                        else if (oled_mouse_x <= 73) selected_array_size <= 4'd7;
                        else                         selected_array_size <= 4'd8;
                    end
                    
                    if (mouse_click_edge) begin // Check for click first
                        if (mouse_on_back_btn) begin // Then check for back btn
                            main_state <= STATE_MENU_SELECT;
                        end else if (mouse_on_create_next_btn) begin // Then check for next btn
                            active_array_size <= selected_array_size;
                            main_state <= STATE_CREATE_ENTRY;
                                
                        end
                     end
                               
                 end
                
                STATE_CREATE_ENTRY: begin
                    if (mouse_click_edge) begin
                        if (mouse_on_back_entry_btn) begin 
                            main_state <= STATE_CREATE_SETUP;
                        // Box selection logic 
                        end else if (mouse_on_box_0 && 0 < active_array_size) begin
                            if (current_entry_value > 0) user_array[selected_entry_index] <= current_entry_value;
                            selected_entry_index <= 0;
                            current_entry_value <= user_array[0];
                        end
                        else if (mouse_on_box_1 && 1 < active_array_size) begin
                            if (current_entry_value > 0) user_array[selected_entry_index] <= current_entry_value;
                            selected_entry_index <= 1;
                            current_entry_value <= user_array[1];
                        end
                        else if (mouse_on_box_2 && 2 < active_array_size) begin
                            if (current_entry_value > 0) user_array[selected_entry_index] <= current_entry_value;
                            selected_entry_index <= 2;
                            current_entry_value <= user_array[2];
                        end
                        else if (mouse_on_box_3 && 3 < active_array_size) begin
                            if (current_entry_value > 0) user_array[selected_entry_index] <= current_entry_value;
                            selected_entry_index <= 3;
                            current_entry_value <= user_array[3];
                        end
                        else if (mouse_on_box_4 && 4 < active_array_size) begin
                            if (current_entry_value > 0) user_array[selected_entry_index] <= current_entry_value;
                            selected_entry_index <= 4;
                            current_entry_value <= user_array[4];
                        end
                        else if (mouse_on_box_5 && 5 < active_array_size) begin
                            if (current_entry_value > 0) user_array[selected_entry_index] <= current_entry_value;
                            selected_entry_index <= 5;
                            current_entry_value <= user_array[5];
                        end
                        else if (mouse_on_box_6 && 6 < active_array_size) begin
                            if (current_entry_value > 0) user_array[selected_entry_index] <= current_entry_value;
                            selected_entry_index <= 6;
                            current_entry_value <= user_array[6];
                        end
                        else if (mouse_on_box_7 && 7 < active_array_size) begin
                            if (current_entry_value > 0) user_array[selected_entry_index] <= current_entry_value;
                            selected_entry_index <= 7;
                            current_entry_value <= user_array[7];
                        end
                        
                        // Numpad logic 
                        else if (mouse_on_num_1 && current_entry_value < 10) current_entry_value <= (current_entry_value * 10) + 1;
                        else if (mouse_on_num_2 && current_entry_value < 10) current_entry_value <= (current_entry_value * 10) + 2;
                        else if (mouse_on_num_3 && current_entry_value < 10) current_entry_value <= (current_entry_value * 10) + 3;
                        else if (mouse_on_num_4 && current_entry_value < 10) current_entry_value <= (current_entry_value * 10) + 4;
                        else if (mouse_on_num_5 && current_entry_value < 10) current_entry_value <= (current_entry_value * 10) + 5;
                        else if (mouse_on_num_6 && current_entry_value < 10) current_entry_value <= (current_entry_value * 10) + 6;
                        else if (mouse_on_num_7 && current_entry_value < 10) current_entry_value <= (current_entry_value * 10) + 7;
                        else if (mouse_on_num_8 && current_entry_value < 10) current_entry_value <= (current_entry_value * 10) + 8;
                        else if (mouse_on_num_9 && current_entry_value < 10) current_entry_value <= (current_entry_value * 10) + 9;
                        else if (mouse_on_num_0 && current_entry_value < 10) current_entry_value <= (current_entry_value * 10) + 0;
                        
                        else if (mouse_on_bs) current_entry_value <= current_entry_value / 10;
                        
                        else if (mouse_on_enter) begin
                            user_array[selected_entry_index] <= current_entry_value;
                            if (selected_entry_index < active_array_size - 1) begin
                                selected_entry_index <= selected_entry_index + 1;
                                current_entry_value <= user_array[selected_entry_index + 1];
                            end else begin
                                current_entry_value <= 0;
                            end
                        end
                        
                        // "SORT" Button 
                        else if (mouse_on_create_sort_btn) begin
                            if (current_entry_value > 0) begin
                                user_array[selected_entry_index] <= current_entry_value;
                            end
                            current_entry_value <= 0;
                            selected_entry_index <= 0;
                            main_state <= STATE_MANUAL_PREP; // Go to prep state
                            wipe_counter <= 0; // Use wipe_counter for delay
                            capture_initial_done <= 0;
                        end
                    end
                end

                STATE_MANUAL_PREP: begin
                    // Wait a few cycles for final user_array write to settle
                    if (wipe_counter < 3) begin
                        wipe_counter <= wipe_counter + 1;
                    end else begin
                        wipe_counter <= 0;
                        main_state <= STATE_MANUAL_LOAD;
                    end
                end
                
                STATE_MANUAL_LOAD: begin
                    if (manual_load_finished) begin
                        main_state <= STATE_SORT_READY;
                    end
                end
                
                STATE_GENERATE: begin
                    if (active_sort_state == 3'd2) begin // 3'd2 is READY
                        main_state <= STATE_SORT_READY;
                    end
                end
                
                STATE_SORT_READY: begin
                            // Wait for sorter to be READY (3'd2)
                            if (active_sort_state == 3'd2) begin
                                
                                if (!sort_ready_delay_flag) begin
                                    // This is the first cycle we've seen the sorter is READY.
                                    // Set the flag and wait one cycle. This allows
                                    // active_readback_busy to go HIGH, preventing the race.
                                    sort_ready_delay_flag <= 1;
                                end
                                // Now that the flag is set, we can safely check readback_busy
                                else if (!active_readback_busy) begin  
                                    trigger_start_sort <= 1;
                                    main_state <= STATE_SORTING;
                                end
                                
                            end
                        end

                STATE_SORTING: begin
                    if (active_sort_done) begin
                        main_state <= STATE_CELEBRATE;
                        celebration_timer <= 0;
                        show_sorted_celebration <= 1;
                    end
                end
                
                STATE_CELEBRATE: begin
                    if (btnR_edge) begin
                        show_sorted_celebration <= 0;
                        main_state <= STATE_PLAYBACK;
                    end
                end
                
                STATE_PLAYBACK: begin
                    // Playback controls are handled by delta_buf
                end

            endcase
        end
    end
           
    wire [5:0] current_step, total_steps;
    wire is_playing, debug_capture_pulse, debug_initial_captured;
    wire [5:0] debug_write_ptr;
    
    delta_animation_buffer #(.DATA_WIDTH(8), .ARRAY_SIZE(8), .MAX_OPERATIONS(64), .BASE_DELAY(25000000)) delta_buf (
        .clk(clk), .rst(global_reset), .capture_initial(capture_initial),
        .init_array_0(active_live_array_0), .init_array_1(active_live_array_1), .init_array_2(active_live_array_2), .init_array_3(active_live_array_3),
        .init_array_4(active_live_array_4), .init_array_5(active_live_array_5), .init_array_6(active_live_array_6), .init_array_7(active_live_array_7),
        .num_bars(active_array_size), 
        
        .operation_valid(active_capture_valid),
        .write_addr(active_write_addr_buffer),
        .write_data(active_write_data_buffer),
        .write_enable(active_write_enable),
        .compare_pos1(active_compare_pos1), .compare_pos2(active_compare_pos2), .comparison_active(active_comparison_active),
        .merge_left_start(active_left_start),
        .merge_left_end(active_left_end),
        .merge_right_start(active_right_start),
        .merge_right_end(active_right_end),
        .merge_active(active_show_boundaries), 
        .sort_finished(active_sort_done),
        
        .play_pause_pulse(play_pause_pulse), 
        .back_pulse(step_back_pulse), 
        .step_fwd_pulse(step_fwd_pulse),       
        .go_to_first_pulse(go_to_first_pulse), 
        .go_to_final_pulse(go_to_final_pulse), 
        .speed_select(speed_select_wires),
        
        .playback_array_0(playback_array_0), .playback_array_1(playback_array_1),
        .playback_array_2(playback_array_2), .playback_array_3(playback_array_3),
        .playback_array_4(playback_array_4), .playback_array_5(playback_array_5),
        .playback_array_6(playback_array_6), .playback_array_7(playback_array_7),
        .playback_pos1(playback_pos1), .playback_pos2(playback_pos2),
        .playback_comparison_active(playback_comparison_active),
        .playback_merge_left_start(playback_merge_left_start),
        .playback_merge_left_end(playback_merge_left_end),
        .playback_merge_right_start(playback_merge_right_start),
        .playback_merge_right_end(playback_merge_right_end),
        .playback_merge_active(playback_merge_active), 
        .current_operation(current_step), .total_operations(total_steps),
        .is_playing(is_playing), .debug_capture_pulse(debug_capture_pulse),
        .debug_write_ptr(debug_write_ptr), .debug_initial_captured(debug_initial_captured)
    );
    
    
    // Display Muxing
        
    wire [7:0] live_display_0 = active_src_is_live ? active_live_array_0 : active_temp_array_0;
    wire [7:0] live_display_1 = active_src_is_live ? active_live_array_1 : active_temp_array_1;
    wire [7:0] live_display_2 = active_src_is_live ? active_live_array_2 : active_temp_array_2;
    wire [7:0] live_display_3 = active_src_is_live ? active_live_array_3 : active_temp_array_3;
    wire [7:0] live_display_4 = active_src_is_live ? active_live_array_4 : active_temp_array_4;
    wire [7:0] live_display_5 = active_src_is_live ? active_live_array_5 : active_temp_array_5;
    wire [7:0] live_display_6 = active_src_is_live ? active_live_array_6 : active_temp_array_6;
    wire [7:0] live_display_7 = active_src_is_live ? active_live_array_7 : active_temp_array_7;
    
    wire [7:0] display_array_0 = playback_mode ? playback_array_0 : live_display_0;
    wire [7:0] display_array_1 = playback_mode ? playback_array_1 : live_display_1;
    wire [7:0] display_array_2 = playback_mode ? playback_array_2 : live_display_2;
    wire [7:0] display_array_3 = playback_mode ? playback_array_3 : live_display_3;
    wire [7:0] display_array_4 = playback_mode ? playback_array_4 : live_display_4;
    wire [7:0] display_array_5 = playback_mode ? playback_array_5 : live_display_5;
    wire [7:0] display_array_6 = playback_mode ? playback_array_6 : live_display_6;
    wire [7:0] display_array_7 = playback_mode ? playback_array_7 : live_display_7;
    
    wire [2:0] display_pos1 = playback_mode ? playback_pos1 : active_compare_pos1;
    wire [2:0] display_pos2 = playback_mode ? playback_pos2 : active_compare_pos2;
    
    // Mux all 4 boundary signals for playback
    wire display_merge_active = playback_mode ? playback_merge_active : active_show_boundaries;
    wire [3:0] display_merge_left_start = playback_mode ? playback_merge_left_start : active_left_start;
    wire [3:0] display_merge_left_end = playback_mode ? playback_merge_left_end : active_left_end;
    wire [3:0] display_merge_right_start = playback_mode ? playback_merge_right_start : active_right_start;
    wire [3:0] display_merge_right_end = playback_mode ? playback_merge_right_end : active_right_end;
    
    wire [2:0] display_write_idx = playback_mode ? 3'b111 : active_write_idx;
    wire display_write_active = playback_mode ? 1'b0 : active_write_active;
    
    wire positions_valid = (display_pos1 != display_pos2) && (display_pos1 < active_array_size) && (display_pos2 < active_array_size);
    wire raw_comparison_active = playback_mode ? playback_comparison_active : active_comparison_active;
    wire display_comparison_active = raw_comparison_active && (playback_mode || (active_sort_is_active && positions_valid));
    
    reg [4:0] sort_anim_counter;
    reg [19:0] sort_anim_clk_counter;
    wire sort_anim_clk_tick = (sort_anim_clk_counter == 20'd500000);
    always @(posedge clk) begin
        if (global_reset || !display_comparison_active) begin
            sort_anim_clk_counter <= 0; sort_anim_counter <= 0;
        end else if (sort_anim_clk_tick) begin
            sort_anim_clk_counter <= 0;
            if (sort_anim_counter < 31) begin
                sort_anim_counter <= sort_anim_counter + 1;
            end
        end else begin
            sort_anim_clk_counter <= sort_anim_clk_counter + 1;
        end
    end

    wire [12:0] pixel_in;

    // Mouse Cursor GFX 
    wire [15:0] cursor_pixel;
    mouse_cursor_gfx mc (
        .pixel_index(pixel_in), 
        .mouse_x(oled_mouse_x), 
        .mouse_y(oled_mouse_y), 
        .mouse_click_lvl(mouse_left_lvl),
        .pixel_colour(cursor_pixel)
    );

    // Verialgo Splash Screen GFX 
    wire [15:0] splash_screen_color_out;
    verialgo_splash_gfx verialgo_splash (
        .pixel_index(pixel_in),
        .flash_bit(flash_bit),
        .animation_wipe_y(wipe_counter),
        .pixel_colour(splash_screen_color_out)
    );

    // Algorithm Selection Screen GFX 
    wire [15:0] algo_select_color_out;
    algo_selection_gfx algo_menu (
        .pixel_index(pixel_in),
        .mouse_on_merge_btn(mouse_on_select_merge_btn),
        .mouse_on_cocktail_btn(mouse_on_select_cocktail_btn),
        .mouse_click_lvl(mouse_left_lvl),
        .pixel_colour(algo_select_color_out)
    );

    // Data Selection Screen GFX 
    wire [15:0] selection_screen_color_out;
    selection_screen_gfx select_menu (
        .pixel_index(pixel_in),
        .mouse_on_random_btn(mouse_on_select_random_btn),
        .mouse_on_create_btn(mouse_on_select_create_btn),
        .mouse_click_lvl(mouse_left_lvl),
        .mouse_on_back_btn(mouse_on_back_btn),
        .pixel_colour(selection_screen_color_out)
    );

    // Prescreen (Random Sort Setup) GFX Wires 
    wire [15:0] prescreen_color_out;
    prescreen_gfx menu (
        .pixel_index(pixel_in),
        .array_size(selected_array_size),
        .selected_algo(selected_algo),  
        .mouse_on_button(mouse_on_prescreen_sort_btn),
        .mouse_on_back_btn(mouse_on_back_btn),
        .pixel_colour(prescreen_color_out)
    );

    // Create Setup GFX Wires 
    wire [15:0] create_setup_color_out;
    create_setup_gfx create_menu (
        .pixel_index(pixel_in),
        .array_size(selected_array_size),
        .mouse_on_button(mouse_on_create_next_btn),
        .mouse_on_back_btn(mouse_on_back_btn),
        .pixel_colour(create_setup_color_out)
    );

    // Array Entry GFX Wires 
    
    wire [7:0] gfx_array_0 = (selected_entry_index == 0) ? current_entry_value : user_array[0];
    wire [7:0] gfx_array_1 = (selected_entry_index == 1) ? current_entry_value : user_array[1];
    wire [7:0] gfx_array_2 = (selected_entry_index == 2) ? current_entry_value : user_array[2];
    wire [7:0] gfx_array_3 = (selected_entry_index == 3) ? current_entry_value : user_array[3];
    wire [7:0] gfx_array_4 = (selected_entry_index == 4) ? current_entry_value : user_array[4];
    wire [7:0] gfx_array_5 = (selected_entry_index == 5) ? current_entry_value : user_array[5];
    wire [7:0] gfx_array_6 = (selected_entry_index == 6) ? current_entry_value : user_array[6];
    wire [7:0] gfx_array_7 = (selected_entry_index == 7) ? current_entry_value : user_array[7];
    
    wire [15:0] array_entry_color_out;
    array_entry_gfx entry_screen (
        .pixel_index(pixel_in),
        .active_array_size(active_array_size),
        .user_array_0(gfx_array_0), .user_array_1(gfx_array_1),
        .user_array_2(gfx_array_2), .user_array_3(gfx_array_3),
        .user_array_4(gfx_array_4), .user_array_5(gfx_array_5),
        .user_array_6(gfx_array_6), .user_array_7(gfx_array_7),
        .selected_entry_index(selected_entry_index),
        .mouse_on_box_0(mouse_on_box_0), .mouse_on_box_1(mouse_on_box_1),
        .mouse_on_box_2(mouse_on_box_2), .mouse_on_box_3(mouse_on_box_3),
        .mouse_on_box_4(mouse_on_box_4), .mouse_on_box_5(mouse_on_box_5),
        .mouse_on_box_6(mouse_on_box_6), .mouse_on_box_7(mouse_on_box_7),
        .mouse_on_num_1(mouse_on_num_1), .mouse_on_num_2(mouse_on_num_2), .mouse_on_num_3(mouse_on_num_3),
        .mouse_on_num_4(mouse_on_num_4), .mouse_on_num_5(mouse_on_num_5), .mouse_on_num_6(mouse_on_num_6),
        .mouse_on_num_7(mouse_on_num_7), .mouse_on_num_8(mouse_on_num_8), .mouse_on_num_9(mouse_on_num_9),
        .mouse_on_bs(mouse_on_bs), .mouse_on_num_0(mouse_on_num_0), .mouse_on_enter(mouse_on_enter),
        .mouse_on_sort_btn(mouse_on_create_sort_btn),
        .mouse_on_back_btn(mouse_on_back_entry_btn),
        .pixel_colour(array_entry_color_out)
    );

    // Sort GFX Wires 
    wire [15:0] bar_color_1 = 16'b11111_000000_00000;
    wire [15:0] bar_color_2 = 16'b00000_000000_11111;
    wire [15:0] sort_visual_color_out;
    
    eight_bars_with_numbers #(
        .W(96), .H(64), .COL_BG(16'b00000_000000_00000), .COL_NUM(16'b11111_111111_11111),
        .COL_SWAP(16'b00000_111111_00000), 
        .COL_LEFT_ARRAY(16'b00000_111111_00000), 
        .COL_RIGHT_ARRAY(16'b00000_111111_00000),
        .COL_HIGHLIGHT(16'hFBE0),
        .OFFSET(5), .MIN_HEIGHT(8), .MAX_HEIGHT(45)
    ) drawer (
        .pixel_index(pixel_in), .bar_color_1(bar_color_1), .bar_color_2(bar_color_2), .num_bars(active_array_size),
        .height_1(display_array_0[6:0]), .height_2(display_array_1[6:0]), .height_3(display_array_2[6:0]), .height_4(display_array_3[6:0]),
        .height_5(display_array_4[6:0]), .height_6(display_array_5[6:0]), .height_7(display_array_6[6:0]), .height_8(display_array_7[6:0]),
        .animate_swap(display_comparison_active), .swap_idx_1(display_pos1), .swap_idx_2(display_pos2), .anim_progress(sort_anim_counter),
        .show_all_green(show_sorted_celebration), .show_merge_boundaries(display_merge_active),
        
        // Pass all 4 boundary signals
        .merge_left_start(display_merge_left_start), 
        .merge_left_end(display_merge_left_end),
        .merge_right_start(display_merge_right_start), 
        .merge_right_end(display_merge_right_end), 
        
        .write_idx(display_write_idx),
        .write_active(display_write_active),
        .is_playback(playback_mode),
        .current_playback_step(current_step),
        .total_playback_steps(total_steps),
        
        .pixel_colour(sort_visual_color_out)
    );
    
    // Final OLED Mux 
    wire fb, send_pix, sample_pix;
    wire [15:0] oled_colour;
    
    reg [15:0] base_color;
    always @* begin
        case (main_state)
            STATE_SPLASH_SCREEN:   base_color = splash_screen_color_out;
            STATE_SPLASH_FADE_OUT: base_color = splash_screen_color_out;
            STATE_ALGO_SELECT:     base_color = algo_select_color_out;
            STATE_MENU_SELECT:     base_color = selection_screen_color_out;
            STATE_PRESCREEN_SETUP: base_color = prescreen_color_out;
            STATE_CREATE_SETUP:    base_color = create_setup_color_out;
            STATE_CREATE_ENTRY:    base_color = array_entry_color_out;
            default:               base_color = sort_visual_color_out;
        endcase
    end
    // Playback Indicator 
    wire [15:0] indicator_color;
    wire show_playback_indicator = (main_state == STATE_PLAYBACK) || (main_state == STATE_SORTING);
    
    playback_indicator_gfx playback_ind (
        .pixel_index(pixel_in),
        .speed_select(speed_select_wires),
        .is_paused(!is_playing),  // Paused when NOT playing
        .show_indicator(show_playback_indicator),
        .pixel_colour(indicator_color)
    );
    
    // Layer the indicator on top of base color
    wire [15:0] color_with_indicator = (indicator_color != 16'h0001) ? indicator_color : base_color;
    
    // Then layer cursor on top of everything
    assign oled_colour = (cursor_pixel != 16'h0001 && 
                         (main_state == STATE_ALGO_SELECT ||
                          main_state == STATE_MENU_SELECT || 
                          main_state == STATE_PRESCREEN_SETUP ||
                          main_state == STATE_CREATE_SETUP ||
                          main_state == STATE_CREATE_ENTRY)) ? cursor_pixel : color_with_indicator;
    
    Oled_Display student_oled(
        .clk(clk_6p25), .reset(1'b0), .frame_begin(fb), .sending_pixels(send_pix),
        .sample_pixel(sample_pix), .pixel_index(pixel_in), .pixel_data(oled_colour),
        .cs(JC[0]), .sdin(JC[1]), .sclk(JC[3]), .d_cn(JC[4]), .resn(JC[5]), .vccen(JC[6]), .pmoden(JC[7])
    );
    assign JC[2] = 1'b0;
    
//    // LEDs
//   assign led[3:0] = main_state;
//    assign led[7:4] = active_array_size;  // Show array size on LEDs 4-7
//    assign led[11:8] = merge_sort_state;  // Show merge sort state
//    assign led[12] = selected_algo;
//    assign led[13] = mouse_on_select_create_btn;
//    assign led[14] = mouse_on_prescreen_sort_btn;
//    assign led[15] = active_readback_busy;

endmodule