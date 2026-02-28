`timescale 1ns / 1ps

module btn_debouncer #(
    parameter integer COUNT_MAX = 1_000_000  // ~10ms @ 100MHz
)(
    input  wire clk,
    input  wire btn_in,      // raw button
    output reg  level = 1'b0, // debounced level
    output wire rise,        // 1-cycle pulse on 0->1
    output wire fall         // 1-cycle pulse on 1->0 
);
    // 2-FF sync to clk
    reg s0 = 0, s1 = 0;
    always @(posedge clk) begin
        s0 <= btn_in;
        s1 <= s0;
    end

    // debounce counter + update level when stable long enough
    reg [$clog2(COUNT_MAX):0] cnt = 0;
    always @(posedge clk) begin
        if (s1 == level) begin
            cnt <= 0;                         // no change; reset counter
        end else if (cnt == COUNT_MAX-1) begin
            level <= s1;                      // accept new stable value
            cnt   <= 0;
        end else begin
            cnt <= cnt + 1;
        end
    end

    // edge detect on debounced level
    reg level_q = 0;
    always @(posedge clk) level_q <= level;

    assign rise =  level & ~level_q;
    assign fall = ~level &  level_q;
endmodule