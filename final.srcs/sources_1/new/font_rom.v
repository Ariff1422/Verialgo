`timescale 1ns / 1ps

module font_rom (
    input wire [7:0] char_ascii,
    output reg [14:0] font_bits // 5 rows x 3 cols
);

    // 3x5 Font ROM (15 bits per char)
    // 0 = background, 1 = foreground
    // Format: [Row1 (3bit_R_C_L)][Row2][Row3][Row4][Row5]
    
    always @* begin
        case (char_ascii)
            // ALPHABET 
            8'd65: font_bits = 15'b111_101_111_101_101; // A
            8'd66: font_bits = 15'b110_101_110_101_110; // B
            8'd67: font_bits = 15'b111_100_100_100_111; // C
            8'd68: font_bits = 15'b110_101_101_101_110; // D
            8'd69: font_bits = 15'b111_100_111_100_111; // E
            8'd71: font_bits = 15'b111_100_101_101_111; // G
            8'd72: font_bits = 15'b101_101_111_101_101; // H  
            8'd73: font_bits = 15'b111_010_010_010_111; // I
            8'd75: font_bits = 15'b101_101_110_101_101; // K  
            8'd76: font_bits = 15'b100_100_100_100_111; // L
            8'd77: font_bits = 15'b101_111_101_101_101; // M
            8'd78: font_bits = 15'b101_111_111_101_101; // N
            8'd79: font_bits = 15'b111_101_101_101_111; // O
            8'd80: font_bits = 15'b111_101_111_100_100; // P
            8'd82: font_bits = 15'b111_101_110_101_101; // R
            8'd83: font_bits = 15'b111_100_111_001_111; // S
            8'd84: font_bits = 15'b111_010_010_010_010; // T
            8'd85: font_bits = 15'b101_101_101_101_111; // U
            8'd86: font_bits = 15'b101_101_101_010_010; // V
            8'd88: font_bits = 15'b101_101_010_101_101; // X
            8'd89: font_bits = 15'b101_101_010_010_010; // Y
            8'd90: font_bits = 15'b111_001_010_100_111; // Z  

            // DIGITS 
            8'd48: font_bits = 15'b111_101_101_101_111; // 0
            8'd49: font_bits = 15'b010_010_010_010_010; // 1
            8'd50: font_bits = 15'b111_001_111_100_111; // 2
            8'd51: font_bits = 15'b111_001_111_001_111; // 3
            8'd52: font_bits = 15'b101_101_111_001_001; // 4
            8'd53: font_bits = 15'b111_100_111_001_111; // 5
            8'd54: font_bits = 15'b111_100_111_101_111; // 6
            8'd55: font_bits = 15'b111_001_001_001_001; // 7
            8'd56: font_bits = 15'b111_101_111_101_111; // 8
            8'd57: font_bits = 15'b111_101_111_001_111; // 9
            
            // SPECIAL 
            8'd32: font_bits = 15'b000_000_000_000_000; // (Space)
            8'd46: font_bits = 15'b000_000_000_000_010; // . (Decimal Point) 
            8'd58: font_bits = 15'b000_010_000_010_000; // :
            
            default: font_bits = 15'b111_101_111_101_111; // Default to '8'
        endcase
    end

endmodule