`timescale 1ns / 1ps

module selection_screen_gfx #(
    parameter W = 96,
    parameter H = 64
)(
    input wire [12:0] pixel_index,
    input wire mouse_on_random_btn,
    input wire mouse_on_create_btn,
    input wire mouse_on_back_btn,   // Input for back button hover
    input wire mouse_click_lvl,     
    output reg [15:0] pixel_colour
);

    wire [6:0] x = pixel_index % W;
    wire [5:0] y = pixel_index / W;

    // Colors 
    localparam COL_BG         = 16'b00000_000100_00000; // Dark Green
    localparam COL_TITLE      = 16'hFBE0; // Yellow
    localparam COL_TEXT       = 16'h0000; // Black
    localparam COL_BTN        = 16'b00000_111111_00000; // Bright Green
    localparam COL_BTN_H      = 16'hFBE0; // Yellow (Highlight)
    localparam COL_BTN_BORDER = 16'h0000; // Black
    
    // Text Rendering
    wire [15:0] title_pix, random_pix, create_pix;
    
    text_renderer tr_title (pixel_index, "SELECT MODE", 11, 20, 8, COL_TITLE, COL_BG, title_pix);
    text_renderer tr_random(pixel_index, "RANDOM", 6, 30, 24, COL_TEXT, COL_BTN, random_pix);
    text_renderer tr_create(pixel_index, "CREATE", 6, 30, 44, COL_TEXT, COL_BTN, create_pix);

    // Button Geometry 
    localparam BTN_WIDTH = 45, BTN_HEIGHT = 11;
    localparam BTN_X_CENTER = W / 2; // 48
    localparam BTN_X1 = BTN_X_CENTER - (BTN_WIDTH / 2); // 25
    localparam BTN_X2 = BTN_X_CENTER + (BTN_WIDTH / 2); // 70

    // Random Button
    localparam RAND_BTN_Y1 = 22, RAND_BTN_Y2 = RAND_BTN_Y1 + BTN_HEIGHT; // 33
    wire is_random_pressed = mouse_on_random_btn && mouse_click_lvl;
    wire in_random_btn_area = (x >= BTN_X1 && x <= BTN_X2 && y >= RAND_BTN_Y1 && y <= RAND_BTN_Y2);
    wire in_random_btn_border = (x >= BTN_X1-1 && x <= BTN_X2+1 && y >= RAND_BTN_Y1-1 && y <= RAND_BTN_Y2+1) && !in_random_btn_area;

    // Create Button
    localparam CREATE_BTN_Y1 = 42, CREATE_BTN_Y2 = CREATE_BTN_Y1 + BTN_HEIGHT; // 53
    wire is_create_pressed = mouse_on_create_btn && mouse_click_lvl;
    wire in_create_btn_area = (x >= BTN_X1 && x <= BTN_X2 && y >= CREATE_BTN_Y1 && y <= CREATE_BTN_Y2);
    wire in_create_btn_border = (x >= BTN_X1-1 && x <= BTN_X2+1 && y >= CREATE_BTN_Y1-1 && y <= CREATE_BTN_Y2+1) && !in_create_btn_area;

    // Back Arrow Geometry 
    // Placed Top-Left. Tip at (6,8).
    wire arrow_shaft = (y == 8) && (x >= 6 && x <= 12);
    wire arrow_top   = (x + y == 14) && (x >= 6 && x <= 9); // Draws pixels (6,8), (7,7), (8,6), (9,5)
    wire arrow_bot   = (y - x == 2)  && (x >= 6 && x <= 9); // Draws pixels (6,8), (7,9), (8,10), (9,11)
    wire is_arrow    = arrow_shaft || arrow_top || arrow_bot;
    
    wire in_back_area = (x >= 4 && x <= 14 && y >= 4 && y <= 12); 

    // Primitives 
    wire in_border = (x < 2 || x > (W-3) || y < 2 || y > (H-3));

    // Final Color Mux 
    always @* begin
        if (in_border)
            pixel_colour = COL_BTN_BORDER; // Use black for border
        
        // Back Arrow 
        // It turns bright green on hover/click, stays yellow normally (matching title)
        else if (is_arrow)
            pixel_colour = (mouse_on_back_btn) ? COL_BTN : COL_TITLE;

        // Button 1: RANDOM 
        // (Slight offset for 3D press effect)
        else if (is_random_pressed && (x >= BTN_X1+1 && x <= BTN_X2+1 && y >= RAND_BTN_Y1+1 && y <= RAND_BTN_Y2+1))
            pixel_colour = (random_pix != COL_BTN) ? COL_TEXT : COL_BTN_H; // Pressed text and bg
        else if (in_random_btn_border)
            pixel_colour = COL_BTN_BORDER;
        else if (in_random_btn_area)
            pixel_colour = (random_pix != COL_BTN) ? COL_TEXT : (mouse_on_random_btn ? COL_BTN_H : COL_BTN);

        // Button 2: CREATE 
        else if (is_create_pressed && (x >= BTN_X1+1 && x <= BTN_X2+1 && y >= CREATE_BTN_Y1+1 && y <= CREATE_BTN_Y2+1))
            pixel_colour = (create_pix != COL_BTN) ? COL_TEXT : COL_BTN_H; // Pressed text and bg
        else if (in_create_btn_border)
            pixel_colour = COL_BTN_BORDER;
        else if (in_create_btn_area)
            pixel_colour = (create_pix != COL_BTN) ? COL_TEXT : (mouse_on_create_btn ? COL_BTN_H : COL_BTN);

        // Other UI 
        else if (title_pix != COL_BG)
            pixel_colour = title_pix;
        else
            pixel_colour = COL_BG;
    end

endmodule