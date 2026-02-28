`timescale 1ns / 1ps

// Algorithm Selection Screen GFX
module algo_selection_gfx #(
    parameter W = 96,
    parameter H = 64
)(
    input wire [12:0] pixel_index,
    input wire mouse_on_merge_btn,
    input wire mouse_on_cocktail_btn,
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
   wire [15:0] title_pix, merge_pix, cocktail_pix;
        
        text_renderer tr_title   (pixel_index, "SELECT ALGORITHM", 16, 8, 8, COL_TITLE, COL_BG, title_pix);
        text_renderer tr_merge   (pixel_index, "MERGE SORT", 10, 24, 24, COL_TEXT, COL_BTN, merge_pix);
        text_renderer tr_cocktail(pixel_index, "COCKTAIL SORT", 13, 22, 44, COL_TEXT, COL_BTN, cocktail_pix);

    // Button Geometry 
    localparam BTN_WIDTH = 60, BTN_HEIGHT = 11;
    localparam BTN_X_CENTER = W / 2; // 48
    localparam BTN_X1 = BTN_X_CENTER - (BTN_WIDTH / 2); // 18
    localparam BTN_X2 = BTN_X_CENTER + (BTN_WIDTH / 2); // 78

    // Merge Sort Button
    localparam MERGE_BTN_Y1 = 22, MERGE_BTN_Y2 = MERGE_BTN_Y1 + BTN_HEIGHT; // 33
    wire is_merge_pressed = mouse_on_merge_btn && mouse_click_lvl;
    wire in_merge_btn_area = (x >= BTN_X1 && x <= BTN_X2 && y >= MERGE_BTN_Y1 && y <= MERGE_BTN_Y2);
    wire in_merge_btn_border = (x >= BTN_X1-1 && x <= BTN_X2+1 && y >= MERGE_BTN_Y1-1 && y <= MERGE_BTN_Y2+1) && !in_merge_btn_area;

    // Cocktail Sort Button
    localparam COCKTAIL_BTN_Y1 = 42, COCKTAIL_BTN_Y2 = COCKTAIL_BTN_Y1 + BTN_HEIGHT; // 53
    wire is_cocktail_pressed = mouse_on_cocktail_btn && mouse_click_lvl;
    wire in_cocktail_btn_area = (x >= BTN_X1 && x <= BTN_X2 && y >= COCKTAIL_BTN_Y1 && y <= COCKTAIL_BTN_Y2);
    wire in_cocktail_btn_border = (x >= BTN_X1-1 && x <= BTN_X2+1 && y >= COCKTAIL_BTN_Y1-1 && y <= COCKTAIL_BTN_Y2+1) && !in_cocktail_btn_area;

    // Primitives 
    wire in_border = (x < 2 || x > (W-3) || y < 2 || y > (H-3));

    // Final Color Mux 
    always @* begin
        if (in_border)
            pixel_colour = COL_BTN_BORDER;
        
        // Button 1: MERGE SORT 
        else if (is_merge_pressed && (x >= BTN_X1+1 && x <= BTN_X2+1 && y >= MERGE_BTN_Y1+1 && y <= MERGE_BTN_Y2+1))
            pixel_colour = (merge_pix != COL_BTN) ? COL_TEXT : COL_BTN_H; // Pressed text and bg
        else if (in_merge_btn_border)
            pixel_colour = COL_BTN_BORDER;
        else if (in_merge_btn_area)
            pixel_colour = (merge_pix != COL_BTN) ? COL_TEXT : (mouse_on_merge_btn ? COL_BTN_H : COL_BTN);

        // Button 2: COCKTAIL SORT 
        else if (is_cocktail_pressed && (x >= BTN_X1+1 && x <= BTN_X2+1 && y >= COCKTAIL_BTN_Y1+1 && y <= COCKTAIL_BTN_Y2+1))
            pixel_colour = (cocktail_pix != COL_BTN) ? COL_TEXT : COL_BTN_H; // Pressed text and bg
        else if (in_cocktail_btn_border)
            pixel_colour = COL_BTN_BORDER;
        else if (in_cocktail_btn_area)
            pixel_colour = (cocktail_pix != COL_BTN) ? COL_TEXT : (mouse_on_cocktail_btn ? COL_BTN_H : COL_BTN);

        //Other UI 
        else if (title_pix != COL_BG)
            pixel_colour = title_pix;
        else
            pixel_colour = COL_BG;
    end

endmodule