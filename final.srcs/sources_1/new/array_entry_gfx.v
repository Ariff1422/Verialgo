`timescale 1ns / 1ps

// Create Mode Array Entry Screen GFX
// - Renders array boxes with better borders
// - Renders numbers inside boxes
// - Renders numpad with borders and better spacing
// - Renders "SORT" button
// - Renders Back Arrow (Bottom Right)

module array_entry_gfx #(
    parameter W = 96,
    parameter H = 64,
    parameter ADDR_WIDTH = 3,
    parameter DATA_WIDTH = 8
)(
    input wire [12:0] pixel_index,
    input wire [ADDR_WIDTH:0] active_array_size,
    input wire [DATA_WIDTH-1:0] user_array_0, user_array_1, user_array_2, user_array_3,
    input wire [DATA_WIDTH-1:0] user_array_4, user_array_5, user_array_6, user_array_7,
    input wire [ADDR_WIDTH-1:0] selected_entry_index,
    
    // Mouse hover inputs
    input wire mouse_on_box_0, mouse_on_box_1, mouse_on_box_2, mouse_on_box_3,
    input wire mouse_on_box_4, mouse_on_box_5, mouse_on_box_6, mouse_on_box_7,
    input wire mouse_on_num_1, mouse_on_num_2, mouse_on_num_3,
    input wire mouse_on_num_4, mouse_on_num_5, mouse_on_num_6,
    input wire mouse_on_num_7, mouse_on_num_8, mouse_on_num_9,
    input wire mouse_on_bs, mouse_on_num_0, mouse_on_enter,
    input wire mouse_on_sort_btn,
    input wire mouse_on_back_btn, // Input for back button hover
    
    output reg [15:0] pixel_colour
);

    wire [6:0] x = pixel_index % W;
    wire [5:0] y = pixel_index / W;

    // Colors 
    localparam COL_BG             = 16'b00000_000100_00000; // Dark Green
    localparam COL_TEXT           = 16'hFFFF; // White
    localparam COL_TEXT_DARK      = 16'h0000; // Black
    localparam COL_BOX            = 16'b00100_001000_00100; // Medium Green
    localparam COL_BOX_SELECT     = 16'hFBE0; // Yellow
    localparam COL_NUMPAD_BTN     = 16'b01100_011000_01100; // Medium Gray
    localparam COL_NUMPAD_H       = 16'b10000_100000_10000; // Light Gray
    localparam COL_SORT_BTN       = 16'b00000_111111_00000; // Bright Green
    localparam COL_SORT_H         = 16'hFBE0; // Yellow
    localparam COL_BORDER         = 16'hFFFF; // White borders

    // 1. Draw Array Boxes
    localparam BOX_Y1 = 4, BOX_Y2 = 15;
    localparam BOX_W = 11;
    wire [6:0] box_x_0 = 2;
    wire [6:0] box_x_1 = 14;
    wire [6:0] box_x_2 = 26;
    wire [6:0] box_x_3 = 38;
    wire [6:0] box_x_4 = 50;
    wire [6:0] box_x_5 = 62;
    wire [6:0] box_x_6 = 74;
    wire [6:0] box_x_7 = 86;
    
    wire in_box_0 = (0 < active_array_size) && (x >= box_x_0 && x < box_x_0 + BOX_W && y >= BOX_Y1 && y <= BOX_Y2);
    wire in_box_1 = (1 < active_array_size) && (x >= box_x_1 && x < box_x_1 + BOX_W && y >= BOX_Y1 && y <= BOX_Y2);
    wire in_box_2 = (2 < active_array_size) && (x >= box_x_2 && x < box_x_2 + BOX_W && y >= BOX_Y1 && y <= BOX_Y2);
    wire in_box_3 = (3 < active_array_size) && (x >= box_x_3 && x < box_x_3 + BOX_W && y >= BOX_Y1 && y <= BOX_Y2);
    wire in_box_4 = (4 < active_array_size) && (x >= box_x_4 && x < box_x_4 + BOX_W && y >= BOX_Y1 && y <= BOX_Y2);
    wire in_box_5 = (5 < active_array_size) && (x >= box_x_5 && x < box_x_5 + BOX_W && y >= BOX_Y1 && y <= BOX_Y2);
    wire in_box_6 = (6 < active_array_size) && (x >= box_x_6 && x < box_x_6 + BOX_W && y >= BOX_Y1 && y <= BOX_Y2);
    wire in_box_7 = (7 < active_array_size) && (x >= box_x_7 && x < box_x_7 + BOX_W && y >= BOX_Y1 && y <= BOX_Y2);

    wire in_box_border_0 = (0 < active_array_size) && (x >= box_x_0-1 && x < box_x_0 + BOX_W+1 && y >= BOX_Y1-1 && y <= BOX_Y2+1) && !in_box_0;
    wire in_box_border_1 = (1 < active_array_size) && (x >= box_x_1-1 && x < box_x_1 + BOX_W+1 && y >= BOX_Y1-1 && y <= BOX_Y2+1) && !in_box_1;
    wire in_box_border_2 = (2 < active_array_size) && (x >= box_x_2-1 && x < box_x_2 + BOX_W+1 && y >= BOX_Y1-1 && y <= BOX_Y2+1) && !in_box_2;
    wire in_box_border_3 = (3 < active_array_size) && (x >= box_x_3-1 && x < box_x_3 + BOX_W+1 && y >= BOX_Y1-1 && y <= BOX_Y2+1) && !in_box_3;
    wire in_box_border_4 = (4 < active_array_size) && (x >= box_x_4-1 && x < box_x_4 + BOX_W+1 && y >= BOX_Y1-1 && y <= BOX_Y2+1) && !in_box_4;
    wire in_box_border_5 = (5 < active_array_size) && (x >= box_x_5-1 && x < box_x_5 + BOX_W+1 && y >= BOX_Y1-1 && y <= BOX_Y2+1) && !in_box_5;
    wire in_box_border_6 = (6 < active_array_size) && (x >= box_x_6-1 && x < box_x_6 + BOX_W+1 && y >= BOX_Y1-1 && y <= BOX_Y2+1) && !in_box_6;
    wire in_box_border_7 = (7 < active_array_size) && (x >= box_x_7-1 && x < box_x_7 + BOX_W+1 && y >= BOX_Y1-1 && y <= BOX_Y2+1) && !in_box_7;

    // 2. Draw Numbers in Boxes
    wire [15:0] num_pix_0, num_pix_1, num_pix_2, num_pix_3, num_pix_4, num_pix_5, num_pix_6, num_pix_7;
    wire [15:0] tens_pix_0, ones_pix_0, tens_pix_1, ones_pix_1, tens_pix_2, ones_pix_2, tens_pix_3, ones_pix_3;
    wire [15:0] tens_pix_4, ones_pix_4, tens_pix_5, ones_pix_5, tens_pix_6, ones_pix_6, tens_pix_7, ones_pix_7;

    // Macro-like instantiation for digits
    text_renderer_digit tr_t0 (pixel_index, user_array_0/10, 1, box_x_0+1, BOX_Y1+4, COL_TEXT, COL_BOX, tens_pix_0);
    text_renderer_digit tr_o0 (pixel_index, user_array_0%10, 1, (user_array_0>=10)?box_x_0+5:box_x_0+2, BOX_Y1+4, COL_TEXT, COL_BOX, ones_pix_0);
    assign num_pix_0 = (in_box_0 && user_array_0>=10 && tens_pix_0!=COL_BOX) ? tens_pix_0 : (in_box_0 && ones_pix_0!=COL_BOX) ? ones_pix_0 : COL_BG;

    text_renderer_digit tr_t1 (pixel_index, user_array_1/10, 1, box_x_1+1, BOX_Y1+4, COL_TEXT, COL_BOX, tens_pix_1);
    text_renderer_digit tr_o1 (pixel_index, user_array_1%10, 1, (user_array_1>=10)?box_x_1+5:box_x_1+2, BOX_Y1+4, COL_TEXT, COL_BOX, ones_pix_1);
    assign num_pix_1 = (in_box_1 && user_array_1>=10 && tens_pix_1!=COL_BOX) ? tens_pix_1 : (in_box_1 && ones_pix_1!=COL_BOX) ? ones_pix_1 : COL_BG;

    text_renderer_digit tr_t2 (pixel_index, user_array_2/10, 1, box_x_2+1, BOX_Y1+4, COL_TEXT, COL_BOX, tens_pix_2);
    text_renderer_digit tr_o2 (pixel_index, user_array_2%10, 1, (user_array_2>=10)?box_x_2+5:box_x_2+2, BOX_Y1+4, COL_TEXT, COL_BOX, ones_pix_2);
    assign num_pix_2 = (in_box_2 && user_array_2>=10 && tens_pix_2!=COL_BOX) ? tens_pix_2 : (in_box_2 && ones_pix_2!=COL_BOX) ? ones_pix_2 : COL_BG;

    text_renderer_digit tr_t3 (pixel_index, user_array_3/10, 1, box_x_3+1, BOX_Y1+4, COL_TEXT, COL_BOX, tens_pix_3);
    text_renderer_digit tr_o3 (pixel_index, user_array_3%10, 1, (user_array_3>=10)?box_x_3+5:box_x_3+2, BOX_Y1+4, COL_TEXT, COL_BOX, ones_pix_3);
    assign num_pix_3 = (in_box_3 && user_array_3>=10 && tens_pix_3!=COL_BOX) ? tens_pix_3 : (in_box_3 && ones_pix_3!=COL_BOX) ? ones_pix_3 : COL_BG;

    text_renderer_digit tr_t4 (pixel_index, user_array_4/10, 1, box_x_4+1, BOX_Y1+4, COL_TEXT, COL_BOX, tens_pix_4);
    text_renderer_digit tr_o4 (pixel_index, user_array_4%10, 1, (user_array_4>=10)?box_x_4+5:box_x_4+2, BOX_Y1+4, COL_TEXT, COL_BOX, ones_pix_4);
    assign num_pix_4 = (in_box_4 && user_array_4>=10 && tens_pix_4!=COL_BOX) ? tens_pix_4 : (in_box_4 && ones_pix_4!=COL_BOX) ? ones_pix_4 : COL_BG;

    text_renderer_digit tr_t5 (pixel_index, user_array_5/10, 1, box_x_5+1, BOX_Y1+4, COL_TEXT, COL_BOX, tens_pix_5);
    text_renderer_digit tr_o5 (pixel_index, user_array_5%10, 1, (user_array_5>=10)?box_x_5+5:box_x_5+2, BOX_Y1+4, COL_TEXT, COL_BOX, ones_pix_5);
    assign num_pix_5 = (in_box_5 && user_array_5>=10 && tens_pix_5!=COL_BOX) ? tens_pix_5 : (in_box_5 && ones_pix_5!=COL_BOX) ? ones_pix_5 : COL_BG;

    text_renderer_digit tr_t6 (pixel_index, user_array_6/10, 1, box_x_6+1, BOX_Y1+4, COL_TEXT, COL_BOX, tens_pix_6);
    text_renderer_digit tr_o6 (pixel_index, user_array_6%10, 1, (user_array_6>=10)?box_x_6+5:box_x_6+2, BOX_Y1+4, COL_TEXT, COL_BOX, ones_pix_6);
    assign num_pix_6 = (in_box_6 && user_array_6>=10 && tens_pix_6!=COL_BOX) ? tens_pix_6 : (in_box_6 && ones_pix_6!=COL_BOX) ? ones_pix_6 : COL_BG;

    text_renderer_digit tr_t7 (pixel_index, user_array_7/10, 1, box_x_7+1, BOX_Y1+4, COL_TEXT, COL_BOX, tens_pix_7);
    text_renderer_digit tr_o7 (pixel_index, user_array_7%10, 1, (user_array_7>=10)?box_x_7+5:box_x_7+2, BOX_Y1+4, COL_TEXT, COL_BOX, ones_pix_7);
    assign num_pix_7 = (in_box_7 && user_array_7>=10 && tens_pix_7!=COL_BOX) ? tens_pix_7 : (in_box_7 && ones_pix_7!=COL_BOX) ? ones_pix_7 : COL_BG;

        // 3. Draw Numpad
    
    localparam NUM_X1 = 4, NUM_W = 13, NUM_S_X = 14;
    localparam NUM_Y1 = 20, NUM_H = 9, NUM_S_Y = 10;
    
    wire in_num_1 = (x >= NUM_X1 && x < NUM_X1+NUM_W && y >= NUM_Y1 && y < NUM_Y1+NUM_H);
    wire in_num_2 = (x >= NUM_X1+NUM_S_X && x < NUM_X1+NUM_S_X+NUM_W && y >= NUM_Y1 && y < NUM_Y1+NUM_H);
    wire in_num_3 = (x >= NUM_X1+2*NUM_S_X && x < NUM_X1+2*NUM_S_X+NUM_W && y >= NUM_Y1 && y < NUM_Y1+NUM_H);
    wire in_num_4 = (x >= NUM_X1 && x < NUM_X1+NUM_W && y >= NUM_Y1+NUM_S_Y && y < NUM_Y1+NUM_S_Y+NUM_H);
    wire in_num_5 = (x >= NUM_X1+NUM_S_X && x < NUM_X1+NUM_S_X+NUM_W && y >= NUM_Y1+NUM_S_Y && y < NUM_Y1+NUM_S_Y+NUM_H);
    wire in_num_6 = (x >= NUM_X1+2*NUM_S_X && x < NUM_X1+2*NUM_S_X+NUM_W && y >= NUM_Y1+NUM_S_Y && y < NUM_Y1+NUM_S_Y+NUM_H);
    wire in_num_7 = (x >= NUM_X1 && x < NUM_X1+NUM_W && y >= NUM_Y1+2*NUM_S_Y && y < NUM_Y1+2*NUM_S_Y+NUM_H);
    wire in_num_8 = (x >= NUM_X1+NUM_S_X && x < NUM_X1+NUM_S_X+NUM_W && y >= NUM_Y1+2*NUM_S_Y && y < NUM_Y1+2*NUM_S_Y+NUM_H);
    wire in_num_9 = (x >= NUM_X1+2*NUM_S_X && x < NUM_X1+2*NUM_S_X+NUM_W && y >= NUM_Y1+2*NUM_S_Y && y < NUM_Y1+2*NUM_S_Y+NUM_H);
    wire in_bs    = (x >= NUM_X1 && x < NUM_X1+NUM_W && y >= NUM_Y1+3*NUM_S_Y && y < NUM_Y1+3*NUM_S_Y+NUM_H);
    wire in_num_0 = (x >= NUM_X1+NUM_S_X && x < NUM_X1+NUM_S_X+NUM_W && y >= NUM_Y1+3*NUM_S_Y && y < NUM_Y1+3*NUM_S_Y+NUM_H);
    wire in_enter = (x >= NUM_X1+2*NUM_S_X && x < NUM_X1+2*NUM_S_X+NUM_W && y >= NUM_Y1+3*NUM_S_Y && y < NUM_Y1+3*NUM_S_Y+NUM_H);

    wire in_num_1_border = (x >= NUM_X1-1 && x < NUM_X1+NUM_W+1 && y >= NUM_Y1-1 && y < NUM_Y1+NUM_H+1) && !in_num_1;
    wire in_num_2_border = (x >= NUM_X1+NUM_S_X-1 && x < NUM_X1+NUM_S_X+NUM_W+1 && y >= NUM_Y1-1 && y < NUM_Y1+NUM_H+1) && !in_num_2;
    wire in_num_3_border = (x >= NUM_X1+2*NUM_S_X-1 && x < NUM_X1+2*NUM_S_X+NUM_W+1 && y >= NUM_Y1-1 && y < NUM_Y1+NUM_H+1) && !in_num_3;
    wire in_num_4_border = (x >= NUM_X1-1 && x < NUM_X1+NUM_W+1 && y >= NUM_Y1+NUM_S_Y-1 && y < NUM_Y1+NUM_S_Y+NUM_H+1) && !in_num_4;
    wire in_num_5_border = (x >= NUM_X1+NUM_S_X-1 && x < NUM_X1+NUM_S_X+NUM_W+1 && y >= NUM_Y1+NUM_S_Y-1 && y < NUM_Y1+NUM_S_Y+NUM_H+1) && !in_num_5;
    wire in_num_6_border = (x >= NUM_X1+2*NUM_S_X-1 && x < NUM_X1+2*NUM_S_X+NUM_W+1 && y >= NUM_Y1+NUM_S_Y-1 && y < NUM_Y1+NUM_S_Y+NUM_H+1) && !in_num_6;
    wire in_num_7_border = (x >= NUM_X1-1 && x < NUM_X1+NUM_W+1 && y >= NUM_Y1+2*NUM_S_Y-1 && y < NUM_Y1+2*NUM_S_Y+NUM_H+1) && !in_num_7;
    wire in_num_8_border = (x >= NUM_X1+NUM_S_X-1 && x < NUM_X1+NUM_S_X+NUM_W+1 && y >= NUM_Y1+2*NUM_S_Y-1 && y < NUM_Y1+2*NUM_S_Y+NUM_H+1) && !in_num_8;
    wire in_num_9_border = (x >= NUM_X1+2*NUM_S_X-1 && x < NUM_X1+2*NUM_S_X+NUM_W+1 && y >= NUM_Y1+2*NUM_S_Y-1 && y < NUM_Y1+2*NUM_S_Y+NUM_H+1) && !in_num_9;
    wire in_bs_border    = (x >= NUM_X1-1 && x < NUM_X1+NUM_W+1 && y >= NUM_Y1+3*NUM_S_Y-1 && y < NUM_Y1+3*NUM_S_Y+NUM_H+1) && !in_bs;
    wire in_num_0_border = (x >= NUM_X1+NUM_S_X-1 && x < NUM_X1+NUM_S_X+NUM_W+1 && y >= NUM_Y1+3*NUM_S_Y-1 && y < NUM_Y1+3*NUM_S_Y+NUM_H+1) && !in_num_0;
    wire in_enter_border = (x >= NUM_X1+2*NUM_S_X-1 && x < NUM_X1+2*NUM_S_X+NUM_W+1 && y >= NUM_Y1+3*NUM_S_Y-1 && y < NUM_Y1+3*NUM_S_Y+NUM_H+1) && !in_enter;

    wire [15:0] txt_1, txt_2, txt_3, txt_4, txt_5, txt_6, txt_7, txt_8, txt_9, txt_0, txt_bs, txt_ent;
    text_renderer tr_1 (pixel_index, "1", 1, NUM_X1+5, NUM_Y1+2, COL_TEXT_DARK, COL_NUMPAD_BTN, txt_1);
    text_renderer tr_2 (pixel_index, "2", 1, NUM_X1+NUM_S_X+5, NUM_Y1+2, COL_TEXT_DARK, COL_NUMPAD_BTN, txt_2);
    text_renderer tr_3 (pixel_index, "3", 1, NUM_X1+2*NUM_S_X+5, NUM_Y1+2, COL_TEXT_DARK, COL_NUMPAD_BTN, txt_3);
    text_renderer tr_4 (pixel_index, "4", 1, NUM_X1+5, NUM_Y1+NUM_S_Y+2, COL_TEXT_DARK, COL_NUMPAD_BTN, txt_4);
    text_renderer tr_5 (pixel_index, "5", 1, NUM_X1+NUM_S_X+5, NUM_Y1+NUM_S_Y+2, COL_TEXT_DARK, COL_NUMPAD_BTN, txt_5);
    text_renderer tr_6 (pixel_index, "6", 1, NUM_X1+2*NUM_S_X+5, NUM_Y1+NUM_S_Y+2, COL_TEXT_DARK, COL_NUMPAD_BTN, txt_6);
    text_renderer tr_7 (pixel_index, "7", 1, NUM_X1+5, NUM_Y1+2*NUM_S_Y+2, COL_TEXT_DARK, COL_NUMPAD_BTN, txt_7);
    text_renderer tr_8 (pixel_index, "8", 1, NUM_X1+NUM_S_X+5, NUM_Y1+2*NUM_S_Y+2, COL_TEXT_DARK, COL_NUMPAD_BTN, txt_8);
    text_renderer tr_9 (pixel_index, "9", 1, NUM_X1+2*NUM_S_X+5, NUM_Y1+2*NUM_S_Y+2, COL_TEXT_DARK, COL_NUMPAD_BTN, txt_9);
    text_renderer tr_bs(pixel_index, "C", 1, NUM_X1+5, NUM_Y1+3*NUM_S_Y+2, COL_TEXT_DARK, COL_NUMPAD_BTN, txt_bs);
    text_renderer tr_0 (pixel_index, "0", 1, NUM_X1+NUM_S_X+5, NUM_Y1+3*NUM_S_Y+2, COL_TEXT_DARK, COL_NUMPAD_BTN, txt_0);
    text_renderer tr_e (pixel_index, "E", 1, NUM_X1+2*NUM_S_X+5, NUM_Y1+3*NUM_S_Y+2, COL_TEXT_DARK, COL_NUMPAD_BTN, txt_ent);

       // 4. Draw "SORT" Button & BACK ARROW
    localparam SORT_BTN_X1 = 48, SORT_BTN_X2 = 92;
    localparam SORT_BTN_Y1 = 26, SORT_BTN_Y2 = 40;
    
    wire in_sort_btn_area = (x >= SORT_BTN_X1 && x <= SORT_BTN_X2 && y >= SORT_BTN_Y1 && y <= SORT_BTN_Y2);
    wire in_sort_btn_border = (x >= SORT_BTN_X1-1 && x <= SORT_BTN_X2+1 && y >= SORT_BTN_Y1-1 && y <= SORT_BTN_Y2+1) && !in_sort_btn_area;
    
    wire [15:0] sort_btn_pix;
    text_renderer tr_sort_btn(pixel_index, "SORT", 4, SORT_BTN_X1 + 14, SORT_BTN_Y1 + 4, COL_TEXT_DARK, COL_SORT_BTN, sort_btn_pix);

    // Back Arrow Geometry 
    // Placed in the empty space below SORT button. 
    // Centered approx X=70, Y=52. Pointing Left. Tip at (65, 52).
    wire arrow_shaft = (y == 52) && (x >= 65 && x <= 75);
    wire arrow_top   = (x + y == 65 + 52) && (x >= 65 && x <= 69); // (65,52) -> (69,48)
    wire arrow_bot   = (y - x == 52 - 65) && (x >= 65 && x <= 69); // (65,52) -> (69,56)
    wire is_arrow    = arrow_shaft || arrow_top || arrow_bot;

    
    // 5. Final Color Mux
    
    always @* begin
        // Numpad borders 
        if (in_num_1_border || in_num_2_border || in_num_3_border || 
            in_num_4_border || in_num_5_border || in_num_6_border || 
            in_num_7_border || in_num_8_border || in_num_9_border || 
            in_bs_border    || in_num_0_border || in_enter_border) begin
            pixel_colour = COL_BORDER;
        end
        // Numpad buttons 
        else if (in_num_1) pixel_colour = (txt_1 != COL_NUMPAD_BTN) ? txt_1 : (mouse_on_num_1 ? COL_NUMPAD_H : COL_NUMPAD_BTN);
        else if (in_num_2) pixel_colour = (txt_2 != COL_NUMPAD_BTN) ? txt_2 : (mouse_on_num_2 ? COL_NUMPAD_H : COL_NUMPAD_BTN);
        else if (in_num_3) pixel_colour = (txt_3 != COL_NUMPAD_BTN) ? txt_3 : (mouse_on_num_3 ? COL_NUMPAD_H : COL_NUMPAD_BTN);
        else if (in_num_4) pixel_colour = (txt_4 != COL_NUMPAD_BTN) ? txt_4 : (mouse_on_num_4 ? COL_NUMPAD_H : COL_NUMPAD_BTN);
        else if (in_num_5) pixel_colour = (txt_5 != COL_NUMPAD_BTN) ? txt_5 : (mouse_on_num_5 ? COL_NUMPAD_H : COL_NUMPAD_BTN);
        else if (in_num_6) pixel_colour = (txt_6 != COL_NUMPAD_BTN) ? txt_6 : (mouse_on_num_6 ? COL_NUMPAD_H : COL_NUMPAD_BTN);
        else if (in_num_7) pixel_colour = (txt_7 != COL_NUMPAD_BTN) ? txt_7 : (mouse_on_num_7 ? COL_NUMPAD_H : COL_NUMPAD_BTN);
        else if (in_num_8) pixel_colour = (txt_8 != COL_NUMPAD_BTN) ? txt_8 : (mouse_on_num_8 ? COL_NUMPAD_H : COL_NUMPAD_BTN);
        else if (in_num_9) pixel_colour = (txt_9 != COL_NUMPAD_BTN) ? txt_9 : (mouse_on_num_9 ? COL_NUMPAD_H : COL_NUMPAD_BTN);
        else if (in_bs)    pixel_colour = (txt_bs != COL_NUMPAD_BTN) ? txt_bs : (mouse_on_bs ? COL_NUMPAD_H : COL_NUMPAD_BTN);
        else if (in_num_0) pixel_colour = (txt_0 != COL_NUMPAD_BTN) ? txt_0 : (mouse_on_num_0 ? COL_NUMPAD_H : COL_NUMPAD_BTN);
        else if (in_enter) pixel_colour = (txt_ent != COL_NUMPAD_BTN) ? txt_ent : (mouse_on_enter ? COL_NUMPAD_H : COL_NUMPAD_BTN);
        
        // Sort Button 
        else if (in_sort_btn_border) pixel_colour = COL_BORDER;
        else if (in_sort_btn_area)   pixel_colour = (sort_btn_pix != COL_SORT_BTN) ? sort_btn_pix : (mouse_on_sort_btn ? COL_SORT_H : COL_SORT_BTN);
        
        // Back Arrow 
        // Matches Sort button theme: Normal=Green(COL_SORT_BTN), Hover=Yellow(COL_SORT_H)
        else if (is_arrow) pixel_colour = (mouse_on_back_btn) ? COL_SORT_H : COL_SORT_BTN;

        // Array Boxes 
        else if (in_box_border_0) pixel_colour = (selected_entry_index == 0) ? COL_BOX_SELECT : COL_BORDER;
        else if (in_box_border_1) pixel_colour = (selected_entry_index == 1) ? COL_BOX_SELECT : COL_BORDER;
        else if (in_box_border_2) pixel_colour = (selected_entry_index == 2) ? COL_BOX_SELECT : COL_BORDER;
        else if (in_box_border_3) pixel_colour = (selected_entry_index == 3) ? COL_BOX_SELECT : COL_BORDER;
        else if (in_box_border_4) pixel_colour = (selected_entry_index == 4) ? COL_BOX_SELECT : COL_BORDER;
        else if (in_box_border_5) pixel_colour = (selected_entry_index == 5) ? COL_BOX_SELECT : COL_BORDER;
        else if (in_box_border_6) pixel_colour = (selected_entry_index == 6) ? COL_BOX_SELECT : COL_BORDER;
        else if (in_box_border_7) pixel_colour = (selected_entry_index == 7) ? COL_BOX_SELECT : COL_BORDER;

        // Numbers in Boxes 
        else if (num_pix_0 != COL_BG) pixel_colour = num_pix_0;
        else if (num_pix_1 != COL_BG) pixel_colour = num_pix_1;
        else if (num_pix_2 != COL_BG) pixel_colour = num_pix_2;
        else if (num_pix_3 != COL_BG) pixel_colour = num_pix_3;
        else if (num_pix_4 != COL_BG) pixel_colour = num_pix_4;
        else if (num_pix_5 != COL_BG) pixel_colour = num_pix_5;
        else if (num_pix_6 != COL_BG) pixel_colour = num_pix_6;
        else if (num_pix_7 != COL_BG) pixel_colour = num_pix_7;

        // Box Fill 
        else if (in_box_0 || in_box_1 || in_box_2 || in_box_3 || in_box_4 || in_box_5 || in_box_6 || in_box_7) begin
             pixel_colour = COL_BOX;
        end
        
        // Background 
        else pixel_colour = COL_BG;
    end

endmodule