`timescale 1ns / 1ps

module mouse_cursor_gfx #(
    parameter W = 96,
    parameter H = 64
)(
    input wire [12:0] pixel_index,
    input wire [6:0] mouse_x, // 0-95
    input wire [5:0] mouse_y, // 0-63
    input wire mouse_click_lvl, 
    output reg [15:0] pixel_colour
);

    wire [6:0] x = pixel_index % W;
    wire [5:0] y = pixel_index / W;

    localparam COL_CURSOR      = 16'hFFFF; // White
    localparam COL_BORDER      = 16'h0000; // Black
    localparam COL_TRANSPARENT = 16'h0001; // Magic number, not 0

    // Bitmaps (8x9) 
    // 00 = Transparent, 01 = Cursor (White), 10 = Border (Black)
    reg [15:0] arrow_bmp [0:8];
    reg [15:0] finger_bmp [0:8];

    initial begin
        // Default Arrow
        arrow_bmp[0] = 16'b0101000000000000;
        arrow_bmp[1] = 16'b0110010000000000;
        arrow_bmp[2] = 16'b0110100100000000;
        arrow_bmp[3] = 16'b0110101001000000;
        arrow_bmp[4] = 16'b0110101010010000;
        arrow_bmp[5] = 16'b0110010001100100;
        arrow_bmp[6] = 16'b0101000001100100;
        arrow_bmp[7] = 16'b0000000001100100;
        arrow_bmp[8] = 16'b0000000001010000;
        
        // Pointing Finger
        finger_bmp[0] = 16'b0000101010000000;
        finger_bmp[1] = 16'b0010010101100000;
        finger_bmp[2] = 16'b0010010101100000;
        finger_bmp[3] = 16'b0010010101100000;
        finger_bmp[4] = 16'b1001010101011000;
        finger_bmp[5] = 16'b1001010101011000;
        finger_bmp[6] = 16'b0010010101011000;
        finger_bmp[7] = 16'b0000101010101000;
        finger_bmp[8] = 16'b0000000000000000;
    end
    
    // Step 1: Check if the current pixel (x, y) is inside the 8x9 cursor box.
    // This is a safe, unsigned comparison that won't wrap around.
    wire in_box = (x >= mouse_x) && (x < (mouse_x + 8)) &&
                  (y >= mouse_y) && (y < (mouse_y + 9));
                  
    // Step 2: Calculate relative coordinates (only valid if in_box is true).
    wire [3:0] x_rel = x - mouse_x;
    wire [3:0] y_rel = y - mouse_y;
    
    // Step 3: Use a wire to determine the 2-bit pixel value.
    wire [1:0] bmp_pixel;

    assign bmp_pixel = (in_box) ? 
                       (mouse_click_lvl ? 
                           (finger_bmp[y_rel] >> ((7-x_rel) * 2)) & 2'b11 :  
                           (arrow_bmp[y_rel] >> ((7-x_rel) * 2)) & 2'b11) :  
                       2'b00; 

    // Step 4: Use a simple, non-latching always block to set the final color.
    always @* begin
        case (bmp_pixel)
            2'b01:   pixel_colour = COL_CURSOR;
            2'b10:   pixel_colour = COL_BORDER;
            default: pixel_colour = COL_TRANSPARENT; // 2'b00
        endcase
    end

endmodule