`timescale 1ns / 1ps

module text_renderer #(
    parameter W = 96,
    parameter H = 64
)(
    input wire [12:0] pixel_index,
    input [8*16-1:0] text_string, 
    input wire [4:0] num_chars,   
    input wire [6:0] start_x,
    input wire [5:0] start_y,
    input wire [15:0] fg_color,
    input wire [15:0] bg_color,
    output reg [15:0] pixel_colour
);

    

    wire [6:0] x = pixel_index % W;
    wire [5:0] y = pixel_index / W;
    
    wire [6:0] x_in_char = x - start_x;
    wire [5:0] y_in_char = y - start_y;
    
    wire [2:0] char_col = x_in_char % 4; // 3-wide font + 1 space
    wire [2:0] char_row = y_in_char;      // 5-high font
    wire [3:0] char_index = x_in_char / 4;
    
    wire [7:0] ascii_char;
    wire [14:0] font_bits;
    wire font_pixel;
    
    // String mode
    assign ascii_char = text_string >> ((num_chars - 1 - char_index) * 8);

    font_rom fr (ascii_char, font_bits);
    
    assign font_pixel = font_bits[ (4-char_row)*3 + (2-char_col) ];
    
    always @* begin
        if (x >= start_x && x < (start_x + num_chars*4) && 
            y >= start_y && y < (start_y + 5) && 
            char_col < 3 && char_index < num_chars) 
        begin
            pixel_colour = font_pixel ? fg_color : bg_color;
        end else begin
            pixel_colour = bg_color;
        end
    end

endmodule

// Special module for single digit
module text_renderer_digit #(
    parameter W = 96,
    parameter H = 64
) (
    input wire [12:0] pixel_index,
    input [3:0] text_string, // Single digit
    input wire [3:0] num_chars,
    input wire [6:0] start_x,
    input wire [5:0] start_y,
    input wire [15:0] fg_color,
    input wire [15:0] bg_color,
    output reg [15:0] pixel_colour
);
    wire [6:0] x = pixel_index % W;
    wire [5:0] y = pixel_index / W;
    
    wire [6:0] x_in_char = x - start_x;
    wire [5:0] y_in_char = y - start_y;
    
    wire [2:0] char_col = x_in_char % 4; // 3-wide font + 1 space
    wire [2:0] char_row = y_in_char;      // 5-high font
    wire [3:0] char_index = x_in_char / 4;
    
    wire [7:0] ascii_char;
    wire [14:0] font_bits;
    wire font_pixel;
    
    // Number mode
    assign ascii_char = (text_string < 10) ? (text_string + 8'd48) : 8'd63; // Convert 0-9 to ASCII '0'-'9'

    font_rom fr (ascii_char, font_bits);
    
    assign font_pixel = font_bits[ (4-char_row)*3 + (2-char_col) ];
    
    always @* begin
        if (x >= start_x && x < (start_x + num_chars*4) && 
            y >= start_y && y < (start_y + 5) && 
            char_col < 3 && char_index < num_chars) 
        begin
            pixel_colour = font_pixel ? fg_color : bg_color;
        end else begin
            pixel_colour = bg_color;
        end
    end
endmodule
