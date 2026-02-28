`timescale 1ns / 1ps


module clock_divider( input clk, input [31:0] m, output reg slow_clk
    );
    reg [31:0] COUNT = 0;
    always @ (posedge clk)
    begin
        COUNT <= (COUNT == m) ? 0 : COUNT + 1;
        slow_clk <= (COUNT == 0) ? ~slow_clk : slow_clk;
    end
endmodule