`timescale 1ns / 1ps

// Create Mode Setup Screen GFX
// - Title 
// - Size slider
// - "NEXT" button
// - Back Arrow (Top Left)

module create_setup_gfx #(
    parameter W = 96,
    parameter H = 64
)(
    input wire [12:0] pixel_index,
    input wire [3:0] array_size,
    input wire mouse_on_button,
    input wire mouse_on_back_btn,   // Input for back button hover
    
    output reg [15:0] pixel_colour
);

    wire [6:0] x = pixel_index % W;
    wire [5:0] y = pixel_index / W;

    // Colors 
    localparam COL_BG              = 16'b00000_000100_00000; // Dark Green
    localparam COL_TEXT            = 16'hFFFF; // White
    localparam COL_TITLE           = 16'hFBE0; // Yellow
    localparam COL_BTN             = 16'b00000_111111_00000; // Bright Green
    localparam COL_BTN_H           = 16'hFBE0; // Yellow (Highlight)
    localparam COL_BTN_BORDER      = 16'h0000; // Black
    localparam COL_SLIDER_BG       = 16'b00100_001000_00100; // Medium Green
    localparam COL_SLIDER_KNOB     = 16'hFFFF; // White
    
    // Text Rendering 
    wire [15:0] title_pix, size_pix, num_pix, btn_pix;
    wire [3:0] size_digit = array_size % 10;
    
    // Moved title to X=17 to clear the back arrow
    text_renderer tr_title (pixel_index, "CREATE ARRAY", 12, 17, 5, COL_TITLE, COL_BG, title_pix);
    text_renderer tr_size  (pixel_index, "SIZE:", 5, 24, 25, COL_TEXT, COL_BG, size_pix);
    text_renderer_digit tr_num (pixel_index, size_digit, 1, 60, 25, COL_TEXT, COL_BG, num_pix);
    text_renderer tr_btn   (pixel_index, "NEXT", 4, 40, 50, 16'b0, COL_BTN, btn_pix);

    // Slider Geometry 
    localparam SLIDER_Y = 36;
    localparam SLIDER_X1 = 24, SLIDER_X2 = 72;
    localparam SLIDER_RANGE = SLIDER_X2 - SLIDER_X1;
    
    // Thin track
    wire in_slider_track = (x >= SLIDER_X1 && x <= SLIDER_X2 && y >= SLIDER_Y - 1 && y <= SLIDER_Y + 1);
    
    // Calculate knob position based on array_size (2 to 8)
    wire [6:0] knob_x_pos = SLIDER_X1 + ((SLIDER_RANGE * (array_size - 2)) / 6);
    // Square knob
    wire in_knob = (x >= knob_x_pos - 3 && x <= knob_x_pos + 3 && y >= SLIDER_Y - 3 && y <= SLIDER_Y + 3);

    // Button Geometry ("NEXT") 
    localparam BTN_Y1 = 47, BTN_Y2 = 57; // 11 pixels high
    localparam BTN_X1 = 28, BTN_X2 = 68; // 41 pixels wide
    
    wire in_button_area = (x >= BTN_X1 && x <= BTN_X2 && y >= BTN_Y1 && y <= BTN_Y2);
    // 1-pixel border
    wire in_button_border = (x >= BTN_X1-1 && x <= BTN_X2+1 && y >= BTN_Y1-1 && y <= BTN_Y2+1) && !in_button_area;

    // Back Arrow Geometry 
    // Placed Top-Left. Tip at (6,8). Ends at x=12.
    wire arrow_shaft = (y == 8) && (x >= 6 && x <= 12);
    wire arrow_top   = (x + y == 14) && (x >= 6 && x <= 9); // Draws pixels (6,8), (7,7), (8,6), (9,5)
    wire arrow_bot   = (y - x == 2)  && (x >= 6 && x <= 9); // Draws pixels (6,8), (7,9), (8,10), (9,11)
    wire is_arrow    = arrow_shaft || arrow_top || arrow_bot;

    // Final Color Mux 
    always @* begin
        // Back Arrow 
        if (is_arrow)
            pixel_colour = (mouse_on_back_btn) ? COL_BTN : COL_TITLE;
            
        // Other UI 
        else if (title_pix != COL_BG)
            pixel_colour = title_pix;
        else if (size_pix != COL_BG)
            pixel_colour = size_pix;
        else if (num_pix != COL_BG)
            pixel_colour = num_pix;
        else if (in_knob)
            pixel_colour = COL_SLIDER_KNOB;
        else if (in_slider_track)
            pixel_colour = COL_SLIDER_BG;
        else if (btn_pix != COL_BTN)
            pixel_colour = btn_pix; // Button text
        else if (in_button_area)
            pixel_colour = mouse_on_button ? COL_BTN_H : COL_BTN;
        else if (in_button_border)
            pixel_colour = COL_BTN_BORDER;
        else
            pixel_colour = COL_BG;
    end

endmodule