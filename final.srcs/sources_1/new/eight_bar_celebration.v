`timescale 1ns / 1ps

module eight_bars_with_numbers #(
    parameter integer W  = 96,
    parameter integer H  = 64,
    parameter [15:0] COL_BG  = 16'b00000_000000_00000,
    parameter [15:0] COL_NUM = 16'b11111_111111_11111,
    parameter [15:0] COL_SWAP = 16'b00000_111111_00000,
    parameter [15:0] COL_LEFT_ARRAY = 16'b11111_111100_00000,
    parameter [15:0] COL_RIGHT_ARRAY = 16'b11111_000000_11111,
    parameter [15:0] COL_HIGHLIGHT = 16'hFBE0, // Color for write pointer
    parameter integer OFFSET = 5,
    parameter integer MIN_HEIGHT = 8,
    parameter integer MAX_HEIGHT = 45
)(
    input  wire [12:0] pixel_index,
    input  wire [15:0] bar_color_1,
    input  wire [15:0] bar_color_2,
    input  wire [3:0]  num_bars,
    input  wire [6:0]  height_1, height_2, height_3, height_4,
                       height_5, height_6, height_7, height_8,
    input  wire        animate_swap,
    input  wire [2:0]  swap_idx_1,
    input  wire [2:0]  swap_idx_2,
    input  wire [4:0]  anim_progress,
    input  wire        show_all_green,
    input  wire        show_merge_boundaries,
    input  wire [3:0]  merge_left_start,
    input  wire [3:0]  merge_left_end,
    input  wire [3:0]  merge_right_start,
    input  wire [3:0]  merge_right_end,
    
    // Inputs for write pointer
    input  wire [2:0]  write_idx,
    input  wire        write_active,
    input  wire        is_playback,
    input  wire [5:0]  current_playback_step,
    input  wire [5:0]  total_playback_steps,
    
    output reg  [15:0] pixel_colour
);

    wire [6:0] x = pixel_index % W;
    wire [5:0] y = pixel_index / W;

    localparam BAR_WIDTH   = 10;
    localparam BAR_SPACING = 12;

    reg [6:0] center_offset;
    always @* begin
        case (num_bars)
            1: center_offset = 43;
            2: center_offset = 36;
            3: center_offset = 30;
            4: center_offset = 24;
            5: center_offset = 18;
            6: center_offset = 12;
            7: center_offset = 6;
            default: center_offset = 0;
        endcase
    end

    wire [6:0] bar_x_0 = center_offset;
    wire [6:0] bar_x_1 = center_offset + 12;
    wire [6:0] bar_x_2 = center_offset + 24;
    wire [6:0] bar_x_3 = center_offset + 36;
    wire [6:0] bar_x_4 = center_offset + 48;
    wire [6:0] bar_x_5 = center_offset + 60;
    wire [6:0] bar_x_6 = center_offset + 72;
    wire [6:0] bar_x_7 = center_offset + 84;

    wire [6:0] scaled_height_1 = MIN_HEIGHT + (((height_1 > 0 ? height_1 - 1 : 0) * (MAX_HEIGHT - MIN_HEIGHT)) / 98);
    wire [6:0] scaled_height_2 = MIN_HEIGHT + (((height_2 > 0 ? height_2 - 1 : 0) * (MAX_HEIGHT - MIN_HEIGHT)) / 98);
    wire [6:0] scaled_height_3 = MIN_HEIGHT + (((height_3 > 0 ? height_3 - 1 : 0) * (MAX_HEIGHT - MIN_HEIGHT)) / 98);
    wire [6:0] scaled_height_4 = MIN_HEIGHT + (((height_4 > 0 ? height_4 - 1 : 0) * (MAX_HEIGHT - MIN_HEIGHT)) / 98);
    wire [6:0] scaled_height_5 = MIN_HEIGHT + (((height_5 > 0 ? height_5 - 1 : 0) * (MAX_HEIGHT - MIN_HEIGHT)) / 98);
    wire [6:0] scaled_height_6 = MIN_HEIGHT + (((height_6 > 0 ? height_6 - 1 : 0) * (MAX_HEIGHT - MIN_HEIGHT)) / 98);
    wire [6:0] scaled_height_7 = MIN_HEIGHT + (((height_7 > 0 ? height_7 - 1 : 0) * (MAX_HEIGHT - MIN_HEIGHT)) / 98);
    wire [6:0] scaled_height_8 = MIN_HEIGHT + (((height_8 > 0 ? height_8 - 1 : 0) * (MAX_HEIGHT - MIN_HEIGHT)) / 98);

    wire in_bar_0 = (x >= bar_x_0) && (x < bar_x_0 + BAR_WIDTH) && (0 < num_bars);
    wire in_bar_1 = (x >= bar_x_1) && (x < bar_x_1 + BAR_WIDTH) && (1 < num_bars);
    wire in_bar_2 = (x >= bar_x_2) && (x < bar_x_2 + BAR_WIDTH) && (2 < num_bars);
    wire in_bar_3 = (x >= bar_x_3) && (x < bar_x_3 + BAR_WIDTH) && (3 < num_bars);
    wire in_bar_4 = (x >= bar_x_4) && (x < bar_x_4 + BAR_WIDTH) && (4 < num_bars);
    wire in_bar_5 = (x >= bar_x_5) && (x < bar_x_5 + BAR_WIDTH) && (5 < num_bars);
    wire in_bar_6 = (x >= bar_x_6) && (x < bar_x_6 + BAR_WIDTH) && (6 < num_bars);
    wire in_bar_7 = (x >= bar_x_7) && (x < bar_x_7 + BAR_WIDTH) && (7 < num_bars);

    wire [6:0] bar_top_0 = H - OFFSET - scaled_height_1;
    wire [6:0] bar_top_1 = H - OFFSET - scaled_height_2;
    wire [6:0] bar_top_2 = H - OFFSET - scaled_height_3;
    wire [6:0] bar_top_3 = H - OFFSET - scaled_height_4;
    wire [6:0] bar_top_4 = H - OFFSET - scaled_height_5;
    wire [6:0] bar_top_5 = H - OFFSET - scaled_height_6;
    wire [6:0] bar_top_6 = H - OFFSET - scaled_height_7;
    wire [6:0] bar_top_7 = H - OFFSET - scaled_height_8;

    wire in_bar_height_0 = (y >= bar_top_0) && (y < H - OFFSET);
    wire in_bar_height_1 = (y >= bar_top_1) && (y < H - OFFSET);
    wire in_bar_height_2 = (y >= bar_top_2) && (y < H - OFFSET);
    wire in_bar_height_3 = (y >= bar_top_3) && (y < H - OFFSET);
    wire in_bar_height_4 = (y >= bar_top_4) && (y < H - OFFSET);
    wire in_bar_height_5 = (y >= bar_top_5) && (y < H - OFFSET);
    wire in_bar_height_6 = (y >= bar_top_6) && (y < H - OFFSET);
    wire in_bar_height_7 = (y >= bar_top_7) && (y < H - OFFSET);

    wire draw_bar_0 = in_bar_0 && in_bar_height_0;
    wire draw_bar_1 = in_bar_1 && in_bar_height_1;
    wire draw_bar_2 = in_bar_2 && in_bar_height_2;
    wire draw_bar_3 = in_bar_3 && in_bar_height_3;
    wire draw_bar_4 = in_bar_4 && in_bar_height_4;
    wire draw_bar_5 = in_bar_5 && in_bar_height_5;
    wire draw_bar_6 = in_bar_6 && in_bar_height_6;
    wire draw_bar_7 = in_bar_7 && in_bar_height_7;

    wire in_left_merge = show_merge_boundaries && 
                         ((draw_bar_0 && (0 >= merge_left_start && 0 < merge_left_end)) ||
                         (draw_bar_1 && (1 >= merge_left_start && 1 < merge_left_end)) ||
                         (draw_bar_2 && (2 >= merge_left_start && 2 < merge_left_end)) ||
                         (draw_bar_3 && (3 >= merge_left_start && 3 < merge_left_end)) ||
                         (draw_bar_4 && (4 >= merge_left_start && 4 < merge_left_end)) ||
                         (draw_bar_5 && (5 >= merge_left_start && 5 < merge_left_end)) ||
                         (draw_bar_6 && (6 >= merge_left_start && 6 < merge_left_end)) ||
                         (draw_bar_7 && (7 >= merge_left_start && 7 < merge_left_end)));

    wire in_right_merge = show_merge_boundaries && 
                          ((draw_bar_0 && (0 >= merge_right_start && 0 < merge_right_end)) ||
                          (draw_bar_1 && (1 >= merge_right_start && 1 < merge_right_end)) ||
                          (draw_bar_2 && (2 >= merge_right_start && 2 < merge_right_end)) ||
                          (draw_bar_3 && (3 >= merge_right_start && 3 < merge_right_end)) ||
                          (draw_bar_4 && (4 >= merge_right_start && 4 < merge_right_end)) ||
                          (draw_bar_5 && (5 >= merge_right_start && 5 < merge_right_end)) ||
                          (draw_bar_6 && (6 >= merge_right_start && 6 < merge_right_end)) ||
                          (draw_bar_7 && (7 >= merge_right_start && 7 < merge_right_end)));

    wire [2:0] active_bar = draw_bar_0 ? 3'd0 :
                            draw_bar_1 ? 3'd1 :
                            draw_bar_2 ? 3'd2 :
                            draw_bar_3 ? 3'd3 :
                            draw_bar_4 ? 3'd4 :
                            draw_bar_5 ? 3'd5 :
                            draw_bar_6 ? 3'd6 : 3'd7;

    wire animate_bar_0 = animate_swap && (swap_idx_1 == 0 || swap_idx_2 == 0);
    wire animate_bar_1 = animate_swap && (swap_idx_1 == 1 || swap_idx_2 == 1);
    wire animate_bar_2 = animate_swap && (swap_idx_1 == 2 || swap_idx_2 == 2);
    wire animate_bar_3 = animate_swap && (swap_idx_1 == 3 || swap_idx_2 == 3);
    wire animate_bar_4 = animate_swap && (swap_idx_1 == 4 || swap_idx_2 == 4);
    wire animate_bar_5 = animate_swap && (swap_idx_1 == 5 || swap_idx_2 == 5);
    wire animate_bar_6 = animate_swap && (swap_idx_1 == 6 || swap_idx_2 == 6);
    wire animate_bar_7 = animate_swap && (swap_idx_1 == 7 || swap_idx_2 == 7);

    wire is_animating = (animate_bar_0 && draw_bar_0) ||
                        (animate_bar_1 && draw_bar_1) ||
                        (animate_bar_2 && draw_bar_2) ||
                        (animate_bar_3 && draw_bar_3) ||
                        (animate_bar_4 && draw_bar_4) ||
                        (animate_bar_5 && draw_bar_5) ||
                        (animate_bar_6 && draw_bar_6) ||
                        (animate_bar_7 && draw_bar_7);

    wire any_bar_drawn = draw_bar_0 | draw_bar_1 | draw_bar_2 | draw_bar_3 | 
                         draw_bar_4 | draw_bar_5 | draw_bar_6 | draw_bar_7;

    function [14:0] get_digit_bitmap;
        input [3:0] digit;
        begin
            case (digit)
                0: get_digit_bitmap = 15'b111_101_101_101_111;
                1: get_digit_bitmap = 15'b010_110_010_010_111;
                2: get_digit_bitmap = 15'b111_001_111_100_111;
                3: get_digit_bitmap = 15'b111_001_111_001_111;
                4: get_digit_bitmap = 15'b101_101_111_001_001;
                5: get_digit_bitmap = 15'b111_100_111_001_111;
                6: get_digit_bitmap = 15'b111_100_111_101_111;
                7: get_digit_bitmap = 15'b111_001_001_001_001;
                8: get_digit_bitmap = 15'b111_101_111_101_111;
                9: get_digit_bitmap = 15'b111_101_111_001_111;
                default: get_digit_bitmap = 15'b000_000_000_000_000;
            endcase
        end
    endfunction

    wire [2:0] current_bar_idx = 
        in_bar_0 ? 3'd0 :
        in_bar_1 ? 3'd1 :
        in_bar_2 ? 3'd2 :
        in_bar_3 ? 3'd3 :
        in_bar_4 ? 3'd4 :
        in_bar_5 ? 3'd5 :
        in_bar_6 ? 3'd6 : 3'd7;
    
    wire [6:0] current_bar_value = 
        in_bar_0 ? height_1 :
        in_bar_1 ? height_2 :
        in_bar_2 ? height_3 :
        in_bar_3 ? height_4 :
        in_bar_4 ? height_5 :
        in_bar_5 ? height_6 :
        in_bar_6 ? height_7 : height_8;
    
    wire [6:0] current_bar_x = 
        in_bar_0 ? bar_x_0 :
        in_bar_1 ? bar_x_1 :
        in_bar_2 ? bar_x_2 :
        in_bar_3 ? bar_x_3 :
        in_bar_4 ? bar_x_4 :
        in_bar_5 ? bar_x_5 :
        in_bar_6 ? bar_x_6 : bar_x_7;
    
    wire [6:0] current_bar_top = 
        in_bar_0 ? bar_top_0 :
        in_bar_1 ? bar_top_1 :
        in_bar_2 ? bar_top_2 :
        in_bar_3 ? bar_top_3 :
        in_bar_4 ? bar_top_4 :
        in_bar_5 ? bar_top_5 :
        in_bar_6 ? bar_top_6 : bar_top_7;

    wire in_any_bar = in_bar_0 || in_bar_1 || in_bar_2 || in_bar_3 || 
                      in_bar_4 || in_bar_5 || in_bar_6 || in_bar_7;

    wire [3:0] tens_digit = current_bar_value / 10;
    wire [3:0] ones_digit = current_bar_value % 10;
    wire has_tens = (current_bar_value >= 10);
    
    wire [6:0] num_y_start = (current_bar_top >= 8) ? current_bar_top - 7 : 0;
    wire [6:0] bar_center_x = current_bar_x + 5; 
    
    wire [6:0] ones_x_start = has_tens ? bar_center_x : (bar_center_x - 1);
    wire [6:0] tens_x_start = bar_center_x - 4;
    
    wire in_number_y = (y >= num_y_start) && (y < num_y_start + 5);
    wire in_ones_x = (x >= ones_x_start) && (x < ones_x_start + 3);
    wire in_tens_x = has_tens && (x >= tens_x_start) && (x < tens_x_start + 3);
    
    wire [1:0] digit_x_ones = x - ones_x_start;
    wire [1:0] digit_x_tens = x - tens_x_start;
    wire [2:0] digit_y = y - num_y_start; 
    
    wire [14:0] ones_bitmap = get_digit_bitmap(ones_digit);
    wire [14:0] tens_bitmap = get_digit_bitmap(tens_digit);
    
    wire [3:0] bit_index_ones = digit_y * 3 + digit_x_ones;
    wire [3:0] bit_index_tens = digit_y * 3 + digit_x_tens;
    
    wire ones_pixel = ones_bitmap[14 - bit_index_ones];
    wire tens_pixel = tens_bitmap[14 - bit_index_tens];
    
    wire draw_number = in_any_bar && in_number_y && 
                       ((in_ones_x && ones_pixel) || (in_tens_x && tens_pixel));

    // Check if this number should be highlighted as a write destination
    wire is_write_target = write_active && (current_bar_idx == write_idx);
    
    // Check if this is the last step of playback
    wire on_last_playback_step = is_playback && (current_playback_step == total_playback_steps) && (total_playback_steps > 0);

    // Final color selection logic
    always @* begin
        if (draw_number) begin
            // Highlight write destination number
            if (is_write_target)
                pixel_colour = COL_HIGHLIGHT;
            else
                pixel_colour = COL_NUM;
        end else if (any_bar_drawn) begin
            // 1. Show all green if celebrating OR on the last playback frame
            if (show_all_green || on_last_playback_step)
                pixel_colour = COL_SWAP; // Green
            // 2. Show animating bars as green
            else if (is_animating)
                pixel_colour = COL_SWAP; // Green
            // 3. Show sorted regions as green 
            else if (in_left_merge)
                pixel_colour = COL_SWAP; // Green
            else if (in_right_merge)
                pixel_colour = COL_SWAP; // Green
            // 4. show as unsorted red/blue
            else
                pixel_colour = (active_bar[0] == 0) ? bar_color_1 : bar_color_2;
        end else begin
            pixel_colour = COL_BG;
        end
    end

endmodule