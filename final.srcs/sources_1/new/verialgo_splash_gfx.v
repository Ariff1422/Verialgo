`timescale 1ns / 1ps

// Verialgo Splash Screen GFX (3D Bevel Border)
module verialgo_splash_gfx #(
    parameter W = 96,
    parameter H = 64
)(
    input wire [12:0] pixel_index,
    input wire flash_bit,   // For pulsing bar 
    input wire [6:0] animation_wipe_y, // For wipe transition (0-64)
    output reg [15:0] pixel_colour
);

    wire [6:0] x = pixel_index % W;
    wire [5:0] y = pixel_index / W;

    localparam COL_BG         = 16'b00000_000100_00000; // Dark Green
    localparam COL_TEXT       = 16'hFFFF; // White
    localparam COL_HIGHLIGHT  = 16'hFBE0; // Yellow/Orange
    localparam COL_SHADOW     = 16'b00000_001000_00000; // Darker Green for shadow
    localparam COL_WIPE       = 16'h0000; // Black for wipe

    // Text Rendering 
    
    // 1. Title "VERIALGO" (Scaled 2x)
    wire [15:0] title_pixel;
    localparam TITLE_X_START = 16; // Centered
    localparam TITLE_Y_START = 22;
    
    // Calculate "virtual" coordinates for the 2x scaled font
    wire [6:0] x_in_char_title = (x - TITLE_X_START) / 2; // Scaled X
    wire [5:0] y_in_char_title = (y - TITLE_Y_START) / 2; // Scaled Y
    wire [12:0] virtual_pixel_title = (y_in_char_title * W) + x_in_char_title;
    
    text_renderer tr_title (
        .pixel_index(virtual_pixel_title), 
        .text_string("VERIALGO"), 
        .num_chars(8), 
        .start_x(0), .start_y(0), // Start at 0 in virtual space
        .fg_color(COL_TEXT),
        .bg_color(COL_BG), 
        .pixel_colour(title_pixel)
    );
    
    // 2. "PRESS START" text (1x scale, new color)
    wire [15:0] start_pixel;
    text_renderer tr_start (
        .pixel_index(pixel_index), 
        .text_string("PRESS START"), 
        .num_chars(11), 
        .start_x(26), // Centered
        .start_y(45), 
        .fg_color(COL_HIGHLIGHT), // Use highlight color
        .bg_color(COL_BG), 
        .pixel_colour(start_pixel)
    );
    
    // Primitives 
    
    // 3D Bevel Border (3px wide)
    localparam BORDER_WIDTH = 3;
    wire in_border_top = (y < BORDER_WIDTH);
    wire in_border_left = (x < BORDER_WIDTH);
    wire in_border_bottom = (y >= H - BORDER_WIDTH);
    wire in_border_right = (x >= W - BORDER_WIDTH);
    
    // Check if current pixel is within the 2x scaled title area
    wire in_title_area = (x >= TITLE_X_START && x < (TITLE_X_START + 8 * 4 * 2) && 
                          y >= TITLE_Y_START && y < (TITLE_Y_START + 5 * 2));

    // Final Color Mux 
    always @* begin
        // Wipe animation has highest priority
        if (y < animation_wipe_y) begin
            pixel_colour = COL_WIPE; 
        end
        // Draw 3D Bevel Border
        else if (in_border_top || in_border_left) begin
            pixel_colour = COL_HIGHLIGHT;
        end
        else if (in_border_bottom || in_border_right) begin
            pixel_colour = COL_SHADOW;
        end
        // Draw 2x Scaled Title
        else if (in_title_area && title_pixel != COL_BG) begin
            pixel_colour = title_pixel;
        end
        // Draw "PRESS START" Text
        else if (start_pixel != COL_BG) begin
            pixel_colour = start_pixel;
        end
        // Draw Background
        else begin
            pixel_colour = COL_BG;
        end
    end

endmodule

