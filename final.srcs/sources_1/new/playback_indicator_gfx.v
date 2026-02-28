`timescale 1ns / 1ps


// Playback Speed & Pause Indicator GFX
// Shows speed (0.5x, 1.0x, 1.5x, 2.0x) or pause icon in top-left

module playback_indicator_gfx #(
    parameter W = 96,
    parameter H = 64
)(
    input wire [12:0] pixel_index,
    input wire [1:0] speed_select,  // 00=0.5x, 01=1.0x, 10=1.5x, 11=2.0x
    input wire is_paused,           // Show pause icon when high
    input wire show_indicator,      // Only show during playback
    output reg [15:0] pixel_colour
);

    wire [6:0] x = pixel_index % W;
    wire [5:0] y = pixel_index / W;

    // Colors 
    localparam COL_BG         = 16'b00000_000100_00000; // Dark Green (transparent)
    localparam COL_TEXT       = 16'hFFFF; // White
    localparam COL_HIGHLIGHT  = 16'hFBE0; // Yellow
    localparam COL_TRANSPARENT = 16'h0001; // Magic transparent value

    // Indicator Position (Top-Left Corner) 
    localparam IND_X = 2;
    localparam IND_Y = 2;
    localparam IND_W = 24; // Width for "0.5x" text (6 chars * 4 pixels)
    localparam IND_H = 8;  // Height (5 pixels for text + 3 padding)

    // Check if pixel is in indicator area 
    wire in_indicator_area = show_indicator && 
                             (x >= IND_X && x < IND_X + IND_W) &&
                             (y >= IND_Y && y < IND_Y + IND_H);

    // Text Rendering 
    wire [15:0] speed_05x_pix, speed_10x_pix, speed_15x_pix, speed_20x_pix;
    
    text_renderer tr_05x (pixel_index, "0.5X", 4, IND_X, IND_Y+1, COL_HIGHLIGHT, COL_BG, speed_05x_pix);
    text_renderer tr_10x (pixel_index, "1.0X", 4, IND_X, IND_Y+1, COL_HIGHLIGHT, COL_BG, speed_10x_pix);
    text_renderer tr_15x (pixel_index, "1.5X", 4, IND_X, IND_Y+1, COL_HIGHLIGHT, COL_BG, speed_15x_pix);
    text_renderer tr_20x (pixel_index, "2.0X", 4, IND_X, IND_Y+1, COL_HIGHLIGHT, COL_BG, speed_20x_pix);

    // Pause Icon (Two vertical bars) 
    // Bar 1: X=6-8, Y=3-7
    // Bar 2: X=10-12, Y=3-7
    wire in_pause_bar1 = (x >= IND_X+4 && x <= IND_X+6 && y >= IND_Y+1 && y <= IND_Y+5);
    wire in_pause_bar2 = (x >= IND_X+9 && x <= IND_X+11 && y >= IND_Y+1 && y <= IND_Y+5);
    wire in_pause_icon = in_pause_bar1 || in_pause_bar2;

    // Select active text based on speed 
    wire [15:0] active_speed_pix;
    assign active_speed_pix = (speed_select == 2'b00) ? speed_05x_pix :
                              (speed_select == 2'b01) ? speed_10x_pix :
                              (speed_select == 2'b10) ? speed_15x_pix :
                              speed_20x_pix;

    // Final Color Mux 
    always @* begin
        if (!in_indicator_area) begin
            // Outside indicator area - fully transparent
            pixel_colour = COL_TRANSPARENT;
        end else if (is_paused) begin
            // Show pause icon
            if (in_pause_icon)
                pixel_colour = COL_HIGHLIGHT;
            else
                pixel_colour = COL_TRANSPARENT;
        end else begin
            // Show speed text
            if (active_speed_pix != COL_BG)
                pixel_colour = active_speed_pix;
            else
                pixel_colour = COL_TRANSPARENT;
        end
    end

endmodule